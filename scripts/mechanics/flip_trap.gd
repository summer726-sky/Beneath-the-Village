extends Area3D
class_name FlipTrap
## 翻板：默认用棍支住，抽棍后两侧才会坠落。中间木轴安全。不放在报信直道上。

@export var trap_id: StringName = &"donkey_trough_trap"
var sprung: bool = false
var armed: bool = false
var _safe_half_width: float = 0.22

@onready var visual: MeshInstance3D = get_node_or_null("Visual")

func _ready() -> void:
	add_to_group("flip_trap")
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)

func arm() -> void:
	armed = true

func get_interact_hint() -> String:
	if sprung:
		return "翻板已触发"
	if not armed:
		return "E 抽掉撑棍（之后敌军踩两侧会坠落，中间仍可走）"
	return "撑棍已抽。走中间木轴"

func interact(_by: Node) -> void:
	if sprung or armed:
		return
	if not BattleState.alarm_rung and not BattleState.exploring:
		EventBus.status_message.emit("先拉响警报，再抽驴槽下面的撑棍。", 2.4)
		return
	arm()
	EventBus.status_message.emit("撑棍已抽掉。踩两侧会坠落，中间木轴仍可走。", 2.6)

func try_trigger_from(body: Node3D) -> bool:
	return _attempt_trigger(body)

func _on_body_entered(body: Node) -> void:
	if body is Node3D:
		_attempt_trigger(body as Node3D)

func _attempt_trigger(body: Node3D) -> bool:
	if not armed or sprung or BattleState.trap_sprung:
		return false
	# 玩家与战友走中间安全
	if body.is_in_group("player") or body.is_in_group("allies"):
		var local_x := to_local(body.global_position).x
		if absf(local_x) <= _safe_half_width:
			return false
		# 玩家踩两侧也会触发，但不伤害友方——仅警告
		EventBus.status_message.emit("小心！你踩到了翻板边缘", 2.0)
		return false
	if not body.is_in_group("enemies"):
		return false
	var local_x2 := to_local(body.global_position).x
	if absf(local_x2) <= _safe_half_width:
		return false
	sprung = true
	BattleState.trap_sprung = true
	_play_spring_visual()
	var vid: StringName = body.enemy_id if "enemy_id" in body else StringName(body.name)
	EventBus.trap_triggered.emit(trap_id, vid)
	if body.has_method("take_damage"):
		body.take_damage(1, self)
	EventBus.status_message.emit("翻板陷阱触发！一名敌军坠入。", 3.0)
	BattleState.log_event("翻板触发")
	return true

func _play_spring_visual() -> void:
	if visual:
		var tw := create_tween()
		tw.tween_property(visual, "rotation_degrees:x", 75.0, 0.35)
