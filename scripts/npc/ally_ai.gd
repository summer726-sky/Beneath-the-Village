extends CharacterBody3D
class_name AllyAI
## 战友：可指派任务；无任务时自由移动、规划攻击；走近自动报下一步。

enum Command {
	FREE, ## 自行决策 / 配合玩家
	PROTECT_SHELTER, ## 在村民隐蔽点附近保护
	AMBUSH_ENTRANCE, ## 在地道入口或房屋枪眼伏击
	HOLD_PORT, ## 守射击孔
	CLOSE_BARRIER, ## 关隔板
	COOPERATE, ## 配合玩家作战
}

const COMMAND_CYCLE := [
	Command.FREE,
	Command.PROTECT_SHELTER,
	Command.AMBUSH_ENTRANCE,
	Command.HOLD_PORT,
	Command.CLOSE_BARRIER,
	Command.COOPERATE,
]

@export var ally_name: StringName = &"甲"
@export var default_command: Command = Command.FREE
@export var move_speed: float = 3.0

var command: Command = Command.FREE
var alive: bool = true
var _feedback: String = "自行配合"
var _mesh: Node3D
var _shot_cd := 0.0
var _aiming := false
var _pose := &"idle"
var _assigned := false
var _task_done := false
var _near_said := false
var _strategy_cd := 0.0
var _alarm_attempted := false
var _patrol_i := 0
var _think_cd := 0.0
var _barrier_hold := 0.0

func _ready() -> void:
	add_to_group("allies")
	add_to_group("interactable")
	command = Command.FREE
	_feedback = _command_label(command)
	_build_visual()

func _build_visual() -> void:
	var path := "res://assets/characters/militia_young.glb"
	var tint := Color(0.9, 0.94, 1.0)
	var height := 1.72
	if ally_name == &"甲":
		path = "res://assets/characters/militia_jia.glb"
		tint = Color.WHITE
		height = 1.7
	if ResourceLoader.exists("res://assets/characters/militia_rig.glb"):
		path = "res://assets/characters/militia_rig.glb"
	elif ResourceLoader.exists("res://assets/characters/militia_apose.glb"):
		path = "res://assets/characters/militia_apose.glb"
	var body := ActorMesh.place(self, path, height, tint)
	if body:
		_mesh = body
	else:
		var box_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.58, 1.7, 0.38)
		box_mesh.mesh = box
		box_mesh.position.y = 0.85
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.18, 0.26) if ally_name == &"甲" else Color(0.28, 0.34, 0.42)
		box_mesh.material_override = mat
		add_child(box_mesh)
		_mesh = box_mesh
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.15
		head_mesh.height = 0.3
		head.mesh = head_mesh
		head.position = Vector3(0, 1.82, 0)
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color(0.72, 0.58, 0.42)
		head.material_override = skin
		add_child(head)
	var tag := Label3D.new()
	tag.set_script(load("res://scripts/world/nameplate.gd"))
	tag.text = "战友·%s" % str(ally_name)
	tag.font_size = 48
	tag.outline_size = 8
	tag.modulate = Color(0.75, 0.9, 1.0)
	tag.position = Vector3(0, 2.25, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.55
	cap.radius = 0.28
	col.shape = cap
	col.position.y = 0.78
	add_child(col)

func _physics_process(delta: float) -> void:
	if not alive or BattleState.battle_over:
		return
	_strategy_cd = maxf(0.0, _strategy_cd - delta)
	_think_cd = maxf(0.0, _think_cd - delta)
	_try_spot_alarm()
	_maybe_report_strategy()
	if BattleState.exploring:
		velocity = Vector3.ZERO
		_idle_face()
		_apply_gravity(delta)
		move_and_slide()
		return
	match command:
		Command.PROTECT_SHELTER:
			_do_protect_shelter(delta)
		Command.AMBUSH_ENTRANCE:
			_do_ambush(delta)
		Command.HOLD_PORT:
			_do_hold_port(delta)
		Command.CLOSE_BARRIER:
			_do_close_barrier(delta)
		Command.COOPERATE:
			_do_cooperate(delta)
		Command.FREE:
			_do_free(delta)
	_try_shoot(delta)
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

func _idle_face() -> void:
	var ahead := global_position + (-global_transform.basis.z)
	ahead.y = global_position.y
	if global_position.distance_squared_to(ahead) > 0.01:
		look_at(ahead, Vector3.UP)

func _try_spot_alarm() -> void:
	if BattleState.alarm_rung or _alarm_attempted or BattleState.exploring:
		return
	if not _sees_enemy_in_yard():
		return
	_alarm_attempted = true
	BattleState.try_speech("战友%s：有敌人进院！隐蔽！敲钟！" % ally_name, 2.6, true)
	_ring_bell_now()

func _ring_bell_now() -> void:
	var bell := get_tree().get_first_node_in_group("alarm_bell")
	if bell and bell.has_method("interact"):
		bell.interact(self)
		return
	#  bell 太远时仍发警报信号
	if not BattleState.alarm_rung:
		EventBus.alarm_triggered.emit(false)

func _sees_enemy_in_yard() -> bool:
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node3D) or not n.has_method("is_alive") or not n.is_alive():
			continue
		var foe := n as Node3D
		if foe.global_position.y < -1.0:
			continue
		if foe.global_position.x > 14.0:
			continue
		if global_position.distance_to(foe.global_position) > 22.0:
			continue
		return true
	return false

