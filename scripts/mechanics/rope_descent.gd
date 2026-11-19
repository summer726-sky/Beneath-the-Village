extends Area3D
class_name RopeDescent
## 固定绳索垂降：固定上方入口、预设路径、地下落点。非通用攀爬/绳索物理。

@export var drop_point_path: NodePath
var is_shelter: bool = false
var _drop: Node3D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("rope_entry")
	add_to_group("entrances")
	_resolve_drop()

func _resolve_drop() -> Node3D:
	if _drop == null and drop_point_path != NodePath():
		_drop = get_node_or_null(drop_point_path) as Node3D
	return _drop

func get_entrance_id() -> StringName:
	return &"rope_entry"

func is_passable() -> bool:
	return true

func get_interact_hint() -> String:
	return "E 沿固定绳索垂降进入地道"

func interact(by: Node) -> void:
	if by is CharacterBody3D and _resolve_drop():
		# 中成本简化：短暂停顿后传送到落点（预留动画挂点）
		if by.has_method("dip_for"):
			by.dip_for(0.14)
		EventBus.status_message.emit("沿绳垂降…", 1.2)
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(by):
			(by as CharacterBody3D).global_position = _resolve_drop().global_position + Vector3(0, 0.3, 0)
			if by.has_method("set_in_tunnel"):
				by.set_in_tunnel(true)
			EventBus.status_message.emit("抵达地下落点", 1.5)
