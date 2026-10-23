## 音。Autoload（設計書 4.3・13）。
##
## バスは「Master（全体）」「SFX（効果音）」「Engine（エンジン音）」。音量と消音は設定（SaveManager）に従う。
## 音そのものは仮：制作工程で焼いた短い合成音を読む（音の方向性は未決、仕様書 18）。
## 同時に鳴らす数には上限を設け、再生口を使い回す。
extends Node

const MAX_VOICES := 12

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
	var bank := load("res://.content/audio.res") as AudioBank
	if bank != null: _sounds = bank.sounds
	SaveManager.settings_changed.connect(_apply_volumes)
	_apply_volumes()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		toggle_mute()

func toggle_mute() -> void:
	SaveManager.set_setting("muted", not bool(SaveManager.settings.muted))

## 効果音を鳴らす。名前は制作工程の build_audio.gd の一覧。
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
