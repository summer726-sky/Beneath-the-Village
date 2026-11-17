extends CharacterBody3D
class_name AllyAI
## 可指挥战友：默认岗位 + 简短命令循环。

enum Command { HOLD_PORT, CLOSE_BARRIER, STANDBY }

@export var ally_name: StringName = &"甲"
@export var default_command: Command = Command.HOLD_PORT
@export var move_speed: float = 3.0

var command: Command
var alive: bool = true
var _feedback: String = ""
var _mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("allies")
	add_to_group("interactable")
	command = default_command
	_build_visual()
	_announce_command()

func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.58, 1.7, 0.38)
	_mesh.mesh = box
	_mesh.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.38, 0.72) if ally_name == &"甲" else Color(0.15, 0.55, 0.62)
	_mesh.material_override = mat
	add_child(_mesh)
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

var _posted: bool = false

func _physics_process(delta: float) -> void:
	if not alive or BattleState.battle_over:
		return
	if not BattleState.alarm_rung:
		command = Command.STANDBY
		_posted = false
	elif not _posted:
		_posted = true
		command = default_command
		_announce_command()
	match command:
		Command.HOLD_PORT:
			_go_to_group("ally_port_post", delta)
		Command.CLOSE_BARRIER:
			_try_close_barrier(delta)
		Command.STANDBY:
			velocity = Vector3.ZERO
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0
	move_and_slide()

func _go_to_group(group: String, delta: float) -> void:
	var post := get_tree().get_first_node_in_group(group)
	if post == null:
		return
	var pos := (post as Node3D).global_position
	var dir := pos - global_position
	dir.y = 0
	if dir.length() > 0.4:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0

func _try_close_barrier(delta: float) -> void:
	var post := get_tree().get_first_node_in_group("ally_barrier_post")
	if post and global_position.distance_to(post.global_position) > 1.3:
		_go_to_group("ally_barrier_post", delta)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	var barrier := get_tree().get_first_node_in_group("water_barrier")
	if barrier and barrier.has_method("interact") and BattleState.water_started and not BattleState.water_barrier_closed:
		barrier.interact(self)
		_feedback = "已从井口放下挡板"
		EventBus.status_message.emit("战友%s：%s" % [ally_name, _feedback], 2.0)
		command = Command.STANDBY

func receive_command_cycle() -> void:
	if not alive:
		return
	if not BattleState.alarm_rung:
		EventBus.status_message.emit("战友%s：先拉响院子里的钟，我再上阵地。" % ally_name, 2.2)
		return
	_posted = true
	command = ((int(command) + 1) % 3) as Command
	_announce_command()

func _announce_command() -> void:
	match command:
		Command.HOLD_PORT:
			_feedback = "守这个孔"
		Command.CLOSE_BARRIER:
			_feedback = "去关隔板"
		Command.STANDBY:
			_feedback = "原地待命"
	EventBus.ally_commanded.emit(ally_name, StringName(_feedback))
	EventBus.status_message.emit("战友%s：%s！" % [ally_name, _feedback], 2.5)

func get_interact_hint() -> String:
	if not alive:
		return ""
	if BattleState.exploring:
		return "E 和战友交谈"
	return "F 下令（当前：%s）" % _feedback

func interact(_by: Node) -> void:
	if BattleState.exploring:
		var line := "树洞能看见东边来路。地道向西通东屋，也能到井和锅台。"
		if ally_name == &"乙":
			line = "我守水井这边。真打起来我会去挡水隔板，你喊话时注意别让敌军听见。"
		else:
			line = "我守墙上的射击孔，枪口朝东。探索的时候可以先把地道走一遍。"
		EventBus.status_message.emit("战友%s：%s" % [ally_name, line], 3.6)
		return
	receive_command_cycle()

func take_damage(_amount: int = 1, _source: Node = null) -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	if _mesh:
		_mesh.material_override.albedo_color = Color(0.2, 0.2, 0.2)
	EventBus.ally_died.emit(ally_name)
	BattleState.log_event("战友阵亡：%s" % ally_name)
	EventBus.status_message.emit("战友%s倒下了" % ally_name, 3.0)

func is_alive() -> bool:
	return alive
