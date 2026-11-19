extends Node
## 枪口短光、弹道亮线、抛壳、弹着土尘、拉雷和翻板尘土、井口滴水。

var _live := 0
var _drip := 0.0

func _ready() -> void:
	EventBus.muzzle_flash.connect(_on_muzzle)
	EventBus.trap_triggered.connect(_on_trap)
	EventBus.player_died.connect(_on_player_hurt)
	EventBus.actor_hit.connect(_on_actor_hit)

func _process(delta: float) -> void:
	var pouring: bool = BattleState.water_started and not BattleState.water_barrier_closed and not BattleState.bunker_flooded and not BattleState.battle_over
	if not pouring:
		return
	_drip -= delta
	if _drip > 0.0 or _live >= 4:
		return
	_drip = 0.18
	var well := get_tree().get_first_node_in_group("well") as Node3D
	if well:
		_puff(well.global_position + Vector3(0, 0.55, 0), Color(0.45, 0.52, 0.48), 6, Vector3.DOWN)

func _on_muzzle(origin: Vector3, hit: Vector3, flesh: bool) -> void:
	_flash(origin)
	_tracer(origin, hit)
	_eject_shell(origin)
	if origin.distance_squared_to(hit) < 0.04:
		return
	var tint := Color(0.62, 0.5, 0.36) if flesh else Color(0.55, 0.46, 0.32)
	_puff(hit, tint, 6 if flesh else 12, Vector3.UP)

func _on_actor_hit(origin: Vector3, _who: StringName) -> void:
	_puff(origin, Color(0.45, 0.36, 0.28), 8, Vector3.UP)

func _on_trap(id: StringName, _victim: StringName) -> void:
	var at := Vector3.ZERO
	var found := false
	for n in get_tree().get_nodes_in_group("flip_trap"):
		var trap := n as Node3D
		if trap == null:
			continue
		if StringName(str(trap.get("trap_id"))) == id or trap.name == String(id):
			at = trap.global_position
			found = true
			break
		if not found:
			at = trap.global_position
			found = true
	if found:
		_puff(at, Color(0.5, 0.4, 0.28), 14, Vector3.UP)
		_flash(at)

func _on_player_hurt(_lives: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dim := cam.get_node_or_null("HurtDim") as MeshInstance3D
	if dim == null:
		dim = MeshInstance3D.new()
		dim.name = "HurtDim"
		var quad := QuadMesh.new()
		quad.size = Vector2(2.4, 1.6)
		dim.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.05, 0.04, 0.03, 0.0)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		dim.material_override = mat
		dim.position = Vector3(0, 0, -0.35)
		cam.add_child(dim)
	var mat2 := dim.material_override as StandardMaterial3D
	mat2.albedo_color.a = 0.55
	var tw := create_tween()
	tw.tween_property(mat2, "albedo_color:a", 0.0, 0.45)

func _flash(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 3.2
	light.omni_range = 3.6
	light.shadow_enabled = false
	add_child(light)
	# 可见火光球体，避免只有灯光看不清
	var burst := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	burst.mesh = ball
	burst.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burst.material_override = mat
	add_child(burst)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(light, "light_energy", 0.0, 0.1)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tw.tween_property(burst, "scale", Vector3(2.2, 2.2, 2.2), 0.1)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(light):
			light.queue_free()
		if is_instance_valid(burst):
			burst.queue_free()
	)

func _tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.2:
		return
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.02, dist)
	line.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.86, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.25)
	mat.emission_energy_multiplier = 2.2
	line.material_override = mat
	add_child(line)
	line.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var tw := create_tween()
	tw.tween_interval(0.06)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.05)
	tw.tween_callback(line.queue_free)

func _eject_shell(origin: Vector3) -> void:
	if _live >= 4:
		return
	_live += 1
	var shell := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.045
	shell.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.62, 0.28)
	mat.metallic = 0.7
	mat.roughness = 0.35
	shell.material_override = mat
	shell.position = origin + Vector3(0.08, -0.05, 0.02)
	add_child(shell)
	var side := Vector3(randf_range(0.8, 1.6), randf_range(1.2, 2.0), randf_range(-0.4, 0.4))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(shell, "position", shell.position + side, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(shell, "rotation", Vector3(randf() * 4.0, randf() * 3.0, randf() * 5.0), 0.35)
	tw.chain().tween_interval(0.2)
	tw.tween_callback(func() -> void:
		_live = maxi(0, _live - 1)
		if is_instance_valid(shell):
			shell.queue_free()
	)

func _puff(at: Vector3, tint: Color, amount: int, direction: Vector3) -> void:
	if _live >= 4:
		return
	_live += 1
	var p := CPUParticles3D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = 0.4
	p.direction = direction
	p.spread = 38.0
	p.gravity = Vector3(0, -2.2, 0)
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 1.3
	var ball := SphereMesh.new()
	ball.radius = 0.035
	ball.height = 0.07
	p.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 1.0
	p.material_override = mat
	add_child(p)
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func() -> void:
		_live = maxi(0, _live - 1)
		if is_instance_valid(p):
			p.queue_free()
	)
