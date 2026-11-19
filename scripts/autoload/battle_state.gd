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
var recon_exposed: bool = false
var player_at_firing_port: bool = false
var firing_port_id: StringName = &""
var firing_port_position: Vector3 = Vector3.ZERO
var firing_port_expose_time: float = 0.0

# 士气与敌军
var enemy_morale: int = 4
const MORALE_MAX := 4
var enemies_alive: int = 12
var commander_alive: bool = true
var enemies_retreated: bool = false

# 村民 / 战友
var villagers_safe: int = 0
var villagers_captured: int = 0  # 正在押送或已带走（含已转移）
var villagers_transferred: int = 0  # 已押到瞭望树
var villagers_killed: int = 0
var villagers_total: int = 3
var allies_alive: int = 2
const ENTRANCE_DISCOVER_CHANCE := 0.67
const TUNNEL_ENEMY_SPEED := 0.42  # 相对地表移速
const TUNNEL_ENEMY_HIT := 0.32
const VILLAGER_FLEE_SPEED := 2.05  # 略慢于敌军地表追击

# 机关 / 灌水
var alarm_rung: bool = false
var trap_sprung: bool = false
var trap_lethal: bool = true  # 翻板只杀第一个踩偏的敌军；之后敌军会踩中间木轴
var water_started: bool = false
var recon_counter_at: float = 0.0  # 树缝开枪后，到此时间三人开始反击
var water_barrier_closed: bool = false
var bunker_flooded: bool = false
var water_progress: float = 0.0  # 0..1
const WATER_DURATION := 25.0
## 对话互斥：同一时间只保留一条 speech，避免字重叠
var speech_busy_until: float = 0.0
const RECON_RUSH := 1.4  # 侦察树开枪后敌军加速倍率
## 进村预算：树洞→敲钟 + 村民躲好 + 3 秒；侧向入视野后再西进
const LOOKOUT_TO_BELL_SEC := 14.0
const VILLAGER_HIDE_SEC := 10.0
const ARRIVAL_BUFFER_SEC := 3.0
const ARRIVAL_BUDGET_SEC := LOOKOUT_TO_BELL_SEC + VILLAGER_HIDE_SEC + ARRIVAL_BUFFER_SEC  # 27
const SIDE_ENTER_MIN := 5.0
const SIDE_ENTER_MAX := 10.0
const APPROACH_BASE_SPEED := 0.55  # 侧向现身后西进；总耗时对齐 ARRIVAL_BUDGET
var enemy_reveal_at: float = 0.0  # 侧向进入侦察树视野的时刻

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
	recon_exposed = false
	player_at_firing_port = false
	firing_port_id = &""
	firing_port_position = Vector3.ZERO
	firing_port_expose_time = 0.0
	enemy_morale = MORALE_MAX
	enemies_alive = 12
	commander_alive = true
	enemies_retreated = false
	villagers_safe = 0
	villagers_captured = 0
	villagers_transferred = 0
	villagers_killed = 0
	villagers_total = 3
	allies_alive = 2
	alarm_rung = false
	trap_sprung = false
	trap_lethal = true
	water_started = false
	recon_counter_at = 0.0
	enemy_reveal_at = 0.0
	water_barrier_closed = false
	bunker_flooded = false
	water_progress = 0.0
	speech_busy_until = 0.0
	battle_over = false
	result = &""
	result_reason = &""
	battle_log.clear()

func log_event(msg: String) -> void:
	battle_log.append(msg)
	print("[Battle] ", msg)

func villagers_alive() -> int:
	return maxi(0, villagers_total - villagers_transferred - villagers_killed)

func now_sec() -> float:
	return Time.get_ticks_msec() * 0.001

func try_speech(text: String, duration: float = 2.4, force: bool = false) -> bool:
	if text.is_empty():
		return false
	var t := now_sec()
	if not force and t < speech_busy_until:
		return false
	speech_busy_until = t + duration
	EventBus.speech_line.emit(text, duration)
	return true
