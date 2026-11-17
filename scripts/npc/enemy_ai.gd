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
var _pour_wait: float = 0.0
var _probe_time: float = 0.0
var _probe_i: int = 0
var _return_pos: Vector3 = Vector3.ZERO
var _probe_path: Array[Vector3] = []
var _mesh: MeshInstance3D
var _head: MeshInstance3D

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
	_head = head
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
	if BattleState.recon_exposed and not BattleState.alarm_rung:
		spd *= 1.75
		if has_long_gun and shoot_cooldown <= 0.0 and _can_see_player():
			_shoot_player()
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
	if BattleState.recon_exposed and not BattleState.alarm_rung and has_long_gun and shoot_cooldown <= 0.0 and _can_see_player():
		_shoot_player()
	if role == &"engineer" and BattleState.alarm_rung and not BattleState.water_started and _combat_mouth_found():
		var well := get_tree().get_first_node_in_group("well")
		if well and global_position.distance_to((well as Node3D).global_position) < 1.5:
			_pour_wait += delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _pour_wait >= 2.0:
				state = State.FLOOD
				EventBus.water_started.emit()
		elif well:
			_pour_wait = 0.0
			_move_toward((well as Node3D).global_position, delta, _recon_pace())
		return
	if target_entrance == null or global_position.distance_to(target_entrance.global_position) < 1.2:
		target_entrance = _pick_search_point()
	if target_entrance:
		_move_toward(target_entrance.global_position, delta, _recon_pace())

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
	if has_player_contact and not BattleState.player_in_tunnel:
		if to_player.length() > 11.0:
			_move_toward(known_player_pos, delta)
		elif shoot_cooldown <= 0.0 and (_can_see_player() or BattleState.firing_port_expose_time > 0.0):
			_shoot_player()
	elif BattleState.player_in_tunnel and _descended:
		var exposed := BattleState.firing_port_expose_time > 0.0
		var close := to_player.length() < 6.5 and _can_see_player()
		if (exposed or close) and shoot_cooldown <= 0.0:
			_shoot_player()
		elif to_player.length() > 2.2:
			_move_toward(known_player_pos, delta, move_speed * 0.55)
	elif BattleState.player_in_tunnel and not _descended:
		if role == &"rifleman" and not _tunnel_occupied() and _combat_mouth_found():
			_begin_probe()
		else:
			state = State.SEARCH

func _do_guard(delta: float) -> void:
	if target_entrance:
		_move_toward(target_entrance.global_position, delta)
		if global_position.distance_to(target_entrance.global_position) < 1.5 and shoot_cooldown <= 0.0:
			if BattleState.player_in_tunnel and BattleState.firing_port_expose_time > 0.0:
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
			_return_pos = global_position
			target_entrance.interact(self)
			_descended = true
			_probe_time = 0.0
			_probe_i = 0
			_fit_tunnel_body(true)
			_build_probe_path()
		return
	_probe_time += delta
	if _probe_time > 40.0 or _probe_i >= _probe_path.size():
		_exit_probe()
		return
	var dest: Vector3 = _probe_path[_probe_i]
	if global_position.distance_to(dest) < 1.15:
		_probe_i += 1
		return
	_move_toward(dest, delta, move_speed * 0.55)
	_check_tunnel_devices()

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

func _recon_pace() -> float:
	if BattleState.recon_exposed and not BattleState.alarm_rung:
		return move_speed * 1.75
	return move_speed

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
		var hold_route := BattleState.recon_exposed and not BattleState.alarm_rung
		if not hold_route and state in [State.SEARCH, State.APPROACH, State.GUARD_HOLE]:
			state = State.COMBAT
	# 枪孔暴露还击
	if BattleState.player_at_firing_port and BattleState.firing_port_expose_time >= 8.0:
		if state == State.SEARCH:
			state = State.COMBAT

func _can_see_player() -> bool:
	if BattleState.player_in_lookout and not BattleState.lookout_exposed and not BattleState.recon_exposed:
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
	var eye_h := 1.42 if BattleState.player_in_lookout else (0.95 if BattleState.player_in_tunnel else 1.2)
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.4,
		BattleState.player_position + Vector3.UP * eye_h
	)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider = hit.get("collider")
	if collider and (collider.is_in_group("player") or (collider.get_parent() and collider.get_parent().is_in_group("player"))):
		return true
	return false

