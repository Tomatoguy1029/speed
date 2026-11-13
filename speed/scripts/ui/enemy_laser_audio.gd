## チャージ音は敵の個体IDで所有し、取り消し・死亡・画面退出で回収する。
## 溜め音は敵ごとの溜め時間にちょうど鳴り終わるよう、再生の速さ（音の高さも）を変える。
extends Node

## 溜め時間に合わせて変える速さの範囲。これを超える差は合わせきらない。
const FIT_MIN := 0.25
const FIT_MAX := 4.0

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
		player.pitch_scale = maxf(0.01,_voices[id].rate*frame.ui.world_scale)
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
		var p := AudioManager.settings(&"enemy.beamer.charge")
		player.volume_db = float(p.get("volume_db", 0.0))
		var rate := 1.0
		var time := float(event.get("time", 0.0))
		if time > 0.0 and stream.get_length() > 0.0 and not p.get("loop", false): rate = clampf(stream.get_length()/time, FIT_MIN, FIT_MAX)
		player.pitch_scale = rate
		add_child(player)
		_voices[id] = {"row": int(event.row), "player": player, "rate": rate}
		player.play()

func stop(id: int) -> void:
	if not _voices.has(id): return
	var player: AudioStreamPlayer = _voices[id].player
	player.stop()
	player.queue_free()
	_voices.erase(id)

func clear() -> void:
	for id in _voices.keys(): stop(id)
