extends SceneTree

const Copy = preload("res://scripts/ui/narrative_copy.gd")
const FrameScript = preload("res://scripts/ui/narrative_frame.gd")
## godot --headless --path . -s res://tests/narrative_ui_test.gd
## 检查旁白边界，以及入口画面在几种宽度下不溢出、打开时有焦点。

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 960)]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	_check_copy(errors)
	for size in SIZES:
		await _check_layout(size, errors)
	if errors.is_empty():
		print("NARRATIVE UI PASSED")
		quit(0)
	else:
		for err in errors:
			push_error(err)
		print("NARRATIVE UI FAILED: %d" % errors.size())
		quit(1)

func _check_copy(errors: Array[String]) -> void:
	var joined := "\n".join([
		Copy.TITLE,
		Copy.PLACE,
		"\n".join(Copy.HISTORY),
		Copy.TASK,
		Copy.FOOT,
		Copy.SOURCE,
	])
	if not joined.contains("一九四二") or not joined.contains("清苑") or not Copy.TITLE.contains("冉庄"):
		errors.append("时间或地点没有写明")
	if not Copy.TASK.contains("夹壁") or not Copy.TASK.contains("隔板"):
		errors.append("任务没有写明藏身和挡水")
	if joined.contains("WASD") or joined.contains("胜利条件") or joined.contains("玩家"):
		errors.append("旁白写成了操作说明")
	if joined.contains("各小组注意"):
		errors.append("误用了电影台词")
	if Copy.TASK.contains("十六公里"):
		errors.append("把全村长度写成了这一座院子")
	if not Copy.SOURCE.contains("十六公里") or not Copy.SOURCE.contains("不是"):
		errors.append("全村长度没有和这一局分开")
	if Copy.is_silent(0) == false or Copy.is_silent(1):
		errors.append("留白没有落在扫荡那一句")
	var win := Copy.outcome_title(&"VICTORY", "敌军全部消灭")
	var lost := Copy.outcome_title(&"DEFEAT", "两名村民被捕")
	if win.contains("胜利") or lost.contains("失败") or win == lost:
		errors.append("结算仍是游戏胜负标题")
	if Copy.outcome_mark(&"VICTORY") == Copy.outcome_mark(&"DEFEAT"):
		errors.append("胜负只靠颜色区分")

func _check_layout(size: Vector2i, errors: Array[String]) -> void:
	var vp := SubViewport.new()
	vp.size = size
	root.add_child(vp)
	var frame = FrameScript.new()
	vp.add_child(frame)
	await process_frame
	await process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	if vp.gui_get_focus_owner() == null:
		errors.append("入口在 %s 没有焦点" % size)
	for node in frame.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is ScrollContainer:
			continue
		if not screen.encloses(control.get_global_rect()):
			errors.append("%s 在 %s 超出画面 %s" % [frame.get_path_to(control), size, control.get_global_rect()])
	frame.show_result(&"VICTORY", "敌军全部消灭")
	await process_frame
	await process_frame
	if vp.gui_get_focus_owner() == null:
		errors.append("结算在 %s 没有焦点" % size)
	for node in frame.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not screen.encloses(control.get_global_rect()):
			errors.append("结算 %s 在 %s 超出画面 %s" % [frame.get_path_to(control), size, control.get_global_rect()])
	var body := ""
	for node in frame.find_children("*", "Label", true, false):
		body += (node as Label).text
	if not body.contains("守住了") or not body.contains("进夹壁"):
		errors.append("结算文案不完整")
	vp.free()
