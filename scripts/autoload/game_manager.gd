extends Node
## 场景与游戏流程管理。

enum FlowState { BOOT, INTRO, PLAYING, RESULT }

var flow: FlowState = FlowState.BOOT
var main_scene_path := "res://scenes/main/main.tscn"
var _time_scale_cache: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_new_battle() -> void:
	BattleState.reset()
	flow = FlowState.INTRO
	get_tree().paused = false
	# 重新加载主场景以保证彻底重置
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == main_scene_path:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(main_scene_path)

func begin_explore() -> void:
	flow = FlowState.PLAYING
	BattleState.exploring = true
	BattleState.phase = BattleState.Phase.EXPLORE
	BattleState.player_can_control = true
	_place_at_marker("explore_spawn", PI)
	EventBus.battle_phase_changed.emit(&"EXPLORE")
	EventBus.status_message.emit("探索中：地道口藏在树洞、锅台、水井和东屋。E 与村民、战友交谈。按 B 钻进树洞开始警戒。", 5.5)

func begin_play() -> void:
	flow = FlowState.PLAYING
	BattleState.exploring = false
	BattleState.phase = BattleState.Phase.OBSERVE
	BattleState.player_can_control = true
	BattleState.enemy_reveal_at = BattleState.now_sec() + randf_range(BattleState.SIDE_ENTER_MIN, BattleState.SIDE_ENTER_MAX)
	_place_at_marker("lookout_spawn", -PI * 0.5)
	EventBus.battle_phase_changed.emit(&"OBSERVE")
	EventBus.status_message.emit("你在树洞里。东边田埂外的敌军会从左右进入视野，再向村子推进。E 进地道回东屋拉钟。", 5.8)

func _place_at_marker(group_name: String, yaw: float) -> void:
	var spawn := get_tree().get_first_node_in_group(group_name) as Node3D
	var player := get_tree().get_first_node_in_group("player")
	if spawn == null or not (player is CharacterBody3D):
		return
	var body := player as CharacterBody3D
	body.global_position = spawn.global_position
	body.rotation.y = yaw
	body.velocity = Vector3.ZERO
	if body.has_method("sync_yaw"):
		body.sync_yaw()
	if body.has_method("set_in_tunnel"):
		body.set_in_tunnel(false)

func enter_combat() -> void:
	if BattleState.phase == BattleState.Phase.COMBAT:
		return
	BattleState.phase = BattleState.Phase.COMBAT
	EventBus.battle_phase_changed.emit(&"COMBAT")

func show_result(result: StringName, reason: StringName) -> void:
	if flow == FlowState.RESULT:
		return
	flow = FlowState.RESULT
	BattleState.phase = BattleState.Phase.RESULT
	BattleState.battle_over = true
	BattleState.result = result
	BattleState.result_reason = reason
	BattleState.player_can_control = false
	EventBus.battle_ended.emit(result, reason)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func restart() -> void:
	start_new_battle()
