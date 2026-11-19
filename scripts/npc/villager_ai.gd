extends CharacterBody3D
class_name VillagerAI
## 村民：默认藏到关隔板后不会被淹的北房暗室。
## 警报失败后就近入口逃窜（速度略慢于敌军）；藏点被发现再逃；不受地道机关杀伤。
## 被捕后由敌军押往瞭望树；玩家开枪未击毙押送者会被处决。

enum State { IDLE, FLEE, HIDDEN, ESCORTED, TRANSFERRED, DEAD }

@export var villager_id: StringName = &"villager"
@export var move_speed: float = 2.05

var state: State = State.IDLE
var target_entrance: Node3D = null
var blocked_ids: Array[StringName] = []
var escort: Node3D = null
var _mesh: Node3D
var _alarm_shouted := false
var _walk_to_safe := false
var _tag: Label3D

func _ready() -> void:
	add_to_group("villagers")
	add_to_group("interactable")
	villager_id = StringName("villager_%d" % get_instance_id())
	move_speed = BattleState.VILLAGER_FLEE_SPEED
	EventBus.alarm_triggered.connect(_on_alarm)
	EventBus.player_fired.connect(_on_player_fired)
	EventBus.enemy_killed.connect(_on_enemy_killed_bus)
	_build_visual()

func _build_visual() -> void:
	var path := "res://assets/characters/villager_young.glb"
	var tint := Color.WHITE
	var height := 1.56
	if name.ends_with("1"):
		path = "res://assets/characters/villager_elder.glb"
		height = 1.55
	elif name.ends_with("3"):
		if ResourceLoader.exists("res://assets/characters/villager_mid.glb"):
			path = "res://assets/characters/villager_mid.glb"
			height = 1.58
		else:
			tint = Color(0.78, 0.74, 0.68)
	# Prefer _apose over base mesh when available.
	# Villagers do NOT upgrade to _rig.glb – militia rigs are for allies only.
	var apose := path.get_basename() + "_apose.glb"
	if ResourceLoader.exists(apose):
		path = apose
	var body := ActorMesh.place(self, path, height, tint)
	if body:
		_mesh = body
	else:
		var box_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.45, 1.45, 0.3)
		box_mesh.mesh = box
		box_mesh.position.y = 0.72
		var mat := StandardMaterial3D.new()
		if name.ends_with("1"):
			mat.albedo_color = Color(0.32, 0.24, 0.18)
		elif name.ends_with("2"):
			mat.albedo_color = Color(0.22, 0.28, 0.40)
		else:
			mat.albedo_color = Color(0.36, 0.38, 0.40)
		box_mesh.material_override = mat
		add_child(box_mesh)
		_mesh = box_mesh
	_tag = Label3D.new()
	_tag.set_script(load("res://scripts/world/nameplate.gd"))
	_tag.text = "村民"
	_tag.font_size = 42
	_tag.outline_size = 8
	_tag.modulate = Color(1.0, 0.95, 0.75)
	_tag.position = Vector3(0, 2.05, 0)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_tag)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.4
	cap.radius = 0.25
	col.shape = cap
	col.position.y = 0.7
	add_child(col)

func _physics_process(delta: float) -> void:
	if state == State.TRANSFERRED or state == State.DEAD or BattleState.battle_over:
		velocity = Vector3.ZERO
		return
	if state == State.ESCORTED:
		_escort_tick(delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	if state == State.HIDDEN:
		velocity = Vector3.ZERO
		_check_hidden_discovery()
		return
	_try_spot_alarm()
	if state == State.FLEE:
		_flee(delta)
	_apply_gravity(delta)
	move_and_slide()
	_check_surface_capture()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

func get_interact_hint() -> String:
	if state in [State.TRANSFERRED, State.DEAD, State.ESCORTED]:
		return ""
	if BattleState.exploring:
		return "E 询问村民"
	return ""

func interact(_by: Node) -> void:
	if not BattleState.exploring or state != State.IDLE:
		return
	var lines := [
		"我们躲北房夹壁下的暗室——关隔板后那儿不会被淹。地图上标「藏身」。",
		"钟晚了就从最近的入口钻下去。跑得比鬼子慢一点，别堵着我们。",
		"要是人被押走，你开枪得打准。打不中，他们会对着人质开枪。"
	]
	BattleState.try_speech(lines[randi() % lines.size()], 3.4, true)

func _on_alarm(_by_player: bool) -> void:
	if state == State.IDLE or state == State.HIDDEN:
		if state == State.HIDDEN:
			return
		state = State.FLEE
		_pick_entrance()

func _try_spot_alarm() -> void:
	if BattleState.alarm_rung or _alarm_shouted or BattleState.exploring:
		return
	if state != State.IDLE:
		return
	if not _enemy_reached_yard():
		return
	_alarm_shouted = true
	BattleState.try_speech("村民：鬼子进院了！隐蔽！快往地道里钻！", 2.8, true)
	var bell := get_tree().get_first_node_in_group("alarm_bell")
	if bell and global_position.distance_to((bell as Node3D).global_position) < 10.0 and bell.has_method("interact"):
		bell.interact(self)
	elif not BattleState.alarm_rung:
		EventBus.alarm_triggered.emit(false)
	state = State.FLEE
	_pick_entrance()

func _enemy_reached_yard() -> bool:
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node3D) or not n.has_method("is_alive") or not n.is_alive():
			continue
		var foe := n as Node3D
		if foe.global_position.y < -1.0:
			continue
		if foe.global_position.x < 13.0 and foe.global_position.x > -16.0:
			if absf(foe.global_position.z) < 10.0:
				return true
	return false

