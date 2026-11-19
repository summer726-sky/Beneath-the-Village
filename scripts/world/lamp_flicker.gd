extends OmniLight3D

var _base := 0.65
var _phase := 0.0

func _ready() -> void:
	_base = light_energy
	_phase = randf() * TAU

func _process(delta: float) -> void:
	_phase += delta
	var wobble := 0.94 + 0.06 * sin(_phase * 5.2) * sin(_phase * 1.7 + 0.7)
	light_energy = _base * wobble
