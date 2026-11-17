extends CharacterBody3D
class_name EnemyAI
## 敌军有限状态机：搜索、还击、守洞、探洞、灌水、撤退。无全图透视。

enum State { WAIT, APPROACH, SEARCH, COMBAT, GUARD_HOLE, PROBE, FLOOD, RETREAT, DEAD }

@export var role: StringName = &"rifleman"  # commander / rifleman / engineer
@export var move_speed: float = 2.4
@export var sight_range: float = 18.0
@export var sight_angle_deg: float = 70.0
@export var hear_gunshot_range: float = 28.0
@export var enemy_id: StringName = &"enemy"

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision: RayCast3D = $VisionRay

var state: State = State.APPROACH
var route: Array[Vector3] = []
var route_i: int = 0
var alive: bool = true
var has_long_gun: bool = true
var known_player_pos: Vector3 = Vector3.ZERO
var has_player_contact: bool = false
var lose_sight_timer: float = 0.0
var shoot_cooldown: float = 0.0
var search_timer: float = 0.0
var target_entrance: Node3D = null
var _descended: bool = false
var _mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("enemies")
	enemy_id = StringName("%s_%d" % [role, get_instance_id()])
	if role == &"commander":
		move_speed = 2.2
	elif role == &"engineer":
		move_speed = 2.0
		has_long_gun = false
	EventBus.player_fired.connect(_on_player_fired)
	EventBus.shout_emitted.connect(_on_shout)
	EventBus.alarm_triggered.connect(_on_alarm)
	EventBus.enemy_retreated.connect(_on_retreat_signal)
	EventBus.tunnel_entrance_discovered.connect(_on_entrance_found)
	_build_visual()

func get_role() -> StringName:
	return role

func is_alive() -> bool:
	return alive

func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.62, 1.75, 0.42)
	_mesh.mesh = box
	_mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	var role_name := "步枪手"
	match role:
		&"commander":
			mat.albedo_color = Color(0.55, 0.12, 0.1)
			role_name = "分队长"
		&"engineer":
			mat.albedo_color = Color(0.32, 0.38, 0.16)
			role_name = "工兵"
		_:
			mat.albedo_color = Color(0.62, 0.5, 0.22)
	_mesh.material_override = mat
	add_child(_mesh)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	head.mesh = head_mesh
	head.position = Vector3(0, 1.85, 0)
	head.material_override = mat
	add_child(head)
	var tag := Label3D.new()
	tag.text = "敌军·%s" % role_name
	tag.font_size = 48
	tag.outline_size = 8
	tag.modulate = Color(1.0, 0.75, 0.55)
	tag.position = Vector3(0, 2.25, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)

func _physics_process(delta: float) -> void:
	if not alive or BattleState.battle_over:
		return
	if BattleState.exploring:
		state = State.WAIT
		velocity = Vector3.ZERO
		var face := global_position + Vector3(-1, 0, 0)
		if global_position.distance_squared_to(face) > 0.01:
			look_at(face, Vector3.UP)
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		move_and_slide()
		return
	if BattleState.enemies_retreated:
		state = State.RETREAT
	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
	match state:
		State.WAIT:
			_do_wait()
		State.APPROACH:
			_do_approach(delta)
		State.SEARCH:
			_do_search(delta)
		State.COMBAT:
			_do_combat(delta)
		State.GUARD_HOLE:
			_do_guard(delta)
		State.PROBE:
			_do_probe(delta)
		State.FLOOD:
			_do_flood(delta)
		State.RETREAT:
			_do_retreat(delta)
		State.DEAD:
			pass
	_try_perceive(delta)
	move_and_slide()

func _do_wait() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var ahead := global_position + Vector3(0, 0, 1)
	if global_position.distance_squared_to(ahead) > 0.01:
		look_at(ahead, Vector3.UP)

func setup_route(points: Array) -> void:
	route.clear()
	route_i = 0
	for p in points:
		route.append(p)

