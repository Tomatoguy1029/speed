## 1つのBossSystemが複数の役者を管理し、1体の削除を他へ波及させない。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if "--cpp-centaurus-combo-shower-tail" in OS.get_cmdline_user_args() and message not in ["強弓の予告が終わるとコズミックの矢を放つ","後半の強弓の姿勢と矢を正式表示へ渡す","強弓の硬直で連携を自然終了し、放った矢は残す","降り矢・強弓の戦闘とcueを同じ通知経路へ送る","前半の取消・参加者消失で降り矢を消して強弓を始めない"]: return
	if "--cpp-centaurus-sail-boundary" in OS.get_cmdline_user_args() and not message.begins_with("弧の中心") and not message.begins_with("弧の終端") and not message.begins_with("硬直が終わっても") and not message.begins_with("次の帆走") and not message.begins_with("取消で護衛"): return
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	if "--cpp-draco-body" in OS.get_cmdline_user_args():
		call_deferred("native_draco_body")
		return
	if "--cpp-hydra-regrow-display" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_regrow_display")
		return
	if "--cpp-hydra-regrow" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_regrow")
		return
	if "--cpp-hydra-body" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_body")
		return
	if "--cpp-centaurus-finish" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_finish")
		return
	if "--cpp-centaurus-combo-shower" in OS.get_cmdline_user_args() or "--cpp-centaurus-combo-shower-tail" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_combo_shower")
		return
	if "--cpp-centaurus-combo-rain" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_combo_rain")
		return
	if "--cpp-centaurus-sail" in OS.get_cmdline_user_args() or "--cpp-centaurus-sail-boundary" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_sail")
		return
	if "--cpp-canis-bay" in OS.get_cmdline_user_args():
		await native_canis_bay()
		return
	if "--cpp-canis-sirius" in OS.get_cmdline_user_args():
		await native_canis_sirius()
		return
	if "--cpp-canis-pounce-cue" in OS.get_cmdline_user_args() or "--cpp-canis-pounce-cue-display" in OS.get_cmdline_user_args():
		call_deferred("native_canis_pounce_cue")
		return
	if "--cpp-canis-pounce-solo" in OS.get_cmdline_user_args():
		call_deferred("native_canis_pounce_solo")
		return
	if "--cpp-canis-pounce" in OS.get_cmdline_user_args():
		call_deferred("native_canis_pounce")
		return
	if "--cpp-canis-howl" in OS.get_cmdline_user_args():
		call_deferred("native_canis_howl")
		return
	if "--cpp-canis-command-next" in OS.get_cmdline_user_args():
		call_deferred("native_canis_command_next")
		return
	if "--cpp-canis-command" in OS.get_cmdline_user_args() or "--cpp-canis-command-runtime" in OS.get_cmdline_user_args():
		call_deferred("native_canis_command")
		return
	if "--cpp-centaurus-shower" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_shower")
		return
	if "--cpp-centaurus-fan-aim" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_fan_aim")
		return
	if "--cpp-centaurus-fan" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_fan")
		return
	if "--cpp-canis-lunge" in OS.get_cmdline_user_args() or "--cpp-canis-lunge-tail" in OS.get_cmdline_user_args():
		call_deferred("native_canis_lunge")
		return
	if "--cpp-centaurus-stomp" in OS.get_cmdline_user_args() or "--cpp-centaurus-stomp-runtime" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_stomp")
		return
	if "--cpp-canis-flame" in OS.get_cmdline_user_args() or "--cpp-canis-flame-tail" in OS.get_cmdline_user_args():
		call_deferred("native_canis_flame")
		return
	if "--cpp-centaurus-power-cancel" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_power_cancel")
		return
	if "--cpp-centaurus-power" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_power")
		return
	if "--cpp-canis-body" in OS.get_cmdline_user_args():
		call_deferred("native_canis_body")
		return
	if "--cpp-centaurus-rain" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_rain")
		return
	if "--cpp-centaurus-rear" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_rear")
		return
	if "--cpp-centaurus-volley-owner" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_volley_owner")
		return
	if "--cpp-centaurus-volley-retry" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_volley_retry")
		return
	if "--cpp-centaurus-volley" in OS.get_cmdline_user_args() or "--cpp-centaurus-volley-tail" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_volley")
		return
	if "--cpp-centaurus-body-view" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_body_view")
		return
	if "--cpp-centaurus-body" in OS.get_cmdline_user_args():
		call_deferred("native_centaurus_body")
		return
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var bosses = session.sim.bosses
	var one = bosses.spawn_lab(&"monoceros", Vector2(3000, 0))
	var two = bosses.spawn_lab(&"monoceros", Vector2(-3000, 0))
	check(bosses.get("actors") != null, "ボス管理は役者の一覧を持つ")
	if bosses.get("actors") != null:
		check(bosses.actors.size() == 2, "同じSystemに2体を登録する")
		var a = bosses.actor_for_row(one)
		var b = bosses.actor_for_row(two)
		check(a.ctx == session.sim.ctx and b.ctx == session.sim.ctx, "両方の役者が同じランのContextを使う")
		bosses.remove_actor(a)
		check(not a.has_body() and b.has_body(), "1体を取り除いても他の本体を保持する")
		check(bosses.actor_for_row(one) == null and bosses.actor_for_row(two) == b, "行とIDで正しい役者を返す")
	session.free()
	await get_tree().process_frame
	print("[boss_registry] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

## ケンタウルス本体の既存ボス登録検査をC++の状態・表示へつなぐ。
func native_centaurus_body() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/centaurus.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	check(not package.is_empty(),"本体と守る雑魚の固定定義を生成する")
	if package.is_empty(): get_tree().quit(1); return
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	if bytes.is_empty():
		for record in builder.Schema.SCHEMA.records:
			for row in package.records[record.name]:
				if not builder.Schema._valid_record(row,record): print("生成入力の不一致: ",record.name," ",row)
	check(not bytes.is_empty(),"全項目と参照を持つ本体の生成形式を書き出す")
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":149,"mode":1,"stage_id":"B_centaurus_body","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"型付き本体・守る雑魚・正式表示資源を読む")
	if not configured.ok: print(configured); get_tree().quit(1); return
	bridge.start(149,{"position":Vector2(1600,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge.command("dev_ship_motion",{"position":Vector2(1600,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1600,0),Vector2(1600,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.kind==1 and body.participants.size()==1 and body.participants[0].id==id and body.participants[0].health_target==id,"独立した守る雑魚を本体の部位やHP共有へ加えない")
	check(body.guards.size()==definition.params.guard_count,"登場時に指定数の守る雑魚を生成する")
	for guard: Dictionary in body.guards:
		check(guard.id!=id and guard.scale>=definition.params.sail_guard_min and guard.scale<=definition.params.sail_guard_max and guard.phase>=0.0 and guard.phase<TAU,"守る雑魚のIDと帆走用の乱数を保持する")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	var render: Dictionary = bridge.read_render(Rect2(-3000,-2000,6000,4000)).value
	check(view.apply_frame(render) and view._boss_body_displays.size()==1,"最初の技前に共通表示入口から正式な本体を作る")
	var display = view._boss_body_displays.values()[0]
	check(display._parts!=null and display._parts.visible and display._parts._clip=="idle","準備済みのパーツと待機姿勢を使う")
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.has_guard_point and body.velocity.length()>0.0 and is_equal_approx(body.velocity.length(),definition.speed),"守る雑魚の平均位置を見て通常速度で好む距離へ動く")
	var prior_velocity: Vector2 = body.velocity
	for cause in ["ram","touch","wave"]:
		check(bridge.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":cause,"direction":Vector2.RIGHT,"knock":1500.0}).ok,"被弾を登録済みの原因で本体へ渡す")
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity==prior_velocity and is_equal_approx(body.hp,body.max_hp-3.0),"本体は全方向から被弾し外力のノックバックで動かない")
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(display.hit>0.0,"表示用の被弾値を本体へ渡す")
	var packet: Dictionary = bridge.read_frame().value
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.apply_snapshot(packet.ui)
	check(hud._cpp_ui.boss_bodies[0].actor==id and is_equal_approx(hud._cpp_ui.boss_bodies[0].hp,body.hp),"HP表示へ本体IDと現在HPを渡す")
	hud.free()
	var guard_id: int = body.guards[0].id
	bridge.command("dev_kill",{"entity_id":guard_id,"cause":"debug"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(body.hp,body.max_hp-3.0) and not body.boss_dead and body.participants[0].active,"守る雑魚の死亡は本体HPとボスの寿命を変えない")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"本体と守る雑魚の途中状態を保持する")
	bridge._core.step(0.6)
	var after: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(after.guards.size()==body.guards.size()+1,"待機中の補充時計で守る雑魚を1体追加する")
	check(bridge.restore(held.value).ok,"本体・護衛ID・乱数・補充時計を復帰する")
	bridge._core.step(0.6)
	check(bridge.command("dev_boss_body_state").value[0]==after,"復帰後も本体の移動と守る雑魚の生成を同じ結果へ戻す")
	bridge.release_checkpoint(held.value)
	bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp*0.55,"cause":"bullet"})
	bridge._core.step(0.01)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.phase==2 and body.mode==2,"非致死の被弾から第2形態へ移る")
	bridge._core.step(0.5)
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(display.sail_fraction()>0.0 and display.sail_fraction()<1.0,"形態の進行だけを読んで帆を広げる")
	var position_before: Vector2 = body.position
	display.apply_frame(body)
	check(bridge.command("dev_boss_body_state").value[0].position==position_before,"表示更新は本体の戦闘状態を書き戻さない")
	bridge.command("dev_cancel_boss",{"entity_id":id})
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok,"中断後も公開APIの固定更新を終える")
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(not body.participants[0].active and not display.visible and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"中断で本体の寿命と表示を閉じ通知の配信を終える")
	var entering: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(500,500),"entrance":true}).value
	var entrance: Dictionary = bridge.command("dev_boss_body_state").value[1]
	check(entrance.mode==0 and entrance.position.x<500.0 and entrance.guards.size()==definition.params.guard_count,"守る雑魚を配置したあと画面外から登場する")
	bridge._core.step(1.4)
	entrance = bridge.command("dev_boss_body_state").value[1]
	check(entrance.mode==1 and entrance.position.is_equal_approx(Vector2(500,500)),"登場時間の終わりに通常待機へ戻る")
	bridge.command("dev_damage",{"entity_id":entering,"amount":entrance.max_hp+1.0,"cause":"bullet"})
	entrance = bridge.command("dev_boss_body_state").value[1]
	check(entrance.mode==4 and not entrance.participants[0].active and entrance.boss_dead,"第1形態の致死ダメージでも本体だけを撃破する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"登場と撃破の通知を最後まで配信する")
	bridge.dispose()
	view.queue_free()
	await get_tree().process_frame
	print("[cpp_centaurus_body] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 未確認だった守る雑魚の正式外観だけを確認する。
func native_centaurus_body_view() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var package: Dictionary = builder.boss_body_package(load("res://data/bosses/centaurus.tres"),cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":149,"mode":1,"stage_id":"B_centaurus_body","profile":{},"settings":{"hitstop":false}})
	bridge.start(149,{"position":Vector2(1600,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge._core.set_motion_context(Vector2(1600,0),Vector2(1600,0),Vector2(640,360))
	bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false})
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value),"本体と守る雑魚の表示出力を受け取る")
	check(view.enemy_frames.size()==1 and view.enemy_frames.values()[0]._parts.size()>0,"守る雑魚の生成済み塗装と照明で正式な本体・装甲を作る")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"表示確認の通知を配信する")
	bridge.dispose()
	view.queue_free()
	await get_tree().process_frame
	print("[cpp_centaurus_body_view] failures=",failed)
	get_tree().quit(1 if failed else 0)

func centaurus_volley_case(flow_enabled := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.guard_count = 0
	definition.params.guard_min = 0
	definition.speed = 0.0
	var move = load("res://data/bosses/centaurus_moves/volley.tres").duplicate(true)
	move.warn = 0.1
	move.count = 3
	move.count_p2 = 4
	move.interval = 0.05
	move.recover = 0.05
	move.cd = 0.0
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg)
	if flow_enabled:
		var rules = load("res://data/bosses/ai/centaurus_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {"volley":{"min":0.0,"max":500.0}}
		rules.costs = {"volley":1.0}
		rules.selection_bias = {}
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.maximum_stamina = 10.0
		flow.sections = [{"request":"any","weights":{"single":1.0,"major":1.0},"cap":1.0,"action_count":1,"next":0}]
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in records: package.records[key] = records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":159,"mode":1,"stage_id":"B_centaurus_volley","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(159,{"position":Vector2(300,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	return {"bridge":bridge,"id":id,"package":package,"events":events}

## 速射の開始・発射間隔・命中・自然終了と中断を既存ボス検査から確認する。
func native_centaurus_volley() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var definition = load("res://data/bosses/centaurus.tres")
	var move = load("res://data/bosses/centaurus_moves/volley.tres")
	var records: Dictionary = builder.boss_technique_records(definition,move)
	if "--cpp-centaurus-volley-tail" not in OS.get_cmdline_user_args():
		check(records.CentaurusVolleyDefinition[0].count==5 and records.CentaurusVolleyDefinition[1].count==8 and records.BossTechniqueDefinition[0].warn==move.warn,"制作Resourceの全値と形態ごとの弾数を生成する")
		check(records.BossTechniqueStage.size()==15 and records.BossTechniqueStage[0].at==move.warn and is_equal_approx(records.BossTechniqueStage[5].at,move.warn+move.interval*4.0+0.05),"発射と終了のキー時刻を実効値から生成する")
		var timeline: AnimationLibrary = load("res://scenes/bosses/centaurus_boss_timeline.tres")
		check(timeline.get_animation(&"attack").track_get_key_count(0)==0,"保存済みの戦闘methodキーを残さない")
	var c := centaurus_volley_case(true)
	if "--cpp-centaurus-volley-tail" not in OS.get_cmdline_user_args(): check(not c.is_empty(),"技・矢の固有外観・フローと本体を同じ生成形式で読む")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(900,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(900,0),Vector2(900,0),Vector2(640,360))
	bridge._core.step(0.001)
	var attacks: Array = bridge.command("dev_boss_state").value
	if "--cpp-centaurus-volley-tail" not in OS.get_cmdline_user_args(): check(attacks.size()==1 and attacks[0].stage==0,"速射は遅延照準の距離条件から共通フローで選ぶ")
	if attacks.is_empty(): bridge.dispose(); get_tree().quit(1); return
	var first: Dictionary = attacks[0]
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	if "--cpp-centaurus-volley-tail" not in OS.get_cmdline_user_args(): check(bridge._core.hostiles_snapshot().is_empty(),"予告の開始時は矢を撃たない")
	bridge._core.step(0.1)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and t.released==1 and bridge._core.hostiles_snapshot().size()==1,"予告時刻に最初の矢を1本だけ撃つ")
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var shot: Dictionary = bridge._core.hostiles_snapshot()[0]
	check(shot.pos.is_equal_approx(body.position+Vector2.from_angle(body.facing)*body.radius*definition.params.bow_reach) and is_equal_approx(shot.life,move.travel/move.speed),"弓口から射程÷速さの寿命で長さ0の矢を出す")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	var render: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	check(view.apply_frame(render) and view._boss_body_displays.values()[0]._parts._clip=="shot_release" and render.shapes.any(func(shape): return shape.kind==builder.Schema.ENUMS.RenderShapeKind.LightArrow and shape.length==0.0),"発射段階から弓の解放姿勢と矢じりを正式表示する")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.05)
	bridge._core.step(0.05)
	t = bridge.command("dev_boss_state").value[0]
	check(t.released==3 and bridge._core.hostiles_snapshot().size()==3,"指定間隔ごとに残りの矢を撃つ")
	var after: Dictionary = t.duplicate(true)
	check(bridge.restore(held.value).ok,"速射の途中状態・次の発射キーと飛行中の矢を復帰する")
	bridge._core.step(0.05)
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0]==after,"復帰後の残りの速射が同じ時刻と状態へ進む")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==2 and bridge._core.hostiles_snapshot().size()==3,"最後の発射から0.05秒後に硬直へ移り矢を残す")
	bridge._core.step(0.05)
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.15)
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value[0].id>first.id,"硬直が終わるとフローから次の行動へ進む")
	bridge.command("dev_cancel_flow",{"entity_id":c.id})
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hostiles(0.5)
	check(bridge._core.ship_snapshot().ship_hp<hp,"矢じりの飛行区間が機体へ命中し実ダメージを与える")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"速射の出来事と命中を公開更新・配信・記録の入口へ渡す")
	check(c.events.any(func(event): return event.type=="centaurus_cue" and event.payload.cue=="released"),"役者内の発射cueを専用の通知種別で記録する")
	bridge.dispose()
	view.queue_free()
	c = centaurus_volley_case()
	bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.1)
	check(bridge.command("dev_cancel_technique",{"ticket":ticket}).ok and bridge._core.hostiles_snapshot().size()==1,"速射の取消で発射済みの矢を消さない")
	bridge.command("dev_remove",{"entity_id":c.id})
	check(bridge._core.hostiles_snapshot().size()==1,"発射元が消えても矢を寿命まで残す")
	bridge._core.step_hostiles(2.0)
	check(bridge._core.hostiles_snapshot().is_empty(),"残った矢は射程の寿命で消える")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"取消と参加者消失の通知を配信する")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_volley] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 速射で未成立だった表示と次行動だけを確認する。
