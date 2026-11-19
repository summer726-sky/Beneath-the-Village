extends Node

var _swing := 0.02

func _ready() -> void:
	EventBus.bell_hit.connect(func() -> void: _swing = 0.22)

func _process(delta: float) -> void:
	var bell := get_parent().get_node_or_null("PropMesh") as Node3D
	if bell == null:
		return
	_swing = move_toward(_swing, 0.015, delta * 0.28)
	var t := Time.get_ticks_msec() * 0.001
	bell.rotation.z = sin(t * (2.2 if _swing > 0.05 else 0.7)) * _swing
