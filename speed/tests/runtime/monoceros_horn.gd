extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if semantics_strict():return
	if not ok:
		failed += 1
		push_error(label)

func aligned(actor: MonocerosBoss) -> bool:
	var horn: Sprite2D = actor._presentation.horn
	var lengths: PackedFloat32Array = horn.texture.get_meta("core_lengths")
	var root := actor.to_local(horn.global_position)
	var tip := actor.to_local(horn.to_global(Vector2.DOWN * lengths[horn.frame]))
	return absf(tip.dot((tip - root).normalized()) - actor.horn_length()) < 0.01

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
	if "--cpp-body-hud" in OS.get_cmdline_user_args() or "--cpp-body-view-retry" in OS.get_cmdline_user_args():
		call_deferred("native_body_hud")
		return
	if "--cpp-body-retry" in OS.get_cmdline_user_args():
		call_deferred("native_body_retry")
		return
	if "--cpp-body" in OS.get_cmdline_user_args():
		call_deferred("native_body")
		return
	var session := RunManager.create_session(self, {
		"lab": true, "stage": ContentManager.runtime_stage(1), "stage_index": 1, "seed": 42,
	}, true)
	session.auto_step = false
	session.sim.bosses.spawn(load("res://data/bosses/monoceros.tres"), Vector2.ZERO)
	var actor := session.sim.bosses.actor as MonocerosBoss
	actor.selection_enabled = false
	actor.mode = &"idle"
	var view = actor._presentation
	check(view.horn.frame == 0, "第一形態は通常の角")
	check(view.horn.texture.normal_texture != null and view.horn.material.get_shader_parameter("use_normal"), "角に法線照明を適用")
	check(aligned(actor), "通常角の先端は既存の判定長と一致")
	actor.phase_pending = true
	actor.sim_tick(0.01, 0.01)
	check(actor.phase == 2 and view.horn.frame > 0 and view.horn.frame < 14, "第二形態に入ると変形を開始")
	actor.sim_tick(0.45, 0.45)
	var halfway: int = view.horn.frame
	check(halfway > 1 and halfway < 14, "変形の途中フレームを表示")
	actor.sim_tick(0.2, 0.0)
	view._process(0.2)
	check(view.horn.frame == halfway, "世界時間の停止中は変形も停止")
	actor.sim_tick(0.55, 0.55)
	check(view.horn.frame == 14 and actor.mode == &"idle", "形態移行の待機時間内に剣へ変形を完了")
	check(aligned(actor), "剣の先端は既存の判定長と一致")
	actor.sim_tick(0.5, 0.5)
	check(view.horn.frame == 14, "第二形態は最終フレームを保持")
	actor.table.facing[actor.body] += 0.8
	actor.presentation_advanced.emit(0.1)
	check(aligned(actor), "頭の旋回後も角の長さを維持")
	actor.technique = &"charge"
	actor.mode = &"active"
	actor.presentation_advanced.emit(0.01)
	check(view.horn.self_modulate.r > 1.0, "角を使う攻撃中は発光")
	actor.mode = &"idle"
	var restored = actor.presentation_scene.instantiate()
	actor.add_child(restored)
	restored.bind_monoceros(actor)
	check(restored.horn.frame == 14, "第二形態の表示を途中から作っても通常角へ戻さない")
	restored.queue_free()
	session.queue_free()
	await get_tree().process_frame
	print("[monoceros-horn] failures=", failed)
	get_tree().quit(1 if failed else 0)

## 同じ角の検査をC++の本体・表示入口へつなぐ。
func native_aligned(view, body: Dictionary) -> bool:
	var lengths: PackedFloat32Array = view.horn.texture.get_meta("core_lengths")
	var root: Vector2 = view.to_local(view.horn.global_position)
	var tip: Vector2 = view.to_local(view.horn.to_global(Vector2.DOWN*lengths[view.horn.frame]))
	return absf(tip.dot((tip-root).normalized())-float(body.horn_length))<0.01