func native_centaurus_volley_retry() -> void:
	var c := centaurus_volley_case()
	var bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.1)
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	var render: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	var accepted: bool = view.apply_frame(render)
	var clip: String = view._boss_body_displays.values()[0]._parts._clip
	var arrows: Array = render.shapes.filter(func(shape): return shape.kind==load("res://tools/content/generated/run_schema.gd").ENUMS.RenderShapeKind.LightArrow and shape.length==0.0)
	if not accepted or clip!="shot_release" or arrows.is_empty(): print("表示の未成立: ",accepted," ",clip," ",render.shapes)
	check(accepted and clip=="shot_release" and not arrows.is_empty(),"発射段階から弓の解放姿勢と長さ0の矢じりを正式表示する")
	bridge.dispose()
	view.queue_free()
	c = centaurus_volley_case(true)
	bridge = c.bridge
	bridge._core.step(0.001)
	var first: int = bridge.command("dev_boss_state").value[0].id
	bridge._core.step(0.25)
	bridge._core.step(0.05)
	bridge._core.step(0.15)
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value[0].id>first,"硬直とフローの区切りを終えて次の速射へ進む")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"未成立条件の公開更新と通知配信を終える")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_volley_retry] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 取消前に発射元が消えた場合の停止だけを確認する。
func native_centaurus_volley_owner() -> void:
	var c := centaurus_volley_case()
	var bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.1)
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge._core.hostiles_snapshot().size()==1,"発射元の消失で残りの速射を止め、発射済みの矢は残す")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"発射元消失の通知を配信する")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_volley_owner] failures=",failed)
	get_tree().quit(1 if failed else 0)

func centaurus_rear_case(flow_enabled := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.guard_count = 0
	definition.params.guard_min = 0
	definition.speed = 0.0
	var move = load("res://data/bosses/centaurus_moves/rear_attack.tres").duplicate(true)
	move.warn = 0.1
	move.active = 0.1
	move.recover = 0.05
	move.cd = 0.0
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg)
	if flow_enabled:
		var rules = load("res://data/bosses/ai/centaurus_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {"rear_attack":{"min":0.0,"max":500.0}}
		rules.costs = {"rear_attack":1.0}
		rules.selection_bias = {}
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.maximum_stamina = 10.0
		flow.sections = [{"request":"any","weights":{"single":1.0,"major":1.0},"cap":1.0,"action_count":1,"next":0}]
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in records: package.records[key] = records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":158,"mode":1,"stage_id":"B_centaurus_rear_attack","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(158,{"position":Vector2(300,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(900,0),Vector2(900,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_ship_motion",{"position":Vector2(-110,0),"velocity":Vector2.ZERO})
	return {"bridge":bridge,"id":id,"package":package,"events":events}

## 背後攻撃の制作値・時刻・掃引・復帰・中断を既存のボス検査で確認する。
func native_centaurus_rear() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/centaurus_moves/rear_attack.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
	check(records.CentaurusRearDefinition.size()==2 and records.CentaurusRearDefinition[0].radius==move.range_radius and records.CentaurusRearDefinition[0].back_offset==move.back_offset,"制作Resourceの半径と背後距離を形態ごとに生成する")
	check(records.BossTechniqueStage[0].at==move.warn and is_equal_approx(records.BossTechniqueStage[1].at,move.warn+move.active+0.05),"開始と終了をRunnerと同じ実効時刻で生成する")
	check(not move.has_method("make_runner") or move.make_runner()==null,"編集Resourceへ戦闘Runnerを残さない")
	var c := centaurus_rear_case(true)
	check(not c.is_empty(),"本体・背後攻撃・フローを同じ生成形式で読む")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.step(0.001)
	var attacks: Array = bridge.command("dev_boss_state").value
	check(not attacks.is_empty() and attacks[0].kind==9 and attacks[0].stage==0,"背後攻撃は遅延照準でなく機体位置の条件から選ぶ")
	if attacks.is_empty(): bridge.dispose(); get_tree().quit(1); return
	var first: int = attacks[0].id
	var facing: float = bridge.command("dev_boss_body_state").value[0].facing
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.1)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and not t.hit and bridge._core.ship_snapshot().ship_hp==hp and bridge.command("dev_boss_body_state").value[0].facing==facing,"予告中は旋回せず開始キーの次の更新まで判定しない")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	var render: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	check(view.apply_frame(render) and view._boss_body_displays.values()[0]._mode()==&"strike" and t.back_offset==move.back_offset and t.range_radius==move.range_radius,"攻撃段階と赤い点滅の表示入力を読み取り専用で渡す")
	var held: Dictionary = bridge.checkpoint()
	bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	var hp_after: float = bridge._core.ship_snapshot().ship_hp
	check(t.hit and is_equal_approx(hp-hp_after,move.damage*load("res://data/config.tres").atk_scale),"背後円と機体の移動線分の交差で倍率を1回掛けて命中する")
	check(bridge.restore(held.value).ok,"命中前の段階・機体の前位置を復帰する")
	bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.ship_snapshot().ship_hp==hp_after,"復帰後も同じ掃引と1回命中の状態へ進む")
	bridge.release_checkpoint(held.value)
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge.command("dev_ship_motion",{"position":Vector2(-110,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.14)
	check(bridge.command("dev_boss_state").value[0].stage==2 and bridge._core.ship_snapshot().ship_hp==hp_after,"接触を続けても再命中せず終了キーで硬直へ移る")
	bridge._core.step(0.05)
	bridge._core.step(0.15)
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value[0].id>first,"硬直の後は共通フローの次の行動へ進む")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"命中と技の通知を公開更新・配信へ渡す")
	bridge.dispose()
	view.queue_free()
	c = centaurus_rear_case()
	bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.1)
	hp = bridge._core.ship_snapshot().ship_hp
	check(bridge.command("dev_cancel_technique",{"ticket":ticket}).ok,"判定開始直後に技を取消できる")
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge._core.ship_snapshot().ship_hp==hp,"取消後に背後攻撃を残さない")
	bridge.dispose()
	c = centaurus_rear_case()
	bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].stage==7,"参加者の消失で予告中の技を止める")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"参加者消失の通知を配信する")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_rear] failures=",failed)
	get_tree().quit(1 if failed else 0)

func centaurus_rain_case(flow_enabled := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.guard_count = 0
	definition.params.guard_min = 0
	definition.speed = 0.0
	var move = load("res://data/bosses/centaurus_moves/rain.tres").duplicate(true)
	move.warn = 0.1
	move.traces = 2
	move.traces_p2 = 3
	move.trace_length = 200.0
	move.trace_speed = 1000.0
	move.trace_gap = 0.05
	move.trace_bend = 1.2
	move.forward = 100.0
	move.circle_radius = 20.0
	move.arrow_gap = 50.0
	move.drop_delay = 0.05
	move.fall = 0.05
	move.linger = 0.05
	move.recover = 0.05
	move.cd = 0.0
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg)
	if flow_enabled:
		var rules = load("res://data/bosses/ai/centaurus_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {"rain":{"min":0.0,"max":500.0}}
		rules.costs = {"rain":1.0}
		rules.selection_bias = {}
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.maximum_stamina = 10.0
		flow.sections = [{"request":"any","weights":{"single":1.0,"major":1.0},"cap":1.0,"action_count":1,"next":0}]
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in records: package.records[key] = records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":158,"mode":1,"stage_id":"B_centaurus_rain","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(158,{"position":Vector2(300,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	return {"bridge":bridge,"id":id,"package":package,"events":events}


## 矢の雨の段階・弧・トレース単位の命中と中断を確認する。
func native_centaurus_rain() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/centaurus_moves/rain.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
	check(records.CentaurusRainDefinition[0].traces==4 and records.CentaurusRainDefinition[1].traces==6 and records.CentaurusRainDefinition[1].arrows_per_step==2 and records.CentaurusRainDefinition[1].arrow_gap==22.0,"制作値と第2形態の本数・散布数・間隔を生成する")
	check(records.BossTechniqueStage.size()==2 and records.BossTechniqueStage[0].at==move.warn and records.BossTechniqueStage[0].command==6,"予告終了時刻だけを生成し着弾終了を技が判断する")
	check(move.make_runner()==null,"雨の編集Resourceから戦闘Runnerを分離する")
	var c := centaurus_rain_case(true)
	check(not c.is_empty(),"雨・固有外観・本体・フローを同じ生成形式で読む")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.step(0.001)
	var attacks: Array = bridge.command("dev_boss_state").value
	check(not attacks.is_empty() and attacks[0].kind==10 and attacks[0].stage==0,"遅延照準の距離条件から矢の雨を選ぶ")
	if attacks.is_empty(): bridge.dispose(); get_tree().quit(1); return
	var first: int = attacks[0].id
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.1)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and t.rain.traces.is_empty() and t.rain.left==2,"warnの開始命令ではまだトレースを作らない")
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	check(t.rain.traces.size()==1 and t.rain.traces[0].landed==0.0 and t.rain.traces[0].next_drop==50.0,"次の更新で弧の始点を作り距離0の矢を散布する")
	var trace: Dictionary = t.rain.traces[0]
	check(trace.start.is_equal_approx(Vector2(400,0)) and trace.turn==1,"停止中の機体からボスと逆向きの前方へ開始し最初は正の曲がりを使う")
	bridge._core.step(0.08)
	check(bridge._core.ship_snapshot().ship_hp==hp,"drop_delayとfallの間は着弾判定を出さない")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.12)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	var hp_after: float = bridge._core.ship_snapshot().ship_hp
	check(t.rain.traces[0].hit and hp_after<hp,"着弾の弧上の前回点と今回点を結ぶ弦が機体へ1回当たる")
	check(bridge.restore(held.value).ok,"弧・散布の次距離・着弾距離・次トレース時刻を復帰する")
	bridge._core.step(0.12)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.ship_snapshot().ship_hp==hp_after,"復帰後も同じ弦の命中と着弾状態へ進む")
	bridge.release_checkpoint(held.value)
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	var render: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	var accepted: bool = view.apply_frame(render)
	check(accepted and view._boss_body_displays.values()[0]._mode()==&"rain" and view._boss_body_displays.values()[0]._rain_visual.state.traces==t.rain.traces,"弧と着弾の値から正式な光の粉と落下矢を表示する")
	await get_tree().process_frame
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.051)
	t = bridge.command("dev_boss_state").value[0]
	check(t.rain.traces.size()==2 and t.rain.traces[1].turn==-1 and bridge._core.ship_snapshot().ship_hp==hp_after,"duration+trace_gapごとに逆向きの弧を作り同じトレースは再命中しない")
	bridge._core.step(0.51)
	check(bridge.command("dev_boss_state").value[0].stage==2 and bridge.command("dev_boss_state").value[0].rain.traces.is_empty(),"全着弾と最後の落下矢の表示期限の後だけ硬直へ移る")
	bridge._core.step(0.05)
	bridge._core.step(0.15)
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value[0].id>first,"雨の自然終了後は次の行動を選ぶ")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"雨の開始・トレース・命中を公開更新と通知配信へ渡す")
	bridge.dispose()
	view.queue_free()
	c = centaurus_rain_case()
	bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.1)
	bridge._core.step(0.01)
	hp = bridge._core.ship_snapshot().ship_hp
	check(bridge.command("dev_cancel_technique",{"ticket":ticket}).ok,"散布中の雨を取消できる")
	bridge._core.step(0.5)
	check(bridge.command("dev_boss_state").value[0].rain.traces.is_empty() and bridge._core.ship_snapshot().ship_hp==hp,"取消でトレース・落下表示・未発生の着弾を消す")
	bridge.dispose()
	c = centaurus_rain_case()
	bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.1)
	bridge._core.step(0.01)
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.5)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_state").value[0].rain.traces.is_empty(),"参加者消失でも散布と着弾を止める")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"参加者消失の出来事を配信する")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_rain] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_canis_body() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/canis_major.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	check(not package.is_empty(),"本体と猟犬を同じ固定入力から生成する")
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	if bytes.is_empty():
		for record in builder.Schema.SCHEMA.records:
			for row in package.records[record.name]:
				if not builder.Schema._valid_record(row,record): print("生成入力の不一致: ",record.name," ",row)
	check(not bytes.is_empty(),"大犬座の全項目と参照を型付き形式へ書く")
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":144,"mode":1,"stage_id":"B_canis_major_body","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"型付き本体・猟犬・表示資源を読む")
	if not configured.ok: print(configured); get_tree().quit(1); return
	bridge.start(144,{"position":Vector2(1600,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge.command("dev_ship_motion",{"position":Vector2(1600,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1600,0),Vector2(1600,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.kind==2 and body.participants.size()==1 and body.participants[0].id==id and body.participants[0].health_target==id,"猟犬は本体の部位やHP共有に加えない")
	check(body.led.size()==definition.params.pack_size,"本体とは別の個体IDで指定数の猟犬を率いる")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value) and view._boss_body_displays.size()==1,"正式なパーツを表示入口へ接続する")
	var display = view._boss_body_displays.values()[0]
	check(display.parts.visible,"最初の技の前から本体とシリウスを表示する")
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(body.velocity.length(),definition.speed),"機体を向いて通常速度で追う")
	var velocity: Vector2 = body.velocity
	for cause in ["ram","touch","wave"]:
		check(bridge.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":cause,"direction":Vector2.RIGHT,"knock":1500.0}).ok,"全方向からの被弾を受ける")
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity==velocity and is_equal_approx(body.hp,body.max_hp-3.0),"本体のHPを減らし外力のノックバックは受けない")
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(display.hit>0.0,"被弾の値を正式表示へ渡す")
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.apply_snapshot(bridge.read_frame().value.ui)
	check(hud._cpp_ui.boss_bodies[0].actor==id and is_equal_approx(hud._cpp_ui.boss_bodies[0].hp,body.hp),"本体IDと現在HPをHUDへ渡す")
	hud.free()
	bridge.command("dev_kill",{"entity_id":body.led[0].id,"cause":"debug"})
	check(not bridge.command("dev_boss_body_state").value[0].boss_dead,"猟犬の撃破でボスを撃破しない")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"本体と群れの途中状態を値として保持する")
	bridge._core.step(0.6)
	var after: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(bridge.restore(held.value).ok,"本体と群れのID・隊形時計を復帰する")
	bridge._core.step(0.6)
	check(bridge.command("dev_boss_body_state").value[0]==after,"復帰後の本体・群れが同じ状態になる")
	bridge.release_checkpoint(held.value)
	var position_before: Vector2 = after.position
	display.apply_frame(after)
	check(bridge.command("dev_boss_body_state").value[0].position==position_before,"表示から戦闘位置を書き戻さない")
	bridge.command("dev_cancel_boss",{"entity_id":id})
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(not body.participants[0].active and body.led.is_empty() and not display.visible,"中断で群れの指示を解き本体の寿命と表示を閉じる")
	var entering: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(500,500),"entrance":true}).value
	bridge._core.step(1.4)
	var entrance: Dictionary = bridge.command("dev_boss_body_state").value[1]
	check(entrance.barking and entrance.position.is_equal_approx(Vector2(500,500)),"画面外から登場して吠える時間へ移る")
	bridge._core.step(0.6)
	check(not bridge.command("dev_boss_body_state").value[1].barking,"吠え終わってから通常待機へ戻る")
	bridge.command("dev_damage",{"entity_id":entering,"amount":entrance.max_hp+1.0,"cause":"bullet"})
	entrance = bridge.command("dev_boss_body_state").value[1]
	check(entrance.mode==4 and not entrance.participants[0].active and entrance.boss_dead,"第1形態の致死ダメージもHP保護を入れず撃破する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"中断と撃破の通知を最後まで配信する")
	bridge.dispose()
	view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_body] failures=",failed)
	get_tree().quit(1 if failed else 0)

