extends StaticBody3D
class_name WaterBarrier
## 挡水隔板：合页在顶上。敞开时人能过；关上才挡路、挡水。可以再拉开。

var closed: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("water_barrier")
	_apply_pose(false, false)

func get_interact_hint() -> String:
	if closed:
		return "按住 E 三秒拉开隔板。松开后才能再开"
	return "按住 E 三秒关上隔板，挡住来水"

func get_hold_seconds() -> float:
	return 3.0

func interact(_by: Node) -> void:
	_apply_pose(not closed, true)

func _apply_pose(shut: bool, animate: bool) -> void:
	closed = shut
	BattleState.water_barrier_closed = shut
	collision_layer = 1 if shut else 0
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape:
		shape.disabled = not shut
	var target := 0.0 if shut else 88.0
	if animate:
		var tw := create_tween()
		tw.tween_property(self, "rotation_degrees:x", target, 0.35)
	else:
		rotation_degrees.x = target
	if not animate:
		return
	if shut:
		EventBus.water_barrier_closed.emit()
		BattleState.log_event("挡水隔板关闭")
	else:
		BattleState.log_event("挡水隔板拉开")
