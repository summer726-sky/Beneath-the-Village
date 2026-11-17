extends PanelContainer
class_name NarrativeFrame

const Copy = preload("res://scripts/ui/narrative_copy.gd")
## 入口与结算共用一帧：上半是年代和处境，下半是这一仗要做的事。
## 锚在全屏，文字放在居中的窄栏里，避免拉成一条横贯屏幕的说明。

signal history_hush(silent: bool)
signal entered_lookout
signal entered_yard
signal restart_requested

const INK := Color(0.91, 0.87, 0.78, 1.0)
const INK_DIM := Color(0.78, 0.73, 0.64, 1.0)
const PAPER := Color(0.055, 0.048, 0.04, 0.98)
const LINE := Color(0.62, 0.54, 0.42, 1.0)
const HOLD := 6.4

var _index := 0
var _hold := 0.0
var _showing_result := false
var _history: Label
var _intro_box: VBoxContainer
var _result_box: VBoxContainer
var _result_title: Label
var _result_mark: Label
var _result_body: Label
var _enter: Button
var _look: Button
var _again: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint_panel()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC"
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	var theme := Theme.new()
	theme.default_font = font
	self.theme = theme
	var margin := MarginContainer.new()
	margin.name = "SafeMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_safe_margins(margin)
	add_child(margin)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(640, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 0)
	center.add_child(column)

	_intro_box = _build_intro()
	_result_box = _build_result()
	_result_box.visible = false
	column.add_child(_intro_box)
	column.add_child(_result_box)

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
	_intro_box.visible = false
	_result_box.visible = true
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
	if _showing_result or not visible:
		return
	if _index >= Copy.HISTORY.size() - 1:
		return
	_hold += delta
	if _hold < HOLD:
		return
	_hold = 0.0
	_index += 1
	_crossfade_history(Copy.HISTORY[_index], Copy.is_silent(_index))


func _focus_enter() -> void:
	if _enter == null or _look == null or not is_inside_tree() or _showing_result:
		return
	_enter.focus_neighbor_right = _enter.get_path_to(_look)
	_look.focus_neighbor_left = _look.get_path_to(_enter)
	_enter.grab_focus()


func _focus_again() -> void:
	if _again:
		_again.grab_focus()


func _crossfade_history(next_text: String, silent: bool) -> void:
	var tween := create_tween()
	tween.tween_property(_history, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		_history.text = next_text
		history_hush.emit(silent)
	)
	tween.tween_property(_history, "modulate:a", 1.0, 0.5)


func _build_intro() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "IntroColumn"
	box.add_theme_constant_override("separation", 18)
	box.add_child(_label(Copy.TITLE, 46, INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_rule())
	box.add_child(_label(Copy.PLACE, 22, INK, HORIZONTAL_ALIGNMENT_CENTER))
	_history = _label("", 22, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_history.custom_minimum_size = Vector2(0, 108)
	box.add_child(_history)
	box.add_child(_spacer(28))
	var task := _label(Copy.TASK, 20, INK, HORIZONTAL_ALIGNMENT_CENTER)
	task.custom_minimum_size = Vector2(0, 96)
	box.add_child(task)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 28)
	_enter = _button(Copy.ENTER, true)
	_look = _button(Copy.LOOK, false)
	_enter.pressed.connect(func() -> void: entered_lookout.emit())
	_look.pressed.connect(func() -> void: entered_yard.emit())
	modes.add_child(_enter)
	modes.add_child(_look)
	box.add_child(modes)
	box.add_child(_label(Copy.FOOT, 18, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	return box


func _build_result() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "ResultColumn"
	box.add_theme_constant_override("separation", 14)
	_result_title = _label("", 34, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_result_mark = _label("", 20, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_result_title)
	box.add_child(_result_mark)
	box.add_child(_rule())
	_result_body = _label("", 18, INK, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_result_body)
	box.add_child(_spacer(12))
	_again = _button(Copy.AGAIN, true)
	_again.pressed.connect(func() -> void: restart_requested.emit())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_again)
	box.add_child(row)
	return box


func _paint_panel() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = PAPER
	add_theme_stylebox_override("panel", panel)


func _label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = LINE
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _spacer(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(196, 48)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	var normal := _button_box(primary, false)
	var hover := _button_box(primary, false)
	hover.bg_color = Color(0.16, 0.13, 0.10, 1.0)
	var focus := _button_box(true, true)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	return button


func _button_box(primary: bool, focused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.11, 0.095, 0.075, 1.0) if primary else Color(0.08, 0.07, 0.06, 1.0)
	box.border_color = Color(0.9, 0.82, 0.66, 1.0) if focused else LINE
	box.set_border_width_all(2 if focused else 1)
	box.set_content_margin_all(10)
	return box


func _apply_safe_margins(margin: MarginContainer) -> void:
	var left := 64
	var top := 36
	var right := 64
	var bottom := 28
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