func centaurus_power_case(flow_enabled := false,tracking := true) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.guard_count = 0
	definition.params.guard_min = 0
	definition.speed = 0.0
	var move = load("res://data/bosses/centaurus_moves/power_shot.tres").duplicate(true)
	move.warn = 0.1
	move.alert = 0.04
	move.count = 3
	move.count_p2 = 5
	move.track_during_warn = tracking
	move.recover = 0.05
	move.cd = 0.0
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg)
	if flow_enabled:
		var rules = load("res://data/bosses/ai/centaurus_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {"power_shot":{"min":0.0,"max":500.0}}
		rules.costs = {"power_shot":1.0}
		rules.selection_bias = {}
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.maximum_stamina = 10.0
		flow.sections = [{"request":"any","weights":{"single":1.0,"major":1.0},"cap":1.0,"action_count":1,"next":0}]
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in records: package.records[key] = records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":158,"mode":1,"stage_id":"B_centaurus_power_shot","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(158,{"position":Vector2(300,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	return {"bridge":bridge,"id":id,"package":package,"events":events}


## 強弓の警告固定・同時発射・通常終了・中断を確認する。

func native_centaurus_power() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/centaurus_moves/power_shot.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
	check(records.CentaurusPowerDefinition[0].count==1 and records.CentaurusPowerDefinition[1].count==3 and records.LightArrowDefinition[0].cosmic and records.CentaurusPowerDefinition[0].spread==move.spread,"強弓の全値・形態別本数・コズミック外観を生成する")
	check(records.BossTechniqueStage.size()==6 and is_equal_approx(records.BossTechniqueStage[0].at,move.warn-move.alert) and records.BossTechniqueStage[1].at==move.warn and is_equal_approx(records.BossTechniqueStage[2].at,move.warn+0.05),"alert・release・end_attackを実効値から生成する")
	check(move.make_runner()==null,"強弓の編集ResourceからRunnerを分離する")
	var c := centaurus_power_case(true)
	check(not c.is_empty(),"強弓・固有矢・本体・フローを同じ生成形式で読む")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(900,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.001)
	var attacks: Array = bridge.command("dev_boss_state").value
	check(not attacks.is_empty() and attacks[0].kind==11 and attacks[0].stage==0,"強弓の選択条件は遅延照準の位置を使う")
	if attacks.is_empty(): bridge.dispose(); get_tree().quit(1); return
	var first: int = attacks[0].id
	bridge.command("dev_ship_motion",{"position":Vector2(300,300),"velocity":Vector2.ZERO})
	bridge._core.step(0.05)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(not t.alerting and is_equal_approx(t.facing,PI*0.25) and bridge._core.hostiles_snapshot().is_empty(),"予告中は機体の今の位置へ即座に向き発射を待つ")
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	var origin: Vector2 = t.locked_origin
	var angle: float = t.locked_angle
	check(t.alerting and is_equal_approx(angle,PI*0.25) and origin.is_equal_approx(Vector2.from_angle(angle)*t.radius*load("res://data/bosses/centaurus.tres").params.bow_reach),"warn-alertで弓口の起点と向きを固定する")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0].technique.alerting,"固定した警告射線と機体で切れる表示を正式表示へ渡す")
	await get_tree().process_frame
	var held: Dictionary = bridge.checkpoint()
	bridge.command("dev_ship_motion",{"position":Vector2(300,-300),"velocity":Vector2.ZERO})
	bridge._core.step(0.04)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	var shots: Array = bridge._core.hostiles_snapshot()
	check(t.stage==1 and t.released==3 and shots.size()==3 and is_equal_approx(t.facing,angle),"機体が移動してもwarn時刻に固定した向きへ3本を同時発射する")
	var positions_ok := shots.size()==3
	for k in shots.size(): positions_ok = positions_ok and shots[k].pos.is_equal_approx(origin) and is_equal_approx(shots[k].vel.angle(),angle+(k-1)*move.spread) and shots[k].kind==builder.Schema.ENUMS.HostileKind.CosmicArrow and is_equal_approx(shots[k].life,move.travel/move.speed)
	check(positions_ok,"固定起点・対称の扇角度・射程÷速さの寿命でコズミック矢を出す")
	check(bridge.restore(held.value).ok,"警告後の固定起点・向き・未発射状態を復帰する")
	bridge.command("dev_ship_motion",{"position":Vector2(300,-300),"velocity":Vector2.ZERO})
	bridge._core.step(0.04)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.hostiles_snapshot()==shots,"復帰後も同じ起点と角度から同じ矢を発射する")
	bridge.release_checkpoint(held.value)
	var render: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	check(view.apply_frame(render) and view._boss_body_displays.values()[0]._parts._clip=="shot_release" and render.shapes.filter(func(shape): return shape.kind==builder.Schema.ENUMS.RenderShapeKind.LightArrow and shape.cosmic).size()==3,"弓の解放姿勢と3本のコズミック矢を正式表示する")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==2 and not bridge.command("dev_boss_state").value[0].alerting,"発射から0.05秒後に警告を消して硬直へ移る")
	bridge._core.step(0.05)
	bridge._core.step(0.15)
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value[0].id>first,"硬直終了後に次の行動を選ぶ")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"警告と発射cueを公開更新・記録・配信へ渡す")
	bridge.dispose()
	view.queue_free()
	c = centaurus_power_case()
	bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.06)
	check(bridge.command("dev_cancel_technique",{"ticket":ticket}).ok,"警告中に強弓を取消できる")
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge._core.hostiles_snapshot().is_empty(),"警告中の取消後は矢を撃たない")
	bridge.dispose()
	c = centaurus_power_case()
	bridge = c.bridge
	ticket = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.1)
	check(bridge.command("dev_cancel_technique",{"ticket":ticket}).ok and bridge._core.hostiles_snapshot().size()==3,"発射後の取消でも撃った矢を残す")
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge.command("dev_ship_motion",{"position":Vector2(500,0),"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hostiles(0.5)
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,move.damage*load("res://data/config.tres").atk_scale),"参加者が消えても残った強弓の矢が機体へ実ダメージを与える")
	bridge._core.step_hostiles(1.0)
	check(bridge._core.hostiles_snapshot().is_empty(),"発射済みの矢は寿命で終わる")
	bridge.dispose()
	c = centaurus_power_case(false,false)
	bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge.command("dev_ship_motion",{"position":Vector2(0,300),"velocity":Vector2.ZERO})
	bridge._core.step(0.05)
	check(is_zero_approx(bridge.command("dev_boss_state").value[0].facing),"追尾しない設定では予告開始時の機体位置へ旋回する")
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge._core.hostiles_snapshot().is_empty(),"予告中の参加者消失で未発射の技を止める")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"参加者消失の出来事を配信する")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_power] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 指定の中断確認に不足していた警告フラグの解除だけを確認する。

func native_centaurus_power_cancel() -> void:
	var c := centaurus_power_case()
	var bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.06)
	bridge.command("dev_cancel_technique",{"ticket":ticket})
	check(not bridge.command("dev_boss_state").value[0].alerting,"警告中の取消で固定射線の警告フラグを消す")
	bridge.dispose()
	c = centaurus_power_case()
	bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.06)
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.01)
	check(not bridge.command("dev_boss_state").value[0].alerting,"参加者消失でも固定射線の警告フラグを消す")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_power_cancel] failures=",failed)
	get_tree().quit(1 if failed else 0)

func canis_flame_case() -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.base_hp = 1000.0
	var package: Dictionary = builder.boss_body_package(load("res://data/bosses/canis_major.tres"),cfg)
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	check(not bytes.is_empty(),"炎と点火の実効値を共通生成する")
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":153,"mode":1,"stage_id":"B_canis_flame","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"炎の型付き生成物を読む")
	if not configured.ok: print(configured); return {}
	bridge.start(153,{"position":Vector2(2000,0)})
	bridge.command("dev_ship_motion",{"position":Vector2(2000,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(2000,0),Vector2(2000,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	bridge.subscribe("表示",view.receive_frame)
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	return {"bridge":bridge,"view":view,"id":id,"package":package,"scope":scope}

func canis_effects(bridge) -> Array:
	return bridge.command("dev_boss_body_state").value[0].flames

func native_canis_flame() -> void:
	var c := canis_flame_case()
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	var view = c.view
	var display = view._boss_body_displays.values()[0].flames
	var initial: Dictionary = bridge.checkpoint()
	var held_jet := {}
	if "--cpp-canis-flame-tail" not in OS.get_cmdline_user_args():
		var profile: Dictionary = c.package.records.CanisFlameDefinition[0]
		var move = load("res://data/bosses/canis_major_moves/sirius.tres")
		check(is_equal_approx(profile.particle_life,move.beam_particle_life),"噴射の粒の寿命は技の実効値から生成する")
		var emitted: Dictionary = bridge.command("dev_canis_flame",{"entity_id":c.id,"definition":1,"target":0,"observation":4294967301})
		check(emitted.ok,"噴射・戦闘粒・焼け跡へ同じ64bit観測IDを渡す")
		bridge._core.step(0.12)
		var effects: Array = canis_effects(bridge)
		check(effects.any(func(e): return e.kind==1) and effects.any(func(e): return e.kind==2 and e.length>0.0),"発生した戦闘粒から焼け跡の到達距離を伸ばす")
		check(effects.all(func(e): return e.observation==4294967301),"別の技が始まっても生成時の観測IDを保持する")
		held_jet = bridge.checkpoint()
		check(held_jet.ok,"噴射中の親・粒・焼け跡を保持する")
		bridge._core.step(0.11)
		var after_jet: Array = canis_effects(bridge)
		check(bridge.restore(held_jet.value).ok,"噴射中の値と乱数を復帰する")
		bridge._core.step(0.11)
		check(canis_effects(bridge)==after_jet,"復帰後の粒の位置・速度・命中旗が一致する")
		view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
		check(display.displays.size()>0,"同じ戦闘粒をPixelFireの表示へ渡す")
		var before_display: Array = canis_effects(bridge).duplicate(true)
		display.presets[1] = display.presets[1].duplicate(true)
		display.presets[1].lifetime = 10.0
		display.apply_frame(before_display,0.23)
		check(canis_effects(bridge)==before_display,"表示プリセットの寿命を戦闘へ戻さない")
		bridge.command("dev_cancel_boss",{"entity_id":c.id})
		check(canis_effects(bridge).is_empty(),"噴射中の本体終了で全ての炎をBossClearする")
	check(bridge.restore(initial.value).ok,"点火前の独立状態へ戻る")
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var target: int = body.led[0].id
	check(bridge.command("dev_canis_flame",{"entity_id":c.id,"definition":5,"target":target,"observation":83}).ok,"移送先を個体IDと世代で持つ")
	bridge._core.step(0.07)
	var held_transfer: Dictionary = bridge.checkpoint()
	check(held_transfer.ok and canis_effects(bridge).any(func(e): return e.kind==3),"点火移送中の値を保持する")
	bridge._core.step(0.09)
	var packet: Dictionary = bridge.read_frame().value
	var arrivals: Array = packet.events.filter(func(e): return e.type==&"canis_ignite_arrived")
	check(canis_effects(bridge).is_empty() and arrivals.size()==1 and arrivals[0].payload.observation==83 and arrivals[0].payload.target==target,"表示の余韻を足さずignite_stepで点火の到着を確定する")
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	if not arrivals.is_empty(): display.frame_event(arrivals[0].payload.merged({"type":&"canis_ignite_arrived"}))
	display.apply_frame([],0.16)
	check(not display.fading.is_empty(),"到着後の点火の余韻は表示だけに残す")
	check(bridge.restore(held_transfer.value).ok,"点火移送中へ復帰する")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(canis_effects(bridge).is_empty(),"移送中の本体終了で到着予定も回収する")
	bridge.restore(initial.value)
	bridge.command("dev_canis_flame",{"entity_id":c.id,"definition":1,"target":0,"observation":84})
	bridge._core.step(1.1)
	var trail: Array = canis_effects(bridge)
	check(trail.size()==1 and trail[0].kind==2,"戦闘粒が消えた後も焼け跡を元の寿命まで残す")
	var held_trail: Dictionary = bridge.checkpoint()
	bridge._core.step(0.1)
	var after_trail: Array = canis_effects(bridge)
	check(held_trail.ok and bridge.restore(held_trail.value).ok,"焼け跡中の時計と伸びた長さを復帰する")
	bridge._core.step(0.1)
	check(canis_effects(bridge)==after_trail,"復帰後の焼け跡が同じ時刻まで残る")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(canis_effects(bridge).is_empty() and display.displays.is_empty() and display.fading.is_empty(),"焼け跡中の本体終了で戦闘と表示を閉じる")
	for held in [initial,held_jet,held_transfer,held_trail]:
		if not held.is_empty(): bridge.release_checkpoint(held.value)
	check(bridge.collect_frame().ok and bridge.delivery_error.ok,"炎の通知を共通配信から届ける")
	bridge.dispose()
	view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_flame] failures=",failed)
	get_tree().quit(1 if failed else 0)

func centaurus_stomp_case(flow_enabled := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.guard_count = 0
	definition.params.guard_min = 0
	definition.speed = 0.0
	var move = load("res://data/bosses/centaurus_moves/stomp.tres").duplicate(true)
	move.warn = 0.1
	move.active = 0.1
	move.recover = 0.05
	move.cd = 0.0
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg)
	if flow_enabled:
		var rules = load("res://data/bosses/ai/centaurus_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {"stomp":{"min":0.0,"max":500.0}}
		rules.costs = {"stomp":1.0}
		rules.selection_bias = {}
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.maximum_stamina = 10.0
		flow.sections = [{"request":"any","weights":{"single":1.0,"major":1.0},"cap":1.0,"action_count":1,"next":0}]
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in records: package.records[key] = records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	if bytes.is_empty():
		for record in builder.Schema.SCHEMA.records:
			for row in package.records[record.name]:
				if not builder.Schema._valid_record(row,record): print("生成入力の不一致: ",record.name," ",row)
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":158,"mode":1,"stage_id":"B_centaurus_stomp","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(158,{"position":Vector2(300,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(900,0),Vector2(900,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	return {"bridge":bridge,"id":id,"package":package,"events":events}


## 踏みつけの扇・脚の中心・時計・受理された命中だけの1回制限を確認する。

func native_centaurus_stomp() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/centaurus_moves/stomp.tres")
	var source = load("res://scripts/bosses/centaurus/techniques/stomp.gd")
	var animation = load("res://data/visuals/centaurus_animation.tres")
	if "--cpp-centaurus-stomp-runtime" not in OS.get_cmdline_user_args():
		var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
		check(records.CentaurusStompDefinition.size()==2 and records.CentaurusStompDefinition[0].radius==move.range_radius and is_equal_approx(records.CentaurusStompDefinition[0].half_angle,deg_to_rad(move.half_angle)) and records.BossTechniqueStage.is_empty(),"全項目と脚のフレームを生成し、戦闘method trackを使わない")
		check(move.make_runner()==null,"編集ResourceからRunnerを分離する")
	var c := centaurus_stomp_case(true)
	check(not c.is_empty(),"踏みつけを制作入口から型付きデータへつなぐ")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.step(0.001)
	var attacks: Array = bridge.command("dev_boss_state").value
	check(not attacks.is_empty() and attacks[0].kind==12 and attacks[0].stage==0,"遅延照準ではなく機体の今の位置で技を選ぶ")
	if attacks.is_empty(): bridge.dispose(); get_tree().quit(1); return
	var t: Dictionary = attacks[0]
	var expected: Vector2 = (source.contact_center(animation,0.0)*t.radius/135.0).rotated(t.facing-PI*0.5)+t.position
	check(t.center.is_equal_approx(expected),"脚の保存配置から現在の接地点を生成する")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0]._mode()==&"windup","扇の予告と脚の姿勢を正式表示へつなぐ")
	var facing: float = t.facing
	bridge.command("dev_ship_motion",{"position":t.center+Vector2(100,0),"velocity":Vector2.ZERO})
	bridge.command("dev_ship_defense",{"shield":1.0,"invulnerability":0.0})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.1)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and not t.hit and is_equal_approx(t.facing,facing) and bridge._core.ship_snapshot().ship_hp==hp,"予告中は向きを固定し、拒否されたダメージで命中済みにしない")
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0]._mode()==&"strike" and view._boss_body_displays.values()[0]._parts._clip=="stomp","実行中の脚のコマと扇を表示する")
	var held: Dictionary = bridge.checkpoint()
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.01)
	var after: Dictionary = bridge.command("dev_boss_state").value[0].duplicate(true)
	var hp_after: float = bridge._core.ship_snapshot().ship_hp
	check(after.hit and is_equal_approx(hp-hp_after,move.damage*load("res://data/config.tres").atk_scale),"盾がなくなると扇で1回だけ実ダメージを受ける")
	check(bridge.restore(held.value).ok,"開始時計・命中フラグ・脚の時刻を保持復帰する")
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.ship_snapshot().ship_hp==hp_after,"復帰後の中心・段階・命中結果が一致する")
	bridge.release_checkpoint(held.value)
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_state").value[0].stage==2 and bridge._core.ship_snapshot().ship_hp==hp_after,"有効時間の終わりに判定を閉じて硬直する")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5,"硬直が自然終了する")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"技の予告・実行・命中を公開更新と記録へ配信する")
	bridge.dispose()
	view.queue_free()
	c = centaurus_stomp_case()
	bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	t = bridge.command("dev_boss_state").value[0]
	bridge.command("dev_ship_motion",{"position":t.center+Vector2(-200,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.1)
	check(not bridge.command("dev_boss_state").value[0].hit,"中心の後ろは半径内でも扇の判定に入らない")
	bridge.command("dev_ship_motion",{"position":t.center+Vector2(1000,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.01)
	check(not bridge.command("dev_boss_state").value[0].hit,"今の機体位置だけを使い通過した線分で命中しない")
	hp = bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_cancel_technique",{"ticket":ticket})
	bridge.command("dev_ship_motion",{"position":t.center+Vector2(100,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge._core.ship_snapshot().ship_hp==hp,"取消後は扇の残留判定を持たない")
	bridge.dispose()
	c = centaurus_stomp_case()
	bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].stage==7,"参加者消失で未実行の踏みつけを取消する")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_stomp] failures=",failed)
	get_tree().quit(1 if failed else 0)

func begin_canis_lunge(c: Dictionary, target: int, action: int, changes := {}) -> Dictionary:
	var p := {"entity_id":c.id,"target":target,"action":action,"speed":500.0,"duration":0.5,"damage":2.0,"sweep":true,"shared_hit":false,"overwrite":true,"release":true,"defer":false}
	p.merge(changes,true)
	return c.bridge.command("dev_canis_lunge",p)

func canis_lunges(bridge) -> Array:
	return bridge.command("dev_boss_body_state").value[0].lunges

func enemy_velocity(core, id: int) -> Vector2:
	for enemy: Dictionary in core.enemies_snapshot():
		if enemy.id==id: return Vector2(enemy.vel[0],enemy.vel[1])
	return Vector2(INF,INF)

func native_canis_lunge() -> void:
	var c := canis_flame_case()
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.set_motion_context(Vector2(2000,0),Vector2(1000,0),Vector2(3000,2000))
	var initial: Dictionary = bridge.checkpoint()
	var led: Array = bridge.command("dev_boss_body_state").value[0].led
	var target: int = led[0].id
	var held := {}
	if "--cpp-canis-lunge-tail" not in OS.get_cmdline_user_args():
		bridge.command("dev_relocate",{"entity_id":target,"position":Vector2(500,0)})
		check(begin_canis_lunge(c,target,11).ok,"共通の部品から猟犬単位の突進を始める")
		bridge.command("dev_hound_order",{"entity_id":target,"action":"quiet","until":10.0,"velocity":Vector2(0,40)})
		bridge._core.step(0.1)
		var first: Dictionary = canis_lunges(bridge)[0]
		check(first.position.is_equal_approx(Vector2(500,4)) and first.from==first.position,"通常敵の移動を終えた位置からボスの掃引を更新する")
		check(enemy_velocity(bridge._core,target).is_equal_approx(Vector2(500,0)),"並行した移動指示の後に必要な型だけ固定速度を書き戻す")
		held = bridge.checkpoint()
		check(held.ok,"突進と並行指示の途中状態を保持する")
		bridge._core.step(0.1)
		var after: Array = canis_lunges(bridge)
		var after_velocity := enemy_velocity(bridge._core,target)
		check(bridge.restore(held.value).ok,"猟犬の世代・指示・前の位置・命中旗を復帰する")
		bridge._core.step(0.1)
		check(canis_lunges(bridge)==after and enemy_velocity(bridge._core,target)==after_velocity,"復帰後の突進と速度上書きが一致する")
		bridge.command("dev_cancel_canis_lunge",{"entity_id":c.id,"action":11})
		check(canis_lunges(bridge).is_empty() and not bridge._core.hound_snapshot().follows.any(func(f): return f.id==target),"猟犬単位の取消でfollowとquietの指示を解く")
	bridge.restore(initial.value)
	bridge.command("dev_relocate",{"entity_id":target,"position":Vector2(800,0)})
	bridge.command("dev_ship_motion",{"position":Vector2(800,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(800,0),Vector2(800,0),Vector2(640,360))
	for i in 2:
		bridge.command("dev_relocate",{"entity_id":led[i].id,"position":Vector2(800,0)})
		check(begin_canis_lunge(c,led[i].id,12,{"speed":0.0,"sweep":false,"shared_hit":true,"overwrite":false,"release":false}).ok,"号令用の点判定と行動全体の1回制限を設定する")
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.01)
	var hits: Array = canis_lunges(bridge)
	var scale: float = c.package.records.RunConfig[0].combat_atk_scale
	check(hits.size()==2 and hits.all(func(h): return h.hit) and is_equal_approx(bridge._core.ship_snapshot().ship_hp,hp-2.0*scale),"複数の猟犬が同時に触れても行動全体で1回だけ当てる")
	bridge.command("dev_hound_order",{"entity_id":target,"action":"quiet","until":10.0,"velocity":Vector2(0,40)})
	bridge._core.step(0.01)
	check(enemy_velocity(bridge._core,target).is_equal_approx(Vector2(0,40)),"号令用の型は毎tickの固定速度上書きを行わない")
	bridge.command("dev_cancel_canis_lunge",{"entity_id":c.id,"action":12})
	check(canis_lunges(bridge).is_empty() and bridge._core.hound_snapshot().follows.any(func(f): return f.id==target),"号令用の取消は当たりだけを終えfollowをその場で解除しない")
	bridge.restore(initial.value)
	begin_canis_lunge(c,target,13)
	bridge.command("dev_kill",{"entity_id":target,"cause":"debug"})
	bridge._core.step(0.01)
	check(canis_lunges(bridge).is_empty() and not bridge.command("dev_boss_body_state").value[0].boss_dead,"猟犬が消えたらその突進だけを閉じ本体を倒さない")
	bridge.restore(initial.value)
	begin_canis_lunge(c,target,14,{"duration":0.1})
	bridge._core.step(0.11)
	check(canis_lunges(bridge).is_empty(),"突進が自然に終わったら当たりと残留所有を閉じる")
	bridge.restore(initial.value)
	begin_canis_lunge(c,target,15)
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(canis_lunges(bridge).is_empty(),"本体取消で並行中の猟犬突進もBossClearする")
	for hold in [initial,held]:
		if not hold.is_empty(): bridge.release_checkpoint(hold.value)
	check(bridge.collect_frame().ok and bridge.delivery_error.ok,"突進の命中と終了を共通の通知配信へ渡す")
	bridge.dispose()
	c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_lunge] failures=",failed)
	get_tree().quit(1 if failed else 0)

func centaurus_fan_case(flow_enabled := false,tracking := true) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.guard_count = 0
	definition.params.guard_min = 0
	definition.speed = 0.0
	var move = load("res://data/bosses/centaurus_moves/fan_volley.tres").duplicate(true)
	move.warn = 0.1
	move.shots = 3
	move.interval = 0.1
	move.count = 3
	move.track_during_warn = tracking
	move.recover = 0.05
	move.cd = 0.0
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg)
	if flow_enabled:
		var rules = load("res://data/bosses/ai/centaurus_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {"fan_volley":{"min":0.0,"max":500.0}}
		rules.costs = {"fan_volley":1.0}
		rules.selection_bias = {}
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.maximum_stamina = 10.0
		flow.sections = [{"request":"normal","weights":{"major":1.0},"cap":1.0,"action_count":1,"next":0}]
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in records: package.records[key] = records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":158,"mode":1,"stage_id":"B_centaurus_fan_volley","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(158,{"position":Vector2(300,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	return {"bridge":bridge,"id":id,"package":package,"events":events}



## 扇状連射の本体追尾と射線の違い、追いつき連射、弾の残留を確認する。

func native_centaurus_fan() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/centaurus_moves/fan_volley.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
	check(records.CentaurusFanDefinition.size()==2 and records.CentaurusFanDefinition[0].shots==move.shots and records.CentaurusFanDefinition[0].count==move.count and is_equal_approx(records.CentaurusFanDefinition[0].spread,deg_to_rad(move.spread)) and records.CentaurusFanDefinition[0].length==move.length and records.BossTechniqueStage.is_empty(),"制作値の回数・本数・扇角度・カプセル長を生成する")
	check(move.make_runner()==null,"編集Resourceから扇状連射のRunnerを分離する")
	var c := centaurus_fan_case(false,false)
	check(not c.is_empty(),"制作入口の扇状連射と固有の矢を型付き形式へつなぐ")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.set_motion_context(Vector2(1400,1400),Vector2(300,300),Vector2(640,360))
	bridge._core.step(0.05)
	bridge._core.step(0.05)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	var shots: Array = bridge._core.hostiles_snapshot()
	check(t.stage==1 and t.released==1 and shots.size()==3 and is_zero_approx(t.facing),"追跡しない予告は本体の向きを保ちwarnで最初の3本を射る")
	var aim: Vector2 = Vector2(300,0)+(Vector2(1400,1400)-Vector2(300,0)).normalized()*load("res://data/config.tres").enemy_aim_speed*0.05
	var expected: float = (aim-shots[1].pos).angle() if shots.size()==3 else 0.0
	var angles_ok := shots.size()==3
	for k in shots.size(): angles_ok = angles_ok and is_equal_approx(shots[k].vel.angle(),expected+(k-1)*deg_to_rad(move.spread)*0.5) and is_equal_approx(shots[k].life,move.travel/move.speed) and is_equal_approx(shots[k].length,move.length)
	check(angles_ok and expected>0.0,"射る向きは追跡設定に関係なく今の遅延照準を使い扇に配る")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0]._parts._clip=="fan_release","正式な弓の解放姿勢と扇に並ぶ矢を表示する")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.21)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	shots = bridge._core.hostiles_snapshot()
	check(t.stage==2 and t.released==3 and shots.size()==9,"大きな更新では同じ回に不足した2射を出して直ちに硬直へ移る")
	check(bridge.restore(held.value).ok,"本体時計と射った回数を途中復帰する")
	bridge._core.step(0.21)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.hostiles_snapshot()==shots,"復帰後も同じ射数・角度・寿命になる")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5 and bridge._core.hostiles_snapshot().size()==9,"技が自然終了しても9本の矢は残る")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"一斉射のcueと戦闘通知を配信する")
	bridge.dispose()
	view.queue_free()
	c = centaurus_fan_case()
	bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.1)
	bridge.command("dev_cancel_technique",{"ticket":ticket})
	bridge.command("dev_remove",{"entity_id":c.id})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hostiles(1.0)
	check(bridge.command("dev_boss_state").value[0].stage==7 and is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,move.damage*load("res://data/config.tres").atk_scale),"取消と参加者消失でも発射済みの矢は残り倍率を1回掛けて命中する")
	bridge._core.step_hostiles(4.0)
	check(bridge._core.hostiles_snapshot().is_empty(),"残った扇の矢は寿命で終わる")
	bridge.dispose()
	c = centaurus_fan_case()
	bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.3)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge._core.hostiles_snapshot().is_empty(),"予告中の参加者消失では矢を発射しない")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_fan] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 遅延照準の更新順を使い、射線の未成立ケースだけを確認する。

