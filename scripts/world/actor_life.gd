extends Node
## 有骨骼就播动画。没有骨骼时用程序动作：分腿走跑、抬枪、贴墙隐蔽、跳跃、中弹倒地。

var _mesh: Node3D
var _base_scale := Vector3.ONE
var _anim: AnimationPlayer
var _skel: Skeleton3D
var _head := -1
var _head_rest := Quaternion.IDENTITY
var _phase := "hold"
var _phase_left := 2.0
var _yaw := 0.0
var _yaw_from := 0.0
var _yaw_to := 0.0
var _breath := 0.0
var _base_y := 0.0
var _pose := &"idle"
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _rifle: Node3D
var _rifle_on_bone := false
var _fire_left := 0.0
var _step := 0.0
var _cover_side := 1.0
static var _rifle_templates: Dictionary = {}

func bind(mesh: Node3D) -> void:
	_mesh = mesh
	_base_scale = mesh.scale
	_base_y = mesh.position.y
	_soften(mesh)
	_anim = _find_player(mesh)
	_skel = _find_skeleton(mesh)
	if _skel:
		for i in _skel.get_bone_count():
			var bone_name := _skel.get_bone_name(i).to_lower()
			if bone_name.contains("head"):
				_head = i
				_head_rest = _skel.get_bone_pose_rotation(i)
				break
		# 村民不持枪；敌军/民兵挂精细步枪
		if not _is_villager():
			_build_rifle_only()
	else:
		if _is_villager():
			_build_limbs_no_rifle()
		else:
			_build_limbs()
	_phase_left = randf_range(2.5, 5.0)

## Return first clip name from candidates that exists in _anim, or "" if none found.
func _first_clip(candidates: Array) -> String:
	for c in candidates:
		if _has(c):
			return c
	return ""


func set_pose(pose: StringName) -> void:
	_pose = pose
	# If a rigged AnimationPlayer is available, seek the best clip immediately
	# so pose changes from enemy/ally/villager take effect without waiting a frame.
	if _anim == null or _anim.get_animation_list().size() == 0:
		return
	var clip := ""
	match pose:
		&"dead":   clip = _first_clip(["Death",  "Death01",   "Dead"])
		&"aim":    clip = _first_clip(["Aim",    "Pistol_Aim_Neutral"])
		&"run":    clip = _first_clip(["Run",    "Sprint_Loop"])
		&"walk":   clip = _first_clip(["Walk",   "Walk_Loop"])
		&"crouch": clip = _first_clip(["Crouch", "Crouch_Idle_Loop"])
		&"jump":   clip = _first_clip(["Jump",   "Jump_Loop"])
		&"idle":   clip = _first_clip(["Idle",   "Idle_Loop"])
	if clip != "" and _anim.current_animation != clip:
		_anim.play(clip)

func _process(delta: float) -> void:
	if _mesh == null or not is_instance_valid(_mesh):
		return
	if _fire_left > 0.0:
		_fire_left = maxf(0.0, _fire_left - delta)
	var body := get_parent() as CharacterBody3D
	if body and body.get("alive") == false and _pose != &"dead":
		_pose = &"dead"
	var moving := false
	var speed := 0.0
	var crouched := false
	var airborne := false
	if body:
		speed = Vector2(body.velocity.x, body.velocity.z).length()
		moving = speed > 0.35
		var covering: bool = false
		var aiming: bool = false
		if body.get("_covering") == true:
			covering = true
		if body.get("_aiming") == true:
			aiming = true
		crouched = body.global_position.y < -1.0 or covering
		airborne = not body.is_on_floor() and body.velocity.y > 0.4
		var posed: Variant = body.get("_pose")
		if posed != null and str(posed) != "":
			_pose = posed as StringName
		if _fire_left > 0.0:
			_pose = &"aim"
		elif aiming:
			_pose = &"aim"
		elif covering:
			_pose = &"cover"
		elif airborne:
			_pose = &"jump"
		elif moving and speed > 2.6:
			_pose = &"run"
		elif moving:
			_pose = &"walk"
		elif _pose != &"dead" and _pose != &"aim" and _pose != &"cover":
			_pose = &"idle"
	if _anim and _anim.get_animation_list().size() > 0:
		_drive(moving, crouched)
		_update_rifle_pose(moving)
		_ease_head(delta)
		return
	_breath += delta
	if _pose == &"dead":
		_mesh.rotation.x = move_toward(_mesh.rotation.x, PI * 0.5, delta * 4.0)
		_mesh.position.y = move_toward(_mesh.position.y, 0.12, delta * 3.0)
		return
	var squash := absf(_mesh.scale.y / maxf(_base_scale.y, 0.001) - 1.0) > 0.15
	if not squash:
		var breath := 1.0 + sin(_breath * 1.7) * 0.008
		_mesh.scale = Vector3(_base_scale.x, _base_scale.y * breath, _base_scale.z)
	if moving:
		_step += delta * clampf(speed, 1.0, 5.5) * (1.7 if _pose == &"run" else 1.15)
	_apply_limbs(moving, crouched, speed)
	_ease_yaw(delta)

