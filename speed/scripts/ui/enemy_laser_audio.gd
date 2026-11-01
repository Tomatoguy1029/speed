## チャージ音は敵の個体IDで所有し、取り消し・死亡・画面退出で回収する。
extends Node

var _voices: Dictionary = {}

func handle(event: Dictionary) -> void:
	var id := int(event.id)
	stop(id)
	if event.type == &"enemy_laser_fire":
		AudioManager.play(&"enemy_laser_fire", -12.0)
	elif event.type == &"enemy_laser_charge":
		var stream := AudioManager.sound(&"enemy_laser_charge")
		if stream == null: return
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = &"SFX"
		player.volume_db = -16.0
		add_child(player)
		_voices[id] = {"row": int(event.row), "player": player}
		player.play()

func sync(run: RunSimulation) -> void:
	if run.state.phase in [RunState.Phase.FINISHING, RunState.Phase.ENDED]:
		clear()
		return
	var paused := run.state.phase != RunState.Phase.PLAY or run.ui_overlay_active or run.ui_reward_active
	var table := run.enemies.table
	for id in _voices.keys():
		var voice: Dictionary = _voices[id]
		var row := int(voice.row)
		if not run.enemies.is_same(row, id) or table.dead[row] != 0 or table.mode[row] != EnemyTable.Mode.WINDUP:
			stop(id)
			continue
		var player: AudioStreamPlayer = voice.player
		player.stream_paused = paused or table.stone[row] > 0.0 or table.held[row] != 0 \
			or table.shove_time[row] > 0.0 or table.knock_t[row] > 0.0 or run.state.hitstop > 0.0
		player.pitch_scale = maxf(0.01, run.draw.world_scale())

func stop(id: int) -> void:
	if not _voices.has(id): return
	var player: AudioStreamPlayer = _voices[id].player
	player.stop()
	player.queue_free()
	_voices.erase(id)

func clear() -> void:
	for id in _voices.keys(): stop(id)