func native_centaurus_fan_aim() -> void:
	var c := centaurus_fan_case(false,false)
	var bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.set_motion_context(Vector2(1400,1400),Vector2(300,300),Vector2(640,360))
	bridge._core.step(0.05)
	bridge._core.step(0.05)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	var shots: Array = bridge._core.hostiles_snapshot()
	var aim: Vector2 = Vector2(300,0)+(Vector2(1400,1400)-Vector2(300,0)).normalized()*load("res://data/config.tres").enemy_aim_speed*0.05
	var expected: float = (aim-shots[1].pos).angle() if shots.size()==3 else 0.0
	var angles_ok := shots.size()==3 and is_zero_approx(t.facing)
	var move = load("res://data/bosses/centaurus_moves/fan_volley.tres")
	for k in shots.size(): angles_ok = angles_ok and is_equal_approx(shots[k].vel.angle(),expected+(k-1)*deg_to_rad(move.spread)*0.5) and is_equal_approx(shots[k].life,move.travel/move.speed) and is_equal_approx(shots[k].length,move.length)
	check(angles_ok and expected>0.0,"本体の向きを固定しても実際の遅延照準へ扇を射る")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_fan_aim] failures=",failed)
	get_tree().quit(1 if failed else 0)

func centaurus_shower_case(pattern := "chase") -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.guard_count = 0
	definition.params.guard_min = 0
	definition.speed = 0.0
	var move = load("res://data/bosses/centaurus_moves/shower_"+pattern+".tres").duplicate(true)
	move.warn = 0.1
	move.count = 3
	move.count_p2 = 3 if pattern=="path" else 5
	move.interval = 0.1
	move.step = 0.1
	move.mark_time = 0.15
	move.rain_time = 0.05
	move.linger = 0.3
	move.recover = 0.05
	move.cd = 0.0
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	if bytes.is_empty():
		for record in builder.Schema.SCHEMA.records:
			for row in package.records[record.name]:
				if not builder.Schema._valid_record(row,record): print("生成入力の不一致: ",record.name," ",row)
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":158,"mode":1,"stage_id":"B_centaurus_arrow_shower","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(158,{"position":Vector2(500,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(500,0),Vector2(500,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	if pattern=="path":
		var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
		bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp*0.6,"cause":"bullet"})
		bridge._core.step(0.001)
		bridge._core.step(definition.params.phase_time)
	bridge.command("dev_ship_motion",{"position":Vector2(500,0),"velocity":Vector2.ZERO})
	return {"bridge":bridge,"id":id,"package":package,"events":events}

## 降り注ぐ矢の3配置・着弾だけの円判定・表示の残留と復帰を確認する。
func native_centaurus_shower() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	for pattern in ["chase","wall","path"]:
		var move = load("res://data/bosses/centaurus_moves/shower_"+pattern+".tres")
		var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
		check(records.CentaurusShowerDefinition.size()==2 and records.CentaurusShowerDefinition[0].pattern==["chase","wall","path"].find(pattern) and records.CentaurusShowerDefinition[0].count==move.count and records.CentaurusShowerDefinition[1].count==move.count_p2 and records.CentaurusShowerDefinition[0].linger==move.linger and records.CentaurusShowerDefinition[0].rain_time==move.rain_time and records.BossTechniqueStage.is_empty(),"3パターンの実効値と形態別の数を生成する: "+pattern)
		check(move.make_runner()==null,"3つの制作Resourceから戦闘Runnerを分離する: "+pattern)
	var c := centaurus_shower_case()
	check(not c.is_empty(),"追尾の円を制作入口から型付き状態へ接続する")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge.command("dev_ship_motion",{"position":Vector2(500,0),"velocity":Vector2(100,0)})
	var rng: String = bridge._core.inspect().rng_state
	bridge._core.step(0.1)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and t.shower.marks.size()==1 and t.shower.placed==1 and t.shower.marks[0].center.is_equal_approx(Vector2(550,0)) and t.shower.marks[0].shown and not t.shower.marks[0].landed,"warnで今の位置と速度から予測した円を1つ置く")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0]._mode()==&"rain" and not view._boss_body_displays.values()[0]._shower_visual.groups.is_empty(),"粉の円と降る矢を正式表示へつなぐ")
	await get_tree().process_frame
	var held: Dictionary = bridge.checkpoint()
	bridge.command("dev_ship_motion",{"position":Vector2(550,0),"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.15)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	var hp_after: float = bridge._core.ship_snapshot().ship_hp
	check(t.shower.marks[0].landed and is_equal_approx(hp-hp_after,load("res://data/bosses/centaurus_moves/shower_chase.tres").damage*load("res://data/config.tres").atk_scale),"着弾の瞬間だけ今の機体位置を円で判定して倍率を1回掛ける")
	check(bridge.restore(held.value).ok,"開始時計・円の予告/着弾・残り配置を復帰する")
	bridge.command("dev_ship_motion",{"position":Vector2(550,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.ship_snapshot().ship_hp==hp_after,"復帰後も同じ円と着弾結果になる")
	bridge.release_checkpoint(held.value)
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp==hp_after,"着弾済みの円は無敵が解けても再び当てない")
	bridge.command("dev_ship_motion",{"position":Vector2(1000,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.25)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==2 and t.shower.marks.is_empty() and bridge._core.hostiles_snapshot().is_empty(),"不足した配置に追いつき全円の余韻が終われば判定を閉じる")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5,"硬直が終われば技が自然終了する")
	check(bridge._core.inspect().rng_state==rng,"粉と矢の散らばりで戦闘乱数を消費しない")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"円の配置・着弾と独立したarrow_shower原因の通知を配信する")
	bridge.dispose()
	view.queue_free()
	c = centaurus_shower_case("wall")
	bridge = c.bridge
	ticket = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.1)
	t = bridge.command("dev_boss_state").value[0]
	var marks: Array = t.shower.marks
	check(marks.size()==3 and marks[1].center.is_equal_approx(Vector2(225,0)) and is_equal_approx(marks[0].at,0.2) and is_equal_approx(marks[1].at,0.1) and is_equal_approx(marks[2].at,0.2) and not marks[0].shown and marks[1].shown,"壁は距離割合と上下限で中心を決め、中央から外へ予告する")
	var visual = load("res://scripts/render/bosses/centaurus_shower.gd").new()
	add_child(visual)
	visual.apply_frame(t.shower,bridge.command("dev_boss_body_state").value[0])
	hp = bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_cancel_technique",{"ticket":ticket})
	bridge.command("dev_ship_motion",{"position":Vector2(225,0),"velocity":Vector2.ZERO})
	bridge._core.step(0.2)
	t = bridge.command("dev_boss_state").value[0]
	visual.apply_frame({},bridge.command("dev_boss_body_state").value[0])
	check(t.stage==7 and t.shower.marks.is_empty() and bridge._core.ship_snapshot().ship_hp==hp and not visual.groups.is_empty(),"取消で円の判定を消し、表示の矢だけは薄く残す")
	bridge._core.step(1.0)
	visual.apply_frame({},bridge.command("dev_boss_body_state").value[0])
	check(visual.groups.is_empty(),"表示だけ残した矢も期限で消える")
	bridge.dispose()
	visual.queue_free()
	c = centaurus_shower_case("path")
	bridge = c.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(500,0),"velocity":Vector2(100,0)})
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.1)
	t = bridge.command("dev_boss_state").value[0]
	marks = t.shower.marks
	check(marks.size()==3 and marks[1].center.is_equal_approx(Vector2(760,0)) and is_equal_approx(float(marks[2].at)-float(marks[0].at),0.2),"横切りは機体の進む向きの先を塞ぎ、端から順番に円を置く")
	var first_center: Vector2 = marks[0].center
	bridge._core.step(0.5)
	bridge._core.step(0.05)
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.1)
	marks = bridge.command("dev_boss_state").value[0].shower.marks
	check(marks.size()==3 and marks[2].center.is_equal_approx(first_center),"横切りの配置は次の技で左右を反転する")
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.3)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_state").value[0].shower.marks.is_empty(),"参加者消失で横切りの未着弾を止める")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_shower] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 共通の本体・表示と、指定した1技を既存ボス検査へつなぐ。
func canis_move_case(name: String, changes: Dictionary, flowing := false, body_changes := {}, obstacle := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 100.0 if obstacle else 0.0
	cfg.base_hp = 1000.0
	var definition = load("res://data/bosses/canis_major.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.call_below = 0
	definition.speed = 0.0
	for key in body_changes: definition.params[key] = body_changes[key]
	var move = load("res://data/bosses/canis_major_moves/%s.tres" % name).duplicate(true)
	for key in changes: move.set(key,changes[key])
	var package: Dictionary = builder.canis_technique_package(definition,move,cfg)
	if package.is_empty(): return {}
	if flowing:
		var rules = load("res://data/bosses/ai/canis_major_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {name:{"min":0.0,"max":5000.0}}
		rules.costs = {name:1.0}
		rules.selection_bias = {}
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.maximum_stamina = 10.0
		flow.sections = [{"request":"any","weights":{"single":1.0,"major":1.0},"cap":1.0,"action_count":1,"next":0}]
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in records: package.records[key] = records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":159,"mode":1,"stage_id":"B_canis_major_"+name,"profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(159,{"position":Vector2(2000,0)})
	bridge.command("dev_ship_motion",{"position":Vector2(2000,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(2000,0),Vector2(2000,0),Vector2(3000,2000))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(-400,0) if obstacle else Vector2.ZERO,"entrance":false}).value
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	bridge.subscribe("表示",view.receive_frame)
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	return {"bridge":bridge,"view":view,"scope":scope,"id":id,"package":package,"move":move}


func native_canis_command() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/canis_major_moves/command.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/canis_major.tres"),move)
	if "--cpp-canis-command-runtime" not in OS.get_cmdline_user_args():
		check(move.make_runner()==null and records.CanisCommandDefinition.size()==2 and records.CanisCommandDefinition[0].lunge_speed==move.lunge_speed and records.CanisCommandDefinition[1].lunge_speed==move.lunge_speed_p2 and records.BossTechniqueDefinition[1].cd==move.cd_p2,"号令の編集値と第2形態の実効値を生成する")
		check(records.BossTechniqueStage.size()==4 and records.BossTechniqueStage[0].at==move.warn and records.BossTechniqueStage[1].at==move.warn+move.lunge_time+0.05,"発動と終了を静的method trackから独立した時刻へ生成する")
	var c := canis_move_case("command",{"warn":0.1,"lunge_time":0.2,"lunge_speed":100.0,"lunge_speed_p2":100.0,"recover":0.05,"cd":0.0},true)
	check(not c.is_empty(),"号令の値・本体・フロー・正式表示を同じ入口から読む")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.step(0.01)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.kind==40 and t.stage==0,"フローの条件から号令を選択して予告を開始する")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var display = c.view._boss_body_displays.values()[0]
	check(display.technique.technique=="command" and display.technique.stage==0,"正式な本体の口輪へ予告を渡す")
	var before: Dictionary = bridge.checkpoint()
	check(before.ok,"予告の世代付き猟犬と段階を保持する")
	bridge._core.step(0.1)
	t = bridge.command("dev_boss_state").value[0]
	var lunges: Array = canis_lunges(bridge)
	check(t.stage==1 and lunges.size()==c.package.records.CanisBodyDefinition[0].pack_size and lunges.all(func(v): return not v.sweep and v.shared_hit and not v.overwrite and not v.hit),"warnで全猟犬へ発進し発動tickには命中を評価しない")
	var active: Dictionary = bridge.checkpoint()
	check(active.ok,"飛び出した猟犬の位置・当たり・指示を保持する")
	bridge._core.step(0.01)
	var after: Array = canis_lunges(bridge)
	check(bridge.restore(active.value).ok,"号令の実行中へ復帰する")
	bridge._core.step(0.01)
	check(canis_lunges(bridge)==after,"復帰後の猟犬と1回制限が同じ状態へ進む")
	var at: Vector2 = after[0].position
	bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(at,at,Vector2(3000,2000))
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	check(t.hit and canis_lunges(bridge).all(func(v): return v.hit) and is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,move.damage*load("res://data/config.tres").atk_scale),"猟犬の点と機体の移動線分から技全体で1回だけダメージを与える")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var unchanged: Array = canis_lunges(bridge).duplicate(true)
	for i in 7: c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(not display._trails.is_empty() and display._trails.values()[0].points.size()<=6 and canis_lunges(bridge)==unchanged,"6点以内の正式な軌跡は読むだけで戦闘へ書き戻さない")
	bridge._core.step(0.24)
	check(bridge.command("dev_boss_state").value[0].stage==2 and canis_lunges(bridge).is_empty(),"lunge_timeと0.05秒の後に命中を閉じ硬直へ移る")
	bridge._core.step(0.05)
	bridge._core.step(0.01)
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value.any(func(v): return v.stage==0 and v.id>t.id),"硬直終了をフローへ返し次の行動を開始する")
	check(bridge.restore(before.value).ok,"取消確認のため予告を戻す")
	var ticket: PackedInt64Array = [0,1]
	check(bridge.command("dev_cancel_technique",{"ticket":ticket}).ok and canis_lunges(bridge).is_empty(),"予告取消で猟犬の警告と未発動の攻撃を閉じる")
	bridge.restore(active.value)
	check(bridge.command("dev_cancel_technique",{"ticket":ticket}).ok and canis_lunges(bridge).is_empty() and not bridge._core.hound_snapshot().follows.is_empty(),"実行取消はfollowを即解除せず命中だけを閉じる")
	bridge.restore(active.value)
	var target: int = canis_lunges(bridge)[0].actor
	bridge.command("dev_remove",{"entity_id":target})
	bridge._core.step(0.01)
	check(not canis_lunges(bridge).any(func(v): return v.actor==target) and not bridge.command("dev_boss_body_state").value[0].boss_dead,"猟犬の消失はその猟犬だけの攻撃を閉じる")
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.01)
	check(canis_lunges(bridge).is_empty() and bridge.command("dev_boss_state").value[0].stage==7,"本体消失は号令と全猟犬の当たりを閉じる")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"号令の出来事を既存の配信へ通す")
	bridge.release_checkpoint(before.value)
	bridge.release_checkpoint(active.value)
	bridge.dispose()
	c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_command] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 号令の成功済みの実行検査を繰り返さず、次行動の待ちだけを照合する。

