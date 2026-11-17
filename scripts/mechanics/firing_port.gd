extends Area3D
class_name FiringPort
## 院墙射击孔：站位 + 朝向要求。持续暴露约 8 秒后敌军还击。

@export var port_id: StringName = &"wall_port"
@export var aim_dir: Vector3 = Vector3.RIGHT

func _ready() -> void:
	add_to_group("firing_ports")
	add_to_group("interactable")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func get_interact_hint() -> String:
	return "人在墙后。从窄缝看出去再开枪，开一枪就会暴露"

func interact(_by: Node) -> void:
	pass

func _on_enter(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("set_at_firing_port"):
		body.set_at_firing_port(true, port_id, aim_dir)

func _on_exit(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("set_at_firing_port"):
		body.set_at_firing_port(false)
