extends Area3D
class_name ZoneTrigger
## 区域触发：地道内外、瞭望点等。

@export var zone_id: StringName = &"zone"
@export var mark_tunnel: bool = false
@export var mark_observe: bool = false

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if mark_tunnel and body.has_method("set_in_tunnel"):
		body.set_in_tunnel(true)
	if mark_observe:
		if body.has_method("set_in_lookout"):
			body.set_in_lookout(true)

func _on_exit(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if mark_tunnel and body.has_method("set_in_tunnel"):
		body.set_in_tunnel(false)
	if mark_observe and body.has_method("set_in_lookout"):
		body.set_in_lookout(false)
