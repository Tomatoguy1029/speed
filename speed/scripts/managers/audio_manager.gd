## 音。Autoload（設計書 4.3・13）。
##
## ダッシュは専用バスでスロー減衰を除外し、音量と消音は設定（SaveManager）に従う。
## 制作工程でまとめた納品音声と短い仮の合成音を読む（仕様書 18）。
## 通常効果音は再生口を使い回し、ダッシュとBGMは専用の再生口を持つ。
extends Node

const MAX_VOICES := 12
const DASH_VOICE = preload("res://scripts/managers/dash_audio_voice.gd")
var _dash_voice: Node

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _sounds: Dictionary = {}
var _missing_sounds: Dictionary = {}
var _music: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_track: StringName = &""
var _music_owner: Node
var _music_fade: Tween
var _slow_motion := false
var _slow_gain := 1.0
var _slow_fade: Tween

func _ready() -> void:
	_ensure_bus(&"SFX")
	_ensure_bus(&"Engine")
	_ensure_bus(&"Music")
	_ensure_bus(&"Dash")
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)
	for i in MAX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_reload_bank()
	SaveManager.settings_changed.connect(_apply_volumes)
	_apply_volumes()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		toggle_mute()

func toggle_mute() -> void:
	SaveManager.set_setting("muted", not bool(SaveManager.settings.muted))

## 効果音を鳴らす。名前は制作工程の build_audio.gd の一覧。
func sound(name: StringName) -> AudioStream:
	return _sounds.get(name)

func play(name: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	if name == &"dash":
		start_dash(volume_db, pitch)
		return
	if not _sounds.has(name) and not _missing_sounds.has(name):
		# 開発中に生成済みバンクが更新されても、既存の再生口の音は止めない。
		_reload_bank()
		if not _sounds.has(name):
			_missing_sounds[name] = true
			push_error("音声バンクに効果音がありません: %s" % name)
	var stream: AudioStream = _sounds.get(name)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % MAX_VOICES
	p.stream = stream
	p.volume_db = volume_db - 20.0 if name == &"hurt" else volume_db
	p.pitch_scale = pitch
	p.play()

func _reload_bank() -> void:
	var bank := ResourceLoader.load("res://.content/audio.res", "", ResourceLoader.CACHE_MODE_IGNORE) as AudioBank
	if bank != null:
		_sounds = bank.sounds.duplicate()
		_music = bank.music.duplicate()

## 単一のBGM再生口。切り替え中の再要求や画面退出は古いTweenを取り消す。
func play_music(name: StringName, fade_seconds := 1.0, owner: Node = null) -> void:
	if name == _music_track:
		_music_owner = owner
		return
	if not _music.has(name): _reload_bank()
	var song := _music.get(name) as AudioStream
	if song == null:
		push_error("音声バンクにBGMがありません: %s" % name)
		return
	_music_track = name
	_music_owner = owner
	if _music_fade != null: _music_fade.kill()
	_music_fade = create_tween()
	if _music_player.playing and fade_seconds > 0.0:
		_music_fade.tween_property(_music_player, "volume_linear", 0.0, fade_seconds)
	_music_fade.tween_callback(func():
		_music_player.stop()
		_music_player.stream = song
		_music_player.volume_linear = 0.0 if fade_seconds > 0.0 else 1.0
		_music_player.play(song.loop_offset if song is AudioStreamMP3 else 0.0))
	_music_fade.tween_property(_music_player, "volume_linear", 1.0, minf(fade_seconds, 0.6))
func stop_music(owner: Node = null) -> void:
	if owner != null and _music_owner != owner: return
	_music_owner = null
	if _music_fade != null:
		_music_fade.kill()
		_music_fade = null
	_music_track = &""
	_music_player.stop()
	_music_player.stream = null

## 開始・移動中・終了音を専用の再生口へ渡す。
func start_dash(volume_db := -6.0, pitch := 1.0) -> void:
	if not _sounds.has(&"dash_loop") or not _sounds.has(&"dash_end"): return
	end_dash()
	_dash_voice = DASH_VOICE.new()
	add_child(_dash_voice)
	_dash_voice.start(_sounds, volume_db, pitch)
func end_dash() -> void:
	if is_instance_valid(_dash_voice): _dash_voice.finish()
	_dash_voice = null

## ユーザー設定を保ったまま、BGM・効果音をまとめて減衰する。
func set_slow_motion(enabled: bool) -> void:
	if _slow_motion == enabled: return
	_slow_motion = enabled
	if _slow_fade != null: _slow_fade.kill()
	_slow_fade = create_tween().set_ignore_time_scale(true)
	_slow_fade.tween_method(_set_slow_gain, _slow_gain, 0.35 if enabled else 1.0, 0.15 if enabled else 0.25)

func _set_slow_gain(gain: float) -> void:
	_slow_gain = gain
	_apply_volumes()

func _apply_volumes() -> void:
	var s := SaveManager.settings
	var slow_gain := _slow_gain
	_set_bus(&"Master", float(s.master_volume), bool(s.muted))
	_set_bus(&"SFX", float(s.sfx_volume) * slow_gain, false)
	_set_bus(&"Engine", float(s.engine_volume) * slow_gain, false)
	_set_bus(&"Music", float(s.get("music_volume", 0.5)) * slow_gain, false)
	_set_bus(&"Dash", float(s.sfx_volume), false)

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
