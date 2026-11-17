extends CanvasLayer
class_name GameHUD

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

func _ready() -> void:
	EventBus.interactable_hint.connect(_on_hint)
	EventBus.status_message.connect(_on_message)
	EventBus.battle_ended.connect(_on_battle_ended)
	restart_btn.pressed.connect(_on_restart)
	start_btn.pressed.connect(_on_start)
	explore_btn.pressed.connect(_on_explore)
	overview_panel.visible = false
	result_panel.visible = false
	intro_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	objective_label.text = "目标：保护村民 · 阻止灌水 · 击退敌军"
	_ensure_crosshair()
	_update_static_intro()

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
	if Input.is_action_just_pressed("toggle_overview") and not result_panel.visible and not intro_panel.visible:
		overview_panel.visible = not overview_panel.visible
		if overview_panel.visible:
			_fill_overview()
	if intro_panel.visible and Input.is_action_just_pressed("skip_intro"):
		_on_start()
	if Input.is_physical_key_pressed(KEY_F12) and not _f12_latched:
		_f12_latched = true
		_capture_screenshot()
	elif not Input.is_physical_key_pressed(KEY_F12):
		_f12_latched = false

func _update_static_intro() -> void:
	intro_text.text = "冀中平原·冉庄\n\n两个入口并列。探索：熟悉封闭地道，E 与村民、战友交谈。\n警戒：人在树洞里，朝东的缝看敌军。\n地道口藏在树洞、锅台、水井和东屋，地面没有敞口。\n探索时按 B，会钻进树洞并开始警戒。空格直接开始警戒。\n\nWASD · 鼠标 · E 交互 · G 喊话 · Q 战况"

func _update_hud() -> void:
	ammo_label.text = "弹药 %d/%d  暗室 %d" % [BattleState.player_ammo, BattleState.player_max_ammo, BattleState.ammo_cache_stock]
	lives_label.text = "生命 %d" % BattleState.player_lives
	morale_label.text = "敌军士气 %d" % BattleState.enemy_morale
	villagers_label.text = "村民 安全%d / 被捕%d / 共%d" % [
		BattleState.villagers_safe, BattleState.villagers_captured, BattleState.villagers_total
	]
	allies_label.text = "战友存活 %d" % BattleState.allies_alive
	if BattleState.water_started and not BattleState.water_barrier_closed:
		objective_label.text = "紧急：关闭挡水隔板！灌水进度 %.0f%%" % (BattleState.water_progress * 100.0)
	elif BattleState.exploring:
		objective_label.text = "探索中。地道是封死的。E 交谈。按 B 回到树洞开始警戒。"
	elif BattleState.phase == BattleState.Phase.OBSERVE:
		objective_label.text = "你在树洞里。看东边的敌军，E 进地道回东屋拉钟。"
	elif BattleState.phase == BattleState.Phase.COMBAT:
		objective_label.text = "村民隐蔽，战友已上阵地。G 近距离喊话，可能被听见。"

func _on_hint(text: String) -> void:
	hint_label.text = text

func _on_message(text: String, duration: float) -> void:
	message_label.text = text
	_msg_timer = duration

func _fill_overview() -> void:
	overview_text.text = "\n".join([
		"—— 战场概况 ——",
		"阶段：%s" % str(BattleState.phase),
		"敌军存活：%d  士气：%d  分队长：%s" % [
			BattleState.enemies_alive, BattleState.enemy_morale,
			"在" if BattleState.commander_alive else "亡"
		],
		"村民：安全 %d / 被捕 %d" % [BattleState.villagers_safe, BattleState.villagers_captured],
		"战友存活：%d" % BattleState.allies_alive,
		"警报：%s  翻板：%s  灌水：%s  隔板：%s" % [
			"已响" if BattleState.alarm_rung else "未响",
			"已触发" if BattleState.trap_sprung else "待命",
			"进行中" if BattleState.water_started else "未开始",
			"已关" if BattleState.water_barrier_closed else "开"
		],
		"",
		"胜利：全歼 / 士气破撤退 / 挡水守住掩体",
		"失败：两村民被捕 / 掩体进水 / 团灭",
		"注意：单纯隐蔽或搜索超时不算胜利。"
	])

func _on_battle_ended(result: StringName, reason: StringName) -> void:
	result_panel.visible = true
	overview_panel.visible = false
	intro_panel.visible = false
	if result == &"VICTORY":
		result_title.text = "胜利"
		result_title.modulate = Color(0.85, 0.9, 0.55)
	else:
		result_title.text = "失败"
		result_title.modulate = Color(0.9, 0.45, 0.35)
	result_reason.text = str(reason)
	result_log.text = "本局记录：\n" + "\n".join(BattleState.battle_log)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_restart() -> void:
	GameManager.restart()

func _on_start() -> void:
	intro_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.begin_play()

func _on_explore() -> void:
	intro_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.begin_explore()

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
