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
	if not str(Lines.ENEMY_FIRE).begins_with("敌军（日语口令）"):
		errors.append("敌军字幕没有标明日语口令")
	for row in Lines.spoken_rows():
		var text := String(row).split("|")[1]
		if text.contains("Reload") or text.contains("Enemy"):
			errors.append("口语里混进了英文：%s" % text)
	if errors.is_empty():
		print("=== AUDIO BANK PASSED ===")
		quit(0)
	else:
		print("=== AUDIO BANK FAILED ===")
		for e in errors:
			print("FAIL: ", e)
		quit(1)
