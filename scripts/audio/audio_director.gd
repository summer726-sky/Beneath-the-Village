extends Node
## 声音总控。只听事件和已有状态，不改胜负与 AI。
## 口令见 period_lines.gd。敌军不配中文语音。

const Lines = preload("res://scripts/audio/period_lines.gd")
const Tones = preload("res://scripts/audio/tone_bank.gd")

const CFG_PATH := "user://audio_settings.cfg"
const VOICE_DIR := "user://voice_cache"
const SPEECH_RANGE := 20.0

var master_linear := 0.85
var sfx_linear := 1.0
var ambience_linear := 0.7

var _sfx: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _wind: AudioStreamPlayer
var _cave: AudioStreamPlayer
var _water: AudioStreamPlayer3D
var _flat: AudioStreamPlayer
var _under := 0.0
var _water_gain := 0.0
var _water_target := 0.0
var _bells_left := 0
var _bell_wait := 0.0
var _villager_in := -1.0
var _advance_in := -1.0
var _flood_said := false
var _hint: Label
var _hint_left := 0.0
var _step_acc: Dictionary = {}
var _last_pos: Dictionary = {}
var _enemy_state: Dictionary = {}
var _shot_cd: Dictionary = {}
var _enemy_line_cd := 0.0
var _mouth: Dictionary = {}
var _wire: Dictionary = {}
var _ammo_stock := -1
var _tunnel_init := false
var _was_tunnel := false
var _hit_lock := 0.0
var _player_line_i := 0
var _voices: Dictionary = {}
var _voice_pid := 0
var _voice_done := false
var _voice_hash := ""
var _queued_id := ""
var _queued_pos := Vector3.ZERO
var _queued_muffle := false
var _queued_until := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_sfx()
	_ensure_buses()
	_apply_volumes()
	_build_players()
	_start_beds()
	EventBus.alarm_triggered.connect(_on_alarm)
	EventBus.player_fired.connect(_on_player_fired)
	EventBus.gunshot.connect(_on_gunshot)
	EventBus.dry_fired.connect(_on_dry)
	EventBus.trap_triggered.connect(_on_trap)
	EventBus.water_started.connect(_on_water)
	EventBus.water_barrier_closed.connect(_on_barrier)
	EventBus.villager_entered_shelter.connect(_on_hidden)
	EventBus.villager_captured.connect(_on_captured)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.shout_emitted.connect(_on_shout)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.ally_died.connect(_on_ally_died)
	EventBus.ally_commanded.connect(_on_ally_commanded)
	EventBus.actor_hit.connect(_on_actor_hit)
	_boot_voice()
	_show_hint("音量  −  /  =", 6.0)