func native_body() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/monoceros.tres").duplicate(true)
	definition.params.initial_wait = 0.5
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	check(bridge.configure(bytes,{"api_version":1,"run_id":148,"mode":1,"stage_id":"B_monoceros_body","profile":{},"settings":{"hitstop":false}}).ok,"本体の型付き定義と表示資源を読む")
	bridge.start(148,{"position":Vector2(1000,0)})
	bridge.command("dev_ship_motion",{"position":Vector2(1000,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1000,0),Vector2(1000,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.participants.size()==1 and body.participants[0].id==id and body.participants[0].health_target==id and body.participants[0].is_body,"単体の論理参加者とHPの参照先を本体IDへそろえる")
	var view = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	view.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(view)
	view.apply_frame(body,{},definition.part_appearance)
	check(view.horn.frame==0 and native_aligned(view,body),"最初の技前に通常角と判定長を合わせる")
	check(view.horn.texture.normal_texture!=null and view.horn.material.get_shader_parameter("use_normal"),"準備済み角アトラスの色と法線・メタデータを使う")
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	check(semantics_approx(body.position,Vector2(45,0),"native_body:position") and semantics_approx(body.velocity,Vector2(450,0),"native_body:velocity"),"初回待ち中も通常の接近速度で前進する")
	var before: Vector2 = body.velocity
	for cause in ["ram","touch","wave"]:
		bridge.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":cause,"direction":Vector2.RIGHT,"knock":1500.0})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity==before and semantics_approx(body.hp,body.max_hp-3.0,"native_body:hp"),"被弾はHPへ通し外力で自力移動を変えない")
	if semantics_strict():
		bridge.dispose();view.queue_free();get_tree().quit(1 if failed else 0);return
	view.apply_frame(body,{},definition.part_appearance)
	check(view.parts.modulate.r>1.0,"被弾の表示値を本体へ反映する")
	bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp*0.6,"cause":"bullet"})
	bridge._core.step(0.01)
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(body)
	check(body.phase==2 and body.mode==2 and view.horn.frame>0 and view.horn.frame<14,"C++の形態移行開始から角の変形を表示する")
	bridge._core.step(0.45)
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(body)
	var halfway: int = view.horn.frame
	check(halfway>1 and halfway<14 and native_aligned(view,body),"途中の角を本体の進行と判定長へ合わせる")
	var held: Dictionary = bridge.checkpoint()
	view.apply_frame(body)
	check(view.horn.frame==halfway,"世界時間が止まる間は変形を進めない")
	var restored = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	restored.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(restored)
	restored.apply_frame(body)
	check(restored.horn.frame==halfway and native_aligned(restored,body),"表示を途中から作っても同じ変形へ復帰する")
	bridge._core.step(0.55)
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(body)
	check(view.horn.frame==14 and body.mode==1 and native_aligned(view,body),"形態移行内に剣を完成して判定長へ合わせる")
	check(bridge.restore(held.value).ok,"形態途中の本体状態を保持復帰する")
	bridge.release_checkpoint(held.value)
	var frame: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	check(frame.boss_bodies[0].participants[0].id==id and frame.boss_bodies[0].max_hp==body.max_hp,"本体IDとHP表示値を共通の描画出力へ渡す")
	bridge.command("dev_cancel_boss",{"entity_id":id})
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(body)
	check(not body.participants[0].active and not view.visible and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.get("ok",true),"中断で参加者と本体表示を閉じ登録済み通知を渡す")
	bridge.dispose()
	view.queue_free()
	restored.queue_free()
	await get_tree().process_frame
	print("[cpp_monoceros_body] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 失敗したノックバック条件と未完了の通知条件だけを確認し直す。
func native_body_retry() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var package: Dictionary = builder.boss_body_package(load("res://data/bosses/monoceros.tres"),cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	bridge.configure(bytes,{"api_version":1,"run_id":148,"mode":1,"stage_id":"B_monoceros_body","profile":{},"settings":{"hitstop":false}})
	bridge.start(148,{"position":Vector2(1000,0)})
	bridge.subscribe("確認",func(_frame): return true)
	bridge.command("dev_ship_motion",{"position":Vector2(1000,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1000,0),Vector2(1000,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge._core.step(0.1)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var before: Vector2 = body.velocity
	for cause in ["ram","touch","wave"]:
		check(bridge.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":cause,"direction":Vector2.RIGHT,"knock":1500.0}).ok,"被弾の原因を登録済みIDで渡す")
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.velocity==before and semantics_approx(body.hp,body.max_hp-3.0,"native_body:hp"),"被弾はHPへ通し外力で自力移動を変えない")
	var view = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	view.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(view)
	bridge.command("dev_cancel_boss",{"entity_id":id})
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(body)
	check(not body.participants[0].active and not view.visible and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"中断で参加者と本体表示を閉じ登録済み通知を渡す")
	bridge.dispose()
	view.queue_free()
	await get_tree().process_frame
	print("[cpp_monoceros_body_retry] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 本体表示とHUDへの未実施の接続条件だけを確認する。
func native_body_hud() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/monoceros.tres")
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":148,"mode":1,"stage_id":"B_monoceros_body","profile":{},"settings":{"hitstop":false}})
	bridge.start(148,{"position":Vector2(1000,0)})
	bridge._core.set_motion_context(Vector2(1000,0),Vector2(1000,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_damage",{"entity_id":id,"amount":17.0,"cause":"bullet"})
	var packet: Dictionary = bridge.read_frame().value
	if "--cpp-body-view-retry" not in OS.get_cmdline_user_args():
		var hud = load("res://scripts/ui/hud.gd").new()
		hud.apply_snapshot(packet.ui)
		check(hud._cpp_ui.boss_bodies[0].actor==id and is_equal_approx(hud._cpp_ui.boss_bodies[0].hp,hud._cpp_ui.boss_bodies[0].max_hp-17.0),"HPと論理本体IDをHUDの表示入口へ渡す")
		hud.free()
	var scope := ContentResourceScope.new()
	for asset: Dictionary in package.visuals:
		if not asset.path.is_empty(): scope.provide(asset.path,load(asset.path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	var frame: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	check(view.apply_frame(frame) and view._boss_body_displays.size()==1 and view._boss_body_displays.values()[0].parts!=null,"共通表示入口が準備済み資源から一角獣の実パーツを作る")
	bridge.command("dev_kill",{"entity_id":id,"cause":"debug"})
	bridge._core.step(0.01)
	frame = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	check(view.apply_frame(frame) and not view._boss_body_displays.values()[0].visible and frame.boss_bodies[0].participants[0].id==id and bridge.read_frame().ok,"本体の寿命終了後に古い位置やHPの参照を残さない")
	bridge.dispose()
	view.queue_free()
	await get_tree().process_frame
	print("[cpp_monoceros_body_hud] failures=",failed)
	get_tree().quit(1 if failed else 0)
