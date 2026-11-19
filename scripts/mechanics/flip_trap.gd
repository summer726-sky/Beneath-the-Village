extends Area3D
class_name FlipTrap
## 翻板：默认已可触发，不用先抽撑棍。中间木轴安全。
## 第一个敌军踩偏坠落出局后，后面的人知道要踩中间，不再死在这里。

@export var trap_id: StringName = &"donkey_trough_trap"
var sprung: bool = false
var armed: bool = true
var _safe_half_width: float = 0.22

func _ready() -> void:
	add_to_group("flip_trap")
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	var stick := get_node_or_null("Visual/Stick") as Node3D
	if stick:
		stick.visible = false

func get_interact_hint() -> String:
	if sprung:
		return "翻板已翻开 · 走中间木轴"
	return "翻板已就绪 · 走中间木轴（不用抽棍）"

func interact(_by: Node) -> void:
	# 不用抽棍。靠近只提示走中间。
	pass

func try_trigger_from(body: Node3D) -> bool:
	return _attempt_trigger(body)

func _on_body_entered(body: Node) -> void:
	if body is Node3D:
		_attempt_trigger(body as Node3D)

func _attempt_trigger(body: Node3D) -> bool:
	if not armed or sprung:
		return false
	# 村民不受翻板杀伤
	if body.is_in_group("villagers"):
		return false
	# 玩家与战友走中间安全；踩偏只踉跄
	if body.is_in_group("player") or body.is_in_group("allies"):
		var local_x := to_local(body.global_position).x
		if absf(local_x) <= _safe_half_width:
			return false
		if body.has_method("stumble"):
			body.stumble()
		return false
	if not body.is_in_group("enemies"):
		return false
	# 已有人掉过：后面的敌军会踩木轴，不再触发
	if not BattleState.trap_lethal or BattleState.trap_sprung:
		return false
	var local_x2 := to_local(body.global_position).x
	if absf(local_x2) <= _safe_half_width:
		return false
	sprung = true
	BattleState.trap_sprung = true
	BattleState.trap_lethal = false
	_play_spring_visual()
	var vid: StringName = body.enemy_id if "enemy_id" in body else StringName(body.name)
	EventBus.trap_triggered.emit(trap_id, vid)
	if body.has_method("fall_into_pit"):
		body.fall_into_pit(global_position + Vector3(0, -1.0, 0))
	elif body.has_method("take_damage"):
		body.take_damage(1, self)
	BattleState.log_event("翻板触发：后续敌军会踩中间木轴")
	return true

func _play_spring_visual() -> void:
	_drop_leaf("Visual/BoardL", 75.0)
	_drop_leaf("Visual/BoardR", -75.0)
	_open_pit()

func _open_pit() -> void:
	var pit := get_node_or_null("Pit") as Node3D
	if pit:
		pit.visible = true
		return
	pit = Node3D.new()
	pit.name = "Pit"
	add_child(pit)
	var hole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.35, 0.08, 1.1)
	hole.mesh = box
	hole.position = Vector3(0, -0.05, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.09, 0.06)
	hole.material_override = mat
	pit.add_child(hole)
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1.3, 1.05, 1.05)
	wall.mesh = wall_mesh
	wall.position = Vector3(0, -0.55, 0)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.32, 0.24, 0.16)
	wall.material_override = dirt
	pit.add_child(wall)

func _drop_leaf(path: String, angle: float) -> void:
	var leaf := get_node_or_null(path) as Node3D
	if leaf == null:
		return
	var tw := create_tween()
	tw.tween_property(leaf, "rotation_degrees:x", angle, 0.35)
