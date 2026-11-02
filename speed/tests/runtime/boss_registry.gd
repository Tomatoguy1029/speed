## 1つのBossSystemが複数の役者を管理し、1体の削除を他へ波及させない。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
func check(ok: bool, message: String) -> void:
	if semantics_strict():return
	if "--cpp-boss-trace-stop" in OS.get_cmdline_user_args() and message!="録画停止で並行首の評価をそれぞれ閉じる": return
	if "--cpp-canis-finish-retry" in OS.get_cmdline_user_args() and (message.begins_with("全技の共通パッケージを開始する") or message.begins_with("連携の内包技も同じ24件") or message.begins_with("通常HP・低HPに対応する形態を選ぶ")): return
	if "--cpp-centaurus-combo-shower-tail" in OS.get_cmdline_user_args() and message not in ["強弓の予告が終わるとコズミックの矢を放つ","後半の強弓の姿勢と矢を正式表示へ渡す","強弓の硬直で連携を自然終了し、放った矢は残す","降り矢・強弓の戦闘とcueを同じ通知経路へ送る","前半の取消・参加者消失で降り矢を消して強弓を始めない"]: return
	if "--cpp-centaurus-sail-boundary" in OS.get_cmdline_user_args() and not message.begins_with("弧の中心") and not message.begins_with("弧の終端") and not message.begins_with("硬直が終わっても") and not message.begins_with("次の帆走") and not message.begins_with("取消で護衛"): return
	if not ok:
		failed += 1
		push_error(message)

## 数値幅が未確認の既存場面だけを判定し、成功済みの条件は再判定しない。
func semantics_strict() -> bool:
	return "--semantics-strict" in OS.get_cmdline_user_args()

var semantics_fields: Dictionary = {}
func semantics_approx(a: Variant,b: Variant,field: String) -> bool:
	var fields: PackedStringArray = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--semantics-fields="):fields=argument.trim_prefix("--semantics-fields=").split("|")
	if semantics_strict() and (fields.is_empty() or field in fields):
		var error: float = a.distance_to(b) if a is Vector2 else absf(float(a)-float(b))
		var limit: float = 1e-4 if a is Vector2 else maxf(1e-9,maxf(absf(float(a)),absf(float(b)))*1e-9)
		semantics_fields[field] = maxf(float(semantics_fields.get(field,0.0)),error)
		if not is_finite(error) or error>limit:
			failed += 1
			push_error("数値幅の不一致: %s actual=%s expected=%s error=%.16f limit=%.16f"%[field,a,b,error,limit])
	return a.is_equal_approx(b) if a is Vector2 else is_equal_approx(a,b)

func _exit_tree() -> void:
	if semantics_strict():print("SEMANTICS_FIELDS ",semantics_fields," failures=",failed)

func _ready() -> void:
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--semantics-draco="):
			call_deferred("semantics_draco_"+argument.trim_prefix("--semantics-draco="));return
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--semantics-hydra="):
			call_deferred("semantics_hydra_"+argument.trim_prefix("--semantics-hydra="));return
	if "--cpp-hydra-finish-cause" in OS.get_cmdline_user_args() or "--cpp-hydra-finish-damage" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_finish_cause")
		return
	if "--cpp-hydra-finish-pending" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_finish_pending")
		return
	if "--cpp-hydra-finish" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_finish")
		return
	if "--cpp-hydra-debris-separated" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_debris_separated")
		return
	if "--cpp-hydra-swarm" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_swarm")
		return
	if "--cpp-hydra-sequence-second" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_sequence_second")
		return
	if "--cpp-hydra-sequence" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_sequence")
		return
	if "--cpp-hydra-north-tail" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_north_tail")
		return
	if "--cpp-hydra-north" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_north")
		return
	if "--cpp-hydra-wind-resource" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_wind_resource")
		return
	if "--cpp-hydra-wind" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_wind")
		return
	if "--cpp-hydra-headbutt-loss" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_headbutt_loss")
		return
	if "--cpp-hydra-headbutt" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_headbutt")
		return
	if "--cpp-boss-trace" in OS.get_cmdline_user_args() or "--cpp-boss-trace-stop" in OS.get_cmdline_user_args():
		call_deferred("native_boss_trace")
		return
	if "--cpp-hydra-pincer" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_pincer")
		return
	if "--cpp-hydra-grid" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_grid")
		return
	if "--cpp-hydra-shatter-record" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_shatter_record")
		return
	if "--cpp-hydra-shatter" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_shatter")
		return
	if "--cpp-hydra-tornado" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_tornado")
		return
	if "--cpp-hydra-curve" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_curve")
		return
	if "--cpp-hydra-rubble-retire" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_rubble_retire")
		return
	if "--cpp-hydra-rubble-retry" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_rubble_retry")
		return
	if "--cpp-hydra-rubble" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_rubble")
		return
	if "--cpp-hydra-thunder-hit" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_thunder_hit")
		return
	if "--cpp-hydra-thunder" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_thunder")
		return
	if "--cpp-hydra-blades-origin" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_blades_origin")
		return
	if "--cpp-hydra-blades" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_blades")
		return
	if "--cpp-canis-finish-display" in OS.get_cmdline_user_args():
		call_deferred("native_canis_finish_display")
		return
	if "--cpp-canis-finish" in OS.get_cmdline_user_args():
		call_deferred("native_canis_finish")
		return
	if "--cpp-hydra-fixed-retry" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_fixed_interrupt")
		return
	if "--cpp-hydra-fixed" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_fixed")
		return
	if "--cpp-hydra-bolt" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_bolt")
		return
	if "--cpp-hydra-sweep" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_sweep")
		return
	if "--cpp-hydra-bite-hit" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_bite_hit")
		return
	if "--cpp-hydra-bite" in OS.get_cmdline_user_args() or "--cpp-hydra-bite-retry" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_bite")
		return
	if "--cpp-hydra-common" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_common")
		return
	if "--cpp-hydra-squad" in OS.get_cmdline_user_args() or "--cpp-hydra-squad-retry" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_squad")
		return
	if "--cpp-hydra-swim" in OS.get_cmdline_user_args():
		call_deferred("native_hydra_swim")
		return
	if "--cpp-canis-sirius-flame-flow" in OS.get_cmdline_user_args():
		call_deferred("native_canis_sirius_flame_flow")
		return
	if "--cpp-canis-sirius-flame" in OS.get_cmdline_user_args():
		call_deferred("native_canis_sirius_flame")
		return
	if "--cpp-canis-relay" in OS.get_cmdline_user_args():
		call_deferred("native_canis_relay")
		return
	if "--cpp-canis-nova" in OS.get_cmdline_user_args():
		call_deferred("native_canis_nova")
		return
	if "--cpp-canis-hunt-pounce" in OS.get_cmdline_user_args():
		call_deferred("native_canis_hunt_pounce")
		return
	if "--cpp-canis-hunt-residue" in OS.get_cmdline_user_args():
		call_deferred("native_canis_hunt_residue")
		return
	if "--cpp-canis-hunt" in OS.get_cmdline_user_args():
		call_deferred("native_canis_hunt")
		return
	if "--cpp-canis-stream-cancel" in OS.get_cmdline_user_args():
		call_deferred("native_canis_stream_cancel")
		return
	if "--cpp-draco-pose" in OS.get_cmdline_user_args() or "--cpp-draco-pose-contact" in OS.get_cmdline_user_args():
		call_deferred("native_draco_pose")
		return
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
	if "--cpp-canis-stream-end" in OS.get_cmdline_user_args():
		call_deferred("native_canis_stream_end")
		return
	if "--cpp-canis-stream" in OS.get_cmdline_user_args() or "--cpp-canis-stream-tail" in OS.get_cmdline_user_args():
		call_deferred("native_canis_stream")
		return
	if "--cpp-canis-blaze" in OS.get_cmdline_user_args():
		await native_canis_blaze()
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
	call_deferred("native_centaurus_body")

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
	check(body.has_guard_point and body.velocity.length()>0.0 and semantics_approx(body.velocity.length(),definition.speed,"native_centaurus_body:body.velocity.length()"),"守る雑魚の平均位置を見て通常速度で好む距離へ動く")
	var prior_velocity: Vector2 = body.velocity
	for cause in ["ram","touch","wave"]:
		check(bridge.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":cause,"direction":Vector2.RIGHT,"knock":1500.0}).ok,"被弾を登録済みの原因で本体へ渡す")
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity==prior_velocity and semantics_approx(body.hp,body.max_hp-3.0,"native_centaurus_body:body.hp"),"本体は全方向から被弾し外力のノックバックで動かない")
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
	check(semantics_approx(body.hp,body.max_hp-3.0,"native_centaurus_body:body.hp") and not body.boss_dead and body.participants[0].active,"守る雑魚の死亡は本体HPとボスの寿命を変えない")
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
	check(entrance.mode==1 and semantics_approx(entrance.position,Vector2(500,500),"native_centaurus_body:entrance.position"),"登場時間の終わりに通常待機へ戻る")
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
		if records.is_empty(): return {}
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
	check(semantics_approx(shot.pos,body.position+Vector2.from_angle(body.facing)*body.radius*definition.params.bow_reach,"native_centaurus_volley:shot.pos") and semantics_approx(shot.life,PackedFloat32Array([move.travel/move.speed])[0],"native_centaurus_volley:shot.life"),"弓口から射程÷速さの寿命で長さ0の矢を出す")
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
		if records.is_empty(): return {}
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
	check(t.hit and semantics_approx(hp-hp_after,move.damage*load("res://data/config.tres").atk_scale,"native_centaurus_rear:hp-hp_after"),"背後円と機体の移動線分の交差で倍率を1回掛けて命中する")
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
		if records.is_empty(): return {}
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
	check(semantics_approx(trace.start,Vector2(400,0),"native_centaurus_rain:trace.start") and trace.turn==1,"停止中の機体からボスと逆向きの前方へ開始し最初は正の曲がりを使う")
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
	check(semantics_approx(body.velocity.length(),definition.speed,"native_canis_body:body.velocity.length()"),"機体を向いて通常速度で追う")
	var velocity: Vector2 = body.velocity
	for cause in ["ram","touch","wave"]:
		check(bridge.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":cause,"direction":Vector2.RIGHT,"knock":1500.0}).ok,"全方向からの被弾を受ける")
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity==velocity and semantics_approx(body.hp,body.max_hp-3.0,"native_canis_body:body.hp"),"本体のHPを減らし外力のノックバックは受けない")
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
	check(entrance.barking and semantics_approx(entrance.position,Vector2(500,500),"native_canis_body:entrance.position"),"画面外から登場して吠える時間へ移る")
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
		if records.is_empty(): return {}
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
	check(not t.alerting and semantics_approx(t.facing,Vector2(300,300).angle(),"native_centaurus_power:t.facing") and bridge._core.hostiles_snapshot().is_empty(),"予告中は機体の今の位置へ即座に向き発射を待つ")
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	var origin: Vector2 = t.locked_origin
	var angle: float = t.locked_angle
	check(t.alerting and semantics_approx(angle,Vector2(300,300).angle(),"native_centaurus_power:angle") and semantics_approx(origin,Vector2.from_angle(angle)*t.radius*load("res://data/bosses/centaurus.tres").params.bow_reach,"native_centaurus_power:origin"),"warn-alertで弓口の起点と向きを固定する")
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
	check(t.stage==1 and t.released==3 and shots.size()==3 and semantics_approx(t.facing,angle,"native_centaurus_power:t.facing"),"機体が移動してもwarn時刻に固定した向きへ3本を同時発射する")
	var positions_ok := shots.size()==3
	for k in shots.size(): positions_ok = positions_ok and semantics_approx(shots[k].pos,origin,"native_centaurus_power:shots[k].pos") and semantics_approx(shots[k].vel.angle(),(Vector2.from_angle(angle+(k-1)*move.spread)*move.speed).angle(),"native_centaurus_power:shots[k].vel.angle()") and shots[k].kind==builder.Schema.ENUMS.HostileKind.CosmicArrow and semantics_approx(shots[k].life,PackedFloat32Array([move.travel/move.speed])[0],"native_centaurus_power:shots[k].life")
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
	check(semantics_approx(hp-bridge._core.ship_snapshot().ship_hp,move.damage*load("res://data/config.tres").atk_scale,"native_centaurus_power:hp-bridge._core.ship_snapshot().ship_hp"),"参加者が消えても残った強弓の矢が機体へ実ダメージを与える")
	bridge._core.step_hostiles(1.0)
	check(bridge._core.hostiles_snapshot().is_empty(),"発射済みの矢は寿命で終わる")
	bridge.dispose()
	c = centaurus_power_case(false,false)
	bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge.command("dev_ship_motion",{"position":Vector2(0,300),"velocity":Vector2.ZERO})
	bridge._core.step(0.05)
	check(semantics_approx(bridge.command("dev_boss_state").value[0].facing,0.0,"native_centaurus_power:bridge.command(\"dev_boss_state\").value[0].facing"),"追尾しない設定では予告開始時の機体位置へ旋回する")
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
		if records.is_empty(): return {}
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
	check(semantics_approx(t.center,expected,"native_centaurus_stomp:t.center"),"脚の保存配置から現在の接地点を生成する")
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
	check(t.stage==1 and not t.hit and semantics_approx(t.facing,facing,"native_centaurus_stomp:t.facing") and bridge._core.ship_snapshot().ship_hp==hp,"予告中は向きを固定し、拒否されたダメージで命中済みにしない")
	check(view.apply_frame(bridge.read_render(Rect2(-2000,-2000,4000,4000)).value) and view._boss_body_displays.values()[0]._mode()==&"strike" and view._boss_body_displays.values()[0]._parts._clip=="stomp","実行中の脚のコマと扇を表示する")
	var held: Dictionary = bridge.checkpoint()
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.01)
	var after: Dictionary = bridge.command("dev_boss_state").value[0].duplicate(true)
	var hp_after: float = bridge._core.ship_snapshot().ship_hp
	check(after.hit and semantics_approx(hp-hp_after,move.damage*load("res://data/config.tres").atk_scale,"native_centaurus_stomp:hp-hp_after"),"盾がなくなると扇で1回だけ実ダメージを受ける")
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
		check(semantics_approx(first.position,Vector2(500,4),"native_canis_lunge:first.position") and first.from==first.position,"通常敵の移動を終えた位置からボスの掃引を更新する")
		check(semantics_approx(enemy_velocity(bridge._core,target),Vector2(500,0),"native_canis_lunge:enemy_velocity(bridge._core,target)"),"並行した移動指示の後に必要な型だけ固定速度を書き戻す")
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
	check(hits.size()==2 and hits.all(func(h): return h.hit) and semantics_approx(bridge._core.ship_snapshot().ship_hp,hp-2.0*scale,"native_canis_lunge:bridge._core.ship_snapshot().ship_hp"),"複数の猟犬が同時に触れても行動全体で1回だけ当てる")
	bridge.command("dev_hound_order",{"entity_id":target,"action":"quiet","until":10.0,"velocity":Vector2(0,40)})
	bridge._core.step(0.01)
	check(semantics_approx(enemy_velocity(bridge._core,target),Vector2(0,40),"native_canis_lunge:enemy_velocity(bridge._core,target)"),"号令用の型は毎tickの固定速度上書きを行わない")
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
		if records.is_empty(): return {}
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
	check(t.stage==1 and t.released==1 and shots.size()==3 and semantics_approx(t.facing,0.0,"native_centaurus_fan:t.facing"),"追跡しない予告は本体の向きを保ちwarnで最初の3本を射る")
	var aim: Vector2 = Vector2(300,0)
	# Source EnemyMotion._update_aim と同じ二更新を、同じVector2演算順で進める。
	var aim_config = load("res://data/config.tres")
	for _tick in 2:
		var toward: Vector2 = Vector2(1400,1400)-aim
		var distance: float = toward.length()
		aim += toward/distance*minf(distance*(1.0-exp(-0.05/aim_config.enemy_aim_lag)),aim_config.enemy_aim_speed*0.05)
	var expected: float = (aim-shots[1].pos).angle() if shots.size()==3 else 0.0
	var angles_ok := shots.size()==3
	for k in shots.size(): angles_ok = angles_ok and semantics_approx(shots[k].vel.angle(),(Vector2.from_angle(expected+(k-1)*deg_to_rad(move.spread)*0.5)*move.speed).angle(),"native_centaurus_fan:shots[k].vel.angle()") and semantics_approx(shots[k].life,PackedFloat32Array([move.travel/move.speed])[0],"native_centaurus_fan:shots[k].life") and semantics_approx(shots[k].length,move.length,"native_centaurus_fan:shots[k].length")
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
	check(bridge.command("dev_boss_state").value[0].stage==7 and semantics_approx(hp-bridge._core.ship_snapshot().ship_hp,move.damage*load("res://data/config.tres").atk_scale,"native_centaurus_fan:hp-bridge._core.ship_snapshot().ship_hp"),"取消と参加者消失でも発射済みの矢は残り倍率を1回掛けて命中する")
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
	var aim: Vector2 = Vector2(300,0)
	# Source EnemyMotion._update_aim と同じ二更新を、同じVector2演算順で進める。
	var aim_config = load("res://data/config.tres")
	for _tick in 2:
		var toward: Vector2 = Vector2(1400,1400)-aim
		var distance: float = toward.length()
		aim += toward/distance*minf(distance*(1.0-exp(-0.05/aim_config.enemy_aim_lag)),aim_config.enemy_aim_speed*0.05)
	var expected: float = (aim-shots[1].pos).angle() if shots.size()==3 else 0.0
	var angles_ok := shots.size()==3 and semantics_approx(t.facing,0.0,"native_centaurus_fan_aim:t.facing")
	var move = load("res://data/bosses/centaurus_moves/fan_volley.tres")
	for k in shots.size(): angles_ok = angles_ok and semantics_approx(shots[k].vel.angle(),(Vector2.from_angle(expected+(k-1)*deg_to_rad(move.spread)*0.5)*move.speed).angle(),"native_centaurus_fan_aim:shots[k].vel.angle()") and semantics_approx(shots[k].life,PackedFloat32Array([move.travel/move.speed])[0],"native_centaurus_fan_aim:shots[k].life") and semantics_approx(shots[k].length,move.length,"native_centaurus_fan_aim:shots[k].length")
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
	check(t.stage==1 and t.shower.marks.size()==1 and t.shower.placed==1 and semantics_approx(t.shower.marks[0].center,Vector2(550,0),"native_centaurus_shower:t.shower.marks[0].center") and t.shower.marks[0].shown and not t.shower.marks[0].landed,"warnで今の位置と速度から予測した円を1つ置く")
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
	check(t.shower.marks[0].landed and semantics_approx(hp-hp_after,load("res://data/bosses/centaurus_moves/shower_chase.tres").damage*load("res://data/config.tres").atk_scale,"native_centaurus_shower:hp-hp_after"),"着弾の瞬間だけ今の機体位置を円で判定して倍率を1回掛ける")
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
	check(marks.size()==3 and semantics_approx(marks[1].center,Vector2(225,0),"native_centaurus_shower:marks[1].center") and semantics_approx(marks[0].at,0.2,"native_centaurus_shower:marks[0].at") and semantics_approx(marks[1].at,0.1,"native_centaurus_shower:marks[1].at") and semantics_approx(marks[2].at,0.2,"native_centaurus_shower:marks[2].at") and not marks[0].shown and marks[1].shown,"壁は距離割合と上下限で中心を決め、中央から外へ予告する")
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
	check(marks.size()==3 and semantics_approx(marks[1].center,Vector2(760,0),"native_centaurus_shower:marks[1].center") and semantics_approx(float(marks[2].at)-float(marks[0].at),0.2,"native_centaurus_shower:float(marks[2].at)-float(marks[0].at)"),"横切りは機体の進む向きの先を塞ぎ、端から順番に円を置く")
	var first_center: Vector2 = marks[0].center
	bridge._core.step(0.5)
	bridge._core.step(0.05)
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.1)
	marks = bridge.command("dev_boss_state").value[0].shower.marks
	check(marks.size()==3 and semantics_approx(marks[2].center,first_center,"native_centaurus_shower:marks[2].center"),"横切りの配置は次の技で左右を反転する")
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.3)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_state").value[0].shower.marks.is_empty(),"参加者消失で横切りの未着弾を止める")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_centaurus_shower] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 共通の本体・表示と、指定した1技を既存ボス検査へつなぐ。
func canis_move_case(name: String, changes: Dictionary, flowing := false, body_changes := {}, obstacle := false, start_delay := 0.0, dependency_changes := {}) -> Dictionary:
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
	for table: String in package.records:
		for row: Dictionary in package.records[table]:
			var technique: Dictionary = package.records.BossTechniqueDefinition[int(row.technique)-1] if row.has("technique") else row if table=="BossTechniqueDefinition" else {}
			if technique.is_empty() or not dependency_changes.has(technique.external_id): continue
			for key: String in dependency_changes[technique.external_id]:
				if row.has(key): row[key] = dependency_changes[technique.external_id][key]
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
		if records.is_empty(): return {}
		for key in records: package.records[key] = records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":159,"mode":1,"stage_id":"B_canis_major_"+name,"profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(159,{"position":Vector2(2000,0)})
	bridge.command("dev_ship_motion",{"position":Vector2(2000,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(2000,0),Vector2(2000,0),Vector2(3000,2000))
	if start_delay>0.0: bridge._core.step(start_delay)
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
	check(t.hit and canis_lunges(bridge).all(func(v): return v.hit) and semantics_approx(hp-bridge._core.ship_snapshot().ship_hp,move.damage*load("res://data/config.tres").atk_scale,"native_canis_command:hp-bridge._core.ship_snapshot().ship_hp"),"猟犬の点と機体の移動線分から技全体で1回だけダメージを与える")
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
	check(semantics_approx(body.ring_radius,300.0,"native_canis_howl:body.ring_radius") and body.ring_started>=0.0,"形成時は開始半径で自機の位置を中心にする")
	var formed: Dictionary = body.duplicate(true)
	var order: Array = t.sequence.duplicate(true)
	check(bridge.restore(before.value).ok,"形成前の乱数と状態へ復帰する")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_body_state").value[0]==formed and bridge.command("dev_boss_state").value[0].sequence==order,"復帰後も輪のずれ・薄い所・召喚・発進順が一致する")
	var ring_ids: Array = body.ring.map(func(v): return v.id)
	var base_angles: Array = body.ring.map(func(v): return v.angle)
	check(base_angles.all(func(a): return a>=base_angles[0]) and base_angles.any(func(a): return is_equal_approx((a-base_angles[0])/TAU*14.0,7.0)),"空ける2箇所を含む14等分の位置へ配置する")
	if semantics_strict():
		var opposite := INF
		for angle: float in base_angles:
			var slot: float = (angle-base_angles[0])/TAU*14.0
			if absf(slot-7.0)<absf(opposite-7.0):opposite=slot
		semantics_approx(opposite,7.0,"native_canis_howl:opposite_slot")
	var center: Vector2 = formed.ring_center
	bridge.command("dev_ship_motion",{"position":center+Vector2(100,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(center+Vector2(100,0),center+Vector2(100,0),Vector2(3000,2000))
	bridge._core.step(0.05)
	body = bridge.command("dev_boss_body_state").value[0]
	check(semantics_approx(body.ring_center,center+Vector2(100,0)*(1.0-exp(-4.0*0.05)),"native_canis_howl:body.ring_center") and semantics_approx(body.ring_radius,300.0,"native_canis_howl:body.ring_radius"),"gather_timeの間は半径を保ち世界時計で中心を指数追従する")
	var ring_saved: Dictionary = bridge.checkpoint()
	check(ring_saved.ok,"輪の中心・個体世代・次の予告時刻を保持する")
	bridge._core.step(0.05)
	body = bridge.command("dev_boss_body_state").value[0]
	check(semantics_approx(body.ring_radius,250.0,"native_canis_howl:body.ring_radius"),"gather_time後はclose_timeの間に半径を線形で狭める")
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
	check(canis_lunges(bridge).any(func(v): return v.actor==target and v.hit) and semantics_approx(hp-bridge._core.ship_snapshot().ship_hp,move.damage*load("res://data/config.tres").atk_scale,"native_canis_howl:hp-bridge._core.ship_snapshot().ship_hp"),"猟犬の移動線分と機体から個体ごとに1回だけ実ダメージを出す")
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
	check(t.stage==1 and t.released==1 and t.boosted and t.side==1 and t.orbit_radius==300.0 and semantics_approx(t.position,Vector2.ZERO,"native_centaurus_sail:start"),"弧の中心・半径・交互の向きを保持して予告後に走り始める")
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
	check(t.stage==2 and t.released==3 and not t.boosted and semantics_approx(t.position,Vector2(300,-300),"native_centaurus_sail:t.position") and shots.size()==3,"弧の終端まで差分移動し時間内の3射だけ出して護衛の強化を解除する")
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
	check(t.combo_waiting and t.stage==2 and semantics_approx(t.remaining,0.05,"native_centaurus_combo_rain:t.remaining") and t.rain.traces.is_empty(),"前半の硬直10秒を使わず、雨を閉じて世界時間のgapへ移る")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.03)
	check(bridge.command("dev_boss_state").value[0].combo_waiting and bridge._core.hostiles_snapshot().is_empty(),"gapが残る間は後半を始めない")
	bridge._core.step(0.03)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	check(t.technique=="volley" and t.combo_step==1 and t.stage==0 and semantics_approx(t.elapsed,0.0,"native_centaurus_combo_rain:t.elapsed") and t.id==1,"次の更新で同じ技チケットのまま速射の予告を始める")
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
	check(t.combo_waiting and t.shower.marks.is_empty() and semantics_approx(t.remaining,0.05,"native_centaurus_combo_shower:t.remaining"),"降り矢の表示と攻撃を閉じ、前半の硬直を挟まずgapへ進む")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.051)
	t = bridge.command("dev_boss_state").value[0]
	var after: Dictionary = t.duplicate(true)
	check(t.technique=="power_shot" and t.combo_step==1 and t.stage==0 and semantics_approx(t.elapsed,0.0,"native_centaurus_combo_shower:t.elapsed"),"次の更新で強弓自身の予告を始める")
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
func centaurus_finish_case(limit := -1.0, automatic := false, parameters := {}, idle_only := false) -> Dictionary:
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
	stage.boss_enabled = false
	stage.time_limit = limit
	stage.legendary_module_id = ContentManager.stage(2).legendary_module_id
	var options := {}
	if idle_only:
		# 数値の確認前に通常技を始めない。前方では選ばれない背後技だけを抽選候補にする。
		var flow = load("res://data/bosses/ai/centaurus_flow.tres").duplicate(true)
		flow.sections = [{"request":"any","allowed_techniques":["rear_attack"],"cap":3.0,"action_count":1,"next":0,"weights":{"single":1.0,"combo":1.0,"major":1.0}}]
		options["flow"]=flow
		options["rules"]=load("res://data/bosses/ai/centaurus_action_rules.tres")
	var package: Dictionary = builder.boss_package(boss,cfg,stage,options)
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
	if semantics_strict():
		semantics_centaurus_finish();return
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
	check(t.technique=="stomp" and t.stage==0 and semantics_approx(t.elapsed,0.0,"native_centaurus_finish:t.elapsed") and bridge.command("dev_boss_flow_state").value[0].stamina==load("res://data/bosses/ai/centaurus_flow.tres").maximum_stamina,"踏みつけを抽選より優先し、開始した更新のdtやスタミナを使わない")
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
	check(t.technique=="shower_path" and t.stage==0 and semantics_approx(bridge.command("dev_boss_body_state").value[0].path_hold,0.0,"native_centaurus_finish:bridge.command(\"dev_boss_body_state\").value[0].path_hold"),"横切りが続くと制作の条件からshower_pathを自動開始して保持時間を戻す")
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
	check(body.leaping and semantics_approx(body.leap_to,Vector2(-320,0),"native_centaurus_finish:body.leap_to") and bridge.command("dev_boss_state").value.is_empty(),"近づいた機体から離れる跳躍を最初の優先順位で始める")
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
	check(not bridge.command("dev_boss_body_state").value[0].leaping and t.technique=="shower_wall" and t.stage==0 and semantics_approx(t.elapsed,0.0,"native_centaurus_finish:t.elapsed"),"着地でshower_wallを始め、同じ更新のdtを予告へ使わない")
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
	check(centaurus_finish_steps(bridge,1) and bridge.read_frame().value.ui.phase==RunIds.Phase.Finishing and bridge.read_frame().value.result==null,"第1形態の実撃破から報酬未確定の決着へ進む")
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
	check(t.left==1 and semantics_approx(t.aim,Vector2(320,0),"native_canis_pounce:t.aim") and not t.locked,"群れが多いと1回だけ跳び残り予告とlead_extraで先読みする")
	bridge._core.step(0.04)
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var display = c.view._boss_body_displays.values()[0]
	check(display.technique.technique=="pounce" and is_equal_approx(display.technique.crouch,0.4) and is_equal_approx(display.parts.scale.x/display.parts.scale.y,1.06/0.94),"正式パーツへ溜めの縮みと着地点の予告を渡す")
	bridge._core.step(0.021)
	t = bridge.command("dev_boss_state").value[0]
	check(t.locked and semantics_approx(t.aim,Vector2(356,0),"native_canis_pounce:t.aim") and semantics_approx(t.direction,Vector2.RIGHT,"native_canis_pounce:t.direction"),"lock時点の先読みにovershootを足して固定する")
	bridge.command("dev_ship_motion",{"position":Vector2(800,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(800,0),Vector2(800,0),Vector2(3000,2000))
	bridge._core.step(0.04)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and t.jumping and t.position==Vector2.ZERO and semantics_approx(t.aim,Vector2(356,0),"native_canis_pounce:t.aim"),"warnで発進しそのtickは動かず固定した着地点を維持する")
	var active: Dictionary = bridge.checkpoint()
	check(active.ok,"発進した本体の狙い・段階・命中旗を保持する")
	bridge.command("dev_ship_motion",{"position":Vector2(178,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(178,0),Vector2(178,0),Vector2(3000,2000))
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.05)
	t = bridge.command("dev_boss_state").value[0]
	var hp_after: float = bridge._core.ship_snapshot().ship_hp
	check(semantics_approx(t.position,Vector2(89,0),"native_canis_pounce:t.position") and t.hit and semantics_approx(hp-hp_after,move.damage*load("res://data/config.tres").atk_scale,"native_canis_pounce:hp-hp_after"),"残り時間で移動し本体の掃引と機体線分から1回だけ実ダメージを出す")
	var after: Dictionary = t.duplicate(true)
	check(bridge.restore(active.value).ok,"飛びかかりの発進時点へ復帰する")
	bridge.command("dev_ship_motion",{"position":Vector2(178,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(178,0),Vector2(178,0),Vector2(3000,2000))
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0]==after and bridge._core.ship_snapshot().ship_hp==hp_after,"復帰後も位置・速度・命中結果を同じにする")
	bridge._core.step(0.15)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==2 and t.done and t.left==0 and semantics_approx(t.position,Vector2(356,0),"native_canis_pounce:t.position") and bridge._core.ship_snapshot().ship_hp==hp_after,"activeの終わりで着地し再命中せず硬直へ移る")
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
		check(locked.size()==1 and semantics_approx(locked[0].payload.world_time,0.04,"native_canis_pounce_cue:locked[0].payload.world_time"),"技の光の時刻を後から出た本体の時計で渡す")
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
	check(t.stage==0 and not t.locked and semantics_approx(t.facing,0.195,"native_canis_sirius:t.facing") and t.aim==Vector2(320,300),"先読みと旋回を適用し固定判定は加算前の予告時刻を見る")
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	check(t.locked and semantics_approx(t.facing,0.225,"native_canis_sirius:t.facing"),"warnからlockを引いた境界で向きを固定する")
	bridge.command("dev_ship_motion",{"position":Vector2(1000,-1000),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1000,-1000),Vector2(1000,-1000),Vector2(3000,2000))
	bridge._core.step(0.04)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and t.fired and t.shot==0 and semantics_approx(t.facing,0.225,"native_canis_sirius:t.facing") and canis_effects(bridge).any(func(v): return v.kind==0) and canis_effects(bridge).any(func(v): return v.kind==2),"予告を終えたtickに固定方向の噴射と焼け跡を生成する")
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
	check(t.stage==2 and t.jump_done and t.members.is_empty() and semantics_approx(t.remaining,jump.recover,"native_canis_bay:t.remaining"),"飛びかかりの終了で猟犬を解除し、bayのrecoverではなくpounceの硬直を使う")
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

func hydra_regrow_case(flowing := false, squad_changes := {}, move_changes := {}, selected_move := "bite_thrust", config_changes := {}) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	for key in config_changes: cfg.set(key,config_changes[key])
	var definition = load("res://data/bosses/hydra.tres").duplicate(true)
	definition.speed = 0.0
	definition.params.squad.merge(squad_changes,true)
	definition.params.merge({"head_hp":10.0,"regrow":0.2,"regrow_per_head":0.1,"regrow_combo":0.25,"fire_regrow_scale":3.0,"chance_time":0.3,"growth_time":0.1,"debris_dmg":0.0},true)
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	if not move_changes.is_empty():
		var move = load("res://data/bosses/hydra_moves/%s.tres" % selected_move).duplicate(true)
		move.assign_values(move_changes)
		package = builder.hydra_technique_package(definition,move,cfg)

	if flowing:
		var rules = load("res://data/bosses/ai/hydra_action_rules.tres").duplicate(true)
		rules.techniques.assign([load("res://data/bosses/hydra_moves/%s.tres" % selected_move).duplicate(true)])
		rules.combos = {};rules.conditions = {selected_move:{}};rules.condition_groups = {};rules.graph_nodes = {};rules.selection_bias = {}
		var flow = load("res://data/bosses/ai/hydra_flow.tres").duplicate(true)
		flow.sections = flow.sections.slice(0,2)
		flow.sections[0].next = 1;flow.sections[1].next = 0
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		check(not records.is_empty(),"保存済みのrulesとflowの深いコピーを対応済み通常技だけの制作構成へ限定する")
		if records.is_empty(): return {}
		var template_action: Dictionary = records.BossFlowAction[0].duplicate(true)
		var template_node: Dictionary = records.BossFlowNode[template_action.node-1].duplicate(true)
		records.BossFlowAction.clear();records.BossFlowNode.clear()
		for index in 8:
			var node: Dictionary = template_node.duplicate(true);node.id=index+1;node.participant=index+1
			var action: Dictionary = template_action.duplicate(true);action.id=index+1;action.node=index+1;action.exclusive=false
			records.BossFlowNode.append(node);records.BossFlowAction.append(action)
		for key in records: package.records[key] = records[key]
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

## 点火後の猟犬を技と別の寿命で更新し、爆発・解除・表示まで照合する。
func native_canis_blaze() -> void:
	var c := canis_move_case("blaze",{"warn":0.3,"count":2,"min_hounds":2,"ignite_at":0.2,"ignite_step":0.1,"run_speed":40.0,"stop_dist":120.0,"max_run":0.5,"blink":0.2,"explode_radius":100.0,"damage":7.0,"recover":0.05},false,{"pack_size":4,"lead_scan":0.01})
	check(not c.is_empty(),"燃える猟犬の全編集値と炎の表示資源を生成する")
	if c.is_empty(): get_tree().quit(1); return
	var bridge = c.bridge
	var observed: Array = []
	bridge.subscribe("記録確認",func(packet): observed.append_array(packet.events); return true)
	check(c.move.make_runner()==null and c.package.records.CanisBlazeDefinition.size()==2 and c.package.records.CanisBlazeDefinition[0].turn_fast==load("res://data/bosses/canis_major_moves/bay.tres").turn_fast and c.package.records.CanisFlameDefinition[4].duration==0.1,"編集Resourceを分け、Bayから借りる操舵と点火間隔も生成する")
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(started.ok,"制作入口から燃える猟犬だけを発動する")
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.chosen.size()==2 and t.chosen[0].at==0.2 and semantics_approx(t.chosen[1].at,0.3,"native_canis_blaze:t.chosen[1].at"),"近い猟犬に順番ごとの点火時刻を割り当てる")
	bridge._core.step(0.1)
	t = bridge.command("dev_boss_state").value[0]
	check(t.chosen[0].sent and not t.chosen[0].lit and not t.chosen[1].sent,"点火の1間隔前にだけ口元からの火の移送を始める")
	var pending: Dictionary = bridge.checkpoint()
	bridge._core.step(0.11)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.burning.size()==1 and body.led.size()==3 and body.burning[0].age==0.11,"点火した猟犬を隊形から外し同じtickの炎更新で走行時計を進める")
	var burning: Dictionary = body.burning[0]
	var cfg = load("res://data/config.tres")
	check(semantics_approx(burning.max_hp,cfg.base_attack*cfg.atk_scale*0.5,"native_canis_blaze:burning.max_hp"),"点火した猟犬の最大HPを体当たり基準の半分へ変える")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var display = c.view._boss_body_displays.values()[0]
	check(display.flames.displays.has("猟犬:%d" % burning.actor) and display.flames.displays.has("口元の点火"),"正式表示へ猟犬の炎と点火中の口元を渡す")
	var active: Dictionary = bridge.checkpoint()
	check(active.ok,"点火済みの猟犬・元のHP・個別時計を保持する")
	bridge._core.step(0.1)
	var after: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(after.burning.size()==2 and after.led.size()==2 and bridge.command("dev_boss_state").value[0].stage==2,"2体目の点火で技は硬直へ移り燃える猟犬は本体側へ残す")
	check(bridge.restore(active.value).ok,"点火途中へ復帰する")
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_body_state").value[0]==after,"復帰後も点火順・隊形からの除外・走行を一致させる")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5 and bridge.command("dev_boss_body_state").value[0].burning.size()==2,"技の自然終了後も点火済みの猟犬は残る")
	bridge.restore(active.value)
	bridge.command("dev_cancel_technique",{"ticket":started.value})
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].burning.size()==1,"取消は未点火の予定だけを止め点火済みの猟犬を残す")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	var restored: Array = bridge.read_lab().value.enemies.filter(func(e): return e.id==burning.actor)
	check(bridge.command("dev_boss_body_state").value[0].burning.is_empty() and restored.size()==1 and semantics_approx(restored[0].max_hp,burning.base_hp,"native_canis_blaze:restored[0].max_hp"),"本体の終了で点火を解除し元の最大HPへ戻す")
	bridge.restore(active.value)
	bridge.command("dev_cancel_technique",{"ticket":started.value})
	bridge.command("dev_relocate",{"entity_id":burning.actor,"position":Vector2(2000,0)})
	bridge._core.step(0.01)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.burning.size()==1 and semantics_approx(body.burning[0].blink_age,0.01,"native_canis_blaze:body.burning[0].blink_age"),"機体の近くで明滅を始め同じtickから明滅時計を進める")
	var blinking: Dictionary = bridge.checkpoint()
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.2)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.burning.is_empty() and semantics_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*cfg.atk_scale,"native_canis_blaze:hp-bridge._core.ship_snapshot().ship_hp"),"明滅の期限に円判定で1回ダメージを与え猟犬自身を死亡させる")
	check(observed.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause=="blaze" and e.payload.technique=="blaze"),"爆発の原因と発動元の技を共通記録へ渡す")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	c.view.update_effects(bridge.read_frame().value,0.0)
	display = c.view._boss_body_displays.values()[0]
	display.apply_frame(body,{})
	check(not display.flames.bursts.is_empty() and display.flames.displays.keys().any(func(k): return str(k).begins_with("爆発:")),"猟犬が死亡した後も爆発の炎は表示寿命まで残す")
	check(bridge.restore(blinking.value).ok,"明滅途中へ復帰する")
	bridge.command("dev_remove",{"entity_id":burning.actor})
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_body_state").value[0].burning.is_empty() and not bridge.command("dev_boss_body_state").value[0].boss_dead,"燃える猟犬だけの消失では爆発も本体死亡も起こさない")
	bridge.restore(active.value)
	bridge.command("dev_cancel_technique",{"ticket":started.value})
	bridge._core.step(0.4)
	check(bridge.command("dev_boss_body_state").value[0].burning.is_empty(),"走行時間の上限からも明滅と爆発へ進む")
	bridge.restore(pending.value)
	bridge.command("dev_remove",{"entity_id":t.chosen[0].actor})
	bridge._core.step(0.11)
	check(bridge.command("dev_boss_body_state").value[0].burning.is_empty(),"未点火の参加者が消失したときは点火しない")
	for held in [pending,active,blinking]: bridge.release_checkpoint(held.value)
	check(bridge.collect_frame().ok and bridge.delivery_error.ok,"点火・明滅・爆発と表示用通知を同じ共通配信へ渡す")
	bridge.dispose()
	c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_blaze] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_draco_pose() -> void:
	var form = load("res://scripts/bosses/draco_form.gd")
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/draco.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	check(bridge.configure(bytes,{"api_version":1,"run_id":151,"mode":1,"stage_id":"B_draco_pose","profile":{},"settings":{"hitstop":false}}).ok,"姿勢と寸法の編集値をC++へ読む")
	bridge.start(151,{"position":Vector2(500,0)})
	bridge.subscribe("確認",func(_frame): return true)
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	if "--cpp-draco-pose-contact" in OS.get_cmdline_user_args():
		native_draco_pose_contact(bridge,id)
		bridge.dispose()
		print("[B_draco_pose_contact] failures=",failed)
		get_tree().quit(1 if failed else 0)
		return
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var neutral := PackedVector2Array([Vector2.ZERO])
	for j in int(definition.params.body_segments):
		var t := float(j+1)/float(definition.params.body_segments)
		neutral.append(Vector2(-t*float(definition.params.body_length),sin(t*TAU*1.25)*float(definition.params.body_wave)*sin(t*PI*0.8)))
	var original_length: float = form.length(neutral)
	for j in neutral.size(): neutral[j] *= float(definition.params.body_length)/original_length
	var same: bool = body.body_points.size()==neutral.size()
	for j in neutral.size(): same = same and body.body_points[j].distance_to(neutral[j])<0.002
	check(same,"最初の姿勢は既存と同じ波と長さの点列を使う")
	var base_radius: float = body.radius
	check(is_equal_approx(base_radius,definition.radius*float(definition.params.head_scale)),"頭の半径にキャラクター倍率を重ねない")
	for depth in [0.25,0.1,1.0]:
		check(bridge.command("dev_draco_pose",{"entity_id":id,"operation":"depth","depth":depth,"alpha":0.4}).ok,"深度と透明度を適用する")
		body = bridge.command("dev_boss_body_state").value[0]
		check(is_equal_approx(body.radius,base_radius*depth) and is_equal_approx(body.alpha,0.4),"深度は頭の命中半径と表示の両方へ同じ倍率を渡す")
		for j in body.segments.size():
			var fraction := float(j+1)/float(body.segments.size())
			check(body.segments[j].position.distance_to(form.sample(body.body_points,fraction))<0.002 and is_equal_approx(body.segments[j].radius,float(definition.params.body_width)*0.5*form.taper(fraction)*depth),"描画と部位は同じ距離分率と尾の太さを使う")
	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"reset"})
	var override := PackedVector2Array([Vector2.ZERO,Vector2(80,0),Vector2(80,500),Vector2(900,500)])
	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"override","points":override})
	body = bridge.command("dev_boss_body_state").value[0]
	for j in body.segments.size():
		check(body.segments[j].position.distance_to(form.sample(override,float(j+1)/float(body.segments.size())))<0.002,"違う点数の姿勢でも部位を距離で配置する")
	var along: float = form.fractions(override)[-2]
	var middle: Vector2 = override[-2].lerp(override[-1],0.5)
	var half_width: float = float(definition.params.body_width)*0.5*form.taper(lerpf(along,1.0,0.5))
	check(bridge.command("dev_draco_pose",{"entity_id":id,"operation":"contains","point":middle+Vector2(0,half_width+3.9),"radius":4.0}).value,"尾の節の間も半径を足して命中する")
	check(not bridge.command("dev_draco_pose",{"entity_id":id,"operation":"contains","point":middle+Vector2(0,half_width+4.1),"radius":4.0}).value,"尾の実半径を外れた点は命中しない")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"上書き点列を値として保持する")
	bridge._core.step(0.1)
	var after: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(bridge.restore(held.value).ok,"上書き点列と深度を復帰する")
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_body_state").value[0]==after,"復帰後の姿勢と尾の位置が一致する")
	bridge.release_checkpoint(held.value)
	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"depth","depth":0.25,"alpha":0.4})
	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"reset"})
	body = bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(body.perspective_scale,1.0) and is_equal_approx(body.alpha,1.0) and is_equal_approx(body.radius,base_radius),"取消で深度・透明度・頭の寸法を戻す")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value),"姿勢を正式表示へ渡す")
	var display = view._boss_body_displays.values()[0]
	check(display.scale==Vector2.ONE and display.state.body_points==body.body_points,"表示は点列の深度に別の倍率を重ねない")
	await get_tree().process_frame
	await get_tree().process_frame
	var tail: Vector2 = (body.segments[-1].position+body.segments[-2].position)*0.5
	var normal: Vector2 = (body.segments[-1].position-body.segments[-2].position).normalized().orthogonal()
	var before_hp: float = body.hp
	bridge._core.rebuild_enemy_grid(128.0)
	check(bridge.command("dev_emit_attack",{"pool":0,"position":tail-normal*90.0,"velocity":normal*450.0,"life":2.0,"damage":50.0,"radius":4.0}).ok,"最小の味方弾を生成する")
	bridge._core.step_projectiles(0.4)
	check(bridge.command("dev_boss_body_state").value[0].hp<before_hp,"本番の広域検索を通った半径4の味方弾が尾の節の間へ命中する")
	native_draco_pose_contact(bridge,id)
	bridge.command("dev_cancel_boss",{"entity_id":id})
	view.free()
	bridge.dispose()
	print("[B_draco_pose] failures=",failed)
	get_tree().quit(1 if failed else 0)


