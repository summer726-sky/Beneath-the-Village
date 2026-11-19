extends Node3D
class_name FlipMouth
## 翻口或翻眼。默认挡住 BoardClosed 所指的那一侧。
## 翻开后改挡 BoardAlt（可以没有）。报信直道默认不挡。

@export var hint_closed: String = "E 翻开翻口：打开南边死道，并挡住通往树洞的直道"
@export var hint_open: String = "E 翻回翻口：死道重新挡住，直道恢复"
@export var report_dead_end: bool = false

var using_alt: bool = false
var _posed: bool = false

func _ready() -> void:
	add_to_group("flip_mouth")
	add_to_group("interactable")
	if report_dead_end:
		add_to_group("combat_flip")
	_apply()

func is_dead_open() -> bool:
	return using_alt

func get_interact_hint() -> String:
	return hint_open if using_alt else hint_closed

func interact(_by: Node) -> void:
	using_alt = not using_alt
	_apply()

func _apply() -> void:
	_set_board(get_node_or_null("BoardClosed"), not using_alt)
	_set_board(get_node_or_null("BoardAlt"), using_alt)
	_posed = true

func _set_board(board: Node, blocking: bool) -> void:
	if board == null or not (board is Node3D):
		return
	var body := board as Node3D
	body.visible = true
	if body is CollisionObject3D:
		(body as CollisionObject3D).collision_layer = 1 if blocking else 0
	if not bool(body.get_meta("hinged", false)):
		body.visible = blocking
		return
	var yaw := float(body.get_meta("shut_yaw", 0.0)) if blocking else float(body.get_meta("open_yaw", -90.0))
	if not _posed:
		body.rotation_degrees.y = yaw
		return
	var tw := body.create_tween()
	tw.tween_property(body, "rotation_degrees:y", yaw, 0.35)
