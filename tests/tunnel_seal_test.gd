extends SceneTree
## 地道封闭、地面无敞口、探索/警戒出生点。
## godot --headless --path . -s res://tests/tunnel_seal_test.gd

class Probe extends CharacterBody3D:
	var push := Vector3.ZERO

	func _physics_process(delta: float) -> void:
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0.0
		velocity.x = push.x
		velocity.z = push.z
		move_and_slide()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	print("=== TUNNEL SEAL TEST START ===")
	var packed: PackedScene = load("res://scenes/main/main.tscn")
	if packed == null:
		_finish(["无法加载 main.tscn"])
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	for _i in 8:
		await physics_frame
	_check_opening(scene, errors, Vector3(22.0, 1.41, 0.0), Vector3(4, 0, 0), 1.2, true, "树缝")
	_check_opening(scene, errors, Vector3(22.0, 1.41, 0.3), Vector3(2, 0, 0), 0.85, false, "树缝旁边")
	_check_opening(scene, errors, Vector3(22.0, 0.5, 0.0), Vector3(2, 0, 0), 0.85, false, "树身下部")
	_check_opening(scene, errors, Vector3(21.1, 1.0, 0.0), Vector3(1.2, 0, 0), 0.7, false, "树的西侧")
	_check_opening(scene, errors, Vector3(9.35, 1.41, 1.65), Vector3(3, 0, 0), 1.6, true, "墙缝")
	_check_opening(scene, errors, Vector3(-13.25, 1.41, 3.85), Vector3(2.5, 0, 0), 1.2, true, "锅台枪眼")
	_check_opening(scene, errors, Vector3(1.25, 1.41, 1.2), Vector3(-2.2, 0, 0), 1.1, true, "门槛枪眼")
	_check_opening(scene, errors, Vector3(-3.55, -2.87, -1.15), Vector3(0, 0, 2.2), 0.9, true, "直道枪眼")
	_check_opening(scene, errors, Vector3(7.2, -1.55, 0.2), Vector3(0, 1.3, 0), 0.9, true, "跳口")
	_check_opening(scene, errors, Vector3(7.2, -1.55, 0.2), Vector3(0.42, 0, 0), 0.35, true, "跳口宽度")
	_check_opening(scene, errors, Vector3(4.25, -2.9, 1.15), Vector3(0.55, 0, 0), 0.45, true, "侧洞宽度")

	# 视觉封闭：走廊内仰视必须很快撞到顶板/覆土；俯视有地板；侧向有壁
	var shell_eyes: Array[Dictionary] = [
		{"p": Vector3(16.0, -2.9, 0.0), "side": Vector3(0, 0, 1)},
		{"p": Vector3(12.0, -2.9, 0.0), "side": Vector3(0, 0, -1)},
		{"p": Vector3(8.2, -2.9, -1.5), "side": Vector3(1, 0, 0)},
		{"p": Vector3(2.6, -2.9, 0.0), "side": Vector3(0, 0, 1)},
		{"p": Vector3(-6.2, -2.9, 0.0), "side": Vector3(0, 0, -1)},
		{"p": Vector3(-10.0, -2.9, -2.0), "side": Vector3(1, 0, 0)},
		{"p": Vector3(-14.5, -2.9, 0.0), "side": Vector3(0, 0, 1)},
		{"p": Vector3(-6.2, -2.9, 11.0), "side": Vector3(1, 0, 0)},
		{"p": Vector3(20.0, -2.9, 0.0), "side": Vector3(0, 0, 1)},
		{"p": Vector3(5.5, -2.9, 0.0), "side": Vector3(0, 0, -1)},
	]
	for item in shell_eyes:
		var eye: Vector3 = item["p"]
		_check_roof_seal(scene, errors, eye, "仰视封闭 %s" % eye)
		_check_shell_hit(scene, errors, eye, Vector3(0, -1, 0), 1.3, "地板 %s" % eye)
		_check_shell_hit(scene, errors, eye, item["side"], 1.4, "侧壁 %s" % eye)

	_check_tunnel_meshes_visible(scene, errors)

	var seal_board := scene.find_child("BoardClosed", true, false) as Node3D
	# 暗室门板应在藏身口；同名 BoardClosed 也可能是翻口——取 VillagerSeal 下的
	var seal := scene.find_child("VillagerSeal", true, false)
	if seal:
		seal_board = seal.find_child("BoardClosed", true, false) as Node3D
	if seal_board == null or absf(seal_board.global_position.z - 6.45) > 0.85:
		var sz := seal_board.global_position.z if seal_board else -999.0
		errors.append("暗室门位置异常 z=%.2f（应在暗室口约 6.45）" % sz)

	var probe := Probe.new()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.15
	col.shape = cap
	col.position.y = 0.58
	probe.add_child(col)
	probe.collision_layer = 32
	probe.collision_mask = 1
	scene.add_child(probe)

	# 北廊→拉雷龛必须能走进去（不被暗室门或岔墙挡在中段）
	var y_mine := await _settle(probe, Vector3(-6.2, -3.5, 2.2), Vector3(0, 0, 2.6), 50)
	if probe.global_position.z < 3.4 or y_mine < -5.0:
		errors.append("北廊走不到拉雷岔 z=%.2f y=%.2f" % [probe.global_position.z, y_mine])
	var y_nook := await _settle(probe, Vector3(-6.6, -3.5, 3.95), Vector3(-2.6, 0, 0), 55)
	if probe.global_position.x > -7.7 or y_nook < -5.0:
		errors.append("拉雷龛走不进去 x=%.2f y=%.2f" % [probe.global_position.x, y_nook])

	var tunnel_points: Array[Vector3] = [
		Vector3(22.0, -4.2, 0.0),
		Vector3(15.2, -4.2, 0.0),
		Vector3(12.0, -4.2, 0.0),
		Vector3(8.2, -4.2, 0.0),
		Vector3(8.2, -4.2, -2.2),
		Vector3(2.4, -4.2, 0.0),
		Vector3(-10.0, -4.2, 0.0),
		Vector3(-10.0, -4.2, -3.2),
	]
	for p in tunnel_points:
		var y := await _settle(probe, p, Vector3.ZERO, 25)
		if y < -6.0 or y > -3.2:
			errors.append("地道内掉出或浮空 %s y=%.2f" % [p, y])
		var shove := Vector3(0, 0, 3.2)
		if absf(p.x - 8.2) < 0.2 and absf(p.z) < 0.2:
			shove = Vector3(0, 0, 3.2)
		elif absf(p.x + 10.0) < 0.2 and absf(p.z) < 0.2:
			shove = Vector3(-3.2, 0, 0)
		elif absf(p.z) < 0.2:
			shove = Vector3(0, 0, 3.2)
		elif absf(p.z - 2.4) < 0.2:
			shove = Vector3(0, 0, 3.2)
		else:
			shove = Vector3(3.2, 0, 0)
		var y2 := await _settle(probe, p, shove, 40)
		if y2 < -6.0:
			errors.append("侧向走出地道 %s y=%.2f" % [p, y2])

	# 翻口默认挡住南死道
	var y_blocked := await _settle(probe, Vector3(2.6, -3.5, -0.3), Vector3(0, 0, -2.4), 40)
	if probe.global_position.z < -1.35:
		errors.append("翻口默认应挡住南死道，却走进了 z=%.2f" % probe.global_position.z)
	var mouth := scene.find_child("FlipMouthEast", true, false)
	if mouth and mouth.has_method("interact"):
		mouth.interact(probe)
		await physics_frame
		await physics_frame
	var y_dead := await _settle(probe, Vector3(2.6, -3.5, -0.3), Vector3(0, 0, -2.4), 50)
	if y_dead < -4.6 or probe.global_position.z > -1.6:
		errors.append("翻开后南边死路仍走不进去 y=%.2f z=%.2f" % [y_dead, probe.global_position.z])
	var stands: Array[Vector3] = [
		Vector3(-3.6, -3.5, -1.2),
		Vector3(1.05, -3.5, -2.9),
		Vector3(2.5, -3.5, 1.55),
	]
	for stand in stands:
		var y_stand := await _settle(probe, stand, Vector3.ZERO, 25)
		var slipped := Vector2(probe.global_position.x - stand.x, probe.global_position.z - stand.z).length()
		if y_stand < -4.6 or y_stand > -3.2 or slipped > 0.55:
			errors.append("枪眼站不住 %s -> %s y=%.2f" % [stand, probe.global_position, y_stand])
	var y_drain := await _settle(probe, Vector3(-10.0, -5.05, -3.2), Vector3.ZERO, 30)
	if y_drain < -6.2 or y_drain > -4.8:
		errors.append("下层排水没有落点 y=%.2f" % y_drain)

	var surface_points: Array[Vector3] = [
		Vector3(-12.0, 0.4, 2.4),
		Vector3(-10.0, 0.4, -3.6),
		Vector3(2.4, 0.4, 0.0),
		Vector3(22.0, 0.4, 0.0),
	]
	for p in surface_points:
		var y3 := await _settle(probe, p, Vector3.ZERO, 30)
		if y3 < -1.0:
			errors.append("地面入口是敞口 %s y=%.2f" % [p, y3])

	var y_tree := await _settle(probe, Vector3(22.0, 0.4, 0.0), Vector3(3.2, 0, 0), 40)
	if y_tree < -1.0:
		errors.append("能从树洞东侧掉出去 y=%.2f" % y_tree)

	var gm := root.get_node("GameManager")
	var player := scene.get_node("Player") as Node3D
	gm.call("begin_play")
	await physics_frame
	await physics_frame
	if player.global_position.distance_to(Vector3(22.0, 0.2, 0.0)) > 0.6:
		errors.append("警戒出生不在树洞 %s" % player.global_position)
	if bool(root.get_node("BattleState").get("exploring")):
		errors.append("警戒后仍在探索")
	var look := player.global_transform.basis.z
	if look.dot(Vector3(-1, 0, 0)) < 0.7:
		errors.append("树洞内没有朝东看敌军 look=%s" % look)

	gm.call("begin_explore")
	await physics_frame
	var enemy: Node3D = get_nodes_in_group("enemies")[0]
	var before := enemy.global_position
	for _i in 40:
		await physics_frame
	if enemy.global_position.distance_to(before) > 0.35:
		errors.append("探索时敌军仍在移动 %s -> %s" % [before, enemy.global_position])
	if player.global_position.distance_to(Vector3(-6.6, 0.25, 0.2)) > 1.2:
		errors.append("探索出生不在院子 %s" % player.global_position)

	probe.queue_free()
	_finish(errors)

