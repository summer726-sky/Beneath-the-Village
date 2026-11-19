extends CanvasLayer
class_name GameHUD

const FrameScript = preload("res://scripts/ui/narrative_frame.gd")
const BedScript = preload("res://scripts/ui/narrative_bed.gd")
const MapScript = preload("res://scripts/ui/level_map.gd")
const PauseScript = preload("res://scripts/ui/pause_menu.gd")

@onready var ammo_label: Label = $Root/TopLeft/Ammo
@onready var lives_label: Label = $Root/TopLeft/Lives
@onready var morale_label: Label = $Root/TopLeft/Morale
@onready var villagers_label: Label = $Root/TopLeft/Villagers
@onready var allies_label: Label = $Root/TopLeft/Allies
@onready var objective_label: Label = $Root/TopCenter/Objective
@onready var hint_label: Label = $Root/BottomCenter/Hint
@onready var message_label: Label = $Root/BottomCenter/Message
@onready var overview_panel: PanelContainer = $Root/Overview
@onready var overview_text: Label = $Root/Overview/Margin/OverviewText
@onready var result_panel: PanelContainer = $Root/Result
@onready var result_title: Label = $Root/Result/Margin/VBox/Title
@onready var result_reason: Label = $Root/Result/Margin/VBox/Reason
@onready var result_log: Label = $Root/Result/Margin/VBox/Log
@onready var restart_btn: Button = $Root/Result/Margin/VBox/Restart
@onready var intro_panel: PanelContainer = $Root/Intro
@onready var intro_text: Label = $Root/Intro/Margin/VBox/IntroText
@onready var start_btn: Button = $Root/Intro/Margin/VBox/Modes/StartBtn
@onready var explore_btn: Button = $Root/Intro/Margin/VBox/Modes/ExploreBtn

var _msg_timer: float = 0.0
var _speech_left: float = 0.0
var _dim: ColorRect
var _f12_latched: bool = false
var _frame
var _bed
var _map
var _pause
var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.interactable_hint.connect(_on_hint)
	EventBus.status_message.connect(_on_message)
	EventBus.speech_line.connect(_on_speech)
	EventBus.player_died.connect(_on_hurt)
	EventBus.battle_ended.connect(_on_battle_ended)
	restart_btn.pressed.connect(_on_restart)
	start_btn.pressed.connect(_on_start)
	explore_btn.pressed.connect(_on_explore)
	overview_panel.visible = false
	result_panel.visible = false
	intro_panel.visible = false
	intro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_btn.focus_mode = Control.FOCUS_NONE
	explore_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.focus_mode = Control.FOCUS_NONE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	objective_label.text = "钟还没响。人还在院子里。"
	_ensure_crosshair()
	_mount_narrative()
	_mount_pause()

func _ensure_crosshair() -> void:
	if $Root.get_node_or_null("Crosshair"):
		return
	var cross := Label.new()
	cross.name = "Crosshair"
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 22)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-8, -12)
	$Root.add_child(cross)

func _process(delta: float) -> void:
	_update_hud()
	if _speech_left > 0.0:
		_speech_left -= delta
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			message_label.text = ""
	var covering := false
	if _frame != null and _frame.has_method("is_covering"):
		covering = _frame.is_covering()
	if _crosshair():
		_crosshair().visible = not covering
	for node_name in ["TopLeft", "TopCenter", "BottomCenter"]:
		var bit := $Root.get_node_or_null(node_name) as CanvasItem
		if bit:
			bit.visible = not covering
	var leave := _leave_hint()
	if leave:
		leave.visible = GameManager.flow == GameManager.FlowState.PLAYING and not covering and not _paused
	if _map:
		_map.visible = not covering and not _paused
	if Input.is_action_just_pressed("toggle_overview") and not covering and not _paused:
		overview_panel.visible = not overview_panel.visible
		if overview_panel.visible:
			_fill_overview()
	if _frame and _frame.is_intro() and Input.is_action_just_pressed("skip_intro"):
		_on_start()
	if Input.is_physical_key_pressed(KEY_F12) and not _f12_latched:
		_f12_latched = true
		_capture_screenshot()
	elif not Input.is_physical_key_pressed(KEY_F12):
		_f12_latched = false

func _mount_pause() -> void:
	_pause = PauseScript.new()
	_pause.name = "PauseMenu"
	$Root.add_child(_pause)
	_pause.resume_requested.connect(_resume_game)
	_pause.restart_requested.connect(_on_pause_restart)
	_pause.quit_requested.connect(_quit_game)

func _mount_narrative() -> void:
	_bed = BedScript.new()
	add_child(_bed)
	_frame = FrameScript.new()
	_frame.history_hush.connect(_bed.hush)
	_frame.entered_lookout.connect(_on_start)
	_frame.entered_yard.connect(_on_explore)
	_frame.restart_requested.connect(_on_restart)
	$Root.add_child(_frame)
	_map = MapScript.new()
	$Root.add_child(_map)
	_mount_leave()

func _mount_leave() -> void:
	var leave := Label.new()
	leave.name = "LeaveExplore"
	leave.text = "Esc    暂停"
	leave.visible = false
	leave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leave.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	leave.offset_left = 36
	leave.offset_top = -44
	leave.offset_right = 280
	leave.offset_bottom = -16
	leave.add_theme_font_size_override("font_size", 18)
	leave.add_theme_color_override("font_color", Color(0.94, 0.93, 0.9, 0.92))
	leave.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	leave.add_theme_constant_override("shadow_offset_x", 1)
	leave.add_theme_constant_override("shadow_offset_y", 1)
	leave.add_theme_constant_override("shadow_outline_size", 3)
	$Root.add_child(leave)

