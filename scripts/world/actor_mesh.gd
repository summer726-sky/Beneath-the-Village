extends RefCounted
class_name ActorMesh
## 把生成的人物网格放到胶囊脚下。碰撞仍由调用方负责。

const _AnimBank := preload("res://scripts/world/anim_bank.gd")

static func place(parent: Node3D, glb_path: String, height: float, tint: Color = Color.WHITE) -> Node3D:
	if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
		return null
	var packed := load(glb_path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	inst.name = "BodyMesh"
	parent.add_child(inst)
	var bounds := _bounds(inst)
	if bounds.size.y < 0.02:
		inst.queue_free()
		return null
	var s := height / bounds.size.y
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(0.0, -bounds.position.y * s, 0.0)
	if tint != Color.WHITE:
		_tint(inst, tint)
	# 先并动作库，再 bind，避免开局空 AnimationPlayer
	_AnimBank.attach_for_mesh(inst, glb_path)
	var life := Node.new()
	life.set_script(load("res://scripts/world/actor_life.gd"))
	life.name = "ActorLife"
	parent.add_child(life)
	if life.has_method("bind"):
		life.bind(inst)
	return inst


static func mark_down(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).material_override:
		(node as MeshInstance3D).material_override.albedo_color = Color(0.22, 0.2, 0.18)
		return
	if node is Node3D:
		var body := node as Node3D
		var tw := body.create_tween()
		tw.tween_property(body, "rotation:x", PI * 0.5, 0.35)
		tw.parallel().tween_property(body, "position:y", 0.15, 0.35)


static func _bounds(root: Node3D) -> AABB:
	var merged := AABB()
	var has := false
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var ab := mi.get_aabb()
			var to_root := root.global_transform.affine_inverse() * mi.global_transform
			for i in 8:
				var p: Vector3 = to_root * ab.get_endpoint(i)
				if not has:
					merged = AABB(p, Vector3.ZERO)
					has = true
				else:
					merged = merged.expand(p)
	return merged


static func _tint(root: Node, tint: Color) -> void:
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var base := mi.get_active_material(0)
			if base == null or not (base is StandardMaterial3D):
				continue
			var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = tint
			mi.set_surface_override_material(0, mat)
