extends Node
class_name InteractionSystem
## 统一视线/距离检测与 E 键交互。

@export var max_distance: float = 2.8
@onready var ray: RayCast3D = get_parent().get_node("Head/Camera3D/InteractRay")

var current_target: Node = null
var hold_progress: float = 0.0

func tick(_delta: float) -> void:
	if not BattleState.player_can_control or BattleState.battle_over:
		_clear_hint()
		return
	ray.force_raycast_update()
	current_target = null
	if ray.is_colliding():
		var col := ray.get_collider() as Node
		var interactable := _find_interactable(col)
		if interactable and _distance_ok(interactable):
			current_target = interactable
	if current_target == null:
		current_target = _nearest_interactable()
	if current_target:
		var hint := ""
		if current_target.has_method("get_interact_hint"):
			hint = current_target.get_interact_hint()
		EventBus.interactable_hint.emit(hint)
		_handle_input(current_target, _delta)
		return
	_clear_hint()

func _nearest_interactable() -> Node:
	var best: Node = null
	var best_d := 2.2
	var origin: Vector3 = (get_parent() as Node3D).global_position
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Node3D:
			var d: float = origin.distance_to((n as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = n
	return best

func _handle_input(interactable: Node, delta: float) -> void:
	var hold_required := 0.0
	if interactable.has_method("get_hold_seconds"):
		hold_required = float(interactable.get_hold_seconds())
	if hold_required > 0.0:
		if Input.is_action_pressed("interact"):
			hold_progress += delta
			EventBus.interactable_hint.emit("%s (%.0f%%)" % [
				interactable.get_interact_hint() if interactable.has_method("get_interact_hint") else "交互",
				clampf(hold_progress / hold_required, 0.0, 1.0) * 100.0
			])
			if hold_progress >= hold_required:
				hold_progress = 0.0
				_do_interact(interactable)
		else:
			hold_progress = 0.0
	elif Input.is_action_just_pressed("interact"):
		_do_interact(interactable)

func _do_interact(interactable: Node) -> void:
	if interactable.has_method("interact"):
		interactable.interact(get_parent())

func _find_interactable(node: Node) -> Node:
	var n := node
	while n:
		if n.is_in_group("interactable") or n.has_method("interact"):
			return n
		n = n.get_parent()
	return null

func _distance_ok(node: Node) -> bool:
	if node is Node3D:
		return get_parent().global_position.distance_to((node as Node3D).global_position) <= max_distance + 1.5
	return true

func _clear_hint() -> void:
	hold_progress = 0.0
	EventBus.interactable_hint.emit("")
