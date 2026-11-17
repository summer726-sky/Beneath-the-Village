extends Node
class_name NarrativeBed
## 入口一层很低的持续音，走单独的 Narrative 总线。
## 不改 AudioDirector 的环境声、口令和音量存档。
## 扫荡那一句把这层拉到无声；风声仍由原来的环境声负责。

const BUS := &"Narrative"
const RATE := 22050

var _player: AudioStreamPlayer
var _hushed := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	_player.stream = _drone()
	_player.volume_db = -80.0
	add_child(_player)
	_player.play()


func hush(silent: bool) -> void:
	if _player == null:
		return
	if silent == _hushed:
		return
	_hushed = silent
	var target := -80.0 if silent else 0.0
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", target, 1.15)


func fade_out() -> void:
	if _player == null:
		return
	_hushed = true
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", -80.0, 0.7)
	tween.tween_callback(_player.stop)


func _ensure_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, &"Master")
	# 组音量固定偏轻，不再去改 Master。0 dB 的播放器已经按峰值压过。
	AudioServer.set_bus_volume_db(idx, -20.0)


static func _drone() -> AudioStreamWAV:
	var seconds := 8.0
	var n := int(RATE * seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 194205
	var noise := 0.0
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var swell := 0.72 + 0.28 * sin(TAU * t / seconds)
		noise += (rng.randf_range(-1.0, 1.0) - noise) * 0.015
		var body := sin(TAU * 49.0 * t) * 0.34
		var fifth := sin(TAU * 73.5 * t) * 0.16
		var octave := sin(TAU * 98.0 * t) * 0.08
		samples[i] = (body + fifth + octave + noise * 0.12) * swell
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(samples[i]))
	var gain := 0.28 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
