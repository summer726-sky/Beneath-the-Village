extends CharacterBody3D
class_name EnemyAI
## 敌军有限状态机：搜索、还击、守洞、探洞、灌水、撤退。无全图透视。

enum State { WAIT, SIDE_HOLD, SIDE_ENTER, APPROACH, SEARCH, COMBAT, GUARD_HOLE, PROBE, FLOOD, ESCORT, RETREAT, DEAD }

@export var role: StringName = &"rifleman"  # commander / rifleman / engineer
@export var move_speed: float = 2.4
@export var sight_range: float = 18.0
@export var sight_angle_deg: float = 70.0
@export var hear_gunshot_range: float = 28.0
@export var enemy_id: StringName = &"enemy"
@export var flank_sign: float = 1.0  # +1 北侧 / -1 南侧入视野

@onready var vision: RayCast3D = $VisionRay

var state: State = State.SIDE_HOLD
var route: Array[Vector3] = []
var route_i: int = 0
var alive: bool = true
var has_long_gun: bool = true
var duty: String = "point"
var _hold_released := false
var _sidestepped := false
var _counter_slot := -1
var _counter_rushed := false
var _aiming := false
var _pose := &"idle"
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
var _mesh: Node3D
var _head: MeshInstance3D
var _stand_scale := Vector3.ONE
var _escort_target: Node3D = null
var _entry_mouth_id: StringName = &""
var _lost_timer: float = 0.0
var _cover_target: Vector3 = Vector3.ZERO
var _has_cover: bool = false
var _cover_hold: float = 0.0
var _cover_cd: float = 0.0  # 离开掩体后的搜索窗口，避免立刻再贴回

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
	EventBus.gunshot.connect(_on_gunshot)
	_build_visual()

func get_role() -> StringName:
	return role

func is_alive() -> bool:
	return alive

func _build_visual() -> void:
	var role_name := "步枪手"
	var tint := Color(0.96, 0.93, 0.86)
	match role:
		&"commander":
			role_name = "分队长"
			tint = Color(0.88, 0.84, 0.74)
		&"engineer":
			role_name = "工兵"
			tint = Color(0.9, 0.86, 0.72)
	var path := "res://assets/characters/ija_soldier.glb"
	if ResourceLoader.exists("res://assets/characters/ija_soldier_rig.glb"):
		path = "res://assets/characters/ija_soldier_rig.glb"
	elif ResourceLoader.exists("res://assets/characters/ija_soldier_apose.glb"):
		path = "res://assets/characters/ija_soldier_apose.glb"
	var body := ActorMesh.place(self, path, 1.68, tint)
	if body:
		_mesh = body
		_stand_scale = body.scale
	else:
		var box_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.62, 1.75, 0.42)
		box_mesh.mesh = box
		box_mesh.position.y = 0.9
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		box_mesh.material_override = mat
		add_child(box_mesh)
		_mesh = box_mesh
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.16
		head_mesh.height = 0.32
		head.mesh = head_mesh
		head.position = Vector3(0, 1.85, 0)
		head.material_override = mat
		add_child(head)
		_head = head
		_stand_scale = Vector3.ONE
	var tag := Label3D.new()
	tag.set_script(load("res://scripts/world/nameplate.gd"))
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
	_tick_recon_counter(delta)
	if state in [State.SIDE_HOLD, State.SIDE_ENTER]:
		_do_side_phase(delta)
		_try_perceive(delta)
		move_and_slide()
		return
	if _hold_back(delta):
		_set_pose(&"aim" if _aiming else &"idle")
		move_and_slide()
		return
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
		State.ESCORT:
			_do_escort(delta)
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