func play_fire() -> void:
	_fire_left = 0.35
	_pose = &"aim"
	if _anim == null or _anim.get_animation_list().size() == 0:
		_update_rifle_pose(false)
		return
	var clip := _first_clip(["Shoot", "Pistol_Shoot", "Aim", "Pistol_Aim_Neutral"])
	if clip != "":
		_anim.play(clip)

func muzzle_point() -> Vector3:
	if _rifle and is_instance_valid(_rifle):
		return _rifle.global_position + (-_rifle.global_transform.basis.z) * 0.55 + Vector3.UP * 0.02
	var body := get_parent() as Node3D
	if body:
		return body.global_position + Vector3.UP * 1.35 + (-body.global_transform.basis.z) * 0.55
	return Vector3.ZERO

func _rifle_glb_path() -> String:
	var body := get_parent()
	if body != null and body.is_in_group("enemies"):
		return "res://assets/props/rifle_arisaka.glb"
	if body != null and (body.is_in_group("allies") or body.is_in_group("player")):
		return "res://assets/props/rifle_hanyang.glb"
	return "res://assets/props/rifle_hanyang.glb"

func _build_rifle_only() -> void:
	_rifle = Node3D.new()
	_rifle.name = "HeldRifle"
	_rifle.visible = true
	_rifle_on_bone = false
	var path := _rifle_glb_path()
	var loaded := false
	var visual := _rifle_visual_from_cache(path)
	if visual:
		_rifle.add_child(visual)
		loaded = true
	if not loaded:
		_build_box_rifle()
	var bone_i := _find_hand_bone()
	if _skel and bone_i >= 0:
		var att := BoneAttachment3D.new()
		att.name = "RifleAttach"
		att.bone_idx = bone_i
		_skel.add_child(att)
		att.add_child(_rifle)
		_rifle.position = Vector3(0.03, -0.02, 0.05)
		_rifle.rotation_degrees = Vector3(-10, 95, 8)
		_rifle_on_bone = true
	else:
		_mesh.add_child(_rifle)
		_rifle.position = Vector3(0.18, 1.05, 0.05)
		_rifle.rotation = Vector3(0.75, 0.15, 0.1)

func _rifle_visual_from_cache(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _rifle_templates.has(path):
		var packed := load(path) as PackedScene
		if packed == null:
			return null
		var inst := packed.instantiate() as Node3D
		if inst == null:
			return null
		_strip_col(inst)
		var bb := _node_aabb(inst)
		var long := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		var s := 0.95 / maxf(long, 0.05)
		inst.scale = Vector3.ONE * s
		inst.rotation_degrees = Vector3(0, 180, 0)
		inst.position = -bb.get_center() * s
		_rifle_templates[path] = inst
	var tmpl: Node3D = _rifle_templates[path]
	return tmpl.duplicate() as Node3D

func _build_box_rifle() -> void:
	var stock := MeshInstance3D.new()
	var stock_mesh := BoxMesh.new()
	stock_mesh.size = Vector3(0.055, 0.08, 0.34)
	stock.mesh = stock_mesh
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.12)
	wood.roughness = 0.85
	stock.material_override = wood
	_rifle.add_child(stock)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.032, 0.032, 0.52)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 0.02, -0.3)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.18, 0.18, 0.16)
	iron.metallic = 0.55
	iron.roughness = 0.4
	barrel.material_override = iron
	_rifle.add_child(barrel)
	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.04, 0.12, 0.05)
	grip.mesh = grip_mesh
	grip.position = Vector3(0, -0.06, 0.02)
	grip.material_override = wood
	_rifle.add_child(grip)

func _find_hand_bone() -> int:
	if _skel == null:
		return -1
	var best := -1
	for i in _skel.get_bone_count():
		var n := _skel.get_bone_name(i).to_lower().replace(" ", "").replace(".", "").replace("_", "")
		if "lefthand" in n or n.ends_with("handl") or n == "lefthand":
			continue
		if "righthand" in n or n.ends_with("handr") or n == "righthand" or n.ends_with("rhand"):
			return i
		if best < 0 and n.contains("hand") and n.contains("r") and not n.contains("left"):
			best = i
	return best

func _strip_col(node: Node) -> void:
	for c in node.get_children():
		_strip_col(c)
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true

