extends Node
## 全局事件总线。所有胜负相关事件由 BattleManager 监听，NPC 不得自行结束游戏。

signal player_fired(origin: Vector3, direction: Vector3)
signal shout_emitted(origin: Vector3)
signal alarm_triggered(by_player: bool)
signal villager_entered_shelter(villager_id: StringName, shelter_id: StringName)
signal villager_captured(villager_id: StringName)
signal villager_transferred(villager_id: StringName)
signal villager_killed(villager_id: StringName)
signal villager_rescued(villager_id: StringName)
signal trap_triggered(trap_id: StringName, victim_id: StringName)
signal tunnel_entrance_discovered(entrance_id: StringName, by_enemy_id: StringName)
signal water_started()
signal water_barrier_closed()
signal enemy_killed(enemy_id: StringName, role: StringName)
signal commander_killed(enemy_id: StringName)
signal enemy_retreated()
signal ally_commanded(ally_id: StringName, command: StringName)
signal ally_died(ally_id: StringName)
signal player_died(lives_remaining: int)
signal player_revived()
signal battle_phase_changed(phase: StringName)
signal battle_ended(result: StringName, reason: StringName)
signal interactable_hint(text: String)
signal status_message(text: String, duration: float)
signal speech_line(text: String, duration: float)
signal muzzle_flash(origin: Vector3, hit: Vector3, flesh: bool)
signal gunshot(origin: Vector3)
signal dry_fired()
signal bell_hit()
signal actor_hit(origin: Vector3, who: StringName)
signal actor_pose(actor: Node, pose: StringName)

func emit_named(event_name: StringName, args: Array = []) -> void:
	match event_name:
		&"PLAYER_FIRED":
			player_fired.emit(args[0], args[1])
		&"ALARM_TRIGGERED":
			alarm_triggered.emit(bool(args[0]) if args.size() > 0 else true)
		&"VILLAGER_ENTERED_SHELTER":
			villager_entered_shelter.emit(args[0], args[1])
		&"VILLAGER_CAPTURED":
			villager_captured.emit(args[0])
		&"TRAP_TRIGGERED":
			trap_triggered.emit(args[0], args[1])
		&"TUNNEL_ENTRANCE_DISCOVERED":
			tunnel_entrance_discovered.emit(args[0], args[1])
		&"WATER_STARTED":
			water_started.emit()
		&"WATER_BARRIER_CLOSED":
			water_barrier_closed.emit()
		&"ENEMY_KILLED":
			enemy_killed.emit(args[0], args[1])
		&"COMMANDER_KILLED":
			commander_killed.emit(args[0])
		&"ENEMY_RETREATED":
			enemy_retreated.emit()
		_:
			push_warning("Unknown event: %s" % event_name)
