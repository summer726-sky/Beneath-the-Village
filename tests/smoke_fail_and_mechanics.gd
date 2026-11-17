extends SceneTree
## 失败条件 + 机关冒烟：godot --headless --path . -s res://tests/smoke_fail_and_mechanics.gd

func _init() -> void:
	call_deferred("_run")

func _bs() -> Node:
	return root.get_node("BattleState")

func _run() -> void:
	var errors: Array[String] = []
	print("=== MECHANICS / FAIL SMOKE START ===")

	# --- Case A: 两名村民被捕失败 ---
	var packed: PackedScene = load("res://scenes/main/main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var bs := _bs()
	var bell := scene.find_child("AlarmBell", true, false)
	if bell and bell.has_method("interact"):
		bell.interact(scene.get_node("Player"))
	await process_frame

	var captured := 0
	for v in get_nodes_in_group("villagers"):
		if v.has_method("_capture"):
			v.call("_capture")
			captured += 1
			await process_frame
			if captured >= 2:
				break
	await create_timer(0.3).timeout
	if not bool(bs.get("battle_over")):
		errors.append("两村民被捕后未失败结算")
	elif str(bs.get("result")) != "DEFEAT":
		errors.append("结果应为 DEFEAT，实际 %s" % str(bs.get("result")))
	scene.queue_free()
	await process_frame
	bs.call("reset")

	# --- Case B: 翻板只触发一次 ---
	scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	bs = _bs()
	var trap := scene.find_child("FlipTrap", true, false)
	var enemy: Node = null
	for e in get_nodes_in_group("enemies"):
		if str(e.get("role")) == "rifleman":
			enemy = e
			break
	if trap == null or enemy == null:
		errors.append("缺少翻板或步枪手")
	else:
		(enemy as Node3D).global_position = (trap as Node3D).global_position + Vector3(0.6, 0.1, 0)
		await process_frame
		if trap.has_method("arm"):
			trap.call("arm")
		if trap.has_method("try_trigger_from"):
			var first: bool = trap.call("try_trigger_from", enemy)
			var second: bool = false
			# 换另一个还活着的敌再踩
			for e2 in get_nodes_in_group("enemies"):
				if e2 != enemy and e2.has_method("is_alive") and e2.is_alive():
					second = trap.call("try_trigger_from", e2)
					break
			if not first:
				errors.append("翻板首次应触发")
			if second:
				errors.append("翻板第二次不应触发")
			if not bool(bs.get("trap_sprung")):
				errors.append("trap_sprung 未置位")
	scene.queue_free()
	await process_frame
	bs.call("reset")

	# --- Case C: 挡水阻止灌水失败路径被取消 ---
	scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	bs = _bs()
	var eb := root.get_node("EventBus")
	eb.emit_signal("water_started")
	await process_frame
	var barrier := scene.find_child("WaterBarrier", true, false)
	if barrier and barrier.has_method("interact"):
		barrier.interact(scene.get_node("Player"))
	await process_frame
	if not bool(bs.get("water_barrier_closed")):
		errors.append("隔板未关闭")
	# 灌水进度不应导致进水
	bs.set("water_progress", 1.0)
	await create_timer(0.4).timeout
	if bool(bs.get("bunker_flooded")):
		errors.append("隔板关闭后不应进水")

	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("=== MECHANICS / FAIL SMOKE PASSED ===")
		quit(0)
	else:
		print("=== MECHANICS / FAIL SMOKE FAILED ===")
		for e in errors:
			print("FAIL: ", e)
		quit(1)