func _node_aabb(root: Node3D) -> AABB:
	var merged := AABB()
	var has := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		for c in n.get_children():
			var child_xf := xf
			if c is Node3D:
				child_xf = xf * (c as Node3D).transform
			stack.append([c, child_xf])
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var ab := mi.get_aabb()
			for i in 8:
				var p: Vector3 = xf * ab.get_endpoint(i)
				if not has:
					merged = AABB(p, Vector3.ZERO)
					has = true
				else:
					merged = merged.expand(p)
	return merged if has else AABB(Vector3(-0.05, -0.05, -0.4), Vector3(0.1, 0.1, 0.8))

func _update_rifle_pose(moving: bool) -> void:
	if _rifle == null:
		return
	_rifle.visible = _pose != &"dead"
	if _rifle_on_bone:
		match _pose:
			&"aim":
				_rifle.position = Vector3(0.02, -0.01, 0.04)
				_rifle.rotation_degrees = Vector3(-12, 92, 4)
			_:
				_rifle.position = Vector3(0.03, -0.02, 0.05)
				_rifle.rotation_degrees = Vector3(-6, 95, 10)
		return
	match _pose:
		&"aim":
			_rifle.position = Vector3(0.12, 1.28, -0.22)
			_rifle.rotation = Vector3(-0.08, 0.0, 0.0)
		&"cover":
			_rifle.position = Vector3(0.18, 1.1, -0.05)
			_rifle.rotation = Vector3(0.4, 0.2, 0.1)
		_:
			_rifle.position = Vector3(0.22, 1.05, 0.02)
			_rifle.rotation = Vector3(0.85, 0.2, 0.15)
			if not moving and _pose == &"idle":
				_rifle.visible = true

func _build_limbs_no_rifle() -> void:
	_leg_l = _limb("LegL", Vector3(-0.12, 0.55, 0.0), Vector3(0.14, 0.7, 0.16), Color(0.2, 0.18, 0.14))
	_leg_r = _limb("LegR", Vector3(0.12, 0.55, 0.0), Vector3(0.14, 0.7, 0.16), Color(0.2, 0.18, 0.14))
	_arm_l = _limb("ArmL", Vector3(-0.28, 1.35, 0.0), Vector3(0.11, 0.55, 0.12), Color(0.55, 0.45, 0.32))
	_arm_r = _limb("ArmR", Vector3(0.28, 1.35, 0.0), Vector3(0.11, 0.55, 0.12), Color(0.55, 0.45, 0.32))

func _build_limbs() -> void:
	# 给无骨骼的身体挂上可摆动的四肢与步枪，做出突击动作。
	_build_limbs_no_rifle()
	_build_rifle_only()
	if _rifle:
		_rifle.visible = false