func _do_side_phase(delta: float) -> void:
	# 开局侧向潜伏 → 随机 5–10s 后切入侦察树视野 → 再西进
	if BattleState.enemy_reveal_at <= 0.0:
		BattleState.enemy_reveal_at = BattleState.now_sec() + randf_range(BattleState.SIDE_ENTER_MIN, BattleState.SIDE_ENTER_MAX)
	if state == State.SIDE_HOLD:
		velocity.x = 0.0
		velocity.z = 0.0
		var face := Vector3(22.0, global_position.y, 0.0)
		if global_position.distance_squared_to(face) > 0.05:
			look_at(face, Vector3.UP)
		_set_pose(&"idle")
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0.0
		if BattleState.now_sec() >= BattleState.enemy_reveal_at or BattleState.recon_exposed or BattleState.alarm_rung:
			state = State.SIDE_ENTER
		return
	# SIDE_ENTER：沿 Z 切入视野中心线
	var enter := Vector3(clampf(global_position.x, 24.0, 28.5), global_position.y, flank_sign * 0.8)
	var spd := BattleState.APPROACH_BASE_SPEED * 1.35
	if BattleState.recon_exposed:
		spd *= BattleState.RECON_RUSH
	_move_toward(enter, delta, spd)
	_set_pose(&"run" if spd > 1.2 else &"walk")
	if absf(global_position.z) < 3.0 and global_position.x > 20.0:
		state = State.APPROACH
		route_i = 0
	elif global_position.distance_to(enter) < 1.2:
		state = State.APPROACH
		route_i = 0

func _do_approach(delta: float) -> void:
	# 侧向现身后西进；总耗时对齐 ARRIVAL_BUDGET（敲钟+隐蔽+3s）
	var spd := BattleState.APPROACH_BASE_SPEED if not BattleState.alarm_rung else move_speed
	if BattleState.recon_exposed and not BattleState.alarm_rung:
		spd *= BattleState.RECON_RUSH
		if has_long_gun and shoot_cooldown <= 0.0 and _can_see_player():
			_shoot_player()
	_set_pose(&"run" if spd > 1.2 else &"walk")
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
	if BattleState.recon_exposed and not BattleState.alarm_rung and shoot_cooldown <= 0.0:
		_engage_fire()
	if role == &"engineer" and BattleState.alarm_rung and not BattleState.water_started and _combat_mouth_found():
		var well := get_tree().get_first_node_in_group("well")
		if well and global_position.distance_to((well as Node3D).global_position) < 1.5:
			_pour_wait += delta
			velocity.x = 0.0
			velocity.z = 0.0
			_set_pose(&"idle")
			if _pour_wait >= 2.0:
				state = State.FLOOD
				EventBus.water_started.emit()
		elif well:
			_pour_wait = 0.0
			_move_toward((well as Node3D).global_position, delta, _recon_pace())
			_set_pose(&"walk")
		return
	# 警报后定时主动探洞（不依赖玩家先发现）
	if BattleState.alarm_rung and role == &"rifleman" and search_timer > 6.0 and not _tunnel_occupied():
		if _combat_mouth_found() or _any_discovered_mouth():
			_begin_probe()
			search_timer = 0.0
			return
	# 地表先短暂贴掩体，再留出窗口去搜洞口
	if global_position.y > -1.0 and _seek_cover(delta, false):
		return
	if target_entrance == null or global_position.distance_to(target_entrance.global_position) < 1.2:
		target_entrance = _pick_search_point()
	if target_entrance:
		_move_toward(target_entrance.global_position, delta, _recon_pace())
		_set_pose(&"run" if _recon_pace() > 1.2 else &"walk")

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
		if global_position.y > -1.0 and _seek_cover(delta, true):
			return
		if to_player.length() > 11.0:
			_move_toward(known_player_pos, delta)
			_set_pose(&"run")
		elif shoot_cooldown <= 0.0:
			_engage_fire()
			_set_pose(&"aim")
	elif BattleState.player_in_tunnel and _descended:
		var exposed := BattleState.firing_port_expose_time > 0.0
		var close := to_player.length() < 6.5 and _can_see_player()
		if (exposed or close) and shoot_cooldown <= 0.0:
			_engage_fire()
			_set_pose(&"aim")
		elif to_player.length() > 2.2:
			_move_toward(known_player_pos, delta, move_speed * 0.55)
			_set_pose(&"walk")
	elif BattleState.player_in_tunnel and not _descended:
		if role == &"rifleman" and not _tunnel_occupied() and _combat_mouth_found():
			_begin_probe()
		else:
			state = State.SEARCH

