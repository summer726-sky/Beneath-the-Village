extends CanvasLayer
class_name GameHUD

const FrameScript = preload("res://scripts/ui/narrative_frame.gd")
const BedScript = preload("res://scripts/ui/narrative_bed.gd")

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
var _f12_latched: bool = false
var _frame
var _bed

func _ready() -> void:
	EventBus.interactable_hint.connect(_on_hint)
	EventBus.status_message.connect(_on_message)
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
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			message_label.text = ""
	var covering := false
	if _frame != null and _frame.has_method("is_covering"):
		covering = _frame.is_covering()
	if _crosshair():
		_crosshair().visible = not covering
	if Input.is_action_just_pressed("toggle_overview") and not covering:
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

func _mount_narrative() -> void:
	_bed = BedScript.new()
	add_child(_bed)
	_frame = FrameScript.new()
	_frame.history_hush.connect(_bed.hush)
	_frame.entered_lookout.connect(_on_start)
	_frame.entered_yard.connect(_on_explore)
	_frame.restart_requested.connect(_on_restart)
	$Root.add_child(_frame)

func _crosshair() -> CanvasItem:
	return $Root.get_node_or_null("Crosshair") as CanvasItem

func _update_hud() -> void:
	ammo_label.text = "弹药 %d/%d  暗室 %d" % [BattleState.player_ammo, BattleState.player_max_ammo, BattleState.ammo_cache_stock]
	lives_label.text = "生命 %d" % BattleState.player_lives
	morale_label.text = "剩余敌军 %d" % BattleState.enemies_alive
	villagers_label.text = "村民 安全%d / 被捕%d / 共%d" % [
		BattleState.villagers_safe, BattleState.villagers_captured, BattleState.villagers_total
	]
	allies_label.text = "战友存活 %d" % BattleState.allies_alive
	if BattleState.exploring:
		objective_label.text = "探索中。地道是封死的。E 交谈。按 B 回到树洞开始警戒。"
	elif BattleState.phase == BattleState.Phase.OBSERVE:
		objective_label.text = "你在树洞里。地面火力很密。E 进地道回东屋拉钟，先让村民躲进北房。"
	elif BattleState.phase == BattleState.Phase.COMBAT:
		objective_label.text = "保护村民。敌军会进地道搜查。用地道打，直到全部消灭。"

func _on_hint(text: String) -> void:
	hint_label.text = text

func _on_message(text: String, duration: float) -> void:
	message_label.text = text
	_msg_timer = duration

func _fill_overview() -> void:
	overview_text.text = "\n".join([
		"—— 战场概况 ——",
		"阶段：%s" % str(BattleState.phase),
		"敌军存活：%d  分队长：%s" % [
			BattleState.enemies_alive,
			"在" if BattleState.commander_alive else "亡"
		],
		"村民：安全 %d / 被捕 %d" % [BattleState.villagers_safe, BattleState.villagers_captured],
		"战友存活：%d" % BattleState.allies_alive,
		"",
		"胜利：敌军全部消灭",
		"失败：两村民被捕 / 掩体进水 / 团灭",
		"注意：单纯隐蔽或搜索超时不算胜利。"
	])

func _on_battle_ended(result: StringName, reason: StringName) -> void:
	result_panel.visible = false
	overview_panel.visible = false
	intro_panel.visible = false
	if _bed:
		_bed.fade_out()
	if _frame:
		_frame.show_result(result, str(reason))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_restart() -> void:
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