func _maybe_report_strategy() -> void:
	if BattleState.exploring or not BattleState.player_can_control:
		return
	var dist := global_position.distance_to(BattleState.player_position)
	if dist > 3.2:
		_near_said = false
		return
	if _near_said or _strategy_cd > 0.0:
		return
	_near_said = true
	_strategy_cd = 7.0
	var plan := _next_plan_line()
	BattleState.try_speech("战友%s：%s" % [ally_name, plan], 2.8)

func _next_plan_line() -> String:
	if _assigned and not _task_done:
		return "我先%s。" % _feedback
	if not BattleState.alarm_rung:
		return "钟一响我就跟你配合。走近按 F 派任务。"
	if _seen_enemy() != null:
		return "我盯住门口，你翻板那边小心。"
	if BattleState.water_started and not BattleState.water_barrier_closed:
		return "井口在灌水，我去关隔板。"
	if BattleState.villagers_safe < BattleState.villagers_total - BattleState.villagers_captured:
		return "我去北房隐蔽点附近护着村民。"
	return "我找枪眼伏击，你招呼一声。"

func _do_protect_shelter(delta: float) -> void:
	var safe := get_tree().get_first_node_in_group("villager_safe_zone") as Node3D
	var north := _entrance_by_id(&"north_house")
	var dest: Vector3
	if BattleState.player_in_tunnel and safe:
		dest = safe.global_position + Vector3(1.1, 0, -0.6)
	elif north:
		dest = north.global_position + Vector3(0.8, 0, -1.2)
	else:
		dest = Vector3(-6.2, 0.2, 6.4)
	if _move_to(dest, delta, move_speed):
		_finish_task_if_assigned("隐蔽点守住了，我自行配合")

func _do_ambush(delta: float) -> void:
	var posts: Array[Vector3] = [
		Vector3(2.4, 0.2, 1.6),
		Vector3(-4.8, 0.2, -3.6),
		Vector3(1.8, -3.6, 0.2),
		Vector3(-9.2, -3.6, -1.2),
	]
	if BattleState.player_in_tunnel:
		posts = [Vector3(2.6, -3.6, -1.0), Vector3(-4.2, -3.6, -3.8), Vector3(7.6, -3.6, 0.1)]
	var dest: Vector3 = posts[_patrol_i % posts.size()]
	if _move_to(dest, delta, move_speed):
		_patrol_i += 1
		_finish_task_if_assigned("伏击位就位，我接着自己打")

func _do_hold_port(delta: float) -> void:
	if _go_to_group("ally_port_post", delta):
		_finish_task_if_assigned("枪眼我守着")

func _do_close_barrier(delta: float) -> void:
	var post := get_tree().get_first_node_in_group("ally_barrier_post")
	if post and global_position.distance_to(post.global_position) > 1.3:
		_barrier_hold = 0.0
		_go_to_group("ally_barrier_post", delta)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	var barrier := get_tree().get_first_node_in_group("water_barrier")
	if barrier and barrier.has_method("interact") and BattleState.water_started and not BattleState.water_barrier_closed:
		# 与玩家一致：按住约三秒才关上
		var need := 3.0
		if barrier.has_method("get_hold_seconds"):
			need = float(barrier.get_hold_seconds())
		_barrier_hold += delta
		if _barrier_hold < need:
			return
		_barrier_hold = 0.0
		barrier.interact(self)
		BattleState.try_speech("战友%s：隔板放下了" % ally_name, 2.2)
		_finish_task_if_assigned("隔板好了，我自行配合")
	elif BattleState.water_barrier_closed or not BattleState.water_started:
		_barrier_hold = 0.0
		if _assigned:
			_finish_task_if_assigned("隔板这边没事，我自行配合")

