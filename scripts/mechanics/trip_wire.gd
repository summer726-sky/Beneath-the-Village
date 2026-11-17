extends Area3D
## 拉雷：拉线之后只有敌军绊发。不挡玩家。

var armed: bool = false
var sprung: bool = false

func _ready() -> void:
	add_to_group("trip_wire")
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)

func get_interact_hint() -> String:
	if sprung:
		return "拉雷已触发"
	if not armed:
		return "E 拉线。之后只有敌军绊上会响"
	return "线已拉开。从旁边过去"

func interact(_by: Node) -> void:
	if sprung or armed:
		return
	if not BattleState.alarm_rung and not BattleState.exploring:
		EventBus.status_message.emit("先拉响警报，再拉这根线。", 2.2)
		return
	armed = true

func try_trigger_from(body: Node3D) -> bool:
	return _attempt(body)

func _on_body_entered(body: Node) -> void:
	if body is Node3D:
		_attempt(body as Node3D)

func _attempt(body: Node3D) -> bool:
	if not armed or sprung:
		return false
	if not body.is_in_group("enemies"):
		return false
	sprung = true
	if body.has_method("take_damage"):
		body.take_damage(1, self)
	BattleState.log_event("拉雷触发")
	return true