func set_master(linear: float) -> void:
	master_linear = clampf(linear, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_sfx(linear: float) -> void:
	sfx_linear = clampf(linear, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_ambience(linear: float) -> void:
	ambience_linear = clampf(linear, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var key: Key = key_event.physical_keycode
	if key == KEY_MINUS or key == KEY_KP_SUBTRACT:
		set_master(master_linear - 0.08)
		_show_hint("主音量 %d%%" % int(round(master_linear * 100.0)), 1.3)
	elif key == KEY_EQUAL or key == KEY_KP_ADD:
		set_master(master_linear + 0.08)
		_show_hint("主音量 %d%%" % int(round(master_linear * 100.0)), 1.3)

func _process(delta: float) -> void:
	_under = move_toward(_under, 1.0 if BattleState.player_in_tunnel else 0.0, delta * 1.4)
	if _wind:
		_wind.volume_db = _db(0.2 * (1.0 - _under))
	if _cave:
		_cave.volume_db = _db(0.24 * _under)
	_tick_bell(delta)
	_tick_scheduled(delta)
	_tick_water(delta)
	_tick_steps(delta)
	_tick_enemies(delta)
	_tick_mechanisms()
	_tick_ammo()
	_tick_tunnel_edge()
	_tick_voice()
	_hit_lock = maxf(0.0, _hit_lock - delta)
	_enemy_line_cd = maxf(0.0, _enemy_line_cd - delta)
	if _hint and _hint_left > 0.0:
		_hint_left -= delta
		_hint.modulate.a = clampf(_hint_left / 0.4, 0.0, 1.0) if _hint_left < 0.4 else 1.0
		if _hint_left <= 0.0:
			_hint.visible = false

func _on_alarm(_by_player: bool) -> void:
	_bells_left = 4
	_bell_wait = 0.05
	_villager_in = 1.2
	_advance_in = 2.0

func _on_player_fired(origin: Vector3, _dir: Vector3) -> void:
	_play_rifle(origin)

func _on_gunshot(origin: Vector3) -> void:
	_play_rifle(origin)

func _on_dry() -> void:
	_play_flat(_sfx["bolt"], -6.0)

func _on_trap(_trap_id: StringName, _victim_id: StringName) -> void:
	_play(_sfx["wood"], _node_pos("flip_trap"), _bus_at(_node_pos("flip_trap")), -2.0, 1.0, 24.0)

func _on_water() -> void:
	var engineer := _living_enemy("engineer")
	var pour_id := Lines.enemy_voice_id(_enemy_index(engineer), "pour") if engineer else Lines.ENEMY_POUR_ID
	_say_enemy_if_near(Lines.ENEMY_POUR, engineer.global_position if engineer else Vector3.ZERO, pour_id)
	_villager_in = 1.3

func _on_barrier() -> void:
	var pos := _node_pos("water_barrier")
	_play(_sfx["slide"], pos, _bus_at(pos), -4.0, 1.0, 18.0)
	_water_target = 0.0

func _on_hidden(_vid: StringName, _sid: StringName) -> void:
	_play(_sfx["pack"], _villager_pos(_vid), "Muffle", -8.0, 1.0, 12.0)

func _on_captured(_vid: StringName) -> void:
	_play(_sfx["pack"], _villager_pos(_vid), "Sfx", -6.0, 0.9, 14.0)

func _on_enemy_killed(enemy_id: StringName, _role: StringName) -> void:
	_play(_sfx["fall"], _enemy_pos(enemy_id), "Sfx", -5.0, randf_range(0.94, 1.05), 16.0)

func _on_actor_hit(origin: Vector3, _who: StringName) -> void:
	_play(_sfx["grunt"], origin, "Sfx", -4.0, randf_range(0.9, 1.08), 14.0)
	_play(_sfx["fall"], origin, "Sfx", -7.0, randf_range(0.92, 1.05), 12.0)

func _on_ally_died(ally_id: StringName) -> void:
	_play(_sfx["fall"], _ally_pos(ally_id), "Sfx", -5.0, 1.0, 16.0)

func _on_player_died(_lives: int) -> void:
	if _hit_lock > 0.0:
		return
	_hit_lock = 0.45
	_play(_sfx["fall"], _ear(), "Sfx", -3.0, 0.85, 8.0)

func _on_ally_commanded(ally_id: StringName, command: StringName) -> void:
	var vid := Lines.ally_voice_id(String(ally_id), String(command))
	if vid == "":
		return
	_voice_at(vid, _ally_pos(ally_id), false)

func _on_shout(origin: Vector3) -> void:
	if BattleState.exploring or not BattleState.alarm_rung:
		EventBus.speech_line.emit("你低声说：%s" % Lines.PLAYER_EXPLORE, 2.6)
		_voice_at(Lines.PLAYER_EXPLORE_ID, origin, true)
		return
	var i := _player_line_i % Lines.PLAYER_COMBAT.size()
	_player_line_i += 1
	EventBus.speech_line.emit("你喊：%s" % Lines.PLAYER_COMBAT[i], 2.4)
	_voice_at(Lines.PLAYER_COMBAT_IDS[i], origin, BattleState.player_in_tunnel)

func _on_battle_ended(result: StringName, _reason: StringName) -> void:
	_bells_left = 0
	_water_target = 0.0
	_villager_in = -1.0
	_advance_in = -1.0
	if result == &"VICTORY":
		_play_flat(_sfx["soft"], -16.0)
	else:
		_play_flat(_sfx["low"], -14.0)

func _tick_bell(delta: float) -> void:
	if _bells_left <= 0:
		return
	_bell_wait -= delta
	if _bell_wait > 0.0:
		return
	var pos := _node_pos("alarm_bell")
	var left := _bells_left
	_play(_sfx["bell"], pos, _bus_at(pos), -1.5 * (4 - left), randf_range(0.98, 1.02), 75.0)
	EventBus.bell_hit.emit()
	_bells_left -= 1
	_bell_wait = 0.52

func _tick_scheduled(delta: float) -> void:
	if _villager_in >= 0.0:
		_villager_in -= delta
		if _villager_in < 0.0:
			_villager_shout()
	if _advance_in >= 0.0:
		_advance_in -= delta
		if _advance_in < 0.0:
			var commander := _living_enemy("commander")
			var advance_id := Lines.enemy_voice_id(_enemy_index(commander), "advance") if commander else Lines.ENEMY_ADVANCE_ID
			_say_enemy_if_near(Lines.ENEMY_ADVANCE, commander.global_position if commander else Vector3.ZERO, advance_id)

func _villager_shout() -> void:
	var water := BattleState.water_started and not BattleState.water_barrier_closed
	var text := Lines.VILLAGER_WATER if water else Lines.VILLAGER_ALARM
	var body := _surface_villager()
	var vid := Lines.villager_voice_id(_villager_slot(body), water)
	var pos := body.global_position if body else _node_pos("villager_safe_zone")
	var underground := body == null
	var prefix := "地道里有人喊：" if underground else "村民："
	EventBus.speech_line.emit(prefix + text, 3.0)
	_voice_at(vid, pos, underground or BattleState.player_in_tunnel)

func _tick_water(delta: float) -> void:
	var running := BattleState.water_started and not BattleState.water_barrier_closed and not BattleState.battle_over and not BattleState.bunker_flooded
	_water_target = (0.16 + 0.84 * BattleState.water_progress) if running else 0.0
	if BattleState.bunker_flooded and not _flood_said:
		_flood_said = true
		_play(_sfx["gush"], _node_pos("well"), _bus_at(_node_pos("well")), -4.0, 1.0, 22.0)
	_water_gain = move_toward(_water_gain, _water_target, delta * 0.55)
	if _water == null:
		return
	var well := get_tree().get_first_node_in_group("well") as Node3D
	if well:
		_water.global_position = well.global_position
	_water.bus = "Tunnel" if BattleState.player_in_tunnel else "Sfx"
	if _water_gain <= 0.02:
		if _water.playing:
			_water.stop()
		return
	if not _water.playing:
		_water.play()
	_water.volume_db = _db(_water_gain) - 4.0

func _tick_steps(delta: float) -> void:
	var bodies: Array = []
	for g in ["player", "villagers", "allies", "enemies"]:
		bodies.append_array(get_tree().get_nodes_in_group(g))
	var ear := _ear()
	for node in bodies:
		if not (node is Node3D):
			continue
		var body := node as Node3D
		var id := body.get_instance_id()
		var pos := body.global_position
		var prev: Vector3 = _last_pos.get(id, pos)
		var dist := Vector2(pos.x - prev.x, pos.z - prev.z).length()
		_last_pos[id] = pos
		if dist > 1.5:
			_step_acc[id] = 0.0
			continue
		var speed := dist / maxf(delta, 0.001)
		if speed < 0.45:
			continue
		var own := body.is_in_group("player")
		if not own and ear.distance_to(pos) > 20.0:
			continue
		var acc := float(_step_acc.get(id, 0.0)) + delta
		var interval := clampf(0.76 - speed * 0.07, 0.34, 0.72)
		if acc < interval:
			_step_acc[id] = acc
			continue
		_step_acc[id] = 0.0
		var underground := pos.y < -1.0 or (own and BattleState.player_in_tunnel)
		var stream: AudioStream = _sfx["tunnel"]
		if not underground:
			stream = _sfx["boot"] if body.is_in_group("enemies") else _sfx["cloth_step"]
		var db := -11.0 if own else -7.0
		if body.is_in_group("villagers") and speed > 2.4:
			db = -5.5
		_play(stream, pos, _bus_at(pos), db, randf_range(0.92, 1.08), 18.0)

func _tick_enemies(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node3D):
			continue
		var body := node as Node3D
		var id := body.get_instance_id()
		var st := int(body.get("state"))
		var cd := float(body.get("shoot_cooldown"))
		var prev := int(_enemy_state.get(id, -1))
		var prev_cd := float(_shot_cd.get(id, cd))
		if prev < 0:
			_enemy_state[id] = st
			_shot_cd[id] = cd
			continue
		if cd > prev_cd + 0.2 and bool(body.get("alive")):
			_play_rifle(body.global_position)
		_shot_cd[id] = cd
		_enemy_state[id] = st
		if prev == st or not bool(body.get("alive")):
			continue
		if not (BattleState.alarm_rung or BattleState.recon_exposed):
			continue
		if _enemy_line_cd > 0.0 or _ear().distance_to(body.global_position) > SPEECH_RANGE:
			continue
		var line := ""
		var voice_id := ""
		if st == int(EnemyAI.State.COMBAT):
			line = Lines.ENEMY_FIRE
			voice_id = Lines.enemy_voice_id(_enemy_index(body), "fire")
		elif st == int(EnemyAI.State.PROBE) or st == int(EnemyAI.State.GUARD_HOLE):
			line = Lines.ENEMY_HOLE
			voice_id = Lines.enemy_voice_id(_enemy_index(body), "hole")
		if line != "":
			EventBus.speech_line.emit(line, 2.2)
			_enemy_line_cd = 3.4
			_voice_at(voice_id, body.global_position, body.global_position.y < -1.0 or BattleState.player_in_tunnel)

func _tick_mechanisms() -> void:
	for node in get_tree().get_nodes_in_group("flip_mouth"):
		if not (node is Node3D):
			continue
		var id := node.get_instance_id()
		var alt := bool(node.get("using_alt"))
		if not _mouth.has(id):
			_mouth[id] = alt
			continue
		if alt != bool(_mouth[id]):
			_mouth[id] = alt
			var pos := (node as Node3D).global_position
			_play(_sfx["slide"], pos, _bus_at(pos), -6.0, 1.0, 14.0)
	for node in get_tree().get_nodes_in_group("trip_wire"):
		if not (node is Node3D):
			continue
		var id2 := node.get_instance_id()
		var sprung := bool(node.get("sprung"))
		if not _wire.has(id2):
			_wire[id2] = sprung
			continue
		if sprung and not bool(_wire[id2]):
			_wire[id2] = true
			var pos2 := (node as Node3D).global_position
			_play(_sfx["mine"], pos2, _bus_at(pos2), -2.0, 1.0, 28.0)

func _tick_ammo() -> void:
	var stock := int(BattleState.ammo_cache_stock)
	if _ammo_stock >= 0 and stock < _ammo_stock:
		_play(_sfx["pack"], _ear(), "Sfx", -8.0, 1.0, 6.0)
	_ammo_stock = stock

func _tick_tunnel_edge() -> void:
	var now := BattleState.player_in_tunnel
	if not _tunnel_init:
		_tunnel_init = true
		_was_tunnel = now
		return
	if now != _was_tunnel:
		_was_tunnel = now
		_play(_sfx["pack"], _ear(), "Muffle" if now else "Sfx", -10.0, 0.8 if now else 1.0, 6.0)

func _say_enemy_if_near(line: String, pos: Vector3, voice_id: String) -> void:
	if _enemy_line_cd > 0.0:
		return
	if pos == Vector3.ZERO or _ear().distance_to(pos) > SPEECH_RANGE + 6.0:
		return
	EventBus.speech_line.emit(line, 2.4)
	_enemy_line_cd = 3.4
	_voice_at(voice_id, pos, pos.y < -1.0 or BattleState.player_in_tunnel)

func _play_rifle(pos: Vector3) -> void:
	_play(_sfx["rifle"], pos, _bus_at(pos), -2.0, randf_range(0.97, 1.03), 46.0)

func _dry_fire_now() -> bool:
	return BattleState.player_can_control and BattleState.player_alive and not BattleState.exploring and not BattleState.battle_over and BattleState.player_ammo <= 0

func _bus_at(pos: Vector3) -> String:
	if pos.y < -1.0 or BattleState.player_in_tunnel:
		return "Tunnel"
	return "Sfx"

func _play(stream: AudioStream, pos: Vector3, bus: String, db: float, pitch: float, reach: float) -> void:
	if stream == null or _pool.is_empty():
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	if p.playing:
		p.stop()
	p.stream = stream
	p.global_position = pos
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch
	p.max_distance = reach
	p.unit_size = 4.5
	p.play()

func _play_flat(stream: AudioStream, db: float) -> void:
	if stream == null or _flat == null:
		return
	_flat.stream = stream
	_flat.volume_db = db
	_flat.bus = "Sfx"
	_flat.play()

func _voice_at(id: String, pos: Vector3, muffled: bool) -> void:
	var stream := _voice_stream(id)
	if stream == null:
		_queued_id = id
		_queued_pos = pos
		_queued_muffle = muffled
		_queued_until = Time.get_ticks_msec() / 1000.0 + 20.0
		return
	var bus := "Muffle" if muffled else "Voice"
	_play(stream, pos, bus, -8.0 if muffled else -3.0, 1.0, 32.0)

func _voice_stream(id: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "res://audio/voice/%s.%s" % [id, ext]
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			var res = load(path)
			if res is AudioStream:
				return res
	return _voices.get(id, null)

func _tick_voice() -> void:
	if not _voice_done and _voice_pid > 0 and not OS.is_process_running(_voice_pid):
		_import_voice_cache()
		_voice_done = true
	if _queued_id == "":
		return
	if Time.get_ticks_msec() / 1000.0 > _queued_until:
		_queued_id = ""
		return
	if _voice_stream(_queued_id) != null:
		var id := _queued_id
		_queued_id = ""
		_voice_at(id, _queued_pos, _queued_muffle)

func _bundled_voice(id: String) -> bool:
	return FileAccess.file_exists("res://audio/voice/%s.wav" % id) or FileAccess.file_exists("res://audio/voice/%s.ogg" % id)

func _boot_voice() -> void:
	var bundled := true
	for row in Lines.spoken_rows():
		if not _bundled_voice(String(row).split("|")[0]):
			bundled = false
			break
	if bundled or _headless() or OS.get_name() != "Windows":
		_voice_done = true
		return
	var err := VOICE_DIR + "/error.txt"
	if FileAccess.file_exists(err):
		_voice_done = true
		return
	var payload := ""
	for row in Lines.spoken_rows():
		payload += row + "\n"
	_voice_hash = str(payload.hash())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VOICE_DIR))
	var hash_file := VOICE_DIR + "/hash.txt"
	var hash_ok := FileAccess.file_exists(hash_file) and FileAccess.get_file_as_string(hash_file).strip_edges() == _voice_hash
	var complete := hash_ok
	if complete:
		for row in Lines.spoken_rows():
			var id := String(row).split("|")[0]
			if not FileAccess.file_exists("%s/%s.wav" % [VOICE_DIR, id]):
				complete = false
				break
	if complete:
		_import_voice_cache()
		_voice_done = true
		return
	var list_path := VOICE_DIR + "/lines.txt"
	var f := FileAccess.open(list_path, FileAccess.WRITE)
	if f == null:
		_voice_done = true
		return
	f.store_8(0xEF)
	f.store_8(0xBB)
	f.store_8(0xBF)
	f.store_string(payload)
	f.close()
	var script := ProjectSettings.globalize_path("res://tools/speak_lines.ps1")
	var out_dir := ProjectSettings.globalize_path(VOICE_DIR)
	_voice_pid = OS.create_process("powershell.exe", PackedStringArray([
		"-WindowStyle", "Hidden",
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", script,
		"-OutDir", out_dir,
		"-ListPath", ProjectSettings.globalize_path(list_path),
	]))
	if _voice_pid <= 0:
		_voice_done = true

func _import_voice_cache() -> void:
	var ok := false
	for row in Lines.spoken_rows():
		var id := String(row).split("|")[0]
		var path := "%s/%s.wav" % [VOICE_DIR, id]
		if not FileAccess.file_exists(path):
			continue
		var stream := Tones.load_wav(path)
		if stream:
			_voices[id] = stream
			ok = true
	if ok and _voice_hash != "":
		var f := FileAccess.open(VOICE_DIR + "/hash.txt", FileAccess.WRITE)
		if f:
			f.store_string(_voice_hash)
			f.close()

func _build_sfx() -> void:
	_sfx["bell"] = Tones.bell()
	_sfx["cloth_step"] = Tones.foot_cloth()
	_sfx["boot"] = Tones.foot_boot()
	_sfx["tunnel"] = Tones.foot_tunnel()
	_sfx["rifle"] = Tones.rifle()
	_sfx["bolt"] = Tones.empty_bolt()
	_sfx["wood"] = Tones.wood_break()
	_sfx["slide"] = Tones.wood_slide()
	_sfx["fall"] = Tones.body_fall()
	_sfx["grunt"] = Tones.hit_grunt()
	_sfx["pack"] = Tones.cloth()
	_sfx["mine"] = Tones.mine()
	_sfx["gush"] = Tones.gush()
	_sfx["wind"] = Tones.wind_loop()
	_sfx["cave"] = Tones.cave_loop()
	_sfx["water"] = Tones.water_loop()
	_sfx["low"] = Tones.sting_low()
	_sfx["soft"] = Tones.sting_soft()

func _build_players() -> void:
	for i in 18:
		var p := AudioStreamPlayer3D.new()
		p.name = "Sfx%d" % i
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 1.25
		p.attenuation_filter_cutoff_hz = 4500.0
		p.attenuation_filter_db = -18.0
		add_child(p)
		_pool.append(p)
	_wind = AudioStreamPlayer.new()
	_wind.stream = _sfx["wind"]
	_wind.bus = "Ambience"
	add_child(_wind)
	_cave = AudioStreamPlayer.new()
	_cave.stream = _sfx["cave"]
	_cave.bus = "Ambience"
	add_child(_cave)
	_water = AudioStreamPlayer3D.new()
	_water.stream = _sfx["water"]
	_water.bus = "Sfx"
	_water.max_distance = 24.0
	_water.unit_size = 5.0
	_water.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(_water)
	_flat = AudioStreamPlayer.new()
	_flat.bus = "Sfx"
	add_child(_flat)

func _start_beds() -> void:
	if _headless():
		return
	_wind.play()
	_cave.play()

func _ensure_buses() -> void:
	_add_bus("Sfx")
	_add_bus("Ambience")
	_add_bus("Voice")
	_add_bus("Tunnel")
	_add_bus("Muffle")
	var tunnel := AudioServer.get_bus_index("Tunnel")
	if tunnel >= 0 and AudioServer.get_bus_effect_count(tunnel) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 1500.0
		lp.resonance = 0.35
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.4
		rv.damping = 0.6
		rv.spread = 0.55
		rv.dry = 0.8
		rv.wet = 0.22
		rv.predelay_msec = 28.0
		rv.predelay_feedback = 0.06
		AudioServer.add_bus_effect(tunnel, lp)
		AudioServer.add_bus_effect(tunnel, rv)
	var muffle := AudioServer.get_bus_index("Muffle")
	if muffle >= 0 and AudioServer.get_bus_effect_count(muffle) == 0:
		var lp2 := AudioEffectLowPassFilter.new()
		lp2.cutoff_hz = 980.0
		lp2.resonance = 0.25
		AudioServer.add_bus_effect(muffle, lp2)

func _add_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _db(master_linear))
	var sdb := _db(sfx_linear)
	for bus_name in ["Sfx", "Tunnel", "Muffle", "Voice"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, sdb)
	var amb := AudioServer.get_bus_index("Ambience")
	if amb >= 0:
		AudioServer.set_bus_volume_db(amb, _db(ambience_linear))

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	master_linear = float(cfg.get_value("audio", "master", master_linear))
	sfx_linear = float(cfg.get_value("audio", "sfx", sfx_linear))
	ambience_linear = float(cfg.get_value("audio", "ambience", ambience_linear))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_linear)
	cfg.set_value("audio", "sfx", sfx_linear)
	cfg.set_value("audio", "ambience", ambience_linear)
	cfg.save(CFG_PATH)