func _do_cooperate(delta: float) -> void:
	var anchor := BattleState.player_position + (-_player_forward() * 1.8) + Vector3(0.9, 0, 0)
	if BattleState.player_in_tunnel:
		anchor.y = global_position.y
	_move_to(anchor, delta, move_speed * 1.05)
	if _assigned and global_position.distance_to(BattleState.player_position) < 4.0 and _seen_enemy() == null:
		# 保持配合，不立刻结束；敌人清空后再自由
		if _think_cd <= 0.0 and BattleState.enemies_alive <= 2:
			_finish_task_if_assigned("这边清了，我改自由配合")

func _do_free(delta: float) -> void:
	if not BattleState.alarm_rung:
		_wander_cover(delta)
		return
	if BattleState.water_started and not BattleState.water_barrier_closed:
		_do_close_barrier(delta)
		return
	var foe := _seen_enemy()
	if foe:
		var cover := _nearest_cover_pos(12.0)
		if cover != Vector3.ZERO and global_position.distance_to(cover) > 1.2:
			_move_to(cover, delta, move_speed)
		else:
			var to := foe.global_position
			if global_position.distance_to(to) > 9.0:
				_move_to(to, delta, move_speed)
			else:
				_move_to(to + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2)), delta, move_speed * 0.7)
		return
	if BattleState.villagers_safe < maxi(1, BattleState.villagers_total - BattleState.villagers_captured):
		_do_protect_shelter(delta)
		return
	_do_ambush(delta)

func _wander_cover(delta: float) -> void:
	var cover := _nearest_cover_pos(18.0)
	if cover != Vector3.ZERO:
		if _move_to(cover, delta, move_speed * 0.55):
			_patrol_i += 1
		return
	var spots: Array[Vector3] = [
		Vector3(-8.6, 0.2, 1.2),
		Vector3(-3.8, 0.2, -2.4),
		Vector3(-11.2, 0.2, -0.6),
		Vector3(-5.4, 0.2, 4.2),
	]
	var dest: Vector3 = spots[_patrol_i % spots.size()]
	if _move_to(dest, delta, move_speed * 0.55):
		_patrol_i += 1

func _nearest_cover_pos(max_dist: float) -> Vector3:
	var best := Vector3.ZERO
	var best_d := max_dist
	for n in get_tree().get_nodes_in_group("cover_points"):
		if n is Node3D:
			var d := global_position.distance_to((n as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = (n as Node3D).global_position
	if best != Vector3.ZERO:
		return best
	var post := get_tree().get_first_node_in_group("ally_port_post")
	if post is Node3D and global_position.distance_to((post as Node3D).global_position) < max_dist:
		return (post as Node3D).global_position
	return Vector3.ZERO

func _finish_task_if_assigned(line: String) -> void:
	if not _assigned:
		return
	_assigned = false
	_task_done = true
	command = Command.FREE
	_feedback = "自行配合"
	BattleState.try_speech("战友%s：%s" % [ally_name, line], 2.5)

func _try_shoot(delta: float) -> void:
	if not alive or BattleState.exploring or BattleState.battle_over:
		return
	if not BattleState.alarm_rung and not BattleState.recon_exposed:
		return
	_shot_cd = maxf(0.0, _shot_cd - delta)
	var foe := _seen_enemy()
	if foe == null:
		return
	var aim := foe.global_position
	aim.y = global_position.y
	if global_position.distance_squared_to(aim) > 0.04:
		look_at(aim, Vector3.UP)
	if _shot_cd > 0.0:
		return
	var inside := global_position.y < -1.0
	_shot_cd = 1.7 if inside else 0.85
	_aiming = true
	_pose = &"aim"
	var life := get_node_or_null("ActorLife")
	if life and life.has_method("play_fire"):
		life.play_fire()
	elif life and life.has_method("set_pose"):
		life.set_pose(&"aim")
	var origin := global_position + Vector3.UP * (0.95 if inside else 1.35)
	if life and life.has_method("muzzle_point"):
		origin = life.muzzle_point()
	var hit := foe.global_position + Vector3.UP * 1.05
	EventBus.gunshot.emit(origin)
	EventBus.muzzle_flash.emit(origin, hit, true)
	if randf() < (0.45 if inside else 0.8) and foe.has_method("take_damage"):
		foe.take_damage(1, self)

func _seen_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := 18.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node3D) or not n.has_method("is_alive") or not n.is_alive():
			continue
		var foe := n as Node3D
		var to := foe.global_position - global_position
		var dist := to.length()
		if dist > best_d or dist < 0.05:
			continue
		if rad_to_deg((-global_transform.basis.z).angle_to(to.normalized())) > 70.0 and dist > 2.0:
			continue
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, foe.global_position + Vector3.UP * 1.1)
		query.exclude = [get_rid()]
		query.collision_mask = 1 | 4
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var col = hit.get("collider")
		if col == foe or col.get_parent() == foe:
			best = foe
			best_d = dist
	return best