func native_draco_pose_contact(bridge, id: int) -> void:
	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"override","points":PackedVector2Array([Vector2.ZERO,Vector2(-500,0)])})
	bridge._core.rebuild_enemy_grid(128.0)
	bridge.command("dev_ship_motion",{"position":Vector2(-700,0),"velocity":Vector2(600,0)})
	bridge.collect_frame()
	check(bridge._core.handle_draw({"has_cursor":true,"pen":Vector2(-700,0),"press":true},0,1.0),"尾から頭への描線を開始する")
	check(bridge._core.handle_draw({"has_cursor":true,"pen":Vector2(200,0),"press":true},1000,1.0) and bridge._core.draw_snapshot().tracing,"尾から頭へ通る描線を確定する")
	for frame in 20: bridge._core.step_draw(0.04)
	var damage_events: Array = bridge.read_frame().value.events.filter(func(event):return event.type==&"combat_damage" and event.payload.get("cause")==&"ram" and event.payload.get("target_id")==id and float(event.payload.get("applied",0.0))>0.0)
	check(damage_events.size()==1,"胴から頭まで同じ描線で通っても全身から離れるまでは一度だけ当たる")
	get_tree().quit(1 if failed else 0)

func native_canis_stream() -> void:
	var tail_only := "--cpp-canis-stream-tail" in OS.get_cmdline_user_args()
	var builder = load("res://tools/content/build_run_content.gd")
	var move = load("res://data/bosses/canis_major_moves/stream.tres")
	var rows: Dictionary = builder.boss_technique_records(load("res://data/bosses/canis_major.tres"),move)
	if not tail_only:
		check(move.make_runner()==null and rows.CanisStreamDefinition.size()==2 and rows.CanisStreamDefinition[1].lunge_speed==move.lunge_speed_p2 and rows.BossTechniqueDefinition[1].cd==move.cd_p2 and rows.BossTechniqueStage.is_empty(),"順番の号令の編集値・2形態・手動段階を型付き入力へ生成する")
	var values := {"warn":0.1,"interval":0.05,"each_warn":0.02,"lunge_speed":200.0,"lunge_speed_p2":200.0,"lunge_time":0.08,"recover":0.04,"min_hounds":1}
	var c := canis_move_case("stream",values,false,{"pack_size":3,"lead_max":3},false,0.5)
	if not tail_only:
		check(not c.is_empty(),"世界の途中で出現した本体から単独の技を始める")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var events: Array = []
	bridge.subscribe("記録確認",func(packet): events.append_array(packet.events);return true)
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	if not tail_only:
		check(started.ok,"本体の順番の号令を開始する")
	var t: Dictionary = {}
	if not tail_only:
		var held: Dictionary = bridge.checkpoint()
		bridge._core.step(0.101)
		t = bridge.command("dev_boss_state").value[0]
		check(t.kind==46 and t.stage==1 and t.sent and t.sequence.size()==3 and t.sequence[0].marked and not t.sequence[0].launched,"予告明けに猟犬を並べ替え、個別の予告を先に出す")
		var sequence: Array = t.sequence.duplicate(true)
		check(bridge.restore(held.value).ok,"送出前の乱数・予告・本体の時計を保持する")
		bridge._core.step(0.101)
		check(bridge.command("dev_boss_state").value[0].sequence==sequence,"復帰後も同じ猟犬の順番と発進時刻になる")
		bridge.release_checkpoint(held.value)
	else:
		bridge._core.step(0.101)
	bridge._core.step(0.021)
	var lunges: Array = canis_lunges(bridge)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	if not tail_only:
		check(lunges.size()==1 and lunges[0].sweep and not lunges[0].shared_hit and lunges[0].overwrite and semantics_approx(lunges[0].until,float(body.clock)+0.08,"native_canis_stream:lunges[0].until"),"個別の掃引・1回制限・固定速度と本体の時計で突進を保つ")
	var before_hp: float = bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":lunges[0].position,"velocity":Vector2.ZERO})
	bridge._core.step(0.001)
	check(canis_lunges(bridge)[0].hit and bridge._core.ship_snapshot().ship_hp<before_hp,"猟犬の実移動から機体へ命中し実HPを減らす")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(c.view._boss_body_displays.values()[0].technique.technique=="stream","正式な本体表示へ同じ予告・実行状態を渡す")
	bridge.command("set_ui_overlay",{"active":false})
	check(events.any(func(e): return e.type==&"canis_cue" and e.payload.get("cue","")=="stream_launch"),"個別の予告と発進を通常の通知へ残す")
	for k in 22: bridge._core.step(1.0/120.0)
	check(bridge.command("dev_boss_state").value[0].stage==2 and canis_lunges(bridge).is_empty(),"最後の猟犬の期限で自然に硬直へ進む")
	bridge._core.step(0.041)
	check(bridge.command("dev_boss_state").value[0].stage>=5,"硬直が終わると技を閉じる")
	bridge.dispose();c.view.queue_free()
	c = canis_move_case("stream",values,false,{"pack_size":3,"lead_max":3});bridge = c.bridge
	started = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.122)
	t = bridge.command("dev_boss_state").value[0]
	var gone: int = t.sequence[1].actor
	bridge.command("dev_damage",{"entity_id":gone,"amount":100000.0,"cause":"shot"})
	bridge._core.step(0.06)
	t = bridge.command("dev_boss_state").value[0]
	check(not t.sequence[1].launched,"消失した世代の猟犬を後の行再利用で発進させない")
	check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok and canis_lunges(bridge).is_empty(),"途中取消で個別の予告と固定突進を閉じる")
	bridge.dispose();c.view.queue_free()
	c = canis_move_case("stream",values,false,{"pack_size":3,"lead_max":3});bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.122)
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(canis_lunges(bridge).is_empty(),"本体の消失で所有する突進を残さない")
	bridge.dispose();c.view.queue_free()
	values.min_hounds = 5
	c = canis_move_case("stream",values,true,{"pack_size":1,"lead_max":1});bridge = c.bridge
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value.is_empty(),"率いる数が条件未満なら通常フローで選ばない")
	bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_stream] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 初回に粗いdtを使った自然終了の条件だけを固定更新で確認する。
func native_canis_stream_end() -> void:
	var c := canis_move_case("stream",{"warn":0.1,"interval":0.05,"each_warn":0.02,"lunge_speed":200.0,"lunge_speed_p2":200.0,"lunge_time":0.08,"recover":0.04,"min_hounds":1},false,{"pack_size":3,"lead_max":3})
	if c.is_empty(): check(false,"自然終了の入力を生成する");get_tree().quit(1);return
	var bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.101)
	bridge._core.step(0.021)
	for k in 22: bridge._core.step(1.0/120.0)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.stage==2 and canis_lunges(bridge).is_empty(),"最後の猟犬の期限で自然に硬直へ進む")
	bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_stream_end] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_canis_stream_cancel() -> void:
	var c := canis_move_case("stream",{"warn":0.1,"interval":0.05,"each_warn":0.1,"lunge_time":0.08,"recover":0.04,"min_hounds":1},false,{"pack_size":3,"lead_max":3})
	if c.is_empty(): check(false,"予告取消の入力を生成する");get_tree().quit(1);return
	var bridge = c.bridge
	var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.101)
	var before: Array = bridge.read_render(Rect2(-3000,-2000,6000,4000)).value.batches
	check(before.any(func(b): return b.has("glows")),"個別予告の発光を先に確定する")
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	var after: Array = bridge.read_render(Rect2(-3000,-2000,6000,4000)).value.batches
	check(not after.any(func(b): return b.has("glows")),"取消で猟犬の予告の発光と指示を解除する")
	bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_stream_cancel] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 再生・分離・通常技の既存ケースを同じC++窓口へ接続する。
func hydra_normal_case(flowing := false, squad_changes := {}, move_changes := {}, selected_move := "bite_thrust", config_changes := {}) -> Dictionary:
	var c := hydra_regrow_case(flowing,squad_changes,move_changes,selected_move,config_changes)
	if c.is_empty(): return c
	var bridge = c.bridge
	bridge._core.set_motion_context(Vector2(1600,0),Vector2.ZERO,Vector2(2500,1800))
	bridge._core.set_run_guards({"invincible":true})
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp*0.7,"cause":"shot"})
	bridge._core.step(0.101)
	bridge._core.step(0.101)
	bridge._core.step(4.0)
	return c


func native_hydra_common() -> void:
	var c := hydra_normal_case()
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.necks.size()==8,"噛みつく2本を含む実際の8本への成長を使う")
	bridge.command("dev_ship_motion",{"position":body.necks[0].position,"velocity":Vector2.ZERO})
	var first: Dictionary = bridge.command("dev_boss_technique",{"entity_id":body.necks[0].id,"definition":1})
	bridge.command("dev_ship_motion",{"position":body.necks[5].position,"velocity":Vector2.ZERO})
	var second: Dictionary = bridge.command("dev_boss_technique",{"entity_id":body.necks[5].id,"definition":1})
	check(first.ok and second.ok and first.value!=second.value,"並行する首の噛みつきが別々の技チケットを持つ")
	for _tick in 65: bridge._core.step(0.01)
	body = bridge.command("dev_boss_body_state").value[0]
	var observed: Array = bridge.command("dev_boss_state").value
	check(body.necks[0].locked and body.necks[5].locked and observed.filter(func(t): return t.kind==64 and t.stage<5).size()==2,"共通処理の狙い固定と観測を首ごとに保つ")
	check(bridge.command("dev_cancel_technique",{"ticket":first.value}).ok,"一方の噛みつきを途中で取り消す")
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].mode=="idle" and body.necks[5].mode=="bite_thrust" and not body.boss_dead,"取消が並行首と勝利状態へ漏れない")
	var old: int = body.necks[0].id
	var body_hp: float = body.hp
	bridge.command("dev_damage",{"entity_id":old,"amount":1000.0,"cause":"shot"})
	bridge._core.step(1.8)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].alive and body.necks[0].id!=old and body.hp==body_hp and not body.boss_dead,"首の破壊・再生は新IDと独立HPを保ち本体勝利にしない")
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"})
	bridge._core.step(0.001)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.separated and body.necks.size()==8 and body.necks.all(func(n): return n.alive) and not body.boss_dead,"瓦礫を壊す実経路で全首を回復して分離する")
	bridge._core.step(1.21)
	bridge._core.step(4.0)
	body = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_ship_motion",{"position":body.necks[0].position+Vector2(200,0),"velocity":Vector2.ZERO})
	var split: Dictionary = bridge.command("dev_boss_technique",{"entity_id":body.necks[0].id,"definition":1})
	check(split.ok,"分離後も同じ登録済み噛みつきを開始する")
	for _tick in 65: bridge._core.step(0.01)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].locked and body.necks[0].mode=="bite_thrust" and not body.effects.is_empty(),"分離した首の伸長と点列の判定を共通技から出す")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"分離した噛みつきの狙い・伸長・残留形状を保持する")
	bridge._core.step(0.04)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(bridge.restore(held.value).ok,"分離後の攻撃途中へ値で戻す")
	bridge._core.step(0.04)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"復帰後も首ごとの進行と形状が一致する")
	bridge.release_checkpoint(held.value)
	bridge.command("dev_cancel_technique",{"ticket":split.value})
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.mode==5 and not body.boss_dead and body.effects.is_empty(),"分離後の途中取消も本体勝利を誤発火しない")
	bridge.dispose()
	print("[cpp_hydra_common] failures=",failed)
	get_tree().quit(1 if failed else 0)


func native_hydra_swim() -> void:
	var c := hydra_normal_case()
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":body.necks[0].id,"amount":1000.0,"cause":"shot"})
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"})
	bridge._core.step(0.001)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.separated and body.participants.size()==10 and body.bearer.alive and body.necks.all(func(n): return n.alive and is_equal_approx(n.hp,n.max_hp)),"実分離で全首と不死首の所有・HPを作る")
	var before := body.duplicate(true)
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.position==before.position and body.necks[0].position==before.necks[0].position and body.separation_left<before.separation_left,"分離演出中は保護して位置の更新を止める")
	bridge._core.step(1.2)
	bridge._core.step(0.025)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.bearer.velocity.length()>0 and body.bearer.points.size()>8 and body.bearer.points[-1].distance_to(body.bearer.position)<0.001,"不死首が操舵し、胴体の先端が確定した頭に一致する")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.025)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"分離の時計・速度・履歴・姿勢を保持して戻す")
	bridge._core.step(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"泳ぎの途中復帰後の軌道と点列が一致する")
	bridge.release_checkpoint(held.value)
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(c.package.visuals)
	view.setup(scope,entries,c.cfg.character_scale)
	var render: Dictionary = bridge.read_render(Rect2(-2500,-1800,5000,3600)).value
	check(view.apply_frame(render),"分離後の蛇と不死首を正式素材へ表示する")
	var display = view._boss_body_displays.values()[0]
	check(display.get_node("NeckArtwork").frame.has("bearer") and display.get_node("NeckArtwork").immortal!=null,"不死首と尾の素材を読み取り専用点列へ渡す")
	var snapshot: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	view.apply_frame(render)
	bridge._core.step(0.0)
	check(bridge.command("dev_boss_body_state").value[0]==snapshot,"表示と世界停止は泳ぎの状態を更新しない")
	body = snapshot
	var dead_head: int = body.necks[0].id
	bridge.command("dev_damage",{"entity_id":dead_head,"amount":1000.0,"cause":"shot"})
	bridge._core.step(5.0)
	body = bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[0].alive and not body.boss_dead,"分離後に落とした首は再生しない")
	var bearer_id: int = body.bearer.id
	bridge.command("dev_damage",{"entity_id":bearer_id,"amount":1.0,"cause":"shot"})
	bridge._core.step(0.025)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.hp==body.bearer.hp and body.hp<snapshot.hp,"不死首の独立HPだけを本体の表示HPへ同期する")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.mode==5 and not body.has("arena") and not body.bearer.alive and body.necks.all(func(n): return not n.alive) and not body.boss_dead,"途中取消で囲い・蛇・不死首を終了する")
	view.queue_free();bridge.dispose()
	await get_tree().process_frame
	print("[cpp_hydra_swim] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 既存の分離・群れ・姿勢のケースをC++の本体と共通フローへ接続する。
func hydra_squad_case(changes: Dictionary, only_bite := false) -> Dictionary:
	var c := hydra_normal_case(true,changes)
	if c.is_empty(): return c
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"})
	bridge._core.step(0.001);bridge._core.step(1.21)
	body = bridge.command("dev_boss_body_state").value[0]
	if only_bite:
		for n: Dictionary in body.necks:
			if n.kind!="bite": bridge.command("dev_damage",{"entity_id":n.id,"amount":1000.0,"cause":"shot"})
	for tick in 125: bridge._core.step(0.025)
	body = bridge.command("dev_boss_body_state").value[0]
	var parts := PackedInt64Array([c.id])
	for n: Dictionary in body.necks: parts.append(n.id)
	# 死亡した部位も同じ表に保つ。開始時の生存を必須にするAPIには、生存時に固定した世代を渡す。
	c.parts=parts
	return c

func native_hydra_squad() -> void:
	var retry := "--cpp-hydra-squad-retry" in OS.get_cmdline_user_args()
	var c := hydra_squad_case({"pincer_weight":1.0,"wave_weight":0.0,"wall_weight":0.0,"wall_near_weight":0.0,"initial_gap":Vector2(3.2,3.2),"pincer_timeout":0.05,"counter_max":0,"block_distance":0.0})
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	if not retry: check(body.necks.any(func(n): return n.role==1) and body.necks.any(func(n): return n.velocity.length()>30.0) and body.necks.all(func(n): return body.arena.has_point(n.position) and n.points[-1].distance_to(n.position)<0.001),"前衛と近衛を選び、確定した頭を追う胴と囲いの内側の移動を保つ")
	check(bridge.command("dev_boss_flow_state").value[0].participants==c.parts,"実在する首の世代を共通フローの参加者へ渡す")
	for head: Dictionary in body.necks:
		if head.kind!="bite": bridge.command("dev_damage",{"entity_id":head.id,"amount":1000.0,"cause":"shot"})
	# 実在する噛みつく2本を使い、保存値を近似技に置き換えない。
	var launched := false
	for tick in 180:
		bridge._core.step(0.025)
		body = bridge.command("dev_boss_body_state").value[0]
		if body.pair_launched:
			launched=true
			break
	check(launched and body.necks.filter(func(n): return n.mode=="bite_thrust").size()==2,"挟撃は2本の実際の通常技を一組で開始する")
	var flow: Dictionary = bridge.command("dev_boss_flow_state").value[0]
	check(is_equal_approx(flow.stamina,6.0) and is_equal_approx(flow.spent,2.0) and flow.active,"指名の予約を実行時に解放し同じフローの予算を2本分だけ消費する")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.025)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	var expected_flow: Array = bridge.command("dev_boss_flow_state").value.duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"役割・持ち場・視線の乱数と挟撃中のチケットを保持する")
	bridge._core.step(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected and bridge.command("dev_boss_flow_state").value==expected_flow,"途中復帰後も視線・力・移動順とフロー予算が一致する")
	bridge.release_checkpoint(held.value)
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"挟撃・持ち場・視線を正式素材の読み取り専用表示へ渡す")
	await get_tree().process_frame
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"取消で分隊の攻撃と表示を清算する")
	view.queue_free();bridge.dispose()
	# 壁戦術中の迎撃は区間の実行状態を置き換えず、同じ予算だけを消費する。
	c = hydra_squad_case({"pincer_weight":0.0,"wave_weight":0.0,"wall_weight":1.0,"wall_near_weight":0.0,"block_distance":10000.0})
	if c.is_empty(): get_tree().quit(1);return
	bridge=c.bridge;body=bridge.command("dev_boss_body_state").value[0]
	var n: Dictionary = body.necks[0]
	bridge.command("dev_ship_motion",{"position":n.free_pos+Vector2.from_angle(n.look_angle)*100.0,"velocity":Vector2.ZERO})
	check(bridge.command("dev_boss_flow_state").value[0].participants==c.parts,"迎撃も同じ参加者と制作フローへ接続する")
	bridge._core.step(0.025)
	body=bridge.command("dev_boss_body_state").value[0];flow=bridge.command("dev_boss_flow_state").value[0]
	if not retry: check(body.necks.any(func(head): return head.counter and head.mode=="bite_thrust") and body.counter_time>0.0 and is_equal_approx(flow.stamina,7.0) and not flow.active and flow.completed==0,"迎撃が通常技を実行して共通予算を消費し、区間の完了数を増やさない")
	check(body.necks.filter(func(head): return head.role==3).size()==2,"残る護衛が2つの割込点を担当する")
	var before: Dictionary = body.duplicate(true)
	bridge._core.step(0.0)
	check(bridge.command("dev_boss_body_state").value[0]==before,"世界停止中は役割・視線・割込点と乱数を更新しない")
	bridge.command("dev_damage",{"entity_id":n.id,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.025)
	check(not bridge.command("dev_boss_body_state").value[0].boss_dead,"迎撃する首の消失は分隊全体の勝利にしない")
	bridge.command("dev_cancel_boss",{"entity_id":c.id});bridge.dispose()
	await get_tree().process_frame
	print("[cpp_hydra_squad] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 既存の通常技検査から、制作値・時計・掃引・寿命・中断を同じ窓口で確認する。
func native_hydra_bite() -> void:
	var retry := "--cpp-hydra-bite-retry" in OS.get_cmdline_user_args()
	var move = load("res://data/bosses/hydra_moves/bite_thrust.tres").duplicate(true)
	if not retry: check(move.make_runner()==null and move.get_script().resource_path=="res://scripts/data_types/boss_techniques/hydra/bite_thrust.gd","噛みつきの制作Resourceは編集値だけを持つ")
	if not retry: check(load("res://scripts/bosses/legacy_technique_runners.gd").make(move).kind()==&"bite_thrust","通常入口の切替前も互換Runnerから元の噛みつきを呼べる")
	var edits := {"normal_charge":0.15,"normal_lunge":0.4,"normal_hold":0.1,"attack_cd":0.05,"bite_radius":150.0,"bite_dmg":7.0}
	var c := hydra_normal_case(true,{},edits)
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var generated: Dictionary = c.package.records.BossTechniqueDefinition[0]
	var normal: Dictionary = c.package.records.HydraNormalDefinition[0]
	if not retry: check(generated.warn==0.15 and generated.active==0.4 and generated.hold==0.1 and generated.damage==7.0 and normal.attack_cd==0.05 and normal.bite_radius==150.0,"編集値を生成し種類固有の時間・幅・ダメージと待ちを保つ")
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var target: Vector2 = body.necks[0].position+Vector2(200,0)
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	bridge._core.set_run_guards({"invincible":false})
	var actions: Array = []
	for tick in 200:
		bridge._core.step(0.01)
		actions = bridge.command("dev_boss_state").value
		if not actions.is_empty(): break
	check(not actions.is_empty(),"共通フローの候補選択の待ち後に自然開始する")
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	var t: Dictionary = actions[0]
	check(t.kind==64 and t.stage==0 and t.elapsed==0.0 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"自然選択で首の予告を開始し、その更新では攻撃を出さない")
	var hp: float = bridge._core.ship_snapshot().ship_hp
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].glow>0.9 and body.effects.is_empty() and bridge._core.ship_snapshot().ship_hp==hp,"予告は頭の発光だけで命中判定を出さない")
	bridge._core.step(0.011)
	body=bridge.command("dev_boss_body_state").value[0]
	t=bridge.command("dev_boss_state").value[0]
	check(t.stage==1 and body.necks[0].locked and body.effects.size()==1 and body.effects[0].width==150.0 and body.effects[0].points.size()==2,"発動時刻に元の頭から今の頭への点列を出し幅を保つ")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.025)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"噛みつきの固定目標・段階・首と点列を途中保持して戻す")
	bridge._core.step(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"途中復帰後も同じ編集時間と形状へ進む")
	bridge.release_checkpoint(held.value)
	for tick in 13:
		bridge._core.step(0.025)
		bridge._core.step_hazards(0.025)
		bridge.command("dev_boss_body_state")
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実際の点列が掃引する機体へ命中し倍率を一度だけ掛ける")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"噛みつく首と判定形を正式表示へ渡す")
	await get_tree().process_frame
	bridge._core.step(0.15)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].mode=="idle" and body.effects.is_empty(),"自然終了で0.1秒の残留判定も清算して首の待ちへ戻る")
	var first_id: int = t.id
	for tick in 12: bridge._core.step(0.025)
	check(bridge.command("dev_boss_state").value.any(func(action): return action.id>first_id and action.kind==64),"首の待ちが終わると共通フローから次の噛みつきを選ぶ")
	bridge.command("dev_cancel_flow",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"途中取消は噛みつきの残留判定を消す")
	body=bridge.command("dev_boss_body_state").value[0]
	var other: Dictionary = body.necks[5]
	bridge.command("dev_ship_motion",{"position":other.position+Vector2.from_angle(other.angle)*200.0,"velocity":Vector2.ZERO})
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":other.id,"definition":1})
	check(started.ok,"別の噛みつく首から同じ種類を開始する")
	bridge._core.step(0.2)
	bridge.command("dev_damage",{"entity_id":other.id,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[5].alive and body.effects.is_empty() and not body.boss_dead,"参加首の消失でその判定を終了し、本体の勝利にしない")
	bridge._core.set_run_guards({"invincible":true})
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"})
	bridge._core.step(0.001);bridge._core.step(1.21)
	body=bridge.command("dev_boss_body_state").value[0]
	for head: Dictionary in body.necks: bridge.command("dev_damage",{"entity_id":head.id,"amount":1000.0,"cause":"shot"})
	bridge.command("dev_ship_motion",{"position":Vector2(10000,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(10000,0),Vector2(10000,0),Vector2(100,100))
	bridge._core.step(3.1);bridge._core.step(0.001)
	var bearer: int = bridge.command("dev_boss_body_state").value[0].bearer.id
	check(bridge.command("dev_boss_state").value.any(func(action): return action.kind==64 and action.actor==bearer and action.stage==0),"不死首の単独攻撃は画面内・距離・通常指名を要求せず同じ噛みつきを開始する")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	view.queue_free();bridge.dispose()
	await get_tree().process_frame
	print("[cpp_hydra_bite] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 実命中の失敗項目だけを、共通攻撃の更新を含めて再確認する入口。
func native_hydra_bite_hit() -> void:
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"normal_lunge":0.4,"normal_hold":0.1,"attack_cd":0.05,"bite_radius":150.0,"bite_dmg":7.0})
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_ship_motion",{"position":body.necks[0].position+Vector2(200,0),"velocity":Vector2.ZERO})
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = []
	bridge.subscribe("命中記録",func(packet): events.append_array(packet.events);return true)
	var hp: float = bridge._core.ship_snapshot().ship_hp
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	for tick in 50:
		bridge._core.step(0.01)
		bridge._core.step_hazards(0.01)
		bridge.command("dev_boss_body_state")
	var hits: Array = events.filter(func(event): return event.type=="combat_player_damage" and event.payload.accepted and event.payload.cause=="bite")
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale) and hits.size()==1 and hits[0].payload.source==&"hydra" and hits[0].payload.technique==&"bite_thrust","実際の点列が掃引する機体へ命中し倍率を一度だけ掛け、元の攻撃原因と技を記録する")
	if failed: print("命中の状態: ",bridge._core.ship_snapshot()," 命中記録: ",hits)
	bridge.dispose()
	print("[cpp_hydra_bite_hit] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 猟犬の順番から狙撃へ渡す境界と、取消後の炎の寿命を照合する。
func native_canis_hunt() -> void:
	var c := canis_move_case("hunt",{"gap":0.05,"aim_warn":0.1,"aim_lock":0.04,"aim_lead":0.2,"aim_turn":3.0,"beam_time":0.1,"beam_length":300.0,"beam_width":20.0,"beam_particle_life":0.25,"recover":0.05},false,{"pack_size":3,"lead_max":3},false,0.5)
	check(not c.is_empty(),"追い立てと狙撃と内包する順番の号令を同じ生成入口へ渡す")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var records: Dictionary = c.package.records
	check(c.move.make_runner()==null and records.CanisHuntDefinition.size()==2 and records.CanisStreamDefinition.size()==2 and records.CanisHuntDefinition[1].stream==4 and records.BossTechniqueStage.is_empty() and records.CanisFlameDefinition[0].external_id=="hunt" and records.CanisFlameDefinition[0].trail_life==0.0,"全編集値と二形態・依存ID・狙撃専用の炎を生成する")
	var events: Array = []
	bridge.subscribe("記録確認",func(packet): events.append_array(packet.events);return true)
	var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(ticket.ok,"制作入口では通常フローの最低猟犬数と分けて単独発動する")
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	for k in 150:
		if t.sent: break
		bridge._core.step(1.0/120.0)
		t = bridge.command("dev_boss_state").value[0]
	check(t.sent and t.sequence.size()==3 and not t.aiming,"猟犬の全体予告を終えてから順番の個別予告を始める")
	var sequence_checkpoint: Dictionary = bridge.checkpoint()
	var absent: int = t.sequence[2].actor
	for k in 150:
		if t.aiming: break
		bridge._core.step(1.0/120.0)
		t = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(t.aiming and not t.combo_pending and semantics_approx(t.aim_age,1.0/120.0,"native_canis_hunt:t.aim_age") and body.clock>=t.last_launch+0.05 and not canis_lunges(bridge).is_empty(),"最後の発進とgapを過ぎたtickに狙撃を始め、猟犬の突進は並行して残す")
	var aim_checkpoint: Dictionary = bridge.checkpoint()
	check(aim_checkpoint.ok,"内側の順番・狙撃・乱数・本体時計を保持する")
	bridge.command("dev_ship_motion",{"position":Vector2(300,300),"velocity":Vector2(100,0)})
	bridge._core.set_motion_context(Vector2(300,300),Vector2(300,300),Vector2(3000,2000))
	bridge._core.step(0.05)
	t = bridge.command("dev_boss_state").value[0]
	check(not t.locked and t.aim==Vector2(320,300),"狙撃は機体の速度を先読みし、加算前の予告時計で固定を判断する")
	bridge._core.step(0.01)
	check(not bridge.command("dev_boss_state").value[0].locked,"固定時刻へ到達したtickの照準更新を保持する")
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	var facing: float = t.facing
	check(t.locked,"次のtickで照準を固定する")
	bridge.command("dev_ship_motion",{"position":Vector2(1800,-1000),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1800,-1000),Vector2(1800,-1000),Vector2(3000,2000))
	bridge._core.step(0.03)
	t = bridge.command("dev_boss_state").value[0]
	check(t.fired and t.stage==1 and semantics_approx(t.facing,facing,"native_canis_hunt:t.facing") and canis_effects(bridge).any(func(v): return v.kind==0),"固定方向を保って噴射を始める")
	var fired_checkpoint: Dictionary = bridge.checkpoint()
	bridge._core.step(0.04)
	var continued: Dictionary = bridge.command("dev_boss_state").value[0].duplicate(true)
	var flame_rows: Array = canis_effects(bridge).duplicate(true)
	check(bridge.restore(fired_checkpoint.value).ok,"狙撃の発射後へ復帰する")
	bridge._core.step(0.04)
	check(bridge.command("dev_boss_state").value[0]==continued and canis_effects(bridge)==flame_rows,"復帰後も狙撃の時計・猟犬・戦闘粒を一致させる")
	bridge._core.step(0.07)
	check(bridge.command("dev_boss_state").value[0].stage==2,"放射時間が終わると外側の硬直へ進む")
	bridge._core.step(0.06)
	check(bridge.command("dev_boss_state").value[0].stage==5 and not canis_effects(bridge).is_empty(),"自然終了後も発射した粒は寿命まで残る")
	bridge.restore(fired_checkpoint.value)
	var particles: Array = canis_effects(bridge).filter(func(v): return v.kind==1)
	bridge.command("dev_ship_motion",{"position":particles[0].pos,"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp<hp,"狙撃の粒で実際の機体HPを減らす")
	bridge.command("set_ui_overlay",{"active":false})
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause=="flame_jet" and e.payload.technique=="hunt"),"原因は炎の噴射、技は追い立てと狙撃として別々に記録する")
	bridge.restore(fired_checkpoint.value)
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	check(bridge.command("dev_boss_state").value[0].stage==7 and canis_lunges(bridge).is_empty() and not canis_effects(bridge).is_empty(),"取消では猟犬を解放し、発射済みの炎は残す")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(not c.view._boss_body_displays.values()[0].flames.displays.is_empty(),"残留炎を正式表示へ反映する")
	bridge.restore(aim_checkpoint.value)
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(c.view._boss_body_displays.values()[0].technique.aiming,"狙撃の予告を正式な本体表示へ渡す")
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	check(canis_effects(bridge).is_empty() and canis_lunges(bridge).is_empty(),"発射前の取消は猟犬と照準だけを解放し炎を生成しない")
	bridge.restore(sequence_checkpoint.value)
	bridge.command("dev_remove",{"entity_id":absent})
	for k in 150:
		bridge._core.step(1.0/120.0)
		t = bridge.command("dev_boss_state").value[0]
		if t.aiming: break
	check(not t.sequence[2].launched and t.aiming,"参加者が消失しても予定した最終時刻で狙撃へ進む")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(canis_lunges(bridge).is_empty() and canis_effects(bridge).is_empty(),"本体消失では技と残留攻撃を回収する")
	for checkpoint in [sequence_checkpoint,aim_checkpoint,fired_checkpoint]: bridge.release_checkpoint(checkpoint.value)
	bridge.dispose();c.view.queue_free()
	c = canis_move_case("hunt",{},true,{"pack_size":3,"lead_max":3});bridge = c.bridge
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value.is_empty(),"通常フローは5体未満の猟犬で狙撃を選ばない")
	bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_hunt] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 内包する順番と一度だけの飛びかかりを、同じ本体clockで進める。