func _pick_entrance() -> void:
	# 就近任一可进地道的入口，再走到默认不淹藏身点
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("entrances"):
		if not (e is Node3D):
			continue
		var ent := e as Node3D
		if ent.global_position.y < -1.0:
			continue
		var eid: StringName = ent.get_entrance_id() if ent.has_method("get_entrance_id") else StringName(ent.name)
		if eid in blocked_ids:
			continue
		if ent.has_method("is_passable") and not ent.is_passable():
			continue
		if ent.get("enters_tunnel") == false:
			continue
		if str(eid) == "lookout":
			continue
		var d := global_position.distance_to(ent.global_position)
		# 夹壁入口略优先
		if ent.get("is_shelter") == true:
			d *= 0.85
		if d < best_d:
			best_d = d
			best = ent
	target_entrance = best
	if target_entrance == null and blocked_ids.size() > 0:
		blocked_ids.clear()
		_pick_entrance()

func _flee(_delta: float) -> void:
	if _walk_to_safe:
		_walk_safe_room(_delta)
		return
	if target_entrance == null:
		_pick_entrance()
		if target_entrance == null:
			return
	if _entrance_blocked_by_player(target_entrance):
		var eid: StringName = target_entrance.get_entrance_id() if target_entrance.has_method("get_entrance_id") else StringName(target_entrance.name)
		if eid not in blocked_ids:
			blocked_ids.append(eid)
		target_entrance = null
		_pick_entrance()
		EventBus.status_message.emit("村民改道寻找其他入口", 1.5)
		return
	var pos := target_entrance.global_position
	var dir := pos - global_position
	dir.y = 0
	if dir.length() < 1.0:
		_descend_into_shelter()
		return
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	look_at(global_position + dir, Vector3.UP)

func _entrance_blocked_by_player(ent: Node3D) -> bool:
	return BattleState.player_position.distance_to(ent.global_position) < 1.1

func _descend_into_shelter() -> void:
	if target_entrance and target_entrance.has_method("interact"):
		target_entrance.interact(self)
	_walk_to_safe = true

func _walk_safe_room(_delta: float) -> void:
	var safe := get_tree().get_first_node_in_group("villager_safe_zone") as Node3D
	if safe == null:
		_enter_shelter()
		return
	var dir := safe.global_position - global_position
	dir.y = 0
	if dir.length() < 0.7:
		_enter_shelter()
		return
	dir = dir.normalized()
	velocity.x = dir.x * move_speed * 0.9
	velocity.z = dir.z * move_speed * 0.9
	look_at(global_position + dir, Vector3.UP)

func _enter_shelter() -> void:
	state = State.HIDDEN
	velocity = Vector3.ZERO
	_walk_to_safe = false
	var sid: StringName = target_entrance.get_entrance_id() if target_entrance and target_entrance.has_method("get_entrance_id") else &"shelter"
	EventBus.villager_entered_shelter.emit(villager_id, sid)
	BattleState.log_event("村民进入藏身点（关隔板后不淹）：%s" % sid)

func _check_surface_capture() -> void:
	if state != State.FLEE and state != State.IDLE:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_alive") and e.is_alive():
			if global_position.distance_to((e as Node3D).global_position) < 1.2:
				_capture(e as Node3D)
				return

func _check_hidden_discovery() -> void:
	if not _seal_is_open():
		return
	var safe := get_tree().get_first_node_in_group("villager_safe_zone") as Node3D
	if safe == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e.has_method("is_alive") and e.is_alive()):
			continue
		var foe := e as Node3D
		if foe.global_position.y > -1.0:
			continue
		if foe.global_position.distance_to(safe.global_position) < 1.6:
			# 被发现后逃窜，不立刻被捕
			BattleState.try_speech("村民：藏不住了！快跑！", 2.2)
			state = State.FLEE
			_walk_to_safe = false
			blocked_ids.clear()
			_pick_entrance()
			# 若敌军已贴身则仍被捕
			if global_position.distance_to(foe.global_position) < 1.15:
				_capture(foe)
			return

func _seal_is_open() -> bool:
	var seal := get_tree().get_first_node_in_group("villager_seal")
	if seal and seal.has_method("is_dead_open"):
		return seal.is_dead_open()
	return false

