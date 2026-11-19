extends Control
class_name NarrativeFrame

const Copy = preload("res://scripts/ui/narrative_copy.gd")
## 字幕压在画面下沿，时间地点留在左上角。
## 参照《使命召唤 2》任务页和《战地 1》章节卡：不盖住场景，不做居中海报。

signal history_hush(silent: bool)
signal entered_lookout
signal entered_yard
signal restart_requested

const INK := Color(0.94, 0.93, 0.9, 1.0)
const INK_DIM := Color(0.82, 0.8, 0.74, 1.0)
const HOLD := 5.6

var _index := 0
var _hold := 0.0
var _showing_result := false
var _history: Label
var _intro_block: Control
var _result_block: Control
var _result_title: Label
var _result_mark: Label
var _result_body: Label
var _enter: Button
var _look: Button
var _again: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_font()
	add_child(_bottom_shade())

	var margin := MarginContainer.new()
	margin.name = "SafeMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_safe_margins(margin)
	add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_corner())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_intro_block = _build_intro()
	_result_block = _build_result()
	_result_block.visible = false
	column.add_child(_intro_block)
	column.add_child(_result_block)

	_history.text = Copy.HISTORY[0]
	history_hush.emit(Copy.is_silent(0))
	call_deferred("_focus_enter")


func is_intro() -> bool:
	return visible and not _showing_result


func is_covering() -> bool:
	return visible


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED


func show_result(result: StringName, reason: String) -> void:
	_showing_result = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	_intro_block.visible = false
	_result_block.visible = true
	_result_title.text = Copy.outcome_title(result, reason)
	_result_mark.text = Copy.outcome_mark(result)
	_result_body.text = "\n".join([
		Copy.record_text(),
		"",
		Copy.history_note(),
		"",
		Copy.SOURCE,
	])
	call_deferred("_focus_again")


func _process(delta: float) -> void:
	if not _showing_result and visible and _index < Copy.HISTORY.size() - 1:
		_hold += delta
		if _hold >= HOLD:
			_hold = 0.0
			_index += 1
			_crossfade_history(Copy.HISTORY[_index], Copy.is_silent(_index))
	_mark(_enter, Copy.ENTER)
	_mark(_look, Copy.LOOK)
	_mark(_again, Copy.AGAIN)


func _mark(button: Button, caption: String) -> void:
	if button == null or not button.visible:
		return
	var on := button.has_focus()
	button.text = ("▸  " if on else "    ") + caption


func _focus_enter() -> void:
	if _enter == null or _look == null or not is_inside_tree() or _showing_result:
		return
	_enter.focus_neighbor_bottom = _enter.get_path_to(_look)
	_look.focus_neighbor_top = _look.get_path_to(_enter)
	_enter.grab_focus()


func _focus_again() -> void:
	if _again:
		_again.grab_focus()


func _crossfade_history(next_text: String, silent: bool) -> void:
	var tween := create_tween()
	tween.tween_property(_history, "modulate:a", 0.0, 0.28)
	tween.tween_callback(func() -> void:
		_history.text = next_text
		history_hush.emit(silent)
	)
	tween.tween_property(_history, "modulate:a", 1.0, 0.35)


func _corner() -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label(Copy.PLACE, 20, INK, HORIZONTAL_ALIGNMENT_LEFT))
	return box


func _build_intro() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "IntroLines"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(680, 0)
	_history = _label("", 22, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_history.custom_minimum_size = Vector2(640, 48)
	box.add_child(_history)
	var task := _label(Copy.TASK, 20, INK, HORIZONTAL_ALIGNMENT_LEFT)
	task.custom_minimum_size = Vector2(640, 48)
	box.add_child(task)
	var rules := _label(Copy.RULES, 15, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	rules.custom_minimum_size = Vector2(700, 88)
	box.add_child(rules)
	_enter = _text_button(Copy.ENTER)
	_look = _text_button(Copy.LOOK)
	_enter.pressed.connect(func() -> void: entered_lookout.emit())
	_look.pressed.connect(func() -> void: entered_yard.emit())
	box.add_child(_enter)
	box.add_child(_look)
	return box


func _build_result() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "ResultLines"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(720, 0)
	_result_title = _label("", 28, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_result_mark = _label("", 18, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_result_body = _label("", 18, INK, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_result_title)
	box.add_child(_result_mark)
	box.add_child(_result_body)
	_again = _text_button(Copy.AGAIN)
	_again.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(_again)
	return box


func _label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 3)
	return label


func _text_button(caption: String) -> Button:
	var button := Button.new()
	button.text = "    " + caption
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(280, 34)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 1)
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(2)
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	return button


func _bottom_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.28),
		Color(0, 0, 0, 0.62),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 256
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rect.offset_top = -300
	rect.offset_bottom = 0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	return rect


func _apply_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC"
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	var theme := Theme.new()
	theme.default_font = font
	self.theme = theme


func _apply_safe_margins(margin: MarginContainer) -> void:
	var left := 48
	var top := 36
	var right := 64
	var bottom := 32
	var win_size := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win_size.x > 0 and safe.size.x > 0 and safe.size.y > 0:
		var win := Rect2(DisplayServer.window_get_position(), win_size)
		var inner := Rect2(safe).intersection(win)
		if inner.size.x > 8.0 and inner.size.y > 8.0:
			var to_ui := get_viewport_rect().size / win.size
			left = maxi(left, int((inner.position.x - win.position.x) * to_ui.x))
			top = maxi(top, int((inner.position.y - win.position.y) * to_ui.y))
			right = maxi(right, int((win.end.x - inner.end.x) * to_ui.x))
			bottom = maxi(bottom, int((win.end.y - inner.end.y) * to_ui.y))
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