func _shoot_player() -> void:
	var on_surface := not BattleState.player_in_tunnel
	var rushed := BattleState.recon_exposed and not BattleState.alarm_rung
	if on_surface:
		shoot_cooldown = 0.7 if rushed else 0.85
	else:
		shoot_cooldown = 1.7
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("take_damage"):
		var chance := 0.45
		if on_surface:
			chance = 0.88 if rushed else 0.8
		if randf() < chance:
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
	if not alive or BattleState.exploring:
		return
	if global_position.distance_to(origin) <= hear_gunshot_range:
		known_player_pos = origin
		has_player_contact = true
		if not BattleState.alarm_rung:
			BattleState.recon_exposed = true
			return
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
	if role == &"rifleman" and state == State.SEARCH and not _tunnel_occupied():
		for e in get_tree().get_nodes_in_group("entrances"):
			if e.has_method("get_entrance_id") and e.get_entrance_id() == entrance_id:
				target_entrance = e
				state = State.PROBE
				break

func _tunnel_occupied() -> bool:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == self:
			continue
		if bool(n.get("_descended")) and n.has_method("is_alive") and n.is_alive():
			return true
	return false

func _begin_probe() -> void:
	for e in get_tree().get_nodes_in_group("entrances"):
		if not bool(e.get("discovered")) or not bool(e.get("discoverable")):
			continue
		if not bool(e.get("enters_tunnel")):
			continue
		target_entrance = e
		state = State.PROBE
		return

func _fit_tunnel_body(inside: bool) -> void:
	var h := 1.15 if inside else 1.6
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		(col.shape as CapsuleShape3D).height = h
		col.position.y = h * 0.5
	if _mesh:
		_mesh.scale.y = 0.62 if inside else 1.0
		_mesh.position.y = 0.55 if inside else 0.9
	if _head:
		_head.position.y = 1.22 if inside else 1.85

func _build_probe_path() -> void:
	_probe_path.clear()
	var y := global_position.y
	var mouth := get_tree().get_first_node_in_group("combat_flip")
	if mouth and mouth.has_method("is_dead_open") and mouth.is_dead_open():
		_probe_path.append(Vector3(2.6, y, -6.4))
		_probe_path.append(Vector3(2.6, y, -3.2))
	_probe_path.append(Vector3(7.2, y, 0.0))
	_probe_path.append(Vector3(8.2, y, 0.0))
	_probe_path.append(Vector3(2.6, y, 0.15))
	_probe_path.append(Vector3(-6.2, y, 0.4))
	_probe_path.append(Vector3(-6.2, y, 4.6))

func _exit_probe() -> void:
	if _return_pos != Vector3.ZERO:
		global_position = _return_pos
	_descended = false
	has_long_gun = true
	_fit_tunnel_body(false)
	_probe_time = 0.0
	_probe_i = 0
	state = State.SEARCH

func _check_tunnel_devices() -> void:
	var trap := get_tree().get_first_node_in_group("flip_trap")
	if trap and global_position.distance_to((trap as Node3D).global_position) < 1.2 and trap.has_method("try_trigger_from"):
		trap.try_trigger_from(self)
	var wire := get_tree().get_first_node_in_group("trip_wire")
	if wire and global_position.distance_to((wire as Node3D).global_position) < 0.8 and wire.has_method("try_trigger_from"):
		wire.try_trigger_from(self)

func _combat_mouth_found() -> bool:
	for e in get_tree().get_nodes_in_group("entrances"):
		if not bool(e.get("discovered")) or not bool(e.get("discoverable")):
			continue
		if not bool(e.get("enters_tunnel")):
			continue
		var id: StringName = e.get_entrance_id() if e.has_method("get_entrance_id") else &""
		if id == &"east_house" or id == &"well" or id == &"trough":
			return true
	return false

func _pick_search_point() -> Node3D:
	var points := get_tree().get_nodes_in_group("search_points")
	if points.is_empty():
		points = get_tree().get_nodes_in_group("entrances")
	if points.is_empty():
		return null
	return points[randi() % points.size()] as Node3D
