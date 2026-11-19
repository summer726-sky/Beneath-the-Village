extends StaticBody3D
## 卡口板：合页在顶上，横拦东西走道。敞开时人能过；放下才挡路。

var closed: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("choke_gate")
	_apply_pose(false, false)

func get_interact_hint() -> String:
	if closed:
		return "按住 E 三秒拉开卡口"
	return "按住 E 三秒放下卡口，挡住来路"

func get_hold_seconds() -> float:
	return 3.0

func interact(_by: Node) -> void:
	_apply_pose(not closed, true)

func _apply_pose(shut: bool, animate: bool) -> void:
	closed = shut
	collision_layer = 1 if shut else 0
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape:
		shape.disabled = not shut
	var target := 0.0 if shut else -88.0
	if animate:
		var tw := create_tween()
		tw.tween_property(self, "rotation_degrees:z", target, 0.35)
		if shut:
			BattleState.log_event("卡口放下")
		else:
			BattleState.log_event("卡口拉开")
	else:
		rotation_degrees.z = target
