## 音。Autoload（設計書 4.3・13）。
##
## バスは「Master（全体）」「SFX（効果音）」「Engine（エンジン音）」。音量と消音は設定（SaveManager）に従う。
## 音そのものは仮：起動時に短い合成音を作って鳴らす（音の方向性は未決、仕様書 18）。
## 同時に鳴らす数には上限を設け、再生口を使い回す。
extends Node

const MAX_VOICES := 12
const SAMPLE_RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _sounds: Dictionary = {}

func _ready() -> void:
	_ensure_bus(&"SFX")
	_ensure_bus(&"Engine")
	for i in MAX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_build_sounds()
	SaveManager.settings_changed.connect(_apply_volumes)
	_apply_volumes()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		toggle_mute()

func toggle_mute() -> void:
	SaveManager.set_setting("muted", not bool(SaveManager.settings.muted))

## 効果音を鳴らす。名前は _build_sounds() の一覧。
func play(name: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStream = _sounds.get(name)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % MAX_VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

func _apply_volumes() -> void:
	var s := SaveManager.settings
	_set_bus(&"Master", float(s.master_volume), bool(s.muted))
	_set_bus(&"SFX", float(s.sfx_volume), false)
	_set_bus(&"Engine", float(s.engine_volume), false)

func _set_bus(bus: StringName, linear: float, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, muted or linear <= 0.0)

func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, &"Master")

# 仮の効果音（周波数の始まりと終わり、長さ、音色）
func _build_sounds() -> void:
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

func _tone(f0: float, f1: float, length: float, wave: String) -> AudioStreamWAV:
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
