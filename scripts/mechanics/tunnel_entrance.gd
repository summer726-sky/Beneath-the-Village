extends Area3D
class_name TunnelEntrance
## 地面-地下连接入口。记录通行、可发现性、垂直移动与连接节点。

@export var entrance_id: StringName = &"entrance"
@export var passable: bool = true
@export var discoverable: bool = true
@export var supports_vertical: bool = false
@export var linked_node_path: NodePath
@export var is_shelter: bool = true
@export var enters_tunnel: bool = true
@export var hint_text: String = "地道入口"

var discovered: bool = false
var _linked: Node3D

func _ready() -> void:
	add_to_group("entrances")
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	_resolve_link()

func _resolve_link() -> Node3D:
	if _linked == null and linked_node_path != NodePath():
		_linked = get_node_or_null(linked_node_path) as Node3D
	return _linked

func get_entrance_id() -> StringName:
	return entrance_id

func is_passable() -> bool:
	return passable

func get_interact_hint() -> String:
	if supports_vertical:
		return "E 沿绳索进入地道"
	return "E 进入：%s" % hint_text

func interact(by: Node) -> void:
	if not passable:
		EventBus.status_message.emit("此入口暂时无法通行", 2.0)
		return
	var dest := _resolve_link()
	if by is CharacterBody3D and dest:
		(by as CharacterBody3D).global_position = dest.global_position + Vector3(0, 0.15, 0)
		(by as CharacterBody3D).velocity = Vector3.ZERO
		if by.has_method("set_in_tunnel"):
			by.set_in_tunnel(enters_tunnel)
		EventBus.status_message.emit("进入地道" if enters_tunnel else "回到地面", 1.5)
	elif by is CharacterBody3D:
		(by as CharacterBody3D).global_position += Vector3(0, -5.0 if enters_tunnel else 5.0, 0)
		if by.has_method("set_in_tunnel"):
			by.set_in_tunnel(enters_tunnel)

func _on_body_entered(body: Node) -> void:
	if not discoverable or discovered:
		return
	if body.is_in_group("enemies"):
		discovered = true
		var eid: StringName = body.enemy_id if "enemy_id" in body else StringName(body.name)
		EventBus.tunnel_entrance_discovered.emit(entrance_id, eid)
		EventBus.status_message.emit("敌军发现了入口：%s" % hint_text, 2.5)
