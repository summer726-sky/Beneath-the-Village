extends Control
class_name LevelMap
## 右上角分层简图。北朝上，玩家用一个会转向的标记。
## 底图是院子和地道的固定形状。不读取敌军、村民、战友的位置，也不留移动轨迹。

const PAPER := Color(0.08, 0.07, 0.06, 0.94)
const INK := Color(0.86, 0.82, 0.74, 0.95)
const HOUSE := Color(0.42, 0.36, 0.3, 0.95)
const YARD := Color(0.28, 0.24, 0.18, 0.9)
const PASSAGE := Color(0.62, 0.56, 0.46, 0.95)
const EXIT_C := Color(0.93, 0.9, 0.82, 1.0)
const GEAR_C := Color(0.78, 0.62, 0.38, 1.0)
const PLAYER_C := Color(0.96, 0.94, 0.88, 1.0)

var _surf_x := Vector2(-17.0, 34.0)
var _surf_z := Vector2(-11.0, 16.0)
var _tun_x := Vector2(-24.0, 28.0)
var _tun_z := Vector2(-9.0, 15.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -208
	offset_top = 12
	offset_right = -12
	offset_bottom = 176


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var state = _state()
	var underground: bool = state.player_in_tunnel
	draw_rect(Rect2(Vector2.ZERO, size), PAPER, true)
	draw_rect(Rect2(Vector2.ZERO, size), INK, false, 1.0)
	var caption := "地道" if underground else "地面"
	draw_string(ThemeDB.fallback_font, Vector2(8, 16), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 22, 16), "北", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	if underground:
		_draw_tunnel()
	else:
		_draw_surface()
	_draw_player()


func _draw_surface() -> void:
	_fill_world(Rect2(Vector2(-12.2, -6.4), Vector2(12.6, 12.0)), YARD)
	_fill_house(Vector3(-6.2, 0, 7.65), Vector2(15.6, 4.5))
	_fill_house(Vector3(-6.2, 0, -8.15), Vector2(15.6, 3.5))
	_fill_house(Vector3(-14.15, 0, 0.2), Vector2(3.5, 11.2))
	_fill_house(Vector3(2.7, 0, 0.15), Vector2(4.4, 4.6))
	_fill_house(Vector3(4.7, 0, 8.6), Vector2(4.0, 3.2))
	_fill_house(Vector3(5.9, 0, -5.9), Vector2(3.8, 3.4))
	_fill_world(Rect2(Vector2(9.85, -6.2), Vector2(0.7, 12.4)), HOUSE)
	_exit(-6.4, 2.3, "钟")
	_exit(-10.0, -3.6, "井")
	_exit(-4.2, -4.2, "槽")
	_exit(2.6, 0.15, "东屋")
	_exit(-6.2, 7.2, "北房")
	_exit(-6.2, 7.9, "藏身")
	_exit(22.0, 0.0, "树缝")
	var note := _to_map(18.2, -9.2)
	draw_string(ThemeDB.fallback_font, note + Vector2(-28, 0), "东", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)


func _draw_tunnel() -> void:
	# 主廊与现有灰盒一致（含西外廊、北窖、拉雷岔）
	_passage(Vector2(-10.0, 0.1), Vector2(26.2, 0.1))
	_passage(Vector2(-10.0, 0.0), Vector2(-22.0, 0.0))
	_passage(Vector2(-22.0, 0.0), Vector2(-22.0, -1.4))
	_passage(Vector2(14.2, -0.2), Vector2(14.2, -4.15))
	_passage(Vector2(11.0, -4.15), Vector2(14.2, -4.15))
	_passage(Vector2(2.6, 0.15), Vector2(2.6, -7.2))
	_passage(Vector2(-10.0, 0.0), Vector2(-10.0, -7.2))
	_passage(Vector2(-9.6, -4.2), Vector2(-3.4, -4.2))
	_passage(Vector2(-6.2, 0.2), Vector2(-6.2, 7.5))
	_passage(Vector2(-6.2, 8.4), Vector2(-6.2, 14.0))
	_passage(Vector2(-6.2, 3.95), Vector2(-8.5, 3.95))
	_passage(Vector2(8.2, 0.0), Vector2(8.2, -2.2))
	_passage(Vector2(2.6, 0.15), Vector2(2.6, 2.4))
	_fill_world(Rect2(Vector2(-1.25, -3.9), Vector2(2.8, 2.55)), PASSAGE)
	_exit(22.0, 0.0, "")
	_exit(2.6, 0.15, "")
	_exit(-10.0, -3.6, "")
	_exit(-6.2, 7.2, "")
	_exit(-4.2, -4.2, "")
	_exit(-22.0, -1.4, "")
	_exit(-6.2, 14.0, "")
	_gear(-10.0, -1.8, "隔板")
	_gear(-4.2, -4.2, "翻板")
	_gear(-18.2, 0.0, "翻板")
	_gear(-8.2, 3.95, "拉雷")
	_gear(2.6, -1.0, "翻口")
	_gear(-6.2, 6.45, "翻眼")
	_gear(8.2, -2.3, "弹药")
	_gear(-6.2, 7.5, "藏身")
	_gear(20.5, 0.0, "卡口")
	_gear(-14.5, 0.0, "卡口")
	var key_at := Vector2(8, size.y - 6)
	draw_string(ThemeDB.fallback_font, key_at, "圈 出口    方 机关/藏身", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)


func _draw_player() -> void:
	var pos: Vector3 = _state().player_position
	var at := _to_map(pos.x, pos.z)
	var plot := _plot()
	at.x = clampf(at.x, plot.position.x + 6.0, plot.end.x - 6.0)
	at.y = clampf(at.y, plot.position.y + 6.0, plot.end.y - 6.0)
	var facing := _player_forward()
	var ang := atan2(facing.x, facing.y)
	draw_set_transform(at, ang)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -7),
		Vector2(4.5, 5.5),
		Vector2(-4.5, 5.5),
	]), PLAYER_C)
	draw_set_transform(Vector2.ZERO, 0.0)