func _seek_cover(delta: float, peek_fire: bool) -> bool:
	# 战斗中贴掩体射击；搜索态只短暂借掩体，随后强制留出搜洞窗口
	_cover_hold = maxf(0.0, _cover_hold - delta)
	_cover_cd = maxf(0.0, _cover_cd - delta)
	if not peek_fire and _cover_cd > 0.0:
		return false
	if not peek_fire and _has_cover and _cover_hold <= 0.0:
		_has_cover = false
		_cover_cd = randf_range(4.0, 7.0)
		return false
	if not _has_cover:
		var c := _nearest_cover(14.0)
		if c == Vector3.ZERO:
			return false
		_cover_target = c
		_has_cover = true
		_cover_hold = randf_range(1.8, 3.2) if not peek_fire else randf_range(2.8, 5.0)
	var dist := global_position.distance_to(_cover_target)
	if dist > 1.1:
		_move_toward(_cover_target, delta, move_speed * 1.15)
		_set_pose(&"run" if move_speed > 1.2 else &"walk")
		return true
	velocity.x = 0.0
	velocity.z = 0.0
	_set_pose(&"cover" if not peek_fire else &"aim")
	if peek_fire and shoot_cooldown <= 0.0:
		_engage_fire()
	return true

func _any_discovered_mouth() -> bool:
	for e in get_tree().get_nodes_in_group("entrances"):
		if bool(e.get("discovered")) and bool(e.get("discoverable")) and bool(e.get("enters_tunnel")):
			return true
	return false

