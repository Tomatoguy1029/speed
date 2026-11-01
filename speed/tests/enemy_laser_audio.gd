## 予告の中断・再開と、複数方向の同時照射で音声の寿命を確認する。
extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func deliver(run: RunSimulation, audio: Node) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for event in run.state.events:
		if event.type in [&"enemy_laser_charge", &"enemy_laser_cancel", &"enemy_laser_fire"]:
			kinds.append(event.type)
			audio.handle(event)
	run.state.events.clear()
	return kinds

func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var run := session.sim
	run.state.ship_pos = Vector2.ZERO
	run.state.enemy_aim = Vector2.ZERO
	var t := run.enemies.table
	var audio := preload("res://scripts/ui/enemy_laser_audio.gd").new()
	add_child(audio)
	for type in [&"cross", &"beamer", &"ruler", &"aquarius"]:
		var def := run.enemies.def_of(type)
		var row := run.enemies.spawn(def, Vector2(0, -float(def.params.get("approach", 200.0))))
		t.fire_t[row] = 0.0
		t.mode[row] = EnemyTable.Mode.MOVE
		if type == &"ruler":
			t.buds[row] = 1
			t.mode[row] = EnemyTable.Mode.DASH
			t.timer[row] = 0.0
		var behavior := run.enemies.behaviors[t.beh[row]]
		run.state.events.clear()
		behavior.step(row, 0.01)
		check(deliver(run, audio).count(&"enemy_laser_charge") == 1, "予告開始に1回鳴らす: " + String(type))
		check(audio._voices.has(t.id[row]), "個体ごとにチャージ音を持つ: " + String(type))
		var before := AudioManager._next
		behavior.step(row, float(def.params.telegraph) + 0.01)
		check(deliver(run, audio).count(&"enemy_laser_fire") == 1, "複数方向でも発射音は1回: " + String(type))
		check(AudioManager._next == (before + 1) % AudioManager.MAX_VOICES, "発射音を再生する: " + String(type))
		check(not audio._voices.has(t.id[row]), "発射でチャージ音を停止: " + String(type))
	var row := run.enemies.spawn(run.enemies.def_of(&"telescope"), Vector2(200, 0))
	run.field.bodies.clear()
	t.attack_managed[row] = 0
	var id := t.id[row]
	var behavior := run.enemies.behaviors[t.beh[row]]
	t.mode[row] = EnemyTable.Mode.MOVE
	t.facing[row] = PI
	t.charge[row] = 1.0
	run.state.events.clear()
	behavior.step(row, 0.01)
	check(deliver(run, audio).has(&"enemy_laser_charge"), "望遠鏡座の本チャージ開始に音を鳴らす")
	if not audio._voices.has(id):
		print("[enemy_laser_audio] charge setup failed")
		get_tree().quit(1)
		return
	var first: AudioStreamPlayer = audio._voices[id].player
	var before := AudioManager._next
	run.state.ship_pos = Vector2(100000, 0)
	behavior.step(row, 0.01)
	check(deliver(run, audio).has(&"enemy_laser_cancel"), "望遠鏡座の照準解除を通知する")
	check(not first.playing and not audio._voices.has(id), "解除で音を即座に停止する")
	check(AudioManager._next == before, "取り消した攻撃の発射音を鳴らさない")
	t.mode[row] = EnemyTable.Mode.WINDUP
	audio.handle({"type": &"enemy_laser_charge", "id": id, "row": row})
	var second: AudioStreamPlayer = audio._voices[id].player
	check(second != first and second.playing, "再チャージは新しい再生口で先頭から開始する")
	run.state.drawing = true
	audio.sync(run)
	check(is_equal_approx(second.pitch_scale, run.draw.world_scale()), "スロー中はチャージ音も遅く進む")
	run.state.phase = RunState.Phase.PAUSED
	audio.sync(run)
	check(second.stream_paused, "ポーズ中はチャージ音を止める")
	run.state.phase = RunState.Phase.PLAY
	run.state.drawing = false
	audio.sync(run)
	check(not second.stream_paused and is_equal_approx(second.pitch_scale, 1.0), "再開で通常の再生へ戻す")
	t.dead[row] = 1
	audio.sync(run)
	check(not second.playing and audio._voices.is_empty(), "撃破された個体のチャージ音を回収する")
	audio.free()
	session.free()
	for player in AudioManager._players: player.stop()
	await get_tree().process_frame
	print("[enemy_laser_audio] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