func native_canis_command_next() -> void:
	var c := canis_move_case("command",{"warn":0.1,"lunge_time":0.2,"lunge_speed":100.0,"lunge_speed_p2":100.0,"recover":0.05,"cd":0.0},true)
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.step(0.01)
	var first: Dictionary = bridge.command("dev_boss_state").value[0]
	bridge._core.step(0.1)
	bridge._core.step(0.25)
	bridge._core.step(0.05)
	bridge._core.step(0.01)
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value.any(func(v): return v.stage==0 and v.id>first.id),"硬直終了をフローへ返し再選択待ちの後に次の行動を開始する")
	print("次行動の状態: ",bridge.command("dev_boss_state").value," フロー: ",bridge.command("dev_boss_flow_state").value)
	bridge.dispose()
	c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_command_next] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 遠吠えの輪・追従・順番発進を既存のボス検査で確認する。
func native_canis_howl() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/canis_major_moves/howl.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/canis_major.tres"),move)
	check(move.make_runner()==null and records.CanisHowlDefinition.size()==2 and records.BossTechniqueStage.is_empty(),"遠吠えの編集値を手動進行の型付き定義へ生成する")
	for field in builder.Schema.SCHEMA.records.filter(func(v): return v.name=="CanisHowlDefinition")[0].fields:
		if field.name not in ["id","technique"]: check(records.CanisHowlDefinition[0][field.name]==move.get(field.name),"遠吠えの実効値を保持する: "+field.name)
	var changes := {"warn":0.1,"ring_count":10,"summon_max":1,"ring_radius":300.0,"ring_close":200.0,"spawn_out":100.0,"gather_time":0.05,"close_time":0.1,"follow_time":0.2,"follow_rate":4.0,"seq_interval":0.02,"seq_warn":0.05,"lunge_speed":100.0,"lunge_time":0.1,"tail":0.15,"recover":0.05,"cd":0.0,"track_during_warn":false}
	var c := canis_move_case("howl",changes,true)
	check(not c.is_empty(),"遠吠えを通常選択と正式表示へつなぐ")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.step(0.01)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.kind==41 and t.stage==0,"フローから遠吠えを選択して予告する")
	bridge._core.set_motion_context(Vector2(2000,1000),Vector2(2000,1000),Vector2(3000,2000))
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].facing>0.0,"遠吠えはtrack_during_warnの値によらず遅延照準へ向く")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var display = c.view._boss_body_displays.values()[0]
	check(display.parts.get_node("Head").rotation<0.0,"正式パーツで遠吠えの予告姿勢を使う")
	var before: Dictionary = bridge.checkpoint()
	check(before.ok,"形成前の時計と乱数を保持する")
	bridge._core.step(0.05)
	t = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(t.stage==1 and t.formed and body.ring.size()==9 and t.sequence.size()==9,"率いる8体を使い不足分を召喚上限1体まで補う")
	check(is_equal_approx(body.ring_radius,300.0) and body.ring_started>=0.0,"形成時は開始半径で自機の位置を中心にする")
	var formed: Dictionary = body.duplicate(true)
	var order: Array = t.sequence.duplicate(true)
	check(bridge.restore(before.value).ok,"形成前の乱数と状態へ復帰する")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_body_state").value[0]==formed and bridge.command("dev_boss_state").value[0].sequence==order,"復帰後も輪のずれ・薄い所・召喚・発進順が一致する")
	var ring_ids: Array = body.ring.map(func(v): return v.id)
	var base_angles: Array = body.ring.map(func(v): return v.angle)
	check(base_angles.all(func(a): return a>=base_angles[0]) and base_angles.any(func(a): return is_equal_approx((a-base_angles[0])/TAU*14.0,7.0)),"空ける2箇所を含む14等分の位置へ配置する")
	var center: Vector2 = formed.ring_center
	bridge.command("dev_ship_motion",{"position":center+Vector2(100,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(center+Vector2(100,0),center+Vector2(100,0),Vector2(3000,2000))
	bridge._core.step(0.05)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.ring_center.is_equal_approx(center+Vector2(100,0)*(1.0-exp(-4.0*0.05))) and is_equal_approx(body.ring_radius,300.0),"gather_timeの間は半径を保ち世界時計で中心を指数追従する")
	var ring_saved: Dictionary = bridge.checkpoint()
	check(ring_saved.ok,"輪の中心・個体世代・次の予告時刻を保持する")
	bridge._core.step(0.05)
	body = bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(body.ring_radius,250.0),"gather_time後はclose_timeの間に半径を線形で狭める")
	bridge._core.step(0.1)
	t = bridge.command("dev_boss_state").value[0]
	check(t.sequence[0].marked and not t.sequence[0].launched,"follow_timeの後に最初の猟犬を予告する")
	bridge._core.step(0.05)
	var lunges: Array = canis_lunges(bridge)
	check(lunges.size()==1 and lunges[0].sweep and not lunges[0].shared_hit and lunges[0].overwrite,"seq_warn後に猟犬ごとの掃引突進を1体ずつ出す")
	var active: Dictionary = bridge.checkpoint()
	check(active.ok,"輪と発進中の猟犬を一緒に保持する")
	var target: int = lunges[0].actor
	var at: Vector2 = lunges[0].position
	bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(at,at,Vector2(3000,2000))
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.01)
	check(canis_lunges(bridge).any(func(v): return v.actor==target and v.hit) and is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,move.damage*load("res://data/config.tres").atk_scale),"猟犬の移動線分と機体から個体ごとに1回だけ実ダメージを出す")
	body = bridge.command("dev_boss_body_state").value[0]
	var frozen_center: Vector2 = body.ring_center
	bridge._core.step(0.02)
	check(bridge.command("dev_boss_body_state").value[0].ring_center==frozen_center,"follow_time後は輪の中心を固定して順番発進を続ける")
	var after: Array = canis_lunges(bridge)
	var after_body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(bridge.restore(active.value).ok,"発進途中へ復帰する")
	bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(at,at,Vector2(3000,2000))
	bridge._core.step(0.01)
	bridge._core.step(0.02)
	check(canis_lunges(bridge)==after and bridge.command("dev_boss_body_state").value[0]==after_body,"復帰後も突進・輪の残り・次の発進が一致する")
	var read_only: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(display.state.ring==read_only.ring and bridge.command("dev_boss_body_state").value[0]==read_only,"正式表示は輪の現在状態を読むだけにする")
	bridge._core.step(0.5)
	check(bridge.command("dev_boss_state").value[0].stage==2 and canis_lunges(bridge).is_empty() and bridge.command("dev_boss_body_state").value[0].ring_started<0.0,"最後の発進とtailの後に輪と残る突進を閉じる")
	bridge._core.step(0.05)
	bridge._core.step(0.01)
	bridge._core.step(0.15)
	check(bridge.command("dev_boss_state").value.any(func(v): return v.stage==0 and v.id>t.id),"遠吠えの硬直後に次行動へ戻る")
	bridge.restore(ring_saved.value)
	var ticket: PackedInt64Array = [0,1]
	check(bridge.command("dev_cancel_technique",{"ticket":ticket}).ok and bridge.command("dev_boss_body_state").value[0].ring_started<0.0 and canis_lunges(bridge).is_empty(),"形成中の取消で輪・予告・未発進の指示を解く")
	bridge.restore(active.value)
	bridge.command("dev_remove",{"entity_id":target})
	bridge._core.step(0.01)
	check(not canis_lunges(bridge).any(func(v): return v.actor==target) and not bridge.command("dev_boss_body_state").value[0].boss_dead,"猟犬消失はその個体だけを閉じる")
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.01)
	check(canis_lunges(bridge).is_empty() and bridge.command("dev_boss_body_state").value[0].ring_started<0.0 and bridge.command("dev_boss_state").value[0].stage==7,"本体消失は輪と全突進を取消する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"遠吠えの出来事を表示と記録へ配信する")
	for held in [before,ring_saved,active]: bridge.release_checkpoint(held.value)
	bridge.dispose()
	c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_howl] failures=",failed)
	get_tree().quit(1 if failed else 0)

func centaurus_sail_case() -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.phase_time = 0.01
	definition.params.guard_count = 1
	definition.params.guard_min = 0
	definition.speed = 0.0
	var move = load("res://data/bosses/centaurus_moves/sail_run.tres").duplicate(true)
	move.warn = 0.1
	move.duration = 0.3
	move.interval = 0.1
	move.radius_min = 300.0
	move.radius_max = 300.0
	move.arc = 90.0
	move.recover = 0.05
	move.cd = 0.0
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":158,"mode":1,"stage_id":"B_centaurus_sail_run","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(158,{"position":Vector2(300,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	return {"bridge":bridge,"id":id,"package":package,"events":events}


func native_centaurus_sail() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/centaurus_moves/sail_run.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
	check(records.CentaurusSailDefinition.size()==2 and records.CentaurusSailDefinition[0].approach_speed==move.approach_speed and is_equal_approx(records.CentaurusSailDefinition[0].arc,deg_to_rad(move.arc)) and records.CentaurusSailDefinition[0].duration==move.duration and records.BossTechniqueStage.is_empty() and move.make_runner()==null,"帆走の全項目と弧角度を生成し編集ResourceからRunnerを分離する")
	var c := centaurus_sail_case()
	check(not c.is_empty(),"帆走を本体・矢の固有外観と同じ型付き形式で読む")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"第1形態の帆走は直接の制作入口でも拒否する")
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp*0.55,"cause":"bullet"})
	bridge._core.step(0.01)
	bridge._core.step(0.01)
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).value
	bridge._core.step(0.1)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and t.released==1 and t.boosted and t.side==1 and t.orbit_radius==300.0 and t.position.distance_to(Vector2.ZERO)<0.001,"弧の中心・半径・交互の向きを保持して予告後に走り始める")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0]._mode()==&"sail" and view._boss_body_displays.values()[0].sail_fraction()==1.0,"正式な表示入口へ帆走の姿勢・広げた帆と矢を渡す")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.301)
	t = bridge.command("dev_boss_state").value[0]
	var shots: Array = bridge._core.hostiles_snapshot()
	var after: Dictionary = t.duplicate(true)
	check(t.stage==2 and t.released==3 and not t.boosted and t.position.is_equal_approx(Vector2(300,-300)) and shots.size()==3,"弧の終端まで差分移動し時間内の3射だけ出して護衛の強化を解除する")
	check(bridge.restore(held.value).ok,"弧の中心・向き・射数・護衛強化を途中復帰する")
	bridge._core.step(0.301)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.hostiles_snapshot()==shots,"復帰後も同じ弧と射数・矢の寿命になる")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5 and bridge._core.hostiles_snapshot().size()==3,"硬直が終わっても発射済みの矢は自然寿命まで残る")
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.101)
	t = bridge.command("dev_boss_state").value[0]
	check(t.side==-1 and t.boosted,"次の帆走は逆向きに走る")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==7 and not t.boosted and bridge._core.hostiles_snapshot().size()==4,"取消で護衛の強化を外し発射済みの矢は残す")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"帆走開始・射撃・帆たたみのcueを配信する")
	bridge.dispose()
	view.queue_free()
	c = centaurus_sail_case()
	bridge = c.bridge
	body = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp*0.55,"cause":"bullet"})
	bridge._core.step(0.01)
	bridge._core.step(0.01)
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.2)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==7 and not t.boosted and bridge._core.hostiles_snapshot().is_empty(),"参加者が予告中に消失したら強化を外し矢を新しく出さない")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_sail] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 連携でも部品の値と取消規約をそのまま使う。
func centaurus_combo_case(shower := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	var definition = load("res://data/bosses/centaurus.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.guard_count = 0
	definition.params.guard_min = 0
	definition.speed = 0.0
	var name := "combo_shower_shot" if shower else "combo_rain_volley"
	var move = load("res://data/bosses/centaurus_moves/"+name+".tres").duplicate(true)
	move.gap = 0.05
	var first = load("res://data/bosses/centaurus_moves/"+("shower_chase" if shower else "rain")+".tres").duplicate(true)
	var last = load("res://data/bosses/centaurus_moves/"+("power_shot" if shower else "volley")+".tres").duplicate(true)
	first.warn = 0.02
	first.recover = 10.0
	first.cd = 0.5
	last.warn = 0.02
	last.recover = 0.03
	last.cd = 0.5
	if shower:
		first.count = 1
		first.mark_time = 0.03
		first.rain_time = 0.03
		last.alert = 0.01
	else:
		first.traces = 1
		first.trace_length = 60.0
		first.trace_speed = 600.0
		first.arrow_gap = 30.0
		first.drop_delay = 0.02
		first.fall = 0.02
		first.linger = 0.01
		last.count = 2
		last.count_p2 = 2
		last.interval = 0.02
	var package: Dictionary = builder.centaurus_technique_package(definition,move,cfg,[first,last])
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":158,"mode":1,"stage_id":name,"profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(158,{"position":Vector2(600,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge._core.set_motion_context(Vector2(600,0),Vector2(600,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_ship_motion",{"position":Vector2(600,0),"velocity":Vector2.ZERO})
	return {"bridge":bridge,"id":id,"package":package,"events":events}

func native_centaurus_combo_rain() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/centaurus_moves/combo_rain_volley.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
	check(records.CentaurusComboDefinition.size()==2 and records.CentaurusComboDefinition[0].gap==move.gap and records.CentaurusComboDefinition[0].first==1 and records.CentaurusComboDefinition[0].second==3 and records.BossTechniqueDefinition[4].cd==move.cd and move.make_runner()==null,"連携Resourceの全値と形態ごとの部品参照を生成する")
	var c := centaurus_combo_case()
	check(not c.is_empty(),"矢の雨と速射の部品・外観・連携を同じ制作入口で読む")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":5}).value
	bridge._core.step(0.02)
	bridge._core.step(0.01)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.technique=="rain" and t.combo=="combo_rain_volley" and t.combo_step==0 and t.stage==1 and not t.rain.traces.is_empty(),"連携の前半は矢の雨そのものの時計・軌跡・命中を使う")
	for i in 40:
		if bridge.command("dev_boss_state").value[0].get("combo_waiting",false): break
		bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	check(t.combo_waiting and t.stage==2 and is_equal_approx(t.remaining,0.05) and t.rain.traces.is_empty(),"前半の硬直10秒を使わず、雨を閉じて世界時間のgapへ移る")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.03)
	check(bridge.command("dev_boss_state").value[0].combo_waiting and bridge._core.hostiles_snapshot().is_empty(),"gapが残る間は後半を始めない")
	bridge._core.step(0.03)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	check(t.technique=="volley" and t.combo_step==1 and t.stage==0 and is_zero_approx(t.elapsed) and t.id==1,"次の更新で同じ技チケットのまま速射の予告を始める")
	check(bridge.restore(held.value).ok,"前半終了後のgapと子の状態を保持・復帰する")
	bridge._core.step(0.03)
	bridge._core.step(0.03)
	check(bridge.command("dev_boss_state").value[0]==after,"復帰後も同じ更新境界で後半を始める")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.041)
	t = bridge.command("dev_boss_state").value[0]
	check(t.technique=="volley" and t.released==2 and bridge._core.hostiles_snapshot().size()==2,"後半は速射自身の予告・間隔・本数で射る")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0].technique.technique=="volley","連携の現在の部品を正式表示へ渡す")
	bridge._core.step(0.06)
	bridge._core.step(0.03)
	check(bridge.command("dev_boss_state").value[0].stage==5 and bridge._core.hostiles_snapshot().size()==2,"後半の硬直で連携全体を終え、発射済みの矢は残す")
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":5}).ok,"連携と部品の再使用待ちを開始時に確定する")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"両部品の戦闘通知とcueを配信する")
	bridge.dispose()
	view.queue_free()
	for remove in [false,true]:
		c = centaurus_combo_case()
		bridge = c.bridge
		ticket = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":5}).value
		bridge._core.step(0.02)
		bridge._core.step(0.01)
		if remove: bridge.command("dev_remove",{"entity_id":c.id})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket})
		bridge._core.step(0.6)
		t = bridge.command("dev_boss_state").value[0]
		check(t.stage==7 and t.rain.traces.is_empty() and bridge._core.hostiles_snapshot().is_empty(),"前半の取消・参加者消失で雨を消し、後半を始めない")
		bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_combo_rain] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 追跡する降り矢から照準固定の強弓へ進む。
