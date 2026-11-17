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

	var tunnel_points: Array[Vector3] = [
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

	var y_drain := await _settle(probe, Vector3(-10.0, -5.05, -3.2), Vector3.ZERO, 30)
	if y_drain < -6.2 or y_drain > -4.8:
		errors.append("下层排水没有落点 y=%.2f" % y_drain)

	var surface_points: Array[Vector3] = [
		Vector3(-12.0, 0.4, 2.4),
		Vector3(-10.0, 0.4, -3.6),
		Vector3(2.4, 0.4, 0.0),
		Vector3(15.2, 0.4, 0.0),
	]
	for p in surface_points:
		var y3 := await _settle(probe, p, Vector3.ZERO, 30)
		if y3 < -1.0:
			errors.append("地面入口是敞口 %s y=%.2f" % [p, y3])

	var y_tree := await _settle(probe, Vector3(15.2, 0.4, 0.0), Vector3(3.2, 0, 0), 40)
	if y_tree < -1.0:
		errors.append("能从树洞东侧掉出去 y=%.2f" % y_tree)

	var gm := root.get_node("GameManager")
	var player := scene.get_node("Player") as Node3D
	gm.call("begin_play")
	await physics_frame
	await physics_frame
	if player.global_position.distance_to(Vector3(15.2, 0.2, 0.0)) > 0.6:
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