func _player_forward() -> Vector2:
	if not is_inside_tree():
		return Vector2(0, 1)
	var body := get_tree().get_first_node_in_group("player")
	if body is Node3D:
		var forward := -(body as Node3D).global_transform.basis.z
		if forward.length_squared() > 0.001:
			return Vector2(forward.x, forward.z)
	return Vector2(0, 1)


func _fill_house(c: Vector3, fp: Vector2) -> void:
	_fill_world(Rect2(Vector2(c.x - fp.x * 0.5, c.z - fp.y * 0.5), fp), HOUSE)


func _fill_world(rect: Rect2, color: Color) -> void:
	var tl := _to_map(rect.position.x, rect.position.y + rect.size.y)
	var br := _to_map(rect.end.x, rect.position.y)
	draw_rect(Rect2(tl, br - tl), color, true)


func _passage(a: Vector2, b: Vector2) -> void:
	draw_line(_to_map(a.x, a.y), _to_map(b.x, b.y), PASSAGE, 7.0, true)


func _exit(x: float, z: float, caption: String) -> void:
	var at := _to_map(x, z)
	draw_arc(at, 4.5, 0, TAU, 16, EXIT_C, 1.4, true)
	if caption != "":
		draw_string(ThemeDB.fallback_font, at + Vector2(6, 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)


func _gear(x: float, z: float, caption: String) -> void:
	var at := _to_map(x, z)
	draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), GEAR_C, true)
	draw_string(ThemeDB.fallback_font, at + Vector2(6, 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)


func _plot() -> Rect2:
	return Rect2(8, 22, size.x - 16, size.y - 36)


func _bounds() -> Vector4:
	if _state().player_in_tunnel:
		return Vector4(_tun_x.x, _tun_x.y, _tun_z.x, _tun_z.y)
	return Vector4(_surf_x.x, _surf_x.y, _surf_z.x, _surf_z.y)


func _state() -> Object:
	return Engine.get_main_loop().root.get_node("BattleState")


func _to_map(x: float, z: float) -> Vector2:
	var plot := _plot()
	var b := _bounds()
	var u := (x - b.x) / maxf(b.y - b.x, 0.001)
	var v := (z - b.z) / maxf(b.w - b.z, 0.001)
	return plot.position + Vector2(u * plot.size.x, (1.0 - v) * plot.size.y)
