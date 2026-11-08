extends Node

var failed := 0
var passed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("[lab_responsiveness] "+label)

func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/enemy_lab.tscn").instantiate()
	add_child(lab)
	for n in 2400:
		if lab.session.run!=null: break
		await get_tree().process_frame
	if lab.session.run==null:
		check(false,"実験場を起動できる")
		lab.free()
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var session = lab.session
	session.set_physics_process(false)
	check(session.perform("spawn",{"type":"biter","pos":[300,0],"count":10}),"試遊の敵を配置する")
	lab.canvas.spawn_type = "biter"
	lab._hitstop_details.show()
	lab._refresh_hitstop()
	var authored: float = session.run.enemies.def_of(&"biter").hitstop_multiplier
	# 試遊の更新で未確定の数値入力を消さない。
	lab._refresh_hitstop()
	var field: LineEdit = lab._hitstop_value.get_line_edit()
	field.text = "0.7"
	for n in 10: lab._refresh_hitstop()
	check(field.text == "0.7", "同じ状態の更新でヒットストップの入力途中の文字を消さない")
	field.text = str(authored)
	var original_scene: RunSession = session.scene
	var builds: int = session.BUILDER.preparation_build_count
	await session.back_to_play_start()
	check(session.scene==original_scene and session.run.enemies.count()==10,"未再生のリセットでも配置を保ち再生成しない")
	session.playing = true
	session._physics_process(0.0)
	var start_digest: String = session.digest()
	var input_samples: Array[float] = []
	for batch in 6:
		var started := Time.get_ticks_usec()
		for n in 600:
			var index := batch*600+n
			session.perform("input",{"has_cursor":true,"cursor":[float(index),100.0],"pen":[float(index),100.0]})
			session.step()
		input_samples.append(float(Time.get_ticks_usec()-started)/600.0)
	print("[lab_responsiveness] input_step_usec=",input_samples)
	check(session.tick==3600 and session.last_error.ok,"長い入力履歴でも試遊が進む")
	var edited := Time.get_ticks_usec()
	lab._hitstop_value.value = 0.0
	check(session.last_error.ok and session.run.enemies.def_of(&"biter").hitstop_multiplier==0.0,"画面で停止なしへ変更する")
	check(session.perform("spawn",{"type":"biter","pos":[900,600]}),"停止なしの設定後に敵を配置する")
	var victim: int = session._selected_id
	check(session.bridge.command("dev_damage",{"entity_id":victim,"amount":100000.0,"cause":"ram","crit":true}).ok,"変更した定義で命中を処理する")
	check(session.bridge._core.combat_snapshot().hitstop==0.0,"倍率0は現在の戦闘でも停止しない")
	lab._hitstop_value.value = 0.5
	check(session.last_error.ok and session.run.enemies.def_of(&"biter").hitstop_multiplier==0.5,"画面で小数倍率へ変更する")
	check(session.perform("spawn",{"type":"biter","pos":[900,600]}),"小数倍率の設定後に敵を配置する")
	victim = session._selected_id
	check(session.bridge.command("dev_damage",{"entity_id":victim,"amount":100000.0,"cause":"ram","crit":true}).ok,"次に出現した敵への命中を処理する")
	check(session.bridge._core.combat_snapshot().hitstop>0.0,"小数倍率をC++の停止時間へ反映する")
	print("[lab_responsiveness] two_hitstop_edits_ms=",float(Time.get_ticks_usec()-edited)/1000.0)
	check(session.BUILDER.preparation_build_count==builds and session.scene==original_scene,"倍率変更で固定の表や表示Sessionを再生成しない")
	var reset := Time.get_ticks_usec()
	await session.back_to_play_start()
	print("[lab_responsiveness] reset_ms=",float(Time.get_ticks_usec()-reset)/1000.0)
	check(session.scene==original_scene and session.tick==0 and not session.seeking,"リセットは同じSessionですぐ完了する")
	check(session.run.enemies.count()==10 and session.digest()==start_digest,"配置・時計・倍率・入力を再生開始状態に戻す")
	check(session.run.enemies.def_of(&"biter").hitstop_multiplier==authored,"リセットで未保存の倍率を戻す")
	check(not session.branches.is_empty() and session.history.size()==1,"試遊履歴を分岐へ残し配置だけを維持する")
	for button: Button in lab.workspace._transport_panel.find_children("*","Button",true,false):
		if button.text==tr("lab.ui.reset"):
			button.pressed.emit()
			break
	check(session.scene==original_scene and session.run.enemies.count()==10,"リセットボタンでもSessionや配置を壊さない")
	# 復帰後の新しい試遊も保持点を更新し、途中の停止・再開を扱う。
	session.playing = true
	session._physics_process(0.0)
	for n in 12: session.step()
	session.playing = false
	session._physics_process(0.0)
	session.playing = true
	session._physics_process(0.0)
	var resumed_tick: int = session.tick
	var resumed_digest: String = session.digest()
	for n in 12: session.step()
	await session.back_to_play_start()
	check(session.tick==resumed_tick and session.digest()==resumed_digest,"一時停止からの再開位置へ戻す")
	# 旧ContentBundleを保持した通常のseekからも、次の倍率編集を正しく作る。
	check(session.perform("parameter",{"type":"biter","key":"hitstop_multiplier","value":0.25}),"復帰後も倍率を編集できる")
	await session.seek(0)
	check(session.perform("parameter",{"type":"biter","key":"hitstop_multiplier","value":0.75}),"別の保持点へseekした後も倍率を編集できる")
	check(session.run.enemies.def_of(&"biter").hitstop_multiplier==0.75,"seek先の定義を編集する")
	# 星の異なる敵と、現在・次回出現の個体に同じ試遊値を渡す。
	var ranks := {}
	for id in session._definitions:
		var definition: EnemyDef = session._definitions[id]
		if definition.rank<1 or ranks.has(definition.rank): continue
		ranks[definition.rank] = true
		check(session.perform("parameter",{"type":String(id),"key":"hitstop_multiplier","value":0.25}),"星%dの敵の倍率を変更する" % definition.rank)
		check(session.perform("spawn",{"type":String(id),"pos":[800,800]}),"倍率変更後の敵を配置する")
	check(ranks.size()>=5,"異なる星数の敵で試す")
	check(session.perform("boss_parameter",{"type":"monoceros","key":"hitstop_multiplier","value":0.25}),"ボスの倍率も共通の検証境界で変更する")
	check(ContentManager.enemies[&"biter"].hitstop_multiplier==authored,"試遊で本番定義を変更しない")
	session.perform("clear")
	session.perform("spawn",{"type":"biter","pos":[300,0],"count":10})
	if DisplayServer.get_name()!="headless":
		# 実際の物理更新と入力の記録で試遊を継続し、画面の応答を計測する。
		lab.canvas.mode = 3
		session.set_physics_process(true)
		session.playing = true
		var wall_start := Time.get_ticks_msec()
		var tick_start: int = session.tick
		var frames := 0
		while Time.get_ticks_msec()-wall_start<6000:
			await get_tree().process_frame
			frames += 1
		print("[lab_responsiveness] rendered_fps=",1000.0*frames/(Time.get_ticks_msec()-wall_start)," ticks=",session.tick-tick_start)
		session.playing = false
		check(session.tick>tick_start and session.last_error.ok,"描画付きの実際の試遊を継続できる")
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--capture="):
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture="))
	lab.free()
	await get_tree().process_frame
	print("[lab_responsiveness] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