func _check_opening(scene: Node, errors: Array[String], origin: Vector3, travel: Vector3, limit: float, should_pass: bool, label: String) -> void:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + travel)
	var hit: Dictionary = space.intersect_ray(query)
	var dist := travel.length()
	if not hit.is_empty():
		dist = origin.distance_to(hit.position)
	if should_pass and dist < limit:
		errors.append("%s被挡住，射线 %.2f 米" % [label, dist])
	elif not should_pass and dist > limit:
		errors.append("%s是敞口，射线 %.2f 米" % [label, dist])

func _check_roof_seal(scene: Node, errors: Array[String], eye: Vector3, label: String) -> void:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, 6.0, 0))
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		errors.append("%s：向上无碰撞，地表仍透空" % label)
		return
	var dist: float = eye.distance_to(hit.position)
	var hit_y: float = (hit.position as Vector3).y
	print("%s roof_hit dist=%.2f y=%.2f" % [label, dist, hit_y])
	# 洞内视高约 -2.9，顶板/覆土应在 ~ -2.1 … -0.1；不得穿到地面以上
	if dist > 2.6:
		errors.append("%s：顶封过远 %.2f 米（仍像透顶）" % [label, dist])
	if hit_y > -0.02:
		errors.append("%s：射线打到地面高度 y=%.2f，覆土未封" % [label, hit_y])

