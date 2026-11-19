extends RefCounted
class_name ToneBank
## 运行时合成的环境声和音效。材质按土路、布鞋、皮鞋、木板、铜钟、单发步枪来做。

const RATE := 22050

static func bell() -> AudioStreamWAV:
	return _pcm(_peak(_bell_samples(2.5, 168.0), 0.9))

static func foot_cloth() -> AudioStreamWAV:
	return _thud(194201, 0.07, 0.16, 85.0, 0.5)

static func foot_boot() -> AudioStreamWAV:
	return _thud(194202, 0.055, 0.48, 160.0, 0.72)

static func foot_tunnel() -> AudioStreamWAV:
	return _thud(194203, 0.08, 0.08, 62.0, 0.42)

static func rifle() -> AudioStreamWAV:
	var n := int(RATE * 0.38)
	var rng := _rng(193701)
	var y := 0.0
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.62
		var crack := y * exp(-t * 14.0)
		var body := sin(TAU * 92.0 * t) * exp(-t * 9.0) * 0.65
		var snap := sin(TAU * 1280.0 * t) * exp(-t * 70.0) * 0.22
		s[i] = crack * 0.8 + body + snap
	return _pcm(_peak(s, 0.92))

static func empty_bolt() -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var rng := _rng(193702)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var click := 0.0
		if t < 0.008 or (t > 0.07 and t < 0.078):
			click = rng.randf_range(-1.0, 1.0)
		var ring := sin(TAU * 1800.0 * t) * exp(-t * 40.0) * 0.15
		s[i] = click * 0.8 + ring
	return _pcm(_peak(s, 0.7))

static func wood_break() -> AudioStreamWAV:
	return _thud(194211, 0.34, 0.22, 110.0, 0.88)

static func wood_slide() -> AudioStreamWAV:
	return _thud(194212, 0.42, 0.12, 90.0, 0.6)

static func body_fall() -> AudioStreamWAV:
	return _thud(194213, 0.28, 0.1, 55.0, 0.75)

static func hit_grunt() -> AudioStreamWAV:
	var n := int(RATE * 0.32)
	var rng := _rng(194250)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var breath := sin(TAU * 92.0 * t) * exp(-t * 7.0) * 0.55
		var rasp := sin(TAU * 210.0 * t) * exp(-t * 11.0) * 0.35
		var noise := rng.randf_range(-0.2, 0.2) * exp(-t * 14.0)
		s[i] = breath + rasp + noise
	return _pcm(_peak(s, 0.72))

static func cloth() -> AudioStreamWAV:
	return _thud(194214, 0.18, 0.2, 70.0, 0.4)

static func mine() -> AudioStreamWAV:
	var n := int(RATE * 0.48)
	var rng := _rng(194220)
	var y := 0.0
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.35
		var blast := y * exp(-t * 7.5)
		var dirt := sin(TAU * 58.0 * t) * exp(-t * 6.0) * 0.8
		s[i] = blast + dirt
	return _pcm(_peak(s, 0.9))

static func gush() -> AudioStreamWAV:
	return _thud(194230, 0.55, 0.18, 48.0, 0.7)

static func wind_loop() -> AudioStreamWAV:
	return _loop_noise(2.0, 0.94, 190001, 0.32)

static func cave_loop() -> AudioStreamWAV:
	return _loop_noise(2.2, 0.975, 190002, 0.28)

static func water_loop() -> AudioStreamWAV:
	return _loop_noise(1.5, 0.86, 190003, 0.5)

static func sting_low() -> AudioStreamWAV:
	return _pcm(_peak(_tone(0.7, 98.0, 3.2), 0.5))

static func sting_soft() -> AudioStreamWAV:
	return _pcm(_peak(_bell_samples(0.9, 220.0), 0.35))

static func load_wav(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	if data.size() < 44 or data.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var idx := 12
	var channels := 1
	var rate := RATE
	var bits := 16
	var pcm := PackedByteArray()
	while idx + 8 <= data.size():
		var cid := data.slice(idx, idx + 4).get_string_from_ascii()
		var sz := data.decode_u32(idx + 4)
		var start := idx + 8
		if sz < 0 or start + sz > data.size():
			break
		if cid == "fmt " and sz >= 16:
			channels = data.decode_u16(start + 2)
			rate = data.decode_u32(start + 4)
			bits = data.decode_u16(start + 14)
		elif cid == "data":
			pcm = data.slice(start, start + sz)
		var step := sz + (sz % 2)
		idx = start + step
	if pcm.is_empty() or bits != 16 or channels < 1 or channels > 2:
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels == 2
	stream.data = pcm
	return stream


static func _bell_samples(dur: float, f0: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var rng := _rng(188811)
	var partials: Array[float] = [1.0, 2.02, 2.99, 4.18, 5.43, 6.8]
	var amps: Array[float] = [1.0, 0.4, 0.26, 0.14, 0.08, 0.04]
	var decays: Array[float] = [1.05, 1.6, 2.3, 3.2, 4.2, 5.4]
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var y := 0.0
		if t < 0.01:
			y += rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.01) * 0.28
		for p in partials.size():
			y += amps[p] * exp(-t * decays[p]) * sin(TAU * f0 * partials[p] * t)
		s[i] = y
	return s

static func _tone(dur: float, freq: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		s[i] = sin(TAU * freq * t) * exp(-t * decay)
	return s

static func _thud(seed_v: int, dur: float, coef: float, body: float, peak: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var rng := _rng(seed_v)
	var y := 0.0
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := 1.0
		if t < 0.004:
			env = t / 0.004
		else:
			env = exp(-t / maxf(dur * 0.32, 0.02))
		y += (rng.randf_range(-1.0, 1.0) - y) * coef
		var thump := sin(TAU * body * t) * exp(-t * 36.0)
		s[i] = y * env + thump * 0.5
	return _pcm(_peak(s, peak))

static func _loop_noise(seconds: float, smooth: float, seed_v: int, peak: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var fade := int(RATE * 0.08)
	var rng := _rng(seed_v)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var y := 0.0
	var coef := clampf(1.0 - smooth, 0.02, 0.5)
	for i in n:
		y += (rng.randf_range(-1.0, 1.0) - y) * coef
		raw[i] = y
	var out_n := n - fade
	var out := PackedFloat32Array()
	out.resize(out_n)
	for i in out_n:
		out[i] = raw[i]
	for i in fade:
		var w := float(i) / float(fade)
		out[i] = lerpf(raw[out_n + i], out[i], w)
	var mean := 0.0
	for i in out_n:
		mean += out[i]
	mean /= float(out_n)
	for i in out_n:
		out[i] -= mean
	return _pcm(_peak(out, peak), out_n)

static func _peak(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for i in samples.size():
		m = maxf(m, absf(samples[i]))
	var g := peak / m
	for i in samples.size():
		samples[i] = clampf(samples[i] * g, -1.0, 1.0)
	return samples

static func _pcm(samples: PackedFloat32Array, loop_end: int = -1) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop_end > 0:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = loop_end
	return wav

static func _rng(seed_v: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	return rng