func _nearest_cover(max_dist: float) -> Vector3:
	var best := Vector3.ZERO
	var best_d := max_dist
	for n in get_tree().get_nodes_in_group("cover_points"):
		if n is Node3D:
			var d := global_position.distance_to((n as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = (n as Node3D).global_position
	return best

func _do_guard(delta: float) -> void:
	if target_entrance:
		_move_toward(target_entrance.global_position, delta)
		if global_position.distance_to(target_entrance.global_position) < 1.5 and shoot_cooldown <= 0.0:
			if BattleState.player_in_tunnel and BattleState.firing_port_expose_time > 0.0:
				_engage_fire()

func _do_probe(delta: float) -> void:
	# 地道内：移速、反应、准头低于我方；易迷路进死路；更久才摸到其他出口
	if target_entrance == null:
		state = State.SEARCH
		return
	has_long_gun = false
	var tun_spd := move_speed * BattleState.TUNNEL_ENEMY_SPEED
	if not _descended:
		_move_toward(target_entrance.global_position, delta, tun_spd * 0.9)
		if global_position.distance_to(target_entrance.global_position) < 1.15 and target_entrance.has_method("interact"):
			_return_pos = global_position
			if target_entrance.has_method("get_entrance_id"):
				_entry_mouth_id = target_entrance.get_entrance_id()
			target_entrance.interact(self)
			_descended = true
			_probe_time = 0.0
			_probe_i = 0
			_lost_timer = 0.0
			_fit_tunnel_body(true)
			_build_probe_path()
		return
	_probe_time += delta
	if _lost_timer > 0.0:
		_lost_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return
	# 需更长时间才摸清岔路；默认从原入口退出
	if _probe_time > 58.0 or _probe_i >= _probe_path.size():
		_exit_probe()
		return
	var dest: Vector3 = _probe_path[_probe_i]
	if global_position.distance_to(dest) < 1.15:
		_probe_i += 1
		if randf() < 0.18:
			_lost_timer = randf_range(1.2, 2.8)
			BattleState.log_event("敌军在地道里迷路片刻")
		return
	_move_toward(dest, delta, tun_spd)
	_check_tunnel_devices()

func begin_escort(villager: Node3D) -> void:
	_escort_target = villager
	state = State.ESCORT
	_hold_released = true

func clear_escort() -> void:
	_escort_target = null
	if state == State.ESCORT and alive:
		state = State.SEARCH

func _do_escort(delta: float) -> void:
	if _escort_target == null or not is_instance_valid(_escort_target):
		clear_escort()
		return
	var rally := get_tree().get_first_node_in_group("prisoner_rally") as Node3D
	var dest := rally.global_position if rally else Vector3(22.0, 0.2, 1.2)
	# 若在地道里先回到地面再押送
	if global_position.y < -1.0 and _return_pos != Vector3.ZERO:
		global_position = _return_pos
		_descended = false
		_fit_tunnel_body(false)
		has_long_gun = true
	_move_toward(dest, delta, move_speed * 0.95)
	if global_position.distance_to(dest) < 2.0:
		if _escort_target.has_method("_complete_transfer"):
			_escort_target._complete_transfer()
		clear_escort()

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
		return move_speed * BattleState.RECON_RUSH
	return move_speed

func _move_toward(pos: Vector3, _delta: float, spd: float = -1.0) -> void:
	if spd < 0.0:
		spd = move_speed
	var dest := pos
	# 翻板杀过人之后：敌军知道要踩中间木轴（不是因为坑可见）
	if BattleState.trap_sprung or not BattleState.trap_lethal:
		var nearest: Node3D = null
		var best := 2.4
		for n in get_tree().get_nodes_in_group("flip_trap"):
			var trap := n as Node3D
			if trap == null:
				continue
			var d := global_position.distance_to(trap.global_position)
			if d < best:
				best = d
				nearest = trap
		if nearest:
			dest = nearest.global_position
	var dir := dest - global_position
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
	if state == State.DEAD or state == State.RETREAT or state == State.ESCORT:
		return
	if _can_see_player():
		known_player_pos = BattleState.player_position
		has_player_contact = true
		lose_sight_timer = 0.0
		var hold_route := BattleState.recon_exposed and not BattleState.alarm_rung
		if not hold_route and state in [State.SEARCH, State.APPROACH, State.SIDE_ENTER, State.SIDE_HOLD, State.GUARD_HOLE]:
			state = State.COMBAT
	# 枪孔暴露还击
	if BattleState.firing_port_expose_time > 0.0 and state == State.SEARCH:
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
	var on_surface := global_position.y > -1.0
	var rushed := BattleState.recon_exposed and not BattleState.alarm_rung
	if on_surface:
		shoot_cooldown = 0.7 if rushed else 0.85
	else:
		# 地道内反应慢、准头低
		shoot_cooldown = 2.25
	_aiming = true
	_set_pose(&"aim")
	var life := get_node_or_null("ActorLife")
	if life and life.has_method("play_fire"):
		life.play_fire()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("take_damage"):
		var chance := BattleState.TUNNEL_ENEMY_HIT
		if on_surface:
			chance = 0.88 if rushed else 0.8
		var muzzle := global_position + Vector3.UP * 1.35 + (-global_transform.basis.z) * 0.55
		if life and life.has_method("muzzle_point"):
			muzzle = life.muzzle_point()
		EventBus.muzzle_flash.emit(muzzle, BattleState.player_position + Vector3.UP * 1.2, true)
		if randf() < chance:
			player.take_damage(1, self)

func take_damage(amount: int = 1, _source: Node = null) -> void:
	if not alive:
		return
	alive = false
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_set_pose(&"dead")
	EventBus.actor_hit.emit(global_position + Vector3.UP * 1.1, enemy_id)
	if _mesh:
		ActorMesh.mark_down(_mesh)
	EventBus.enemy_killed.emit(enemy_id, role)
	if role == &"engineer":
		var bm := get_tree().get_first_node_in_group("battle_manager")
		if bm and bm.has_method("notify_engineer_down"):
			bm.notify_engineer_down()
	BattleState.log_event("敌军倒下：%s" % role)

func fall_into_pit(at: Vector3) -> void:
	if not alive:
		return
	global_position = at
	take_damage(1, self)

func _set_pose(pose: StringName) -> void:
	if _pose == pose:
		return
	_pose = pose
	EventBus.actor_pose.emit(self, pose)
	var life := get_node_or_null("ActorLife")
	if life and life.has_method("set_pose"):
		life.set_pose(pose)

func _tick_recon_counter(_delta: float) -> void:
	if BattleState.recon_counter_at <= 0.0 or BattleState.alarm_rung:
		return
	if Time.get_ticks_msec() * 0.001 < BattleState.recon_counter_at:
		return
	if _counter_slot < 0:
		_assign_counter_slots()
	if _counter_slot < 0:
		return
	# 树缝开枪后两秒：三人发现射击口并反击，同时 1.4 倍加速进村。
	_hold_released = true
	if not _counter_rushed:
		_counter_rushed = true
		move_speed = minf(move_speed * BattleState.RECON_RUSH, 3.2)
	if has_long_gun and shoot_cooldown <= 0.0 and _slit_in_view():
		_aiming = true
		_shoot_slit()
	if state in [State.WAIT, State.SEARCH, State.SIDE_HOLD, State.SIDE_ENTER]:
		state = State.APPROACH

func _assign_counter_slots() -> void:
	var living: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n.has_method("is_alive") and n.is_alive()):
			continue
		if n.get("has_long_gun") != true:
			continue
		living.append(n)
	living.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	for i in mini(3, living.size()):
		living[i].set("_counter_slot", i)

func _on_gunshot(origin: Vector3) -> void:
	_on_player_fired(origin, Vector3.ZERO)

func _hold_back(delta: float) -> bool:
	if _hold_released:
		return false
	if duty == "rear":
		if BattleState.alarm_rung:
			_hold_released = true
			state = State.APPROACH
			return false
		velocity.x = 0.0
		velocity.z = 0.0
		var face := Vector3(22.0, global_position.y, 0.0)
		if global_position.distance_squared_to(face) > 0.05:
			look_at(face, Vector3.UP)
		shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
		if BattleState.recon_exposed and has_long_gun and shoot_cooldown <= 0.0:
			_shoot_slit()
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0.0
		return true
	if duty == "late":
		if BattleState.alarm_rung or _point_rifleman_down():
			_hold_released = true
			state = State.APPROACH
			return false
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0.0
		return true
	if duty == "commander" and BattleState.recon_exposed and not BattleState.alarm_rung and not _sidestepped:
		var cover := Vector3(16.0, global_position.y, 8.2)
		if global_position.distance_to(cover) > 1.6:
			_move_toward(cover, delta, move_speed * 1.5)
			return true
		_sidestepped = true
	return false

func _point_rifleman_down() -> bool:
	var up := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if str(n.get("duty")) == "point" and n.has_method("is_alive") and n.is_alive():
			up += 1
	return up < 2

func _engage_fire() -> void:
	if not has_long_gun or shoot_cooldown > 0.0:
		return
	if _can_see_player():
		_shoot_player()
		return
	var ally := _visible_ally()
	if ally:
		_shoot_actor(ally)
		return
	if BattleState.firing_port_expose_time > 0.0 and _slit_in_view():
		_shoot_slit()

func _shoot_actor(body: Node3D) -> void:
	var inside := global_position.y < -1.0
	shoot_cooldown = 2.25 if inside else 0.85
	_aiming = true
	_set_pose(&"aim")
	var life := get_node_or_null("ActorLife")
	if life and life.has_method("play_fire"):
		life.play_fire()
	var origin := global_position + Vector3.UP * 1.25
	if life and life.has_method("muzzle_point"):
		origin = life.muzzle_point()
	EventBus.muzzle_flash.emit(origin, body.global_position + Vector3.UP * 1.1, true)
	var chance := BattleState.TUNNEL_ENEMY_HIT if inside else 0.8
	if randf() < chance and body.has_method("take_damage"):
		body.take_damage(1, self)

func _shoot_slit() -> void:
	shoot_cooldown = 0.85
	_aiming = true
	_set_pose(&"aim")
	var life := get_node_or_null("ActorLife")
	if life and life.has_method("play_fire"):
		life.play_fire()
	var slit := BattleState.firing_port_position
	if slit == Vector3.ZERO:
		slit = Vector3(22.73, 1.45, 0.0)
	var origin := global_position + Vector3.UP * 1.4
	if life and life.has_method("muzzle_point"):
		origin = life.muzzle_point()
	EventBus.muzzle_flash.emit(origin, slit, false)

func _slit_in_view() -> bool:
	var slit := BattleState.firing_port_position
	if slit == Vector3.ZERO:
		slit = Vector3(22.73, 1.45, 0.0)
	if global_position.distance_to(slit) > sight_range:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, slit)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	return global_position.distance_to(hit.position) > global_position.distance_to(slit) - 1.4

