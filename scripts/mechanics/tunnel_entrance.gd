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
	return hint_text

func interact(by: Node) -> void:
	if not passable:
		EventBus.status_message.emit("此入口暂时无法通行", 2.0)
		return
	_open_lid()
	var dest := _resolve_link()
	if by is CharacterBody3D and dest:
		(by as CharacterBody3D).global_position = dest.global_position + Vector3(0, 0.15, 0)
		(by as CharacterBody3D).velocity = Vector3.ZERO
		if by.has_method("dip_for"):
			by.dip_for(0.12)
		if by.has_method("set_in_tunnel"):
			by.set_in_tunnel(enters_tunnel)
		EventBus.status_message.emit("进入地道" if enters_tunnel else "回到地面", 1.5)
	elif by is CharacterBody3D:
		(by as CharacterBody3D).global_position += Vector3(0, -5.0 if enters_tunnel else 5.0, 0)
		if by.has_method("set_in_tunnel"):
			by.set_in_tunnel(enters_tunnel)

var _lid_open: bool = false

func _open_lid() -> void:
	var lid := get_node_or_null("Lid") as Node3D
	if lid == null or _lid_open:
		return
	_lid_open = true
	var tw := create_tween()
	if lid.has_meta("slide"):
		tw.tween_property(lid, "position", lid.position + (lid.get_meta("slide") as Vector3), 0.32)
	elif lid.has_meta("hinge"):
		tw.tween_property(lid, "rotation_degrees", lid.get_meta("hinge"), 0.32)

func _on_body_entered(body: Node) -> void:
	if not discoverable or discovered:
		return
	if body.is_in_group("enemies"):
		# 入口附近发现概率 0.67；未发现则离开后再靠近可再判
		if randf() > BattleState.ENTRANCE_DISCOVER_CHANCE:
			BattleState.log_event("敌军未发现入口：%s" % entrance_id)
			return
		discovered = true
		var eid: StringName = body.enemy_id if "enemy_id" in body else StringName(body.name)
		EventBus.tunnel_entrance_discovered.emit(entrance_id, eid)
		BattleState.log_event("敌军发现入口：%s" % entrance_id)