func native_canis_hunt_pounce() -> void:
	var dependencies := {"stream":{"warn":0.05,"interval":0.02,"each_warn":0.01,"lunge_speed":100.0,"lunge_time":0.5,"min_hounds":2},"pounce":{"warn":0.1,"lock":0.03,"active":0.08,"recover":0.04,"overshoot":10.0,"damage":7.0}}
	var c := canis_move_case("hunt_pounce",{"gap":0.02,"track_during_warn":false},false,{"pack_size":3,"lead_max":3},false,0.5,dependencies)
	check(not c.is_empty(),"追い立てと飛びかかりの全編集値と依存する二つの技を生成する")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var records: Dictionary = c.package.records
	check(c.move.make_runner()==null and records.CanisHuntPounceDefinition.size()==2 and records.CanisStreamDefinition.size()==2 and records.CanisPounceDefinition.size()==2 and records.CanisHuntPounceDefinition[1].stream==4 and records.CanisHuntPounceDefinition[1].pounce==6 and records.BossTechniqueStage.is_empty(),"二形態の依存参照を一意に生成し、戦闘method trackを残さない")
	var events: Array = []
	bridge.subscribe("記録確認",func(packet): events.append_array(packet.events);return true)
	var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	for k in 50:
		if t.sent: break
		bridge._core.step(1.0/120.0)
		t = bridge.command("dev_boss_state").value[0]
	var sequence_checkpoint: Dictionary = bridge.checkpoint()
	var lost: int = t.sequence[2].actor
	for k in 50:
		if t.jumping: break
		bridge._core.step(1.0/120.0)
		t = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(t.jumping and not t.jump_active and t.left==1 and semantics_approx(t.jump_age,1.0/120.0,"native_canis_hunt_pounce:t.jump_age") and body.clock>=t.last_launch+0.02 and not canis_lunges(bridge).is_empty(),"猟犬の最後の発進とgapの直後に一度だけの跳躍予告を始める")
	bridge.command("dev_ship_motion",{"position":Vector2(300,300),"velocity":Vector2(100,0)})
	bridge._core.set_motion_context(Vector2(300,300),Vector2(300,300),Vector2(3000,2000))
	bridge._core.step(0.06)
	t = bridge.command("dev_boss_state").value[0]
	check(not t.locked and t.aim.x>320.0 and t.facing>0.0,"外側が追尾無効でも飛びかかり自身の追尾値で残り予告と速度を先読みする")
	bridge._core.step(0.01)
	t = bridge.command("dev_boss_state").value[0]
	check(t.locked,"内側の予告時計を加算した後に着地点を固定する")
	var locked: Vector2 = t.aim
	bridge.command("dev_ship_motion",{"position":Vector2(-800,-800),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(-800,-800),Vector2(-800,-800),Vector2(3000,2000))
	bridge._core.step(0.03)
	t = bridge.command("dev_boss_state").value[0]
	check(t.jump_active and t.aim==locked and t.jump_age==0.0,"発進tickは移動せず固定した着地点を保つ")
	var launched_checkpoint: Dictionary = bridge.checkpoint()
	bridge._core.step(0.04)
	var moved: Dictionary = bridge.command("dev_boss_state").value[0].duplicate(true)
	var lunges: Array = canis_lunges(bridge).duplicate(true)
	check(bridge.restore(launched_checkpoint.value).ok,"内側の二つのRunnerと固定した着地点へ復帰する")
	bridge._core.step(0.04)
	check(bridge.command("dev_boss_state").value[0]==moved and canis_lunges(bridge)==lunges,"復帰後も本体の移動・猟犬・乱数・予告時計を一致させる")
	bridge._core.step(0.05)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==2 and t.jump_done and t.left==0,"跳躍一回の終了で内側pounceの硬直へ進む")
	var residue: Array = canis_lunges(bridge).duplicate(true)
	check(not residue.is_empty() and residue.all(func(v): return v.manual_retained),"早く終わった編集値ではSourceと同じ残留した突進を保持する")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5,"外側の回復値ではなくpounceの回復値で自然終了する")
	bridge._core.step(0.5)
	var stopped: Array = canis_lunges(bridge)
	check(stopped.size()==residue.size() and stopped[0].from==residue[0].from and stopped[0].until==residue[0].until,"自然終了後は残留突進の判定更新と期限の整理を止める")
	var ended_checkpoint: Dictionary = bridge.checkpoint()
	var old_id: int = t.id
	var next_ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(next_ticket.ok and bridge.command("dev_boss_state").value[0].id>old_id and canis_lunges(bridge).size()==residue.size(),"自然終了したticketを再利用し、旧Runnerの残留を勝手に取り消さない")
	bridge._core.step(0.01)
	check(canis_lunges(bridge)[0].from==residue[0].from,"行を再利用した別の技を旧Handleから進めない")
	check(bridge.restore(ended_checkpoint.value).ok,"旧Handleのまま停止した残留も復帰する")
	bridge.command("dev_remove",{"entity_id":residue[0].actor})
	bridge._core.step(0.01)
	check(canis_lunges(bridge).size()==residue.size()-1,"停止中でも消失した参加者の攻撃を解放する")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(canis_lunges(bridge).is_empty(),"本体終了では自然終了後の残留も回収する")
	bridge.restore(launched_checkpoint.value)
	bridge.command("dev_ship_motion",{"position":locked,"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.08)
	bridge.command("dev_boss_state")
	check(bridge._core.ship_snapshot().ship_hp<hp and events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause=="pounce" and e.payload.technique=="hunt_pounce"),"本体の掃引で実ダメージを出し、原因と外側の技名を記録する")
	bridge.restore(launched_checkpoint.value)
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	check(bridge.command("dev_boss_state").value[0].stage==7 and canis_lunges(bridge).is_empty(),"途中取消では並行する猟犬も解放する")
	bridge.restore(sequence_checkpoint.value)
	bridge.command("dev_remove",{"entity_id":lost})
	for k in 60:
		bridge._core.step(1.0/120.0)
		t = bridge.command("dev_boss_state").value[0]
		if t.jumping: break
	check(t.jumping and not t.sequence[2].launched,"予定した猟犬が消失しても本体の予告を予定時刻に始める")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(c.view._boss_body_displays.values()[0].technique.jumping,"内側の着地点と本体の跳躍姿勢を正式表示へ渡す")
	for checkpoint in [sequence_checkpoint,launched_checkpoint,ended_checkpoint]: bridge.release_checkpoint(checkpoint.value)
	bridge.dispose();c.view.queue_free()
	c = canis_move_case("hunt_pounce",{},true,{"pack_size":1,"lead_max":1},false,0.0,dependencies);bridge = c.bridge
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value.is_empty(),"通常選択では内側streamの最低猟犬数を守る")
	bridge.dispose();c.view.queue_free()
	c = canis_move_case("hunt_pounce",{},true,{"pack_size":3,"lead_max":3},false,0.0,dependencies);bridge = c.bridge
	var body_state: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body_state.max_hp*0.55,"cause":"bullet"})
	bridge._core.step(0.01);bridge._core.step(2.0);bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value.is_empty(),"第2形態では追い立てと飛びかかりを通常選択しない")
	bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_hunt_pounce] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 前の一式で未確認だった、短い狙撃の後に残る突進の停止だけを照合する。
func native_canis_hunt_residue() -> void:
	var c := canis_move_case("hunt",{"gap":0.0,"aim_warn":0.01,"beam_time":0.01,"recover":0.01},false,{"pack_size":1,"lead_max":1})
	if c.is_empty(): check(false,"残留確認の入力を生成する");get_tree().quit(1);return
	var bridge = c.bridge
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	for k in 180:
		if t.stage==2: break
		bridge._core.step(1.0/120.0)
		t = bridge.command("dev_boss_state").value[0]
	var residual: Array = canis_lunges(bridge).duplicate(true)
	check(not residual.is_empty(),"短い狙撃では技を終えても発射した突進を消さない")
	bridge._core.step(0.03);bridge._core.step(0.6)
	check(canis_lunges(bridge).size()==residual.size() and canis_lunges(bridge)[0].from==residual[0].from,"追い立てと狙撃も自然終了後に突進の判定更新を止める")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(canis_lunges(bridge).is_empty(),"自然終了後の停止した突進も本体の終了で解放する")
	bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_hunt_residue] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 実位置から作る影と、技の自然終了後も続く輪を同じ制作入口で確かめる。
func native_canis_nova() -> void:
	var c := canis_move_case("nova",{"warn":0.2,"after":0.1,"recover":0.02,"ring_speed":200.0,"ring_end":1000.0,"ring_gap":0.2,"ring_band":1.0,"body_radius":30.0,"gather_speed":0.0},false,{"pack_size":6,"lead_max":6},false,0.5)
	check(not c.is_empty(),"閃光の編集Resource・本体・正式表示を同じ制作入口から読む")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = []
	bridge.subscribe("閃光の記録",func(packet): events.append_array(packet.events);return true)
	var records: Dictionary = c.package.records
	check(c.move.make_runner()==null and records.CanisNovaDefinition.size()==2 and records.BossTechniqueStage.is_empty() and records.CanisNovaDefinition[0].arrive==load("res://data/bosses/canis_major_moves/bay.tres").arrive,"全編集値とBayから借りる操舵を二形態分生成し、method trackを残さない")
	var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(ticket.ok,"閃光を単独発動する")
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.kind==49 and t.pairs.size()==6 and t.ring_hit==[false,false] and not t.flashed,"抽選した6体を3組へ分け、輪ごとの命中を初期化する")
	for k in 6:
		check(t.pairs[k].group==k/2 and t.pairs[k].side==(1.0 if k%2==0 else -1.0) and semantics_approx(float(t.pairs[k].angle)-float(t.pairs[0].angle),float(k/2)*TAU/3.0,"native_canis_nova:float(t.pairs[k].angle)-float(t.pairs[0].angle)"),"組の固定角と左右を保持する")
	var initial: Dictionary = bridge.checkpoint()
	var facing: float = bridge.command("dev_boss_body_state").value[0].facing
	bridge.command("dev_ship_motion",{"position":Vector2(0,2000),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(0,2000),Vector2(0,2000),Vector2(3000,2000))
	bridge._core.step(0.1)
	t = bridge.command("dev_boss_state").value[0]
	check(not t.flashed and t.stage==0 and semantics_approx(t.age,0.1,"native_canis_nova:t.age") and bridge.command("dev_boss_body_state").value[0].facing==facing,"予告は本体clockで進み、本体の向きと組の角度を固定する")
	var warning: Dictionary = bridge.checkpoint()
	bridge._core.step(0.01)
	var continuation: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(bridge.restore(warning.value).ok,"組・影・乱数と本体clockへ復帰する")
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_body_state").value[0]==continuation,"復帰後も組の操舵と実位置の影を一致させる")
	bridge._core.step(0.1)
	bridge._core.step(0.7)
	t = bridge.command("dev_boss_state").value[0]
	check(t.flashed and t.released and t.stage==2,"予告後に発光し、warn+afterで組を解放して硬直へ進む")
	bridge._core.step(0.03)
	t = bridge.command("dev_boss_state").value[0]
	check(t.stage==5 and not bridge.command("dev_boss_body_state").value[0].nova.is_empty(),"自然終了後も輪の判定を本体に保持する")
	for pair: Dictionary in t.pairs:
		var u := Vector2.from_angle(float(pair.angle))
		bridge.command("dev_relocate",{"entity_id":pair.actor,"position":t.source+u*100.0+u.orthogonal()*float(pair.side)*10.0})
	bridge._core.step(0.001)
	t = bridge.command("dev_boss_state").value[0]
	check(t.shadows.size()==3 and float(t.shadows[0].near)<110.0,"影を予定の持ち場から作らず、そのtickの猟犬の実位置から作る")
	var retained: Dictionary = bridge.checkpoint()
	var radius := 30.0+200.0*(float(t.age)+0.001-0.2)
	var protected: Vector2 = t.source+Vector2.from_angle(float(t.shadows[0].angle))*radius
	bridge.command("dev_ship_motion",{"position":protected,"velocity":Vector2.ZERO})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp==hp and not bridge.command("dev_boss_state").value[0].ring_hit[0],"機体半径を含めて影に収まると輪の帯に触れても被弾しない")
	t = bridge.command("dev_boss_state").value[0]
	var open_angle := float(t.shadows[0].angle)+PI/3.0
	radius = 30.0+200.0*(float(t.age)+0.001-0.2)
	bridge.command("dev_ship_motion",{"position":t.source+Vector2.from_angle(open_angle)*radius,"velocity":Vector2.ZERO})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp<hp and bridge.command("dev_boss_state").value[0].ring_hit[0],"影を外れると自然終了後の輪でも実際の機体HPが減る")
	bridge.command("set_ui_overlay",{"active":false})
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause=="nova" and e.payload.technique=="nova"),"閃光の原因と技名を記録へ届ける")
	hp = bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp==hp,"輪ごとの命中を保持し、同じ輪で繰り返しHPを減らさない")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var display = c.view._boss_body_displays.values()[0]
	check(not display._nova.is_empty() and display._nova_layer!=null,"自然終了後の輪と影も正式表示へ渡す")
	await get_tree().process_frame
	bridge.restore(retained.value)
	t = bridge.command("dev_boss_state").value[0]
	var finish_age := 0.2+0.2+(1000.0-30.0)/200.0
	bridge._core.step(finish_age-float(t.age)-0.001)
	check(not bridge.command("dev_boss_body_state").value[0].nova.is_empty(),"輪の最終半径の直前まで保持する")
	bridge._core.step(0.002)
	check(bridge.command("dev_boss_body_state").value[0].nova.is_empty(),"厳密な終了期限を越えると輪の参照を解放する")
	bridge.restore(initial.value)
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].nova.is_empty(),"取消では自然終了と違って輪も直ちに消す")
	bridge.restore(warning.value)
	t = bridge.command("dev_boss_state").value[0]
	bridge.command("dev_remove",{"entity_id":t.pairs[0].actor})
	bridge._core.step(0.001)
	check(bridge.command("dev_boss_state").value[0].pairs[0].actor==0 and bridge.checkpoint().ok,"猟犬が消失しても古い行を影へ使わず、保持復帰を続ける")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].nova.is_empty(),"本体消失では残留する輪も回収する")
	for checkpoint in [initial,warning,retained]: bridge.release_checkpoint(checkpoint.value)
	bridge.dispose();c.view.queue_free()
	c = canis_move_case("nova",{},true,{"pack_size":5,"lead_max":5});bridge=c.bridge
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value.is_empty(),"通常フローは必要な6体がそろわないと閃光を選ばない")
	bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_nova] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 猟犬の固定射撃と、残り予告時間で先読みする最後の射撃を接続する。
func native_canis_relay() -> void:
	var c := canis_move_case("relay",{"warn":0.1,"interval":0.05,"each_warn":0.05,"hound_beam_time":0.1,"hound_beam_length":250.0,"hound_beam_width":15.0,"hound_damage":7.0,"final_warn":0.1,"final_lock":0.03,"final_turn":3.0,"final_time":0.12,"final_length":300.0,"final_width":20.0,"final_damage":9.0,"beam_particle_life":0.25,"recover":0.03},false,{"pack_size":3,"lead_max":3},false,0.5)
	check(not c.is_empty(),"光を継ぐ群れを本体・猟犬・炎・正式表示と同じ制作入口へ渡す")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = []
	bridge.subscribe("継ぐ炎の記録",func(packet): events.append_array(packet.events);return true)
	var records: Dictionary = c.package.records
	check(c.move.make_runner()==null and records.CanisRelayDefinition.size()==2 and records.CanisRelayDefinition[1].hound_flame==8 and records.CanisRelayDefinition[1].final_flame==2 and records.CanisFlameDefinition[6].damage==7.0 and records.CanisFlameDefinition[0].damage==9.0 and records.BossTechniqueStage.is_empty(),"全編集値・二形態と猟犬用/本体用の炎を一意に生成する")
	var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(ticket.ok,"制作入口では通常選択の猟犬数と分けて単独発動する")
	var initial: Dictionary = bridge.checkpoint()
	bridge._core.step(0.11)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	check(t.stage==0 and t.ordered and t.items.size()==3 and t.items[0].marked and not t.items[0].fired and t.warnings.size()==1,"全体予告を終えてから抽選し、最初の猟犬だけ個別予告を始める")
	check(semantics_approx(float(t.items[1].at)-float(t.items[0].at),0.05,"native_canis_relay:float(t.items[1].at)-float(t.items[0].at)") and semantics_approx(float(t.last_fire)-float(t.items[0].at),0.15,"native_canis_relay:float(t.last_fire)-float(t.items[0].at)"),"個別時刻と最後の発射予定を本体clockへ置く")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(c.view._boss_body_displays.values()[0].technique.warnings.size()==1,"猟犬の固定予告を正式表示へ渡す")
	var marked: Dictionary = bridge.checkpoint()
	var first: Dictionary = t.items[0].duplicate(true)
	bridge.command("dev_ship_motion",{"position":Vector2(1000,1000),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1000,1000),Vector2(1000,1000),Vector2(3000,2000))
	bridge._core.step(0.055)
	t = bridge.command("dev_boss_state").value[0]
	var jets: Array = canis_effects(bridge).filter(func(v): return v.kind==0 and v.profile==7)
	check(t.items[0].fired and jets.size()==1 and jets[0].target==first.actor and semantics_approx(float(jets[0].angle),float(first.angle),"native_canis_relay:float(jets[0].angle)") and jets[0].from==first.from,"発射時には予告した位置と角度を使い、機体を狙い直さない")
	var jet_id: int = jets[0].id
	var fired: Dictionary = bridge.checkpoint()
	var moved := Vector2(500,100)
	bridge.command("dev_relocate",{"entity_id":first.actor,"position":moved})
	bridge._core.step(0.001)
	jets = canis_effects(bridge).filter(func(v): return v.kind==0 and v.target==first.actor)
	check(jets.size()==1 and jets[0].pos.distance_to(moved)<60.0 and semantics_approx(float(jets[0].angle),float(first.angle),"native_canis_relay:float(jets[0].angle)"),"発射後の口元だけを猟犬の実位置へ追従させ、角度は固定する")
	bridge.restore(fired.value)
	var particle: Dictionary = canis_effects(bridge).filter(func(v): return v.kind==1 and v.profile==7)[0]
	bridge.command("dev_ship_motion",{"position":particle.pos,"velocity":Vector2.ZERO})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp<hp,"猟犬の炎の粒で実際の機体HPを減らす")
	bridge.command("set_ui_overlay",{"active":false})
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause=="flame_jet" and e.payload.technique=="relay"),"炎の噴射という原因と光を継ぐ群れという技を別々に記録する")
	bridge.restore(fired.value)
	bridge._core.step(0.02)
	var continued: Dictionary = bridge.command("dev_boss_state").value[0].duplicate(true)
	var flames: Array = canis_effects(bridge).duplicate(true)
	check(bridge.restore(fired.value).ok,"順番と猟犬に付いた炎の途中へ復帰する")
	bridge._core.step(0.02)
	check(bridge.command("dev_boss_state").value[0]==continued and canis_effects(bridge)==flames,"復帰後も射撃の予定・猟犬・粒・乱数を一致させる")
	bridge.restore(fired.value)
	bridge.command("dev_remove",{"entity_id":first.actor})
	bridge._core.step(0.001)
	check(not canis_effects(bridge).any(func(v): return v.kind==0 and v.id==jet_id and v.emitting) and canis_effects(bridge).any(func(v): return v.kind==1),"射撃中の猟犬が消失すると新しい粒だけを止め、発射済みの粒は残す")
	bridge.restore(fired.value)
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	check(bridge.command("dev_boss_state").value[0].stage==7 and not canis_effects(bridge).is_empty(),"取消では個別予告と猟犬の指示を解き、発射済みの炎は消さない")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	check(not c.view._boss_body_displays.values()[0].flames.displays.is_empty(),"取消後の猟犬の炎を専用profileで正式表示する")
	bridge.restore(marked.value)
	bridge.command("dev_remove",{"entity_id":t.items[2].actor})
	for k in 100:
		bridge._core.step(0.008)
		t = bridge.command("dev_boss_state").value[0]
		if t.aiming: break
	check(t.aiming and semantics_approx(t.aim_age,0.008,"native_canis_relay:t.aim_age") and bridge.command("dev_boss_body_state").value[0].clock>=t.last_fire+0.35,"最後の猟犬が消失しても最後の予定時刻と固定の間隔から本体の照準を始める")
	bridge.command("dev_ship_motion",{"position":Vector2(300,300),"velocity":Vector2(100,0)})
	bridge._core.set_motion_context(Vector2(300,300),Vector2(300,300),Vector2(3000,2000))
	bridge._core.step(0.02)
	t = bridge.command("dev_boss_state").value[0]
	check(semantics_approx(t.aim,Vector2(309.2,300),"native_canis_relay:t.aim") and not t.locked,"最後の先読みは加算前の残り予告時間を使う")
	for k in 20:
		bridge._core.step(0.01)
		t = bridge.command("dev_boss_state").value[0]
		if t.fired: break
	check(t.fired and t.locked and t.stage==1,"最後の照準を固定して本体の炎を開始する")
	bridge._core.step(0.13)
	check(bridge.command("dev_boss_state").value[0].stage==2 and bridge.command("dev_boss_state").value[0].cancelled,"最後の噴射を終えると猟犬を解放して硬直へ進む")
	bridge._core.step(0.04)
	check(bridge.command("dev_boss_state").value[0].stage==5 and not canis_effects(bridge).is_empty(),"自然終了後も最後の炎の粒は寿命まで残す")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(canis_effects(bridge).is_empty(),"本体の終了では残留炎も回収する")
	bridge.restore(initial.value)
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	check(canis_effects(bridge).is_empty(),"発射前の取消では炎を生成しない")
	for checkpoint in [initial,marked,fired]: bridge.release_checkpoint(checkpoint.value)
	bridge.dispose();c.view.queue_free()
	c = canis_move_case("relay",{},true,{"pack_size":5,"lead_max":5});bridge=c.bridge
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value.is_empty(),"通常フローは必要な6体がそろわないと光を継ぐ群れを選ばない")
	bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_relay] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 既存の通常技の正常・中断ケースを薙ぎ払いの実行先へ接続する。
func native_hydra_sweep() -> void:
	var move = load("res://data/bosses/hydra_moves/bite_sweep.tres")
	check(move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(move).kind()==&"bite_sweep","薙ぎ払いは編集Resourceと互換Runnerに分かれる")
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"sweep_time":0.4,"normal_hold":0.1,"attack_cd":0.05,"sweep_arc":1.8,"sweep_reach":350.0,"bite_radius":150.0,"bite_dmg":7.0},"bite_sweep")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = []
	bridge.subscribe("薙ぎの記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_ship_motion",{"position":Vector2(350,0),"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==65,"薙ぎ払いが共通フローから自然に選ばれる")
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	var hp: float = bridge._core.ship_snapshot().ship_hp
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].glow>0.9 and body.effects.is_empty(),"予告時刻では発光だけを出す")
	bridge._core.step(0.011)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].locked and body.effects.size()==1 and is_equal_approx(body.effects[0].life,0.12) and body.effects[0].width==150.0,"発動時刻に根元を中心とする薙ぎを寿命0.12秒で出す")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.025)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"薙ぎの固定方向・点列・時計を保持して戻す")
	bridge._core.step(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"復帰後も同じ円弧を進む")
	bridge.release_checkpoint(held.value)
	for tick in 36:
		bridge._core.step(0.01);bridge._core.step_hazards(0.01);bridge.command("dev_boss_body_state")
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bite")
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale) and hits.size()==1 and hits[0].payload.technique==&"bite_sweep","円弧の線分が実HPへ一度倍率を掛け、biteと薙ぎ払いを記録する")
	check(not events.any(func(e): return e.type=="hydra_cue" and e.payload.cue=="target_locked"),"分離前の薙ぎは元と同じく狙い固定cueを出さない")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"薙ぎ払いの首と判定を正式素材へ渡す")
	await get_tree().process_frame
	bridge._core.step(0.2)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].mode=="idle" and body.effects.is_empty(),"自然終了で首が待ちに戻り判定を消す")
	var first_id: int = actions[0].id
	for tick in 20: bridge._core.step(0.025)
	check(bridge.command("dev_boss_state").value.any(func(t): return t.kind==65 and t.id>first_id),"次の行動でも薙ぎ払いを選べる")
	bridge.command("dev_cancel_flow",{"entity_id":c.id})
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty(),"取消で残留判定を清算する")
	var other: Dictionary = body.necks[5]
	bridge.command("dev_ship_motion",{"position":other.position+Vector2.from_angle(other.angle)*150,"velocity":Vector2.ZERO})
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":other.id,"definition":1})
	check(started.ok,"別の噛みつく首も同じ技を開始する")
	bridge._core.step(0.2)
	bridge.command("dev_damage",{"entity_id":other.id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[5].alive and body.effects.is_empty() and not body.boss_dead,"参加首の消失は判定を消し本体勝利にしない")
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	body=bridge.command("dev_boss_body_state").value[0]
	other=body.necks[0]
	bridge.command("dev_ship_motion",{"position":other.position+Vector2.from_angle(other.look_angle)*150,"velocity":Vector2.ZERO})
	started=bridge.command("dev_boss_technique",{"entity_id":other.id,"definition":1})
	check(started.ok,"分離後も同じ薙ぎ払いの登録を使う")
	bridge._core.step(0.16)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].locked and body.effects.size()>0 and is_equal_approx(body.effects[-1].life,0.1),"分離後は開始頭を中心に伸長して寿命0.1秒の線分を出す")
	held=bridge.checkpoint();bridge._core.step(0.025);expected=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"分離後の薙ぎも保持して戻す");bridge._core.step(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"分離後の復帰も同じ頭と点列になる");bridge.release_checkpoint(held.value)
	bridge._core.step(0.4);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty() and body.necks[0].normal_phase==2,"分離後はholdに入った時点で首の判定を消す")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"本体取消も首の判定を残さない")
	view.queue_free();bridge.dispose();await get_tree().process_frame
	print("[cpp_hydra_sweep] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 既存の首技の正常・中断・表示のケースを移動するビーム弾へ接続する。
func native_hydra_bolt() -> void:
	var move = load("res://data/bosses/hydra_moves/beam_bolt.tres")
	check(move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(move).kind()==&"beam_bolt","ビーム弾は編集値と互換Runnerに分かれる")
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"normal_hold":0.25,"attack_cd":0.05,"bolt_length":150.0,"bolt_width":60.0,"bolt_speed":400.0,"bolt_life":2.0,"beam_dmg":7.0},"beam_bolt")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = [];bridge.subscribe("ビーム弾の記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*220,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==66,"ビームの首から共通フローが自然にビーム弾を選ぶ")
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[3].glow>0.9 and body.effects.is_empty(),"予告は頭の発光だけを出す")
	bridge._core.step(0.011);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].kind=="bolt" and body.effects[0].points.size()==2 and body.effects[0].width==60.0,"発動時刻に固定方向の線分を1つ放つ")
	var effect: Dictionary = body.effects[0].duplicate(true)
	var direction: Vector2 = (effect.points[1]-effect.points[0]).normalized()
	bridge.command("dev_ship_motion",{"position":effect.points[1]+direction*100,"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step_hazards(0.3);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects[0].points[0].distance_to(effect.points[0]+direction*120)<0.001,"世界時間で等速移動し、前の点列から掃引する")
	var expected: Dictionary = body.duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"移動弾の前後の点列・命中済みと時計を保持して戻す")
	bridge._core.step_hazards(0.3);body=bridge.command("dev_boss_body_state").value[0]
	check(body==expected,"復帰後も同じ移動と判定になる");bridge.release_checkpoint(held.value)
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bolt")
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale) and hits.size()==2 and hits[-1].payload.technique==&"beam_bolt" and hits[-1].payload.source==&"hydra","掃引で実HPへ倍率を一度だけ掛け、bolt・技・所有元を記録する")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"生成したshot_visualの正式素材でビーム弾を表示する")
	await get_tree().process_frame
	bridge._core.step(0.3);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[3].mode=="idle" and body.effects.size()==1,"自然終了でも発射済みの弾が残る")
	var first_id: int = actions[0].id
	for tick in 20: bridge._core.step(0.025)
	check(bridge.command("dev_boss_state").value.any(func(t): return t.kind==66 and t.id>first_id),"首の待ち後に次のビーム弾を選ぶ")
	bridge.command("dev_cancel_flow",{"entity_id":c.id});body=bridge.command("dev_boss_body_state").value[0]
	var count: int = body.effects.size()
	check(count>0,"技の取消でも発射済みの弾を残す")
	bridge.command("dev_damage",{"entity_id":body.necks[3].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[3].alive and body.effects.size()==count and not body.boss_dead,"参加首が消失しても発射済みの弾は寿命まで残る")
	bridge._core.step_hazards(2.1);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty(),"寿命で弾を回収する")
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.look_angle)*220,"velocity":Vector2.ZERO})
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1})
	check(started.ok,"分離後も同じビーム弾の実装を開始する")
	bridge._core.step(0.16);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.necks[3].normal_phase==2 and body.necks[3].glow==0.0,"分離後は固定した視線方向へ放ち、その場でholdへ入る")
	bridge.command("dev_cancel_boss",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"本体の退場では弾を全て消す")
	view.queue_free();bridge.dispose();await get_tree().process_frame
	print("[cpp_hydra_bolt] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 既存の首技の正常・中断ケースを予告付き固定ビームへ接続する。
func native_hydra_fixed() -> void:
	var move = load("res://data/bosses/hydra_moves/beam_fixed.tres")
	check(move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(move).kind()==&"beam_fixed","固定ビームの編集ResourceとUID参照を分離する")
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"beam_time":0.4,"normal_hold":0.1,"attack_cd":0.05,"beam_len":600.0,"beam_width":60.0,"beam_dmg":7.0},"beam_fixed")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = [];bridge.subscribe("固定ビームの記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle+0.3)*400,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==67,"共通フローから固定ビームを自然に選ぶ")
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	bridge._core.step(0.01);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].kind=="beam" and is_equal_approx(body.effects[0].delay,0.14) and is_equal_approx(body.effects[0].life,0.4),"予告の最初の更新でcharge-tの遅れを持つビームを作る")
	var first: Dictionary = body.effects[0].duplicate(true)
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle+0.3)*400,"velocity":Vector2.ZERO})
	for tick in 12:
		bridge._core.step(0.01);bridge._core.step_hazards(0.01);bridge.command("dev_boss_body_state")
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[3].glow>0.8 and body.effects[0].points!=first.points and body.effects[0].age<body.effects[0].delay,"予告中は頭と照準に点列を追従させる")
	bridge._core.step(0.03);body=bridge.command("dev_boss_body_state").value[0]
	var effect: Dictionary = body.effects[0].duplicate(true)
	check(body.necks[3].locked and bridge.command("dev_boss_state").value[0].stage==1,"chargeで首の位置と向きを固定する")
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":effect.points[0].lerp(effect.points[1],0.5),"velocity":Vector2.ZERO})
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.025);bridge._core.step_hazards(0.025);body=bridge.command("dev_boss_body_state").value[0]
	var expected: Dictionary = body.duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"予告・ビームの点列・単発命中と時計を保持して戻す")
	bridge._core.step(0.025);bridge._core.step_hazards(0.025);body=bridge.command("dev_boss_body_state").value[0]
	check(body==expected and body.effects[0].points==effect.points,"復帰後も同じ固定位置と判定になる");bridge.release_checkpoint(held.value)
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="beam")
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale) and hits.size()==2 and hits[-1].payload.technique==&"beam_fixed" and hits[-1].payload.source==&"hydra","固定線分の実命中は倍率を一度だけ掛けてbeam・技・所有元を記録する")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"固定ビームの正式shot_visualへ予告と照射を渡す")
	await get_tree().process_frame
	for tick in 22: bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[3].mode=="idle" and body.effects.is_empty(),"照射とholdの自然終了で待ちへ戻る")
	var first_id: int = actions[0].id
	for tick in 20: bridge._core.step(0.025)
	check(bridge.command("dev_boss_state").value.any(func(t): return t.kind==67 and t.id>first_id),"首の待ち後に次の固定ビームを選べる")
	bridge.command("dev_cancel_flow",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"取消で予告と照射を消す")
	bridge._core.set_attack_formation_mode(true)
	body=bridge.command("dev_boss_body_state").value[0]
	if body.necks[3].cd>0: bridge._core.step(body.necks[3].cd+0.001)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(body.facing+TAU*3/8)*400,"velocity":Vector2.ZERO})
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1})
	check(started.ok,"首の直接入口でも固定ビームを開始する")
	bridge._core.step(0.1);bridge.command("dev_damage",{"entity_id":head.id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[3].alive and body.effects.is_empty() and not body.boss_dead,"参加首の消失でビームを消す")
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	body=bridge.command("dev_boss_body_state").value[0]
	if body.necks[3].cd>0: bridge._core.step(body.necks[3].cd+0.001)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.look_angle)*400,"velocity":Vector2.ZERO})
	started=bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1});check(started.ok,"分離後も同じ固定ビームの登録を使う")
	bridge._core.step(0.1);bridge._core.step(0.06);body=bridge.command("dev_boss_body_state").value[0]
	effect=body.effects[0].duplicate(true)
	check(effect.points[0].distance_to(body.necks[3].position)<0.001,"分離後は照射中も動く頭を起点にビームを更新する")
	held=bridge.checkpoint();bridge._core.step(0.025);expected=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"分離後の照射の持続Handleも保持して戻す");bridge._core.step(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"分離後も同じ頭追従の照射へ復帰する");bridge.release_checkpoint(held.value)
	bridge._core.step(0.4);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty() and body.necks[3].normal_phase==2,"分離後はholdへ入った更新で照射を止める")
	bridge.command("dev_cancel_boss",{"entity_id":c.id});view.queue_free();bridge.dispose();await get_tree().process_frame
	print("[cpp_hydra_fixed] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 残っている首の待ちを進め、中断と分離後の未実行ケースだけを確認する。
func native_hydra_fixed_interrupt() -> void:
	var c := hydra_normal_case(false,{}, {"normal_charge":0.15,"beam_time":0.4,"normal_hold":0.1,"attack_cd":0.05,"beam_len":600.0,"beam_width":60.0,"beam_dmg":7.0},"beam_fixed")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_attack_formation_mode(true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	if body.necks[3].cd>0: bridge._core.step(body.necks[3].cd+0.001)
	body=bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(body.facing+TAU*3/8)*400,"velocity":Vector2.ZERO})
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1})
	check(started.ok,"待ちが終わった首の直接入口で固定ビームを開始する")
	if not started.ok: print("開始前: ",head," 開始結果: ",started);bridge.dispose();get_tree().quit(1);return
	bridge._core.step(0.1);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1,"消失前に首が所有する実際の予告形を作る")
	bridge.command("dev_damage",{"entity_id":head.id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[3].alive and body.effects.is_empty() and not body.boss_dead,"参加首の消失でビームを消す")
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	body=bridge.command("dev_boss_body_state").value[0]
	if body.necks[3].cd>0: bridge._core.step(body.necks[3].cd+0.001)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.look_angle)*400,"velocity":Vector2.ZERO})
	started=bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1});check(started.ok,"分離後も同じ固定ビームの登録を使う")
	if not started.ok: print("分離後の開始前: ",head," 開始結果: ",started);bridge.dispose();get_tree().quit(1);return
	bridge._core.step(0.1);bridge._core.step(0.06);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1,"分離後も予告から照射へ進む")
	if body.effects.is_empty(): bridge.dispose();get_tree().quit(1);return
	var effect: Dictionary = body.effects[0].duplicate(true)
	check(effect.points[0].distance_to(body.necks[3].position)<0.001,"分離後は照射中も動く頭を起点にビームを更新する")
	var held: Dictionary = bridge.checkpoint();bridge._core.step(0.025)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"分離後の照射の持続Handleも保持して戻す");bridge._core.step(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"分離後も同じ頭追従の照射へ復帰する");bridge.release_checkpoint(held.value)
	bridge._core.step(0.4);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty() and body.necks[3].normal_phase==2,"分離後はholdへ入った更新で照射を止める")
	bridge.command("dev_cancel_boss",{"entity_id":c.id});bridge.dispose()
	print("[cpp_hydra_fixed_interrupt] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 予告の無害な粒と、毎tick判定する本体の放射を同じ炎部品で確認する。
func native_canis_sirius_flame() -> void:
	var c := canis_move_case("sirius_flame",{"warn":0.12,"duration":0.1,"emit_rate":20.0,"spread":0.0,"particle_speed":0.0,"drag":0.0,"life":0.3,"r_start":8.0,"r_end":8.0,"hit_scale":1.0,"turn":2.0,"advance":40.0,"advance_until":100.0,"damage":7.0,"recover":0.03},false,{"pack_size":0,"lead_max":0},false,0.5)
	check(not c.is_empty(),"シリウスの光を本体・粒・正式表示と同じ制作入口へ渡す")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = []
	bridge.subscribe("連続炎の記録",func(packet): events.append_array(packet.events);return true)
	var records: Dictionary = c.package.records
	check(c.move.make_runner()==null and records.CanisSiriusFlameDefinition.size()==2 and records.CanisSiriusFlameDefinition[1].flame==4 and records.CanisFlameDefinition[2].speed==0.0 and records.CanisFlameDefinition[2].damage==7.0 and records.CanisFlameDefinition[2].particle_life==0.3 and records.BossTechniqueStage.is_empty(),"全編集値と二形態の自由な粒を生成し、method trackを残さない")
	var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(ticket.ok,"猟犬がいない場合もシリウスの光を単独発動する")
	var initial: Dictionary = bridge.checkpoint()
	bridge._core.step(0.06)
	var t: Dictionary = bridge.command("dev_boss_state").value[0]
	var warnings: Array = canis_effects(bridge).filter(func(v): return v.kind==1 and not v.harmful)
	check(t.kind==51 and t.stage==0 and not t.started and semantics_approx(t.age,0.06,"native_canis_sirius_flame:t.age") and semantics_approx(t.emit_left,0.08,"native_canis_sirius_flame:t.emit_left") and warnings.size()==1 and semantics_approx(warnings[0].life,0.3,"native_canis_sirius_flame:warnings[0].life") and semantics_approx(warnings[0].velocity.length(),100.0,"native_canis_sirius_flame:warnings[0].velocity.length()"),"予告中は18個毎秒の無害な粒を出し、固定寿命と速度を使う")
	var warning: Dictionary = bridge.checkpoint()
	bridge.command("dev_ship_motion",{"position":warnings[0].pos,"velocity":Vector2.ZERO})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp==hp,"無害な予告の粒に触れても実際の機体HPを減らさない")
	bridge.restore(warning.value)
	bridge._core.step(0.07)
	t = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var harmful: Array = canis_effects(bridge).filter(func(v): return v.kind==1 and v.harmful)
	check(t.started and t.stage==1 and t.age==0.0 and semantics_approx(t.emit_left,0.4,"native_canis_sirius_flame:t.emit_left") and harmful.size()==1 and body.position.x>0.0,"予告を越えたtickに攻撃時計と発生余りをリセットし、そのtickの前進と放射を行う")
	var active: Dictionary = bridge.checkpoint()
	var particle: Dictionary = harmful[0]
	var reach: float = particle.radius+load("res://data/config.tres").ship_radius
	bridge.command("dev_ship_motion",{"position":particle.pos+Vector2(0,reach),"velocity":Vector2.ZERO})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	hp = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp==hp,"粒の半径と機体半径がちょうど接する境界ではstrictな判定で被弾しない")
	bridge.command("dev_ship_motion",{"position":particle.pos+Vector2(0,reach-0.1),"velocity":Vector2.ZERO})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp<hp,"自由な炎の粒の内側へ触れると実際の機体HPを減らす")
	hp = bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge._core.step(0.001)
	check(bridge._core.ship_snapshot().ship_hp<hp,"噴射の一度制限を流用せず、同じ自由な粒が毎tick判定する")
	bridge.command("set_ui_overlay",{"active":false})
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause=="sirius_flame" and e.payload.technique=="sirius_flame"),"シリウスの光という原因と技を共通記録へ届ける")
	bridge.restore(active.value)
	bridge._core.step(0.02)
	var continued: Dictionary = bridge.command("dev_boss_state").value[0].duplicate(true)
	var flames: Array = canis_effects(bridge).duplicate(true)
	check(bridge.restore(active.value).ok,"放射中の時計・発生余り・粒・乱数へ復帰する")
	bridge._core.step(0.02)
	check(bridge.command("dev_boss_state").value[0]==continued and canis_effects(bridge)==flames,"復帰後も本体の旋回・前進と全ての粒を一致させる")
	c.view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value)
	var display = c.view._boss_body_displays.values()[0]
	check(display.technique.flame and display.technique.glow==1.0 and not display.flames.displays.is_empty(),"本体の口元の発光と予告/攻撃の粒を正式表示へ渡す")
	await get_tree().process_frame
	bridge.restore(active.value)
	bridge._core.step(0.101)
	check(bridge.command("dev_boss_state").value[0].stage==2,"放射時間を越えると硬直へ進む")
	bridge._core.step(0.04)
	check(bridge.command("dev_boss_state").value[0].stage==5 and not canis_effects(bridge).is_empty(),"自然終了後も炎の粒は寿命まで残る")
	bridge.restore(active.value)
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	var count: int = canis_effects(bridge).size()
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and canis_effects(bridge).size()<=count and not canis_effects(bridge).is_empty(),"取消は放射の追加を止め、発射済みの粒は残す")
	bridge.restore(active.value)
	bridge.command("dev_remove",{"entity_id":c.id})
	bridge._core.step(0.001)
	check(canis_effects(bridge).is_empty(),"本体消失では残っている無害な粒と攻撃の粒を回収する")
	bridge.restore(initial.value)
	bridge.command("dev_cancel_technique",{"ticket":ticket.value})
	check(canis_effects(bridge).is_empty(),"開始前の取消では粒を生成しない")
	for checkpoint in [initial,warning,active]: bridge.release_checkpoint(checkpoint.value)
	bridge.dispose();c.view.queue_free()
	await native_canis_sirius_flame_flow()