func _show_hint(text: String, seconds: float) -> void:
	if _hint == null:
		var layer := CanvasLayer.new()
		layer.layer = 30
		add_child(layer)
		_hint = Label.new()
		_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_hint.offset_left = 16
		_hint.offset_top = -34
		_hint.offset_right = 280
		_hint.offset_bottom = -8
		_hint.add_theme_font_size_override("font_size", 14)
		_hint.add_theme_color_override("font_color", Color(0.93, 0.9, 0.8, 0.85))
		layer.add_child(_hint)
	_hint.text = text
	_hint.visible = true
	_hint_left = seconds

func _ear() -> Vector3:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		return p.global_position
	return BattleState.player_position

func _node_pos(group_name: String) -> Vector3:
	var n := get_tree().get_first_node_in_group(group_name) as Node3D
	if n:
		return n.global_position
	return _ear()

func _villager_pos(vid: StringName) -> Vector3:
	for n in get_tree().get_nodes_in_group("villagers"):
		if n.get("villager_id") == vid and n is Node3D:
			return (n as Node3D).global_position
	return _ear()

func _enemy_pos(enemy_id: StringName) -> Vector3:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.get("enemy_id") == enemy_id and n is Node3D:
			return (n as Node3D).global_position
	return _ear()

func _ally_pos(ally_id: StringName) -> Vector3:
	for n in get_tree().get_nodes_in_group("allies"):
		if String(n.get("ally_name")) == String(ally_id) and n is Node3D:
			return (n as Node3D).global_position
	return _ear()

func _villager_slot(body: Node) -> int:
	if body == null:
		return 1
	var tail := String(body.name)
	if tail.ends_with("2"):
		return 2
	if tail.ends_with("3"):
		return 3
	return 1

func _enemy_index(body: Node) -> int:
	if body == null:
		return 0
	var parts := String(body.name).split("_")
	if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
		return int(parts[parts.size() - 1])
	return 0

func _living_enemy(role: String) -> Node3D:
	for n in get_tree().get_nodes_in_group("enemies"):
		if String(n.get("role")) == role and n is Node3D and bool(n.get("alive")):
			return n as Node3D
	return null

func _surface_villager() -> Node3D:
	for n in get_tree().get_nodes_in_group("villagers"):
		if not (n is Node3D):
			continue
		var st := int(n.get("state"))
		if st == int(VillagerAI.State.HIDDEN) or st == int(VillagerAI.State.ESCORTED) or st == int(VillagerAI.State.TRANSFERRED) or st == int(VillagerAI.State.DEAD):
			continue
		return n as Node3D
	return null

func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _db(linear: float) -> float:
	if linear <= 0.001:
		return -80.0
	return linear_to_db(linear)
