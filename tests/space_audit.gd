extends SceneTree
## 站位视线要能偏转，地道开口不能通向虚空。
## godot --headless --path . -s res://tests/space_audit.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	print("=== SPACE AUDIT START ===")
	var packed: PackedScene = load("res://scenes/main/main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	for _i in 6:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var eye := -2.865
	# 地面观察：正视、左右 12 度、上仰约 8 度都要看出去
	_need(space, errors, "树缝", Vector3(15.35, 1.445, 0.0), Vector3(1, 0, 0), 4.0)
	_need(space, errors, "墙缝", Vector3(9.5, 1.445, 1.65), Vector3(1, 0, 0), 4.0)
	_need(space, errors, "锅台", Vector3(-13.05, 1.445, 3.85), Vector3(1, 0, 0), 3.0)
	_need(space, errors, "门槛", Vector3(1.16, 1.445, 1.2), Vector3(-1, 0, 0), 2.5)
	# 地道枪眼：要打进通道，而不是打在自己的墙上
	_need(space, errors, "直道枪眼", Vector3(-3.55, eye, -0.96), Vector3(0, 0, 1), 1.15)
	_need(space, errors, "死道枪眼", Vector3(1.12, eye, -2.84), Vector3(1, 0, 0), 1.15)
	_need(space, errors, "侧龛枪眼", Vector3(2.15, eye, 1.58), Vector3(0, 0, -1), 1.15)
	# 开口方向：北侧不能漏风，南侧才能进枪眼
	_walled(space, errors, "直道北墙", Vector3(-5.0, eye, 0.15), Vector3(0, 0, 1), 1.3)
	_walled(space, errors, "跳口侧洞南墙", Vector3(4.2, eye, 0.0), Vector3(0, 0, -1), 1.3)
	_reach(space, errors, "井到驴槽", Vector3(-10.0, eye, -4.2), Vector3(1, 0, 0), 1.6)
	_walled(space, errors, "死道尽头", Vector3(2.6, eye, -6.6), Vector3(0, 0, -1), 1.2)
	_reach(space, errors, "死道有长度", Vector3(2.6, eye, -3.6), Vector3(0, 0, -1), 2.4)
	_walled(space, errors, "树洞以东死路", Vector3(17.5, eye, 0.0), Vector3(1, 0, 0), 2.2)
	_walled(space, errors, "坡道北侧", Vector3(6.2, -1.6, 2.35), Vector3(0, 0, 1), 1.0)
	_walled(space, errors, "暗室西侧", Vector3(7.2, -1.5, 1.4), Vector3(-1, 0, 0), 1.2)
	_walled(space, errors, "跳口西壁", Vector3(7.2, -1.5, 0.2), Vector3(-1, 0, 0), 1.2)
	_walled(space, errors, "跳口东壁", Vector3(7.2, -1.5, 0.2), Vector3(1, 0, 0), 1.2)
	_walled(space, errors, "井口西侧", Vector3(-10.0, eye, -4.2), Vector3(-1, 0, 0), 1.2)
	_reach(space, errors, "侧洞能上去", Vector3(4.25, eye, 0.4), Vector3(0, 0, 1), 0.8)
	_walled(space, errors, "侧洞不漏北", Vector3(4.25, eye, 1.5), Vector3(0, 0, 1), 1.6)
	if errors.is_empty():
		print("=== SPACE AUDIT PASSED ===")
		quit(0)
	else:
		for e in errors:
			print("FAIL ", e)
		quit(1)

func _need(space: PhysicsDirectSpaceState3D, errors: Array[String], label: String, eye: Vector3, aim: Vector3, minimum: float) -> void:
	var center := _cast(space, eye, aim * 12.0)
	var left := _cast(space, eye, aim.rotated(Vector3.UP, deg_to_rad(12.0)) * 8.0)
	var right := _cast(space, eye, aim.rotated(Vector3.UP, deg_to_rad(-12.0)) * 8.0)
	var up := _cast(space, eye, (aim + Vector3(0, 0.14, 0)).normalized() * 8.0)
	print("%s center %.2f yaw %.2f/%.2f up %.2f" % [label, center, left, right, up])
	if center < minimum or left < minimum or right < minimum or up < minimum * 0.75:
		errors.append("%s 视线不够 center %.2f yaw %.2f/%.2f up %.2f" % [label, center, left, right, up])

func _walled(space: PhysicsDirectSpaceState3D, errors: Array[String], label: String, origin: Vector3, dir: Vector3, limit: float) -> void:
	var dist := _cast(space, origin, dir * 8.0)
	print("%s wall %.2f" % [label, dist])
	if dist > limit:
		errors.append("%s 漏到 %.2f 米" % [label, dist])

func _reach(space: PhysicsDirectSpaceState3D, errors: Array[String], label: String, origin: Vector3, dir: Vector3, minimum: float) -> void:
	var dist := _cast(space, origin, dir * 8.0)
	print("%s reach %.2f" % [label, dist])
	if dist < minimum:
		errors.append("%s 被挡住 %.2f" % [label, dist])

func _cast(space: PhysicsDirectSpaceState3D, origin: Vector3, travel: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + travel)
	query.collide_with_areas = false
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return travel.length()
	return origin.distance_to(hit.position)
