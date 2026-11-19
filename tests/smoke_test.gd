extends SceneTree
## 用法: godot --headless --path . -s res://tests/smoke_test.gd
## 注意：-s 模式下不使用 Autoload 全局名，改为 /root 节点访问。

func _init() -> void:
	call_deferred("_run")

func _bs() -> Node:
	return root.get_node("BattleState")

func _run() -> void:
	var errors: Array[String] = []
	print("=== SMOKE TEST START ===")

	var packed: PackedScene = load("res://scenes/main/main.tscn")
	if packed == null:
		errors.append("无法加载 main.tscn")
		_finish(errors)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var bs := _bs()
	if int(bs.get("player_lives")) != 3:
		errors.append("初始生命应为 3，实际 %s" % str(bs.get("player_lives")))
	if int(bs.get("enemy_morale")) != 4:
		errors.append("初始士气应为 4")
	if int(bs.get("enemies_alive")) != 12:
		errors.append("敌军数量应为 12")

	if scene.get_node_or_null("Player") == null:
		errors.append("缺少 Player")

	var enemies := get_nodes_in_group("enemies")
	if enemies.size() != 12:
		errors.append("敌军 group 数量=%d" % enemies.size())
	if get_nodes_in_group("villagers").size() != 3:
		errors.append("村民数量异常")
	if get_nodes_in_group("allies").size() != 2:
		errors.append("战友数量异常")

	var bell := scene.find_child("AlarmBell", true, false)
	if bell == null:
		errors.append("缺少 AlarmBell")
	elif bell.has_method("interact"):
		bell.interact(scene.get_node("Player"))
		await process_frame
		await process_frame
		if not bool(bs.get("alarm_rung")):
			errors.append("警报未置位")

	for e in enemies:
		if e.has_method("is_alive") and e.is_alive() and e.has_method("take_damage"):
			e.take_damage(1)
			await process_frame
	await create_timer(0.5).timeout

	if int(bs.get("enemies_alive")) > 0:
		errors.append("击杀后敌军存活=%s" % str(bs.get("enemies_alive")))
	if not bool(bs.get("battle_over")):
		errors.append("全歼后未结束战斗 result=%s" % str(bs.get("result")))
	elif str(bs.get("result")) != "VICTORY":
		errors.append("全歼结果应为 VICTORY，实际 %s" % str(bs.get("result")))

	if bs.has_method("reset"):
		bs.call("reset")
		if int(bs.get("enemy_morale")) != 4 or bool(bs.get("battle_over")):
			errors.append("BattleState.reset 失败")

	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("=== SMOKE TEST PASSED ===")
		quit(0)
	else:
		print("=== SMOKE TEST FAILED ===")
		for e in errors:
			print("FAIL: ", e)
		quit(1)
