extends StaticBody3D
class_name WaterBarrier
## 挡水隔板：按住交互约 1 秒关闭。

var closed: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("water_barrier")

func get_interact_hint() -> String:
	if closed:
		return "挡水隔板已关闭"
	if BattleState.water_started:
		return "按住 E 关闭挡水隔板（阻止灌水）"
	return "按住 E 关闭挡水隔板"

func get_hold_seconds() -> float:
	return 0.0 if closed else 1.0

func interact(_by: Node) -> void:
	if closed:
		return
	closed = true
	BattleState.water_barrier_closed = true
	EventBus.water_barrier_closed.emit()
	BattleState.log_event("挡水隔板关闭")
	var mesh := get_node_or_null("Visual") as MeshInstance3D
	if mesh:
		mesh.position.y -= 0.4