func native_centaurus_combo_shower() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/centaurus_moves/combo_shower_shot.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/centaurus.tres"),move)
	check(records.CentaurusComboDefinition.size()==2 and records.CentaurusComboDefinition[0].gap==move.gap and records.CentaurusShowerDefinition[0].pattern==0 and records.CentaurusPowerDefinition[0].technique==3 and records.BossTechniqueDefinition[4].cd==move.cd and move.make_runner()==null,"降り矢と強弓の全値・形態別参照・連携の値を生成する")
	var c := centaurus_combo_case(true)
	check(not c.is_empty(),"追跡する降り矢・強弓・固有外観を同じ制作入口で読む")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":5})
	bridge._core.step(0.02)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.technique=="shower_chase" and t.combo=="combo_shower_shot" and t.shower.marks.size()==1 and not t.shower.marks[0].landed,"前半の遅延予告は追跡する降り矢の判定・時計を使う")
	bridge._core.step(0.031)
	check(bridge.command("dev_boss_state").value[0].shower.marks[0].landed,"前半の印は自身のmark_timeで一度だけ着弾する")
	bridge._core.step(0.031)
	t = bridge.command("dev_boss_state").value[0]
	check(t.combo_waiting and t.shower.marks.is_empty() and is_equal_approx(t.remaining,0.05),"降り矢の表示と攻撃を閉じ、前半の硬直を挟まずgapへ進む")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.051)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	check(t.technique=="power_shot" and t.combo_step==1 and t.stage==0 and is_zero_approx(t.elapsed),"次の更新で強弓自身の予告を始める")
	check(bridge.restore(held.value).ok,"降り矢終了後のgapと子の値を途中復帰する")
	bridge._core.step(0.051)
	check(bridge.command("dev_boss_state").value[0]==after,"復帰後も同じ境界で強弓へ進む")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.011)
	t = bridge.command("dev_boss_state").value[0]
	check(t.alerting,"後半は強弓自身のalert時刻で照準を固定する")
	bridge._core.step(0.011)
	t = bridge.command("dev_boss_state").value[0]
	check(t.released==1 and bridge._core.hostiles_snapshot().size()==1 and bridge._core.hostiles_snapshot()[0].kind==builder.Schema.ENUMS.HostileKind.CosmicArrow,"強弓の予告が終わるとコズミックの矢を放つ")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,1.0)
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0].technique.technique=="power_shot","後半の強弓の姿勢と矢を正式表示へ渡す")
	bridge._core.step(0.051)
	bridge._core.step(0.031)
	check(bridge.command("dev_boss_state").value[0].stage==5 and bridge._core.hostiles_snapshot().size()==1,"強弓の硬直で連携を自然終了し、放った矢は残す")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"降り矢・強弓の戦闘とcueを同じ通知経路へ送る")
	bridge.dispose()
	view.queue_free()
	for remove in [false,true]:
		c = centaurus_combo_case(true)
		bridge = c.bridge
		var ticket: PackedInt64Array = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":5}).value
		bridge._core.step(0.02)
		if remove: bridge.command("dev_remove",{"entity_id":c.id})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket})
		bridge._core.step(0.6)
		t = bridge.command("dev_boss_state").value[0]
		check(t.stage==7 and t.shower.marks.is_empty() and bridge._core.hostiles_snapshot().is_empty(),"前半の取消・参加者消失で降り矢を消して強弓を始めない")
		bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_combo_shower] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 制作の全技・フローと共通決着を、一つの専用ランへつなぐ。
func centaurus_finish_case(limit := -1.0, automatic := false, parameters := {}) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	for key in ["boss_finish_slow_time","boss_finish_blast_time","boss_finish_relic_appear_time","boss_finish_relic_hold_time","boss_finish_relic_collect_time","boss_finish_clear_time","time_up_charge_time"]: cfg.set(key,0.02)
	cfg.death_freeze_time = 0.01
	cfg.death_explosion_time = 0.01
	cfg.death_game_over_time = 0.01
	var boss = load("res://data/bosses/centaurus.tres").duplicate(true)
	boss.params.initial_wait = 0.0
	boss.params.phase_time = 0.01
	boss.params.guard_count = 0
	boss.params.guard_min = 0
	boss.params.merge(parameters,true)
	boss.speed = 0.0
	var stage := RuntimeStage.new()
	stage.time_limit = limit
	stage.legendary_module_id = ContentManager.stage(2).legendary_module_id
	var package: Dictionary = builder.boss_package(boss,cfg,stage)
	if package.is_empty(): return {}
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":192,"mode":1,"stage_id":"B_centaurus_finish","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(192,{"position":Vector2(600,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge.command("dev_ship_motion",{"position":Vector2(600,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(600,0),Vector2(600,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	if not automatic: bridge.command("dev_cancel_flow",{"entity_id":id})
	return {"bridge":bridge,"id":id,"package":package,"events":events,"boss":boss}

func centaurus_finish_low(f: Dictionary) -> void:
	var body: Dictionary = f.bridge.command("dev_boss_body_state").value[0]
	f.bridge.command("dev_damage",{"entity_id":f.id,"amount":body.max_hp*0.6,"cause":"debug","no_crit":true})
	f.bridge._core.step(0.01)
	f.bridge._core.step(0.01)

func centaurus_finish_steps(bridge, count: int) -> bool:
	var ok := true
	for i in count: ok = bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and ok
	return ok

func native_centaurus_finish() -> void:
	var f := centaurus_finish_case(-1.0,true)
	check(not f.is_empty(),"全技・条件・制作フロー・決着を同じ生成入口で読む")
	if f.is_empty(): get_tree().quit(1); return
	var bridge = f.bridge
	var records: Dictionary = f.package.records
	check(records.BossTechniqueDefinition.size()==24 and records.CentaurusComboDefinition.size()==4 and records.BossFinishDefinition.size()==1 and not records.BossFlowAction.is_empty(),"全12技の2形態を重複登録せず、連携から同じ部品を参照する")
	check(ContentManager.stage(2).boss_enabled==load("res://data/stages/stage_2.tres").boss_enabled and records.BossBodyDefinition[0].hp_floor_enabled==false,"ステージ2の実制作の出現設定と本体のHP下限なしを保つ")
	bridge._core.step(0.01)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(records.BossTechniqueDefinition[t.definition-1].phase==1,"通常HPでは制作フローが第1形態の技を選ぶ")
	bridge.dispose()
	f = centaurus_finish_case(-1.0,true)
	bridge = f.bridge
	centaurus_finish_low(f)
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	check(bridge.command("dev_boss_body_state").value[0].phase==2 and f.package.records.BossTechniqueDefinition[t.definition-1].phase==2,"低HPでは制作フローが第2形態の値を選ぶ")
	bridge.dispose()
	var activated: Array[String] = []
	for name in ["volley","power_shot","rain","rear_attack","shower_chase","shower_wall","stomp","fan_volley","combo_shower_shot","combo_rain_volley","shower_path","sail_run"]:
		f = centaurus_finish_case()
		bridge = f.bridge
		if name in ["shower_path","sail_run"]: centaurus_finish_low(f)
		var rows: Array = f.package.records.BossTechniqueDefinition.filter(func(row): return row.external_id==name and row.phase==1)
		var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":rows[0].id})
		var started: Dictionary = bridge.command("dev_boss_state").value[0]
		var rule: Dictionary = f.package.records.BossTechniqueDefinition[started.definition-1]
		bridge._core.step(rule.warn+0.001)
		bridge._core.step(0.001)
		t = bridge.command("dev_boss_state").value[0]
		var emitted: bool = t.stage==1 and (t.get("combo",t.technique)==name)
		check(ticket.ok and emitted,"実制作の値で攻撃まで発動する: "+name)
		if emitted: activated.append(name)
		bridge.dispose()
	print("[cpp_centaurus_finish] 実発動=",activated)
	# 近距離の踏みつけは通常抽選を通さない。
	f = centaurus_finish_case(-1.0,true,{"leap_trigger":0.0,"retreat_trigger":0.0})
	bridge = f.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(100,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(100,0),Vector2(100,0),Vector2(640,360))
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	check(t.technique=="stomp" and t.stage==0 and is_zero_approx(t.elapsed) and bridge.command("dev_boss_flow_state").value[0].stamina==load("res://data/bosses/ai/centaurus_flow.tres").maximum_stamina,"踏みつけを抽選より優先し、開始した更新のdtやスタミナを使わない")
	bridge.dispose()
	# 第1形態の横切り・帆走を直接の制作入口でも拒否する。
	f = centaurus_finish_case()
	bridge = f.bridge
	var restricted: bool = true
	for name in ["shower_path","sail_run"]:
		var row: Dictionary = f.package.records.BossTechniqueDefinition.filter(func(item): return item.external_id==name and item.phase==1)[0]
		restricted = not bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":row.id}).ok and restricted
	check(restricted,"第2形態だけの横切りと帆走を第1形態では始めない")
	centaurus_finish_low(f)
	bridge.command("dev_ship_motion",{"position":Vector2(600,0),"velocity":Vector2(0,2000)})
	bridge._core.step(0.6)
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.61)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	check(t.technique=="shower_path" and t.stage==0 and is_zero_approx(bridge.command("dev_boss_body_state").value[0].path_hold),"横切りが続くと制作の条件からshower_pathを自動開始して保持時間を戻す")
	check(bridge.restore(held.value).ok,"自動選択前の横切り保持時間と再使用待ちを復帰する")
	bridge._core.step(0.61)
	check(bridge.command("dev_boss_state").value[0]==after,"復帰後も同じ横切りの開始に進む")
	bridge.release_checkpoint(held.value)
	bridge.dispose()
	# 跳躍は差分移動し、着地した更新では壁の予告を進めない。
	f = centaurus_finish_case()
	bridge = f.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(100,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(100,0),Vector2(100,0),Vector2(640,360))
	bridge._core.step(0.01)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.leaping and body.leap_to.is_equal_approx(Vector2(-320,0)) and bridge.command("dev_boss_state").value.is_empty(),"近づいた機体から離れる跳躍を最初の優先順位で始める")
	bridge._core.step(0.175)
	var scope := ContentResourceScope.new()
	for asset: Dictionary in f.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(f.package.visuals)
	view.setup(scope,entries,1.0)
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0]._mode()==&"leap" and view._boss_body_displays.values()[0]._parts.scale.x>body.radius/135.0,"跳躍の進行だけを読み、正式パーツを浮かせて拡大する")
	held = bridge.checkpoint()
	bridge._core.step(0.175)
	t = bridge.command("dev_boss_state").value[0]
	after = t.duplicate(true)
	check(not bridge.command("dev_boss_body_state").value[0].leaping and t.technique=="shower_wall" and t.stage==0 and is_zero_approx(t.elapsed),"着地でshower_wallを始め、同じ更新のdtを予告へ使わない")
	check(bridge.restore(held.value).ok,"跳躍の始点・終点・進行・期限を途中復帰する")
	bridge._core.step(0.175)
	check(bridge.command("dev_boss_state").value[0]==after,"復帰後も同じ着地と壁の開始になる")
	bridge.release_checkpoint(held.value)
	bridge.dispose()
	view.queue_free()
	f = centaurus_finish_case()
	bridge = f.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(380,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(380,0),Vector2(380,0),Vector2(640,360))
	bridge._core.step(0.01)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.leaping and body.retreat_ready_at>body.clock,"後退条件では同じ跳躍へ入り、後退の再使用期限も保存する")
	bridge.dispose()
	# 共通決着は本体撃破・制限時間・途中中断を別の結果へ送る。
	f = centaurus_finish_case()
	bridge = f.bridge
	bridge.command("dev_kill",{"entity_id":f.id,"cause":"debug"})
	check(centaurus_finish_steps(bridge,1) and bridge.read_frame().value.ui.phase==RunState.Phase.FINISHING and bridge.read_frame().value.result==null,"第1形態の実撃破から報酬未確定の決着へ進む")
	held = bridge.checkpoint()
	centaurus_finish_steps(bridge,3)
	var expected: Dictionary = bridge.read_frame().value.ui.boss_finish
	check(expected.blasted and f.events.filter(func(event): return event.type==&"boss_explode").size()==1,"決着のスロー再生後に本体と残る敵弾を一度消す")
	check(bridge.restore(held.value).ok,"決着途中の時計と消滅状態を復帰する")
	centaurus_finish_steps(bridge,3)
	check(bridge.read_frame().value.ui.boss_finish==expected,"復帰後も同じ決着の段階へ進む")
	bridge.release_checkpoint(held.value)
	centaurus_finish_steps(bridge,20)
	var frame: Dictionary = bridge.read_frame().value
	check(frame.result!=null and frame.result.kind=="Clear" and frame.result.legendary=="legendary_sail" and f.events.any(func(event): return event.type==&"clear_banner"),"報酬とCLEARのあとにケンタウルスの勝利を一度確定する")
	check(bridge.collect_frame().ok and bridge.delivery_error.ok,"決着と勝利の通知を共通の表示・記録経路へ渡す")
	bridge.dispose()
	f = centaurus_finish_case(0.01)
	bridge = f.bridge
	centaurus_finish_steps(bridge,2)
	check(bridge.command("dev_boss_body_state").value[0].mode==3 and f.events.any(func(event): return event.type==&"time_limit_reached"),"実制限時間からケンタウルスの最終攻撃へ進む")
	centaurus_finish_steps(bridge,24)
	frame = bridge.read_frame().value
	check(frame.result!=null and frame.result.kind=="Death" and frame.result.last_damage.cause==&"final_strike","時間切れの最終攻撃から共通の敗北へ進む")
	bridge.dispose()
	f = centaurus_finish_case()
	bridge = f.bridge
	check(bridge.command("abort",{"reason":0}).ok and bridge.read_frame().value.result.kind=="Abort" and bridge.command("dev_boss_body_state").value[0].mode==5,"途中中断は本体を取消し、クリア報酬を付けずに終える")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_finish] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 本体の飛びかかりを、先読み・固定・着地・連続跳躍まで照合する。
func native_canis_pounce() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/canis_major_moves/pounce.tres")
	var records: Dictionary = builder.boss_technique_records(load("res://data/bosses/canis_major.tres"),move)
	check(move.make_runner()==null and records.CanisPounceDefinition.size()==2 and records.BossTechniqueStage.is_empty(),"飛びかかりの値をmanualの型付き定義へ分ける")
	check(records.BossTechniqueDefinition[1].warn==move.warn_p2 and records.BossTechniqueDefinition[1].cd==move.cd_p2 and records.CanisPounceDefinition[1].cd_alone==move.cd_alone_p2 and records.CanisPounceDefinition[0].overshoot==move.overshoot,"形態別の予告・再使用待ちと先の着地点の値を生成する")
	var c := canis_move_case("pounce",{"warn":0.1,"active":0.2,"lock":0.04,"overshoot":40.0,"lead_extra":0.1,"recover":0.05})
	check(not c.is_empty(),"飛びかかりの制作値を本体と正式表示へつなぐ")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2(100,0)})
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(3000,2000))
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(started.ok,"本体の独立した飛びかかりを開始する")
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.left==1 and t.aim.is_equal_approx(Vector2(320,0)) and not t.locked,"群れが多いと1回だけ跳び残り予告とlead_extraで先読みする")
	bridge._core.step(0.04)
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var display = c.view._boss_body_displays.values()[0]
	check(display.technique.technique=="pounce" and is_equal_approx(display.technique.crouch,0.4) and is_equal_approx(display.parts.scale.x/display.parts.scale.y,1.06/0.94),"正式パーツへ溜めの縮みと着地点の予告を渡す")
	bridge._core.step(0.021)
	t = bridge.command("dev_boss_state").value[0]
	check(t.locked and t.aim.is_equal_approx(Vector2(356,0)) and t.direction.is_equal_approx(Vector2.RIGHT),"lock時点の先読みにovershootを足して固定する")
	bridge.command("dev_ship_motion",{"position":Vector2(800,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(800,0),Vector2(800,0),Vector2(3000,2000))
	bridge._core.step(0.04)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and t.jumping and t.position==Vector2.ZERO and t.aim.is_equal_approx(Vector2(356,0)),"warnで発進しそのtickは動かず固定した着地点を維持する")
	var active: Dictionary = bridge.checkpoint()
	check(active.ok,"発進した本体の狙い・段階・命中旗を保持する")
	bridge.command("dev_ship_motion",{"position":Vector2(178,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(178,0),Vector2(178,0),Vector2(3000,2000))
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.05)
	t = bridge.command("dev_boss_state").value[0]
	var hp_after: float = bridge._core.ship_snapshot().ship_hp
	check(t.position.is_equal_approx(Vector2(89,0)) and t.hit and is_equal_approx(hp-hp_after,move.damage*load("res://data/config.tres").atk_scale),"残り時間で移動し本体の掃引と機体線分から1回だけ実ダメージを出す")
	var after: Dictionary = t.duplicate(true)
	check(bridge.restore(active.value).ok,"飛びかかりの発進時点へ復帰する")
	bridge.command("dev_ship_motion",{"position":Vector2(178,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(178,0),Vector2(178,0),Vector2(3000,2000))
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.ship_snapshot().ship_hp==hp_after,"復帰後も位置・速度・命中結果を同じにする")
	bridge._core.step(0.15)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==2 and t.done and t.left==0 and t.position.is_equal_approx(Vector2(356,0)) and bridge._core.ship_snapshot().ship_hp==hp_after,"activeの終わりで着地し再命中せず硬直へ移る")
	var read_only: Dictionary = t.duplicate(true)
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(bridge.command("dev_boss_state").value[0]==read_only,"飛びかかりの正式表示は戦闘へ値を書き戻さない")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5,"硬直を終え技の完了を返す")
	bridge.restore(active.value)
	bridge._core.set_run_guards({"invincible":true})
	bridge.command("dev_ship_motion",{"position":Vector2(178,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(178,0),Vector2(178,0),Vector2(3000,2000))
	hp = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].hit and bridge._core.ship_snapshot().ship_hp==hp,"ダメージを拒否されても接触を先に命中済みにする")
	bridge._core.set_run_guards({"invincible":false})
	bridge._core.step(0.01)
	check(bridge._core.ship_snapshot().ship_hp==hp,"保護が終わっても同じ跳躍では再試行しない")
	bridge.restore(active.value)
	check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"跳躍途中を取消する")
	var stopped: Vector2 = bridge.command("dev_boss_body_state").value[0].position
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].position==stopped,"取消後は飛びかかりの移動と当たりを止める")
	bridge.restore(active.value)
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7,"本体消失は飛びかかりを取消する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"飛びかかりの出来事と実被弾を配信する")
	bridge.release_checkpoint(active.value)
	bridge.dispose()
	c.view.queue_free()
	# 天体で着地した後も、残る回数はchain_warnから新しい跳躍として進める。
	var collision := canis_move_case("pounce",{"warn":0.05,"active":0.4,"chain":2,"chain_warn":0.05,"alone_hounds":20,"overshoot":0.0,"recover":0.05},false,{},true)
	check(not collision.is_empty(),"地形付きの飛びかかりを同じ生成入口で作る")
	if collision.is_empty(): get_tree().quit(1); return
	var other = collision.bridge
	other.command("dev_boss_technique",{"entity_id":collision.id,"definition":1})
	other._core.step(0.05)
	other._core.step(0.2)
	var jump: Dictionary = other.command("dev_boss_state").value[0]
	check(jump.stage==0 and jump.left==1 and jump.stage_time==0.0 and jump.warn_time==0.05 and jump.position.x<=-230.0,"天体で早く着地し残る1回をchain_warnと新しい狙いで準備する")
	other._core.step(0.05)
	other._core.step(0.4)
	check(other.command("dev_boss_state").value[0].stage==2 and other.command("dev_boss_state").value[0].done,"最後の跳躍の着地で連続技を終える")
	other.dispose()
	collision.view.queue_free()
	# 再使用待ちは本体clockと使用時刻から、現在の形態と群れの数で引き直す。
	var cooldown := canis_move_case("pounce",{"warn":0.02,"warn_p2":0.04,"active":0.02,"lock":0.0,"recover":0.01,"cd":0.8,"cd_p2":0.4,"cd_alone":0.12,"cd_alone_p2":0.08,"chain":2,"chain_warn":0.02},true,{"phase_time":0.02,"lead_scan":0.01})
	check(not cooldown.is_empty(),"形態と群れの数を使う再使用待ちを生成する")
	if cooldown.is_empty(): get_tree().quit(1); return
	var flow_bridge = cooldown.bridge
	flow_bridge._core.step(0.01)
	var first: Dictionary = flow_bridge.command("dev_boss_state").value[0]
	for dt in [0.02,0.02,0.01,0.01,0.15]: flow_bridge._core.step(dt)
	check(flow_bridge.command("dev_boss_state").value[0].id==first.id and flow_bridge.command("dev_boss_state").value[0].stage==5,"群れが多い間は通常の再使用待ちを保つ")
	var waiting: Dictionary = flow_bridge.checkpoint()
	check(waiting.ok,"使用時刻と次の選択待ちを保持する")
	var led: Array = flow_bridge.command("dev_boss_body_state").value[0].led
	for i in 6: flow_bridge.command("dev_remove",{"entity_id":led[i].id})
	flow_bridge._core.step(0.01)
	flow_bridge._core.step(0.14)
	jump = flow_bridge.command("dev_boss_state").value[0]
	check(jump.id>first.id and jump.stage==0 and jump.left==2,"群れが少なくなると残る待ちをcd_aloneで引き直し連続跳躍を選ぶ")
	check(flow_bridge.restore(waiting.value).ok,"第1形態の再使用待ちへ復帰する")
	var body: Dictionary = flow_bridge.command("dev_boss_body_state").value[0]
	flow_bridge.command("dev_damage",{"entity_id":cooldown.id,"amount":body.max_hp*0.55,"cause":"bullet"})
	for dt in [0.01,0.02,0.15]: flow_bridge._core.step(dt)
	check(flow_bridge.command("dev_boss_state").value[0].id==first.id,"第2形態でもその形態の通常待ちの境界までは始めない")
	flow_bridge._core.step(0.15)
	jump = flow_bridge.command("dev_boss_state").value[0]
	check(jump.id>first.id and jump.definition==2 and jump.stage==0 and jump.warn_time==0.04,"前の使用時刻を保ち第2形態のcdと予告で次行動を始める")
	var second_id: int = jump.id
	for dt in [0.04,0.02,0.01,0.01,0.15]: flow_bridge._core.step(dt)
	check(flow_bridge.command("dev_boss_state").value[0].id==second_id,"第2形態の通常cdの間は選び直さない")
	led = flow_bridge.command("dev_boss_body_state").value[0].led
	for i in 6: flow_bridge.command("dev_remove",{"entity_id":led[i].id})
	flow_bridge._core.step(0.01)
	flow_bridge._core.step(0.14)
	jump = flow_bridge.command("dev_boss_state").value[0]
	check(jump.id>second_id and jump.definition==2 and jump.left==2,"第2形態でも現在の少ない群れに合わせcd_alone_p2を使う")
	flow_bridge.release_checkpoint(waiting.value)
	flow_bridge.dispose()
	cooldown.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_pounce] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 成功済みの飛びかかりを再実行せず、群れの数え直し後の再使用判定だけを確認する。