func native_canis_sirius_flame_flow() -> void:
	for name in ["sirius_flame","nova","relay"]:
		var c := canis_move_case(name,{"track_during_warn":false},true,{"pack_size":0 if name=="sirius_flame" else 5,"lead_max":0 if name=="sirius_flame" else 5})
		check(not c.is_empty(),"%s の互換Runner登録を検証して通常フローを生成する" % name)
		if c.is_empty(): get_tree().quit(1);return
		var bridge = c.bridge
		check(c.package.records.BossFlowProgram.size()==1 and bridge.command("dev_boss_flow_state").value.size()==1,"%s の条件確認を実際に接続したフローで行う" % name)
		bridge._core.step(0.01)
		var techniques: Array = bridge.command("dev_boss_state").value
		if name=="sirius_flame": check(not techniques.is_empty() and techniques[0].kind==51,"通常フローでも猟犬の数で制限せずシリウスの光を選べる")
		else: check(techniques.is_empty(),"%s は通常フローで必要な6体がそろうまで選ばない" % name)
		bridge.dispose();c.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_new_flow] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 既存の首技の正常・中断ケースを3枚の風刃と持続形状の世界時計へ接続する。
func native_hydra_blades() -> void:
	var edits := {"normal_charge":0.15,"blade_interval":0.08,"normal_hold":0.2,"attack_cd":0.05,"blade_size":60.0,"blade_width":40.0,"blade_speed":300.0,"blade_life":3.0,"blade_spread":1.0,"bite_dmg":7.0}
	var move = load("res://data/bosses/hydra_moves/wind_blades.tres")
	check(move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(move).kind()==&"wind_blades","風刃は編集値と互換Runnerに分かれる")
	var c := hydra_normal_case(true,{},edits,"wind_blades")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = [];bridge.subscribe("風刃の記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(body.facing+TAU/8)*400,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==68,"渦の首から共通フローが自然に風刃を選ぶ")
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[1].glow>0.9 and body.effects.is_empty(),"予告中は発光と狙いの動きだけを出す")
	bridge._core.step(0.011);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].kind=="wind_blade" and body.effects[0].points.size()==13,"発動時刻に半楕円の13点の刃を1枚放つ")
	if body.effects.is_empty(): bridge.dispose();get_tree().quit(1);return
	var effect: Dictionary = body.effects[0].duplicate(true)
	var origin: Vector2 = (effect.points[0]+effect.points[12])*0.5
	var direction: Vector2 = (effect.points[6]-origin).normalized()
	bridge.command("dev_ship_motion",{"position":effect.points[6]+direction*35,"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step_hazards(0.2);body=bridge.command("dev_boss_body_state").value[0]
	var expected: Dictionary = body.duplicate(true)
	check(body.effects[0].points[6].distance_to(effect.points[6]+direction*60)<0.001,"世界時間で刃全体を等速移動させる")
	check(held.ok and bridge.restore(held.value).ok,"13点・移動前後の点列・命中と時計を保持して戻す")
	bridge._core.step_hazards(0.2);body=bridge.command("dev_boss_body_state").value[0]
	check(body==expected,"復帰後も同じ移動の掃引判定になる");bridge.release_checkpoint(held.value)
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="wind_blade")
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale) and hits.size()==2 and hits[-1].payload.technique==&"wind_blades" and hits[-1].payload.source==&"hydra","掃引した折れ線が実HPへ一度倍率を掛け、風刃・技・所有元を記録する")
	bridge._core.step_hazards(0.0);check(bridge.command("dev_boss_body_state").value[0]==body,"世界dt0では点列と時計を止める")
	bridge._core.step(0.081);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==2 and ((body.effects[1].points[0]+body.effects[1].points[12])*0.5).distance_to(origin)<0.001,"間隔ごとに1枚だけ放ち、分離前は開始位置を固定する")
	bridge._core.step(0.08);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==3 and body.effects.all(func(e): return e.points.size()==13),"最後の間隔で3枚目を放つ")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"風刃の正式shot_visualへ13点の形を渡す")
	await get_tree().process_frame
	bridge._core.step(0.22);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[1].mode=="idle" and body.effects.size()==3,"自然終了でも発射した3枚の刃を残す")
	var first_id: int = actions[0].id
	bridge.command("dev_ship_motion",{"position":body.necks[1].position+Vector2.from_angle(body.facing+TAU/8)*400,"velocity":Vector2.ZERO})
	for tick in 20: bridge._core.step(0.025)
	check(bridge.command("dev_boss_state").value.any(func(t): return t.kind==68 and t.id>first_id),"首の待ち後に次の風刃を選ぶ")
	bridge.command("dev_cancel_flow",{"entity_id":c.id});body=bridge.command("dev_boss_body_state").value[0]
	var count: int = body.effects.size()
	check(count>=3,"技の取消でも放った刃を残す")
	bridge.command("dev_damage",{"entity_id":body.necks[1].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[1].alive and body.effects.size()==count and not body.boss_dead,"参加首の消失でも刃を寿命まで残す")
	bridge._core.step_hazards(3.1);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty(),"刃の寿命で点列と残留所有を回収する")
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	bridge._core.set_attack_formation_mode(true)
	body=bridge.command("dev_boss_body_state").value[0]
	if body.necks[1].cd>0: bridge._core.step(body.necks[1].cd+0.001)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.look_angle)*400,"velocity":Vector2.ZERO})
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1})
	check(started.ok,"分離後も同じ風刃の実装を開始する")
	if not started.ok: bridge.dispose();get_tree().quit(1);return
	events.clear();bridge._core.step(0.16);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and ((body.effects[0].points[0]+body.effects[0].points[12])*0.5).distance_to(body.necks[1].position)<0.001,"分離後の1枚目は今の頭から放つ")
	bridge._core.step(0.08);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==2 and ((body.effects[1].points[0]+body.effects[1].points[12])*0.5).distance_to(body.necks[1].position)<0.001,"分離後の2枚目も動いた頭を起点にする")
	bridge._core.step(0.08);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==3 and body.necks[1].normal_phase==2,"分離後は3枚目を出す時点でholdへ入り刃は残る")
	check(events.filter(func(e): return e.type=="hydra_cue" and e.payload.cue=="attack_started" and e.payload.technique=="wind_blades").size()==1,"分離後の開始cueは3枚で1回だけ出す")
	bridge.command("dev_cancel_boss",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"本体取消では風刃も全て消す")
	view.queue_free();bridge.dispose();await get_tree().process_frame
	# 同じ持続形状は、Sourceの成長中の早期returnでは時計も止まる。
	c=hydra_regrow_case(false,{},edits,"wind_blades");bridge=c.bridge
	bridge._core.set_attack_formation_mode(true);bridge._core.set_motion_context(Vector2(1600,0),Vector2.ZERO,Vector2(2500,1800));bridge._core.step(4.0)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(body.facing+TAU/3)*400,"velocity":Vector2.ZERO})
	started=bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1});check(started.ok,"成長前の3首の風刃を開始する")
	if started.ok:
		bridge._core.step(0.16);body=bridge.command("dev_boss_body_state").value[0]
		var prior: Dictionary = body.effects[0].duplicate(true)
		bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp*(1.0-c.package.records.HydraRegrowDefinition[0].growth_first+0.01),"cause":"shot"})
		bridge._core.step(0.01);bridge._core.step_hazards(0.05);body=bridge.command("dev_boss_body_state").value[0]
		check(body.growth_left>0 and body.effects.size()==1 and body.effects[0]==prior,"成長中の早期returnでは発射済みの刃の点列と時計を止める")
		bridge._core.step(0.11);bridge._core.step(0.01);bridge._core.step_hazards(0.01);body=bridge.command("dev_boss_body_state").value[0]
		check(body.effects.size()==1 and is_equal_approx(body.effects[0].age,0.01),"成長後の通常更新から同じ世界時計を再開する")
	bridge.dispose()
	print("[cpp_hydra_blades] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 未成立だった分離後の起点だけを、空き行再利用がある実経路で確認する。
func native_hydra_blades_origin() -> void:
	var c := hydra_normal_case(false,{}, {"normal_charge":0.15,"blade_interval":0.08,"normal_hold":0.2,"attack_cd":0.05,"blade_size":60.0,"blade_width":40.0,"blade_speed":300.0,"blade_life":3.0,"blade_spread":1.0,"bite_dmg":7.0},"wind_blades")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_attack_formation_mode(true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(body.facing+TAU/8)*400,"velocity":Vector2.ZERO})
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1})
	if not started.ok: print("開始前: ",head," 開始結果: ",started);bridge.dispose();get_tree().quit(1);return
	bridge._core.step(0.16);bridge._core.step(0.08);bridge._core.step(0.08)
	bridge.command("dev_cancel_technique",{"ticket":started.value});bridge._core.step_hazards(3.1)
	body=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	body=bridge.command("dev_boss_body_state").value[0]
	if body.necks[1].cd>0: bridge._core.step(body.necks[1].cd+0.001)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.look_angle)*400,"velocity":Vector2.ZERO})
	started=bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1})
	if not started.ok: print("分離後: ",head," 開始結果: ",started);bridge.dispose();get_tree().quit(1);return
	bridge._core.step(0.16);bridge._core.step(0.08);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==2 and body.effects[0].id<body.effects[1].id and ((body.effects[1].points[0]+body.effects[1].points[12])*0.5).distance_to(body.necks[1].position)<0.001,"空き行の再利用後も2枚目を生成順に出力し、現在の頭を起点にする")
	bridge.dispose();print("[cpp_hydra_blades_origin] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 全技を同じ制作パッケージから通常選択し、決着へつなぐ。
func canis_finish_case(name := "", low := false, limit := -1.0) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.base_hp = 10000.0
	cfg.character_scale = 1.0
	for key in ["boss_finish_slow_time","boss_finish_blast_time","boss_finish_relic_appear_time","boss_finish_relic_hold_time","boss_finish_relic_collect_time","boss_finish_clear_time","time_up_charge_time"]: cfg.set(key,0.02)
	for key in ["death_freeze_time","death_explosion_time","death_game_over_time"]: cfg.set(key,0.01)
	var boss = load("res://data/bosses/canis_major.tres").duplicate(true)
	boss.speed = 0.0
	boss.params.initial_wait = 0.0
	boss.params.phase_time = 0.01
	var rules = load("res://data/bosses/ai/canis_major_action_rules.tres").duplicate(true)
	var flow = load("res://data/bosses/ai/canis_major_flow.tres").duplicate(true)
	if not name.is_empty():
		flow.sections = [{"request":"any","allowed_techniques":[name],"cap":3.0,"action_count":1,"next":0,"weights":{"single":1.0,"combo":1.0,"major":1.0}}]
	var stage := RuntimeStage.new()
	stage.boss_enabled = false
	stage.time_limit = limit
	stage.legendary_module_id = ContentManager.stage(3).legendary_module_id
	var package: Dictionary = builder.boss_package(boss,cfg,stage,{"rules":rules,"flow":flow})
	if package.is_empty(): return {}
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":187,"mode":1,"stage_id":"B_canis_major_finish","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); return {}
	bridge.start(187,{"position":Vector2(500,0)})
	var events: Array = []
	bridge.subscribe("確認",func(packet): events.append_array(packet.events); return true)
	bridge.command("dev_ship_motion",{"position":Vector2(500,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(500,0),Vector2(500,0),Vector2(2000,1500))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	if low:
		var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
		bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp*0.6,"cause":"debug","no_crit":true})
		bridge._core.step(0.01)
		bridge._core.step(0.01)
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,1.0)
	bridge.subscribe("表示",view.receive_frame)
	return {"bridge":bridge,"id":id,"package":package,"events":events,"view":view,"scope":scope}

func native_canis_finish() -> void:
	var activated: Array[String] = []
	var cues := {"command":"command","howl":"howl","pounce":"pounce","sirius":"sirius","bay":"pounce","blaze":"blaze_ignite","stream":"stream_launch","hunt":"stream_launch","hunt_pounce":"stream_launch","nova":"nova_flash","relay":"relay_fire","sirius_flame":"flame_start"}
	for name: String in cues:
		var f := canis_finish_case(name,name in ["sirius","blaze","hunt","nova","relay","sirius_flame"])
		check(not f.is_empty(),"全技の共通パッケージを開始する: "+name)
		if f.is_empty(): get_tree().quit(1); return
		var bridge = f.bridge
		check(f.package.records.BossTechniqueDefinition.size()==24 and f.package.records.CanisStreamDefinition.size()==2 and f.package.records.CanisPounceDefinition.size()==2,"連携の内包技も同じ24件の定義を参照する: "+name)
		var selected := false
		var emitted := false
		for tick in 1200:
			bridge._core.step(0.01)
			var states: Array = bridge.command("dev_boss_state").value
			selected = selected or states.any(func(row): return row.technique==name)
			bridge.collect_frame()
			emitted = f.events.any(func(event): return event.type==&"canis_cue" and event.payload.cue==cues[name])
			if emitted: break
		check(selected and emitted,"制作の条件・予算・通常選択から実際に発動する: "+name)
		if selected and emitted: activated.append(name)
		var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
		check(body.phase==(2 if name in ["sirius","blaze","hunt","nova","relay","sirius_flame"] else 1),"通常HP・低HPに対応する形態を選ぶ: "+name)
		check(f.view.apply_frame(bridge.read_render(Rect2(-2000,-1500,4000,3000)).value) and f.view._boss_body_displays.values()[0].technique.get("technique","")==name,"全技の発動状態を正式表示へ渡す: "+name)
		var clocks: Dictionary = bridge.command("dev_boss_flow_state").value[0]
		bridge._core.step(0.001)
		check(semantics_approx(bridge.command("dev_boss_flow_state").value[0].clock,clocks.clock,"native_canis_finish:flow_clock:"+name),"技中はフローの時計を進めない: "+name)
		bridge.dispose()
		f.view.queue_free()
	print("[cpp_canis_finish] 通常選択から実発動=",activated)
	if semantics_strict():get_tree().quit(1 if failed else 0);return
	var f := canis_finish_case("nova",true)
	var bridge = f.bridge
	bridge._core.step(0.01)
	bridge._core.step(0.02)
	check(bridge.command("dev_kill",{"entity_id":f.id,"cause":"debug"}).ok,"低HP形態の本体を撃破できる")
	check(centaurus_finish_steps(bridge,1) and bridge.read_frame().value.ui.phase==RunIds.Phase.Finishing,"撃破から共通の決着へ進む")
	check(bridge.command("dev_boss_body_state").value[0].flames.is_empty() and bridge.command("dev_boss_body_state").value[0].nova.is_empty(),"撃破で残留炎と閃光を解放する")
	centaurus_finish_steps(bridge,23)
	var frame: Dictionary = bridge.read_frame().value
	check(frame.result!=null and frame.result.kind=="Clear" and f.events.any(func(event): return event.type==&"clear_banner"),"CLEARと勝利通知を一度確定する")
	check(bridge.collect_frame().ok and bridge.delivery_error.ok,"決着と勝利を共通の通知経路へ渡す")
	bridge.dispose()
	f.view.queue_free()
	f = canis_finish_case("",false,0.01)
	bridge = f.bridge
	centaurus_finish_steps(bridge,2)
	check(bridge.command("dev_boss_body_state").value[0].mode==3,"時間切れで最終攻撃を始める")
	f.view.apply_frame(bridge.read_render(Rect2(-2000,-1500,4000,3000)).value)
	check(f.view._boss_final_beams.size()==1 and is_equal_approx(f.view._boss_final_beams.values()[0].width,bridge.command("dev_boss_body_state").value[0].final_width),"最終攻撃の幅と位置を共通の正式ビームへ渡す")
	centaurus_finish_steps(bridge,24)
	frame = bridge.read_frame().value
	check(frame.result!=null and frame.result.kind=="Death" and frame.result.last_damage.cause==&"final_strike","時間切れの最終攻撃から敗北へ進む")
	bridge.dispose()
	f.view.queue_free()
	f = canis_finish_case("relay",true)
	bridge = f.bridge
	bridge._core.step(0.01)
	check(bridge.command("abort",{"reason":0}).ok and bridge.read_frame().value.result.kind=="Abort" and bridge.command("dev_boss_body_state").value[0].mode==5,"途中中断は本体を取消し、勝利を付けずに終える")
	check(bridge.command("dev_boss_body_state").value[0].flames.is_empty(),"途中中断で残留攻撃を解放する")
	bridge.dispose()
	f.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_finish] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_canis_finish_display() -> void:
	var f := canis_finish_case()
	check(not f.is_empty(),"全技を持つ表示確認のランを開始する")
	if f.is_empty(): get_tree().quit(1); return
	var assets_ready := true
	for asset: Dictionary in f.package.visuals:
		if asset.has("canis_flame") or asset.has("canis_burst"): assets_ready = not asset.path.is_empty() and f.scope.resources.has(asset.path) and assets_ready
	check(assets_ready,"全技の炎と爆発が外部表示資源を参照する")
	check(f.view.apply_frame(f.bridge.read_render(Rect2(-2000,-1500,4000,3000)).value),"全技の表示資源を正式表示へ接続する")
	var flames = f.view._boss_body_displays.values()[0].flames
	check(flames.presets.size()==f.package.records.CanisFlameDefinition.size() and flames.burst_presets.size()==2 and flames.burning_preset!=null and flames.trail_preset!=null,"全技分の炎・爆発・燃える猟犬・焼け跡を保持する")
	f.bridge.dispose()
	f.view.queue_free()
	await get_tree().process_frame
	print("[cpp_canis_finish_display] failures=",failed)
	get_tree().quit(1 if failed else 0)

func hydra_major_case(selected_move: String, edits: Dictionary, flowing := false, body_changes := {}, config_changes := {}) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true);cfg.planet_radius=0.0
	for key in config_changes:cfg.set(key,config_changes[key])
	var definition = load("res://data/bosses/hydra.tres").duplicate(true);definition.speed=0.0
	definition.params.merge({"head_hp":10.0,"growth_time":0.1,"tech_cd":0.05,"debris_dmg":0.0},true)
	definition.params.merge(body_changes,true)
	if selected_move!="curve": definition.params.combo_cooldown=0.05
	var move = load("res://data/bosses/hydra_moves/%s.tres" % selected_move).duplicate(true);move.assign_values(edits)
	var package: Dictionary = builder.hydra_technique_package(definition,move,cfg)
	if package.is_empty(): check(false,"大技の編集値を生成する");return {}
	if flowing:
		var rules = load("res://data/bosses/ai/hydra_action_rules.tres").duplicate(true)
		rules.techniques.assign([move]);rules.combos={};rules.conditions={selected_move:{}};rules.condition_groups={};rules.graph_nodes={};rules.selection_bias={}
		var flow = load("res://data/bosses/ai/hydra_flow.tres").duplicate(true)
		flow.sections=flow.sections.slice(0,1) if move.category==&"combo" else flow.sections.slice(2,3)
		flow.sections[0].next=0;flow.sections[0].fallback=0
		if move.category==&"combo":flow.sections[0].weights={"combo":100.0}
		if move.category==&"combo": flow.sections[0].request="any";flow.sections[0].weights={"combo":100.0,"major":100.0}
		var records: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		if records.is_empty(): check(false,"大技の共通フローを生成する");return {}
		for key in records: package.records[key]=records[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":372,"mode":1,"stage_id":"B_hydra_"+selected_move,"profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"ヒュドラ大技の型付き生成物を読み込む")
	if not configured.ok: print(configured);return {}
	bridge.start(372,{"position":Vector2(800,0)})
	bridge.subscribe("確認",func(_frame): return true);bridge._core.set_attack_formation_mode(true)
	bridge._core.set_motion_context(Vector2(800,0),Vector2(800,0),Vector2(1400,1000))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp*0.4,"cause":"shot"});bridge._core.step(0.11)
	return {"bridge":bridge,"package":package,"cfg":cfg,"id":id,"move":move}

func hydra_move_view(c: Dictionary):
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(c.bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"技の点列と予告を正式なshot_visualへ渡す")
	return view

func native_hydra_curve() -> void:
	var c := hydra_major_case("curve",{"warning_time":0.15,"performance_time":0.55,"curve_delay":0.12,"curve_time":0.35,"curve_turn":0.45,"curve_lag":1.1,"beam_len":600.0,"beam_width":60.0,"beam_dmg":7.0,"tech_recovery":0.05,"cooldown":0.1},true)
	if c.is_empty(): get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	var events: Array=[];bridge.subscribe("曲線の記録",func(packet):events.append_array(packet.events);return true)
	check(c.move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(c.move).kind()==&"curve","編集Resourceと互換RunnerをUID付きで分ける")
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==72,"五首の共通フローから曲線ビームを自然に選ぶ")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	check(body.count==5 and body.effects.size()==5 and body.effects.all(func(e):return e.points.size()==25 and is_equal_approx(e.delay,0.12) and is_equal_approx(e.life,0.35)),"予告開始で全首に24区間の曲線を作り、独立した遅れと寿命を持つ")
	var first: Dictionary=body.effects[0].duplicate(true)
	var angle: float=body.necks[0].angle
	var at: Vector2=first.points[0]
	for j in range(1,25):at+=Vector2.from_angle(angle-float(j)/24.0*1.1)*600.0/24.0
	check(at.distance_to(first.points[-1])<0.001,"ラジアンの軌跡差と24分割の点列がSourceの式に一致する")
	var facing: float=body.facing
	bridge._core.step(0.1);bridge._core.step_hazards(0.1);body=bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(body.facing,facing) and body.effects[0].age<body.effects[0].delay,"予告中は本体を回さず、形だけの時計を進める")
	bridge._core.step(0.05);bridge._core.step_hazards(0.05);body=bridge.command("dev_boss_body_state").value[0]
	check(body.facing>facing and body.effects[0].points!=first.points,"発動したtickから本体を回して全首の曲線を更新する")
	var point: Vector2=body.effects[0].points[5]
	bridge.command("dev_ship_motion",{"position":point,"velocity":Vector2.ZERO})
	var hp: float=bridge._core.ship_snapshot().ship_hp
	var held: Dictionary=bridge.checkpoint();bridge._core.step(0.01);bridge._core.step_hazards(0.01);body=bridge.command("dev_boss_body_state").value[0];var expected: Dictionary=body.duplicate(true)
	check(hp>bridge._core.ship_snapshot().ship_hp,"曲線の掃引判定が実際の機体HPを減らす")
	check(held.ok and bridge.restore(held.value).ok,"参加首・曲線・本体向き・別時計を保持して戻す")
	bridge._core.step(0.01);bridge._core.step_hazards(0.01);check(bridge.command("dev_boss_body_state").value[0]==expected,"途中復帰後に同じ点列と時計へ進む")
	bridge.command("dev_boss_body_state")
	check(events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="beam" and e.payload.technique=="curve" and e.payload.source=="hydra"),"命中はbeam・curve・hydraを共通の通知へ出す")
	var view=hydra_move_view(c);await get_tree().process_frame
	bridge.restore(held.value);body=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":body.necks[0].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==4 and bridge.command("dev_boss_state").value[0].stage==1,"参加首1本の消失はその曲線だけを消し、残りの首で続ける")
	bridge.restore(held.value);bridge.command("dev_cancel_flow",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"途中取消で全ての持続曲線を回収する")
	bridge.restore(held.value)
	for tick in 36:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty(),"曲線の持続時間で判定を消す")
	for tick in 60:bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value.any(func(t):return t.id>first_id and t.kind==72),"技の自然終了と余白の後に次の大技を選べる")
	bridge.restore(held.value);body=bridge.command("dev_boss_body_state").value[0]
	for n in body.necks:bridge.command("dev_damage",{"entity_id":n.id,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty() and bridge.command("dev_boss_state").value[0].stage==7,"全参加首の消失では大技を中断する")
	bridge.release_checkpoint(held.value);bridge.dispose();view.queue_free();await get_tree().process_frame
	print("[cpp_hydra_curve] failures=",failed);get_tree().quit(1 if failed else 0)

func hydra_grid_separate(c: Dictionary) -> void:
	var bridge=c.bridge
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"})
	bridge._core.step(0.11);bridge._core.step(0.001);bridge._core.step(1.21)
	bridge.command("dev_ship_motion",{"position":Vector2(-200,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(-200,0),Vector2.ZERO,Vector2(1400,1000))

func native_hydra_grid() -> void:
	var edits := {"warning_time":0.15,"performance_time":0.8,"normal_charge":0.1,"grid_time":0.35,"beam_width":60.0,"beam_dmg":7.0,"tech_recovery":0.05,"cooldown":0.1}
	var c := hydra_major_case("grid",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":true})
	check(c.move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(c.move).kind()==&"grid" and c.package.records.HydraGridSlot.size()==8,"格子の編集Resourceと配置の順序付き生成値を分ける")
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"分離前には格子を開始しない")
	hydra_grid_separate(c)
	bridge._core.set_motion_context(Vector2(-200,0),Vector2.ZERO,Vector2(100,80));bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value.is_empty(),"狭い表示領域では安全な格子を作れず選択しない")
	bridge._core.set_motion_context(Vector2(-200,0),Vector2.ZERO,Vector2(1400,1000))
	for tick in 40:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==73,"分離後の共通フローから格子ビームを自然に選ぶ")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var t: Dictionary=actions[0];var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var source = load("res://data/bosses/hydra.tres")
	var maximum: float=c.cfg.draw_length*c.cfg.base_max_speed/c.cfg.base_max_speed
	var reference: Dictionary=load("res://scripts/bosses/hydra_grid.gd").build(Rect2(Vector2(-1400,-1000),Vector2(2800,2000)).intersection(body.arena),Vector2(-200,0),8,source.params,c.cfg.ship_radius,maximum)
	check(not reference.is_empty() and t.grid_name==String(reference.name) and is_equal_approx(t.grid_length,reference.length) and t.grid_bearer.distance_to(reference.bearer)<0.001,"領域・回転・倍率・経路予算をSourceの配置関数へ照合する")
	var equal: bool = not reference.is_empty() and reference.beams.size()==t.grid_starts.size()
	if equal:
		for i in reference.beams.size():equal=equal and t.grid_starts[i].distance_to(reference.beams[i][0])<0.001 and t.grid_ends[i].distance_to(reference.beams[i][1])<0.001
	check(equal,"優先順で選んだ全ビームの始点と終点がSourceに一致する")
	check(t.positioning and t.elapsed==0.0 and t.performance_time==0.0 and body.effects.is_empty(),"配置中は予告と攻撃の時計を止めて形を出さない")
	var preparing: Dictionary=bridge.checkpoint();bridge._core.step(0.1);var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true);var expected_t: Dictionary=bridge.command("dev_boss_state").value[0].duplicate(true)
	check(preparing.ok and bridge.restore(preparing.value).ok,"配置計画・到着集合・不死首の目標を保持して戻す");bridge._core.step(0.1)
	check(bridge.command("dev_boss_body_state").value[0]==expected and bridge.command("dev_boss_state").value[0]==expected_t,"配置途中の復帰後も同じ操舵と時計へ進む")
	var ready := false
	for tick in 600:
		bridge._core.step(0.02);bridge._core.step_hazards(0.02)
		t=bridge.command("dev_boss_state").value[0]
		if t.stage==7:break
		if not t.positioning and not bridge.command("dev_boss_body_state").value[0].effects.is_empty():ready=true;break
	body=bridge.command("dev_boss_body_state").value[0]
	check(ready and body.effects.size()==8 and body.bearer.position.distance_to(t.grid_bearer)<=6.0,"全首と不死首の配置完了後に予告を進めて8本の格子を放つ")
	if not ready:print(t);bridge.dispose();get_tree().quit(1);return
	check(body.effects.all(func(e):return e.points.size()==2 and is_equal_approx(e.delay,0.1) and is_equal_approx(e.life,0.35)),"格子は線分・個別の遅れ・寿命を持つ")
	check(body.necks.all(func(n):return n.points[-1].distance_to(n.position)<0.001),"大技の位置を確定した後に首点列を1回だけ同期する")
	var view=hydra_move_view(c);await get_tree().process_frame
	var firing: Dictionary=bridge.checkpoint();var events: Array=[];bridge.subscribe("格子の記録",func(packet):events.append_array(packet.events);return true)
	bridge._core.set_run_guards({"invincible":false});var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":body.effects[0].points[0].lerp(body.effects[0].points[1],0.5),"velocity":Vector2.ZERO})
	for tick in 7:bridge._core.step(0.02);bridge._core.step_hazards(0.02);bridge.command("dev_boss_body_state")
	check(hp>bridge._core.ship_snapshot().ship_hp and events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="beam" and e.payload.technique=="grid"),"格子の実命中とbeam・gridの記録を同じ経路へ渡す")
	bridge.restore(firing.value);body=bridge.command("dev_boss_body_state").value[0];bridge.command("dev_damage",{"entity_id":body.necks[0].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_body_state").value[0].effects.size()==7 and bridge.command("dev_boss_state").value[0].stage==1,"1本の参加首が消えても残りの格子を続ける")
	bridge.restore(firing.value);bridge.command("dev_cancel_flow",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"取消で格子と配置の所有を解放する")
	bridge.restore(firing.value)
	for tick in 50:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"格子の寿命が終われば線分を消す")
	for tick in 80:bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value.any(func(a):return a.id>first_id and a.kind==73),"自然終了と余白を過ぎると次の行動へ戻る")
	bridge.restore(firing.value);body=bridge.command("dev_boss_body_state").value[0]
	for n in body.necks:bridge.command("dev_damage",{"entity_id":n.id,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.01);check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"全参加首の消失で格子を中断する")
	bridge.release_checkpoint(preparing.value);bridge.release_checkpoint(firing.value);bridge.dispose();view.queue_free()
	c=hydra_major_case("grid",edits,false,{"formation_timeout":0.01});bridge=c.bridge;hydra_grid_separate(c)
	check(bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"配置待ちの直接入口を開始する");bridge._core.step(0.02)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"配置の制限時間を超えると攻撃を出さず中断する");bridge.dispose()
	c=hydra_major_case("grid",edits,false,{}, {"draw_length":1.0});bridge=c.bridge;hydra_grid_separate(c)
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"一筆の長さ予算に経路が入らないと格子を選べない");bridge.dispose()
	await get_tree().process_frame;print("[cpp_hydra_grid] failures=",failed);get_tree().quit(1 if failed else 0)

