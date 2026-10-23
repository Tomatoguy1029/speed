## 仮の効果音の合成値。音声の生成は制作工程だけで行う。
@tool
extends RefCounted
const SAMPLE_RATE := 22050

static func build(output: String) -> Error:
	var bank := AudioBank.new()
	var _sounds := bank.sounds
	_sounds[&"hit"] = _tone(520.0, 260.0, 0.06, "square")
	_sounds[&"kill"] = _tone(300.0, 90.0, 0.12, "noise")
	_sounds[&"block"] = _tone(180.0, 140.0, 0.08, "square")
	_sounds[&"hurt"] = _tone(140.0, 60.0, 0.2, "saw")
	_sounds[&"levelup"] = _tone(440.0, 880.0, 0.25, "sine")
	_sounds[&"pickup"] = _tone(880.0, 1200.0, 0.05, "sine")
	_sounds[&"dash"] = _tone(200.0, 900.0, 0.18, "noise")
	_sounds[&"shoot"] = _tone(700.0, 500.0, 0.04, "square")
	_sounds[&"boom"] = _tone(120.0, 30.0, 0.5, "noise")
	_sounds[&"ui"] = _tone(660.0, 660.0, 0.04, "sine")

	return ResourceSaver.save(bank, output)

static func _tone(f0: float, f1: float, length: float, wave: String) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * length)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 31.0 + f1)
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k)
		phase += f / SAMPLE_RATE
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":
				s = fmod(phase, 1.0) * 2.0 - 1.0
			"noise":
				s = rng.randf_range(-1.0, 1.0)
			_:
				s = sin(phase * TAU)
		var env := (1.0 - k) * minf(1.0, i / 40.0)
		bytes.encode_s16(i * 2, int(clampf(s * env * 0.35, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = bytes
	return wav
