## 制作時に合成した音は、元の波形と同じデータを読み込む。
extends Node
const EXPECTED := {
	"block": {
		"hash": "bffdb464e57077af9d6cd023acd05f347580df13686e5c97adb6d96ceb76d676",
		"rate": 22050,
		"size": 3528
	},
	"boom": {
		"hash": "d9cf7b2f07eeec614744e9ec60fd9b5624b578c20f53fb33a4e2c58b9968b084",
		"rate": 22050,
		"size": 22050
	},

	"hit": {
		"hash": "5da78562aab917b6d0ecb27af43212180bfff246039a670f2a5c7c1a82766863",
		"rate": 22050,
		"size": 2646
	},
	"kill": {
		"hash": "640320e43cb28091db1574b84368f4115f494faf0e7ffac54d7dd6edf509b8c6",
		"rate": 22050,
		"size": 5292
	},
	"levelup": {
		"hash": "aa946cb1e3e3066b57f5ea4f40e342bd3de01442590680c9b4261519907ef093",
		"rate": 22050,
		"size": 11024
	},
	"pickup": {
		"hash": "3c61ef68b0cba6c26664ddc54d02ebc33ff7f540246ccad76f5c0b78cc151ee4",
		"rate": 22050,
		"size": 2204
	},
	"shoot": {
		"hash": "723723f560cfde53fc2f5a985c38ac94b173795f1db474d27d191ede479903e0",
		"rate": 22050,
		"size": 1764
	},

}
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	check(not AudioManager.has_method("_build_sounds"), "起動時の音声合成を持たない")
	for name in EXPECTED:
		var wav: AudioStreamWAV = AudioManager._sounds[StringName(name)]
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(wav.data)
		check(hash.finish().hex_encode() == EXPECTED[name].hash, "波形を維持する: " + name)
		check(wav.mix_rate == EXPECTED[name].rate and wav.data.size() == EXPECTED[name].size, "長さとサンプル周波数を維持する: " + name)
	for song in [&"battle", &"boss", &"menu", &"stage_select"]:
		var music := AudioManager._music.get(song) as AudioStreamMP3
		check(music != null and music.loop and music.get_length() > 0.0, "BGMをループ再生できる: " + String(song))
	AudioManager.play_music(&"battle", 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(AudioManager._music_player.playing and AudioManager._music_player.stream == AudioManager._music[&"battle"], "通常戦闘曲を開始する")
	AudioManager.play_music(&"boss", 0.08)
	check(AudioManager._music_player.stream == AudioManager._music[&"battle"], "フェードアウト中は前の曲を保持する")
	await get_tree().create_timer(0.25).timeout
	check(AudioManager._music_player.stream == AudioManager._music[&"boss"] and AudioManager._music_player.playing, "フェード後にボス曲へ切り替える")
	AudioManager.play_music(&"battle", 0.2)
	AudioManager.stop_music()
	await get_tree().create_timer(0.3).timeout
	check(not AudioManager._music_player.playing and AudioManager._music_player.stream == null, "画面退出時は切り替え中でも再生を再開しない")
	var old_screen := Node.new()
	var menu_screen := Node.new()
	AudioManager.play_music(&"battle", 0.0, old_screen)
	await get_tree().process_frame
	AudioManager.play_music(&"menu", 0.0, menu_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	AudioManager.stop_music(old_screen)
	check(AudioManager._music_track == &"menu" and AudioManager._music_player.playing, "前の戦闘画面の退出でメニューBGMを停止しない")
	AudioManager.stop_music(menu_screen)
	old_screen.free()
	menu_screen.free()
	var select_music := AudioManager._music.get(&"stage_select") as AudioStreamMP3
	check(select_music != null and is_equal_approx(select_music.loop_offset, 26.0), "ステージセレクト曲のループを26秒地点から始める")
	var main := preload("res://scripts/ui/main.gd").new()
	add_child(main._fade)
	main._sync_screen_music(GameManager.Screen.STAGE_SELECT)
	await get_tree().process_frame
	await get_tree().process_frame
	check(AudioManager._music_track == &"stage_select" and AudioManager._music_player.stream == select_music, "ステージセレクト画面に専用BGMを割り当てる")
	check(AudioManager._music_player.get_playback_position() >= 26.0, "初回再生も冒頭を飛ばして26秒から始める")
	check(AudioManager._music_player.volume_linear < 1.0, "ステージセレクト曲をフェードインする")
	await get_tree().create_timer(0.7).timeout
	check(is_equal_approx(AudioManager._music_player.volume_linear, 1.0), "フェードイン後は通常音量へ到達する")
	main._sync_screen_music(GameManager.Screen.INTRO)
	check(not AudioManager._music_player.playing, "導入画面への移動でステージセレクト曲を停止する")
	main._sync_screen_music(GameManager.Screen.MAIN_MENU)
	await get_tree().process_frame
	await get_tree().process_frame
	check(AudioManager._music_track == &"menu", "メニューへ戻ると通常のメニュー曲へ切り替える")
	AudioManager.stop_music()
	main._fade.free()
	main.free()
	for sound in [&"menu_open", &"upgrade_apply", &"ui", &"stage_select_click", &"hurt", &"bounce", &"contact_arc", &"enemy_laser_charge", &"enemy_laser_fire"]:
		var stream := AudioManager._sounds.get(sound) as AudioStreamMP3
		check(stream != null, "強化用MP3を読み込む: " + String(sound))
		if stream != null: check(not stream.loop and stream.get_length() > 0.0, "強化音を一回再生できる: " + String(sound))
	AudioManager._sounds.erase(&"menu_open")
	AudioManager.play(&"menu_open")
	check(AudioManager._sounds.has(&"menu_open"), "更新前のバンクを保持していても強化音を再読込する")
	var opened: AudioStreamPlayer = AudioManager._players[(AudioManager._next - 1 + AudioManager.MAX_VOICES) % AudioManager.MAX_VOICES]
	check(opened.playing and opened.stream is AudioStreamMP3, "強化画面の音を再生口へ渡す")
	opened.stop()
	var dash := AudioManager._sounds.get(&"dash") as AudioStreamWAV
	var loop := AudioManager._sounds.get(&"dash_loop") as AudioStreamWAV
	var tail := AudioManager._sounds.get(&"dash_end") as AudioStreamWAV
	check(dash != null and tail != null and loop != null, "開始・維持・終了音を用意する")
	if dash != null and tail != null and loop != null:
		check(dash.loop_mode == AudioStreamWAV.LOOP_DISABLED and tail.loop_mode == AudioStreamWAV.LOOP_DISABLED, "開始と終了は一回再生")
		check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.loop_end > 0, "移動中だけループする")
		AudioManager.start_dash(-6.0)
		var first = AudioManager._dash_voice
		check(is_equal_approx(first.attack.volume_db, -6.0), "新しいダッシュ音は基本音量で再生する")
		for player in [first.attack, first.sustain, first.release]:
			check(player.bus == &"Dash", "ダッシュの開始・ループ・余韻は専用バスで再生する")
		AudioManager.end_dash()
		check(first.attack.playing and first.release.playing, "短いダッシュでも開始音を切らず終了音を鳴らす")
		for i in 40: AudioManager.play(&"hurt")
		check(first.attack.playing and first.release.playing, "ほかの効果音で上書きされない")
		AudioManager.start_dash(-6.0)
		var second = AudioManager._dash_voice
		check(first.release.playing, "次のダッシュでも前の余韻を切らない")
		await second.attack.finished
		check(second.sustain.playing, "長いダッシュは維持音につながる")
		AudioManager.end_dash()
		check(second.release.playing, "ダッシュ終了から余韻を最後まで鳴らす")
		var release_volume: float = second.release.volume_linear
		await get_tree().create_timer(second.release.stream.get_length() / second.release.pitch_scale - 0.08).timeout
		check(second.release.playing and second.release.volume_linear < release_volume * 0.9, "余韻は音源の長さに合わせて再生終了前にフェードする")
		await second.release.finished
		await get_tree().process_frame
		await get_tree().process_frame
		check(not is_instance_valid(first) and not is_instance_valid(second), "終了後は専用の再生口を回収する")
	AudioManager.play(&"hurt", -4.0)
	var hurt: AudioStreamPlayer = AudioManager._players[(AudioManager._next - 1 + AudioManager.MAX_VOICES) % AudioManager.MAX_VOICES]
	check(hurt.stream == AudioManager._sounds[&"hurt"] and is_equal_approx(hurt.volume_db, -24.0), "被弾素材を控えめな音量で再生する")
	var master := AudioServer.get_bus_index(&"Master")
	var original_volume := float(SaveManager.settings.master_volume)
	var original_muted := bool(SaveManager.settings.muted)
	var sfx := AudioServer.get_bus_index(&"SFX")
	var dash_bus := AudioServer.get_bus_index(&"Dash")
	var sfx_volume := float(SaveManager.settings.sfx_volume)
	AudioManager.set_slow_motion(true)
	check(is_equal_approx(AudioManager._slow_gain, 1.0), "スロー開始時に音量を即座に落とさない")
	await get_tree().create_timer(0.06).timeout
	check(AudioManager._slow_gain > 0.35 and AudioManager._slow_gain < 1.0, "スロー開始は途中の音量を通る")
	var partial_gain := AudioManager._slow_gain
	AudioManager.set_slow_motion(false)
	check(is_equal_approx(AudioManager._slow_gain, partial_gain), "切替途中の反転は現在の音量からつなぐ")
	await get_tree().create_timer(0.3).timeout
	check(is_equal_approx(AudioManager._slow_gain, 1.0), "スロー解除のフェードが通常音量へ戻る")
	AudioManager.set_slow_motion(true)
	await get_tree().create_timer(0.2).timeout
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(master)), original_volume), "スロー中もマスター設定を維持する")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sfx)), sfx_volume * 0.35), "スロー中は通常効果音を35%にする")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(dash_bus)), sfx_volume), "ダッシュはスロー中も通常音量を維持する")
	check(AudioServer.get_bus_send(dash_bus) == &"Master", "ダッシュにもマスター音量と消音を適用する")
	for bus in [&"Engine", &"Music"]:
		var volume := float(SaveManager.settings.engine_volume if bus == &"Engine" else SaveManager.settings.music_volume)
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))), volume * 0.35), "スロー中はエンジン音とBGMも減衰する")
	check(AudioServer.is_bus_mute(master) == original_muted, "スローで消音設定を変えない")
	AudioManager.set_slow_motion(false)
	await get_tree().create_timer(0.3).timeout
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sfx)), sfx_volume), "スロー終了で通常効果音を戻す")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(dash_bus)), sfx_volume), "スロー終了でもダッシュ音量は変わらない")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(master)), original_volume), "スロー終了で全体音量を戻す")
	check(float(SaveManager.settings.master_volume) == original_volume, "音量設定を保存し直さない")
	var blaster := AudioManager._sounds.get(&"blaster") as AudioStreamWAV
	check(blaster != null and is_equal_approx(blaster.get_length(), 0.12), "連射用の短いブラスター音を読み込む")
	var hud := preload("res://scripts/ui/hud.gd").new()
	var levelup := AudioManager.sound(&"levelup_notice") as AudioStreamMP3
	check(levelup != null and not levelup.loop, "レベルアップ用MP3を一回再生の音として読み込む")
	var levelup_voice := AudioManager._next
	hud._on_events([{ "type": &"levelup" }])
	check(AudioManager._next == (levelup_voice + 1) % AudioManager.MAX_VOICES and AudioManager._players[levelup_voice].stream == levelup, "レベルアップ時に指定の素材を1回再生する")
	for id in [&"W01", &"W23"]:
		var before := AudioManager._next
		hud._on_events([{ "type": &"weapon_fire", "id": id }])
		check(AudioManager._next == (before + 1) % AudioManager.MAX_VOICES, "発射ごとに1回鳴らす: " + String(id))
		check(AudioManager._players[before].stream == blaster, "両ブラスターに同じ素材を使う: " + String(id))
	var before := AudioManager._next
	hud._on_events([{ "type": &"weapon_fire", "id": &"W02" }])
	check(AudioManager._next == before, "ほかの武器にブラスター音を追加しない")
	hud._on_events([{ "type": &"block_impact" }, { "type": &"bounce" }])
	check(AudioManager._next == (before + 1) % AudioManager.MAX_VOICES, "衝撃と跳ね返りの組で音を二重に鳴らさない")
	check(AudioManager._players[before].stream == AudioManager.sound(&"bounce"), "敵・鉄の瓦礫の衝撃に指定素材を使う")
	before = AudioManager._next
	hud._on_events([{ "type": &"block_impact" }])
	check(AudioManager._next == (before + 1) % AudioManager.MAX_VOICES, "低速で弾かれた衝撃でも1回鳴らす")
	before = AudioManager._next
	hud._on_events([{ "type": &"shield_block" }])
	check(AudioManager._players[before].stream == AudioManager.sound(&"block"), "盾の防御音は既存素材を保つ")
	before = AudioManager._next
	hud._on_events([{ "type": &"bolt", "segments": PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2.ONE, Vector2(2, 2)]) }])
	check(AudioManager._next == before, "接触電撃のSEを鳴らさない")
	var explosion := AudioManager.sound(&"bomber_explode") as AudioStreamWAV
	check(explosion != null and is_equal_approx(explosion.get_length(), 0.4), "自爆音を短い大砲音へ加工する")
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var sim := session.sim
	var enemies := sim.enemies
	var row := enemies.spawn(enemies.def_of(&"bomber"), Vector2(200, 0))
	enemies.table.mode[row] = EnemyTable.Mode.WINDUP
	enemies.table.timer[row] = 0.01
	sim.state.events.clear()
	enemies.behaviors[enemies.table.beh[row]].step(row, 0.02)
	var blasts: Array[Dictionary] = sim.state.events.filter(func(event): return event.type == &"bomber_explode")
	check(blasts.size() == 1 and enemies.table.dead[row] != 0, "カウントダウン完了時にだけ自爆音を通知する")
	before = AudioManager._next
	hud._on_events(blasts)
	check(AudioManager._next == (before + 1) % AudioManager.MAX_VOICES and AudioManager._players[before].stream == explosion, "自爆時に大砲音を1回再生する")
	row = enemies.spawn(enemies.def_of(&"bomber"), Vector2(300, 0))
	sim.state.events.clear()
	enemies.mark_dead(row)
	check(not sim.state.events.any(func(event): return event.type == &"bomber_explode"), "先に倒した自爆敵は爆発音を鳴らさない")
	session.free()
	hud.free()
	var map := preload("res://scripts/ui/constellation_map.gd").new()
	map.navigation_enabled = false
	before = AudioManager._next
	add_child(map)
	check(AudioManager._next == before, "ステージ選択の初期表示では選択音を鳴らさない")
	map._stars[1].pressed.emit()
	check(AudioManager._next == (before + 1) % AudioManager.MAX_VOICES, "別ステージのクリックで選択音を1回鳴らす")
	check(AudioManager._players[before].stream == AudioManager.sound(&"stage_select_click"), "ステージ選択に指定されたクリック音を使う")
	before = AudioManager._next
	map._stars[1].pressed.emit()
	check(AudioManager._next == before, "同じステージを再クリックしても選択音を重ねない")
	if map._final_stage != null:
		map._final_stage.pressed.emit()
		check(AudioManager._next == (before + 1) % AudioManager.MAX_VOICES, "最終ステージの選択でも同じ音を鳴らす")
	map.free()
	for player in AudioManager._players: player.stop()
	await get_tree().process_frame
	print("[baked_audio] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
