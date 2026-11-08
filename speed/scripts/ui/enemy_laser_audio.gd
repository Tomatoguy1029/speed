## チャージ音は敵の個体IDで所有し、取り消し・死亡・画面退出で回収する。
extends Node

var _voices: Dictionary = {}
var _cpp_epoch := 0

func consume_cpp_frame(frame: Dictionary) -> bool:
	if frame.epoch!=_cpp_epoch:
		clear()
		_cpp_epoch = frame.epoch
	for notice: Dictionary in frame.events:
		if notice.type not in [&"enemy_laser_charge",&"enemy_laser_cancel",&"enemy_laser_fire"]: continue
		var event: Dictionary = notice.payload.duplicate(true)
		event["type"] = notice.type
		handle(event)
	var active := {}
	for voice: Dictionary in frame.ui.get("laser_voices",[]):
		active[voice.id] = voice
		if not _voices.has(voice.id): handle({"id":voice.id,"row":0,"type":&"enemy_laser_charge"})
	for id in _voices.keys():
		if not active.has(id):
			stop(id)
			continue
		var player: AudioStreamPlayer = _voices[id].player
		player.stream_paused = active[id].paused
		player.pitch_scale = maxf(0.01,frame.ui.world_scale)
	return true

func handle(event: Dictionary) -> void:
	var id := int(event.id)
	stop(id)
	if event.type == &"enemy_laser_fire":
		AudioManager.play(&"enemy.beamer.fire")
	elif event.type == &"enemy_laser_charge":
		# 何体もが同時に溜めても、溜め音は同時に鳴らす上限までにする。
		if _voices.size() >= AudioManager.MAX_SAME_SOUND: return
		var stream := AudioManager.sound(&"enemy.beamer.charge")
		if stream == null: return
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = &"SFX"
		player.volume_db = float(AudioManager.settings(&"enemy.beamer.charge").get("volume_db", 0.0))
		add_child(player)
		_voices[id] = {"row": int(event.row), "player": player}
		player.play()

func stop(id: int) -> void:
	if not _voices.has(id): return
	var player: AudioStreamPlayer = _voices[id].player
	player.stop()
	player.queue_free()
	_voices.erase(id)

func clear() -> void:
	for id in _voices.keys(): stop(id)
