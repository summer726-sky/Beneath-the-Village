extends SceneTree
## godot --headless --path . -s res://tests/level_map_test.gd

const MapScript = preload("res://scripts/ui/level_map.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	var src := FileAccess.get_file_as_string("res://scripts/ui/level_map.gd")
	for word in ["enemies", "villagers", "allies", "battle_log"]:
		if src.contains(word):
			errors.append("地图读取了不该出现的对象：%s" % word)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	root.add_child(vp)
	var layer := CanvasLayer.new()
	vp.add_child(layer)
	var chart = MapScript.new()
	layer.add_child(chart)
	await process_frame
	await process_frame
	chart.size = Vector2(196, 164)
	var state = root.get_node("BattleState")
	state.player_in_tunnel = false
	state.player_position = Vector3(-6.4, 0.2, 2.0)
	var north: Vector2 = chart._to_map(-6.2, 7.65)
	var south: Vector2 = chart._to_map(-6.2, -8.15)
	var west: Vector2 = chart._to_map(-14.0, 0.0)
	var east: Vector2 = chart._to_map(15.2, 0.0)
	if north.y >= south.y:
		errors.append("北房没有画在南房上方")
	if west.x >= east.x:
		errors.append("树缝没有画在西房右边")
	var yard: Vector2 = chart._to_map(-6.4, 2.0)
	var plot: Rect2 = chart._plot()
	if not plot.grow(-2).has_point(yard):
		errors.append("院中的点落在图外")
	state.player_in_tunnel = true
	state.player_position = Vector3(-10.0, -3.8, -1.8)
	var barrier: Vector2 = chart._to_map(-10.0, -1.8)
	if not plot.grow(-2).has_point(barrier):
		errors.append("隔板落在地道图外")
	var west_flip: Vector2 = chart._to_map(-18.2, 0.0)
	if not plot.grow(-2).has_point(west_flip):
		errors.append("西廊翻板落在地道图外")
	var seal: Vector2 = chart._to_map(-6.2, 6.45)
	if not plot.grow(-2).has_point(seal):
		errors.append("翻眼门落在地道图外")
	var src2 := FileAccess.get_file_as_string("res://scripts/ui/level_map.gd")
	if not src2.contains("6.45"):
		errors.append("地图翻眼坐标未对齐暗室口")
	if not src2.contains("-18.2"):
		errors.append("地图缺少西廊翻板")
	if errors.is_empty():
		print("LEVEL MAP PASSED")
		quit(0)
		return
	for err in errors:
		push_error(err)
	print("LEVEL MAP FAILED %d" % errors.size())
	quit(1)
