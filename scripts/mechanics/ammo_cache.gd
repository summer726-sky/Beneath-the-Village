extends Area3D
class_name AmmoCache
## 地道弹药暗室：每次补充有上限，库存打光后不能再取。离开一段距离后才能再补。

var _locked: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ammo_cache")

func _process(_delta: float) -> void:
	if not _locked:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and global_position.distance_to(player.global_position) > 3.2:
		_locked = false

func get_interact_hint() -> String:
	if BattleState.ammo_cache_stock <= 0:
		return "弹药暗室已空"
	if _locked:
		return "这次已取过，先离开暗室再来"
	return "E 补充弹药（每次最多 %d 发，暗室剩 %d）" % [BattleState.AMMO_RESUPPLY_CAP, BattleState.ammo_cache_stock]

func interact(_by: Node) -> void:
	if BattleState.player_ammo >= BattleState.player_max_ammo:
		EventBus.status_message.emit("身上弹药已满。", 2.0)
		return
	if BattleState.ammo_cache_stock <= 0:
		EventBus.status_message.emit("暗室弹药已经取完。", 2.2)
		return
	if _locked:
		EventBus.status_message.emit("这次已经补充过。离开暗室后再来。", 2.2)
		return
	var need := BattleState.player_max_ammo - BattleState.player_ammo
	var amount := mini(BattleState.AMMO_RESUPPLY_CAP, mini(need, BattleState.ammo_cache_stock))
	BattleState.player_ammo += amount
	BattleState.ammo_cache_stock -= amount
	_locked = true
	BattleState.log_event("暗室补充弹药 %d，剩余库存 %d" % [amount, BattleState.ammo_cache_stock])
	EventBus.status_message.emit("补充 %d 发。身上 %d，暗室还剩 %d。" % [amount, BattleState.player_ammo, BattleState.ammo_cache_stock], 3.0)
