extends CharacterBody3D
class_name PlayerController
## 第一人称移动、蹲伏、射击、生命与复活。

@export var walk_speed: float = 4.2
@export var crouch_speed: float = 2.2
@export var tunnel_speed: float = 2.6
@export var jump_speed: float = 5.2
@export var mouse_sensitivity: float = 0.0022
@export var standing_height: float = 1.7
@export var crouch_height: float = 1.1
@export var fire_interval: float = 1.2
@export var revive_lock_seconds: float = 6.0

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var shoot_ray: RayCast3D = $Head/Camera3D/ShootRay
@onready var interaction: InteractionSystem = $InteractionSystem

var _yaw: float = 0.0
var _pitch: float = 0.0
var _crouching: bool = false
var _fire_cooldown: float = 0.0
var _revive_timer: float = 0.0
var _capsule: CapsuleShape3D
var _port_aim: Vector3 = Vector3.RIGHT
var _head_base := 1.45
var _bob := 0.0
var _kick := 0.0
var _dip := 0.0
var _rifle: Node3D
var _rifle_kick := 0.0
var _covering := false
var _pose := &"idle"

func _ready() -> void:
	add_to_group("player")
	_capsule = collision.shape as CapsuleShape3D
	_yaw = rotation.y
	floor_max_angle = deg_to_rad(50.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.player_revived.connect(_on_revived)
	_build_rifle()

func sync_yaw() -> void:
	_yaw = rotation.y

func _input(event: InputEvent) -> void:
	# 鼠标在 _input 立刻吃掉，避免 _unhandled 排队造成一帧延迟
	if not BattleState.player_can_control or BattleState.battle_over:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		_apply_look()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not BattleState.player_can_control or BattleState.battle_over:
		return
	if event.is_action_pressed("fire"):
		_try_fire()
	if event.is_action_pressed("reload"):
		_reload()
	if event.is_action_pressed("command_ally"):
		_command_looked_ally()
	if event.is_action_pressed("shout"):
		_shout_to_ally()
	if event.is_action_pressed("begin_watch"):
		_try_begin_watch()
	if event.is_action_pressed("jump") and is_on_floor() and not BattleState.player_in_tunnel and not _covering:
		velocity.y = jump_speed
		_dip = 0.1
	if event.is_action_pressed("cover"):
		_covering = not _covering
		_pose = &"cover" if _covering else &"idle"

func _process(_delta: float) -> void:
	# 每渲染帧同步视角，不跟 physics tick 绑死
	if BattleState.player_can_control and not BattleState.battle_over:
		_apply_look()

func _apply_look() -> void:
	rotation.y = _yaw
	if head:
		head.rotation.x = _pitch - _kick - _dip

func _physics_process(delta: float) -> void:
	BattleState.player_position = global_position
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _revive_timer > 0.0:
		_revive_timer -= delta
		BattleState.player_can_control = false
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if _revive_timer <= 0.0 and BattleState.player_alive and not BattleState.battle_over:
			BattleState.player_can_control = true
		return

	if not BattleState.player_can_control or not BattleState.player_alive or BattleState.battle_over:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_update_crouch()
	var speed := crouch_speed if (_crouching or _covering) else walk_speed
	if BattleState.player_in_tunnel:
		speed = tunnel_speed
		_set_height(crouch_height)
		_covering = false

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if not is_on_floor():
		velocity.y -= 20.0 * delta
		_pose = &"jump"
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		if _covering:
			_pose = &"cover"
			speed *= 0.55
		elif direction.length() > 0.1:
			_pose = &"run" if speed > 3.5 and not _crouching else &"walk"
		else:
			_pose = &"idle"
	if _covering:
		direction *= 0.45
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	if global_position.y < -6.4:
		global_position.y = -3.6
		velocity = Vector3.ZERO
	if velocity.y < -3.0:
		_dip = maxf(_dip, 0.08)
	_step_and_kick(delta)

	if interaction:
		interaction.tick(delta)

	if BattleState.firing_port_expose_time > 0.0:
		BattleState.firing_port_expose_time = maxf(0.0, BattleState.firing_port_expose_time - delta)

func _update_crouch() -> void:
	_crouching = Input.is_action_pressed("crouch") or BattleState.player_in_tunnel
	_set_height(crouch_height if _crouching else standing_height)

func _set_height(h: float) -> void:
	if _capsule == null:
		return
	_capsule.height = h
	collision.position.y = h * 0.5
	_head_base = h * 0.85
	head.position.y = _head_base

func _try_fire() -> void:
	if _fire_cooldown > 0.0:
		return
	if BattleState.exploring:
		EventBus.dry_fired.emit()
		return
	if BattleState.player_ammo <= 0:
		EventBus.dry_fired.emit()
		EventBus.status_message.emit("身上没弹了。", 1.6)
		return
	# 枪孔规则：在枪孔处必须朝向合理
	if BattleState.player_at_firing_port:
		if not _firing_port_aim_ok():
			EventBus.status_message.emit("调整枪口朝向射击孔外侧", 1.5)
			return
	elif BattleState.player_in_tunnel and not BattleState.player_at_firing_port:
		# 地道内允许近战距离射击，但精度低——仍允许射击
		pass

	if BattleState.player_in_lookout or BattleState.phase == BattleState.Phase.OBSERVE:
		BattleState.lookout_exposed = true
		BattleState.recon_exposed = true
		if BattleState.recon_counter_at <= 0.0:
			BattleState.recon_counter_at = Time.get_ticks_msec() * 0.001 + 2.0
			BattleState.firing_port_position = Vector3(22.73, 1.45, 0.0)
	if BattleState.player_at_firing_port:
		BattleState.firing_port_expose_time = 6.0
	BattleState.player_ammo -= 1
	_fire_cooldown = fire_interval
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	EventBus.player_fired.emit(origin, dir)
	_kick = 0.05
	_rifle_kick = 0.12

	shoot_ray.force_raycast_update()
	var hit_pos := origin + dir * 8.0
	var flesh := false
	if shoot_ray.is_colliding():
		hit_pos = shoot_ray.get_collision_point()
		var collider := shoot_ray.get_collider()
		if collider and collider.has_method("take_damage"):
			flesh = true
			collider.take_damage(1, self)
		elif collider and collider.get_parent() and collider.get_parent().has_method("take_damage"):
			flesh = true
			collider.get_parent().take_damage(1, self)
	EventBus.muzzle_flash.emit(origin, hit_pos, flesh)

func _firing_port_aim_ok() -> bool:
	var forward := -global_transform.basis.z
	var aim := _port_aim
	if aim.length_squared() < 0.01:
		aim = Vector3.RIGHT
	return forward.dot(aim.normalized()) > 0.45 and absf(_pitch) < deg_to_rad(25.0)

func _reload() -> void:
	EventBus.dry_fired.emit()
	EventBus.status_message.emit("身上没弹了。", 1.6)

func take_damage(amount: int = 1, _source: Node = null) -> void:
	EventBus.actor_hit.emit(global_position + Vector3.UP * 1.2, &"player")
	if not BattleState.player_alive or BattleState.battle_over:
		return
	if Time.get_ticks_msec() / 1000.0 < BattleState.player_invulnerable_until:
		return
	_die()

func _die() -> void:
	BattleState.player_alive = false
	BattleState.player_lives -= 1
	BattleState.player_can_control = false
	EventBus.player_died.emit(BattleState.player_lives)
	BattleState.log_event("玩家倒下，剩余生命 %d" % BattleState.player_lives)

	if BattleState.player_lives > 0 and BattleState.allies_alive > 0:
		EventBus.status_message.emit("战友掩护中…即将在指挥室复活", 3.0)
		await get_tree().create_timer(2.0).timeout
		_revive_at_command_room()
	else:
		EventBus.player_died.emit(0)

func _revive_at_command_room() -> void:
	var spawn := get_tree().get_first_node_in_group("command_room_spawn")
	_set_height(crouch_height)
	set_in_tunnel(true)
	if spawn:
		global_position = spawn.global_position
	velocity = Vector3.ZERO
	BattleState.player_alive = true
	BattleState.player_ammo = maxi(1, int(ceil(BattleState.player_ammo * 0.5)))
	_revive_timer = revive_lock_seconds
	BattleState.player_invulnerable_until = Time.get_ticks_msec() / 1000.0 + revive_lock_seconds
	EventBus.player_revived.emit()
	EventBus.status_message.emit("复活中，%.0f 秒内无法操作" % revive_lock_seconds, revive_lock_seconds)

func _on_revived() -> void:
	pass

func _try_begin_watch() -> void:
	if not BattleState.exploring or BattleState.battle_over:
		return
	GameManager.begin_play()

func _shout_to_ally() -> void:
	const SHOUT_RANGE := 8.0
	var nearest: Node = null
	var best := SHOUT_RANGE
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally.has_method("is_alive") and ally.is_alive():
			var dist := global_position.distance_to((ally as Node3D).global_position)
			if dist <= best:
				best = dist
				nearest = ally
	if BattleState.player_in_lookout:
		BattleState.lookout_exposed = true
	EventBus.shout_emitted.emit(global_position)
	if nearest != null and nearest.has_method("receive_command_cycle"):
		nearest.receive_command_cycle()

func _command_looked_ally() -> void:
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		EventBus.status_message.emit("看向战友后按 F 下令", 1.5)
		return
	var col := interact_ray.get_collider()
	var ally: Node = col
	if not ally.is_in_group("allies"):
		ally = col.get_parent()
	if ally and ally.is_in_group("allies") and ally.has_method("receive_command_cycle"):
		ally.receive_command_cycle()
	else:
		EventBus.status_message.emit("目标不是可指挥战友", 1.5)

func set_in_tunnel(v: bool) -> void:
	BattleState.player_in_tunnel = v

func set_in_lookout(v: bool) -> void:
	BattleState.player_in_lookout = v

func set_at_firing_port(active: bool, port_id: StringName = &"", aim: Vector3 = Vector3.RIGHT, port_pos: Vector3 = Vector3.ZERO) -> void:
	BattleState.player_at_firing_port = active
	BattleState.firing_port_id = port_id
	_port_aim = aim
	if active:
		BattleState.firing_port_position = port_pos

func stumble() -> void:
	var back := global_transform.basis.z
	velocity.x += back.x * 2.4
	velocity.z += back.z * 2.4
	_dip = 0.16

func dip_for(amount: float) -> void:
	_dip = amount

func _step_and_kick(delta: float) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.4 and is_on_floor():
		_bob += delta * clampf(planar, 1.0, 5.0) * 2.2
	_kick = move_toward(_kick, 0.0, delta * 4.2)
	_dip = move_toward(_dip, 0.0, delta * 3.0)
	_rifle_kick = move_toward(_rifle_kick, 0.0, delta * 6.0)
	# 步态颠簸减小，避免和鼠标抢视角造成「粘滞」
	var hop := sin(_bob) * 0.012 if planar > 0.4 else 0.0
	head.position.y = _head_base + hop
	_apply_look()
	if _rifle:
		_rifle.position = Vector3(0.2, -0.18 + hop * 0.35, -0.46 + _rifle_kick)
		_rifle.rotation.x = -_rifle_kick * 1.5

func _build_rifle() -> void:
	if camera == null:
		return
	var root := Node3D.new()
	root.name = "Rifle"
	camera.add_child(root)
	_rifle = root
	_rifle.position = Vector3(0.2, -0.18, -0.46)
	if ResourceLoader.exists("res://assets/props/rifle_hanyang.glb"):
		var packed := load("res://assets/props/rifle_hanyang.glb") as PackedScene
		if packed:
			var inst := packed.instantiate() as Node3D
			if inst:
				inst.name = "RifleMesh"
				root.add_child(inst)
				inst.scale = Vector3(0.55, 0.55, 0.55)
				inst.rotation_degrees = Vector3(4, 180, 0)
				inst.position = Vector3(0, -0.02, -0.08)
				return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.12)
	wood.roughness = 0.92
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.22, 0.2, 0.18)
	iron.roughness = 0.55
	iron.metallic = 0.35
	var stock := MeshInstance3D.new()
	var stock_mesh := BoxMesh.new()
	stock_mesh.size = Vector3(0.06, 0.08, 0.34)
	stock.mesh = stock_mesh
	stock.position = Vector3(0, 0, 0.08)
	stock.material_override = wood
	root.add_child(stock)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.025, 0.025, 0.42)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 0.03, -0.22)
	barrel.material_override = iron
	root.add_child(barrel)
