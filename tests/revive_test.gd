extends SceneTree
## 地面被击倒后，应蹲姿出现在指挥室，锁定结束后恢复操作。

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	print("=== REVIVE TEST START ===")
	var packed: PackedScene = load("res://scenes/main/main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var gm := root.get_node("GameManager")
	var bs := root.get_node("BattleState")
	var player := scene.get_node("Player")
	gm.call("begin_play")
	await physics_frame
	await physics_frame
	if player.has_method("take_damage"):
		player.take_damage(1)
	else:
		errors.append("玩家不能受伤")
	await create_timer(3.0).timeout
	for _i in 20:
		await physics_frame
	var pos: Vector3 = player.global_position
	if pos.distance_to(Vector3(8.2, pos.y, -2.2)) > 1.3:
		errors.append("复活点不在指挥室 %s" % pos)
	if pos.y < -4.3 or pos.y > -3.2:
		errors.append("复活高度异常 y=%.2f" % pos.y)
	if int(bs.get("player_lives")) != 2:
		errors.append("复活后生命应为 2，实际 %s" % str(bs.get("player_lives")))
	if not bool(bs.get("player_alive")):
		errors.append("复活后仍标记为死亡")
	var col := player.get_node_or_null("CollisionShape3D")
	if col and col.shape is CapsuleShape3D:
		var h := (col.shape as CapsuleShape3D).height
		if h > 1.2:
			errors.append("指挥室里仍是站立身高 %.2f" % h)
	if int(bs.get("player_ammo")) > 4:
		errors.append("复活后弹药应减半，实际 %s" % str(bs.get("player_ammo")))
	await create_timer(6.4).timeout
	if not bool(bs.get("player_can_control")):
		errors.append("锁定结束后不能操作")
	if bool(bs.get("battle_over")):
		errors.append("一次阵亡不应结束战斗")
	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("=== REVIVE TEST PASSED ===")
		quit(0)
	else:
		print("=== REVIVE TEST FAILED ===")
		for e in errors:
			print("FAIL: ", e)
		quit(1)
