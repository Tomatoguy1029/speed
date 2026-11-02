## 1つのBossSystemが複数の役者を管理し、1体の削除を他へ波及させない。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
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
		flow.sections = [{"request":"normal","weights":{"single":1.0},"cap":1.0,"action_count":1,"next":0}]
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
		flow.sections = [{"request":"normal","weights":{"single":1.0},"cap":1.0,"action_count":1,"next":0}]
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
		flow.sections = [{"request":"normal","weights":{"single":1.0},"cap":1.0,"action_count":1,"next":0}]
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
