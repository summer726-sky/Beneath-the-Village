extends CharacterBody3D
class_name VillagerAI
## 村民：警报后寻找最近未堵塞入口躲藏；被挡则改道；被捕退出本局。

enum State { IDLE, FLEE, HIDDEN, CAPTURED }

@export var villager_id: StringName = &"villager"
@export var move_speed: float = 3.4

var state: State = State.IDLE
var target_entrance: Node3D = null
var blocked_ids: Array[StringName] = []
var _mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("villagers")
	add_to_group("interactable")
	villager_id = StringName("villager_%d" % get_instance_id())
	EventBus.alarm_triggered.connect(_on_alarm)
	_build_visual()

func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 1.45, 0.3)
	_mesh.mesh = box
	_mesh.position.y = 0.72
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.72, 0.48)
	_mesh.material_override = mat
	add_child(_mesh)
	var tag := Label3D.new()
	tag.text = "村民"
	tag.font_size = 42
	tag.outline_size = 8
	tag.modulate = Color(1.0, 0.95, 0.75)
	tag.position = Vector3(0, 2.05, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.4
	cap.radius = 0.25
	col.shape = cap
	col.position.y = 0.7
	add_child(col)

func _physics_process(delta: float) -> void:
	if state == State.HIDDEN or state == State.CAPTURED or BattleState.battle_over:
		velocity = Vector3.ZERO
		return
	if state == State.FLEE:
		_flee(delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0
	move_and_slide()
	_check_capture()

func get_interact_hint() -> String:
	if state == State.CAPTURED:
		return ""
	if BattleState.exploring:
		return "E 询问村民"
	return ""

func interact(_by: Node) -> void:
	if not BattleState.exploring or state != State.IDLE:
		return
	var lines := [
		"我们躲去北房夹壁下面的暗室。锅台不是入口，是朝院子开枪的地方。",
		"钟在院子的树下。拉响之后我们才往北房地道里躲。",
		"水井下面有两层。上层走人，下层排水。鬼子灌水时得有人去关隔板。"
	]
	EventBus.status_message.emit(lines[randi() % lines.size()], 3.4)

func _on_alarm(_by_player: bool) -> void:
	if state == State.IDLE:
		state = State.FLEE
		_pick_entrance()

func _pick_entrance() -> void:
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("entrances"):
		if not (e is Node3D):
			continue
		var ent := e as Node3D
		var eid: StringName = ent.get_entrance_id() if ent.has_method("get_entrance_id") else StringName(ent.name)
		if eid in blocked_ids:
			continue
		if ent.has_method("is_passable") and not ent.is_passable():
			continue
		if ent.get("is_shelter") == false:
			continue
		var d := global_position.distance_to(ent.global_position)
		if d < best_d:
			best_d = d
			best = ent
	target_entrance = best
	if target_entrance == null and blocked_ids.size() > 0:
		# 全部改道失败则清空再试一次
		blocked_ids.clear()
		_pick_entrance()

func _flee(delta: float) -> void:
	if target_entrance == null:
		_pick_entrance()
		if target_entrance == null:
			return
	# 玩家挡住入口则改道
	if _entrance_blocked_by_player(target_entrance):
		var eid: StringName = target_entrance.get_entrance_id() if target_entrance.has_method("get_entrance_id") else StringName(target_entrance.name)
		if eid not in blocked_ids:
			blocked_ids.append(eid)
		target_entrance = null
		_pick_entrance()
		EventBus.status_message.emit("村民改道寻找其他藏身点", 1.5)
		return
	var pos := target_entrance.global_position
	var dir := pos - global_position
	dir.y = 0
	if dir.length() < 1.0:
		_enter_shelter()
		return
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	look_at(global_position + dir, Vector3.UP)

func _entrance_blocked_by_player(ent: Node3D) -> bool:
	return BattleState.player_position.distance_to(ent.global_position) < 1.1

func _enter_shelter() -> void:
	state = State.HIDDEN
	velocity = Vector3.ZERO
	visible = false
	var sid: StringName = target_entrance.get_entrance_id() if target_entrance and target_entrance.has_method("get_entrance_id") else &"shelter"
	EventBus.villager_entered_shelter.emit(villager_id, sid)
	BattleState.log_event("村民进入藏身点：%s" % sid)
	# 移到地下安全点
	var safe := get_tree().get_first_node_in_group("villager_safe_zone")
	if safe:
		global_position = (safe as Node3D).global_position
		visible = true

func _check_capture() -> void:
	if state != State.FLEE and state != State.IDLE:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_alive") and e.is_alive():
			if global_position.distance_to((e as Node3D).global_position) < 1.2:
				_capture()
				return

func _capture() -> void:
	state = State.CAPTURED
	velocity = Vector3.ZERO
	visible = false
	EventBus.villager_captured.emit(villager_id)
	EventBus.status_message.emit("一名村民被捕！", 3.0)

func is_hidden() -> bool:
	return state == State.HIDDEN

func is_captured() -> bool:
	return state == State.CAPTURED
