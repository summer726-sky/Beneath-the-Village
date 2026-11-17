extends Node
class_name BattleManager
## 战斗状态与胜负判定。NPC 不得自行结束游戏。

@export var water_flood_seconds: float = 25.0

func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.commander_killed.connect(_on_commander_killed)
	EventBus.trap_triggered.connect(_on_trap_triggered)
	EventBus.water_barrier_closed.connect(_on_water_barrier_closed)
	EventBus.villager_captured.connect(_on_villager_captured)
	EventBus.villager_entered_shelter.connect(_on_villager_sheltered)
	EventBus.alarm_triggered.connect(_on_alarm)
	EventBus.water_started.connect(_on_water_started)
	EventBus.player_died.connect(_on_player_died)
	EventBus.ally_died.connect(_on_ally_died)

func _process(delta: float) -> void:
	if BattleState.battle_over:
		return
	if BattleState.water_started and not BattleState.water_barrier_closed and not BattleState.bunker_flooded:
		BattleState.water_progress = minf(1.0, BattleState.water_progress + delta / water_flood_seconds)
		if BattleState.water_progress >= 1.0:
			BattleState.bunker_flooded = true
			BattleState.log_event("地下掩体进水")
			_fail(&"FLOOD", &"灌水完成，地下掩体进水")

func adjust_morale(delta_val: int, reason: String) -> void:
	if BattleState.battle_over or BattleState.enemies_retreated:
		return
	BattleState.enemy_morale = clampi(BattleState.enemy_morale + delta_val, 0, BattleState.MORALE_MAX)
	BattleState.log_event("士气 %+d（%s）→ %d" % [delta_val, reason, BattleState.enemy_morale])
	_check_retreat()

func _check_retreat() -> void:
	if BattleState.enemies_retreated or BattleState.battle_over:
		return
	var should_retreat := false
	var reason := &""
	if BattleState.enemy_morale <= 0:
		should_retreat = true
		reason = &"士气崩溃，敌军撤退"
	elif not BattleState.commander_alive and BattleState.enemies_alive < 2:
		should_retreat = true
		reason = &"分队长阵亡且残余不足，敌军撤退"
	if should_retreat:
		_trigger_retreat(reason)

func _trigger_retreat(reason: StringName) -> void:
	BattleState.enemies_retreated = true
	EventBus.enemy_retreated.emit()
	BattleState.log_event(str(reason))
	# 隐蔽本身不能胜利；撤退才算防护/战术成果
	if BattleState.villagers_captured >= 2:
		_fail(&"CAPTURE", &"两名村民被捕")
		return
	if BattleState.bunker_flooded:
		_fail(&"FLOOD", &"地下掩体进水")
		return
	var route := &"RETREAT"
	if BattleState.water_started and (BattleState.water_barrier_closed or not _engineer_alive()):
		if BattleState.villagers_alive() >= 2 and not BattleState.bunker_flooded:
			route = &"HOLD_BUNKER"
	_win(route, reason)

func _engineer_alive() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.has_method("get_role") and e.get_role() == &"engineer" and e.has_method("is_alive") and e.is_alive():
			return true
	return false

func _win(route: StringName, reason: StringName) -> void:
	if BattleState.battle_over:
		return
	GameManager.show_result(&"VICTORY", reason if reason != &"" else route)
	BattleState.log_event("胜利：%s" % reason)

func _fail(code: StringName, reason: StringName) -> void:
	if BattleState.battle_over:
		return
	GameManager.show_result(&"DEFEAT", reason)
	BattleState.log_event("失败：%s" % reason)

func check_annihilation_victory() -> void:
	if BattleState.enemies_alive <= 0 and not BattleState.battle_over:
		_win(&"ANNIHILATION", &"四名敌军全部消灭")

func _on_enemy_killed(enemy_id: StringName, role: StringName) -> void:
	BattleState.enemies_alive = maxi(0, BattleState.enemies_alive - 1)
	adjust_morale(-1, "敌军阵亡:%s" % role)
	if role == &"commander":
		BattleState.commander_alive = false
		EventBus.commander_killed.emit(enemy_id)
	check_annihilation_victory()
	_check_retreat()

func _on_commander_killed(_enemy_id: StringName) -> void:
	BattleState.commander_alive = false
	_check_retreat()

func _on_trap_triggered(_trap_id: StringName, _victim_id: StringName) -> void:
	if not BattleState.trap_sprung:
		BattleState.trap_sprung = true
	adjust_morale(-1, "翻板陷阱")

func _on_water_barrier_closed() -> void:
	BattleState.water_barrier_closed = true
	if BattleState.water_started:
		adjust_morale(-1, "挡水成功")

func _on_villager_captured(_villager_id: StringName) -> void:
	BattleState.villagers_captured += 1
	adjust_morale(1, "村民被捕")
	if BattleState.villagers_captured >= 2:
		_fail(&"CAPTURE", &"两名村民被捕")

func _on_villager_sheltered(_vid: StringName, _sid: StringName) -> void:
	BattleState.villagers_safe = mini(BattleState.villagers_total, BattleState.villagers_safe + 1)

func _on_alarm(_by_player: bool) -> void:
	BattleState.alarm_rung = true
	GameManager.enter_combat()

func _on_water_started() -> void:
	BattleState.water_started = true
	BattleState.water_progress = 0.0
	EventBus.status_message.emit("敌军开始灌水！尽快关闭挡水隔板或击倒工兵。", 5.0)

func _on_player_died(lives_remaining: int) -> void:
	if lives_remaining <= 0 and BattleState.allies_alive <= 0:
		_fail(&"WIPE", &"团灭：玩家与战友全部阵亡")

func _on_ally_died(_ally_id: StringName) -> void:
	BattleState.allies_alive = maxi(0, BattleState.allies_alive - 1)

## 击倒工兵：若灌水已开始且隔板未关，士气下降并可能撤退
func notify_engineer_down() -> void:
	if BattleState.water_started and not BattleState.water_barrier_closed:
		adjust_morale(-1, "工兵被击倒，灌水中断")
