extends Area3D
class_name AlarmBell
## 警报钟：触发村民躲藏与敌军状态变化。

var rung: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("alarm_bell")
	monitoring = true

func get_interact_hint() -> String:
	if rung:
		return "警报已响起"
	return "E 敲响警报钟"

func get_hold_seconds() -> float:
	return 0.0

func interact(_by: Node) -> void:
	if BattleState.exploring:
		EventBus.status_message.emit("探索中。这口钟在院树下，开始警戒后再拉，村民才会隐蔽。", 3.2)
		return
	if rung:
		return
	rung = true
	EventBus.alarm_triggered.emit(true)
	BattleState.log_event("警报钟敲响")