func native_canis_pounce_solo() -> void:
	var c := canis_move_case("pounce",{"warn":0.02,"warn_p2":0.04,"active":0.02,"lock":0.0,"recover":0.01,"cd":0.8,"cd_p2":0.4,"cd_alone":0.12,"cd_alone_p2":0.08,"chain":2,"chain_warn":0.02},true,{"phase_time":0.02,"lead_scan":0.01})
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.step(0.01)
	var first: Dictionary = bridge.command("dev_boss_state").value[0]
	for dt in [0.02,0.02,0.01,0.01,0.15]: bridge._core.step(dt)
	var waiting: Dictionary = bridge.checkpoint()
	var led: Array = bridge.command("dev_boss_body_state").value[0].led
	for i in 6: bridge.command("dev_remove",{"entity_id":led[i].id})
	bridge._core.step(0.01)
	print("第1形態の群れ再計数: ",bridge.command("dev_boss_body_state").value[0].led)
	bridge._core.step(0.14)
	var jump: Dictionary = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	print("第1形態の少ない群れ: clock=",body.clock," 技=",jump)
	check(jump.id>first.id and jump.stage==0 and jump.left==2 and body.clock<0.81,"群れ再計数後は通常cdより早くcd_aloneで連続跳躍を選ぶ")
	bridge.restore(waiting.value)
	body = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp*0.55,"cause":"bullet"})
	for dt in [0.01,0.02,0.15,0.15]: bridge._core.step(dt)
	var second: Dictionary = bridge.command("dev_boss_state").value[0]
	for dt in [0.04,0.02,0.01,0.01,0.15]: bridge._core.step(dt)
	led = bridge.command("dev_boss_body_state").value[0].led
	for i in 6: bridge.command("dev_remove",{"entity_id":led[i].id})
	bridge._core.step(0.01)
	print("第2形態の群れ再計数: ",bridge.command("dev_boss_body_state").value[0].led)
	bridge._core.step(0.14)
	jump = bridge.command("dev_boss_state").value[0]
	body = bridge.command("dev_boss_body_state").value[0]
	print("第2形態の少ない群れ: clock=",body.clock," 技=",jump)
	check(jump.id>second.id and jump.definition==2 and jump.stage==0 and jump.left==2 and body.clock<0.95,"第2形態も通常cdより早くcd_alone_p2で連続跳躍を選ぶ")
	bridge.release_checkpoint(waiting.value)
	bridge.dispose()
	c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_pounce_solo] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 後から登場した本体の表示時計へ、飛びかかりの光を接続する。
func native_canis_pounce_cue() -> void:
	var c := canis_move_case("pounce",{"warn":0.05,"lock":0.02})
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	bridge._core.step(0.5)
	var actor: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(-500,0),"entrance":false}).value
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":actor,"definition":1})
	bridge._core.step(0.04)
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var packet: Dictionary = bridge.read_frame().value
	var locked: Array = packet.events.filter(func(v): return v.type==&"canis_cue" and v.payload.id==actor and v.payload.cue=="aim_locked")
	if "--cpp-canis-pounce-cue-display" not in OS.get_cmdline_user_args():
		check(locked.size()==1 and is_equal_approx(locked[0].payload.world_time,0.04),"技の光の時刻を後から出た本体の時計で渡す")
	bridge.collect_frame()
	c.view.update_effects(packet,0.0)
	var display = c.view._boss_body_displays.values().filter(func(v): return v.state.actor==actor)[0]
	check(is_equal_approx(display.pulse,0.35),"狙い固定の出来事から正式な口元の星を同じ表示で光らせる")
	var state: Array = bridge.command("dev_boss_state").value.duplicate(true)
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(bridge.command("dev_boss_state").value==state,"技の光は戦闘状態を書き戻さない")
	bridge.command("dev_cancel_technique",{"ticket":started.value})
	bridge._core.step(0.4)
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(is_zero_approx(display.pulse),"本体の世界時計で技の光を消す")
	bridge.dispose()
	c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_pounce_cue] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_hydra_body() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/hydra.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	check(not package.is_empty(),"本体と首を正式Resourceから同じ型付き入力へ生成する")
	if package.is_empty(): get_tree().quit(1); return
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	if bytes.is_empty():
		for record in builder.Schema.SCHEMA.records:
			for row in package.records[record.name]:
				if not builder.Schema._valid_record(row,record): print("生成入力の不一致: ",record.name," ",row)
	check(not bytes.is_empty(),"本体・首・囲いの全項目と参照を生成する")
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":370,"mode":1,"stage_id":"B_hydra_body","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"ヒドラの種類と参照を厳密に読み込む")
	if not configured.ok: print(configured); get_tree().quit(1); return
	bridge.start(370,{"position":Vector2(1600,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge.command("dev_ship_motion",{"position":Vector2(1600,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1600,0),Vector2(1600,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.kind==3 and body.participants.size()==4 and body.participants[0].id==id and body.count==3,"本体と初期3首を別の参加者IDへ登録する")
	check(body.necks.map(func(n): return n.kind)==["bite","vortex","debris"],"正式な首の順序を維持する")
	check(body.arena.has_point(Vector2.ZERO) and body.arena.has_point(Vector2(1600,0)),"本体と機体を同じ固定外周へ囲む")
	var wall_hit: Dictionary = bridge.command("dev_field_query",{"action":"hit","from":body.arena.get_center(),"to":body.arena.end+Vector2(100,100),"radius":10.0})
	check(wall_hit.ok and wall_hit.value is Dictionary and wall_hit.value.id==0,"壁ヒットを天体番号や未命中と区別する")
	var clear_hit: Dictionary = bridge.command("dev_field_query",{"action":"hit","from":body.arena.get_center(),"to":body.arena.get_center()+Vector2(10,0),"radius":10.0})
	check(clear_hit.ok and clear_hit.value==null,"囲いの内側の未命中を維持する")
	check(bridge.command("dev_field_query",{"action":"accel","position":Vector2(20000,0)}).value==Vector2.ZERO,"戦闘外周がある間は円形外周の押し戻しを止める")
	for n: Dictionary in body.necks:
		check(is_equal_approx(n.length,float(definition.params.neck_rest)*0.3) and n.points.size()==int(definition.params.neck_segments)+1,"最初の技前の短い首と戦闘の点列を確定する")
		check(is_equal_approx(n.head_hp,float(definition.params.head_hp)*cfg.enemy_hp_mult),"本体と独立した首HPを確定する")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value) and view._boss_body_displays.size()==1,"正式な本体・首・頭・固定瓦礫を表示する")
	var display = view._boss_body_displays.values()[0]
	check(display.get_node("NeckArtwork").frame.necks.size()==3 and display.get_node("BodyArtwork").body_texture!=null and display.get_node("HeadArtwork").head_textures.size()==6,"法線付きの同じ正式素材へ点列を渡す")
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity.x>0 and body.velocity.length()<definition.speed,"加速を保ち通常移動する")
	var velocity: Vector2 = body.velocity
	var hp: float = body.hp
	for cause in ["ram","touch","wave"]:
		check(bridge.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":cause,"direction":Vector2.RIGHT,"knock":1500.0}).ok,"本体の被弾を共通戦闘へ接続する")
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity==velocity and is_equal_approx(body.hp,hp-3.0),"本体は装甲0・HPを減らし外力を受けない")
	var head_id: int = body.necks[0].id
	bridge.command("dev_damage",{"entity_id":head_id,"amount":10.0,"cause":"bullet","direction":Vector2.LEFT,"knock":1000.0})
	var target: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(target.hp==body.hp,"首のHPは本体へ暗黙転送しない")
	view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value)
	check(display.hit>0.0,"被弾の値を正式表示へ渡す")
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.apply_snapshot(bridge.read_frame().value.ui)
	check(hud._cpp_ui.boss_bodies[0].actor==id and hud._cpp_ui.boss_bodies[0].hp==target.hp,"本体ID・現在HPをHUDへ渡す")
	hud.free()
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"首のID・照準・点列と囲いを値として保持する")
	bridge._core.step(0.2)
	var after: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(bridge.restore(held.value).ok,"本体と部位の途中状態を復帰する")
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_body_state").value[0]==after,"復帰後も同じ姿勢・通常移動・点列へ進む")
	bridge.release_checkpoint(held.value)
	bridge.command("dev_kill",{"entity_id":head_id,"cause":"debug"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(not body.boss_dead and not body.participants[1].active and not body.necks[0].alive,"首の死亡で本体撃破を立てず参加者だけを閉じる")
	bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp+1.0,"cause":"bullet"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.hp<0 and body.separation_pending and not body.boss_dead,"本体致死はHPを正へ戻さず分離待ちとする")
	var before: Dictionary = body.duplicate(true)
	display.apply_frame(body)
	check(bridge.command("dev_boss_body_state").value[0]==before,"正式表示から戦闘値を書き戻さない")
	bridge.command("dev_cancel_boss",{"entity_id":id})
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value)
	check(body.participants.all(func(p): return not p.active) and not body.has("arena") and not display.visible,"中断で首・囲い・表示を終了する")
	var finished: Dictionary = bridge.checkpoint()
	check(finished.ok,"終了後の参加者寿命も整合する")
	if finished.ok: bridge.release_checkpoint(finished.value)
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"被弾と中断の通知を最後まで配信する")
	await get_tree().process_frame
	await get_tree().process_frame
	bridge.dispose()
	view.queue_free()
	await get_tree().process_frame
	print("[cpp_hydra_body] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 連射の照準固定・間隔と、取消後に残る炎を同じ制作入口で確認する。
func native_canis_sirius() -> void:
	var c := canis_move_case("sirius",{"shots":2,"warn":0.1,"lock":0.04,"lead":0.2,"aim_turn":3.0,"beam_time":0.1,"beam_length":300.0,"beam_width":20.0,"beam_particle_life":0.2,"shot_gap":0.05,"recover":0.05,"trail_delay":0.1,"trail_time":1.0})
	check(not c.is_empty(),"シリウスの全実効値を本体・炎・正式表示と同じ生成入口へ渡す")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	var observed: Array = []
	bridge.subscribe("確認",func(packet): observed.append_array(packet.events); return true)
	var records: Dictionary = c.package.records
	check(c.move.make_runner()==null and records.CanisSiriusDefinition.size()==2 and records.BossTechniqueStage.is_empty() and records.CanisFlameDefinition[0].length==300.0 and records.CanisFlameDefinition[0].particle_life==0.2,"編集値だけのResourceから連射と戦闘粒を生成する")
	bridge.command("dev_ship_motion",{"position":Vector2(300,300),"velocity":Vector2(100,0)})
	bridge._core.set_motion_context(Vector2(300,300),Vector2(300,300),Vector2(3000,2000))
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(started.ok,"制作入口でシリウスを単独発動する")
	bridge._core.step(0.065)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.stage==0 and not t.locked and is_equal_approx(t.facing,0.195) and t.aim==Vector2(320,300),"先読みと旋回を適用し固定判定は加算前の予告時刻を見る")
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	check(t.locked and is_equal_approx(t.facing,0.225),"warnからlockを引いた境界で向きを固定する")
	bridge.command("dev_ship_motion",{"position":Vector2(1000,-1000),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1000,-1000),Vector2(1000,-1000),Vector2(3000,2000))
	bridge._core.step(0.04)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and t.fired and t.shot==0 and is_equal_approx(t.facing,0.225) and canis_effects(bridge).any(func(v): return v.kind==0) and canis_effects(bridge).any(func(v): return v.kind==2),"予告を終えたtickに固定方向の噴射と焼け跡を生成する")
	var active: Dictionary = bridge.checkpoint()
	check(active.ok,"連射途中の段階・炎・乱数を保持する")
	bridge._core.step(0.1)
	t = bridge.command("dev_boss_state").value[0]
	check(t.shot==1 and t.gap_left==0.05 and t.stage==1,"1発目の終了後に独立した射撃間隔を置く")
	var after: Dictionary = t.duplicate(true)
	var flames: Array = canis_effects(bridge).duplicate(true)
	check(bridge.restore(active.value).ok,"連射途中へ復帰する")
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_state").value[0]==after and canis_effects(bridge)==flames,"復帰後も次の射撃段階と全ての粒を一致させる")
	bridge._core.step(0.05)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==0 and not t.fired and not t.locked and t.age==0.0,"間隔の終了tickは次の予告開始だけを行う")
	bridge._core.step(0.1)
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_state").value[0].stage==2 and bridge.command("dev_boss_state").value[0].shot==2,"最後の放射時間が終わると硬直へ移る")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5 and not canis_effects(bridge).is_empty(),"自然終了しても発射済みの炎と焼け跡は残る")
	bridge.restore(active.value)
	var probe := Vector2.from_angle(0.225)*160.0
	bridge.command("dev_ship_motion",{"position":probe,"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(probe,probe,Vector2(3000,2000))
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.03)
	check(bridge._core.ship_snapshot().ship_hp<hp and canis_effects(bridge).any(func(v): return v.kind==0 and v.hit),"放射した粒の接触が親の命中旗と実ダメージへつながる")
	bridge.command("dev_boss_state")
	check(observed.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause=="flame_jet" and e.payload.technique=="sirius"),"原因は炎の噴射、技はシリウスとして別々に記録する")
	bridge.restore(active.value)
	check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"放射途中を取り消す")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==7 and not canis_effects(bridge).is_empty(),"取消は連射を止め、発射済みの炎を寿命まで残す")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(not c.view._boss_body_displays.values()[0].flames.displays.is_empty(),"取消後に残る粒と焼け跡も正式表示へ渡す")
	bridge.restore(active.value)
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and canis_effects(bridge).is_empty(),"本体消失では技と残留炎をまとめて終了する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"技の出来事を共通配信へ届ける")
	bridge.release_checkpoint(active.value)
	bridge.dispose()
	c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_sirius] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 囲みの参加者・個別の噛み・本体の跳躍と解除を照合する。