func _capture(by: Node3D = null) -> void:
	if state in [State.ESCORTED, State.TRANSFERRED, State.DEAD]:
		return
	state = State.ESCORTED
	velocity = Vector3.ZERO
	visible = true
	_walk_to_safe = false
	escort = by if by else _nearest_enemy()
	if escort and escort.has_method("begin_escort"):
		escort.begin_escort(self)
	if _tag:
		_tag.text = "村民·被押"
		_tag.modulate = Color(1.0, 0.55, 0.45)
	EventBus.villager_captured.emit(villager_id)
	EventBus.status_message.emit("村民被捕，敌军押往瞭望树！可冒险开枪救人。", 3.2)
	BattleState.log_event("村民被捕，押往瞭望树")

func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_alive") and e.is_alive():
			var d := global_position.distance_to((e as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = e as Node3D
	return best

func _escort_tick(delta: float) -> void:
	if escort == null or not is_instance_valid(escort) or not (escort.has_method("is_alive") and escort.is_alive()):
		_rescue_free()
		return
	var rally := get_tree().get_first_node_in_group("prisoner_rally") as Node3D
	var dest := rally.global_position if rally else Vector3(22.0, 0.2, 1.2)
	# 跟在押送者身旁，一起往瞭望树
	var follow := escort.global_position + Vector3(-0.7, 0, 0.4)
	if escort.global_position.distance_to(dest) < 2.2 or global_position.distance_to(dest) < 2.4:
		_complete_transfer()
		return
	var dir := follow - global_position
	dir.y = 0
	if dir.length() > 0.35:
		dir = dir.normalized()
		var spd := move_speed * 1.05
		if "move_speed" in escort:
			spd = minf(float(escort.move_speed) * 0.92, 2.3)
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _complete_transfer() -> void:
	if state == State.TRANSFERRED:
		return
	state = State.TRANSFERRED
	velocity = Vector3.ZERO
	var rally := get_tree().get_first_node_in_group("prisoner_rally") as Node3D
	if rally:
		global_position = rally.global_position + Vector3(randf_range(-0.4, 0.4), 0.05, randf_range(-0.3, 0.3))
	if escort and escort.has_method("clear_escort"):
		escort.clear_escort()
	escort = null
	if _tag:
		_tag.text = "村民·被带走"
	EventBus.villager_transferred.emit(villager_id)
	EventBus.status_message.emit("村民已被押到瞭望树附近。", 2.8)
	BattleState.log_event("村民转移到瞭望树")

## 测试或脚本强制完成押送
func force_arrive_lookout() -> void:
	if state != State.ESCORTED:
		_capture()
	_complete_transfer()

func _on_player_fired(origin: Vector3, dir: Vector3) -> void:
	if state != State.ESCORTED or escort == null:
		return
	if not is_instance_valid(escort) or not escort.has_method("is_alive") or not escort.is_alive():
		return
	# 判定是否在朝人质/押送开火：射线靠近人质或押送者
	var aim_pt := origin + dir.normalized() * origin.distance_to(global_position)
	var near_hostage := _dist_point_to_segment(global_position + Vector3.UP, origin, origin + dir * 45.0) < 1.8
	var near_escort := _dist_point_to_segment(escort.global_position + Vector3.UP, origin, origin + dir * 45.0) < 1.8
	if not near_hostage and not near_escort:
		return
	# 等本帧伤害结算：下一帧看押送者是否还活着
	await get_tree().process_frame
	if state != State.ESCORTED:
		return
	if escort == null or not is_instance_valid(escort) or not escort.is_alive():
		_rescue_free()
		return
	# 开枪未击毙 → 敌军对村民开枪
	_execute_by_escort()

func _on_enemy_killed_bus(_eid: StringName, _role: StringName) -> void:
	if state != State.ESCORTED:
		return
	if escort == null or not is_instance_valid(escort) or not escort.is_alive():
		_rescue_free()

func _rescue_free() -> void:
	if state in [State.TRANSFERRED, State.DEAD]:
		return
	escort = null
	state = State.FLEE
	_walk_to_safe = false
	blocked_ids.clear()
	if _tag:
		_tag.text = "村民"
		_tag.modulate = Color(1.0, 0.95, 0.75)
	EventBus.villager_rescued.emit(villager_id)
	BattleState.try_speech("村民：得救了！快躲进地道！", 2.4)
	_pick_entrance()

func _execute_by_escort() -> void:
	if state != State.ESCORTED:
		return
	state = State.DEAD
	velocity = Vector3.ZERO
	visible = false
	if escort and escort.has_method("clear_escort"):
		escort.clear_escort()
	escort = null
	EventBus.villager_killed.emit(villager_id)
	EventBus.status_message.emit("开枪未击毙押送者，村民被杀害！", 3.4)
	BattleState.log_event("村民被处决")

func _dist_point_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := 0.0
	var denom := ab.length_squared()
	if denom > 0.0001:
		t = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func is_hidden() -> bool:
	return state == State.HIDDEN

func is_captured() -> bool:
	return state in [State.ESCORTED, State.TRANSFERRED]

func is_alive_villager() -> bool:
	return state != State.DEAD and state != State.TRANSFERRED
