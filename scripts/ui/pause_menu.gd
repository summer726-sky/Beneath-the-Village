extends PanelContainer
class_name PauseMenu
## Esc 暂停：探索与正式游戏共用。继续 / 回开头 / 退出。

signal resume_requested
signal restart_requested
signal quit_requested

var _resume_btn: Button
var _restart_btn: Button
var _quit_btn: Button
var _title: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(360, 260)
	offset_left = -180
	offset_top = -130
	offset_right = 180
	offset_bottom = 130
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.06, 0.05, 0.96)
	bg.border_color = Color(0.72, 0.66, 0.52, 0.85)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 18
	bg.content_margin_right = 18
	bg.content_margin_top = 16
	bg.content_margin_bottom = 16
	add_theme_stylebox_override("panel", bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_title = Label.new()
	_title.text = "暂停"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.94, 0.9, 0.8))
	box.add_child(_title)
	var tip := Label.new()
	tip.text = "Esc 也可继续"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	box.add_child(tip)
	_resume_btn = _make_btn("继续游戏")
	_restart_btn = _make_btn("回到开头")
	_quit_btn = _make_btn("退出游戏")
	box.add_child(_resume_btn)
	box.add_child(_restart_btn)
	box.add_child(_quit_btn)
	_resume_btn.pressed.connect(func() -> void: resume_requested.emit())
	_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	_quit_btn.pressed.connect(func() -> void: quit_requested.emit())


func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 40)
	return btn


func show_for_mode(exploring: bool) -> void:
	_title.text = "暂停 · 地图探索" if exploring else "暂停"
	_restart_btn.text = "回到开头" if exploring else "重新开始"
	visible = true


func hide_menu() -> void:
	visible = false
