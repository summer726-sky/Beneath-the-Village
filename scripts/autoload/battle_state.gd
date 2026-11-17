extends Node
## 本局运行时状态。由 BattleManager / GameManager 写入，UI 与 AI 只读。

enum Phase { INTRO, EXPLORE, BRIEFING, OBSERVE, COMBAT, RESULT }

var phase: Phase = Phase.INTRO
var exploring: bool = false

# 玩家
var player_lives: int = 3  # 首次 + 两次额外
var player_ammo: int = 8
var player_max_ammo: int = 8
var ammo_cache_stock: int = 16
const AMMO_RESUPPLY_CAP := 4
var player_alive: bool = true
var player_can_control: bool = false
var player_invulnerable_until: float = 0.0
var player_position: Vector3 = Vector3.ZERO
var player_in_tunnel: bool = false
var player_in_lookout: bool = false
var lookout_exposed: bool = false
var player_at_firing_port: bool = false
var firing_port_id: StringName = &""
var firing_port_expose_time: float = 0.0

# 士气与敌军
var enemy_morale: int = 4
const MORALE_MAX := 4
var enemies_alive: int = 4
var commander_alive: bool = true
var enemies_retreated: bool = false

# 村民 / 战友
var villagers_safe: int = 0
var villagers_captured: int = 0
var villagers_total: int = 3
var allies_alive: int = 2

# 机关 / 灌水
var alarm_rung: bool = false
var trap_sprung: bool = false
var water_started: bool = false
var water_barrier_closed: bool = false
var bunker_flooded: bool = false
var water_progress: float = 0.0  # 0..1
const WATER_DURATION := 25.0

# 结算
var battle_over: bool = false
var result: StringName = &""
var result_reason: StringName = &""
var battle_log: Array[String] = []

func reset() -> void:
	phase = Phase.INTRO
	exploring = false
	player_lives = 3
	player_ammo = 8
	player_max_ammo = 8
	ammo_cache_stock = 16
	player_alive = true
	player_can_control = false
	player_invulnerable_until = 0.0
	player_position = Vector3.ZERO
	player_in_tunnel = false
	player_in_lookout = false
	lookout_exposed = false
	player_at_firing_port = false
	firing_port_id = &""
	firing_port_expose_time = 0.0
	enemy_morale = MORALE_MAX
	enemies_alive = 4
	commander_alive = true
	enemies_retreated = false
	villagers_safe = 0
	villagers_captured = 0
	villagers_total = 3
	allies_alive = 2
	alarm_rung = false
	trap_sprung = false
	water_started = false
	water_barrier_closed = false
	bunker_flooded = false
	water_progress = 0.0
	battle_over = false
	result = &""
	result_reason = &""
	battle_log.clear()

func log_event(msg: String) -> void:
	battle_log.append(msg)
	print("[Battle] ", msg)

func villagers_alive() -> int:
	return villagers_total - villagers_captured