## 瓦礫の通常技を、首技の正常・中断と同じ入口で確認する。
func native_hydra_rubble() -> void:
	var name := "rubble_fan" if "--fan" in OS.get_cmdline_user_args() else "rubble_lump"
	var fan := name=="rubble_fan"
	var move = load("res://data/bosses/hydra_moves/%s.tres" % name)
	check(move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(move).kind()==StringName(name),"瓦礫の編集値と互換Runnerを分ける")
	var edits := {"normal_charge":0.15,"normal_hold":0.25,"attack_cd":0.05,"lump_speed":400.0,"lump_dmg":7.0}
	if fan: edits.merge({"rubble_count":6,"rubble_spread":1.3,"rubble_small_radius":16.0})
	else: edits.lump_r=26.0
	var c := hydra_normal_case(true,{},edits,name)
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = [];bridge.subscribe("瓦礫の記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[2]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*300,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==(81 if fan else 80),"共通フローが瓦礫の首から自然に選ぶ")
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[2].glow>0.9 and body.effects.is_empty(),"予告時刻は頭だけを発光する")
	bridge._core.step(0.011);body=bridge.command("dev_boss_body_state").value[0]
	var count: int = 6 if fan else 1
	check(body.effects.size()==count and body.effects[0].kind=="rubble" and body.effects[0].width==(32.0 if fan else 52.0),"発動時刻に同じ部品で数・幅・敵の行を作る")
	var effect: Dictionary = body.effects[0].duplicate(true)
	var rubble: Array = bridge._core.enemies_snapshot().filter(func(e): return e.type=="hydra_rubble" and not e.dead)
	check(rubble.size()==count,"各瓦礫は判定だけでなく敵の行を持つ")
	if fan:
		var first_velocity := Vector2(rubble[0].vel[0],rubble[0].vel[1])
		var last_velocity := Vector2(rubble[-1].vel[0],rubble[-1].vel[1])
		check(is_equal_approx(first_velocity.length(),400.0) and is_equal_approx(absf(angle_difference(first_velocity.angle(),last_velocity.angle())),1.3),"6個の散弾はラジアンの広がりと同じ初速を保つ")
	bridge.command("dev_ship_motion",{"position":effect.points[0],"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step_hazards(0.01);body=bridge.command("dev_boss_body_state").value[0]
	var expected: Dictionary = body.duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"瓦礫の世代付き参照・点列と時計を途中保持して戻す")
	bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"復帰後も同じ追従と判定になる");bridge.release_checkpoint(held.value)
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="rubble")
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale) and hits.size()==2 and hits[-1].payload.technique==StringName(name) and hits[-1].payload.source==&"hydra","実HP・倍率1回・rubble原因と技と所有元を保つ")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"正式表示へ瓦礫の敵とshapeを渡す")
	await get_tree().process_frame
	bridge._core.step(0.3);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[2].mode=="idle" and body.effects.size()==count,"自然終了でも飛んだ瓦礫が残る")
	bridge._core.step_hazards(0.01);body=bridge.command("dev_boss_body_state").value[0]
	var moved: Array = bridge._core.enemies_snapshot().filter(func(e): return e.type=="hydra_rubble" and not e.dead)
	check(body.effects[0].points[0].distance_to(effect.points[0])>0.01 and body.effects[0].points[0].distance_to(Vector2(moved[0].pos[0],moved[0].pos[1]))<0.001,"減速する敵の行へ点列を追従する")
	head=body.necks[2]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*500,"velocity":Vector2.ZERO})
	var first_id: int = actions[0].id
	for tick in 20: bridge._core.step(0.025)
	check(bridge.command("dev_boss_state").value.any(func(t): return t.kind==(81 if fan else 80) and t.id>first_id),"待ち後に次の瓦礫技を選ぶ")
	bridge.command("dev_cancel_flow",{"entity_id":c.id});body=bridge.command("dev_boss_body_state").value[0]
	count=body.effects.size()
	check(count>0,"取消でも飛んだ瓦礫を残す")
	bridge.command("dev_damage",{"entity_id":body.necks[2].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[2].alive and body.effects.size()==count,"参加首の消失後も瓦礫が残る")
	var broken: Array = bridge._core.enemies_snapshot().filter(func(e): return e.type=="hydra_rubble" and not e.dead)
	bridge.command("dev_remove",{"entity_id":broken[0].id});bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_body_state").value[0].effects.size()==count-1,"消失した瓦礫の判定だけを回収し世代再利用へ追従しない")
	bridge._core.step_hazards(6.1)
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"寿命で瓦礫の判定を回収する")
	view.queue_free();bridge.dispose();await get_tree().process_frame
	print("[cpp_hydra_",name,"] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_hydra_rubble_retry() -> void:
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"normal_hold":0.25,"attack_cd":0.05,"lump_speed":400.0,"lump_dmg":7.0,"lump_r":26.0},"rubble_lump")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[2]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*500,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var first_id: int = bridge.command("dev_boss_state").value[0].id
	bridge._core.step(0.41)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[2]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*500,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if bridge.command("dev_boss_state").value.any(func(t): return t.kind==80 and t.id>first_id): break
	check(bridge.command("dev_boss_state").value.any(func(t): return t.kind==80 and t.id>first_id),"正規の位置条件と待ちを満たして次の瓦礫技を選ぶ")
	bridge.command("dev_cancel_flow",{"entity_id":c.id})
	var broken: Array = bridge._core.enemies_snapshot().filter(func(e): return e.type=="hydra_rubble" and not e.dead)
	body=bridge.command("dev_boss_body_state").value[0]
	var count: int = body.effects.size()
	bridge.command("dev_remove",{"entity_id":broken[0].id});bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_body_state").value[0].effects.size()==count-1,"技の取消後も生存参照を調べ、消失した瓦礫だけを回収する")
	bridge.dispose();print("[cpp_hydra_rubble_retry] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_rubble_retire() -> void:
	var c := hydra_normal_case(false,{}, {"normal_charge":0.15,"normal_hold":0.25,"attack_cd":0.05,"lump_speed":400.0,"lump_dmg":7.0,"lump_r":26.0},"rubble_lump")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[2]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*500,"velocity":Vector2.ZERO})
	bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1});bridge._core.step(0.16)
	var rubble: Array = bridge._core.enemies_snapshot().filter(func(e): return e.type=="hydra_rubble" and not e.dead)
	bridge.command("dev_remove",{"entity_id":rubble[0].id});bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"消失した瓦礫の世代参照を調べ、その判定を回収する")
	bridge.dispose();print("[cpp_hydra_rubble_retire] failures=",failed);get_tree().quit(1 if failed else 0)

func hydra_pincer_grow(c: Dictionary) -> void:
	var body: Dictionary=c.bridge.command("dev_boss_body_state").value[0]
	c.bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp*0.3,"cause":"shot"});c.bridge._core.step(0.11)

func native_hydra_pincer() -> void:
	var edits := {"warning_time":0.15,"performance_time":0.7,"pincer_delay":0.1,"pincer_time":0.3,"pincer_open_angle":0.8,"pincer_close_angle":0.12,"beam_len":600.0,"beam_width":60.0,"beam_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("beam_pincer",edits,true,{"combo_cooldown":0.1})
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	check(c.move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(c.move).kind()==&"beam_pincer","挟撃の編集Resourceと互換Runnerを分けてUID参照を維持する")
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"ビームの首が1本だけなら挟撃を開始しない")
	hydra_pincer_grow(c)
	for tick in 40:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==74,"コンボ区間の共通フローから挟撃を自然に選ぶ")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	check(body.necks.filter(func(n):return n.mode=="beam_pincer").size()==2 and body.necks[3].mode=="beam_pincer" and body.necks[6].mode=="beam_pincer" and body.effects.is_empty(),"首順で異なる2本のビーム首だけを参加させ、予告中は形を出さない")
	var passive_angle: float=body.necks[0].angle
	for tick in 15:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	var t: Dictionary=bridge.command("dev_boss_state").value[0];body=bridge.command("dev_boss_body_state").value[0]
	check(t.stage==1 and t.pincer_aims.size()==2 and body.effects.size()==2 and not is_equal_approx(passive_angle,body.necks[0].angle),"予告後に2本を発射し、非参加首は普段の操舵を続ける")
	check(body.effects.all(func(e):return e.points.size()==2 and is_equal_approx(e.delay,0.1) and is_equal_approx(e.life,0.3)),"挟撃は遅れと寿命が別の2線分として生成する")
	var from: Array=[body.effects[0].points[0],body.effects[1].points[0]];var aims: PackedFloat64Array=t.pincer_aims.duplicate()
	bridge.command("dev_ship_motion",{"position":Vector2(900,-600),"velocity":Vector2.ZERO});bridge._core.set_motion_context(Vector2(900,-600),Vector2.ZERO,Vector2(1400,1000))
	bridge._core.step(0.12);bridge._core.step_hazards(0.12);t=bridge.command("dev_boss_state").value[0];body=bridge.command("dev_boss_body_state").value[0]
	var fraction: float=clampf((t.performance_time-0.1)/0.3,0.0,1.0)
	var exact := true
	for i in 2:
		var angle: float=aims[i]+(1.0 if i==0 else -1.0)*lerpf(0.8,0.12,fraction)
		exact=exact and body.effects[i].points[0].distance_to(from[i])<0.001 and body.effects[i].points[1].distance_to(from[i]+Vector2.from_angle(angle)*600.0)<0.001
	check(t.pincer_aims==aims and exact,"初回の自機方向を固定し、ラジアンの開始角から終点角へ両側を閉じるSourceの式を保つ")
	var held: Dictionary=bridge.checkpoint();bridge._core.step(0.01);bridge._core.step_hazards(0.01);var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"2本の参加首・狙い・形・時計を保持して戻す");bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"途中復帰後も同じ挟撃の角度と点列へ進む")
	var events: Array=[];bridge.subscribe("挟撃の記録",func(packet):events.append_array(packet.events);return true)
	bridge._core.set_run_guards({"invincible":false});body=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_ship_motion",{"position":body.effects[0].points[0].lerp(body.effects[0].points[1],0.5),"velocity":Vector2.ZERO})
	var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.01);bridge._core.step_hazards(0.01);bridge.command("dev_boss_body_state")
	check(hp>bridge._core.ship_snapshot().ship_hp and events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="beam" and e.payload.technique=="beam_pincer" and e.payload.source=="hydra"),"閉じる線分の実命中と原因・技・所有元を共通の記録へ渡す")
	var view=hydra_move_view(c);await get_tree().process_frame
	bridge.restore(held.value);body=bridge.command("dev_boss_body_state").value[0];bridge.command("dev_damage",{"entity_id":body.necks[3].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"片方の参加首が倒れると両方のビームを中断する")
	bridge.restore(held.value);bridge.command("dev_cancel_flow",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"取消で2本の持続ビームを同時に回収する")
	bridge.restore(held.value)
	for tick in 50:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty(),"挟撃の寿命を過ぎると線分を消す")
	for tick in 60:bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value.any(func(a):return a.id>first_id and a.kind==74),"自然終了とコンボの待ち後に次の行動を選べる")
	bridge.restore(held.value);body=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	bridge.command("dev_cancel_flow",{"entity_id":c.id});bridge._core.step(0.21);body=bridge.command("dev_boss_body_state").value[0]
	var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	check(started.ok,"分離後も2本のビーム首で同じ挟撃を開始できる")
	if started.ok:
		bridge._core.step(0.16);body=bridge.command("dev_boss_body_state").value[0]
		var anchored: Array=[body.effects[0].points[0],body.effects[1].points[0]];bridge._core.step(0.1);body=bridge.command("dev_boss_body_state").value[0]
		check(body.effects[0].points[0]==anchored[0] and body.effects[1].points[0]==anchored[1],"分離後も参加首の配置とビームの起点を固定する")
	bridge.release_checkpoint(held.value);bridge.dispose();view.queue_free()
	var short_edits: Dictionary=edits.duplicate();short_edits.performance_time=0.05
	c=hydra_major_case("beam_pincer",short_edits,false,{"combo_cooldown":0.1});bridge=c.bridge;hydra_pincer_grow(c)
	check(bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"寿命より先に技が終わる挟撃を開始する");bridge._core.step(0.16)
	check(bridge.command("dev_boss_body_state").value[0].effects.size()==2,"短い実行時間でも発動時点に2本を生成する");bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].stage==5 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"自然終了は長い寿命が残ったビームも消す");bridge.dispose()
	await get_tree().process_frame;print("[cpp_hydra_pincer] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_tornado() -> void:
	var c := hydra_major_case("tornado",{"warning_time":0.15,"performance_time":0.65,"tornado_charge":0.2,"tornado_life":0.3,"tornado_speed":400.0,"tornado_width":120.0,"lump_dmg":7.0,"tech_recovery":0.05,"cooldown":0.1},true)
	if c.is_empty(): get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	var events: Array=[];bridge.subscribe("竜巻の記録",func(packet):events.append_array(packet.events);return true)
	check(c.move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(c.move).kind()==&"tornado","竜巻の編集Resourceを互換Runnerから分ける")
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==82,"共通フローから2首の竜巻を自然に選ぶ")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var heads: Array=body.necks.filter(func(n):return n.mode=="tornado")
	check(heads.size()==2 and heads[0].kind=="vortex" and heads[1].kind=="debris" and body.effects.is_empty(),"渦・瓦礫の2首だけ参加し、全体予告中は形を出さない")
	bridge._core.step(0.15);body=bridge.command("dev_boss_body_state").value[0]
	var feed: Array=body.effects.filter(func(e):return e.kind=="tornado_charge")
	check(feed.size()==1 and feed[0].width==96.0 and feed[0].feed.size()==3 and feed[0].fill>0.0,"発動後は無害な溜め円と3個の投入瓦礫を正式表示へ出す")
	bridge.command("dev_ship_motion",{"position":feed[0].points[0],"velocity":Vector2.ZERO})
	bridge._core.step_hazards(0.01)
	check(bridge._core.ship_snapshot().ship_invuln==0.0 and bridge._core.ship_snapshot().ship_hurt==0.0,"無害な溜め円に触れても無敵時間や被弾表示を付けない")
	var gathered: Dictionary=bridge.checkpoint()
	var view=hydra_move_view(c);await get_tree().process_frame
	bridge._core.step(0.06);body=bridge.command("dev_boss_body_state").value[0]
	var active: Array=body.effects.filter(func(e):return e.kind=="tornado")
	check(active.size()==1 and active[0].width==120.0 and is_equal_approx(active[0].points[0].distance_to(active[0].points[1]),90.0) and bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead).is_empty(),"個別溜めの時刻に瓦礫を回収し、長さ90の竜巻を放つ")
	if active.is_empty():bridge.dispose();get_tree().quit(1);return
	var effect: Dictionary=active[0].duplicate(true);var direction: Vector2=(effect.points[1]-effect.points[0]).normalized()
	bridge.command("dev_ship_motion",{"position":effect.points[1]+direction*10,"velocity":Vector2.ZERO})
	var hp: float=bridge._core.ship_snapshot().ship_hp
	var launched: Dictionary=bridge.checkpoint();bridge._core.step_hazards(0.05);body=bridge.command("dev_boss_body_state").value[0]
	var expected: Dictionary=body.duplicate(true)
	check(body.effects[0].points[0].distance_to(effect.points[0]+direction*20)<0.001 and is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"竜巻は等速掃引し実HPへ倍率を一度だけ掛ける")
	check(launched.ok and bridge.restore(launched.value).ok,"竜巻の別時計・参加首・発射状態を途中保持して戻す")
	bridge._core.step_hazards(0.05);check(bridge.command("dev_boss_body_state").value[0]==expected,"途中復帰後も点列と寿命が一致する")
	check(events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="tornado" and e.payload.technique=="tornado" and e.payload.source=="hydra"),"竜巻の原因・技・所有元を共通通知へ記録する")
	bridge.restore(gathered.value);bridge.command("dev_cancel_flow",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty() and bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead).is_empty(),"溜め中の取消は予告と投入瓦礫を回収する")
	bridge.restore(gathered.value);bridge.command("dev_damage",{"entity_id":heads[0].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"参加首は2本とも必要で、片方消失なら溜めを中断する")
	bridge.restore(launched.value);bridge.command("dev_cancel_flow",{"entity_id":c.id});bridge.command("dev_damage",{"entity_id":heads[0].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_body_state").value[0].effects.size()==1,"放った竜巻は取消と参加首消失後も残る")
	bridge._core.step_hazards(0.31);check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"放った竜巻は独立した寿命で終わる")
	bridge.restore(launched.value);bridge._core.step(0.61)
	check(bridge.command("dev_boss_state").value[0].stage==5,"実行時間の終了で大技を自然終了する")
	for tick in 80:
		bridge._core.step(0.01)
		if bridge.command("dev_boss_state").value.any(func(t):return t.id>first_id and t.kind==82):break
	check(bridge.command("dev_boss_state").value.any(func(t):return t.id>first_id and t.kind==82),"回復とコンボ待ちの後に次の技を自然に選ぶ")
	bridge.release_checkpoint(gathered.value);bridge.release_checkpoint(launched.value);bridge.dispose();view.queue_free();await get_tree().process_frame
	print("[cpp_hydra_tornado] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_shatter() -> void:
	var c := hydra_major_case("debris_shatter",{"warning_time":0.1,"performance_time":0.8,"shatter_deploy":0.2,"shatter_time":0.4,"shatter_arc":1.8,"rubble_count":3,"beam_len":800.0,"beam_width":80.0,"beam_dmg":7.0,"shard_dmg":9.0,"shard_speed":300.0,"tech_recovery":0.05,"cooldown":0.1},true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	var events: Array=[];bridge.subscribe("瓦礫砕きの記録",func(packet):events.append_array(packet.events);return true)
	check(c.move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(c.move).kind()==&"debris_shatter","瓦礫砕きの編集値とRunnerを分ける")
	for tick in 40:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==83,"共通フローが瓦礫とビームの2首を自然に選ぶ")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var heads: Array=body.necks.filter(func(n):return n.mode=="debris_shatter")
	check(heads.size()==2 and heads[0].kind=="debris" and heads[1].kind=="beam" and body.effects.is_empty(),"必要な2首だけ参加し、予告中に攻撃しない")
	bridge._core.step(0.1);bridge._core.step(0.05)
	body=bridge.command("dev_boss_body_state").value[0]
	var stones: Array=bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead)
	check(stones.size()==3 and body.effects.is_empty() and stones.all(func(e):return Vector2(e.vel[0],e.vel[1])==Vector2.ZERO),"個別展開中は静止した瓦礫を3個広げ、ビームを出さない")
	var deployed: Dictionary=bridge.checkpoint()
	bridge._core.step(0.06);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].kind=="beam" and body.effects[0].width==80.0 and is_equal_approx(body.effects[0].points[0].distance_to(body.effects[0].points[1]),800.0),"展開時刻の後に線分ビームを始める")
	var beam: Dictionary=body.effects[0];var direction: Vector2=(beam.points[1]-beam.points[0]).normalized()
	bridge.command("dev_ship_motion",{"position":beam.points[0]+direction*100,"velocity":Vector2.ZERO})
	var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hazards(0.01)
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"ビームは線分で実HPへ倍率を一度だけ掛ける")
	var view=hydra_move_view(c);await get_tree().process_frame
	for tick in 16:bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	body=bridge.command("dev_boss_body_state").value[0]
	var shots: Array=bridge._core.hostiles_snapshot()
	check(shots.size()>0 and shots.size()%6==0 and shots.all(func(e):return is_equal_approx(e.vel.length(),300.0)),"掃引ビームが瓦礫へ触れた順に6発ずつ破片を出す")
	var cues: Array=events.filter(func(e):return e.type=="hydra_cue" and e.payload.cue=="rubble_shattered")
	check(cues.size()*6==shots.size(),"瓦礫を砕いた回数と6発のまとまりを対応させる")
	var after: Dictionary=bridge.checkpoint();var expected_shots: Array=shots.duplicate(true)
	check(bridge.restore(deployed.value).ok,"瓦礫の世代参照・配置先・掃引の時計を保持して戻す")
	bridge._core.step(0.06);bridge._core.step_hazards(0.01)
	for tick in 16:bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	check(bridge._core.hostiles_snapshot()==expected_shots,"復帰後も砕く順番と破片の軌道・乱数消費が同じになる")
	bridge.restore(after.value)
	if not shots.is_empty():
		bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
		bridge.command("dev_ship_motion",{"position":shots[0].pos,"velocity":Vector2.ZERO})
		hp=bridge._core.ship_snapshot().ship_hp;bridge._core.step_hostiles(0.001);bridge.command("dev_boss_body_state")
		check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,9.0),"破片はshard_dmgそのままで実HPを減らし追加倍率を掛けない")
		check(events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bullet" and e.payload.technique=="debris_shatter" and e.payload.source=="hydra"),"破片はbullet・debris_shatter・hydraを記録する")
	bridge.restore(deployed.value);bridge.command("dev_cancel_flow",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty() and bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead).is_empty(),"展開中の取消で瓦礫を回収する")
	bridge.restore(after.value);bridge.command("dev_damage",{"entity_id":heads[1].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty() and bridge._core.hostiles_snapshot().size()==shots.size(),"参加首消失ではビームと残る瓦礫を消し、発射済み破片を残す")
	var remaining_life: float=shots.map(func(shot):return shot.life).max() if not shots.is_empty() else 1.0
	bridge._core.step_hostiles(remaining_life+0.1)
	check(bridge._core.hostiles_snapshot().is_empty(),"発射済み破片は自然寿命で回収する")
	bridge.restore(after.value);bridge._core.step(0.3)
	check(bridge.command("dev_boss_state").value[0].stage==5 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"実行時間で自然終了し持続ビームを消す")
	for tick in 80:
		bridge._core.step(0.01)
		if bridge.command("dev_boss_state").value.any(func(t):return t.id>first_id and t.kind==83):break
	check(bridge.command("dev_boss_state").value.any(func(t):return t.id>first_id and t.kind==83),"自然終了の待ち後に次のコンボを選ぶ")
	bridge.release_checkpoint(deployed.value);bridge.release_checkpoint(after.value);bridge.dispose();view.queue_free();await get_tree().process_frame
	print("[cpp_hydra_debris_shatter] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_shatter_record() -> void:
	var c := hydra_major_case("debris_shatter",{"warning_time":0.1,"performance_time":0.8,"shatter_deploy":0.2,"shatter_time":0.4,"shatter_arc":1.8,"rubble_count":3,"beam_len":800.0,"beam_width":80.0,"beam_dmg":7.0,"shard_dmg":9.0,"shard_speed":300.0,"tech_recovery":0.05,"cooldown":0.1})
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	var events: Array=[];bridge.subscribe("破片の記録",func(packet):events.append_array(packet.events);return true)
	bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1})
	bridge._core.step(0.1);bridge._core.step(0.05);bridge._core.step(0.06)
	for tick in 16:bridge._core.step(0.025)
	var shots: Array=bridge._core.hostiles_snapshot()
	if shots.is_empty():check(false,"記録用の破片が出る");bridge.dispose();get_tree().quit(1);return
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	bridge.command("dev_ship_motion",{"position":shots[0].pos,"velocity":Vector2.ZERO})
	bridge._core.step_hostiles(0.001);bridge.command("dev_boss_body_state")
	check(events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bullet" and e.payload.technique=="debris_shatter" and e.payload.source=="hydra"),"破片の原因・技と、共通通知のボス所有元を保つ")
	bridge.dispose();print("[cpp_hydra_shatter_record] failures=",failed);get_tree().quit(1 if failed else 0)


func hydra_thunder_case(flowing := false, overrides := {}) -> Dictionary:
	var values := {"normal_charge":0.2,"normal_hold":0.1,"attack_cd":0.03,"thunder_radius":50.0,"thunder_flash":0.12,"beam_dmg":7.0,"target_lock_fraction":0.5,"thunder_lead":0.4}
	values.merge(overrides,true)
	return hydra_normal_case(flowing,{},values,"thunder_drop")

func hydra_thunder_tick(bridge, dt: float) -> void:
	bridge._core.step(dt)
	bridge._core.step_hazards(dt)
	bridge.command("dev_boss_body_state")

func native_hydra_thunder() -> void:
	var move = load("res://data/bosses/hydra_moves/thunder_drop.tres")
	if not "--cpp-hydra-thunder-rest" in OS.get_cmdline_user_args():
		check(move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(move).kind()==&"thunder_drop","落雷の編集値と旧Runnerを分離する")
	var c := hydra_thunder_case(true)
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var events: Array = [];bridge.subscribe("落雷の記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[4]
	var target: Vector2 = head.position+Vector2.from_angle(head.angle)*450
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(30,0)})
	for tick in 200:
		hydra_thunder_tick(bridge,0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==91,"雷の首が通常フローから落雷を選ぶ")
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	check(actions[0].aim.distance_to(target+Vector2(12,0))<0.001,"開始時に速度とthunder_leadで一度だけ先読みする")
	hydra_thunder_tick(bridge,0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].kind=="lightning" and body.effects[0].points.size()==2 and body.effects[0].width==100.0 and is_equal_approx(body.effects[0].delay,0.19),"最初の首更新でcharge-tの予告と直径を生成する")
	var held: Dictionary = bridge.checkpoint()
	for tick in 10: hydra_thunder_tick(bridge,0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[4].locked and body.effects[0].age<body.effects[0].delay,"chargeの割合で狙いが固定し、まだ命中しない")
	var expected: Dictionary = body.duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"予告の点・時計・ロックを保持して戻す")
	for tick in 10: hydra_thunder_tick(bridge,0.01)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"復帰後も同じ落雷予告になる");bridge.release_checkpoint(held.value)
	var strike: Vector2 = expected.effects[0].points[0]
	bridge._core.set_run_guards({"invincible":false})
	bridge.command("dev_ship_motion",{"position":strike,"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	for tick in 11: hydra_thunder_tick(bridge,0.01)
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="lightning")
	check(is_equal_approx(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale) and hits.size()==1 and hits[0].payload.technique==&"thunder_drop" and hits[0].payload.source==&"hydra","固定した円で実HPへ倍率を一度掛け、雷・技・所有元を記録する")
	var scope := ContentResourceScope.new()
	for asset: Dictionary in c.package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),"正式なHydra表示で落雷を描く")
	await get_tree().process_frame
	for tick in 21: hydra_thunder_tick(bridge,0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty(),"flashの寿命で落雷を回収する")
	for tick in 60: hydra_thunder_tick(bridge,0.01)
	check(bridge.command("dev_boss_state").value.any(func(t): return t.kind==91 and t.id>actions[0].id),"自然終了と待ちのあと次の落雷を選ぶ")
	bridge.dispose();view.queue_free()
	for cancel_at in [0.05,0.23,0.35]:
		var q := hydra_thunder_case()
		if q.is_empty(): continue
		var qb=q.bridge;var state: Dictionary=qb.command("dev_boss_body_state").value[0];var n: Dictionary=state.necks[4]
		qb.command("dev_ship_motion",{"position":n.position+Vector2.from_angle(n.angle)*450,"velocity":Vector2.ZERO})
		var start: Dictionary=qb.command("dev_boss_technique",{"entity_id":n.id,"definition":1})
		check(start.ok,"予告・発動・回復の取消用の落雷を開始する")
		if start.ok:
			for tick in int(round(cancel_at/0.01)): hydra_thunder_tick(qb,0.01)
			var keep: Dictionary=qb.checkpoint();check(keep.ok and qb.restore(keep.value).ok,"各段階で落雷を保持して戻す");qb.release_checkpoint(keep.value)
			check(qb.command("dev_cancel_technique",{"ticket":start.value}).ok and qb.command("dev_boss_body_state").value[0].effects.is_empty(),"取消で予告と継続中の落雷を回収する")
		qb.dispose()
	var lost := hydra_thunder_case()
	if not lost.is_empty():
		var lb=lost.bridge;var state: Dictionary=lb.command("dev_boss_body_state").value[0];var n: Dictionary=state.necks[4]
		lb.command("dev_ship_motion",{"position":n.position+Vector2.from_angle(n.angle)*450,"velocity":Vector2.ZERO})
		lb.command("dev_boss_technique",{"entity_id":n.id,"definition":1});hydra_thunder_tick(lb,0.05)
		lb.command("dev_remove",{"entity_id":n.id});hydra_thunder_tick(lb,0.01)
		check(lb.command("dev_boss_body_state").value[0].effects.is_empty(),"参加首の消失で予告を回収する");lb.dispose()
	var zero := hydra_thunder_case(false,{"normal_charge":0.0})
	if not zero.is_empty():
		var zb=zero.bridge;var state: Dictionary=zb.command("dev_boss_body_state").value[0];var n: Dictionary=state.necks[4]
		zb.command("dev_ship_motion",{"position":n.position+Vector2.from_angle(n.angle)*450,"velocity":Vector2.ZERO})
		zb.command("dev_boss_technique",{"entity_id":n.id,"definition":1});hydra_thunder_tick(zb,0.01)
		var z: Dictionary=zb.command("dev_boss_body_state").value[0]
		check(z.effects.size()==1 and z.effects[0].delay<0.0,"charge0でもSourceの負の余りを0止めせず保持する")
		var keep: Dictionary=zb.checkpoint();check(keep.ok and zb.restore(keep.value).ok,"負のdelayを持つ落雷も保持・復帰する");zb.release_checkpoint(keep.value);zb.dispose()
	var separated := hydra_thunder_case()
	if not separated.is_empty():
		var sb=separated.bridge;var body_state: Dictionary=sb.command("dev_boss_body_state").value[0]
		sb.command("dev_damage",{"entity_id":separated.id,"amount":body_state.max_hp+1,"cause":"shot"});sb._core.step(0.001);sb._core.step(1.21)
		body_state=sb.command("dev_boss_body_state").value[0];var n: Dictionary=body_state.necks[4]
		sb.command("dev_ship_motion",{"position":n.position+Vector2.from_angle(n.look_angle)*450,"velocity":Vector2.ZERO})
		check(body_state.separated and sb.command("dev_boss_technique",{"entity_id":n.id,"definition":1}).ok,"分離後も同じ落雷定義を開始する")
		hydra_thunder_tick(sb,0.05);var saved: Dictionary=sb.checkpoint()
		check(saved.ok and sb.restore(saved.value).ok,"分離後の予告の所有と時計を復帰する");sb.release_checkpoint(saved.value)
		hydra_thunder_tick(sb,0.16);body_state=sb.command("dev_boss_body_state").value[0]
		check(body_state.necks[4].normal_phase==1 and body_state.necks[4].glow==0.0,"分離後は閃光時間がactiveで、予告後は頭の発光を消す")
		hydra_thunder_tick(sb,0.12);body_state=sb.command("dev_boss_body_state").value[0]
		check(body_state.necks[4].normal_phase==2 and body_state.effects.is_empty(),"holdに入ると首所有の落雷を消す")
		sb.command("dev_cancel_boss",{"entity_id":separated.id});check(sb.command("dev_boss_body_state").value[0].effects.is_empty(),"本体終了で落雷の所有を解放する");sb.dispose()
	await get_tree().process_frame
	print("[cpp_hydra_thunder] failures=",failed)
	get_tree().quit(1 if failed else 0)


func native_hydra_thunder_hit() -> void:
	var c := hydra_thunder_case(true)
	if c.is_empty(): get_tree().quit(1);return
	var b=c.bridge;var events: Array=[];b.subscribe("落雷の命中",func(packet):events.append_array(packet.events);return true)
	var state: Dictionary=b.command("dev_boss_body_state").value[0];var n: Dictionary=state.necks[4]
	b.command("dev_ship_motion",{"position":n.position+Vector2.from_angle(n.angle)*450,"velocity":Vector2(30,0)})
	for tick in 200:
		hydra_thunder_tick(b,0.01)
		if not b.command("dev_boss_state").value.is_empty(): break
	for tick in 11:hydra_thunder_tick(b,0.01)
	state=b.command("dev_boss_body_state").value[0]
	b._core.set_run_guards({"invincible":false})
	b.command("dev_ship_motion",{"position":state.effects[0].points[0],"velocity":Vector2.ZERO})
	var hp:float=b._core.ship_snapshot().ship_hp
	for tick in 11:hydra_thunder_tick(b,0.01)
	var hits:Array=events.filter(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="lightning")
	print("落雷命中値 ",{"before":hp,"after":b._core.ship_snapshot().ship_hp,"scale":c.cfg.atk_scale,"hits":hits,"damage_events":events.filter(func(e):return e.type=="combat_player_damage")})
	check(hits.size()==1 and hits[0].payload.technique==&"thunder_drop" and hits[0].payload.source==&"hydra","落雷の命中記録を同じtickで受け取る")
	b.dispose();print("[cpp_hydra_thunder_hit] failures=",failed);get_tree().quit(1 if failed else 0)

func hydra_headbutt_case(flowing := false) -> Dictionary:
	return hydra_normal_case(flowing,{}, {"normal_charge":0.1,"normal_lunge":0.12,"normal_hold":0.1,"attack_cd":0.03,"bite_radius":10.0,"bite_dmg":3.0,"thunder_radius":120.0,"thunder_flash":0.08,"beam_dmg":7.0},"thunder_headbutt")

func native_hydra_headbutt() -> void:
	var c:=hydra_headbutt_case(true)
	if c.is_empty():get_tree().quit(1);return
	var b=c.bridge;var state:Dictionary=b.command("dev_boss_body_state").value[0];var n:Dictionary=state.necks[4]
	var target:Vector2=n.position+Vector2.from_angle(n.angle)*450
	b.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	for tick in 200:
		hydra_thunder_tick(b,0.01)
		if not b.command("dev_boss_state").value.is_empty():break
	var acts:Array=b.command("dev_boss_state").value
	check(not acts.is_empty() and acts[0].kind==92,"雷の首が通常フローから頭突きを選ぶ")
	if acts.is_empty():b.dispose();get_tree().quit(1);return
	for tick in 10:hydra_thunder_tick(b,0.01)
	var held:Dictionary=b.checkpoint()
	for tick in 5:hydra_thunder_tick(b,0.01)
	state=b.command("dev_boss_body_state").value[0]
	check(state.effects.any(func(e):return e.kind=="bite" and e.width==10.0) and not state.effects.any(func(e):return e.kind=="lightning"),"噛みつき部品が踏み込み線分を作り、落雷はまだ出さない")
	var expected:Dictionary=state.duplicate(true)
	check(held.ok and b.restore(held.value).ok,"踏み込みと落雷設定を値型で復帰する")
	for tick in 5:hydra_thunder_tick(b,0.01)
	check(b.command("dev_boss_body_state").value[0]==expected,"同じ踏み込み点列へ戻る");b.release_checkpoint(held.value)
	b.command("dev_ship_motion",{"position":target+Vector2(0,80),"velocity":Vector2.ZERO});b._core.set_run_guards({"invincible":false})
	var events:Array=[];b.subscribe("頭突きの落雷記録",func(packet):events.append_array(packet.events);return true)
	var hp:float=b._core.ship_snapshot().ship_hp
	for tick in 9:hydra_thunder_tick(b,0.01)
	state=b.command("dev_boss_body_state").value[0]
	var light:Array=state.effects.filter(func(e):return e.kind=="lightning")
	var hits:Array=events.filter(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="lightning")
	check(light.size()==1 and light[0].points[0].distance_to(target)<0.001 and light[0].width==240.0,"踏み込みの終了に狙った位置へ一度だけ落雷する")
	check(is_equal_approx(hp-b._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale) and hits.size()==1 and hits[0].payload.technique==&"thunder_headbutt" and hits[0].payload.source==&"hydra","噛みつきの外側へ落雷だけが命中し、倍率・原因・技を記録する")
	var scope:=ContentResourceScope.new()
	for asset:Dictionary in c.package.visuals:
		if not asset.path.is_empty():scope.provide(asset.path,load(asset.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]:scope.provide(path,load(path))
	var view=load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries:Array[Dictionary]=[];entries.assign(c.package.visuals);view.setup(scope,entries,c.cfg.character_scale)
	check(view.apply_frame(b.read_render(Rect2(-2500,-1800,5000,3600)).value),"踏み込みと落雷を正式表示へ渡す")
	await get_tree().process_frame
	for tick in 50:hydra_thunder_tick(b,0.01)
	check(b.command("dev_boss_state").value.any(func(t):return t.kind==92 and t.id>acts[0].id),"頭突き自然終了後に次の行動へ進む")
	b.dispose();view.queue_free()
	for cancel_at in [0.04,0.16,0.24]:
		var q:=hydra_headbutt_case()
		if q.is_empty():continue
		var qb=q.bridge;var x:Dictionary=qb.command("dev_boss_body_state").value[0];var head:Dictionary=x.necks[4]
		qb.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*450,"velocity":Vector2.ZERO})
		var start:Dictionary=qb.command("dev_boss_technique",{"entity_id":head.id,"definition":1})
		check(start.ok,"各段階の取消用に頭突きを開始する")
		if start.ok:
			for tick in int(round(cancel_at/0.01)):hydra_thunder_tick(qb,0.01)
			var saved:Dictionary=qb.checkpoint();check(saved.ok and qb.restore(saved.value).ok,"予告・踏み込み・落雷の各段階を保持復帰する");qb.release_checkpoint(saved.value)
			check(qb.command("dev_cancel_technique",{"ticket":start.value}).ok and qb.command("dev_boss_body_state").value[0].effects.is_empty(),"取消で首所有の噛みつきと雷を回収する")
		qb.dispose()
	var free:=hydra_headbutt_case()
	if not free.is_empty():
		var fb=free.bridge;var x:Dictionary=fb.command("dev_boss_body_state").value[0]
		fb.command("dev_damage",{"entity_id":free.id,"amount":x.max_hp+1,"cause":"shot"});fb._core.step(0.001);fb._core.step(1.21)
		x=fb.command("dev_boss_body_state").value[0];var head:Dictionary=x.necks[4]
		fb.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.look_angle)*450,"velocity":Vector2.ZERO})
		check(fb.command("dev_boss_technique",{"entity_id":head.id,"definition":1}).ok,"分離後も同じ噛みつき部品へ落雷設定を渡す")
		for tick in 24:hydra_thunder_tick(fb,0.01)
		x=fb.command("dev_boss_body_state").value[0]
		check(x.necks[4].normal_phase==1 and x.effects.any(func(e):return e.kind=="lightning"),"分離後は踏み込み終点へ雷を出し、閃光時間までactiveを保つ")
		for tick in 7:hydra_thunder_tick(fb,0.01)
		x=fb.command("dev_boss_body_state").value[0]
		check(x.necks[4].normal_phase==2 and x.effects.is_empty(),"分離後はflash後にholdへ入り、首の判定を回収する")
		fb.command("dev_cancel_boss",{"entity_id":free.id});check(fb.command("dev_boss_body_state").value[0].effects.is_empty(),"本体終了で頭突きと落雷を解放する");fb.dispose()
	await get_tree().process_frame
	print("[cpp_hydra_headbutt] failures=",failed);get_tree().quit(1 if failed else 0)