func _visible_ally() -> Node3D:
	var best: Node3D = null
	var best_d := sight_range
	for n in get_tree().get_nodes_in_group("allies"):
		if not (n is Node3D) or not n.has_method("is_alive") or not n.is_alive():
			continue
		var ally := n as Node3D
		var to := ally.global_position - global_position
		var dist := to.length()
		if dist > best_d or dist < 0.05:
			continue
		if rad_to_deg((-global_transform.basis.z).angle_to(to.normalized())) > sight_angle_deg:
			continue
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, ally.global_position + Vector3.UP * 1.1)
		query.exclude = [get_rid()]
		query.collision_mask = 1 | 8
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var col = hit.get("collider")
		if col == ally or col.get_parent() == ally:
			best = ally
			best_d = dist
	return best

func _on_player_fired(origin: Vector3, _dir: Vector3) -> void:
	if not alive or BattleState.exploring:
		return
	if global_position.distance_to(origin) <= hear_gunshot_range:
		known_player_pos = origin
		has_player_contact = true
		if not BattleState.alarm_rung:
			BattleState.recon_exposed = true
			if state == State.SIDE_HOLD:
				state = State.SIDE_ENTER
			return
		if state in [State.SEARCH, State.APPROACH, State.SIDE_ENTER, State.SIDE_HOLD, State.WAIT]:
			state = State.COMBAT

