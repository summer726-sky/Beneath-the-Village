extends Node
class_name InteractionSystem
## 统一视线/距离检测与 E 键交互。优先射线；近距兜底要求朝向大致对准。

@export var max_distance: float = 2.8
@onready var ray: RayCast3D = get_parent().get_node("Head/Camera3D/InteractRay")

var current_target: Node = null
var hold_progress: float = 0.0
var _hold_latched: bool = false
var _hold_target: Node = null

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
	if current_target != _hold_target:
		hold_progress = 0.0
		_hold_latched = false
		_hold_target = current_target
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
	var best_d := 1.85
	var body := get_parent() as Node3D
	if body == null:
		return null
	var origin: Vector3 = body.global_position
	var cam := body.get_node_or_null("Head/Camera3D") as Node3D
	var forward := -cam.global_transform.basis.z if cam else -body.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D):
			continue
		var target := n as Node3D
		var to := target.global_position - origin
		var d := to.length()
		if d > best_d or d < 0.05:
			continue
		var flat := Vector3(to.x, 0, to.z)
		if flat.length_squared() > 0.01:
			if rad_to_deg(forward.angle_to(flat.normalized())) > 55.0:
				continue
		if not _has_clear_line(origin + Vector3.UP * 1.35, target.global_position + Vector3.UP * 0.6, target):
			continue
		best_d = d
		best = n
	return best

func _has_clear_line(from: Vector3, to: Vector3, want: Node3D) -> bool:
	var space := (get_parent() as Node3D).get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [(get_parent() as CollisionObject3D).get_rid()] if get_parent() is CollisionObject3D else []
	query.collision_mask = 1 | 32
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var col: Object = hit.get("collider")
	if col == null:
		return false
	var n := col as Node
	while n:
		if n == want or n.get_parent() == want:
			return true
		if n.is_in_group("interactable") and n == want:
			return true
		n = n.get_parent()
	# 撞到世界墙则不可交互
	return false

func _handle_input(interactable: Node, delta: float) -> void:
	var hold_required := 0.0
	if interactable.has_method("get_hold_seconds"):
		hold_required = float(interactable.get_hold_seconds())
	if hold_required > 0.0:
		if Input.is_action_pressed("interact"):
			if _hold_latched:
				EventBus.interactable_hint.emit("先松开，再重新按住")
				return
			hold_progress += delta
			EventBus.interactable_hint.emit("%s (%.0f%%)" % [
				interactable.get_interact_hint() if interactable.has_method("get_interact_hint") else "交互",
				clampf(hold_progress / hold_required, 0.0, 1.0) * 100.0
			])
			if hold_progress >= hold_required:
				hold_progress = 0.0
				_hold_latched = true
				_do_interact(interactable)
		else:
			hold_progress = 0.0
			_hold_latched = false
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
	_hold_latched = false
	_hold_target = null
	EventBus.interactable_hint.emit("")