func _do_approach(delta: float) -> void:
	var spd := 1.2 if not BattleState.alarm_rung else move_speed
	if route.is_empty():
		var gate := get_tree().get_first_node_in_group("village_gate")
		if gate:
			_move_toward((gate as Node3D).global_position, delta, spd)
			if global_position.distance_to((gate as Node3D).global_position) < 2.0:
				state = State.SEARCH
		else:
			state = State.SEARCH
		return
	if route_i >= route.size():
		state = State.SEARCH
		search_timer = 0.0
		return
	var target := route[route_i]
	if global_position.distance_to(target) < 1.5:
		route_i += 1
		return
	_move_toward(target, delta, spd)

func _do_search(delta: float) -> void:
	search_timer += delta
	# 巡逻：在院落入口线索点之间移动
	if target_entrance == null or global_position.distance_to(target_entrance.global_position) < 1.2:
		target_entrance = _pick_search_point()
	if target_entrance:
		_move_toward(target_entrance.global_position, delta)
	# 工兵在警报后一段时间尝试灌水
	if role == &"engineer" and BattleState.alarm_rung and search_timer > 18.0 and not BattleState.water_started:
		var well := get_tree().get_first_node_in_group("well")
		if well and global_position.distance_to((well as Node3D).global_position) < 2.5:
			state = State.FLOOD
			EventBus.water_started.emit()
		elif well:
			_move_toward((well as Node3D).global_position, delta)

func _do_combat(delta: float) -> void:
	if not has_player_contact:
		lose_sight_timer += delta
		if lose_sight_timer > 3.0:
			has_player_contact = false
			state = State.SEARCH
			return
	else:
		lose_sight_timer = 0.0
	var to_player := known_player_pos - global_position
	to_player.y = 0
	if to_player.length() > 0.1:
		look_at(global_position + to_player, Vector3.UP)
	# 地面追击：仅在保持接触时靠近
	if has_player_contact and not BattleState.player_in_tunnel:
		if to_player.length() > 6.0:
			_move_toward(known_player_pos, delta)
		elif shoot_cooldown <= 0.0 and _can_see_player():
			_shoot_player()
	elif BattleState.player_in_tunnel and BattleState.firing_port_expose_time > 8.0:
		if shoot_cooldown <= 0.0:
			_shoot_player()
			EventBus.status_message.emit("敌军向射击孔还击！", 1.5)

func _do_guard(delta: float) -> void:
	if target_entrance:
		_move_toward(target_entrance.global_position, delta)
		if global_position.distance_to(target_entrance.global_position) < 1.5 and shoot_cooldown <= 0.0:
			if BattleState.player_in_tunnel and BattleState.firing_port_expose_time > 5.0:
				_shoot_player()

func _do_probe(delta: float) -> void:
	# 步枪手探洞：走到已发现的入口，再真正下到地道里
	if target_entrance == null:
		state = State.SEARCH
		return
	has_long_gun = false
	if not _descended:
		_move_toward(target_entrance.global_position, delta, move_speed * 0.45)
		if global_position.distance_to(target_entrance.global_position) < 1.15 and target_entrance.has_method("interact"):
			target_entrance.interact(self)
			_descended = true
		return
	var dest := Vector3(8.0, global_position.y, 0.0)
	var mouth := get_tree().get_first_node_in_group("combat_flip")
	if mouth and mouth.has_method("is_dead_open") and mouth.is_dead_open():
		dest = Vector3(2.6, global_position.y, -3.2)
	_move_toward(dest, delta, move_speed * 0.4)
	var trap := get_tree().get_first_node_in_group("flip_trap")
	if trap and global_position.distance_to((trap as Node3D).global_position) < 1.2 and trap.has_method("try_trigger_from"):
		trap.try_trigger_from(self)

func _do_flood(delta: float) -> void:
	var well := get_tree().get_first_node_in_group("well")
	if well:
		_move_toward((well as Node3D).global_position, delta)
	if BattleState.water_barrier_closed:
		state = State.SEARCH

func _do_retreat(delta: float) -> void:
	var exit_pt := get_tree().get_first_node_in_group("enemy_spawn")
	if exit_pt:
		_move_toward((exit_pt as Node3D).global_position, delta, move_speed * 1.2)