func native_hydra_headbutt_loss() -> void:
	for at in [0.15,0.24]:
		var c:=hydra_headbutt_case()
		if c.is_empty():continue
		var b=c.bridge;var state:Dictionary=b.command("dev_boss_body_state").value[0];var n:Dictionary=state.necks[4]
		b.command("dev_ship_motion",{"position":n.position+Vector2.from_angle(n.angle)*450,"velocity":Vector2.ZERO})
		var start:Dictionary=b.command("dev_boss_technique",{"entity_id":n.id,"definition":1})
		if not start.ok:check(false,"首消失の確認用の頭突きを開始する");b.dispose();continue
		for tick in int(round(at/0.01)):hydra_thunder_tick(b,0.01)
		b.command("dev_remove",{"entity_id":n.id});hydra_thunder_tick(b,0.01)
		check(b.command("dev_boss_body_state").value[0].effects.is_empty(),"踏み込み中と落雷後の参加首消失で首所有の判定を回収する")
		b.dispose()
	print("[cpp_hydra_headbutt_loss] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_wind() -> void:
	var edits := {"normal_charge":0.15,"wind_time":0.4,"normal_hold":0.1,"attack_cd":0.05,"wind_length":300.0,"wind_width":90.0,"wind_force":400.0}
	hydra_wind_resource_check()
	var c := hydra_normal_case(true,{},edits,"wind_band")
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	var events: Array=[];bridge.subscribe("風の帯の記録",func(packet):events.append_array(packet.events);return true)
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0];var head: Dictionary=body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*200.0,"velocity":Vector2.ZERO})
	for tick in 100:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==75,"共通フローが渦の首から風の帯を自然に選ぶ")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	bridge._core.step(0.08);bridge._core.step_hazards(0.08);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty() and body.necks[1].glow>0.0 and not body.necks[1].locked,"予告中は狙いと発光だけを更新し風を出さない")
	bridge._core.step(0.08);bridge._core.step_hazards(0.08);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[1].locked and body.effects.size()==1 and body.effects[0].kind=="wind" and is_equal_approx(body.effects[0].wind_force,400.0) and is_equal_approx(body.effects[0].life,0.4),"溜め後に押す力と寿命を持つ無害な風の線分を作る")
	var first: Dictionary=body.effects[0].duplicate(true)
	bridge.command("dev_ship_motion",{"position":Vector2(900,-600),"velocity":Vector2.ZERO});bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects[0].points==first.points,"分離前の風の起点と向きを固定する")
	var firing: Dictionary=bridge.checkpoint();var point: Vector2=first.points[0].lerp(first.points[1],0.5);var direction: Vector2=(first.points[1]-first.points[0]).normalized()
	bridge.command("dev_ship_motion",{"position":point,"velocity":Vector2.ZERO})
	var held: Dictionary=bridge.checkpoint();var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.025);bridge._core.step_hazards(0.025);body=bridge.command("dev_boss_body_state").value[0];var ship: Dictionary=bridge._core.ship_snapshot()
	check(ship.ship_vel.distance_to(direction*400.0*0.025)<0.001 and ship.ship_hp==hp and ship.ship_hurt==0.0 and ship.ship_invuln==0.0,"接触はforce×世界dtだけ押し、倍率・ダメージ・被弾表示・無敵時間を付けない")
	var expected: Dictionary=body.duplicate(true);var expected_velocity: Vector2=ship.ship_vel
	check(held.ok and bridge.restore(held.value).ok,"風の形・力・時計と機体速度を保持して戻す");bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected and bridge._core.ship_snapshot().ship_vel==expected_velocity,"復帰後も同じ押し出しと形へ進む")
	bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	check(bridge._core.ship_snapshot().ship_vel.distance_to(direction*20.0)<0.001,"同じ風に触れている間は毎tick押し出す")
	bridge.restore(firing.value);bridge.command("dev_ship_motion",{"position":point,"velocity":Vector2.ZERO,"glide":true});bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	check(bridge._core.ship_snapshot().ship_vel==Vector2.ZERO,"滑空中は風で速度を足さない")
	bridge.restore(firing.value);bridge.command("dev_ship_motion",{"position":point,"velocity":Vector2(c.cfg.base_max_speed,0)});bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	check(bridge._core.ship_snapshot().ship_vel==Vector2(c.cfg.base_max_speed,0),"最高速度ちょうどでは風で速度を足さない")
	bridge.restore(firing.value);bridge.command("dev_ship_motion",{"position":point,"velocity":Vector2.ZERO})
	bridge._core.handle_draw({"has_cursor":true,"pen":point,"press":true},0,1.0);bridge._core.handle_draw({"has_cursor":true,"pen":point+Vector2(200,0),"press":true},1000,1.0)
	var tracing: bool=bridge._core.draw_snapshot().tracing;var before_velocity: Vector2=bridge._core.ship_snapshot().ship_vel
	bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	check(tracing and before_velocity.length()<c.cfg.base_max_speed and bridge._core.ship_snapshot().ship_vel==before_velocity,"最高速度より遅い突進中も風で速度を足さない")
	bridge.command("dev_boss_body_state")
	check(not events.any(func(e):return e.type=="combat_player_damage" and e.payload.cause=="wind"),"風の接触から0ダメージの戦闘通知を出さない")
	bridge.restore(firing.value);var view=hydra_move_view(c);await get_tree().process_frame
	bridge.command("dev_cancel_flow",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"途中取消で風を回収する")
	bridge.restore(firing.value);body=bridge.command("dev_boss_body_state").value[0];bridge.command("dev_damage",{"entity_id":body.necks[1].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(not body.necks[1].alive and body.effects.is_empty() and not body.boss_dead,"参加首の消失で風だけを消す")
	bridge.restore(firing.value);bridge._core.step(0.5);bridge._core.step_hazards(0.5);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[1].mode=="idle" and body.effects.is_empty() and is_equal_approx(body.necks[1].cd,0.05),"自然終了したtickは新しい待ち時間を減らさず風を消す")
	head=body.necks[1];bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*200.0,"velocity":Vector2.ZERO})
	for tick in 30:bridge._core.step(0.025)
	check(bridge.command("dev_boss_state").value.any(func(a):return a.id>first_id and a.kind==75),"首の待ち後に次の風の帯へ進む")
	bridge.release_checkpoint(held.value);bridge.release_checkpoint(firing.value);bridge.dispose();view.queue_free()
	c=hydra_normal_case(false,{},edits,"wind_band");bridge=c.bridge;body=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[1]
	if head.cd>0:bridge._core.step(head.cd+0.001)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.look_angle)*200.0,"velocity":Vector2.ZERO})
	check(bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1}).ok,"分離後も同じ風の帯の登録を使う")
	bridge._core.step(0.08);bridge._core.step_hazards(0.08);bridge._core.step(0.08);bridge._core.step_hazards(0.08);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].points[0].distance_to(body.necks[1].position)<0.001,"分離後は動く頭から風の帯を始める")
	var old_origin: Vector2=body.effects[0].points[0];held=bridge.checkpoint();bridge._core.step(0.05);bridge._core.step_hazards(0.05);body=bridge.command("dev_boss_body_state").value[0];expected=body.duplicate(true)
	check(body.effects[0].points[0].distance_to(body.necks[1].position)<0.001 and body.effects[0].points[0]!=old_origin,"分離後の風は固定した向きを保って動く頭に追従する")
	check(held.ok and bridge.restore(held.value).ok,"分離後の持続する風も保持して戻す");bridge._core.step(0.05);bridge._core.step_hazards(0.05)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"分離後の風も同じ操舵・頭追従・時計へ復帰する")
	bridge._core.step(0.4);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[1].normal_phase==2 and body.effects.is_empty(),"分離後はholdへ入った更新で風を消す")
	bridge.release_checkpoint(held.value);bridge.dispose();await get_tree().process_frame
	print("[cpp_hydra_wind] failures=",failed);get_tree().quit(1 if failed else 0)


func hydra_wind_resource_check() -> void:
	var move=load("res://data/bosses/hydra_moves/wind_band.tres")
	check(move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(move).kind()==&"wind_band" and is_equal_approx(move.range_info(move.values()).max,430.0),"風の帯の編集値・範囲案内・互換RunnerとUID参照を分ける")


func native_hydra_wind_resource() -> void:
	hydra_wind_resource_check()
	print("[cpp_hydra_wind_resource] failures=",failed);get_tree().quit(1 if failed else 0)

func hydra_separated_live(bridge, kind: int) -> Array:
	return bridge.command("dev_boss_state").value.filter(func(t):return t.kind==kind and t.stage<5)


func native_hydra_debris_separated() -> void:
	for name in ["rubble_lump","rubble_fan","tornado","debris_shatter"]:
		var only := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--move="):only=arg.trim_prefix("--move=")
		if not only.is_empty() and only!=name:continue
		if name in ["rubble_lump","rubble_fan"]:await hydra_separated_rubble(name)
		else:await hydra_separated_debris_combo(name)
	print("[cpp_hydra_debris_separated] failures=",failed);get_tree().quit(1 if failed else 0)


func hydra_separated_rubble(name: String) -> void:
	var fan := name=="rubble_fan"
	var edits := {"normal_charge":0.15,"normal_hold":0.3,"attack_cd":0.05,"lump_speed":400.0,"lump_dmg":7.0}
	if fan:edits.merge({"rubble_count":6,"rubble_spread":1.3,"rubble_small_radius":16.0})
	else:edits.lump_r=26.0
	var c := hydra_normal_case(true,{},edits,name)
	if c.is_empty():return
	var bridge=c.bridge;bridge._core.set_attack_formation_mode(true)
	hydra_grid_separate(c)
	bridge._core.set_motion_context(Vector2(-200,0),Vector2.ZERO,Vector2(2500,1800))
	var kind: int=81 if fan else 80
	var actions: Array=[]
	for tick in 240:
		var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
		var candidate: Dictionary=body.necks.filter(func(n):return n.kind=="debris" and n.alive)[0]
		bridge.command("dev_ship_motion",{"position":candidate.position+Vector2.from_angle(candidate.look_angle)*500,"velocity":Vector2.ZERO})
		bridge._core.step(0.025);actions=hydra_separated_live(bridge,kind)
		if not actions.is_empty():break
	check(not actions.is_empty(),name+"：分離後の共通フローから首ごとの通常技を始める")
	if actions.is_empty():bridge.dispose();return
	var actor: int=actions[0].actor
	bridge._core.step(0.16)
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary=body.necks.filter(func(n):return n.id==actor)[0]
	var effects: Array=body.effects.filter(func(e):return e.technique==name)
	var count: int=6 if fan else 1
	var primary_effects: Array=effects.filter(func(e):return e.points[0].distance_to(head.position)<0.001)
	check(body.separated and head.normal_phase==2 and head.glow==0.0 and primary_effects.size()==count,name+"：分離後は発動した更新でholdへ入り発光を消す")
	if primary_effects.size()!=count:bridge.dispose();return
	check(primary_effects.all(func(e):return e.points[0].distance_to(head.position)<0.001),name+"：泳いでいる頭の現在位置から瓦礫を放つ")
	var stones: Array=bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead and Vector2(e.pos[0],e.pos[1]).distance_to(head.position)<0.001)
	var velocity := Vector2(stones[0].vel[0],stones[0].vel[1]).rotated(0.65 if fan else 0.0)
	check(absf(angle_difference(velocity.angle(),head.look_angle))<0.0001,name+"：分離後の視線を発射方向へ固定する")
	var view=hydra_move_view(c);await get_tree().process_frame
	var held: Dictionary=bridge.checkpoint();bridge._core.step(0.04);bridge._core.step_hazards(0.04)
	var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	var expected_stones: Array=bridge._core.enemies_snapshot()
	check(held.ok and bridge.restore(held.value).ok,name+"：分離した首と瓦礫の途中状態を戻せる")
	bridge._core.step(0.04);bridge._core.step_hazards(0.04)
	check(bridge.command("dev_boss_body_state").value[0]==expected and bridge._core.enemies_snapshot()==expected_stones,name+"：復帰後も共通finish_frameの首点列と追従判定が一致する")
	bridge.restore(held.value)
	var ids: Array=effects.map(func(e):return e.id)
	check(bridge.command("dev_cancel_flow",{"entity_id":c.id}).ok,name+"：分離後の実行中フローを取消できる")
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.map(func(e):return e.id)==ids and body.necks.filter(func(n):return n.id==actor)[0].mode=="idle",name+"：取消は首の所有だけを外し発射済み瓦礫を残す")
	bridge.command("dev_damage",{"entity_id":actor,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_body_state").value[0].effects.map(func(e):return e.id)==ids,name+"：分離した参加首が消えても瓦礫の所有を引き継がない")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),name+"：本体の取消では残った判定を回収する")
	bridge.release_checkpoint(held.value);bridge.dispose();view.queue_free();await get_tree().process_frame


func hydra_separated_debris_combo(name: String) -> void:
	var tornado := name=="tornado"
	var edits := {"warning_time":0.15,"performance_time":1.0,"tech_recovery":0.05,"cooldown":0.1}
	if tornado:edits.merge({"tornado_charge":0.25,"tornado_life":0.8,"tornado_speed":400.0,"tornado_width":120.0,"lump_dmg":7.0})
	else:edits.merge({"shatter_deploy":0.25,"shatter_time":0.4,"shatter_arc":1.8,"rubble_count":3,"beam_len":800.0,"beam_width":80.0,"beam_dmg":7.0,"shard_dmg":9.0,"shard_speed":300.0})
	var c := hydra_major_case(name,edits,true)
	if c.is_empty():return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":true})
	hydra_grid_separate(c)
	var kind: int=82 if tornado else 83
	var actions: Array=[]
	for tick in 160:
		actions=hydra_separated_live(bridge,kind)
		if not actions.is_empty():break
		bridge._core.step(0.025)
	check(not actions.is_empty(),name+"：分離後も共通フローから2首のコンボを始める")
	if actions.is_empty():bridge.dispose();return
	bridge._core.step(0.15)
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var heads: Array=body.necks.filter(func(n):return n.mode==name)
	check(body.separated and heads.size()==2 and heads[0].kind==("vortex" if tornado else "debris") and heads[1].kind==("debris" if tornado else "beam"),name+"：必要な種類の2首だけが参加する")
	if heads.size()!=2:bridge.dispose();return
	var gathered: Dictionary=bridge.checkpoint()
	var anchors: Array=heads.map(func(n):return n.position)
	bridge._core.step(0.04);bridge._core.step_hazards(0.04)
	var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(bridge.restore(gathered.value).ok,name+"：分離した参加首と展開中の瓦礫を保持して戻す")
	bridge._core.step(0.04);bridge._core.step_hazards(0.04)
	check(bridge.command("dev_boss_body_state").value[0]==expected,name+"：展開中の復帰後も首点列と攻撃の時計が一致する")
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks.filter(func(n):return n.mode==name).map(func(n):return n.position)==anchors,name+"：分離後も共通busy中は参加首の位置を固定する")
	var view=hydra_move_view(c);await get_tree().process_frame
	bridge.restore(gathered.value);bridge.command("dev_cancel_flow",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty() and bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead).is_empty(),name+"：分離後の展開取消で予告と所有する瓦礫を回収する")
	bridge.restore(gathered.value);bridge.command("dev_damage",{"entity_id":heads[0].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value.any(func(t):return t.kind==kind and t.stage==7) and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),name+"：分離した片方の参加首の消失で展開を中断する")
	bridge.restore(gathered.value);bridge._core.step(0.11)
	if not tornado:
		for tick in 14:
			if not bridge._core.hostiles_snapshot().is_empty():break
			bridge._core.step(0.025)
	body=bridge.command("dev_boss_body_state").value[0]
	var effects: Array=body.effects.filter(func(e):return e.technique==name)
	var shots: Array=bridge._core.hostiles_snapshot()
	check(effects.size()==1 and effects[0].kind==("tornado" if tornado else "beam") and (tornado or shots.size()>0),name+"：分離した固定起点から実行し発射済みの攻撃を持つ")
	if effects.is_empty():bridge.release_checkpoint(gathered.value);bridge.dispose();view.queue_free();return
	check(view.apply_frame(bridge.read_render(Rect2(-2500,-1800,5000,3600)).value),name+"：分離した首と実行中の形を正式表示へ渡す")
	var firing: Dictionary=bridge.checkpoint();bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	expected=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	var expected_shots: Array=bridge._core.hostiles_snapshot()
	check(bridge.restore(firing.value).ok,name+"：分離後の発射・掃引状態を保持して戻す")
	bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	check(bridge.command("dev_boss_body_state").value[0]==expected and bridge._core.hostiles_snapshot()==expected_shots,name+"：実行中の復帰後も形・所有・破片が一致する")
	bridge.restore(firing.value);bridge.command("dev_cancel_flow",{"entity_id":c.id})
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==(1 if tornado else 0) and bridge._core.hostiles_snapshot().size()==shots.size(),name+"：実行取消は持続形を消し発射済みの攻撃だけを残す")
	bridge.restore(firing.value);bridge.command("dev_damage",{"entity_id":heads[1].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==(1 if tornado else 0) and bridge._core.hostiles_snapshot().size()==shots.size(),name+"：参加首消失でも発射済みの所有と残留規則を保つ")
	bridge.command("dev_cancel_boss",{"entity_id":c.id})
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),name+"：分離後の本体取消で持続する判定を回収する")
	bridge.release_checkpoint(gathered.value);bridge.release_checkpoint(firing.value);bridge.dispose();view.queue_free();await get_tree().process_frame


func native_hydra_north() -> void:
	var edits := {"warning_time":0.24,"performance_time":0.5,"north_flight":0.12,"north_lock_time":0.12,"north_spread":90.0,"bite_radius":35.0,"bite_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("north",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	check(c.move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(c.move).kind()==&"north","同時噛みつきの編集Resourceと互換Runnerを分ける")
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==88,"五首から共通フローで同時噛みつきを選ぶ")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	check(body.north_targets.size()==3 and body.necks.filter(func(n):return n.mode=="north").size()==3,"機体方向に近い三首だけへ線と円の予告を渡す")
	bridge.command("dev_ship_motion",{"position":Vector2(850,180),"velocity":Vector2.ZERO});bridge._core.step(0.05)
	body=bridge.command("dev_boss_body_state").value[0]
	var targets: Array=body.north_targets.duplicate(true)
	var tracking: Dictionary=bridge.command("dev_boss_state").value[0]
	check(tracking.north_aiming and tracking.north_target==Vector2(850,180) and body.necks.any(func(n):return n.mode=="north" and n.glow>0),"首更新で機体を追い、首を引いて光らせる")
	var direction: Vector2=(Vector2(850,180)-body.position).normalized();var side: Vector2=direction.orthogonal()
	var center: Vector2=body.position+direction*maxf(Vector2(850,180).distance_to(body.position),body.radius+c.package.records.HydraBodyDefinition[0].neck_rest)
	var ordered: Array=targets.duplicate(true);ordered.sort_custom(func(a,b):return a.target.dot(side)<b.target.dot(side))
	var exact := ordered.size()==3
	for i in ordered.size():exact=exact and ordered[i].target.distance_to(center+side*90.0*(i-1))<0.01
	check(exact,"根元の横位置で並べた三首へ中心と90間隔のSource標的式を使う")
	var held: Dictionary=bridge.checkpoint();bridge._core.step(0.02);var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(held.ok and bridge.restore(held.value).ok,"狙いを追っている途中の時計と参加首を保持して戻す");bridge._core.step(0.02)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"復帰後も同じ首の位置と予告へ進む")
	bridge._core.step(0.06);body=bridge.command("dev_boss_body_state").value[0];targets=body.north_targets.duplicate(true)
	check(targets.size()==3 and targets.all(func(x):return x.locked),"固定時刻で三首の狙いを固定する")
	bridge.command("dev_ship_motion",{"position":Vector2(950,-220),"velocity":Vector2.ZERO});bridge._core.step(0.03)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.north_targets.map(func(x):return x.target)==targets.map(func(x):return x.target),"固定後に機体が動いても標的位置を変えない")
	var view=hydra_move_view(c);await get_tree().process_frame
	for tick in 20:
		bridge._core.step(0.01)
		if bridge.command("dev_boss_state").value[0].north_burst:break
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.is_empty() and body.north_targets.is_empty(),"発動tickは首を進めず予告だけを閉じる")
	var burst: Dictionary=bridge.checkpoint();var from: Array=body.necks.filter(func(n):return n.mode=="north").map(func(n):return n.position)
	bridge._core.step(0.04);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==3 and body.effects.all(func(e):return e.points.size()==2 and is_equal_approx(e.width,70.0) and is_equal_approx(e.life,0.041)),"次の首更新で移動区間を三つの幅付き線分へ出す")
	var events: Array=[];bridge.subscribe("同時噛みの記録",func(packet):events.append_array(packet.events);return true)
	bridge._core.set_run_guards({"invincible":false});var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":body.effects[0].points[0].lerp(body.effects[0].points[1],0.5),"velocity":Vector2.ZERO});bridge._core.step_hazards(0.001);bridge.command("dev_boss_body_state")
	check(hp>bridge._core.ship_snapshot().ship_hp and events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bite" and e.payload.technique=="north" and e.payload.source=="hydra"),"噛みつきが実HPとbite・north・hydra通知へ届く")
	bridge.restore(burst.value);bridge._core.step(0.04);var flight: Dictionary=bridge.checkpoint();bridge._core.step(0.02);expected=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(flight.ok and bridge.restore(flight.value).ok,"飛行途中の首と判定を保持する");bridge._core.step(0.02);check(bridge.command("dev_boss_body_state").value[0]==expected,"飛行途中の復帰でも区間を飛ばさない")
	bridge.restore(burst.value);body=bridge.command("dev_boss_body_state").value[0];var participant: Dictionary=body.necks.filter(func(n):return n.mode=="north")[0]
	bridge.command("dev_damage",{"entity_id":participant.id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"参加首一本の消失で同時噛みと判定を中断する")
	bridge.restore(flight.value);bridge.command("dev_cancel_flow",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"途中取消で全区間を回収する")
	bridge.restore(flight.value);bridge.command("dev_remove",{"entity_id":c.id});bridge._core.step(0.01);check(bridge.command("dev_boss_state").value[0].stage==7,"本体の消失で同時噛みを中断する")
	bridge.restore(burst.value);bridge._core.step(0.13);body=bridge.command("dev_boss_body_state").value[0]
	var landed: Array=body.necks.filter(func(n):return n.mode=="north").map(func(n):return n.position)
	check(landed.size()==3 and landed.all(func(p):return targets.any(func(x):return x.target.distance_to(p)<0.01)),"follow時刻をまたいでも全首が最後の標的位置へ到達する")
	for tick in 150:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_state").value.any(func(t):return t.id>first_id and t.kind==88),"自然終了と余白の後に次の同時噛みを選ぶ")
	bridge.release_checkpoint(held.value);bridge.release_checkpoint(burst.value);bridge.release_checkpoint(flight.value);bridge.dispose();view.queue_free()
	c=hydra_major_case("north",edits,false);bridge=c.bridge
	hydra_grid_separate(c)
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"分離後はSourceと同じく同時噛みを選ばない")
	bridge.dispose();await get_tree().process_frame;print("[cpp_hydra_north] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_north_tail() -> void:
	var edits := {"warning_time":0.24,"performance_time":0.5,"north_flight":0.12,"north_lock_time":0.12,"north_spread":90.0,"bite_radius":35.0,"bite_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("north",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	var targets: Array=[]
	for tick in 60:
		bridge._core.step(0.01)
		var b: Dictionary=bridge.command("dev_boss_body_state").value[0]
		if not b.north_targets.is_empty():targets=b.north_targets.duplicate(true)
		var actions: Array=bridge.command("dev_boss_state").value
		if not actions.is_empty() and actions[0].north_burst:break
	var first_id: int=bridge.command("dev_boss_state").value[0].id
	var burst: Dictionary=bridge.checkpoint()
	bridge._core.step(0.04);var flight: Dictionary=bridge.checkpoint()
	var body: Dictionary
	var view=hydra_move_view(c)
	bridge.restore(burst.value);body=bridge.command("dev_boss_body_state").value[0];var participant: Dictionary=body.necks.filter(func(n):return n.mode=="north")[0]
	bridge.command("dev_damage",{"entity_id":participant.id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"参加首一本の消失で同時噛みと判定を中断する")
	bridge.restore(flight.value);bridge.command("dev_cancel_flow",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"途中取消で全区間を回収する")
	bridge.restore(flight.value);bridge.command("dev_remove",{"entity_id":c.id});bridge._core.step(0.01);check(bridge.command("dev_boss_state").value[0].stage==7,"本体の消失で同時噛みを中断する")
	bridge.restore(burst.value);bridge._core.step(0.13);body=bridge.command("dev_boss_body_state").value[0]
	var landed: Array=body.necks.filter(func(n):return n.mode=="north").map(func(n):return n.position)
	check(landed.size()==3 and landed.all(func(p):return targets.any(func(x):return x.target.distance_to(p)<0.01)),"follow時刻をまたいでも全首が最後の標的位置へ到達する")
	for tick in 150:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_state").value.any(func(t):return t.id>first_id and t.kind==88),"自然終了と余白の後に次の同時噛みを選ぶ")
	bridge.release_checkpoint(burst.value);bridge.release_checkpoint(flight.value);bridge.dispose();view.queue_free()
	c=hydra_major_case("north",edits,false);bridge=c.bridge
	hydra_grid_separate(c)
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"分離後はSourceと同じく同時噛みを選ばない")
	bridge.dispose();await get_tree().process_frame;print("[cpp_hydra_north_tail] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_sequence() -> void:
	var edits := {"warning_time":0.15,"performance_time":0.85,"sequence_charge":0.08,"sequence_gap":0.2,"normal_lunge":0.12,"bite_radius":35.0,"bite_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("sequence",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	check(c.move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(c.move).kind()==&"sequence","順番噛みの編集Resourceと互換Runnerを分ける")
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==89,"五首から共通フローで順番噛みを自然選択する")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var participants: Array=body.necks.filter(func(n):return n.mode=="sequence")
	participants.sort_custom(func(a,b):return absf(angle_difference(TAU*float(body.necks.find(a))/body.necks.size()+body.facing,(Vector2(800,0)-body.position).angle()))<absf(angle_difference(TAU*float(body.necks.find(b))/body.necks.size()+body.facing,(Vector2(800,0)-body.position).angle())))
	check(participants.size()==3 and body.effects.is_empty() and participants.all(func(n):return not n.locked),"正面に近い三首をSource順で選び、予告中は判定を出さない")
	var before_facing: float=body.facing
	bridge.command("dev_ship_motion",{"position":Vector2(800,160),"velocity":Vector2.ZERO})
	for tick in 25:
		bridge._core.step(0.01)
		if bridge.command("dev_boss_state").value[0].stage==1:break
	var t: Dictionary=bridge.command("dev_boss_state").value[0];body=bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(t.performance_time,0.01) and body.effects.is_empty() and not is_equal_approx(body.facing,before_facing),"発動tickから実行時計へdtを加え、本体は機体へ向け続ける")
	bridge._core.step(0.08);body=bridge.command("dev_boss_body_state").value[0];t=bridge.command("dev_boss_state").value[0]
	var first: Dictionary=body.necks.filter(func(n):return n.id==participants[0].id)[0]
	var fraction: float=clampf((t.performance_time-0.08)/0.12,0.0,1.0)
	check(body.effects.size()==1 and first.locked and first.position.distance_to(participants[0].position.lerp(Vector2(800,160),fraction))<0.01 and body.effects[0].points[0].distance_to(participants[0].position)<0.01,"一首目は個別の溜め後に現在の機体へ固定しSourceのlerp区間を出す")
	check(is_equal_approx(body.effects[0].width,70.0) and is_equal_approx(body.effects[0].life,0.081),"順番噛みの線分幅は半径の二倍、寿命はmax(dt,.02)+.001")
	var view=hydra_move_view(c);await get_tree().process_frame
	var flight: Dictionary=bridge.checkpoint();bridge._core.step(0.03);bridge._core.step_hazards(0.03);var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(flight.ok and bridge.restore(flight.value).ok,"順番噛みの参加首・個別固定・時計と判定を保持する");bridge._core.step(0.03);bridge._core.step_hazards(0.03)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"途中復帰でも同じ首と区間へ進む")
	bridge.restore(flight.value);body=bridge.command("dev_boss_body_state").value[0]
	var events: Array=[];bridge.subscribe("順番噛みの記録",func(packet):events.append_array(packet.events);return true)
	bridge._core.set_run_guards({"invincible":false});var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":body.effects[0].points[0].lerp(body.effects[0].points[1],0.5),"velocity":Vector2.ZERO});bridge._core.step_hazards(0.001);bridge.command("dev_boss_body_state")
	check(hp>bridge._core.ship_snapshot().ship_hp and events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bite" and e.payload.technique=="sequence" and e.payload.source=="hydra"),"順番噛みが実HPとbite・sequence・hydraの通知へ届く")
	bridge.restore(flight.value);bridge.command("dev_ship_motion",{"position":Vector2(900,-120),"velocity":Vector2.ZERO});bridge._core.step(0.21)
	body=bridge.command("dev_boss_body_state").value[0];t=bridge.command("dev_boss_state").value[0]
	var second: Dictionary=body.necks.filter(func(n):return n.id==participants[1].id)[0]
	fraction=clampf((t.performance_time-0.2-0.08)/0.12,0.0,1.0)
	check(second.locked and second.position.distance_to(participants[1].position.lerp(Vector2(900,-120),fraction))<0.01 and events.any(func(e):return e.type=="hydra_cue" and e.payload.cue=="target_locked" and e.payload.neck>=0) and body.necks.filter(func(n):return n.mode=="sequence" and n.locked).size()==2,"二首目は間隔分だけ遅れて新しい機体位置へ固定する")
	bridge._core.step(0.31);bridge._core.step_hazards(0.001);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks.filter(func(n):return n.mode=="sequence" and n.locked).size()==3 and body.necks.filter(func(n):return n.mode=="sequence").all(func(n):return n.position.distance_to(Vector2(800,160) if n.id==participants[0].id else Vector2(900,-120))<0.01),"粗い更新でも三首目まで順に最終地点へ届く")
	bridge.restore(flight.value);bridge.command("dev_damage",{"entity_id":participants[1].id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"参加首一本の消失で順番噛みを中断し全判定を回収する")
	bridge.restore(flight.value);bridge.command("dev_cancel_flow",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"取消で順番噛みの判定を回収する")
	bridge.restore(flight.value);bridge.command("dev_remove",{"entity_id":c.id});bridge._core.step(0.01);check(bridge.command("dev_boss_state").value[0].stage==7,"本体消失で順番噛みを中断する")
	bridge.restore(flight.value)
	for tick in 180:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_state").value.any(func(a):return a.id>first_id and a.kind==89),"自然終了と余白後に次の順番噛みを選べる")
	bridge.release_checkpoint(flight.value);bridge.dispose();view.queue_free()
	c=hydra_major_case("sequence",edits,false);bridge=c.bridge;hydra_grid_separate(c)
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"分離後はSourceと同じく順番噛みを選ばない")
	bridge.dispose();await get_tree().process_frame;print("[cpp_hydra_sequence] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_sequence_second() -> void:
	var c := hydra_major_case("sequence",{"warning_time":0.15,"performance_time":0.85,"sequence_charge":0.08,"sequence_gap":0.2,"normal_lunge":0.12,"bite_radius":35.0,"bite_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05},true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var participants: Array=body.necks.filter(func(n):return n.mode=="sequence")
	participants.sort_custom(func(a,b):return absf(angle_difference(TAU*float(body.necks.find(a))/body.necks.size()+body.facing,(Vector2(800,0)-body.position).angle()))<absf(angle_difference(TAU*float(body.necks.find(b))/body.necks.size()+body.facing,(Vector2(800,0)-body.position).angle())))
	bridge.command("dev_ship_motion",{"position":Vector2(800,160),"velocity":Vector2.ZERO})
	for tick in 25:
		bridge._core.step(0.01)
		if bridge.command("dev_boss_state").value[0].stage==1:break
	bridge._core.step(0.08)
	var events: Array=[];bridge.subscribe("二首目の記録",func(packet):events.append_array(packet.events);return true)
	bridge.command("dev_ship_motion",{"position":Vector2(900,-120),"velocity":Vector2.ZERO});bridge._core.step(0.21)
	body=bridge.command("dev_boss_body_state").value[0];var t: Dictionary=bridge.command("dev_boss_state").value[0]
	var second: Dictionary=body.necks.filter(func(n):return n.id==participants[1].id)[0]
	var fraction: float=clampf((t.performance_time-0.2-0.08)/0.12,0.0,1.0)
	check(second.locked and second.position.distance_to(participants[1].position.lerp(Vector2(900,-120),fraction))<0.01 and events.any(func(e):return e.type=="hydra_cue" and e.payload.cue=="target_locked" and e.payload.neck>=0) and body.necks.filter(func(n):return n.mode=="sequence" and n.locked).size()==2,"二首目は間隔分だけ遅れて新しい機体位置へ固定する")
	bridge.dispose();print("[cpp_hydra_sequence_second] failures=",failed);get_tree().quit(1 if failed else 0)

func hydra_swarm_expected_target(body: Dictionary, neck: Dictionary, ship: Vector2, reach: float) -> Vector2:
	var from: Vector2=neck.position
	var to: Vector2=from+(ship-from).normalized()*reach
	var safe: Rect2=body.arena.grow(-neck.radius)
	var delta: Vector2=to-from
	var fraction := 1.0
	var normal := Vector2.ZERO
	for axis in 2:
		if is_zero_approx(delta[axis]):continue
		var f: float=((safe.end[axis] if delta[axis]>0.0 else safe.position[axis])-from[axis])/delta[axis]
		if f>=0.0 and f<=fraction:
			fraction=f;normal=Vector2.ZERO;normal[axis]=-signf(delta[axis])
	return from.lerp(to,fraction)+normal*0.01

func native_hydra_swarm() -> void:
	var edits := {"warning_time":0.15,"performance_time":0.9,"sequence_charge":0.08,"swarm_gap":0.05,"swarm_flight":0.18,"swarm_reach":1800.0,"bite_radius":35.0,"bite_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("swarm",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	check(c.move.make_runner()==null and load("res://scripts/bosses/legacy_technique_runners.gd").make(c.move).kind()==&"swarm","連続飛びかかりの編集Resourceと互換Runnerを分ける")
	check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"分離前には連続飛びかかりを選ばない")
	hydra_grid_separate(c)
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	check(not actions.is_empty() and actions[0].kind==90,"分離後の共通フローから連続飛びかかりを自然選択する")
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var t: Dictionary=actions[0]
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var rect: Rect2=Rect2(Vector2(-1400,-1000),Vector2(2800,2000)).intersection(body.arena).grow(-70.0)
	var slots: PackedVector2Array=t.swarm_slots
	var exact: bool = slots.size()==body.necks.size()
	for i in slots.size():exact=exact and slots[i].distance_to(rect.get_center()+Vector2(cos(TAU*i/slots.size())*rect.size.x*0.45,sin(TAU*i/slots.size())*rect.size.y*0.45))<0.01
	check(t.positioning and t.performance_time==0.0 and exact and body.necks.all(func(n):return n.mode=="swarm"),"全生存首を画面と闘技場の交差矩形の楕円へ配置し、その間は技時計を止める")
	var preparing: Dictionary=bridge.checkpoint();bridge._core.step(0.02);var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(preparing.ok and bridge.restore(preparing.value).ok,"配置途中の持ち場・到着状態・経過を保持する");bridge._core.step(0.02)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"配置途中の復帰でも同じ位置と点列へ進む")
	var ready := false
	for tick in 1200:
		bridge._core.step(0.02)
		t=bridge.command("dev_boss_state").value[0]
		if not t.positioning:ready=true;break
		if t.stage>=5:break
	body=bridge.command("dev_boss_body_state").value[0]
	check(ready and t.stage==0 and t.performance_time==0.0 and body.effects.is_empty(),"全首の配置完了から予告時計を再開し、配置中には攻撃を出さない")
	if not ready:print(t);bridge.dispose();get_tree().quit(1);return
	var positioned: Dictionary=bridge.checkpoint()
	var origins := {};var targets := {}
	for n: Dictionary in body.necks:
		origins[n.id]=n.position;targets[n.id]=hydra_swarm_expected_target(body,n,Vector2(-200,0),1800.0)
	for tick in 30:
		bridge._core.step(0.01)
		t=bridge.command("dev_boss_state").value[0]
		if t.stage==1:break
	body=bridge.command("dev_boss_body_state").value[0]
	check(is_equal_approx(t.performance_time,0.01) and body.effects.size()==1 and is_equal_approx(body.effects[0].width,35.0) and is_equal_approx(body.effects[0].delay,0.08) and is_equal_approx(body.effects[0].life,0.001) and body.effects[0].points[1].distance_to(targets[body.necks[0].id])<0.02,"発動tickから個別時計を進め、闘技場で切った固定軌道を半径と同じ幅の予告へ出す")
	var active: Dictionary=bridge.checkpoint();var events: Array=[];bridge.subscribe("連続飛びかかりの記録",func(packet):events.append_array(packet.events);return true)
	bridge._core.set_run_guards({"invincible":false});var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":body.effects[0].points[0].lerp(body.effects[0].points[1],0.5),"velocity":Vector2.ZERO});bridge._core.step_hazards(0.04);bridge.command("dev_boss_body_state")
	check(bridge._core.ship_snapshot().ship_hp==hp and not events.any(func(e):return e.type=="combat_player_damage"),"個別予告にはダメージと0ダメージ通知を出さない")
	bridge.restore(active.value);bridge.command("dev_ship_motion",{"position":Vector2(600,-500),"velocity":Vector2.ZERO});bridge._core.step(0.08)
	body=bridge.command("dev_boss_body_state").value[0];t=bridge.command("dev_boss_state").value[0]
	var offensive: Array=body.effects.filter(func(e):return e.delay==0.0)
	var first: Dictionary=body.necks[0]
	var fraction: float=clampf((t.performance_time-0.08)/0.18,0.0,1.0)
	check(first.locked and first.position.distance_to(Vector2(origins[first.id]).lerp(targets[first.id],fraction))<0.02 and offensive.size()==1 and is_equal_approx(offensive[0].width,35.0) and is_equal_approx(offensive[0].life,0.081),"配置後に機体が動いても固定軌道を変えず、Sourceの飛行式とdt+.001の区間を出す")
	check(first.position==first.free_pos and body.necks.all(func(n):return n.points[-1].distance_to(n.position)<0.01),"飛行位置をfree_posと首点列へ同じtickに反映する")
	var view=hydra_move_view(c);await get_tree().process_frame
	var flight: Dictionary=bridge.checkpoint();bridge._core.step(0.02);bridge._core.step_hazards(0.02);expected=bridge.command("dev_boss_body_state").value[0].duplicate(true)
	check(flight.ok and bridge.restore(flight.value).ok,"飛行途中の個別段階・標的・形状を保持する");bridge._core.step(0.02);bridge._core.step_hazards(0.02)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"飛行途中から復帰しても同じ区間と首姿勢になる")
	bridge.restore(flight.value);body=bridge.command("dev_boss_body_state").value[0];offensive=body.effects.filter(func(e):return e.delay==0.0);events.clear()
	bridge._core.set_run_guards({"invincible":false});hp=bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":offensive[0].points[0].lerp(offensive[0].points[1],0.5),"velocity":Vector2.ZERO});bridge._core.step_hazards(0.001);bridge.command("dev_boss_body_state")
	check(hp>bridge._core.ship_snapshot().ship_hp and events.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bite" and e.payload.technique=="swarm" and e.payload.source=="hydra"),"連続飛びかかりが実HPとbite・swarm・hydra通知へ届く")
	bridge.restore(flight.value);bridge.command("dev_damage",{"entity_id":first.id,"amount":1000.0,"cause":"shot"});bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(bridge.command("dev_boss_state").value[0].stage==1 and body.necks.filter(func(n):return n.alive).size()==7 and body.effects.all(func(e):return e.points[0].distance_to(origins[first.id])>0.01),"参加首一本の消失ではその攻撃を消し、残りの首で続ける")
	bridge.restore(flight.value);bridge.command("dev_cancel_flow",{"entity_id":c.id});check(bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"取消で連続飛びかかりの判定と予告を回収する")
	bridge.restore(flight.value);body=bridge.command("dev_boss_body_state").value[0]
	for n: Dictionary in body.necks:bridge.command("dev_damage",{"entity_id":n.id,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.01);check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"全参加首が消えると連続飛びかかりを中断する")
	bridge.restore(flight.value);bridge.command("dev_remove",{"entity_id":c.id});bridge._core.step(0.01);check(bridge.command("dev_boss_state").value[0].stage==7,"本体消失で連続飛びかかりを中断する")
	bridge.restore(flight.value);bridge._core.step(0.65);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks.all(func(n):return n.position.distance_to(targets[n.id])<0.02),"粗い更新でも八首がそれぞれの固定軌道の終端へ届く")
	bridge.restore(flight.value)
	for tick in 200:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	check(bridge.command("dev_boss_state").value.any(func(a):return a.id>first_id and a.kind==90),"自然終了と余白の後に次の連続飛びかかりを選べる")
	bridge.release_checkpoint(preparing.value);bridge.release_checkpoint(positioned.value);bridge.release_checkpoint(active.value);bridge.release_checkpoint(flight.value);bridge.dispose();view.queue_free()
	c=hydra_major_case("swarm",edits,false,{"formation_timeout":0.01});bridge=c.bridge;hydra_grid_separate(c)
	check(bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"配置待ちの直接入口を開始する");bridge._core.step(0.02)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"配置の制限時間を超えると攻撃を出さず中断する");bridge.dispose()
	c=hydra_major_case("swarm",edits,false,{"formation_tolerance":1000000000.0});bridge=c.bridge;hydra_grid_separate(c)
	bridge._core.set_motion_context(Vector2(-200,0),Vector2.ZERO,Vector2(80,80));check(bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"配置後の画面内条件を確かめる入口を開始する");bridge._core.step(0.02)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[0].effects.is_empty(),"到着扱いでも首が画面外に残れば中断する");bridge.dispose()
	c=hydra_major_case("swarm",edits,false);bridge=c.bridge;hydra_grid_separate(c);body=bridge.command("dev_boss_body_state").value[0]
	for i in 7:bridge.command("dev_damage",{"entity_id":body.necks[i].id,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.001);check(not bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"生存首が一本だけでは連続飛びかかりを開始しない");bridge.dispose()
	await get_tree().process_frame;print("[cpp_hydra_swarm] failures=",failed);get_tree().quit(1 if failed else 0)


class TraceRecorder:
	extends "res://scripts/dev/play_recorder.gd"
	func _recording_directory() -> String: return "/tmp/speed-boss-observation-recording"

func trace_recorder(bridge) -> Dictionary:
	var session := RunSession.new()
	session.id = 371
	session.runtime_kind = "cpp"
	session.auto_step = false
	session.bridge = bridge
	add_child(session)
	session.add_to_group("recordable_runs")
	var recorder := TraceRecorder.new()
	add_child(recorder)
	recorder.set_process(false)
	recorder.armed = true
	recorder._begin_cpp(session,true)
	check(recorder._file!=null,"既存の録画入口から共通観測を開始する")
	return {"session":session,"recorder":recorder}

func native_boss_trace() -> void:
	var c := hydra_normal_case(false,{}, {"normal_charge":0.1,"normal_lunge":0.25,"normal_hold":0.05,"attack_cd":0.01,"bite_radius":150.0})
	if c.is_empty(): check(false,"並行首の定義を生成する");get_tree().quit(1);return
	var bridge = c.bridge
	var events: Array = []
	bridge.subscribe("首の観測",func(packet): events.append_array(packet.events);return true)
	var recording := trace_recorder(bridge)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	for index in [0,5]:
		bridge.command("dev_ship_motion",{"position":body.necks[index].position,"velocity":Vector2.ZERO})
		check(bridge.command("dev_boss_technique",{"entity_id":body.necks[index].id,"definition":1}).ok,"並行する首を正式技から開始する")
	for tick in 24:
		bridge._core.step(1.0/120.0)
		bridge._core.step_hazards(1.0/120.0)
		bridge.command("dev_boss_body_state")
	var starts: Array = events.filter(func(e): return e.type=="boss_action" and e.payload.step=="selected")
	var executions: Array = events.filter(func(e): return e.type=="boss_action" and e.payload.step=="execute")
	check(starts.size()==2 and starts[0].payload.action_id!=starts[1].payload.action_id and starts[0].payload.body_id!=starts[1].payload.body_id,"並行首は異なる行動IDを持つ")
	check(executions.size()==2,"判定形状を繰り返し生成してもexecuteは各行動に一度だけ記録する")
	recording.recorder._end("stopped")
	var closed: Array = events.filter(func(e): return e.type=="boss_action" and e.payload.step=="observation_end")
	check(closed.size()==2 and closed.all(func(e): return e.payload.reason=="recording_end" and e.payload.checks>0),"録画停止で並行首の評価をそれぞれ閉じる")
	check(bridge.read_recording().value.active_observations==0,"録画停止後に観測を残さない")
	recording.recorder.free();recording.session.free()
	if "--cpp-boss-trace-stop" in OS.get_cmdline_user_args():
		print("[cpp_boss_trace_stop] failures=",failed)
		get_tree().quit(1 if failed else 0)
		return
	c = hydra_normal_case(false,{}, {"normal_charge":0.1,"normal_hold":0.1,"attack_cd":0.01,"bolt_length":150.0,"bolt_width":60.0,"bolt_speed":200.0,"bolt_life":2.0},"beam_bolt")
	if c.is_empty(): check(false,"残留弾の定義を生成する");get_tree().quit(1);return
	bridge = c.bridge
	events = []
	bridge.subscribe("残留弾の観測",func(packet): events.append_array(packet.events);return true)
	bridge.command("set_recording",{"active":true})
	body = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*200,"velocity":Vector2.ZERO})
	check(bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1}).ok,"残留する弾の技を開始する")
	for tick in 40:
		bridge._core.step(1.0/120.0)
		bridge.command("dev_boss_body_state")
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and bridge.read_recording().value.active_observations==1,"技が終わっても残留弾の元の観測を保持する")
	var old_effect: Dictionary = body.effects[0].duplicate(true)
	head = body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*200,"velocity":Vector2.ZERO})
	check(bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1}).ok,"残留弾がある間に次の技を開始する")
	var old_id: int = events.filter(func(e): return e.type=="boss_action" and e.payload.step=="selected")[0].payload.action_id
	bridge._core.set_run_guards({"invincible":false})
	bridge.command("dev_ship_motion",{"position":(old_effect.points[0]+old_effect.points[1])*0.5,"velocity":Vector2.ZERO})
	bridge._core.step_hazards(1.0/120.0)
	bridge.command("dev_boss_body_state")
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.cause=="bolt")
	check(not hits.is_empty() and hits[-1].payload.observation_id==old_id and hits[-1].payload.hp_before>hits[-1].payload.hp_after,"次の技の開始後も残留弾の実HP減少を元の行動へ加算する")
	bridge.command("dev_remove",{"entity_id":head.id})
	closed = events.filter(func(e): return e.type=="boss_action" and e.payload.step=="observation_end")
	check(closed.size()==2 and closed.all(func(e): return e.payload.reason=="actor_end"),"役者の破棄で残留弾と次の行動の両観測を閉じる")
	bridge.command("set_recording",{"active":false})
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_boss_trace] failures=",failed)
	get_tree().quit(1 if failed else 0)