func native_canis_bay() -> void:
	var c := canis_move_case("bay",{"warn":0.05,"count":4,"min_hounds":2,"pounce_at":4.0,"nip_warn":0.1,"nip_time":0.2,"nip_max":1,"back_angle":0.0,"front_angle":180.0,"nip_speed":100.0,"orbit":0.0,"max_speed":0.0,"accel":0.0,"recover":9.0},false,{"pack_size":4})
	check(not c.is_empty(),"吠え立てと依存する飛びかかりを同じ制作形式へ生成する")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	check(c.move.make_runner()==null and c.package.records.CanisBayDefinition.size()==2 and c.package.records.CanisPounceDefinition.size()==2 and c.package.records.BossTechniqueDefinition.size()==4 and is_equal_approx(c.package.records.CanisBayDefinition[0].front_angle,PI),"全編集値・形態別の跳躍・角度の単位を型付き定義へ渡す")
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(started.ok,"囲みを制作入口から単独発動する")
	var first: Dictionary = bridge.command("dev_boss_state").value[0]
	check(first.members.size()==4 and first.members.all(func(m): return m.cool>=0.6 and m.cool<=1.4 and m.warn==-1.0),"近い猟犬を選び角度・揺れ・噛み待ち・吠え待ちを個別に初期化する")
	bridge._core.step(0.05)
	bridge._core.step(1.41)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	var marked: Array = t.members.filter(func(m): return m.warn>=0.0)
	check(t.stage==1 and not t.jumping and marked.size()==1,"背後の猟犬は同時噛み数の上限まで予告する")
	check(bridge._core.hound_snapshot().follows.is_empty() and t.members.size()==4,"囲みの追従を通常隊形のfollowで上書きしない")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"囲みの参加者・個別タイマー・指示を保持する")
	bridge._core.step(0.11)
	t = bridge.command("dev_boss_state").value[0]
	check(t.members.filter(func(m): return m.nipping).size()==1 and canis_lunges(bridge).size()==1,"個別予告の期限で共通の猟犬突進を発動する")
	var after: Dictionary = t.duplicate(true)
	var lunges: Array = canis_lunges(bridge).duplicate(true)
	check(bridge.restore(held.value).ok,"囲みの予告途中へ復帰する")
	bridge._core.step(0.11)
	check(bridge.command("dev_boss_state").value[0]==after and canis_lunges(bridge)==lunges,"復帰後も個別噛みの順序・向き・期限を一致させる")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(c.view._boss_body_displays.values()[0].technique.technique=="bay" and not c.view._boss_body_displays.values()[0]._trails.is_empty(),"正式表示へ囲みの技と噛みの軌跡を渡す")
	bridge._core.step(0.21)
	t = bridge.command("dev_boss_state").value[0]
	check(t.members.any(func(m): return m.actor==marked[0].actor and not m.nipping and m.cool>0.0),"噛み終えた猟犬を個別の再使用待ちへ戻す")
	bridge.command("dev_remove",{"entity_id":t.members[0].actor})
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].members.size()==3,"参加猟犬の消失だけを囲みから除外する")
	bridge.command("dev_cancel_technique",{"ticket":started.value})
	check(bridge.command("dev_boss_state").value[0].members.is_empty() and canis_lunges(bridge).is_empty(),"取消で全参加者の囲みと噛みの指示を解除する")
	bridge.restore(held.value)
	bridge._core.step(3.0)
	t = bridge.command("dev_boss_state").value[0]
	check(t.jumping and t.stage==1 and t.jump_age==0.0,"囲みの期限で本体の飛びかかりを1回だけ始める")
	bridge._core.step(0.45)
	t = bridge.command("dev_boss_state").value[0]
	var jump = load("res://data/bosses/canis_major_moves/pounce.tres")
	check(t.stage==2 and t.jump_done and t.members.is_empty() and is_equal_approx(t.remaining,jump.recover),"飛びかかりの終了で猟犬を解除し、bayのrecoverではなくpounceの硬直を使う")
	bridge._core.step(jump.recover)
	check(bridge.command("dev_boss_state").value[0].stage==5,"硬直が終わると囲み技の完了を返す")
	bridge.restore(held.value)
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and canis_lunges(bridge).is_empty(),"本体消失では囲み技と個別噛みを取り消す")
	bridge.release_checkpoint(held.value)
	check(bridge.collect_frame().ok and bridge.delivery_error.ok,"吠え立ての出来事を共通配信へ届ける")
	bridge.dispose()
	c.view.queue_free()
	var gated := canis_move_case("bay",{"min_hounds":2},true,{"pack_size":1})
	check(not gated.is_empty(),"猟犬が不足する通常選択の入口を生成する")
	if not gated.is_empty():
		gated.bridge._core.step(0.01)
		check(gated.bridge.command("dev_boss_state").value.is_empty(),"必要な猟犬の数に足りないと共通フローで囲みを選ばない")
		gated.bridge.dispose()
		gated.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_bay] failures=",failed)
	get_tree().quit(1 if failed else 0)

func hydra_regrow_case() -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/hydra.tres").duplicate(true)
	definition.speed = 0.0
	definition.params.merge({"head_hp":10.0,"regrow":0.2,"regrow_per_head":0.1,"regrow_combo":0.25,"fire_regrow_scale":3.0,"chance_time":0.3,"growth_time":0.1,"debris_dmg":0.0},true)
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":371,"mode":1,"stage_id":"B_hydra_regrow","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"再生と成長の編集値を正式定義から生成する")
	if not configured.ok: print(configured);return {}
	bridge.start(371,{"position":Vector2(1600,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge.command("dev_ship_motion",{"position":Vector2(1600,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1600,0),Vector2(1600,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	return {"bridge":bridge,"package":package,"cfg":cfg,"id":id}


func native_hydra_regrow() -> void:
	var c := hydra_regrow_case()
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var before: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var old_id: int = before.necks[0].id
	bridge.command("dev_damage",{"entity_id":old_id,"amount":1000.0,"cause":"shot"})
	bridge.command("dev_damage",{"entity_id":before.necks[1].id,"amount":1000.0,"cause":"fire"})
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[0].alive and not body.necks[1].alive and body.necks[1].burned,"死亡hookで炎の命中を行再利用前に確定する")
	check(is_equal_approx(body.necks[0].regrow,0.4) and is_equal_approx(body.necks[1].regrow,0.6),"倒すたび全ての失った首へ猶予を延ばし炎の待ちも保つ")
	check(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value.shapes.filter(func(shape): return shape.has("debris_style")).size()==16,"首ごとの破片を同じ更新で8個ずつ生成する")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"首死亡と再生待ち・炎・死亡/生存集合を保持する")
	bridge._core.step(0.401)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].alive and body.necks[0].id!=old_id and not body.necks[1].alive,"再生で新IDを割り当て、炎の待ち中の首は復活させない")
	var after := body.duplicate(true)
	check(bridge.restore(held.value).ok,"首の再生前へ値型だけで戻す")
	bridge._core.step(0.401)
	check(bridge.command("dev_boss_body_state").value[0]==after,"途中復帰後も同じ首・ID・時計・点列になる")
	bridge.release_checkpoint(held.value)
	bridge.dispose()
	c = hydra_regrow_case();bridge = c.bridge
	before = bridge.command("dev_boss_body_state").value[0]
	for n: Dictionary in before.necks: bridge.command("dev_damage",{"entity_id":n.id,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.001)
	body = bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(body.chance_left,0.3) and body.necks.all(func(n): return not n.alive),"全滅を先に確定し、同じ更新で再生しない")
	bridge._core.step(0.2)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.necks.all(func(n): return not n.alive) and is_equal_approx(body.necks[2].regrow,0.2),"露出中は首ごとの再生時計を進めない")
	bridge._core.step(0.101)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.necks.all(func(n): return n.alive) and body.chance_left==0.0,"露出が終わった更新で全首を生やす")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value) and view._boss_body_displays.values()[0].get_node("NeckArtwork").frame.necks.all(func(n): return n.alive),"再生した新しい首だけを正式素材へ読み取り専用で表示する")
	view.queue_free();bridge.dispose()
	c = hydra_regrow_case();bridge = c.bridge
	var input: Dictionary = bridge.pack_intent(Intent.new())
	input.press = true;input.touch = true;input.pen = Vector2(1600,0)
	check(bridge._core.handle_draw(input,1000,1.0),"首の同一描線撃破を実入力で開始する")
	input.press = false;input.has_cursor = true;input.pen = Vector2(2000,0);input.pen_release = true
	check(bridge._core.handle_draw(input,1010,1.0),"同一の突進IDを確定する")
	before = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":before.necks[0].id,"amount":1000.0,"cause":"ram"})
	held = bridge.checkpoint()
	bridge.command("dev_damage",{"entity_id":before.necks[1].id,"amount":1000.0,"cause":"ram"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(body.necks[1].regrow,0.375),"同じ線で倒した2首目へ連続撃破の再生猶予を掛ける")
	after = body.duplicate(true)
	check(bridge.restore(held.value).ok,"同じ突進の撃破本数を保持する")
	bridge.command("dev_damage",{"entity_id":before.necks[1].id,"amount":1000.0,"cause":"ram"})
	check(bridge.command("dev_boss_body_state").value[0]==after,"復帰後の連続撃破も同じ再生待ちになる")
	bridge.release_checkpoint(held.value);bridge.dispose()
	c = hydra_regrow_case();bridge = c.bridge
	before = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":before.max_hp*0.7,"cause":"shot"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.count==5 and is_equal_approx(body.growth_left,0.1) and body.necks.map(func(n): return n.kind)==["bite","vortex","debris","beam","thunder"],"本体のHP閾値で5首へ作り直す")
	check(body.necks[0].id!=before.necks[0].id and body.necks.all(func(n): return n.alive),"成長前の行と世代を新しい首へ持ち越さない")
	held = bridge.checkpoint()
	check(held.ok,"成長の途中の5首と待ちを保持する")
	bridge._core.step(0.101)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.count==8 and is_equal_approx(body.growth_left,0.1) and body.necks.map(func(n): return n.kind)==["bite","vortex","debris","beam","thunder","bite","beam","vortex"],"成長明けに低HPなら連続で8首へ進む")
	after = body.duplicate(true)
	check(bridge.restore(held.value).ok,"成長前の首と参加者を同じ旧世代へ戻す")
	bridge._core.step(0.101)
	check(bridge.command("dev_boss_body_state").value[0]==after,"再成長後も同じ乱数・ID・首の順になる")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.101)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.growth_left==0.0 and body.participants.size()==9,"最後の成長が終わると本体と8首の参加者を保つ")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	bridge._core.step(0.5)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.participants.all(func(p): return not p.active) and body.necks.all(func(n): return not n.alive) and not body.has("arena"),"中断で首・囲いを終え、再生させない")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_hydra_regrow] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 初回に準備を欠いた表示条件だけを確認する。

func native_hydra_regrow_display() -> void:
	var c := hydra_regrow_case()
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var old: int = body.necks[0].id
	bridge.command("dev_damage",{"entity_id":old,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.401)
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value) and view._flame!=null and view._spark!=null and view._boss_body_displays.values()[0].get_node("NeckArtwork").frame.necks[0].id!=old,"新しい首を必要な表示資源と一緒に正式素材へ渡す")
	view.queue_free();bridge.dispose()
	await get_tree().process_frame
	print("[cpp_hydra_regrow_display] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_draco_body() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/draco.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	check(not package.is_empty(),"本体と胴の編集値を生成する")
	if package.is_empty(): get_tree().quit(1); return
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	check(not bytes.is_empty(),"ドラコの型付きレコードを書き出す")
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":146,"mode":1,"stage_id":"B_draco_body","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"本体と胴の定義をC++へ読む")
	if not configured.ok: print(configured); get_tree().quit(1); return
	bridge.start(146,{"position":Vector2(1800,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge._core.set_motion_context(Vector2(1800,0),Vector2(-900,0),Vector2(640,360))
	var spawned: Dictionary = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false})
	check(spawned.ok,"ドラコ本体と部位を生成する")
	if not spawned.ok: get_tree().quit(1); return
	var id: int = spawned.value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.kind==4 and body.participants.size()==definition.params.body_segments+1,"本体と全ての胴の参加者を保持する")
	var ids := {}
	for part: Dictionary in body.participants:
		check(not ids.has(part.id) and part.active and part.health_target==id,"部位ごとの論理IDと本体へのHP転送先を持つ")
		ids[part.id] = true
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value) and view._boss_body_displays.size()==1,"最初の技前に正式なパーツを表示する")
	var display = view._boss_body_displays.values()[0]
	check(display._parts.visible and display._parts._segments.size()>0,"胴・尾・頭の画像と法線を点列に沿って表示する")
	await get_tree().process_frame
	await get_tree().process_frame
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity==Vector2(definition.speed,0) and body.position.x>0.0,"通常移動は遅延した敵照準ではなく自機へ進む")
	var prior_velocity: Vector2 = body.velocity
	var tail_id: int = body.participants[-1].id
	for target in [id,tail_id]:
		check(bridge.command("dev_damage",{"entity_id":target,"amount":10.0,"cause":"bullet","direction":Vector2.RIGHT,"knock":1500.0}).ok,"本体と尾の被弾を共通戦闘へ渡す")
	body = bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(body.hp,body.max_hp-20.0) and is_equal_approx(body.segments[-1].hp,definition.hp) and body.velocity==prior_velocity,"胴のHPを独立に減らさず本体へ転送しノックバックしない")
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(display.hit>0.0,"部位の被弾も本体表示の白い光へ渡す")
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.apply_snapshot(bridge.read_frame().value.ui)
	check(hud._cpp_ui.boss_bodies[0].actor==id and is_equal_approx(hud._cpp_ui.boss_bodies[0].hp,body.hp),"本体IDと共有HPをHUDへ渡す")
	hud.free()
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"本体・胴・点列の途中状態を保持する")
	bridge._core.step(0.2)
	var after: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(bridge.restore(held.value).ok,"参加者IDと点列を復帰する")
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_body_state").value[0]==after,"復帰後も本体と胴が同じ位置へ進む")
	bridge.release_checkpoint(held.value)
	display.apply_frame(after)
	check(bridge.command("dev_boss_body_state").value[0]==after,"表示から戦闘の点列や位置を書き戻さない")
	bridge.command("dev_damage",{"entity_id":tail_id,"amount":1.0e8,"cause":"bullet"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.phase==2 and body.mode==2 and is_equal_approx(body.hp,body.max_hp*0.7) and not body.boss_dead,"尾への大ダメージで次の形態のHPまで減らし勝利しない")
	bridge._core.step(1.01)
	bridge.command("dev_damage",{"entity_id":id,"amount":1.0e8,"cause":"bullet"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.phase==3 and is_equal_approx(body.hp,body.max_hp*0.4) and not body.boss_dead,"第3形態も本体のHP下限を保つ")
	bridge._core.step(1.01)
	bridge.command("dev_damage",{"entity_id":id,"amount":1.0e8,"cause":"bullet"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.mode==3 and not body.boss_dead and body.participants[0].active,"最終致死は通常撃破でなく専用の決着へ渡す")
	bridge.command("dev_cancel_boss",{"entity_id":id})
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(body.participants.all(func(part):return not part.active) and not display.visible,"中断で全参加者と本体表示を閉じる")
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,360)}).ok and bridge.delivery_error.ok,"中断後も固定更新と通知の配信を終える")
	view.free()
	bridge.dispose()
	print("[B_draco_body] failures=",failed)
	get_tree().quit(1 if failed else 0)