func _move_to(pos: Vector3, _delta: float, spd: float) -> bool:
	var dir := pos - global_position
	dir.y = 0
	if dir.length() <= 0.45:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	look_at(global_position + dir, Vector3.UP)
	return false

func _go_to_group(group: String, delta: float) -> bool:
	var post := get_tree().get_first_node_in_group(group)
	if post == null:
		return true
	return _move_to((post as Node3D).global_position, delta, move_speed)

func _entrance_by_id(id: StringName) -> Node3D:
	for e in get_tree().get_nodes_in_group("entrances"):
		if e.has_method("get_entrance_id") and e.get_entrance_id() == id:
			return e as Node3D
	return null

func _player_forward() -> Vector3:
	var p := get_tree().get_first_node_in_group("player")
	if p is Node3D:
		return -(p as Node3D).global_transform.basis.z
	return Vector3.FORWARD

func receive_command_cycle() -> void:
	if not alive:
		return
	var idx := COMMAND_CYCLE.find(command)
	if idx < 0:
		idx = 0
	idx = (idx + 1) % COMMAND_CYCLE.size()
	command = COMMAND_CYCLE[idx]
	_assigned = command != Command.FREE
	_task_done = false
	_feedback = _command_label(command)
	EventBus.ally_commanded.emit(ally_name, StringName(_feedback))
	BattleState.try_speech("战友%s：明白，%s。" % [ally_name, _feedback], 2.4, true)

func _command_label(cmd: Command) -> String:
	match cmd:
		Command.PROTECT_SHELTER:
			return "去村民隐蔽点附近保护"
		Command.AMBUSH_ENTRANCE:
			return "在入口或枪眼伏击"
		Command.HOLD_PORT:
			return "守射击孔"
		Command.CLOSE_BARRIER:
			return "去关隔板"
		Command.COOPERATE:
			return "配合你作战"
		_:
			return "自行配合"

func get_interact_hint() -> String:
	if not alive:
		return ""
	if BattleState.exploring:
		return "E 和战友交谈"
	return "F 派任务（当前：%s）" % _feedback

func interact(_by: Node) -> void:
	if BattleState.exploring:
		var line := "树洞能看见东边来路。地道向西通东屋，也能到井和锅台。"
		if ally_name == &"乙":
			line = "我常在井边。真打起来可派我护隐蔽点，或去关隔板。"
		else:
			line = "走近我会说下一步打算。F 从指定任务里挑：护隐蔽点、伏击、守孔、关隔板、配合你。"
		BattleState.try_speech("战友%s：%s" % [ally_name, line], 3.4, true)
		return
	receive_command_cycle()

func take_damage(_amount: int = 1, _source: Node = null) -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	_pose = &"dead"
	EventBus.actor_hit.emit(global_position + Vector3.UP * 1.1, ally_name)
	if _mesh:
		ActorMesh.mark_down(_mesh)
	EventBus.ally_died.emit(ally_name)
	BattleState.log_event("战友阵亡：%s" % ally_name)
	EventBus.status_message.emit("战友%s倒下了" % ally_name, 3.0)

func is_alive() -> bool:
	return alive