func _on_shout(origin: Vector3) -> void:
	if not alive:
		return
	if global_position.distance_to(origin) <= 15.0:
		known_player_pos = origin
		has_player_contact = true
		if state in [State.SEARCH, State.APPROACH, State.SIDE_ENTER, State.SIDE_HOLD, State.WAIT]:
			state = State.COMBAT

func _on_alarm(_by_player: bool) -> void:
	move_speed = minf(move_speed * 1.45, 2.8)
	if state in [State.WAIT, State.SIDE_HOLD]:
		state = State.SIDE_ENTER
	elif state == State.SIDE_ENTER:
		pass
	elif state == State.APPROACH:
		pass

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
		_mesh.rotation.x = 0.42 if inside else 0.0
	if _head:
		_head.position.y = 1.22 if inside else 1.85

func _build_probe_path() -> void:
	_probe_path.clear()
	var y := global_position.y
	var mouth := get_tree().get_first_node_in_group("combat_flip")
	if mouth and mouth.has_method("is_dead_open") and mouth.is_dead_open():
		_probe_path.append(Vector3(2.6, y, -6.4))
		_probe_path.append(Vector3(2.6, y, -3.2))
	# 一定概率先走进死路再折返（地道不熟）
	if randf() < 0.45:
		_probe_path.append(Vector3(2.6, y, 2.4))
		_probe_path.append(Vector3(2.6, y, 0.15))
	_probe_path.append(Vector3(7.2, y, 0.0))
	_probe_path.append(Vector3(8.2, y, 0.0))
	_probe_path.append(Vector3(2.6, y, 0.15))
	_probe_path.append(Vector3(-6.2, y, 0.4))
	# 后半段才摸向北房/井侧/西廊翻板（其他出口更难发现）
	_probe_path.append(Vector3(-4.2, y, 0.2))
	_probe_path.append(Vector3(-6.2, y, 0.4))
	if randf() < 0.4:
		_probe_path.append(Vector3(-14.5, y, 0.0))
		_probe_path.append(Vector3(-18.2, y, 0.0))
		_probe_path.append(Vector3(-14.5, y, 0.0))
		_probe_path.append(Vector3(-6.2, y, 0.4))
	if randf() < 0.55:
		_probe_path.append(Vector3(-6.2, y, 4.6))
	if randf() < 0.28:
		_probe_path.append(Vector3(-10.0, y, -1.8))
		_probe_path.append(Vector3(-6.2, y, 0.4))

func _exit_probe() -> void:
	# 默认从进来的口出去；其他出口要额外时间才「发现」
	if _return_pos != Vector3.ZERO:
		global_position = _return_pos
	_descended = false
	has_long_gun = true
	_fit_tunnel_body(false)
	_probe_time = 0.0
	_probe_i = 0
	_lost_timer = 0.0
	# 探洞后对「非入口」的发现要更慢：未满 50s 不当作摸清全图
	state = State.SEARCH

func _check_tunnel_devices() -> void:
	for n in get_tree().get_nodes_in_group("flip_trap"):
		var trap := n as Node3D
		if trap == null or global_position.distance_to(trap.global_position) >= 1.2:
			continue
		# 已触发后主动踩木轴中线，不再尝试机关
		if BattleState.trap_sprung or not BattleState.trap_lethal:
			var center := trap.global_position
			global_position.x = lerpf(global_position.x, center.x, 0.55)
			global_position.z = lerpf(global_position.z, center.z, 0.55)
		elif trap.has_method("try_trigger_from"):
			# 第一次可踩偏触发：略偏中心
			if absf(to_local_trap_x(trap)) < 0.08:
				global_position += trap.global_transform.basis.x * 0.35
			trap.try_trigger_from(self)
	var wire := get_tree().get_first_node_in_group("trip_wire")
	if wire and global_position.distance_to((wire as Node3D).global_position) < 0.8 and wire.has_method("try_trigger_from"):
		wire.try_trigger_from(self)

func to_local_trap_x(trap: Node3D) -> float:
	return trap.to_local(global_position).x

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
