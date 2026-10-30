## 納品音声と仮の合成音を制作工程で音声バンクへまとめる。
@tool
extends RefCounted
const SAMPLE_RATE := 22050

static func build(output: String) -> Error:
	var bank := AudioBank.new()
	var _sounds := bank.sounds
	_sounds[&"hit"] = _tone(520.0, 260.0, 0.06, "square")
	_sounds[&"kill"] = _tone(300.0, 90.0, 0.12, "noise")
	_sounds[&"block"] = _tone(180.0, 140.0, 0.08, "square")
	_sounds[&"bounce"] = load("res://assets/audio/sfx/bounce_robot.mp3")
	_sounds[&"hurt"] = load("res://assets/audio/sfx/hurt_robot.mp3")
	_sounds[&"levelup"] = _tone(440.0, 880.0, 0.25, "sine")
	_sounds[&"levelup_notice"] = load("res://assets/audio/sfx/levelup_notice.mp3")
	_sounds[&"pickup"] = _tone(880.0, 1200.0, 0.05, "sine")
	_sounds[&"dash"] = load("res://assets/audio/sfx/dash_start.wav")
	var sustain := load("res://assets/audio/sfx/dash_loop.wav").duplicate() as AudioStreamWAV
	sustain.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sustain.loop_begin = 0
	sustain.loop_end = int(sustain.data.size() / (4 if sustain.stereo else 2))
	_sounds[&"dash_loop"] = sustain
	_sounds[&"dash_end"] = load("res://assets/audio/sfx/dash_end.wav")
	_sounds[&"shoot"] = _tone(700.0, 500.0, 0.04, "square")
	_sounds[&"blaster"] = load("res://assets/audio/sfx/blaster_shot.wav")
	_sounds[&"contact_arc"] = load("res://assets/audio/sfx/contact_arc.mp3")
	_sounds[&"bomber_explode"] = load("res://assets/audio/sfx/bomber_explode.wav")
	_sounds[&"enemy_laser_charge"] = load("res://assets/audio/sfx/enemy_laser_charge.mp3")
	_sounds[&"enemy_laser_fire"] = load("res://assets/audio/sfx/enemy_laser_fire.mp3")
	_sounds[&"roar"] = _tone(90.0,38.0,1.0,"saw")
	_sounds[&"boom"] = _tone(120.0, 30.0, 0.5, "noise")
	_sounds[&"menu_open"] = load("res://assets/audio/sfx/menu_open.mp3")
	_sounds[&"upgrade_apply"] = load("res://assets/audio/sfx/upgrade_apply.mp3")
	_sounds[&"ui"] = load("res://assets/audio/sfx/ui_confirm.mp3")
	_sounds[&"stage_select_click"] = load("res://assets/audio/sfx/stage_select_click.mp3")

	for name in _sounds:
		if _sounds[name] == null:
			push_error("音源を読み込めません: %s" % name)
			return ERR_CANT_OPEN
	for entry in [[&"battle", "kulakovka-space-283176.mp3"], [&"boss", "nastelbom-war-391660.mp3"], [&"menu", "leberch-space-ambient-509783.mp3"],
		[&"stage_select", "atlasaudio-space-music-625739.mp3"]]:
		var song := load("res://assets/audio/music/" + entry[1]) as AudioStreamMP3
		if song == null: return ERR_CANT_OPEN
		song = song.duplicate() as AudioStreamMP3
		song.loop = true
		if entry[0] == &"stage_select": song.loop_offset = 26.0
		bank.music[entry[0]] = song
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
