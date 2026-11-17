extends CharacterBody3D
class_name PlayerController
## 第一人称移动、蹲伏、射击、生命与复活。

@export var walk_speed: float = 4.2
@export var crouch_speed: float = 2.2
@export var tunnel_speed: float = 2.6
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

func _ready() -> void:
	add_to_group("player")
	_capsule = collision.shape as CapsuleShape3D
	_yaw = rotation.y
	floor_max_angle = deg_to_rad(50.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.player_revived.connect(_on_revived)

func sync_yaw() -> void:
	_yaw = rotation.y

func _unhandled_input(event: InputEvent) -> void:
	if not BattleState.player_can_control or BattleState.battle_over:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation.y = _yaw
		head.rotation.x = _pitch
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
	var speed := crouch_speed if _crouching else walk_speed
	if BattleState.player_in_tunnel:
		speed = tunnel_speed
		_set_height(crouch_height)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	if global_position.y < -6.4:
		global_position.y = -3.6
		velocity = Vector3.ZERO

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
	head.position.y = h * 0.85

func _try_fire() -> void:
	if _fire_cooldown > 0.0:
		return
	if BattleState.exploring:
		return
	if BattleState.player_ammo <= 0:
		EventBus.status_message.emit("身上弹药已空。沿地道前往弹药暗室，每次最多补充 4 发。", 3.2)
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
	if BattleState.player_at_firing_port:
		BattleState.firing_port_expose_time = 6.0
	BattleState.player_ammo -= 1
	_fire_cooldown = fire_interval
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	EventBus.player_fired.emit(origin, dir)
	EventBus.status_message.emit("射击！剩余弹药 %d" % BattleState.player_ammo, 1.0)

	shoot_ray.force_raycast_update()
	if shoot_ray.is_colliding():
		var collider := shoot_ray.get_collider()
		if collider and collider.has_method("take_damage"):
			collider.take_damage(1, self)
		elif collider and collider.get_parent() and collider.get_parent().has_method("take_damage"):
			collider.get_parent().take_damage(1, self)

func _firing_port_aim_ok() -> bool:
	var forward := -global_transform.basis.z
	var aim := _port_aim
	if aim.length_squared() < 0.01:
		aim = Vector3.RIGHT
	return forward.dot(aim.normalized()) > 0.45 and absf(_pitch) < deg_to_rad(25.0)

func _reload() -> void:
	EventBus.status_message.emit("没有随身备弹。地道弹药暗室可补充，每次最多 %d 发。" % BattleState.AMMO_RESUPPLY_CAP, 2.6)

func take_damage(amount: int = 1, _source: Node = null) -> void:
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

func set_at_firing_port(active: bool, port_id: StringName = &"", aim: Vector3 = Vector3.RIGHT) -> void:
	BattleState.player_at_firing_port = active
	BattleState.firing_port_id = port_id
	_port_aim = aim
