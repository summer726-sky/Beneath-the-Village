extends Node3D
class_name FlipMouth
## 翻口或翻眼。默认挡住 BoardClosed 所指的那一侧。
## 翻开后改挡 BoardAlt（可以没有）。报信直道默认不挡。

@export var hint_closed: String = "E 翻开翻口：打开南边死道，并挡住通往树洞的直道"
@export var hint_open: String = "E 翻回翻口：死道重新挡住，直道恢复"
@export var report_dead_end: bool = false

var using_alt: bool = false

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
	EventBus.status_message.emit(hint_open if using_alt else hint_closed, 2.4)

func _apply() -> void:
	_set_board(get_node_or_null("BoardClosed"), not using_alt)
	_set_board(get_node_or_null("BoardAlt"), using_alt)

func _set_board(board: Node, enabled: bool) -> void:
	if board == null:
		return
	board.visible = enabled
	if board is CollisionObject3D:
		(board as CollisionObject3D).collision_layer = 1 if enabled else 0
