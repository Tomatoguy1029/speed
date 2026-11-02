## 1つのBossSystemが複数の役者を管理し、1体の削除を他へ波及させない。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
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