func _move_toward(pos: Vector3, _delta: float, spd: float = -1.0) -> void:
	if spd < 0.0:
		spd = move_speed
	var dir := pos - global_position
	dir.y = 0
	if dir.length() < 0.15:
		velocity.x = 0
		velocity.z = 0
		return
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if not is_on_floor():
		velocity.y -= 20.0 * _delta
	else:
		velocity.y = 0
	look_at(global_position + dir, Vector3.UP)

func _try_perceive(_delta: float) -> void:
	if state == State.DEAD or state == State.RETREAT:
		return
	if _can_see_player():
		known_player_pos = BattleState.player_position
		has_player_contact = true
		lose_sight_timer = 0.0
		if state in [State.SEARCH, State.APPROACH, State.GUARD_HOLE]:
			state = State.COMBAT
	# 枪孔暴露还击
	if BattleState.player_at_firing_port and BattleState.firing_port_expose_time >= 8.0:
		if state == State.SEARCH:
			state = State.COMBAT

func _can_see_player() -> bool:
	if BattleState.player_in_lookout and not BattleState.lookout_exposed:
		return false
	var to := BattleState.player_position - global_position
	var dist := to.length()
	if dist > sight_range:
		return false
	if dist < 0.01:
		return true
	var forward := -global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to.normalized()))
	if angle > sight_angle_deg:
		return false
	# 射线遮挡
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.4,
		BattleState.player_position + Vector3.UP * 1.2
	)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider = hit.get("collider")
	if collider and (collider.is_in_group("player") or (collider.get_parent() and collider.get_parent().is_in_group("player"))):
		return true
	return false

func _shoot_player() -> void:
	shoot_cooldown = 1.6
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("take_damage"):
		# 简化命中：看见且距离内约 55% 命中
		if randf() < 0.55:
			player.take_damage(1, self)
			EventBus.status_message.emit("你被击中！", 1.2)

func take_damage(amount: int = 1, _source: Node = null) -> void:
	if not alive:
		return
	alive = false
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if _mesh:
		_mesh.material_override.albedo_color = Color(0.15, 0.15, 0.15)
	EventBus.enemy_killed.emit(enemy_id, role)
	if role == &"engineer":
		var bm := get_tree().get_first_node_in_group("battle_manager")
		if bm and bm.has_method("notify_engineer_down"):
			bm.notify_engineer_down()
	BattleState.log_event("敌军倒下：%s" % role)

func _on_player_fired(origin: Vector3, _dir: Vector3) -> void:
	if not alive:
		return
	if global_position.distance_to(origin) <= hear_gunshot_range:
		known_player_pos = origin
		has_player_contact = true
		if state in [State.SEARCH, State.APPROACH, State.WAIT]:
			state = State.COMBAT

func _on_shout(origin: Vector3) -> void:
	if not alive:
		return
	if global_position.distance_to(origin) <= 15.0:
		known_player_pos = origin
		has_player_contact = true
		if state in [State.SEARCH, State.APPROACH, State.WAIT]:
			state = State.COMBAT

func _on_alarm(_by_player: bool) -> void:
	move_speed = minf(move_speed * 1.45, 2.8)
	if state == State.WAIT:
		state = State.APPROACH

func _on_retreat_signal() -> void:
	if alive:
		state = State.RETREAT

func _on_entrance_found(entrance_id: StringName, _by: StringName) -> void:
	if role == &"rifleman" and state == State.SEARCH:
		for e in get_tree().get_nodes_in_group("entrances"):
			if e.has_method("get_entrance_id") and e.get_entrance_id() == entrance_id:
				target_entrance = e
				state = State.PROBE
				break

func _pick_search_point() -> Node3D:
	var points := get_tree().get_nodes_in_group("search_points")
	if points.is_empty():
		points = get_tree().get_nodes_in_group("entrances")
	if points.is_empty():
		return null
	return points[randi() % points.size()] as Node3D