func hydra_finish_case(name := "", count := 3, limit := -1.0) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true);cfg.planet_radius=0.0
	for key in ["boss_finish_slow_time","boss_finish_blast_time","boss_finish_relic_appear_time","boss_finish_relic_hold_time","boss_finish_relic_collect_time","boss_finish_clear_time"]:cfg.set(key,0.02)
	cfg.time_up_charge_time=0.3
	for key in ["death_freeze_time","death_explosion_time","death_game_over_time"]:cfg.set(key,0.01)
	var boss = load("res://data/bosses/hydra.tres").duplicate(true);boss.speed=0.0;boss.params.growth_time=0.1
	var rules = load("res://data/bosses/ai/hydra_action_rules.tres").duplicate(true)
	var flow = load("res://data/bosses/ai/hydra_flow.tres").duplicate(true)
	if not name.is_empty():
		var selected: Resource=rules.techniques.filter(func(move):return String(move.technique)==name)[0]
		flow.sections=flow.sections.slice(2,3) if selected.category==&"major" else flow.sections.slice(0,1)
		flow.sections[0].next=0;flow.sections[0].fallback=0;flow.sections[0].allowed_techniques=[name]
	var stage := RuntimeStage.new();stage.time_limit=limit+(1.541 if count==9 else 0.22 if count>=8 else 0.11 if count>=5 else 0.0) if limit>=0.0 else -1.0
	var package: Dictionary=builder.boss_package(boss,cfg,stage,{"rules":rules,"flow":flow})
	if package.is_empty():print("生成不可: ",name);return {}
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary=bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":374,"mode":1,"stage_id":"B_hydra_finish","profile":{},"settings":{"hitstop":false}})
	if not configured.ok:print("読込不可: ",name," ",configured);return {}
	bridge.start(374,{"position":Vector2(800,0)});bridge._core.set_run_guards({"invincible":true})
	var events: Array=[];bridge.subscribe("全技の記録",func(packet):events.append_array(packet.events);return true)
	bridge.command("set_recording",{"active":true})
	bridge._core.set_motion_context(Vector2(800,0),Vector2.ZERO,Vector2(1400,1000))
	var id: int=bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var c := {"bridge":bridge,"id":id,"package":package,"cfg":cfg,"events":events}
	if count>=5:
		var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
		bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp*0.4,"cause":"shot"});bridge._core.step(0.11)
	if count>=8:
		var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
		bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp*0.3,"cause":"shot"});bridge._core.step(0.11)
	if count==9:hydra_grid_separate(c)
	if not name.is_empty():
		var rows: Array=package.records.HydraNormalDefinition.filter(func(row):return package.records.BossTechniqueDefinition[row.technique-1].external_id==name)
		if not rows.is_empty():
			var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
			var kinds := ["bite","vortex","debris","beam","thunder"]
			var neck: Dictionary=body.necks.filter(func(n):return n.kind==kinds[rows[0].head_kind])[0]
			var gate: Dictionary=package.records.HydraNormalGate.filter(func(g):return g.technique==rows[0].technique)[0]
			var origin: Vector2=neck.position if gate.distance_origin==1 else neck.points[0] if gate.distance_origin==2 else body.position
			var angle: float=body.facing+(TAU*body.necks.find(neck)/body.necks.size() if gate.angle_origin==1 else 0.0)+gate.angle
			var distance: float=lerpf(gate.minimum,gate.maximum,0.25) if name=="thunder_drop" else (gate.minimum+gate.maximum)*0.5
			var point: Vector2=origin+Vector2.from_angle(angle)*distance
			bridge.command("dev_ship_motion",{"position":point,"velocity":Vector2.ZERO});bridge._core.set_motion_context(point,Vector2.ZERO,Vector2(1400,1000))
	return c

func native_hydra_finish() -> void:
	var stages := {"bite_thrust":3,"bite_sweep":3,"wind_band":3,"wind_blades":3,"rubble_lump":3,"rubble_fan":3,"beam_fixed":5,"beam_bolt":5,"thunder_headbutt":5,"thunder_drop":5,"north":5,"sequence":5,"curve":5,"tornado":3,"debris_shatter":5,"beam_pincer":8,"swarm":9,"grid":9}
	var activated: Array[String]=[]
	for name: String in stages:
		var c := hydra_finish_case(name,stages[name])
		check(not c.is_empty(),"全18技を持つ通常生成パッケージを開始する: "+name)
		if c.is_empty():continue
		var bridge=c.bridge
		check(c.package.records.BossTechniqueDefinition.size()==18 and c.package.records.HydraNormalDefinition.size()==10 and c.package.records.HydraMajorDefinition.size()==8,"全通常技と全大技の定義を同じパッケージで保持する: "+name)
		var emitted := false
		for tick in 2000:
			bridge._core.step(0.02);bridge._core.step_hazards(0.02);bridge.command("dev_boss_body_state")
			emitted=c.events.any(func(event):return event.type=="boss_action" and event.payload.action==name and event.payload.step=="execute")
			if emitted:break
		check(emitted,"元の条件・フロー・予算から選び、全技の実発動を共通IDで記録する: "+name)
		if emitted:activated.append(name)
		var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
		check(body.count==(8 if stages[name]>=8 else stages[name]) and body.separated==(stages[name]==9),"通常HP・低HP・分離後に対応する首構成で選ぶ: "+name)
		var view=hydra_move_view(c)
		check(not view._boss_body_displays.is_empty() and view._boss_body_displays.values()[0].state.necks.size()==body.necks.size(),"全技の本体・首と発動状態を正式表示へ渡す: "+name)
		bridge.dispose();view.queue_free()
	print("[cpp_hydra_finish] 通常選択から実発動=",activated)
	var c := hydra_finish_case("swarm",9)
	if c.is_empty():check(false,"撃破確認の全技生成を開始する");get_tree().quit(1);return
	var bridge=c.bridge
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":body.bearer.id,"amount":body.bearer.hp+1.0,"cause":"shot"});bridge._core.step(0.01)
	check(centaurus_finish_steps(bridge,1) and bridge.read_frame().value.ui.phase==RunIds.Phase.Finishing,"不死首の撃破から共通の決着へ進む")
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.mode==4 and body.effects.is_empty() and not body.has("arena") and body.necks.all(func(n):return not n.alive),"撃破で全首・残留攻撃・闘技場を回収する")
	centaurus_finish_steps(bridge,30)
	var frame: Dictionary=bridge.read_frame().value
	check(frame.result!=null and frame.result.kind=="Clear" and c.events.filter(func(e):return e.type=="boss_defeated").size()==1 and c.events.filter(func(e):return e.type=="clear_banner").size()==1,"撃破とCLEAR・勝利通知を一度だけ確定する")
	bridge.dispose()
	for count in [3,9]:
		c=hydra_finish_case("",count,0.01);bridge=c.bridge
		for tick in 30:
			centaurus_finish_steps(bridge,1)
			var current: Dictionary=bridge.command("dev_boss_body_state").value[0]
			if current.mode==3 and current.effects.any(func(e):return e.get("final",false)):break
		body=bridge.command("dev_boss_body_state").value[0]
		var beams: Array=body.effects.filter(func(e):return e.get("final",false))
		check(body.mode==3 and beams.size()==(9 if count==9 else 3),"時間切れは全生存首から最終ビームを出す: %d"%count)
		check(beams.all(func(e):return e.technique=="final_strike" and is_equal_approx(e.width,body.final_width) and is_equal_approx(e.points[0].distance_to(e.points[1]),Vector2(c.package.records.HydraBodyDefinition[0].arena_x,c.package.records.HydraBodyDefinition[0].arena_y).length()*1.5)),"最終ビームの幅・射程はSourceの式と同じ: %d"%count)
		var view=hydra_move_view(c)
		check(view._boss_final_beams.is_empty() and view._boss_body_displays.values()[0].effects.size()==beams.size(),"ヒドラの首別ビームだけを正式表示し、本体ビームを重複させない: %d"%count)
		var held: Dictionary=bridge.checkpoint();centaurus_finish_steps(bridge,2);var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true)
		check(held.ok and bridge.restore(held.value).ok,"最終ビームの首・時計・所有を途中保持して戻す: %d"%count);centaurus_finish_steps(bridge,2)
		check(bridge.command("dev_boss_body_state").value[0]==expected,"復帰後も同じ首別ビームと幅へ進む: %d"%count)
		centaurus_finish_steps(bridge,50);frame=bridge.read_frame().value
		check(frame.result!=null and frame.result.kind=="Death" and frame.result.last_damage.cause=="final_strike","時間切れの最終攻撃から敗北へ進む: %d"%count)
		bridge.release_checkpoint(held.value);bridge.dispose();view.queue_free()
	c=hydra_finish_case("curve",5);bridge=c.bridge
	for tick in 50:
		bridge._core.step(0.02)
		if not bridge.command("dev_boss_body_state").value[0].effects.is_empty():break
	check(bridge.command("abort",{"reason":0}).ok and bridge.read_frame().value.result.kind=="Abort" and bridge.command("dev_boss_body_state").value[0].mode==5,"途中中断は勝利を付けず全技の本体を取り消す")
	check(bridge.command("dev_boss_body_state").value[0].effects.is_empty() and not bridge.command("dev_boss_body_state").value[0].has("arena"),"途中中断で持続攻撃と闘技場を回収する");bridge.dispose()
	await get_tree().process_frame;print("[cpp_hydra_finish] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_finish_pending() -> void:
	var c := hydra_finish_case("thunder_drop",5)
	if c.is_empty():check(false,"落雷の全技パッケージを開始する");get_tree().quit(1);return
	var bridge=c.bridge
	for tick in 2000:
		bridge._core.step(0.02);bridge._core.step_hazards(0.02);bridge.command("dev_boss_body_state")
		if c.events.any(func(e):return e.type=="boss_action" and e.payload.action=="thunder_drop" and e.payload.step=="execute"):break
	check(c.events.any(func(e):return e.type=="boss_action" and e.payload.action=="thunder_drop" and e.payload.step=="execute"),"元の条件・フロー・予算から選び、全技の実発動を共通IDで記録する: thunder_drop")
	print("[cpp_hydra_finish_pending] 実発動=thunder_drop")
	bridge.dispose()
	for count in [3,9]:
		c=hydra_finish_case("",count,0.01);bridge=c.bridge
		var body: Dictionary
		for tick in 30:
			centaurus_finish_steps(bridge,1);body=bridge.command("dev_boss_body_state").value[0]
			if body.mode==3 and body.effects.any(func(e):return e.get("final",false)):break
		var beams: Array=body.effects.filter(func(e):return e.get("final",false))
		check(body.mode==3 and beams.size()==(9 if count==9 else 3),"時間切れは全生存首から最終ビームを出す: %d"%count)
		check(not beams.is_empty() and beams.all(func(e):return e.technique=="final_strike" and is_equal_approx(e.width,body.final_width) and is_equal_approx(e.points[0].distance_to(e.points[1]),Vector2(c.package.records.HydraBodyDefinition[0].arena_x,c.package.records.HydraBodyDefinition[0].arena_y).length()*1.5)),"最終ビームの幅・射程はSourceの式と同じ: %d"%count)
		var view=hydra_move_view(c)
		check(not beams.is_empty() and view._boss_final_beams.is_empty() and view._boss_body_displays.values()[0].effects.size()==beams.size(),"ヒドラの首別ビームだけを正式表示し、本体ビームを重複させない: %d"%count)
		var held: Dictionary=bridge.checkpoint();centaurus_finish_steps(bridge,2);var expected: Dictionary=bridge.command("dev_boss_body_state").value[0].duplicate(true)
		check(held.ok and bridge.restore(held.value).ok,"最終ビームの首・時計・所有を途中保持して戻す: %d"%count);centaurus_finish_steps(bridge,2)
		check(bridge.command("dev_boss_body_state").value[0]==expected,"復帰後も同じ首別ビームと幅へ進む: %d"%count)
		bridge.release_checkpoint(held.value);bridge.dispose();view.queue_free()
	await get_tree().process_frame;print("[cpp_hydra_finish_pending] failures=",failed);get_tree().quit(1 if failed else 0)

func native_hydra_finish_cause() -> void:
	var c := hydra_finish_case("",9)
	if c.is_empty():check(false,"勝利通知確認の全技パッケージを生成する");get_tree().quit(1);return
	var body: Dictionary=c.bridge.command("dev_boss_body_state").value[0]
	c.bridge.command("dev_damage",{"entity_id":body.bearer.id,"amount":body.bearer.hp+1.0,"cause":"shot"});c.bridge._core.step(0.01);c.bridge.command("dev_boss_body_state")
	if "--cpp-hydra-finish-damage" not in OS.get_cmdline_user_args():check(c.events.any(func(e):return e.type=="boss_defeated" and e.payload.cause=="ram"),"ヒドラの勝利通知原因だけをSourceのramへ保つ")
	check(c.events.any(func(e):return e.type=="combat_damage" and e.payload.cause=="shot"),"首の被弾・観測には実際の原因を保持する")
	c.bridge.dispose();print("[cpp_hydra_finish_cause] failures=",failed);get_tree().quit(1 if failed else 0)


func semantics_number(a: float,b: float) -> bool:
	return absf(a-b)<=maxf(1e-9,maxf(absf(a),absf(b))*1e-9)

func semantics_hydra_finish(bridge,label: String) -> void:
	bridge.dispose();print("SEMANTICS_HYDRA ",label," failures=",failed);get_tree().quit(1 if failed else 0)

func semantics_hydra_curve() -> void:
	var c := hydra_major_case("curve",{"warning_time":0.15,"performance_time":0.55,"curve_delay":0.12,"curve_time":0.35,"curve_turn":0.45,"curve_lag":1.1,"beam_len":600.0,"beam_width":60.0,"beam_dmg":7.0,"tech_recovery":0.05,"cooldown":0.1},true)
	if c.is_empty(): get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	var events: Array=[];bridge.subscribe("曲線の記録",func(packet):events.append_array(packet.events);return true)
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	check(body.count==5 and body.effects.size()==5 and body.effects.all(func(e):return e.points.size()==25 and semantics_number(e.delay,0.12) and semantics_number(e.life,0.35)),"予告開始で全首に24区間の曲線を作り、独立した遅れと寿命を持つ")
	var first: Dictionary=body.effects[0].duplicate(true)
	var angle: float=body.necks[0].angle
	var at: Vector2=first.points[0]
	for j in range(1,25):
		at+=Vector2.from_angle(angle-float(j)/24.0*1.1)*600.0/24.0
		check(at.distance_to(first.points[j])<=1e-4,"曲線の全点の指定許容幅")
	check(at.distance_to(first.points[-1])<=1e-4,"ラジアンの軌跡差と24分割の点列がSourceの式に一致する")
	var facing: float=body.facing
	bridge._core.step(0.1);bridge._core.step_hazards(0.1);body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.facing,facing) and body.effects[0].age<body.effects[0].delay,"予告中は本体を回さず、形だけの時計を進める")
	bridge._core.step(0.05);bridge._core.step_hazards(0.05);body=bridge.command("dev_boss_body_state").value[0]
	semantics_hydra_finish(bridge,"curve")

func semantics_hydra_grid() -> void:
	var edits := {"warning_time":0.15,"performance_time":0.8,"normal_charge":0.1,"grid_time":0.35,"beam_width":60.0,"beam_dmg":7.0,"tech_recovery":0.05,"cooldown":0.1}
	var c := hydra_major_case("grid",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":true})
	hydra_grid_separate(c)
	bridge._core.set_motion_context(Vector2(-200,0),Vector2.ZERO,Vector2(100,80));bridge._core.step(0.01)
	bridge._core.set_motion_context(Vector2(-200,0),Vector2.ZERO,Vector2(1400,1000))
	for tick in 40:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var t: Dictionary=actions[0];var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var source = load("res://data/bosses/hydra.tres")
	var maximum: float=c.cfg.draw_length*c.cfg.base_max_speed/c.cfg.base_max_speed
	var reference: Dictionary=load("res://scripts/bosses/hydra_grid.gd").build(Rect2(Vector2(-1400,-1000),Vector2(2800,2000)).intersection(body.arena),Vector2(-200,0),8,source.params,c.cfg.ship_radius,maximum)
	check(not reference.is_empty() and t.grid_name==String(reference.name) and semantics_number(t.grid_length,reference.length) and t.grid_bearer.distance_to(reference.bearer)<=1e-4,"領域・回転・倍率・経路予算をSourceの配置関数へ照合する")
	var equal: bool = not reference.is_empty() and reference.beams.size()==t.grid_starts.size()
	if equal:
		for i in reference.beams.size():equal=equal and t.grid_starts[i].distance_to(reference.beams[i][0])<=1e-4 and t.grid_ends[i].distance_to(reference.beams[i][1])<=1e-4
	check(equal,"優先順で選んだ全ビームの始点と終点がSourceに一致する")
	var ready := false
	for tick in 600:
		bridge._core.step(0.02);bridge._core.step_hazards(0.02)
		t=bridge.command("dev_boss_state").value[0]
		if t.stage==7:break
		if not t.positioning and not bridge.command("dev_boss_body_state").value[0].effects.is_empty():ready=true;break
	body=bridge.command("dev_boss_body_state").value[0]
	if not ready:print(t);bridge.dispose();get_tree().quit(1);return
	check(body.effects.all(func(e):return e.points.size()==2 and semantics_number(e.delay,0.1) and semantics_number(e.life,0.35)),"格子は線分・個別の遅れ・寿命を持つ")
	check(body.necks.all(func(n):return n.points[-1].distance_to(n.position)<=1e-4),"大技の位置を確定した後に首点列を1回だけ同期する")
	semantics_hydra_finish(bridge,"grid")

func semantics_hydra_pincer() -> void:
	var edits := {"warning_time":0.15,"performance_time":0.7,"pincer_delay":0.1,"pincer_time":0.3,"pincer_open_angle":0.8,"pincer_close_angle":0.12,"beam_len":600.0,"beam_width":60.0,"beam_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("beam_pincer",edits,true,{"combo_cooldown":0.1})
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	hydra_pincer_grow(c)
	for tick in 40:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var passive_angle: float=body.necks[0].angle
	for tick in 15:bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	var t: Dictionary=bridge.command("dev_boss_state").value[0];body=bridge.command("dev_boss_body_state").value[0]
	check(t.stage==1 and t.pincer_aims.size()==2 and body.effects.size()==2 and not semantics_number(passive_angle,body.necks[0].angle),"予告後に2本を発射し、非参加首は普段の操舵を続ける")
	check(body.effects.all(func(e):return e.points.size()==2 and semantics_number(e.delay,0.1) and semantics_number(e.life,0.3)),"挟撃は遅れと寿命が別の2線分として生成する")
	var from: Array=[body.effects[0].points[0],body.effects[1].points[0]];var aims: PackedFloat64Array=t.pincer_aims.duplicate()
	bridge.command("dev_ship_motion",{"position":Vector2(900,-600),"velocity":Vector2.ZERO});bridge._core.set_motion_context(Vector2(900,-600),Vector2.ZERO,Vector2(1400,1000))
	bridge._core.step(0.12);bridge._core.step_hazards(0.12);t=bridge.command("dev_boss_state").value[0];body=bridge.command("dev_boss_body_state").value[0]
	var fraction: float=clampf((t.performance_time-0.1)/0.3,0.0,1.0)
	var exact := true
	for i in 2:
		var angle: float=aims[i]+(1.0 if i==0 else -1.0)*lerpf(0.8,0.12,fraction)
		exact=exact and body.effects[i].points[0].distance_to(from[i])<=1e-4 and body.effects[i].points[1].distance_to(from[i]+Vector2.from_angle(angle)*600.0)<=1e-4
	check(t.pincer_aims==aims and exact,"初回の自機方向を固定し、ラジアンの開始角から終点角へ両側を閉じるSourceの式を保つ")
	semantics_hydra_finish(bridge,"pincer")

func semantics_hydra_north() -> void:
	var edits := {"warning_time":0.24,"performance_time":0.5,"north_flight":0.12,"north_lock_time":0.12,"north_spread":90.0,"bite_radius":35.0,"bite_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("north",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_ship_motion",{"position":Vector2(850,180),"velocity":Vector2.ZERO});bridge._core.step(0.05)
	body=bridge.command("dev_boss_body_state").value[0]
	var targets: Array=body.north_targets.duplicate(true)
	var tracking: Dictionary=bridge.command("dev_boss_state").value[0]
	var direction: Vector2=(Vector2(850,180)-body.position).normalized();var side: Vector2=direction.orthogonal()
	var center: Vector2=body.position+direction*maxf(Vector2(850,180).distance_to(body.position),body.radius+c.package.records.HydraBodyDefinition[0].neck_rest)
	var ordered: Array=targets.duplicate(true);ordered.sort_custom(func(a,b):return a.target.dot(side)<b.target.dot(side))
	var exact := ordered.size()==3
	for i in ordered.size():exact=exact and ordered[i].target.distance_to(center+side*90.0*(i-1))<=1e-4
	check(exact,"根元の横位置で並べた三首へ中心と90間隔のSource標的式を使う")
	bridge._core.step(0.06);body=bridge.command("dev_boss_body_state").value[0];targets=body.north_targets.duplicate(true)
	bridge.command("dev_ship_motion",{"position":Vector2(950,-220),"velocity":Vector2.ZERO});bridge._core.step(0.03)
	body=bridge.command("dev_boss_body_state").value[0]
	var view=hydra_move_view(c);await get_tree().process_frame
	for tick in 20:
		bridge._core.step(0.01)
		if bridge.command("dev_boss_state").value[0].north_burst:break
	body=bridge.command("dev_boss_body_state").value[0]
	var from: Array=body.necks.filter(func(n):return n.mode=="north").map(func(n):return n.position)
	bridge._core.step(0.04);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==3 and body.effects.all(func(e):return e.points.size()==2 and semantics_number(e.width,70.0) and semantics_number(e.life,0.041)),"次の首更新で移動区間を三つの幅付き線分へ出す")
	semantics_hydra_finish(bridge,"north")

func semantics_hydra_sequence() -> void:
	var edits := {"warning_time":0.15,"performance_time":0.85,"sequence_charge":0.08,"sequence_gap":0.2,"normal_lunge":0.12,"bite_radius":35.0,"bite_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("sequence",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var participants: Array=body.necks.filter(func(n):return n.mode=="sequence")
	participants.sort_custom(func(a,b):return absf(angle_difference(TAU*float(body.necks.find(a))/body.necks.size()+body.facing,(Vector2(800,0)-body.position).angle()))<absf(angle_difference(TAU*float(body.necks.find(b))/body.necks.size()+body.facing,(Vector2(800,0)-body.position).angle())))
	var before_facing: float=body.facing
	bridge.command("dev_ship_motion",{"position":Vector2(800,160),"velocity":Vector2.ZERO})
	for tick in 25:
		bridge._core.step(0.01)
		if bridge.command("dev_boss_state").value[0].stage==1:break
	var t: Dictionary=bridge.command("dev_boss_state").value[0];body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(t.performance_time,0.01) and body.effects.is_empty() and not semantics_number(body.facing,before_facing),"発動tickから実行時計へdtを加え、本体は機体へ向け続ける")
	bridge._core.step(0.08);body=bridge.command("dev_boss_body_state").value[0];t=bridge.command("dev_boss_state").value[0]
	var first: Dictionary=body.necks.filter(func(n):return n.id==participants[0].id)[0]
	var fraction: float=clampf((t.performance_time-0.08)/0.12,0.0,1.0)
	check(body.effects.size()==1 and first.locked and first.position.distance_to(participants[0].position.lerp(Vector2(800,160),fraction))<=1e-4 and body.effects[0].points[0].distance_to(participants[0].position)<=1e-4,"一首目は個別の溜め後に現在の機体へ固定しSourceのlerp区間を出す")
	check(semantics_number(body.effects[0].width,70.0) and semantics_number(body.effects[0].life,0.081),"順番噛みの線分幅は半径の二倍、寿命はmax(dt,.02)+.001")
	semantics_hydra_finish(bridge,"sequence")

func semantics_hydra_swarm() -> void:
	var edits := {"warning_time":0.15,"performance_time":0.9,"sequence_charge":0.08,"swarm_gap":0.05,"swarm_flight":0.18,"swarm_reach":1800.0,"bite_radius":35.0,"bite_dmg":7.0,"cooldown":0.1,"tech_recovery":0.05}
	var c := hydra_major_case("swarm",edits,true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge
	hydra_grid_separate(c)
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var t: Dictionary=actions[0]
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var rect: Rect2=Rect2(Vector2(-1400,-1000),Vector2(2800,2000)).intersection(body.arena).grow(-70.0)
	var slots: PackedVector2Array=t.swarm_slots
	var exact: bool = slots.size()==body.necks.size()
	for i in slots.size():exact=exact and slots[i].distance_to(rect.get_center()+Vector2(cos(TAU*i/slots.size())*rect.size.x*0.45,sin(TAU*i/slots.size())*rect.size.y*0.45))<=1e-4
	var ready := false
	for tick in 1200:
		bridge._core.step(0.02)
		t=bridge.command("dev_boss_state").value[0]
		if not t.positioning:ready=true;break
		if t.stage>=5:break
	body=bridge.command("dev_boss_body_state").value[0]
	if not ready:print(t);bridge.dispose();get_tree().quit(1);return
	var origins := {};var targets := {}
	for n: Dictionary in body.necks:
		origins[n.id]=n.position;targets[n.id]=hydra_swarm_expected_target(body,n,Vector2(-200,0),1800.0)
	for tick in 30:
		bridge._core.step(0.01)
		t=bridge.command("dev_boss_state").value[0]
		if t.stage==1:break
	body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(t.performance_time,0.01) and body.effects.size()==1 and semantics_number(body.effects[0].width,35.0) and semantics_number(body.effects[0].delay,0.08) and semantics_number(body.effects[0].life,0.001) and body.effects[0].points[1].distance_to(targets[body.necks[0].id])<=1e-4,"発動tickから個別時計を進め、闘技場で切った固定軌道を半径と同じ幅の予告へ出す")
	bridge.command("dev_ship_motion",{"position":Vector2(600,-500),"velocity":Vector2.ZERO});bridge._core.step(0.08)
	body=bridge.command("dev_boss_body_state").value[0];t=bridge.command("dev_boss_state").value[0]
	var offensive: Array=body.effects.filter(func(e):return e.delay==0.0)
	var first: Dictionary=body.necks[0]
	var fraction: float=clampf((t.performance_time-0.08)/0.18,0.0,1.0)
	check(first.locked and first.position.distance_to(Vector2(origins[first.id]).lerp(targets[first.id],fraction))<=1e-4 and offensive.size()==1 and semantics_number(offensive[0].width,35.0) and semantics_number(offensive[0].life,0.081),"配置後に機体が動いても固定軌道を変えず、Sourceの飛行式とdt+.001の区間を出す")
	check(first.position==first.free_pos and body.necks.all(func(n):return n.points[-1].distance_to(n.position)<=1e-4),"飛行位置をfree_posと首点列へ同じtickに反映する")
	semantics_hydra_finish(bridge,"swarm")

func semantics_hydra_bite_hit() -> void:
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"normal_lunge":0.4,"normal_hold":0.1,"attack_cd":0.05,"bite_radius":150.0,"bite_dmg":7.0})
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_ship_motion",{"position":body.necks[0].position+Vector2(200,0),"velocity":Vector2.ZERO})
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = []
	bridge.subscribe("命中記録",func(packet): events.append_array(packet.events);return true)
	var hp: float = bridge._core.ship_snapshot().ship_hp
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	for tick in 50:
		bridge._core.step(0.01)
		bridge._core.step_hazards(0.01)
		bridge.command("dev_boss_body_state")
	var hits: Array = events.filter(func(event): return event.type=="combat_player_damage" and event.payload.accepted and event.payload.cause=="bite")
	check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実HPの指定許容幅")
	if failed: print("命中の状態: ",bridge._core.ship_snapshot()," 命中記録: ",hits)
	bridge.dispose()
	print("[cpp_hydra_bite_hit] failures=",failed)
	semantics_hydra_finish(bridge,"bite_hit")