func _check_tunnel_meshes_visible(scene: Node, errors: Array[String]) -> void:
	var world := scene.get_node_or_null("World")
	if world == null:
		errors.append("缺少 World 节点，无法检查地道网格可见性")
		return
	var hidden: Array[String] = []
	var checked := 0
	for child in world.get_children():
		if not (child is StaticBody3D):
			continue
		var n := str(child.name)
		var shell := n.begins_with("CF") or n.begins_with("CL") or n.begins_with("CR") or n.begins_with("CC")
		shell = shell or n.begins_with("OF") or n.begins_with("OS") or n.begins_with("ON") or n.begins_with("OC")
		shell = shell or n.begins_with("HubF") or n.begins_with("HubC")
		if not shell:
			continue
		checked += 1
		for mesh_child in child.get_children():
			if mesh_child is MeshInstance3D and not (mesh_child as MeshInstance3D).visible:
				hidden.append(n)
				break
	print("tunnel_mesh_check checked=%d hidden=%d" % [checked, hidden.size()])
	if checked < 20:
		errors.append("走廊壳网格过少 checked=%d（生成异常）" % checked)
	if not hidden.is_empty():
		errors.append("走廊壳被隐藏：%s" % ", ".join(hidden.slice(0, mini(8, hidden.size()))))

func _check_shell_hit(scene: Node, errors: Array[String], eye: Vector3, dir: Vector3, limit: float, label: String) -> void:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var travel := dir.normalized() * 3.0
	var query := PhysicsRayQueryParameters3D.create(eye, eye + travel)
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		errors.append("%s：无碰撞（缺地板或侧壁）" % label)
		return
	var dist: float = eye.distance_to(hit.position)
	print("%s shell_hit dist=%.2f" % [label, dist])
	if dist > limit:
		errors.append("%s：过远 %.2f 米（该段缺壳）" % [label, dist])

func _settle(probe: Probe, pos: Vector3, push: Vector3, frames: int) -> float:
	probe.global_position = pos
	probe.velocity = Vector3.ZERO
	probe.push = push
	for _i in frames:
		await physics_frame
	return probe.global_position.y

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("=== TUNNEL SEAL TEST PASSED ===")
		quit(0)
	else:
		print("=== TUNNEL SEAL TEST FAILED ===")
		for e in errors:
			print("FAIL: ", e)
		quit(1)
