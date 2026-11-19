extends SceneTree
## godot --headless --path . -s res://tests/audio_bank_test.gd

const Lines = preload("res://scripts/audio/period_lines.gd")
const Tones = preload("res://scripts/audio/tone_bank.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	var streams: Array[AudioStreamWAV] = [
		Tones.bell(),
		Tones.foot_cloth(),
		Tones.foot_boot(),
		Tones.foot_tunnel(),
		Tones.rifle(),
		Tones.empty_bolt(),
		Tones.wood_break(),
		Tones.mine(),
		Tones.water_loop(),
		Tones.wind_loop(),
	]
	for s in streams:
		if s == null or s.data.size() < 400:
			errors.append("合成波形过短")
			break
	var wind: AudioStreamWAV = Tones.wind_loop()
	if wind.loop_mode != AudioStreamWAV.LOOP_FORWARD or wind.loop_end < 1000:
		errors.append("风声没有循环")
	if Lines.VILLAGER_ALARM.contains("各小组注意") or Lines.PLAYER_EXPLORE.contains("高！实在是高"):
		errors.append("口令误用了电影台词")
	if not str(Lines.VILLAGER_ALARM).contains("北房"):
		errors.append("村民口令没有对上北房藏身点")
	if str(Lines.ENEMY_ADVANCE) != "前へ！" or str(Lines.ENEMY_FIRE) != "撃て！" or str(Lines.ENEMY_HOLE) != "穴を探せ！" or str(Lines.ENEMY_POUR) != "井戸に水を入れろ！":
		errors.append("敌军口令应只写日语")
	for line in [Lines.ENEMY_ADVANCE, Lines.ENEMY_FIRE, Lines.ENEMY_HOLE, Lines.ENEMY_POUR]:
		if "敌军" in str(line) or "射击" in str(line) or "向前" in str(line) or "搜洞" in str(line) or "灌水" in str(line):
			errors.append("敌军口令附了中文译文")
	for row in Lines.spoken_rows():
		var text := String(row).split("|")[1]
		if text.contains("Reload") or text.contains("Enemy"):
			errors.append("口语里混进了英文：%s" % text)
	var voices: PackedStringArray = [
		"player_explore", "player_warn", "player_hide", "player_quiet",
		"villager_1_alarm", "villager_1_water",
		"villager_2_alarm", "villager_2_water",
		"villager_3_alarm", "villager_3_water",
		"ally_jia_port", "ally_jia_barrier", "ally_jia_standby",
		"ally_yi_port", "ally_yi_barrier", "ally_yi_standby",
		"enemy_0_advance", "enemy_0_fire", "enemy_3_pour", "enemy_5_hole",
	]
	for id in voices:
		var path := "res://audio/voice/%s.wav" % id
		if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size() < 8000:
			errors.append("缺少配音：%s" % id)
	if Lines.ally_voice_id("甲", "守这个孔") != "ally_jia_port":
		errors.append("战友甲的配音编号不对")
	if Lines.ally_voice_id("乙", "去关隔板") != "ally_yi_barrier":
		errors.append("战友乙的配音编号不对")
	if Lines.villager_voice_id(1, false) != "villager_1_alarm" or Lines.villager_voice_id(2, true) != "villager_2_water":
		errors.append("村民配音编号不对")
	if Lines.enemy_voice_id(3, "pour") != "enemy_3_pour":
		errors.append("日军配音编号不对")
	if errors.is_empty():
		print("=== AUDIO BANK PASSED ===")
		quit(0)
	else:
		print("=== AUDIO BANK FAILED ===")
		for e in errors:
			print("FAIL: ", e)
		quit(1)