func semantics_hydra_sweep() -> void:
	var move = load("res://data/bosses/hydra_moves/bite_sweep.tres")
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"sweep_time":0.4,"normal_hold":0.1,"attack_cd":0.05,"sweep_arc":1.8,"sweep_reach":350.0,"bite_radius":150.0,"bite_dmg":7.0},"bite_sweep")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = []
	bridge.subscribe("薙ぎの記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_ship_motion",{"position":Vector2(350,0),"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	var hp: float = bridge._core.ship_snapshot().ship_hp
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	bridge._core.step(0.011)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[0].locked and body.effects.size()==1 and semantics_number(body.effects[0].life,0.12) and body.effects[0].width==150.0,"発動時刻に根元を中心とする薙ぎを寿命0.12秒で出す")
	bridge._core.step(0.025)
	for tick in 36:
		bridge._core.step(0.01);bridge._core.step_hazards(0.01);bridge.command("dev_boss_body_state")
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bite")
	check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実HPの指定許容幅")
	semantics_hydra_finish(bridge,"sweep")

func semantics_hydra_bolt() -> void:
	var move = load("res://data/bosses/hydra_moves/beam_bolt.tres")
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"normal_hold":0.25,"attack_cd":0.05,"bolt_length":150.0,"bolt_width":60.0,"bolt_speed":400.0,"bolt_life":2.0,"beam_dmg":7.0},"beam_bolt")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = [];bridge.subscribe("ビーム弾の記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*220,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	bridge._core.step(0.011);body=bridge.command("dev_boss_body_state").value[0]
	var effect: Dictionary = body.effects[0].duplicate(true)
	var direction: Vector2 = (effect.points[1]-effect.points[0]).normalized()
	bridge.command("dev_ship_motion",{"position":effect.points[1]+direction*100,"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hazards(0.3);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects[0].points[0].distance_to(effect.points[0]+direction*120)<=1e-4,"世界時間で等速移動し、前の点列から掃引する")
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="bolt")
	check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実HPの指定許容幅")
	semantics_hydra_finish(bridge,"bolt")

func semantics_hydra_fixed() -> void:
	var move = load("res://data/bosses/hydra_moves/beam_fixed.tres")
	var c := hydra_normal_case(true,{}, {"normal_charge":0.15,"beam_time":0.4,"normal_hold":0.1,"attack_cd":0.05,"beam_len":600.0,"beam_width":60.0,"beam_dmg":7.0},"beam_fixed")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = [];bridge.subscribe("固定ビームの記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[3]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle+0.3)*400,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	bridge._core.step(0.01);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].kind=="beam" and semantics_number(body.effects[0].delay,0.14) and semantics_number(body.effects[0].life,0.4),"予告の最初の更新でcharge-tの遅れを持つビームを作る")
	var first: Dictionary = body.effects[0].duplicate(true)
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle+0.3)*400,"velocity":Vector2.ZERO})
	for tick in 12:
		bridge._core.step(0.01);bridge._core.step_hazards(0.01);bridge.command("dev_boss_body_state")
	body=bridge.command("dev_boss_body_state").value[0]
	bridge._core.step(0.03);body=bridge.command("dev_boss_body_state").value[0]
	var effect: Dictionary = body.effects[0].duplicate(true)
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":effect.points[0].lerp(effect.points[1],0.5),"velocity":Vector2.ZERO})
	bridge._core.step(0.025);bridge._core.step_hazards(0.025);body=bridge.command("dev_boss_body_state").value[0]
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="beam")
	check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実HPの指定許容幅")
	semantics_hydra_finish(bridge,"fixed")

func semantics_hydra_blades() -> void:
	var edits := {"normal_charge":0.15,"blade_interval":0.08,"normal_hold":0.2,"attack_cd":0.05,"blade_size":60.0,"blade_width":40.0,"blade_speed":300.0,"blade_life":3.0,"blade_spread":1.0,"bite_dmg":7.0}
	var move = load("res://data/bosses/hydra_moves/wind_blades.tres")
	var c := hydra_normal_case(true,{},edits,"wind_blades")
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = [];bridge.subscribe("風刃の記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(body.facing+TAU/8)*400,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	bridge._core.step(0.011);body=bridge.command("dev_boss_body_state").value[0]
	if body.effects.is_empty(): bridge.dispose();get_tree().quit(1);return
	var effect: Dictionary = body.effects[0].duplicate(true)
	var origin: Vector2 = (effect.points[0]+effect.points[12])*0.5
	var direction: Vector2 = (effect.points[6]-origin).normalized()
	bridge.command("dev_ship_motion",{"position":effect.points[6]+direction*35,"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hazards(0.2);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects[0].points[6].distance_to(effect.points[6]+direction*60)<=1e-4,"世界時間で刃全体を等速移動させる")
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="wind_blade")
	check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実HPの指定許容幅")
	semantics_hydra_finish(bridge,"blades")

func semantics_hydra_rubble() -> void:
	var name := "rubble_fan" if "--fan" in OS.get_cmdline_user_args() else "rubble_lump"
	var fan := name=="rubble_fan"
	var move = load("res://data/bosses/hydra_moves/%s.tres" % name)
	var edits := {"normal_charge":0.15,"normal_hold":0.25,"attack_cd":0.05,"lump_speed":400.0,"lump_dmg":7.0}
	if fan: edits.merge({"rubble_count":6,"rubble_spread":1.3,"rubble_small_radius":16.0})
	else: edits.lump_r=26.0
	var c := hydra_normal_case(true,{},edits,name)
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	bridge._core.set_run_guards({"invincible":false})
	var events: Array = [];bridge.subscribe("瓦礫の記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[2]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*300,"velocity":Vector2.ZERO})
	for tick in 200:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	for tick in 14: bridge._core.step(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	bridge._core.step(0.011);body=bridge.command("dev_boss_body_state").value[0]
	var count: int = 6 if fan else 1
	var effect: Dictionary = body.effects[0].duplicate(true)
	var rubble: Array = bridge._core.enemies_snapshot().filter(func(e): return e.type=="hydra_rubble" and not e.dead)
	if fan:
		var first_velocity := Vector2(rubble[0].vel[0],rubble[0].vel[1])
		var last_velocity := Vector2(rubble[-1].vel[0],rubble[-1].vel[1])
		for j in rubble.size():
			var expected_velocity:=Vector2.from_angle(body.necks[2].angle+lerpf(-0.65,0.65,float(j)/5.0))*400.0
			check(Vector2(rubble[j].vel[0],rubble[j].vel[1]).distance_to(expected_velocity)<=1e-4,"散弾の全初速をSource式の指定許容幅で照合する")
	bridge.command("dev_ship_motion",{"position":effect.points[0],"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hazards(0.01);body=bridge.command("dev_boss_body_state").value[0]
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="rubble")
	check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実HPの指定許容幅")
	semantics_hydra_finish(bridge,"rubble")

func semantics_hydra_tornado() -> void:
	var c := hydra_major_case("tornado",{"warning_time":0.15,"performance_time":0.65,"tornado_charge":0.2,"tornado_life":0.3,"tornado_speed":400.0,"tornado_width":120.0,"lump_dmg":7.0,"tech_recovery":0.05,"cooldown":0.1},true)
	if c.is_empty(): get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	var events: Array=[];bridge.subscribe("竜巻の記録",func(packet):events.append_array(packet.events);return true)
	for tick in 30:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var heads: Array=body.necks.filter(func(n):return n.mode=="tornado")
	bridge._core.step(0.15);body=bridge.command("dev_boss_body_state").value[0]
	var feed: Array=body.effects.filter(func(e):return e.kind=="tornado_charge")
	var center:Vector2=feed[0].points[0]
	var source_direction:Vector2=(Vector2(800,0)-body.necks.filter(func(n):return n.mode=="tornado" and n.kind=="vortex")[0].position).normalized()
	bridge.command("dev_ship_motion",{"position":feed[0].points[0],"velocity":Vector2.ZERO})
	bridge._core.step_hazards(0.01)
	bridge._core.step(0.06);body=bridge.command("dev_boss_body_state").value[0]
	var active: Array=body.effects.filter(func(e):return e.kind=="tornado")
	check(active.size()==1 and active[0].width==120.0 and active[0].points[0].distance_to(center-source_direction*45.0)<=1e-4 and active[0].points[1].distance_to(center+source_direction*45.0)<=1e-4 and bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead).is_empty(),"個別溜めの時刻に瓦礫を回収し、長さ90の竜巻を放つ")
	if "--semantics-hydra-shape-only" in OS.get_cmdline_user_args():semantics_hydra_finish(bridge,"tornado_shape");return
	if active.is_empty():bridge.dispose();get_tree().quit(1);return
	var effect: Dictionary=active[0].duplicate(true);var direction: Vector2=(effect.points[1]-effect.points[0]).normalized()
	bridge.command("dev_ship_motion",{"position":effect.points[1]+direction*10,"velocity":Vector2.ZERO})
	var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hazards(0.05);body=bridge.command("dev_boss_body_state").value[0]
	var expected: Dictionary=body.duplicate(true)
	check(body.effects[0].points[0].distance_to(effect.points[0]+direction*20)<=1e-4 and semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"竜巻は等速掃引し実HPへ倍率を一度だけ掛ける")
	semantics_hydra_finish(bridge,"tornado")

func semantics_hydra_thunder() -> void:
	var move = load("res://data/bosses/hydra_moves/thunder_drop.tres")
	var c := hydra_thunder_case(true)
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var events: Array = [];bridge.subscribe("落雷の記録",func(packet): events.append_array(packet.events);return true)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var head: Dictionary = body.necks[4]
	var target: Vector2 = head.position+Vector2.from_angle(head.angle)*450
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(30,0)})
	for tick in 200:
		hydra_thunder_tick(bridge,0.01)
		if not bridge.command("dev_boss_state").value.is_empty(): break
	var actions: Array = bridge.command("dev_boss_state").value
	if actions.is_empty(): bridge.dispose();get_tree().quit(1);return
	check(actions[0].aim.distance_to(target+Vector2(12,0))<=1e-4,"開始時に速度とthunder_leadで一度だけ先読みする")
	hydra_thunder_tick(bridge,0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].kind=="lightning" and body.effects[0].points.size()==2 and body.effects[0].width==100.0 and semantics_number(body.effects[0].delay,0.19),"最初の首更新でcharge-tの予告と直径を生成する")
	for tick in 10: hydra_thunder_tick(bridge,0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	var expected: Dictionary = body.duplicate(true)
	var strike: Vector2 = expected.effects[0].points[0]
	bridge._core.set_run_guards({"invincible":false})
	bridge.command("dev_ship_motion",{"position":strike,"velocity":Vector2.ZERO})
	var hp: float = bridge._core.ship_snapshot().ship_hp
	for tick in 11: hydra_thunder_tick(bridge,0.01)
	var hits: Array = events.filter(func(e): return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="lightning")
	check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実HPの指定許容幅")
	semantics_hydra_finish(bridge,"thunder")

func semantics_hydra_headbutt() -> void:
	var c:=hydra_headbutt_case(true)
	if c.is_empty():get_tree().quit(1);return
	var b=c.bridge;var state:Dictionary=b.command("dev_boss_body_state").value[0];var n:Dictionary=state.necks[4]
	var target:Vector2=n.position+Vector2.from_angle(n.angle)*450
	b.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	for tick in 200:
		hydra_thunder_tick(b,0.01)
		if not b.command("dev_boss_state").value.is_empty():break
	var acts:Array=b.command("dev_boss_state").value
	if acts.is_empty():b.dispose();get_tree().quit(1);return
	for tick in 10:hydra_thunder_tick(b,0.01)
	for tick in 5:hydra_thunder_tick(b,0.01)
	state=b.command("dev_boss_body_state").value[0]
	var expected:Dictionary=state.duplicate(true)
	b.command("dev_ship_motion",{"position":target+Vector2(0,80),"velocity":Vector2.ZERO});b._core.set_run_guards({"invincible":false})
	var events:Array=[];b.subscribe("頭突きの落雷記録",func(packet):events.append_array(packet.events);return true)
	var hp:float=b._core.ship_snapshot().ship_hp
	for tick in 9:hydra_thunder_tick(b,0.01)
	state=b.command("dev_boss_body_state").value[0]
	var light:Array=state.effects.filter(func(e):return e.kind=="lightning")
	var hits:Array=events.filter(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="lightning")
	check(light.size()==1 and light[0].points[0].distance_to(target)<=1e-4 and light[0].width==240.0,"踏み込みの終了に狙った位置へ一度だけ落雷する")
	check(semantics_number(hp-b._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"実HPの指定許容幅")
	semantics_hydra_finish(b,"headbutt")

func semantics_hydra_wind() -> void:
	var edits := {"normal_charge":0.15,"wind_time":0.4,"normal_hold":0.1,"attack_cd":0.05,"wind_length":300.0,"wind_width":90.0,"wind_force":400.0}
	pass
	var c := hydra_normal_case(true,{},edits,"wind_band")
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
	var events: Array=[];bridge.subscribe("風の帯の記録",func(packet):events.append_array(packet.events);return true)
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0];var head: Dictionary=body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*200.0,"velocity":Vector2.ZERO})
	for tick in 100:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	bridge._core.step(0.08);bridge._core.step_hazards(0.08);body=bridge.command("dev_boss_body_state").value[0]
	bridge._core.step(0.08);bridge._core.step_hazards(0.08);body=bridge.command("dev_boss_body_state").value[0]
	check(body.necks[1].locked and body.effects.size()==1 and body.effects[0].kind=="wind" and semantics_number(body.effects[0].wind_force,400.0) and semantics_number(body.effects[0].life,0.4),"溜め後に押す力と寿命を持つ無害な風の線分を作る")
	var first: Dictionary=body.effects[0].duplicate(true)
	bridge.command("dev_ship_motion",{"position":Vector2(900,-600),"velocity":Vector2.ZERO});bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	body=bridge.command("dev_boss_body_state").value[0]
	var point: Vector2=first.points[0].lerp(first.points[1],0.5);var direction: Vector2=(first.points[1]-first.points[0]).normalized()
	bridge.command("dev_ship_motion",{"position":point,"velocity":Vector2.ZERO})
	var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.025);bridge._core.step_hazards(0.025);body=bridge.command("dev_boss_body_state").value[0];var ship: Dictionary=bridge._core.ship_snapshot()
	check(ship.ship_vel.distance_to(direction*400.0*0.025)<=1e-4 and ship.ship_hp==hp and ship.ship_hurt==0.0 and ship.ship_invuln==0.0,"接触はforce×世界dtだけ押し、倍率・ダメージ・被弾表示・無敵時間を付けない")
	var expected: Dictionary=body.duplicate(true);var expected_velocity: Vector2=ship.ship_vel
	bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	check(bridge._core.ship_snapshot().ship_vel.distance_to(direction*20.0)<=1e-4,"同じ風に触れている間は毎tick押し出す")
	semantics_hydra_finish(bridge,"wind")

func semantics_hydra_shatter() -> void:
	var c := hydra_major_case("debris_shatter",{"warning_time":0.1,"performance_time":0.8,"shatter_deploy":0.2,"shatter_time":0.4,"shatter_arc":1.8,"rubble_count":3,"beam_len":800.0,"beam_width":80.0,"beam_dmg":7.0,"shard_dmg":9.0,"shard_speed":300.0,"tech_recovery":0.05,"cooldown":0.1},true)
	if c.is_empty():get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_run_guards({"invincible":false})
	var events: Array=[];bridge.subscribe("瓦礫砕きの記録",func(packet):events.append_array(packet.events);return true)
	for tick in 40:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	var actions: Array=bridge.command("dev_boss_state").value
	if actions.is_empty():bridge.dispose();get_tree().quit(1);return
	var first_id: int=actions[0].id
	var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
	var heads: Array=body.necks.filter(func(n):return n.mode=="debris_shatter")
	bridge._core.step(0.1);bridge._core.step(0.05)
	body=bridge.command("dev_boss_body_state").value[0]
	var stones: Array=bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead)
	bridge._core.step(0.06);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and body.effects[0].kind=="beam" and body.effects[0].width==80.0 and body.effects[0].points[1].distance_to(body.effects[0].points[0]+Vector2.from_angle(body.necks.filter(func(n):return n.mode=="debris_shatter" and n.kind=="beam")[0].angle)*800.0)<=1e-4,"展開時刻の後に線分ビームを始める")
	var beam: Dictionary=body.effects[0];var direction: Vector2=(beam.points[1]-beam.points[0]).normalized()
	bridge.command("dev_ship_motion",{"position":beam.points[0]+direction*100,"velocity":Vector2.ZERO})
	var hp: float=bridge._core.ship_snapshot().ship_hp
	bridge._core.step_hazards(0.01)
	check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,7.0*c.cfg.atk_scale),"ビームは線分で実HPへ倍率を一度だけ掛ける")
	for tick in 16:bridge._core.step(0.025);bridge._core.step_hazards(0.025)
	body=bridge.command("dev_boss_body_state").value[0]
	var shots: Array=bridge._core.hostiles_snapshot()
	for j in shots.size():
		var base_angle:float=shots[j-j%6].vel.angle()
		check(shots[j].vel.distance_to(Vector2.from_angle(base_angle+float(j%6)*0.45)*300.0)<=1e-4,"破片の全速度をSourceの式で照合する")
	var cues: Array=events.filter(func(e):return e.type=="hydra_cue" and e.payload.cue=="rubble_shattered")
	if not shots.is_empty():
		bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
		bridge.command("dev_ship_motion",{"position":shots[0].pos,"velocity":Vector2.ZERO})
		hp=bridge._core.ship_snapshot().ship_hp;bridge._core.step_hostiles(0.001);bridge.command("dev_boss_body_state")
		check(semantics_number(hp-bridge._core.ship_snapshot().ship_hp,9.0),"破片はshard_dmgそのままで実HPを減らし追加倍率を掛けない")
	semantics_hydra_finish(bridge,"shatter")

func semantics_hydra_final() -> void:
	var count:=9 if "--separated" in OS.get_cmdline_user_args() else 3
	var c:=hydra_finish_case("",count,0.01)
	if c.is_empty():check(false,"最終攻撃の固定場面を準備する");get_tree().quit(1);return
	var bridge=c.bridge;var body:Dictionary;var input_ship:Vector2
	for tick in 30:
		input_ship=bridge._core.ship_snapshot().ship_pos
		centaurus_finish_steps(bridge,1);body=bridge.command("dev_boss_body_state").value[0]
		if body.mode==3 and body.effects.any(func(e):return e.get("final",false)):break
	var beams:Array=body.effects.filter(func(e):return e.get("final",false))
	var rule:Dictionary=c.package.records.BossBodyDefinition[0]
	var params:Dictionary=c.package.records.HydraBodyDefinition[0]
	var progress:float=clampf((body.final_elapsed-(0.3-rule.final_widen_time))/rule.final_widen_time,0.0,1.0)
	var width:float=lerpf(rule.final_warn_width,rule.final_beam_width,progress*progress)
	var reach:float=Vector2(params.arena_x,params.arena_y).length()*1.5
	check(not beams.is_empty(),"首別最終ビームの数値を採取する")
	for beam:Dictionary in beams:
		var start:Vector2=beam.points[0]
		var direction:Vector2=(input_ship-start).normalized()
		check(("--semantics-hydra-geometry-only" in OS.get_cmdline_user_args() or semantics_number(beam.width,width)) and beam.points[1].distance_to(start+direction*reach)<=1e-4,"最終ビームの幅と終点をSource式の指定許容幅で照合する")
	semantics_hydra_finish(bridge,"final_"+str(count))

func semantics_hydra_body() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/hydra.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	if package.is_empty(): get_tree().quit(1); return
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	if bytes.is_empty():
		for record in builder.Schema.SCHEMA.records:
			for row in package.records[record.name]:
				if not builder.Schema._valid_record(row,record): print("生成入力の不一致: ",record.name," ",row)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":370,"mode":1,"stage_id":"B_hydra_body","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); get_tree().quit(1); return
	bridge.start(370,{"position":Vector2(1600,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge.command("dev_ship_motion",{"position":Vector2(1600,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1600,0),Vector2(1600,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var wall_hit: Dictionary = bridge.command("dev_field_query",{"action":"hit","from":body.arena.get_center(),"to":body.arena.end+Vector2(100,100),"radius":10.0})
	var clear_hit: Dictionary = bridge.command("dev_field_query",{"action":"hit","from":body.arena.get_center(),"to":body.arena.get_center()+Vector2(10,0),"radius":10.0})
	for n: Dictionary in body.necks:
		check(semantics_number(n.length,float(definition.params.neck_rest)*0.3) and n.points.size()==int(definition.params.neck_segments)+1,"最初の技前の短い首と戦闘の点列を確定する")
		check(semantics_number(n.head_hp,float(definition.params.head_hp)*cfg.enemy_hp_mult),"本体と独立した首HPを確定する")

	bridge._core.step(0.1);body=bridge.command("dev_boss_body_state").value[0]
	var hp:float=body.hp
	for cause in ["ram","touch","wave"]:bridge.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":cause,"direction":Vector2.RIGHT,"knock":1500.0})
	body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.hp,hp-3.0),"本体HPの指定許容幅")
	semantics_hydra_finish(bridge,"body")

func semantics_hydra_swim() -> void:
	var c := hydra_normal_case()
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":body.necks[0].id,"amount":1000.0,"cause":"shot"})
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"})
	bridge._core.step(0.001)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.separated and body.participants.size()==10 and body.bearer.alive and body.necks.all(func(n): return n.alive and semantics_number(n.hp,n.max_hp)),"実分離で全首と不死首の所有・HPを作る")
	var before := body.duplicate(true)
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	bridge._core.step(1.2)
	bridge._core.step(0.025)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.bearer.velocity.length()>0 and body.bearer.points.size()>8 and body.bearer.points[-1].distance_to(body.bearer.position)<=1e-4,"不死首が操舵し、胴体の先端が確定した頭に一致する")
	semantics_hydra_finish(bridge,"swim")

func semantics_hydra_squad() -> void:
	var retry := "--cpp-hydra-squad-retry" in OS.get_cmdline_user_args()
	var c := hydra_squad_case({"pincer_weight":1.0,"wave_weight":0.0,"wall_weight":0.0,"wall_near_weight":0.0,"initial_gap":Vector2(3.2,3.2),"pincer_timeout":0.05,"counter_max":0,"block_distance":0.0})
	if c.is_empty(): get_tree().quit(1);return
	var bridge = c.bridge
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.necks.any(func(n): return n.role==1) and body.necks.any(func(n): return n.velocity.length()>30.0) and body.necks.all(func(n): return body.arena.has_point(n.position) and n.points[-1].distance_to(n.position)<=1e-4),"前衛と近衛を選び、確定した頭を追う胴と囲いの内側の移動を保つ")
	for head: Dictionary in body.necks:
		if head.kind!="bite": bridge.command("dev_damage",{"entity_id":head.id,"amount":1000.0,"cause":"shot"})
	# 実在する噛みつく2本を使い、保存値を近似技に置き換えない。
	var launched := false
	for tick in 180:
		bridge._core.step(0.025)
		body = bridge.command("dev_boss_body_state").value[0]
		if body.pair_launched:
			launched=true
			break
	var flow: Dictionary = bridge.command("dev_boss_flow_state").value[0]
	check(semantics_number(flow.stamina,6.0) and semantics_number(flow.spent,2.0) and flow.active,"指名の予約を実行時に解放し同じフローの予算を2本分だけ消費する")
	bridge.dispose()
	c = hydra_squad_case({"pincer_weight":0.0,"wave_weight":0.0,"wall_weight":1.0,"wall_near_weight":0.0,"block_distance":10000.0})
	if c.is_empty(): get_tree().quit(1);return
	bridge=c.bridge;body=bridge.command("dev_boss_body_state").value[0]
	var n: Dictionary = body.necks[0]
	bridge.command("dev_ship_motion",{"position":n.free_pos+Vector2.from_angle(n.look_angle)*100.0,"velocity":Vector2.ZERO})
	bridge._core.step(0.025)
	body=bridge.command("dev_boss_body_state").value[0];flow=bridge.command("dev_boss_flow_state").value[0]
	check(body.necks.any(func(head): return head.counter and head.mode=="bite_thrust") and body.counter_time>0.0 and semantics_number(flow.stamina,7.0) and not flow.active and flow.completed==0,"迎撃が通常技を実行して共通予算を消費し、区間の完了数を増やさない")
	semantics_hydra_finish(bridge,"squad")

func semantics_hydra_regrow() -> void:
	var c:=hydra_regrow_case();var bridge=c.bridge
	var before:Dictionary=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":before.necks[0].id,"amount":1000.0,"cause":"shot"})
	bridge.command("dev_damage",{"entity_id":before.necks[1].id,"amount":1000.0,"cause":"fire"})
	var body:Dictionary=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.necks[0].regrow,0.4) and semantics_number(body.necks[1].regrow,0.6),"再生猶予と炎の待ちの指定許容幅")
	bridge.dispose();c=hydra_regrow_case();bridge=c.bridge
	before=bridge.command("dev_boss_body_state").value[0]
	for n:Dictionary in before.necks:bridge.command("dev_damage",{"entity_id":n.id,"amount":1000.0,"cause":"shot"})
	bridge._core.step(0.001);body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.chance_left,0.3),"全滅時の露出時間の指定許容幅")
	bridge._core.step(0.2);body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.necks[2].regrow,0.2),"露出中の再生時計の指定許容幅")
	bridge.dispose();c=hydra_regrow_case();bridge=c.bridge
	var input:Dictionary=bridge.pack_intent(Intent.new());input.press=true;input.touch=true;input.pen=Vector2(1600,0)
	bridge._core.handle_draw(input,1000,1.0)
	input.press=false;input.has_cursor=true;input.pen=Vector2(2000,0);input.pen_release=true
	bridge._core.handle_draw(input,1010,1.0);before=bridge.command("dev_boss_body_state").value[0]
	for j in 2:bridge.command("dev_damage",{"entity_id":before.necks[j].id,"amount":1000.0,"cause":"ram"})
	body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.necks[1].regrow,0.375),"同一描線の連続撃破猶予の指定許容幅")
	bridge.dispose();c=hydra_regrow_case();bridge=c.bridge;before=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":before.max_hp*0.7,"cause":"shot"})
	body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.growth_left,0.1),"5首成長時計の指定許容幅")
	bridge._core.step(0.101);body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.growth_left,0.1),"8首成長時計の指定許容幅")
	semantics_hydra_finish(bridge,"regrow")

func semantics_draco_body() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/draco.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	if package.is_empty(): get_tree().quit(1); return
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":146,"mode":1,"stage_id":"B_draco_body","profile":{},"settings":{"hitstop":false}})
	if not configured.ok: print(configured); get_tree().quit(1); return
	bridge.start(146,{"position":Vector2(1800,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge._core.set_motion_context(Vector2(1800,0),Vector2(-900,0),Vector2(640,360))
	var spawned: Dictionary = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false})
	if not spawned.ok: get_tree().quit(1); return
	var id: int = spawned.value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var ids := {}
	for part: Dictionary in body.participants:
		ids[part.id] = true

	bridge._core.step(0.1);body=bridge.command("dev_boss_body_state").value[0]
	var tail_id:int=body.participants[-1].id
	for target in [id,tail_id]:bridge.command("dev_damage",{"entity_id":target,"amount":10.0,"cause":"bullet","direction":Vector2.RIGHT,"knock":1500.0})
	body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.hp,body.max_hp-20.0) and semantics_number(body.segments[-1].hp,definition.hp),"胴から本体への共有HPの指定許容幅")
	bridge.command("dev_damage",{"entity_id":tail_id,"amount":1.0e8,"cause":"bullet"});body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.hp,body.max_hp*0.7),"第2形態のSource HP下限の指定許容幅")
	bridge._core.step(1.01);bridge.command("dev_damage",{"entity_id":id,"amount":1.0e8,"cause":"bullet"});body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.hp,body.max_hp*0.4),"第3形態のSource HP下限の指定許容幅")
	semantics_hydra_finish(bridge,"draco_body")

func semantics_draco_pose() -> void:
	var form = load("res://scripts/bosses/draco_form.gd")
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/draco.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	check(bridge.configure(bytes,{"api_version":1,"run_id":151,"mode":1,"stage_id":"B_draco_pose","profile":{},"settings":{"hitstop":false}}).ok,"姿勢と寸法の編集値をC++へ読む")
	bridge.start(151,{"position":Vector2(500,0)})
	bridge.subscribe("確認",func(_frame): return true)
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var neutral := PackedVector2Array([Vector2.ZERO])
	for j in int(definition.params.body_segments):
		var t := float(j+1)/float(definition.params.body_segments)
		neutral.append(Vector2(-t*float(definition.params.body_length),sin(t*TAU*1.25)*float(definition.params.body_wave)*sin(t*PI*0.8)))
	var original_length: float = form.length(neutral)
	for j in neutral.size(): neutral[j] *= float(definition.params.body_length)/original_length
	var same: bool = body.body_points.size()==neutral.size()
	for j in neutral.size(): same = same and body.body_points[j].distance_to(neutral[j])<=1e-4
	check(same,"最初の姿勢は既存と同じ波と長さの点列を使う")
	var base_radius: float = body.radius
	check(semantics_number(base_radius,definition.radius*float(definition.params.head_scale)),"頭の半径にキャラクター倍率を重ねない")
	for depth in [0.25,0.1,1.0]:
		check(bridge.command("dev_draco_pose",{"entity_id":id,"operation":"depth","depth":depth,"alpha":0.4}).ok,"深度と透明度を適用する")
		body = bridge.command("dev_boss_body_state").value[0]
		check(semantics_number(body.radius,base_radius*depth) and semantics_number(body.alpha,0.4),"深度は頭の命中半径と表示の両方へ同じ倍率を渡す")
		for j in body.segments.size():
			var fraction := float(j+1)/float(body.segments.size())
			check(body.segments[j].position.distance_to(form.sample(body.body_points,fraction))<=1e-4 and semantics_number(body.segments[j].radius,float(definition.params.body_width)*0.5*form.taper(fraction)*depth),"描画と部位は同じ距離分率と尾の太さを使う")
	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"reset"})
	var override := PackedVector2Array([Vector2.ZERO,Vector2(80,0),Vector2(80,500),Vector2(900,500)])
	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"override","points":override})
	body = bridge.command("dev_boss_body_state").value[0]
	for j in body.segments.size():
		check(body.segments[j].position.distance_to(form.sample(override,float(j+1)/float(body.segments.size())))<=1e-4,"違う点数の姿勢でも部位を距離で配置する")

	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"depth","depth":0.25,"alpha":0.4})
	bridge.command("dev_draco_pose",{"entity_id":id,"operation":"reset"});body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.perspective_scale,1.0) and semantics_number(body.alpha,1.0) and semantics_number(body.radius,base_radius),"取消時の寸法の指定許容幅")
	semantics_hydra_finish(bridge,"draco_pose")

func semantics_hydra_detached() -> void:
	var kind:="bite_sweep"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--move="):kind=arg.trim_prefix("--move=")
	var edits:={"normal_charge":0.15,"normal_hold":0.3,"attack_cd":0.05,"sweep_time":0.4,"sweep_arc":1.8,"sweep_reach":350.0,"bite_radius":150.0,"wind_time":0.4,"wind_length":300.0,"wind_width":90.0,"wind_force":400.0,"blade_interval":0.08,"blade_size":60.0,"blade_width":40.0,"blade_speed":300.0,"blade_life":3.0,"blade_spread":1.0,"bite_dmg":7.0,"lump_speed":400.0,"lump_dmg":7.0,"rubble_count":6,"rubble_spread":1.3,"rubble_small_radius":16.0,"lump_r":26.0}
	var move=load("res://data/bosses/hydra_moves/%s.tres"%kind)
	var allowed:Dictionary=move.values();var selected:={}
	for key in edits:
		if allowed.has(key):selected[key]=edits[key]
	var c:=hydra_normal_case(false,{},selected,kind)
	if c.is_empty():check(false,"分離後の数値場面を準備する");get_tree().quit(1);return
	var bridge=c.bridge;bridge._core.set_attack_formation_mode(true)
	var body:Dictionary=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp+1.0,"cause":"shot"});bridge._core.step(0.001);bridge._core.step(1.21)
	body=bridge.command("dev_boss_body_state").value[0]
	var row:int=2 if kind.begins_with("rubble") else 0 if kind=="bite_sweep" else 1
	var head:Dictionary=body.necks[row]
	if head.cd>0:bridge._core.step(head.cd+0.001)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[row]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.look_angle)*400.0,"velocity":Vector2.ZERO})
	check(bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1}).ok,"分離後の数値対象の技を開始する")
	if kind=="wind_band":bridge._core.step(0.08);bridge._core.step_hazards(0.08);bridge._core.step(0.08);bridge._core.step_hazards(0.08)
	else:bridge._core.step(0.16)
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[row]
	var effects:Array=body.effects.filter(func(e):return e.technique==kind)
	check(not effects.is_empty(),"分離後の実際の攻撃値を採取する")
	if effects.is_empty():semantics_hydra_finish(bridge,"detached_"+kind);return
	if kind=="bite_sweep":check(semantics_number(effects[-1].life,0.1),"分離後の薙ぎ区間の寿命の指定許容幅")
	elif kind=="wind_band":
		check(effects[0].points[0].distance_to(head.position)<=1e-4,"分離後の風の初期起点の指定許容幅")
		bridge._core.step(0.05);bridge._core.step_hazards(0.05);body=bridge.command("dev_boss_body_state").value[0]
		check(body.effects[0].points[0].distance_to(body.necks[row].position)<=1e-4,"分離後の風の頭追従の指定許容幅")
	elif kind=="wind_blades":
		check(((effects[0].points[0]+effects[0].points[12])*0.5).distance_to(head.position)<=1e-4,"分離後の風刃1枚目の起点の指定許容幅")
		bridge._core.step(0.08);body=bridge.command("dev_boss_body_state").value[0]
		check(((body.effects[-1].points[0]+body.effects[-1].points[12])*0.5).distance_to(body.necks[row].position)<=1e-4,"分離後の風刃2枚目の起点の指定許容幅")
	else:
		var stones:Array=bridge._core.enemies_snapshot().filter(func(e):return e.type=="hydra_rubble" and not e.dead)
		for j in stones.size():
			var angle:float=head.look_angle+(float(j)/5.0-0.5)*1.3 if kind=="rubble_fan" else head.look_angle
			check(Vector2(stones[j].pos[0],stones[j].pos[1]).distance_to(head.position)<=1e-4 and Vector2(stones[j].vel[0],stones[j].vel[1]).distance_to(Vector2.from_angle(angle)*400.0)<=1e-4,"分離後の瓦礫の起点と視線方向速度の指定許容幅")
	semantics_hydra_finish(bridge,"detached_"+kind)

func semantics_hydra_lifecycle() -> void:
	var edits:={"normal_charge":0.15,"blade_interval":0.08,"normal_hold":0.2,"attack_cd":0.05,"blade_size":60.0,"blade_width":40.0,"blade_speed":300.0,"blade_life":3.0,"blade_spread":1.0,"bite_dmg":7.0}
	var c:=hydra_regrow_case(false,{},edits,"wind_blades");var bridge=c.bridge
	bridge._core.set_attack_formation_mode(true);bridge._core.set_motion_context(Vector2(1600,0),Vector2.ZERO,Vector2(2500,1800));bridge._core.step(4.0)
	var body:Dictionary=bridge.command("dev_boss_body_state").value[0];var head:Dictionary=body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(body.facing+TAU/3)*400,"velocity":Vector2.ZERO})
	check(bridge.command("dev_boss_technique",{"entity_id":head.id,"definition":1}).ok,"成長前の風刃の数値場面を開始する")
	bridge._core.step(0.16);body=bridge.command("dev_boss_body_state").value[0]
	bridge.command("dev_damage",{"entity_id":c.id,"amount":body.max_hp*(1.0-c.package.records.HydraRegrowDefinition[0].growth_first+0.01),"cause":"shot"})
	bridge._core.step(0.01);bridge._core.step_hazards(0.05)
	bridge._core.step(0.11);bridge._core.step(0.01);bridge._core.step_hazards(0.01);body=bridge.command("dev_boss_body_state").value[0]
	check(body.effects.size()==1 and semantics_number(body.effects[0].age,0.01),"成長後に再開した風刃時計の指定許容幅")
	bridge.dispose()
	c=hydra_normal_case(true,{}, {"normal_charge":0.15,"wind_time":0.4,"normal_hold":0.1,"attack_cd":0.05,"wind_length":300.0,"wind_width":90.0,"wind_force":400.0},"wind_band");bridge=c.bridge
	body=bridge.command("dev_boss_body_state").value[0];head=body.necks[1]
	bridge.command("dev_ship_motion",{"position":head.position+Vector2.from_angle(head.angle)*200.0,"velocity":Vector2.ZERO})
	for tick in 100:
		bridge._core.step(0.01)
		if not bridge.command("dev_boss_state").value.is_empty():break
	bridge._core.step(0.08);bridge._core.step_hazards(0.08);bridge._core.step(0.08);bridge._core.step_hazards(0.08)
	bridge.command("dev_ship_motion",{"position":Vector2(900,-600),"velocity":Vector2.ZERO});bridge._core.step(0.01);bridge._core.step_hazards(0.01)
	bridge._core.step(0.5);bridge._core.step_hazards(0.5);body=bridge.command("dev_boss_body_state").value[0]
	check(semantics_number(body.necks[1].cd,0.05),"自然終了したtickの再使用待ちの指定許容幅")
	semantics_hydra_finish(bridge,"lifecycle")
## 既存の優先行動場面から、まだ数値幅を確かめていない値だけを読む。
func semantics_centaurus_finish() -> void:
	var f := centaurus_finish_case(-1.0,true,{"leap_trigger":0.0,"retreat_trigger":0.0})
	var bridge = f.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(100,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(100,0),Vector2(100,0),Vector2(640,360))
	bridge._core.step(0.01)
	var attacks: Array = bridge.command("dev_boss_state").value
	if attacks.is_empty():failed+=1;push_error("踏みつけの場面を開始できない")
	else:semantics_approx(attacks[0].elapsed,0.0,"native_centaurus_finish:stomp_elapsed")
	bridge.dispose()
	f=centaurus_finish_case(-1.0,true,{},true);bridge=f.bridge
	centaurus_finish_low(f)
	bridge.command("dev_ship_motion",{"position":Vector2(600,0),"velocity":Vector2(0,2000)})
	bridge._core.step(0.6);bridge._core.step(0.61)
	semantics_approx(bridge.command("dev_boss_body_state").value[0].path_hold,0.0,"native_centaurus_finish:path_hold")
	bridge.dispose()
	f=centaurus_finish_case(-1.0,true,{},true);bridge=f.bridge
	bridge.command("dev_ship_motion",{"position":Vector2(100,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(100,0),Vector2(100,0),Vector2(640,360))
	bridge._core.step(0.01)
	semantics_approx(bridge.command("dev_boss_body_state").value[0].leap_to,Vector2(-320,0),"native_centaurus_finish:leap_to")
	bridge._core.step(0.175);bridge._core.step(0.175)
	attacks=bridge.command("dev_boss_state").value
	if attacks.is_empty():failed+=1;push_error("着地後の壁の場面を開始できない")
	else:semantics_approx(attacks[0].elapsed,0.0,"native_centaurus_finish:wall_elapsed")
	bridge.dispose();print("SEMANTICS_CENTAURUS_FINISH failures=",failed);get_tree().quit(1 if failed else 0)
