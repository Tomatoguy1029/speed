## One dash owns its players. Other effects and later dashes cannot steal its release.
extends Node
var attack: AudioStreamPlayer
var sustain: AudioStreamPlayer
var release: AudioStreamPlayer
var ending := false
var _fade_done := true
## voices は開始・移動中・終了の順に {stream, volume_db, pitch}。開始音がなければすぐ移動中の音にする。
func start(voices: Array[Dictionary]) -> void:
	attack = _player(voices[0])
	sustain = _player(voices[1])
	release = _player(voices[2])
	attack.finished.connect(_attack_finished)
	release.finished.connect(_collect)
	if attack.stream == null: _attack_finished()
	else: attack.play()
func _player(voice: Dictionary) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Dash"
	player.stream = voice.stream
	player.volume_db = voice.volume_db
	player.pitch_scale = voice.pitch
	add_child(player)
	return player
func finish() -> void:
	if ending: return
	ending = true
	release.play()
	var duration := release.stream.get_length() / release.pitch_scale
	var tail_fade := minf(0.2, duration * 0.4)
	var tail := create_tween().set_ignore_time_scale(true)
	tail.tween_interval(maxf(0.0, duration - tail_fade))
	tail.tween_property(release, "volume_linear", 0.0, tail_fade)
	if sustain.playing:
		_fade_done = false
		var fade := create_tween().set_ignore_time_scale(true)
		var fade_seconds := minf(0.12, sustain.stream.get_length() / sustain.pitch_scale * 0.25)
		fade.tween_property(sustain, "volume_linear", 0.0, fade_seconds)
		fade.tween_callback(func():
			sustain.stop()
			_fade_done = true
			_collect())
	_collect()
func _attack_finished() -> void:
	if not ending: sustain.play()
	else: _collect()
func _collect() -> void:
	if ending and _fade_done and not attack.playing and not release.playing:
		queue_free()