func _limb(limb_name: String, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = limb_name
	root.position = pos
	_mesh.add_child(root)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = Vector3(0, -size.y * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mi.material_override = mat
	root.add_child(mi)
	return root

func _apply_limbs(moving: bool, crouched: bool, speed: float) -> void:
	var hop := 0.0
	var lean := 0.0
	if _pose == &"cover":
		lean = 0.35 * _cover_side
		_mesh.rotation.y = lean
		_mesh.position.y = _base_y + 0.02
	elif _pose == &"jump":
		hop = 0.08
		_mesh.position.y = _base_y + hop
		_mesh.rotation.x = -0.12
	else:
		_mesh.rotation.x = 0.22 if crouched else 0.0
		if moving:
			hop = absf(sin(_step)) * (0.05 if _pose == &"run" else 0.035)
		_mesh.position.y = _base_y + hop
	if _leg_l and _leg_r:
		var swing := sin(_step) * (0.55 if _pose == &"run" else 0.38) if moving else 0.0
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		if crouched:
			_leg_l.rotation.x += 0.55
			_leg_r.rotation.x += 0.55
	if _arm_l and _arm_r:
		if _pose == &"aim":
			_arm_r.rotation = Vector3(-1.15, 0.15, -0.2)
			_arm_l.rotation = Vector3(-1.05, -0.25, 0.35)
			if _rifle:
				_rifle.visible = true
				_rifle.position = Vector3(0.12, 1.28, -0.22)
				_rifle.rotation = Vector3(-0.08, 0.0, 0.0)
		elif _pose == &"cover":
			_arm_r.rotation = Vector3(-0.6, 0.4, -0.2)
			_arm_l.rotation = Vector3(-0.4, -0.3, 0.25)
			if _rifle:
				_rifle.visible = true
				_rifle.position = Vector3(0.18, 1.1, -0.05)
				_rifle.rotation = Vector3(0.4, 0.2, 0.1)
		else:
			var arm_swing := sin(_step) * (0.45 if _pose == &"run" else 0.28) if moving else 0.0
			_arm_l.rotation = Vector3(-arm_swing, 0, 0.08)
			_arm_r.rotation = Vector3(arm_swing, 0, -0.08)
			if _rifle:
				_rifle.visible = moving or _pose == &"idle"
				_rifle.position = Vector3(0.22, 1.05, 0.02)
				_rifle.rotation = Vector3(0.85, 0.2, 0.15)

func _drive(moving: bool, crouched: bool) -> void:
	# Prefer simple canonical names (Idle/Walk/Run/Aim/Crouch/Jump/Death) so
	# retargeted clips work out of the box; fall back to Lux3D/Mixamo long names.
	if _fire_left > 0.0:
		# 开火窗内保持射击/瞄准轨，不让 walk 盖掉
		var fire_clip := _first_clip(["Shoot", "Pistol_Shoot", "Aim", "Pistol_Aim_Neutral"])
		if fire_clip != "" and _anim.current_animation != fire_clip:
			_anim.play(fire_clip)
		return
	var clip := ""
	if _pose == &"dead":
		clip = _first_clip(["Death",  "Death01",         "Dead"])
	elif _pose == &"aim":
		clip = _first_clip(["Aim",    "Pistol_Aim_Neutral"])
	elif _pose == &"jump":
		clip = _first_clip(["Jump",   "Jump_Loop"])
	elif _pose == &"run":
		clip = _first_clip(["Run", "Jog_Fwd_Loop", "Sprint_Loop", "Jog"])
	elif moving and crouched:
		clip = _first_clip(["CrouchWalk", "Crouch_Fwd_Loop", "Crouch", "Crouch_Idle_Loop"])
	elif crouched or _pose == &"cover":
		clip = _first_clip(["Crouch", "Crouch_Idle_Loop", "Cover"])
	elif moving:
		clip = _first_clip(["Walk", "Walk_Loop"])
	elif _phase == "talk":
		clip = _first_clip(["Idle_Talking_Loop", "Idle_Talk"])
	elif _phase == "nod":
		clip = _first_clip(["Yes",    "Nod"])
	elif _phase == "work" and _is_villager():
		clip = _first_clip(["Farm_Harvest", "Work", "Harvest"])
	# Default idle fallback
	if clip == "":
		clip = _first_clip(["Idle", "Idle_Loop"])
	# Last resort: first available clip
	if clip == "":
		var list := _anim.get_animation_list()
		if list.size() > 0:
			clip = list[0]
	if clip != "" and _anim.current_animation != clip:
		_anim.play(clip)

func _ease_head(delta: float) -> void:
	_phase_left -= delta
	if _phase_left > 0.0:
		return
	if _phase == "hold":
		var roll := randf()
		if roll < 0.4:
			_phase = "nod"
		elif roll < 0.75:
			_phase = "talk"
		else:
			_phase = "work" if _is_villager() else "nod"
		_phase_left = randf_range(1.6, 2.6)
		if _head >= 0:
			var turn := Quaternion(Vector3.UP, deg_to_rad(randf_range(-12.0, 12.0)))
			_skel.set_bone_pose_rotation(_head, _head_rest * turn)
		return
	_phase = "hold"
	_phase_left = randf_range(4.5, 8.5)
	if _head >= 0:
		_skel.set_bone_pose_rotation(_head, _head_rest)

func _is_villager() -> bool:
	var body := get_parent()
	return body != null and body.is_in_group("villagers")

func _ease_yaw(delta: float) -> void:
	if _pose == &"cover" or _pose == &"aim" or _pose == &"dead":
		return
	_phase_left -= delta
	if _phase == "hold" and _phase_left <= 0.0:
		_phase = "turn"
		_yaw_from = _yaw
		_yaw_to = deg_to_rad(randf_range(-14.0, 14.0))
		_phase_left = 0.7
	elif _phase == "turn" and _phase_left <= 0.0:
		_phase = "back"
		_yaw_from = _yaw
		_yaw_to = 0.0
		_phase_left = 0.8
	elif _phase == "back" and _phase_left <= 0.0:
		_phase = "hold"
		_phase_left = randf_range(6.0, 11.0)
		_yaw = 0.0
	var duration := 0.7 if _phase == "turn" else 0.8
	if _phase == "turn" or _phase == "back":
		var t := 1.0 - clampf(_phase_left / duration, 0.0, 1.0)
		_yaw = lerpf(_yaw_from, _yaw_to, t)
	_mesh.rotation.y = _yaw

func _has(anim_name: String) -> bool:
	return _anim != null and _anim.has_animation(anim_name)

func _soften(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			return
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				var copy := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.roughness = maxf(copy.roughness, 0.9)
				copy.metallic = 0.0
				copy.metallic_specular = 0.12
				(node as MeshInstance3D).set_surface_override_material(s, copy)
	for child in node.get_children():
		_soften(child)

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