func _leave_hint() -> Label:
	return $Root.get_node_or_null("LeaveExplore") as Label

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.physical_keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if _paused:
		_resume_game()
		return
	if BattleState.battle_over or (_frame and _frame.is_covering()):
		return
	if GameManager.flow != GameManager.FlowState.PLAYING:
		return
	_open_pause()

func _open_pause() -> void:
	if _paused:
		return
	_paused = true
	overview_panel.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _pause:
		_pause.show_for_mode(BattleState.exploring)

func _resume_game() -> void:
	if not _paused:
		return
	_paused = false
	if _pause:
		_pause.hide_menu()
	get_tree().paused = false
	if GameManager.flow == GameManager.FlowState.PLAYING and not BattleState.battle_over:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_pause_restart() -> void:
	_paused = false
	if _pause:
		_pause.hide_menu()
	get_tree().paused = false
	GameManager.restart()

func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()

func _crosshair() -> CanvasItem:
	return $Root.get_node_or_null("Crosshair") as CanvasItem

func _update_hud() -> void:
	ammo_label.text = "弹药 %d/%d  暗室 %d" % [BattleState.player_ammo, BattleState.player_max_ammo, BattleState.ammo_cache_stock]
	lives_label.text = "生命 %d" % BattleState.player_lives
	morale_label.text = "剩余敌军 %d" % BattleState.enemies_alive
	# 「已进洞」= 警报后成功躲进暗室的人数；开局为 0 表示还没人隐蔽，不是人在地道里
	villagers_label.text = "村民 已进洞%d / 押走%d / 遇害%d / 共%d" % [
		BattleState.villagers_safe, BattleState.villagers_transferred, BattleState.villagers_killed, BattleState.villagers_total
	]
	allies_label.text = "战友存活 %d" % BattleState.allies_alive
	if BattleState.exploring:
		objective_label.text = "地图探索。E 交谈。B 进入正式游戏（树洞）。"
	elif BattleState.phase == BattleState.Phase.OBSERVE:
		objective_label.text = "你在树洞里。地面火力很密。E 进地道回东屋拉钟，先让村民躲进北房。"
	elif BattleState.phase == BattleState.Phase.COMBAT:
		objective_label.text = "保护村民。敌军会进地道搜查。用地道打，直到全部消灭。"

func _on_hint(text: String) -> void:
	hint_label.text = text

func _on_speech(text: String, duration: float) -> void:
	message_label.text = text
	_msg_timer = duration
	_speech_left = duration

func _on_message(text: String, duration: float) -> void:
	var critical := "被捕" in text or "进水" in text or "复活" in text or "倒下" in text
	if _speech_left > 0.2 and not critical:
		return
	message_label.text = text
	_msg_timer = duration

func _on_hurt(_lives: int) -> void:
	if _dim == null:
		_dim = ColorRect.new()
		_dim.color = Color(0.02, 0.015, 0.01, 0.0)
		_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Root.add_child(_dim)
	_dim.color.a = 0.45
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 0.0, 0.4)

func _fill_overview() -> void:
	overview_text.text = "\n".join([
		"—— 战场概况 ——",
		"阶段：%s" % str(BattleState.phase),
		"敌军存活：%d  分队长：%s" % [
			BattleState.enemies_alive,
			"在" if BattleState.commander_alive else "亡"
		],
		"村民：已进洞 %d / 押到树 %d / 遇害 %d（开局未进洞属正常）" % [
			BattleState.villagers_safe, BattleState.villagers_transferred, BattleState.villagers_killed
		],
		"战友存活：%d" % BattleState.allies_alive,
		"",
		"成功：消灭全部敌军",
		"失败：两村民押到瞭望树 / 两村民被杀 / 掩体进水 / 团灭",
		"藏身：关隔板后不淹的暗室；地图标「藏身」；翻眼关闭更安全",
		"人质：可冒险开枪救人，未击毙押送者则人质遇害",
		"战友：走近听策略；F 派任务；不派则自行配合",
		"右上角：分层地图。Q：概况。Esc：暂停（继续 / 回开头 / 退出）。"
	])

func _on_battle_ended(result: StringName, reason: StringName) -> void:
	if _paused:
		_resume_game()
	result_panel.visible = false
	overview_panel.visible = false
	intro_panel.visible = false
	if _bed:
		_bed.fade_out()
	if _frame:
		_frame.show_result(result, str(reason))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_restart() -> void:
	if _paused:
		_paused = false
		if _pause:
			_pause.hide_menu()
		get_tree().paused = false
	GameManager.restart()

func _on_start() -> void:
	_leave_narrative()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.begin_play()

func _on_explore() -> void:
	_leave_narrative()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.begin_explore()

func _leave_narrative() -> void:
	intro_panel.visible = false
	if _frame:
		_frame.close()
	if _bed:
		_bed.fade_out()

func _capture_screenshot() -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var dir := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/shot_%d.png" % [dir, Time.get_unix_time_from_system()]
	var err := img.save_png(path)
	if err == OK:
		EventBus.status_message.emit("截图已保存：%s" % path, 2.0)
		print("Screenshot: ", path)
	else:
		push_warning("Screenshot failed: %s" % err)
