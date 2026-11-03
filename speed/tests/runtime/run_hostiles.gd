## 敵弾の移動、誘導、被弾、無敵時間、画面外と寿命の終了を確認する。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
var bullet_finished := false
var bullet_fixes := false
var mute_checks := false
func check(ok: bool, label: String) -> void:
	if mute_checks: return
	if not ok:
		failed += 1
		push_error(label)
func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	if "--cpp-triangle" in OS.get_cmdline_user_args():
		var completed: bool=await check_cpp_triangle()
		check(completed,"三角形の親の指定条件を最後まで確認する")
		print("[cpp_triangle] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-ruler" in OS.get_cmdline_user_args():
		mute_checks="--cpp-ruler-tail" in OS.get_cmdline_user_args() or "--cpp-ruler-voices" in OS.get_cmdline_user_args()
		var completed: bool=await check_cpp_ruler()
		mute_checks=false
		check(completed,"じょうぎ座の未実施条件を最後まで確認する")
		print("[cpp_ruler] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-cepheus-notifications" in OS.get_cmdline_user_args():
		await check_cpp_cepheus_notifications()
		print("[cpp_cepheus_notifications] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-triangle-star" in OS.get_cmdline_user_args():
		await check_cpp_triangle_star()
		print("[cpp_triangle_star] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-cepheus" in OS.get_cmdline_user_args():
		await check_cpp_cepheus()
		print("[cpp_cepheus] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-reticle" in OS.get_cmdline_user_args():
		await check_cpp_reticle()
		print("[cpp_reticle] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-clock" in OS.get_cmdline_user_args():
		await check_cpp_clock()
		print("[cpp_clock] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-auriga" in OS.get_cmdline_user_args():
		await check_cpp_auriga()
		print("[cpp_auriga] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-soldier" in OS.get_cmdline_user_args():
		mute_checks = "--cpp-soldier-tail" in OS.get_cmdline_user_args()
		await check_cpp_soldier()
		print("[cpp_soldier] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lynx" in OS.get_cmdline_user_args():
		await check_cpp_lynx()
		print("[cpp_lynx] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-bolt" in OS.get_cmdline_user_args() or "--cpp-bolt-tail-fix" in OS.get_cmdline_user_args():
		mute_checks = "--cpp-bolt-tail-fix" in OS.get_cmdline_user_args()
		var finished: bool = await check_cpp_bolt()
		check(finished,"兵の光弾の確認を最後まで実施する")
		print("[cpp_bolt] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-slash" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_slash()
		check(finished,"斬撃の確認を最後まで実施する")
		print("[cpp_slash] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-dolphin" in OS.get_cmdline_user_args():
		await check_cpp_dolphin()
		print("[cpp_dolphin] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-pulser" in OS.get_cmdline_user_args():
		await check_cpp_pulser()
		print("[cpp_pulser] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-wave" in OS.get_cmdline_user_args() or "--cpp-wave-fixes" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_wave()
		check(finished,"波動の確認を最後まで実施する")
		print("[cpp_wave] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

	if "--cpp-missile" in OS.get_cmdline_user_args() or "--cpp-missile-gap-fixes" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_missile()
		check(finished,"誘導弾の確認を最後まで実施する")
		print("[cpp_missile] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

	if "--cpp-bullet" in OS.get_cmdline_user_args() or "--cpp-bullet-fixes" in OS.get_cmdline_user_args():
		bullet_fixes = "--cpp-bullet-fixes" in OS.get_cmdline_user_args()
		mute_checks = bullet_fixes
		await check_cpp_bullet()
		mute_checks = false
		check(bullet_finished,"通常敵弾の確認本体が最後まで進んだ")
		print("[cpp_bullet] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	await check_cpp_triangle()
	print("[run_hostiles] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func add_shot(core, fields: Dictionary) -> void:
	check(core.spawn_hostile(fields)>=0,"敵弾を生成・再利用する")

func bullet_pair_step(core, dt: float, label: String) -> void:
	check(core.step_hostiles(dt),label+"：C++の敵弾を進める")

func check_cpp_bullet() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 1500.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.atk_scale = 3.0
	var stage := RuntimeStage.new()
	stage.index = 86
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_bullet"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder!=null and builder.can_instantiate(),"敵弾の生成入口を読み込める")
	if builder==null or not builder.can_instantiate(): return
	var built: Error = builder.build(stage,config,output,"通常敵弾の発生元・飛行・被弾・終了".sha256_text())
	check(built==OK,"敵弾の固定値・当たりの規則・表示キーを生成する")
	if built!=OK: return
	var path := output.path_join("stage_86.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":348},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"敵弾の表示を準備して出撃する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	var target := Vector2(-900,0)
	check(bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(100,0)}).ok,"固定の機体位置と速度を設定する")
	var intent := Intent.new()
	bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(640,480)})
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(100,0)})
	core.set_motion_context(target,target,Vector2(640,360))
	var source_position := Vector2(-1500,0)
	var source_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":source_position}).value
	var empty: Dictionary = bridge.checkpoint()
	var emitted: Dictionary = bridge.command("dev_fire_enemy",{"source_id":source_id,"angle":0.0,"speed":600.0,"damage":11.0,"slow":0.3})
	check(emitted.ok,"発生元の位置・半径から通常敵弾を発射する")
	if not emitted.ok:
		session.free()
		return
	var pending: Dictionary = bridge.checkpoint()
	mute_checks = false
	bullet_pair_step(core,1.0/60.0,"直進")
	var visual := 0
	var stone_visual := 0
	for entry: Dictionary in session.cpp_resources.visuals:
		if entry.role==11: visual = entry.id
		if entry.role==12: stone_visual = entry.id
	var frame: Dictionary = bridge.read_render(Rect2(-1800,-500,1500,1000)).value
	var visible := false
	for batch: Dictionary in frame.batches:
		if batch.visual_id==visual: visible = batch.ids.has(int(emitted.value.id)) and is_equal_approx(batch.transforms[0],7.0)
	if not bullet_fixes: check(visible,"同じ当たり半径・攻撃IDの敵弾をまとめて表示する")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.batches.has(visual),"赤い外側と暗い内側の共通の弾を通常画面へ渡す")
	if not bullet_fixes:
		check(bridge.command("dev_kill",{"entity_id":source_id,"cause":"ram"}).ok,"弾の飛行中に発生元を倒す")
		var source_kept := false
		for attack: Dictionary in core.attack_snapshot():
			if attack.id==int(emitted.value.id): source_kept = attack.source_id==source_id and not attack.source_alive
		check(source_kept,"発生元の死後も弾と出どころのIDを保持する")
		bullet_pair_step(core,1.0,"高速な機体横断")
		var hit: Dictionary = core.ship_snapshot()
		check(core.hostiles_snapshot().is_empty() and is_equal_approx(hit.ship_hp,config.base_hp-11.0),"命中で一度だけ被弾・減速し、通常敵弾へatk_scaleを重ねて掛けない")
		check(bridge.restore(pending.value).ok,"発生元・弾・機体を保持点へ戻す")
		core.step_hostiles(1.0/60.0)
		core.step_hostiles(1.0)
		check(core.hostiles_snapshot().is_empty() and core.ship_snapshot()==hit,"復帰後にも同じ飛行・被弾・消滅になる")
		check(bridge.restore(pending.value).ok,"石化の固定場面へ戻す")
		check(bridge.command("dev_stone_hostiles",{"duration":0.1,"view":Rect2(-1800,-500,1500,1000)}).ok,"石化を共通の敵弾へ適用する")
		bullet_pair_step(core,0.05,"石化中の位置と寿命")
		frame = bridge.read_render(Rect2(-1800,-500,1500,1000)).value
		var stone_visible := false
		for batch: Dictionary in frame.batches:
			if batch.visual_id==stone_visual: stone_visible = batch.ids.has(int(emitted.value.id)) and is_equal_approx(batch.transforms[0],7.0*1.3)
		check(stone_visible,"石化した弾の灰色の円を同じ攻撃IDへ重ねる")
		var stone_at: Vector2 = core.hostiles_snapshot()[0].pos
		bridge.command("dev_ship_motion",{"position":stone_at,"velocity":Vector2.ZERO})
		bullet_pair_step(core,0.02,"石化した弾への接触")
		check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"石化中の弾は触れると被弾させず消える")
	var base := {"kind":0,"speed":1200.0,"r":7.0,"life":4.0,"dmg":7.0,"slow":0.0,"turn":0.0}
	for scenario in [
		{"name":"寿命を使い切る更新の命中","pos":target+Vector2(200,0),"vel":Vector2(-1200,0),"life":0.001,"ship":target,"dt":0.25,"live":false,"hurt":true},
		{"name":"画面外で遠ざかる弾","pos":target+Vector2(2000,0),"vel":Vector2(1200,0),"life":4.0,"ship":target,"dt":0.1,"live":false,"hurt":false},
		{"name":"画面外から近づく弾","pos":target+Vector2(2000,0),"vel":Vector2(-1200,0),"life":4.0,"ship":target,"dt":0.1,"live":true,"hurt":false},
		{"name":"機体より先の地形","pos":Vector2(-300,0),"vel":Vector2(1200,0),"life":4.0,"ship":Vector2(500,0),"dt":0.5,"live":false,"hurt":false}]:
		if bullet_fixes and scenario.name not in ["画面外から近づく弾","機体より先の地形"]: continue
		check(bridge.restore(empty.value).ok,"終了条件の独立した固定場面へ戻す")
		bridge.command("dev_ship_motion",{"position":scenario.ship,"velocity":Vector2.ZERO})
		core.set_motion_context(scenario.ship,scenario.ship,Vector2(640,360))
		add_shot(core,base.merged({"pos":scenario.pos,"vel":scenario.vel,"life":scenario.life},true))
		bullet_pair_step(core,scenario.dt,scenario.name)
		if not bullet_fixes: check((not core.hostiles_snapshot().is_empty())==scenario.live and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-(7.0 if scenario.hurt else 0.0)),scenario.name+"：継続・消滅・被弾が正しい")
	bridge.release_checkpoint(pending.value)
	bridge.release_checkpoint(empty.value)
	await get_tree().process_frame
	session.free()
	bullet_finished = true

func missile_emit_pair(bridge,position: Vector2,angle: float,speed: float,settings: Dictionary) -> Dictionary:
	var spawned: Dictionary = bridge.command("dev_spawn",{"definition_id":"drifter","position":position})
	check(spawned.ok,"誘導弾の生存する発生元を生成する")
	if not spawned.ok: return {}
	var emitted: Dictionary = bridge.command("dev_fire_missile",{"source_id":spawned.value,"angle":angle,"speed":speed,
		"damage":float(settings.get("bullet_dmg",7.0)),"slow":float(settings.get("slow",0.0)),"turn":float(settings.get("missile_turn",0.0))})
	check(emitted.ok,"発生元の位置・半径と定義値から誘導弾を発射する")
	if not emitted.ok: return {}
	return {"source_id":spawned.value,"attack":emitted.value}

func missile_reset(bridge,point: Dictionary,target: Vector2,config: GameConfig) -> bool:
	if not bridge.restore(point.value).ok:
		check(false,"誘導弾の固定場面へ戻る")
		return false
	bridge.collect_frame()
	bridge._core.set_motion_context(target,target,Vector2(640,360))
	return true

func check_cpp_missile() -> bool:
	var gap_fixes := "--cpp-missile-gap-fixes" in OS.get_cmdline_user_args()
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 1500.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.atk_scale = 3.0
	var stage := RuntimeStage.new()
	stage.index = 87
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter","shield"])
	var builder = load("res://tools/content/build_run_content.gd")
	var output := "res://.content/dev/run_missile"
	var built: Error = builder.build(stage,config,output,"誘導弾の発生元・追尾・石化・飛行・被弾・終了".sha256_text())
	check(built==OK,"誘導弾と反射弾・全種類共通の固定値を同じステージへ生成する")
	if built!=OK: return false
	var path := output.path_join("stage_87.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":348},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"誘導弾を生成する通常の状態・資源・表示を準備する")
	if session.bridge==null:
		session.free()
		return false
	var bridge = session.bridge
	var core = bridge._core
	var target := Vector2(-900,0)
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(100,0)})
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(100,0)})
	core.set_motion_context(target,target,Vector2(640,360))
	var empty: Dictionary = bridge.checkpoint()
	if not missile_reset(bridge,empty,target,config): return false
	var params: Dictionary = (load("res://data/enemies/missile.tres") as EnemyDef).params
	var settings := {"bullet_dmg":float(params.get("bullet_dmg",7.0)),"slow":float(params.get("slow",0.0)),"missile_turn":float(params.get("missile_turn",0.0))}
	var speed: float = params.missile_speed
	var emitted: Dictionary = missile_emit_pair(bridge,Vector2(-1500,0),PI*0.5,speed,settings)
	if emitted.is_empty(): return false
	if gap_fixes:
		# 先に通った表示・命中・復帰は繰り返さず、失敗した地形の余裕だけを照合する。
		core.step_hostiles(0.1)
		var view := Rect2(-1800,-500,1500,1000)
		bridge.command("dev_stone_hostiles",{"view":view,"duration":0.2})
		for dt in [0.1,0.15]:
			core.step_hostiles(dt)
		bullet_pair_step(core,0.05,"解除後は追尾と寿命を再開する")
		if not missile_reset(bridge,empty,target,config): return false
		emitted = missile_emit_pair(bridge,Vector2(-4000,2000),PI,speed,settings)
		if emitted.is_empty(): return false
		bullet_pair_step(core,0.1,"画面外で遠ざかっても継続する")
		bridge.release_checkpoint(empty.value)
		session.free()
		await get_tree().process_frame
		await get_tree().process_frame
		return true
	var source_radius: float = core.enemies_snapshot().filter(func(enemy): return enemy.id==emitted.source_id)[0].radius
	bullet_pair_step(core,0.1,"旋回上限つきの追尾")
	var visual := 0
	var stone_visual := 0
	for entry: Dictionary in session.cpp_resources.visuals:
		if entry.role==11: visual = entry.id
		if entry.role==12: stone_visual = entry.id
	var frame: Dictionary = bridge.read_render(Rect2(-1800,-500,1500,1000)).value
	check(frame.batches.any(func(batch): return batch.visual_id==visual and batch.ids.has(int(emitted.attack.id)) and is_equal_approx(batch.transforms[0],9.0)),"誘導弾を実際の半径と安定した攻撃IDで表示する")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.batches.has(visual),"共通の二重の円の表示を通常画面へ渡す")
	var stone_view := Rect2(-1800,-500,1500,1000)
	bridge.command("dev_stone_hostiles",{"view":stone_view,"duration":0.2})
	bullet_pair_step(core,0.1,"石化中は飛行と寿命を止める")
	frame = bridge.read_render(stone_view).value
	check(frame.batches.any(func(batch): return batch.visual_id==stone_visual and batch.ids.has(int(emitted.attack.id))),"石化した誘導弾を同じIDの石表示へ渡す")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.batches.has(stone_visual),"石化表示も通常の表示経路へ渡す")
	var frozen: Dictionary = bridge.checkpoint()
	bullet_pair_step(core,0.15,"石化の終了境界でもその更新は動かない")
	bullet_pair_step(core,0.05,"解除後は追尾と寿命を再開する")
	var resumed: Array = core.hostiles_snapshot()
	check(bridge.restore(frozen.value).ok,"石化途中の旋回・寿命・位置を保持して復帰する")
	bridge.collect_frame()
	core.step_hostiles(0.15)
	core.step_hostiles(0.05)
	check(core.hostiles_snapshot()==resumed,"復帰後も同じ解除・追尾の状態へ進む")
	bridge.release_checkpoint(frozen.value)
	if not missile_reset(bridge,empty,target,config): return false
	emitted = missile_emit_pair(bridge,Vector2(-1500,0),0.0,speed,settings)
	if emitted.is_empty(): return false
	bridge.command("dev_kill",{"entity_id":emitted.source_id,"cause":"ram"})
	check(core.attack_snapshot().any(func(attack): return attack.id==int(emitted.attack.id) and attack.source_id==emitted.source_id and not attack.source_alive),"発生元を倒しても独立した誘導弾と出所を保つ")
	bullet_pair_step(core,1.5,"高速な機体横断で被弾して終了する")
	check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-settings.bullet_dmg),"誘導弾が一度だけ被弾させ、atk_scaleを重ねて掛けない")
	var hit_frame: Dictionary = bridge.read_frame().value
	check(hit_frame.events.any(func(event): return event.type==&"hurt" and event.payload.cause==&"missile"),"機体の被弾をmissileの原因で共通記録へ渡す")
	if not missile_reset(bridge,empty,target,config): return false
	emitted = missile_emit_pair(bridge,Vector2(-4000,2000),PI,speed,settings)
	if emitted.is_empty(): return false
	bullet_pair_step(core,0.1,"画面外で遠ざかっても継続する")
	check(core.hostiles_snapshot().size()==1,"誘導弾は通常弾の画面外退場へ入れない")
	bullet_pair_step(core,5.0,"自然寿命で終了する")
	check(core.hostiles_snapshot().is_empty(),"寿命が終わった誘導弾を回収する")
	if not missile_reset(bridge,empty,target,config): return false
	var straight: Dictionary = settings.duplicate()
	straight.missile_turn = 0.0
	emitted = missile_emit_pair(bridge,Vector2(-300,0),0.0,speed,straight)
	if emitted.is_empty(): return false
	bullet_pair_step(core,1.0,"天体との交差で終了する")
	check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"先に当たった地形で回収し機体へ被弾を通さない")
	if not missile_reset(bridge,empty,target,config): return false
	emitted = missile_emit_pair(bridge,target-Vector2(source_radius,0),0.0,speed,straight)
	if emitted.is_empty(): return false
	bridge.command("dev_stone_hostiles",{"view":stone_view,"duration":1.0})
	bullet_pair_step(core,0.01,"石化中の機体接触")
	check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"石化中の接触はダメージなしで弾を回収する")
	bridge.release_checkpoint(empty.value)
	session.free()
	await get_tree().process_frame
	await get_tree().process_frame
	return true

func wave_emit_pair(bridge,params: Dictionary) -> Dictionary:
	var emitted: Dictionary = bridge.command("dev_fire_wave",params)
	check(emitted.ok,"波動の初期半径・予告・拡大を共通生成へ接続する")
	if not emitted.ok: return {}
	return {"attack":emitted.value}

func wave_pair_step(core, dt: float, label: String) -> void:
	check(core.step_hazards(dt),label+"：範囲の世界時計を進める")

func wave_reset(bridge,point: Dictionary,at: Vector2,config: GameConfig) -> bool:
	if not missile_reset(bridge,point,at,config): return false
	bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
	return true

func check_cpp_wave() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.atk_scale = 3.0
	var stage := RuntimeStage.new()
	stage.index = 88
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var builder = load("res://tools/content/build_run_content.gd")
	var output := "res://.content/dev/run_wave"
	if builder.build(stage,config,output,"波動の予告・拡大・切れ目・命中・終了".sha256_text())!=OK: return false
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":349},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free(); return false
	var bridge = session.bridge
	var core = bridge._core
	var center := Vector2(-1500,0)
	var target := center+Vector2(140,0)
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var empty: Dictionary = bridge.checkpoint()
	if not wave_reset(bridge,empty,target,config): return false
	var params := {"position":center,"angle":0.0,"arc":PI,"radius":500.0,"start_radius":80.0,"speed":100.0,"width":12.0,"delay":0.2,"damage":7.0}
	if "--cpp-wave-fixes" in OS.get_cmdline_user_args():
		if not wave_reset(bridge,empty,center+Vector2(1000,0),config): return false
		var layers := params.merged({"layers":3,"interval":0.15,"gap":0.2,"gap_arc":0.1,"gap_step":0.4},true)
		var rings: Dictionary = bridge.command("dev_fire_wave",layers)
		if not rings.ok: return false
		wave_pair_step(core,0.4,"複数の輪を同じ行順で拡大する")
		if not wave_reset(bridge,empty,center+Vector2(1000,0),config): return false
		var victim_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":center+Vector2(110,0)}).value
		var hp: float = core.enemies_snapshot().filter(func(enemy): return enemy.id==victim_id)[0].hp
		var emitted: Dictionary = wave_emit_pair(bridge,params.merged({"enemy_damage":1.0},true))
		if emitted.is_empty(): return false
		wave_pair_step(core,0.4,"通過する帯で敵へ一度当たる")
		check(core.enemies_snapshot().any(func(enemy): return enemy.id==victim_id and is_equal_approx(enemy.hp,hp-1.0)),"波の敵ダメージと命中済みIDを保つ")
		var point: Dictionary = bridge.checkpoint()
		wave_pair_step(core,0.01,"命中した敵への二度目を防ぐ")
		var future: Array = core.enemies_snapshot()
		check(bridge.restore(point.value).ok,"敵への実命中履歴を復帰する")
		core.step_hazards(0.01)
		check(core.enemies_snapshot()==future,"実命中を含む復帰でも二度当てない")
		bridge.release_checkpoint(point.value)
		bridge.release_checkpoint(empty.value)
		session.free()
		await get_tree().process_frame
		await get_tree().process_frame
		return true
	var emitted: Dictionary = wave_emit_pair(bridge,params)
	if emitted.is_empty(): return false
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	wave_pair_step(core,0.1,"予告中は初期半径で止まり当たらない")
	presentation._present_cpp(0.0)
	check(presentation.frame_view._wave_displays.size()==1,"波動の予告を通常画面へ表示する")
	check(is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"予告中に機体へダメージを通さない")
	wave_pair_step(core,0.1,"予告が終わった時点は初期半径")
	wave_pair_step(core,0.5,"広がった輪が機体へ一度当たる")
	check(is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-7.0),"atk_scaleを重ねず指定ダメージを一度与える")
	var point: Dictionary = bridge.checkpoint()
	wave_pair_step(core,0.1,"命中後も波は拡大し続ける")
	var future: Array = core.hazards_snapshot()
	check(bridge.restore(point.value).ok,"途中の半径・命中済み・残り寿命を復帰する")
	core.step_hazards(0.1)
	check(core.hazards_snapshot()==future,"復帰後も同じ拡大と命中履歴へ進む")
	bridge.release_checkpoint(point.value)
	wave_pair_step(core,5.0,"最大半径までの時間で自然終了する")
	check(core.hazards_snapshot().is_empty(),"波動の自然終了で範囲を回収する")
	presentation._present_cpp(0.0)
	check(presentation.frame_view._wave_displays.values().all(func(display): return not display.visible),"終了した波の表示を残さない")
	for scenario in [
		{"name":"切れ目の中","angle":0.0,"gap":0.0,"gap_arc":0.3,"arc":PI,"hit":false},
		{"name":"切れ目の外","angle":0.0,"gap":PI,"gap_arc":0.3,"arc":PI,"hit":true},
		{"name":"扇の外","angle":PI,"gap":0.0,"gap_arc":0.0,"arc":0.5,"hit":false}]:
		if not wave_reset(bridge,empty,target,config): return false
		var shape := params.duplicate()
		shape.merge({"angle":scenario.angle,"gap":scenario.gap,"gap_arc":scenario.gap_arc,"arc":scenario.arc},true)
		emitted = wave_emit_pair(bridge,shape)
		if emitted.is_empty(): return false
		wave_pair_step(core,0.7,scenario.name)
		check(is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-(7.0 if scenario.hit else 0.0)),scenario.name+"の当たりを保つ")
	# 層ごとに予告と切れ目の向きをずらす生成も同じ値を使う。
	if not wave_reset(bridge,empty,center+Vector2(1000,0),config): return false
	var layers := params.merged({"layers":3,"interval":0.15,"gap":0.2,"gap_arc":0.1,"gap_step":0.4},true)
	var rings: Dictionary = bridge.command("dev_fire_wave",layers)
	check(rings.ok and rings.value.size()==3,"層ごとに遅延と切れ目を変えた輪を生成する")
	wave_pair_step(core,0.4,"複数の輪を同じ行順で拡大する")
	# 見た目の種類を同じ描画関数へ渡し、完成輪は専用の輪を再利用する。
	for style in [1,2,3]:
		if not wave_reset(bridge,empty,target,config): return false
		emitted = wave_emit_pair(bridge,params.merged({"style":style},true))
		if emitted.is_empty(): return false
		wave_pair_step(core,0.5,"波紋・雷色・完成輪の拡大")
		var frame: Dictionary = bridge.read_render(Rect2(center-Vector2(600,600),Vector2(1200,1200))).value
		check(frame.shapes.any(func(shape): return shape.kind==2 and shape.wave_style==style and shape.owner_id==emitted.attack.id),"種類と攻撃IDを表示へ渡す")
		presentation._present_cpp(0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		check(presentation.frame_view._wave_displays.values().any(func(display): return display.visible and display._cpp_values.style==[0,6,2,14][style]),"各種の波動を通常画面へ表示する")
		if style==3:
			check(presentation.frame_view._wave_displays.values().any(func(display): return display.visible and not display._rings.is_empty() and display._rings[0].visible),"完成輪の専用描画を再利用する")
	# 発射前は発生元の死亡・吸引で取消。発射後は独立し、復帰でもその区切りを保つ。
	for after_launch in [false,true]:
		for pulled in [false,true]:
			if not wave_reset(bridge,empty,center+Vector2(1000,0),config): return false
			var owner_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":center}).value
			emitted = wave_emit_pair(bridge,params.merged({"owner_id":owner_id,"style":3},true))
			if emitted.is_empty(): return false
			if after_launch:
				wave_pair_step(core,0.3,"発射時に完成輪の生存参照を外す")
				check(not core.hazards_snapshot()[0].attached,"発射後の生存参照を解除する")
				var launched: Dictionary = bridge.checkpoint()
				check(bridge.restore(launched.value).ok,"独立した完成輪を保持復帰する")
				bridge.release_checkpoint(launched.value)
			if pulled:
				var pump_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":center+Vector2(20,0)}).value
				check(bridge.command("dev_enemy_combat",{"entity_id":owner_id,"pump_owner":pump_id}).ok,"発生元を吸引中にする")
			else:
				bridge.command("dev_kill",{"entity_id":owner_id,"cause":"ram"})
			wave_pair_step(core,0.05,"発射の前後の死亡・吸引")
			check((not core.hazards_snapshot().is_empty())==after_launch,"発射前だけ取り消し、発射後は自然寿命まで残す")
	# 敵への波は通過帯を一度ずつ当て、機体の命中済み状態とは別に保持する。
	if not wave_reset(bridge,empty,center+Vector2(1000,0),config): return false
	var victim_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":center+Vector2(110,0)}).value
	var hp: float = core.enemies_snapshot().filter(func(enemy): return enemy.id==victim_id)[0].hp
	emitted = wave_emit_pair(bridge,params.merged({"enemy_damage":1.0},true))
	if emitted.is_empty(): return false
	wave_pair_step(core,0.4,"通過する帯で敵へ一度当たる")
	check(core.enemies_snapshot().any(func(enemy): return enemy.id==victim_id and is_equal_approx(enemy.hp,hp-1.0)),"波の敵ダメージと命中済みIDを保つ")
	var hit_point: Dictionary = bridge.checkpoint()
	wave_pair_step(core,0.01,"同じ敵への二度目を防ぐ")
	var enemies: Array = core.enemies_snapshot()
	check(bridge.restore(hit_point.value).ok,"敵への命中履歴を復帰する")
	core.step_hazards(0.01)
	check(core.enemies_snapshot()==enemies,"復帰しても同じ敵へ二度当てない")
	bridge.release_checkpoint(hit_point.value)
	bridge.release_checkpoint(empty.value)
	session.free()
	await get_tree().process_frame
	await get_tree().process_frame
	return true

func check_cpp_slash() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 88
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_slash"
	var builder = load("res://tools/content/build_run_content.gd")
	if builder.build(stage,config,output,"斬撃の左右と3本の爪痕".sha256_text())!=OK:
		check(false,"斬撃の生成済みの爪痕を準備する")
		return false
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":288},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"斬撃を表示する通常のC++ランを準備する")
	if session.bridge==null: session.free(); return false
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var origin := Vector2(-900,0)
	bridge.command("dev_ship_motion",{"position":origin-Vector2(0,300),"velocity":Vector2.ZERO})
	core.set_motion_context(origin-Vector2(0,300),origin,Vector2(640,360))
	var owner_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":origin+Vector2(-300,300)}).value
	var empty: Dictionary = bridge.checkpoint()
	var params := {"position":origin,"angle":0.0,"speed":100.0,"size":60.0,"range":200.0,"damage":7.0,"side":1.0,"owner_id":owner_id}
	var fired: Dictionary = bridge.command("dev_fire_slash",params)
	check(fired.ok,"発生源から斬撃を生成する")
	if not fired.ok: session.free(); return false
	core.step_hostiles(0.1)
	var shot: Dictionary = core.hostiles_snapshot()[0]
	check(shot.pos==origin+Vector2(10,0) and shot.vel==Vector2(100,0) and is_equal_approx(shot.life,1.9),"斬撃が形を保って直進し寿命を減らす")
	var shape = load("res://scripts/data_types/attack_defaults.gd")
	var frame: Dictionary = bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(frame.shapes.size()==1 and frame.shapes[0].widths.size()==9,"左右3本の爪痕を光・本体・芯の9本で表示する")
	if frame.shapes.size()==1:
		var rendered: PackedVector2Array = frame.shapes[0].points.slice(0,17)
		var expected: PackedVector2Array = shape.slash_points(shot.pos,0.0,60.0,1.0,0)
		var equal := rendered.size()==expected.size()
		for n in mini(rendered.size(),expected.size()): equal = equal and rendered[n].distance_to(expected[n])<0.001
		check(equal,"生成した爪痕の表示点が現行の式と一致する")
	check(presentation.frame_view.apply_frame(frame),"飛んでいる斬撃を通常の表示へ渡す")
	await get_tree().process_frame
	bridge.command("dev_remove",{"entity_id":owner_id})
	check(core.attack_snapshot()[0].source_id==owner_id and not core.attack_snapshot()[0].source_alive,"発射元が退場しても斬撃は元のIDで飛び続ける")
	var active: Dictionary = bridge.checkpoint()
	var state: Array = core.hostiles_snapshot()
	check(active.ok,"斬撃の位置・速度・寿命・左右を値で保持する")
	core.step_hostiles(2.0)
	check(core.hostiles_snapshot().is_empty(),"斬撃は届く距離を使い切ると消える")
	bridge.restore(active.value)
	check(core.hostiles_snapshot()==state,"飛行中の斬撃を保持点から復元する")
	for side in [-1.0,1.0]:
		for claw in 3:
			bridge.restore(empty.value)
			params.side = side
			check(bridge.command("dev_fire_slash",params).ok,"左右の斬撃を生成する: %s/%d" % [side,claw])
			var at: Vector2 = shape.slash_points(origin+Vector2(10,0),0.0,60.0,side,claw)[8]
			check(shape.slash_touches(origin+Vector2(10,0),0.0,60.0,side,at,config.ship_radius),"現行の各爪痕の接触条件を通る")
			bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
			core.step_hostiles(0.1)
			check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-7.0),"左右の各爪痕が共通被弾へ通って消える: %s/%d" % [side,claw])
			var events: Array = bridge.read_frame().value.events
			check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause==&"slash"),"斬撃の原因名を共通記録へ残す")
	bridge.restore(empty.value)
	params.side = 1.0
	check(bridge.command("dev_fire_slash",params).ok,"爪痕の反対側を通る斬撃を生成する")
	bridge.command("dev_ship_motion",{"position":origin+Vector2(10,-100),"velocity":Vector2.ZERO})
	core.step_hostiles(0.1)
	check(core.hostiles_snapshot().size()==1 and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"爪痕の反対側は大きな円として被弾させない")
	bridge.restore(empty.value)
	params.position = Vector2(-300,0)
	params.speed = 2000.0
	check(bridge.command("dev_fire_slash",params).ok,"天体へ飛ぶ斬撃を生成する")
	core.step_hostiles(0.1)
	check(core.hostiles_snapshot().is_empty(),"斬撃は天体との接触で消える")
	bridge.restore(empty.value)
	params.position = origin
	params.size = 0.0
	check(not bridge.command("dev_fire_slash",params).ok and core.hostiles_snapshot().is_empty(),"大きさ0の斬撃を状態を変えずに拒否する")
	bridge.release_checkpoint(active.value)
	bridge.release_checkpoint(empty.value)
	session.free()
	return true

func check_cpp_bolt() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 89
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_bolt"
	var builder = load("res://tools/content/build_run_content.gd")
	if builder.build(stage,config,output,"兵の光弾の飛行・命中・終了".sha256_text())!=OK:
		check(false,"兵の光弾の定義を生成する")
		return false
	var path := output.path_join("stage_89.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":289},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"兵の光弾を表示する通常のC++ランを準備する")
	if session.bridge==null: session.free(); return false
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var origin := Vector2(-900,0)
	bridge.command("dev_ship_motion",{"position":origin+Vector2(0,100),"velocity":Vector2.ZERO})
	core.set_motion_context(origin+Vector2(0,100),origin,Vector2(640,360))
	var owner_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":origin+Vector2(-300,300)}).value
	var empty: Dictionary = bridge.checkpoint()
	var params := {"position":origin,"angle":PI*0.5,"speed":100.0,"damage":9.0,"owner_id":owner_id}
	if "--cpp-bolt-tail-fix" in OS.get_cmdline_user_args():
		params.angle = 0.0
		var tail: Dictionary = bridge.command("dev_fire_bolt",params)
		bridge.command("dev_ship_motion",{"position":origin-Vector2(7.0+config.ship_radius+5.0,0),"velocity":Vector2.ZERO})
		core.step_hostiles(0.1)
		mute_checks = false
		check(tail.ok and core.hostiles_snapshot().size()==1 and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"光弾の長い尾だけに重なっても半径7の判定外なら被弾しない")
		bridge.release_checkpoint(empty.value)
		session.free()
		return true
	var fired: Dictionary = bridge.command("dev_fire_bolt",params)
	check(fired.ok,"発生源から兵の光弾を生成する")
	if not fired.ok: session.free(); return false
	core.step_hostiles(0.1)
	var shot: Dictionary = core.hostiles_snapshot()[0]
	check(shot.pos.distance_to(origin+Vector2(0,10))<0.001 and is_equal_approx(shot.life,3.9),"光弾が指定の方向へ直進して寿命を減らす")
	var frame: Dictionary = bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(frame.shapes.size()==1 and frame.shapes[0].widths==PackedFloat32Array([14.0,6.0,2.5]),"光弾は元の幅で光・本体・芯の3本を表示する")
	if frame.shapes.size()==1:
		var points: PackedVector2Array = frame.shapes[0].points
		check(points[0].distance_to(shot.pos-Vector2(0,34))<0.001 and points[1].distance_to(shot.pos+Vector2(0,6))<0.001,"細長い光弾の向きと前後の長さを保つ")
	check(presentation.frame_view.apply_frame(frame),"飛んでいる光弾を通常の表示へ渡す")
	await get_tree().process_frame
	bridge.command("dev_remove",{"entity_id":owner_id})
	check(core.attack_snapshot()[0].source_id==owner_id and not core.attack_snapshot()[0].source_alive,"発射元の退場後も元のIDで光弾が残る")
	var active: Dictionary = bridge.checkpoint()
	var state: Array = core.hostiles_snapshot()
	check(active.ok,"飛行中の光弾を値で保持する")
	core.step_hostiles(1.0)
	check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-9.0),"飛行区間で機体に当たり共通被弾へ通って消える")
	var events: Array = bridge.read_frame().value.events
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause==&"bolt"),"光弾の原因名を共通記録へ残す")
	bridge.restore(active.value)
	check(core.hostiles_snapshot()==state and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"光弾の速度・寿命・位置・未命中状態を保持点から復元する")
	bridge.command("dev_ship_motion",{"position":origin-Vector2(0,300),"velocity":Vector2.ZERO})
	core.step_hostiles(4.0)
	check(core.hostiles_snapshot().is_empty(),"光弾は4秒の寿命で消える")
	bridge.restore(empty.value)
	params.position = Vector2(-300,0)
	params.angle = 0.0
	params.speed = 1000.0
	check(bridge.command("dev_fire_bolt",params).ok,"天体へ向かう光弾を生成する")
	bridge.command("dev_ship_motion",{"position":Vector2(50,0),"velocity":Vector2.ZERO})
	core.step_hostiles(0.5)
	check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"機体より手前の天体に当たって光弾が消える")
	bridge.restore(empty.value)
	params.position = origin
	params.speed = 100.0
	check(bridge.command("dev_fire_bolt",params).ok,"判定幅を確認する光弾を生成する")
	bridge.command("dev_ship_motion",{"position":origin+Vector2(10,7.0+config.ship_radius),"velocity":Vector2.ZERO})
	core.step_hostiles(0.1)
	check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-9.0),"半径7と機体半径を足した境界で当たる")
	bridge.restore(empty.value)
	check(bridge.command("dev_fire_bolt",params).ok,"見た目の尾と当たりを分ける光弾を生成する")
	bridge.command("dev_ship_motion",{"position":origin-Vector2(7.0+config.ship_radius+5.0,0),"velocity":Vector2.ZERO})
	core.step_hostiles(0.1)
	check(core.hostiles_snapshot().size()==1 and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"光弾の長い尾だけに重なっても半径7の判定外なら被弾しない")
	bridge.restore(empty.value)
	params.speed = -1.0
	check(not bridge.command("dev_fire_bolt",params).ok and core.hostiles_snapshot().is_empty(),"負の速度の光弾を状態を変えずに拒否する")
	bridge.release_checkpoint(active.value)
	bridge.release_checkpoint(empty.value)
	session.free()
	return true
func pulse_motion(core, id: int) -> Dictionary:
	for item: Dictionary in core.enemy_motion_snapshot():
		if item.id==id: return item
	return {}

func check_cpp_pulser() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 74
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["pulser","drifter"])
	stage.enemy_tuning = {"pulser":{"speed":0.0,"params.telegraph":0.25,"params.fire_interval":1.0,"params.wave_radius":300.0,"params.wave_speed":100.0}}
	var output := "res://.content/dev/run_pulser"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"波動の敵の予告と発射".sha256_text())
	check(built==OK,"波動の敵の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_74.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":749},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"波動の敵のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var position := target-Vector2(400,0)
	var id: int = core.spawn_enemy(&"pulser",position,{"size":1.0})
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.set_enemy_motion(id,{"fire_t":0.0})
	core.step(0.1)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Move and core.hazards_snapshot().is_empty(),"予算0では予告と波を開始しない")
	core.configure_attack_budget({"enabled":true,"budget":2.0,"jitter":0.0})
	core.step(0.1)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Windup and is_equal_approx(pulse_motion(core,id).timer,0.25),"予算取得後に編集値の予告へ入る")
	core.step(0.1)
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	var frame: Dictionary = bridge.read_render(Rect2(position-Vector2(200,200),Vector2(1000,400))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(frame.pulser.size()==6 and is_equal_approx(frame.pulser[4],0.4) and presentation.frame_view.apply_frame(frame),"停止予告の輪と84本の光筋を通常画面へ表示する")
	await get_tree().process_frame
	core.step(0.2)
	check(core.hazards_snapshot().size()==1 and pulse_motion(core,id).mode==RunIds.EnemyModeId.Move,"予告終了で一つの波を生成して待機へ戻る")
	var wave: Dictionary = core.hazards_snapshot()[0]
	var expected: float = frame.pulser[2]
	check(is_equal_approx(wave.start_radius,expected) and is_equal_approx(wave.time,-0.15) and wave.attached,"完成輪の初期半径と端数時間を持ち発射直前まで所有する")
	core.step_hazards(0.2)
	wave = core.hazards_snapshot()[0]
	check(is_equal_approx(wave.radius,expected+5.0) and not wave.attached,"同じ更新の端数0.05秒だけ拡大して所有参照を解除する")
	frame = bridge.read_render(Rect2(position-Vector2(200,200),Vector2(1000,400))).value
	check(frame.pulser.is_empty() and not frame.shapes.is_empty() and presentation.frame_view.apply_frame(frame),"予告を消し発射済みの輪を共通表示へ渡す")
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step_hazards(0.1)
	check(core.hazards_snapshot().size()==1,"飛び始めた後に本体を倒しても波が残る")
	core.step_hazards(4.0)
	check(core.hazards_snapshot().is_empty(),"波は最大半径で自然終了する")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"予告の時計と予算を値から復帰する")
	core.step(0.2)
	var future: Array = core.hazards_snapshot()
	bridge.restore(pending.value)
	core.step(0.2)
	check(core.hazards_snapshot()==future,"復帰後の発射が一致し保持元を変更しない")
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step_hazards(0.2)
	check(core.hazards_snapshot().is_empty(),"同じ更新の本体撃破で発射前の波を取り消す")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step(0.3)
	check(core.hazards_snapshot().is_empty(),"予告中の撃破では遅延した波を残さない")
	core.remove_enemy(id)
	var replacement: int = core.spawn_enemy(&"pulser",position,{})
	check(replacement!=id and pulse_motion(core,replacement).mode==RunIds.EnemyModeId.Move and pulse_motion(core,replacement).charge==0.0,"行の再利用で予告を引き継がない")
	var owner: int = core.spawn_enemy(&"drifter",target,{})
	core.set_enemy_motion(replacement,{"pump_owner":owner,"fire_t":0.0})
	core.remove_enemy(owner)
	core.step(0.1)
	check(pulse_motion(core,replacement).mode==RunIds.EnemyModeId.Windup,"参照相手が先に消えても古い行へ接続しない")
	bridge.release_checkpoint(pending.value)
	session.free()

func dolphin_enemy(core, id: int) -> Dictionary:
	for item: Dictionary in core.enemies_snapshot():
		if item.id==id: return item
	return {}

func check_cpp_dolphin() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 75
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["dolphin","drifter"])
	stage.enemy_tuning = {"dolphin":{"speed":0.0,"params.telegraph":0.3,"params.fire_interval":1.0,"params.wave_radius":300.0,"params.wave_speed":300.0,"params.enemy_dmg":7.0,"params.bullet_dmg":4.0},"drifter":{"speed":0.0,"hp":100.0,"armor":0.0}}
	var output := "res://.content/dev/run_dolphin"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"いるか座の予告と敵への波".sha256_text())
	check(built==OK,"いるか座の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_75.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":759},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"いるか座のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	var position := target-Vector2(400,0)
	core.set_motion_context(target,target,Vector2(640,360))
	var id: int = core.spawn_enemy(&"dolphin",position,{"facing":0.0})
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.set_enemy_motion(id,{"fire_t":0.25})
	core.step(0.1)
	check(core.attack_budget_snapshot().groups.is_empty() and pulse_motion(core,id).mode==RunIds.EnemyModeId.Move,"予告時間による先取りをせず発射間隔の直前まで待つ")
	core.step(0.1)
	core.step(0.1)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Move and core.hazards_snapshot().is_empty(),"予算0では構えと波を開始しない")
	core.configure_attack_budget({"enabled":true,"budget":2.0,"jitter":0.0})
	core.step(0.1)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Windup and is_equal_approx(pulse_motion(core,id).timer,0.3),"編集値の構えへ入る")
	var initial_facing: float = dolphin_enemy(core,id).facing
	target = position+Vector2(0,600)
	core.set_motion_context(target,target,Vector2(640,360))
	core.step(0.1)
	check(is_equal_approx(dolphin_enemy(core,id).facing,initial_facing+0.2) and is_equal_approx(pulse_motion(core,id).charge,1.0/3.0),"構え中は現在の機体へ旋回速度2で向き直る")
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	var frame: Dictionary = bridge.read_render(Rect2(position-Vector2(300,300),Vector2(800,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var warning := false
	for batch: Dictionary in frame.batches:
		if batch.has("dolphin"): warning = batch.dolphin.size()==6 and is_equal_approx(batch.dolphin[5],0.7)
	check(warning and presentation.frame_view.apply_frame(frame),"向きと扇の切れ目を三層の弧で通常画面へ予告する")
	await get_tree().process_frame
	core.step(0.21)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Recover and is_equal_approx(pulse_motion(core,id).timer,0.6) and core.hazards_snapshot().size()==1,"構えの終わりに一発を生成し0.6秒休む")
	var wave: Dictionary = core.hazards_snapshot()[0]
	check(wave.style==1 and is_equal_approx(wave.arc,0.7) and wave.enemy_damage==7.0 and not wave.attached and wave.time==0.0,"層状の扇と敵ダメージを持つ独立した波を生成する")
	var direction := Vector2.from_angle(wave.angle)
	var ahead: Vector2 = wave.pos+direction*100.0
	var behind: Vector2 = wave.pos-direction*100.0
	var victim: int = core.spawn_enemy(&"drifter",ahead,{"size":1.0})
	var outside: int = core.spawn_enemy(&"drifter",behind,{"size":1.0})
	var hp: float = dolphin_enemy(core,victim).hp
	var outside_hp: float = dolphin_enemy(core,outside).hp
	bridge.command("dev_ship_motion",{"position":ahead,"velocity":Vector2.ZERO})
	core.rebuild_enemy_grid(cfg.grid_cell)
	var ship_hp: float = core.ship_snapshot().ship_hp
	core.step_hazards(0.3)
	check(is_equal_approx(dolphin_enemy(core,victim).hp,hp-7.0) and is_equal_approx(dolphin_enemy(core,outside).hp,outside_hp),"扇を通った敵へ編集値のダメージを一度与え切れ目側は通さない")
	check(is_equal_approx(core.ship_snapshot().ship_hp,ship_hp-4.0) and core.hazards_snapshot()[0].hit,"同じ先頭の弧が機体にも一度当たる")
	core.step_hazards(0.01)
	check(is_equal_approx(dolphin_enemy(core,victim).hp,hp-7.0),"重なる帯で同じ敵へ二度当てない")
	frame = bridge.read_render(Rect2(position-Vector2(300,300),Vector2(800,800))).value
	check(not frame.shapes.is_empty() and presentation.frame_view.apply_frame(frame),"発射済みの丸い端を持つ層状の扇を共通表示へ渡す")
	await get_tree().process_frame
	core.step(0.61)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Move and pulse_motion(core,id).fire_t==1.0,"休みが終わると編集値の間隔で待機へ戻る")
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step_hazards(0.1)
	check(core.hazards_snapshot().size()==1,"本体を倒しても発射済みの波は残る")
	core.step_hazards(2.0)
	check(core.hazards_snapshot().is_empty(),"波が最大半径で自然終了する")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"構え中の向き・溜め・時計を値から復帰する")
	core.step(0.21)
	var future: Array = core.hazards_snapshot()
	bridge.restore(pending.value)
	core.step(0.21)
	check(core.hazards_snapshot()==future,"復帰後の発射と扇の向きが一致し保持元を変更しない")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step(0.5)
	check(core.hazards_snapshot().is_empty(),"構えの途中で倒すと波を残さない")
	core.remove_enemy(id)
	var replacement: int = core.spawn_enemy(&"dolphin",position,{})
	check(replacement!=id and pulse_motion(core,replacement).mode==RunIds.EnemyModeId.Move and pulse_motion(core,replacement).charge==0.0,"行の再利用で古い構えを引き継がない")
	var owner: int = core.spawn_enemy(&"drifter",target,{})
	core.set_enemy_motion(replacement,{"pump_owner":owner,"fire_t":0.0})
	core.remove_enemy(owner)
	core.step(0.1)
	check(pulse_motion(core,replacement).mode==RunIds.EnemyModeId.Windup,"参照相手が先に消えても古い行を追わず構える")
	bridge.release_checkpoint(pending.value)
	session.free()

func check_cpp_lynx() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 76
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["lynx","drifter"])
	stage.enemy_tuning = {"lynx":{"params.telegraph":0.25,"params.fire_interval":1.0}}
	var output := "res://.content/dev/run_lynx"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"やまねこ座の左右の爪".sha256_text())
	check(built==OK,"やまねこ座の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_76.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":769},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"やまねこ座のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var position := target-Vector2(600,0)
	var id: int = core.spawn_enemy(&"lynx",position,{"facing":0.0})
	core.set_enemy_motion(id,{"fire_t":1.0})
	core.configure_attack_budget({"enabled":false,"budget":2.0,"jitter":0.0})
	core.step(0.05)
	check(dolphin_enemy(core,id).vel[0]>0.0,"画面矩形へ収まる目標へ進み画面外の遠い位置で待たない")
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.set_enemy_motion(id,{"fire_t":0.2})
	core.step(0.05)
	check(pulse_motion(core,id).charge==0.0 and pulse_motion(core,id).buds==0 and core.hostiles_snapshot().is_empty(),"予算0では左右の溜めと発射を進めない")
	core.configure_attack_budget({"enabled":true,"budget":2.0,"jitter":0.0})
	core.step(0.05)
	check(pulse_motion(core,id).charge>0.0 and pulse_motion(core,id).buds==0,"許可後に最初の前足を構える")
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(900,400),Vector2(1800,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var side := 0.0
	for batch: Dictionary in frame.batches:
		if batch.has("lynx"): side = batch.lynx[5]
	check(side==1.0 and presentation.frame_view.apply_frame(frame),"次に振る側の前足と三本の爪を通常画面へ表示する")
	await get_tree().process_frame
	core.step(0.2)
	check(core.hostiles_snapshot().size()==1 and core.hostiles_snapshot()[0].side==1.0 and pulse_motion(core,id).buds==1,"最初の片側の爪痕を生成して回数を進める")
	core.step(0.8)
	frame = bridge.read_render(Rect2(target-Vector2(900,400),Vector2(1800,800))).value
	side = 0.0
	for batch: Dictionary in frame.batches:
		if batch.has("lynx"): side = batch.lynx[5]
	check(side==-1.0 and presentation.frame_view.apply_frame(frame),"次の構えでは反対側の前足を光らせる")
	core.step(0.21)
	check(core.hostiles_snapshot().size()==2 and core.hostiles_snapshot()[1].side==-1.0 and pulse_motion(core,id).buds==2,"次の爪痕を左右交互に撃つ")
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step_hostiles(0.01)
	check(core.hostiles_snapshot().size()==2,"本体の撃破後も発射済みの爪痕が進む")
	core.step_hostiles(8.0)
	check(core.hostiles_snapshot().is_empty(),"爪痕を自然寿命で終了する")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"左右の回数・向き・溜めを値から復帰する")
	core.step(0.2)
	var future: Array = core.hostiles_snapshot()
	bridge.restore(pending.value)
	core.step(0.2)
	check(core.hostiles_snapshot()==future,"復帰後も同じ側へ撃ち保持元へ変更を漏らさない")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step(0.3)
	check(core.hostiles_snapshot().is_empty(),"溜め中の撃破では新しい爪痕を撃たない")
	core.remove_enemy(id)
	var replacement: int = core.spawn_enemy(&"lynx",position,{})
	check(replacement!=id and pulse_motion(core,replacement).buds==0 and pulse_motion(core,replacement).charge==0.0,"行の再利用で左右と溜めを引き継がない")
	var owner: int = core.spawn_enemy(&"drifter",target,{})
	core.set_enemy_motion(replacement,{"pump_owner":owner,"fire_t":0.01})
	core.remove_enemy(owner)
	core.step(0.1)
	check(pulse_motion(core,replacement).buds==1 and core.hostiles_snapshot().size()==1,"参照相手が先に消えても古い行を追わず撃つ")
	bridge.release_checkpoint(pending.value)
	session.free()

func check_cpp_soldier() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 78
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["cepheus_soldier","drifter"])
	stage.enemy_tuning = {"cepheus_soldier":{"armor":0.0},"drifter":{"speed":0.0}}
	var output := "res://.content/dev/run_soldier"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"兵の隊列と王の消失".sha256_text())
	check(built==OK,"兵の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_78.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":789},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"兵のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	core.configure_attack_budget({"enabled":false,"budget":4.0,"jitter":0.0})
	var anchor := target-Vector2(500,0)
	var king: int = core.spawn_enemy(&"drifter",anchor,{"facing":0.0})
	core.set_enemy_motion(king,{"held":true})
	var a_goal := anchor+Vector2(120,-60)
	var b_goal := anchor+Vector2(120,60)
	var a: int = core.spawn_enemy(&"cepheus_soldier",a_goal+Vector2(5,0),{})
	var b: int = core.spawn_enemy(&"cepheus_soldier",b_goal+Vector2(5,0),{})
	var formation := {"king_id":king,"tier":1,"anchor":anchor,"values":PackedFloat64Array([60,120,230,190,0.42])}
	check(bridge.command("dev_soldier_formation",formation.merged({"entity_id":a,"slot":0})).ok and bridge.command("dev_soldier_formation",formation.merged({"entity_id":b,"slot":2})).ok,"王Handleと隊列の値を兵へ渡す")
	core.step(0.01)
	check(pulse_motion(core,a).mode==RunIds.EnemyModeId.Move and Vector2(dolphin_enemy(core,a).pos[0],dolphin_enemy(core,a).pos[1]).is_equal_approx(a_goal),"隊列へ移動し距離8未満で固定位置へ着く")
	core.set_enemy_motion(a,{"charge":1.0})
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(900,400),Vector2(1800,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var visible := false
	for batch: Dictionary in frame.batches:
		if batch.has("soldier"): visible = batch.soldier.size()==14
	check(visible and presentation.frame_view.apply_frame(frame),"通常の兵と射撃予告を共通表示へ渡す")
	await get_tree().process_frame
	check(bridge.command("dev_soldier_fire",{"entity_id":a}).ok and core.hostiles_snapshot().size()==1,"王からの射撃入口で編集値の光弾を生成する")
	core.remove_enemy(king)
	core.step(0.01)
	check(pulse_motion(core,a).mode==RunIds.EnemyModeId.Recover and is_equal_approx(pulse_motion(core,a).timer,0.4),"王を先に消すと古い行を参照せず反乱を始める")
	var hp: float = dolphin_enemy(core,b).hp
	core.set_enemy_motion(a,{"fire_t":0.0})
	core.set_enemy_motion(b,{"fire_t":0.0})
	core.step(0.05)
	check(is_equal_approx(dolphin_enemy(core,b).hp,hp*0.65),"反乱で最寄りの兵へ最大HPの35%を与える")
	mute_checks = false
	var output_frame: Dictionary = bridge.read_frame().value
	check(output_frame.events.any(func(event): return event.type==&"beam"),"反乱の射撃を共通の光線イベントへ渡す")
	presentation.frame_view.receive_frame(output_frame)
	presentation.frame_view.update_effects(output_frame,0.0)
	frame = bridge.read_render(Rect2(target-Vector2(900,400),Vector2(1800,800))).value
	check(presentation.frame_view.apply_frame(frame) and not presentation.frame_view._mutiny_beams.is_empty(),"崩壊中の赤い点滅と兵同士の射撃を通常画面へ表示する")
	await get_tree().process_frame
	core.step(0.5)
	check(dolphin_enemy(core,a).dead and dolphin_enemy(core,b).dead,"反乱の期限で兵を共通の撃破処理へ渡す")
	core.step_hostiles(0.01)
	check(core.hostiles_snapshot().size()==1,"兵の撃破後も発射済みの光弾が進む")
	core.step_hostiles(8.0)
	check(core.hostiles_snapshot().is_empty(),"光弾は自然終了する")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"王参照・隊列値・構えを値から復帰する")
	core.remove_enemy(king)
	core.step(0.01)
	var future: Array = core.enemy_motion_snapshot()
	bridge.restore(pending.value)
	core.remove_enemy(king)
	core.step(0.01)
	check(core.enemy_motion_snapshot()==future,"復帰後も同じ反乱を始め保持元を変更しない")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":a,"cause":"bullet"})
	check(not bridge.command("dev_soldier_fire",{"entity_id":a}).ok and core.hostiles_snapshot().is_empty(),"途中撃破された兵は新しい光弾を撃たない")
	core.remove_enemy(a)
	var replacement: int = core.spawn_enemy(&"cepheus_soldier",a_goal,{})
	check(replacement!=a and pulse_motion(core,replacement).king_id==0 and pulse_motion(core,replacement).charge==0.0,"行の再利用で王と構えを引き継がない")
	core.step(0.01)
	core.step(0.5)
	check(dolphin_enemy(core,replacement).dead,"王のない単体配置は反乱後に自然崩壊する")
	bridge.release_checkpoint(pending.value)
	session.free()

func check_cpp_auriga() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 79
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["auriga","drifter"])
	stage.enemy_tuning = {"auriga":{"speed":100.0,"params.trail_step":0.1,"params.trail_time":0.3,"params.trail_width":8.0,"params.wheel_gap":20.0,"params.bullet_dmg":3.0}}
	var output := "res://.content/dev/run_auriga"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"ぎょしゃ座の車輪跡".sha256_text())
	check(built==OK,"ぎょしゃ座の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_79.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":799},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"ぎょしゃ座のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var position := target-Vector2(400,0)
	var id: int = core.spawn_enemy(&"auriga",position,{"facing":0.0})
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.step(0.1)
	var current := dolphin_enemy(core,id)
	check(current.vel[0]==100.0 and Vector2(current.pos[0],current.pos[1]).is_equal_approx(position+Vector2(10,0)) and core.hazards_snapshot().is_empty(),"予算0でも走行を続け車輪跡だけを待つ")
	core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	core.step(0.1)
	check(core.hazards_snapshot().size()==2 and is_equal_approx(pulse_motion(core,id).fire_t,0.1),"最初の帯の前に予算を取り左右一組を生成する")
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(900,400),Vector2(1800,800))).value
	var walls: Array = frame.shapes.filter(func(shape): return shape.kind==0 and shape.layer==10)
	check(walls.size()==2 and walls[0].points[0].distance_to(position+Vector2(0,-20))<0.01 and walls[1].points[0].distance_to(position+Vector2(0,20))<0.01 and is_equal_approx(walls[0].widths[1],8.0),"左右の間隔と幅と走行区間を編集値から生成する")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(presentation.frame_view.apply_frame(frame),"本体と左右の燃える車輪跡を通常画面へ表示する")
	await get_tree().process_frame
	core.advance_attack_budget(0.8)
	check(core.attack_budget_snapshot().groups.size()==1 and not core.attack_budget_snapshot().groups[0].members[0].closed,"走行中は攻撃枠の初期期限を越えて保持する")
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	core.step(0.1)
	check(core.hazards_snapshot().size()==4 and core.attack_budget_snapshot().groups.size()==1,"次の車輪跡でも同じ攻撃枠を使い続ける")
	var future_motion: Array = core.enemy_motion_snapshot()
	var future_hazards: Array = core.hazards_snapshot()
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.advance_attack_budget(0.9)
	check(core.hazards_snapshot().size()==4 and core.attack_snapshot().filter(func(item): return item.pool==2)[0].residuals==4 and core.attack_budget_snapshot().used>0.0,"本体を倒しても残る帯が同じ予算を保持する")
	var hp: float = core.ship_snapshot().ship_hp
	bridge.command("dev_ship_motion",{"position":position+Vector2(5,-20),"velocity":Vector2.ZERO})
	core.step_hazards(0.05)
	check(is_equal_approx(core.ship_snapshot().ship_hp,hp-3.0),"残った車輪跡が編集値のダメージを機体へ与える")
	core.step_hazards(0.3)
	core.advance_attack_budget(1.0)
	check(core.hazards_snapshot().is_empty() and core.attack_budget_snapshot().used==0.0,"車輪跡の自然終了で保持した予算を返す")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"走行の向き・間隔と残る帯を値から復帰する")
	core.step(0.1)
	check(core.enemy_motion_snapshot()==future_motion and core.hazards_snapshot()==future_hazards,"復帰後も同じ区間へ帯を残し保持元を変更しない")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step(0.2)
	check(core.hazards_snapshot().size()==2,"途中撃破で新しい車輪跡を増やさない")
	core.remove_enemy(id)
	var replacement: int = core.spawn_enemy(&"auriga",position,{})
	check(replacement!=id and pulse_motion(core,replacement).age==0.0 and pulse_motion(core,replacement).fire_t==0.0,"行の再利用で時計と古い帯の所有を引き継がない")
	var owner: int = core.spawn_enemy(&"drifter",target,{})
	core.set_enemy_motion(replacement,{"pump_owner":owner})
	core.remove_enemy(owner)
	core.configure_attack_budget({"enabled":false,"budget":1.0,"jitter":0.0})
	core.step(0.1)
	check(dolphin_enemy(core,replacement).vel[0]!=0.0 or dolphin_enemy(core,replacement).vel[1]!=0.0,"参照相手が先に消えても古い行を追わず走る")
	bridge.release_checkpoint(pending.value)
	session.free()

func clock_shapes(bridge, target: Vector2) -> Array:
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,400),Vector2(1600,800))).value
	return frame.shapes.filter(func(shape): return shape.kind==0 and shape.layer==10)

func check_cpp_clock() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 81
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["clock","drifter"])
	stage.enemy_tuning = {"clock":{"speed":0.0,"params.telegraph":0.25,"params.hand_long":60.0,"params.hand_short":30.0,"params.hand_width":8.0,"params.bullet_dmg":5.0}}
	var output := "res://.content/dev/run_clock"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"とけい座の二本の針".sha256_text())
	check(built==OK,"とけい座の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_81.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":819},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"とけい座のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var position := target-Vector2(400,0)
	var id: int = core.spawn_enemy(&"clock",position,{})
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.step(0.1)
	check(core.hazards_snapshot().is_empty() and pulse_motion(core,id).spin==0.0,"予算0では針と回転時計を開始しない")
	core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	core.step(0.2)
	check(core.hazards_snapshot().size()==2 and is_equal_approx(pulse_motion(core,id).spin,0.2) and core.attack_snapshot().filter(func(item): return item.pool==2).all(func(item): return item.attached and item.source_id==id),"許可後に本体へ二本の針を付けて回転を始める")
	var shapes := clock_shapes(bridge,target)
	check(shapes.size()==2 and shapes[0].points[0]==position and shapes[0].points[1].distance_to(position+Vector2.from_angle(0.2*1.6)*60.0)<0.01 and shapes[1].points[1].distance_to(position+Vector2.from_angle(0.2*-0.7+PI)*30.0)<0.01,"長針と短針の長さと符号の違う回転速度を保持する")
	core.step_hazards(0.1)
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,400),Vector2(1600,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(presentation.frame_view.apply_frame(frame) and core.hazards_snapshot()[0].time<core.hazards_snapshot()[0].delay,"予告中の二本の針を通常画面へ表示する")
	await get_tree().process_frame
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	core.step(0.1)
	var future: Array = core.enemy_motion_snapshot()
	var future_shapes := clock_shapes(bridge,target)
	bridge.command("dev_ship_motion",{"position":position+Vector2.from_angle(0.3*1.6)*40.0,"velocity":Vector2.ZERO})
	var hp: float = core.ship_snapshot().ship_hp
	core.step_hazards(0.15)
	check(is_equal_approx(core.ship_snapshot().ship_hp,hp-5.0),"予告が終わった針だけが編集値のダメージを与える")
	core.advance_attack_budget(2.0)
	check(not core.attack_budget_snapshot().groups[0].members[0].closed,"針が付いている間は予算の初期期限を越えて保持する")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"回転時計と二本の攻撃Handleを値から復帰する")
	core.step(0.1)
	check(core.enemy_motion_snapshot()==future and clock_shapes(bridge,target)==future_shapes,"復帰後も同じ向きへ針を動かし保持元を変更しない")
	bridge.command("dev_clear_hostile",{})
	check(core.hazards_snapshot().is_empty(),"共通の攻撃消去で二本の針が終了する")
	var old_hands: PackedInt64Array = pulse_motion(core,id).hands
	core.step(0.1)
	check(core.hazards_snapshot().size()==2 and pulse_motion(core,id).hands!=old_hands,"消された針を古いHandleへ接続せず二本とも作り直す")
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step(0.2)
	check(core.hazards_snapshot().is_empty(),"本体の途中撃破で付いている針を終了して作り直さない")
	core.remove_enemy(id)
	var replacement: int = core.spawn_enemy(&"clock",position,{})
	check(replacement!=id and pulse_motion(core,replacement).spin==0.0 and pulse_motion(core,replacement).hands==PackedInt64Array([0,0]),"行の再利用で時計と古い針を引き継がない")
	var owner: int = core.spawn_enemy(&"drifter",target,{})
	core.set_enemy_motion(replacement,{"pump_owner":owner})
	core.remove_enemy(owner)
	core.configure_attack_budget({"enabled":false,"budget":1.0,"jitter":0.0})
	core.step(0.1)
	check(core.hazards_snapshot().size()==2,"参照相手が先に消えても古い行を追わず針を出す")
	bridge.release_checkpoint(pending.value)
	session.free()

func check_cpp_reticle() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 1200.0
	cfg.planet_radius = 0.0
	cfg.character_scale = 1.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 92
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["reticle","telescope"])
	stage.enemy_tuning = {"reticle":{"speed":0.0,"params.aim_time":0.2,"params.break_interval":0.3,"params.small_r":90.0,"params.exit_margin":20.0},"telescope":{"speed":0.0}}
	var output := "res://.content/dev/run_reticle"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"レチクル座の遮蔽岩の破壊".sha256_text())
	check(built==OK,"レチクル座の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_92.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":929},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"レチクル座のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var tel_position := target-Vector2(600,0)
	var telescope_id: int = core.spawn_enemy(&"telescope",tel_position,{"facing":0.0})
	core.set_enemy_motion(telescope_id,{"held":true})
	var position := tel_position+Vector2(-30,-150)
	var id: int = core.spawn_enemy(&"reticle",position,{})
	bridge.command("dev_add_rock",{"position":target-Vector2(220,0),"kind":0,"manual":true})
	bridge.command("dev_add_rock",{"position":target-Vector2(200,300),"kind":0,"manual":true})
	bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
	var rocks: Array = bridge.command("dev_field_query",{"action":"rocks"}).value
	var rock: int = rocks[0].enemy_id
	var outside: int = rocks[1].enemy_id
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.step(0.1)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Move and not dolphin_enemy(core,rock).dead,"予算0では遮蔽岩へ照準を始めない")
	core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	core.step(0.1)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Windup and pulse_motion(core,id).target_id==rock and is_equal_approx(pulse_motion(core,id).timer,0.2),"望遠鏡のレンズと機体の間の小隕石だけを狙う")
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	core.step(0.1)
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(900,400),Vector2(1800,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var warning := false
	for batch: Dictionary in frame.batches:
		if batch.has("reticle"): warning = batch.reticle.size()==12 and batch.reticle[8]==1.0
	check(warning and presentation.frame_view.apply_frame(frame),"岩の四隅と本体からの照準線を通常画面へ表示する")
	await get_tree().process_frame
	var kills: int = core.combat_snapshot().kills
	var xp: float = core.pickups_snapshot().xp_dropped
	var ship_hp: float = core.ship_snapshot().ship_hp
	core.step(0.11)
	check(dolphin_enemy(core,rock).dead and not dolphin_enemy(core,outside).dead and pulse_motion(core,id).mode==RunIds.EnemyModeId.Move and pulse_motion(core,id).fire_t==0.3,"予告後に狙った岩だけを破壊して編集値の間隔へ戻る")
	check(core.combat_snapshot().kills==kills and core.pickups_snapshot().xp_dropped==xp and core.ship_snapshot().ship_hp==ship_hp,"岩の破壊を撃破・経験値・機体ダメージへ数えない")
	var output_frame: Dictionary = bridge.read_frame().value
	check(output_frame.events.any(func(event): return event.type==&"beam") and output_frame.events.any(func(event): return event.type==&"rock_break"),"ビームと岩の破片を共通イベントへ渡す")
	presentation.frame_view.receive_frame(output_frame)
	presentation.frame_view.update_effects(output_frame,0.0)
	check(not presentation.frame_view._mutiny_beams.is_empty() and not presentation.frame_view._meteor_shards.is_empty(),"発射した光線と岩の破片を通常画面へ表示する")
	await get_tree().process_frame
	bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
	rocks = bridge.command("dev_field_query",{"action":"rocks"}).value
	check(rocks[0].destroyed and rocks[0].enemy_id==0,"破壊した岩は配置元でも破壊済みとなり再出現しない")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"狙う岩Handle・時計・支援状態を値から復帰する")
	core.step(0.21)
	var future: Array = core.enemy_motion_snapshot()
	bridge.restore(pending.value)
	core.step(0.21)
	check(core.enemy_motion_snapshot()==future,"復帰後も同じ岩を破壊し保持元へ変更を漏らさない")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":rock,"cause":"bullet"})
	core.step(0.1)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Move and not pulse_motion(core,id).target_alive,"照準中の岩を先に壊すと発射を取り消す")
	bridge.restore(pending.value)
	core.remove_enemy(telescope_id)
	core.step(0.1)
	check(pulse_motion(core,id).mode==RunIds.EnemyModeId.Dash and not dolphin_enemy(core,rock).dead,"支援先を先に消すと岩を撃たず退却する")
	var kills_before_exit: int = core.combat_snapshot().kills
	bridge.command("dev_relocate",{"entity_id":id,"position":target-Vector2(700,0)})
	core.step(0.1)
	check(dolphin_enemy(core,id).dead and core.combat_snapshot().kills==kills_before_exit,"画面外で離れる支援機を撃破に数えず退場させる")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step(0.3)
	check(not dolphin_enemy(core,rock).dead,"予告中の本体撃破では岩を破壊しない")
	core.remove_enemy(id)
	var replacement: int = core.spawn_enemy(&"reticle",position,{})
	check(replacement!=id and pulse_motion(core,replacement).target_id==0 and pulse_motion(core,replacement).charge==0.0,"行の再利用で古い岩と照準を引き継がない")
	bridge.release_checkpoint(pending.value)
	session.free()

func cepheus_soldiers(core, king: int) -> Array:
	return core.enemy_motion_snapshot().filter(func(row): return row.get("king_id",0)==king and not dolphin_enemy(core,row.id).dead and row.mode!=RunIds.EnemyModeId.Recover)

func check_cpp_cepheus() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 93
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["cepheus","drifter"])
	stage.enemy_tuning = {"cepheus":{"speed":0.0,"armor":0.0,"params.summon_time":0.1,"params.reinforce_interval":10.0,"params.mutiny_time":0.4},"cepheus_soldier":{"armor":0.0}}
	var output := "res://.content/dev/run_cepheus"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"ケフェウスの召喚と号令".sha256_text())
	check(built==OK,"ケフェウスと参照する兵を編集値から生成する")
	if built!=OK: return
	var path := output.path_join("stage_93.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":931},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"ケフェウスのランと専用画像を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.configure_attack_budget({"enabled":false,"budget":4.0,"jitter":0.0})
	core.set_motion_context(target,target,Vector2(640,360))
	var king: int = core.spawn_enemy(&"cepheus",target-Vector2(400,0),{"facing":0.0})
	core.step(0.05)
	check(pulse_motion(core,king).tier==1 and pulse_motion(core,king).mode==RunIds.EnemyModeId.Windup,"初回は3体隊列の召喚予告を始める")
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	var view := Rect2(target-Vector2(1000,600),Vector2(2000,1200))
	var frame: Dictionary = bridge.read_render(view).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(frame.cepheus.marks.size()==3*10 and presentation.frame_view.apply_frame(frame),"王冠と3か所の召喚予告を共通表示へ渡す")
	await get_tree().process_frame
	core.step(0.05)
	core.step(0.05)
	var soldiers: Array = cepheus_soldiers(core,king)
	check(soldiers.size()==3 and soldiers.all(func(row): return row.age==0.0),"召喚は即時登録し新しい兵の行動は次tickから始める")
	for n in 18: core.step(0.05)
	check(core.hostiles_snapshot().size()==3,"画面内で予告を終えた3体が一斉射撃する")
	check(soldiers.all(func(row): return pulse_motion(core,row.id).mode==RunIds.EnemyModeId.Move),"兵は指定された隊列の位置に整列する")
	var future: Array = core.enemy_motion_snapshot()
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"召喚途中の群れと隊列を値から復帰する")
	for n in 20: core.step(0.05)
	check(core.enemy_motion_snapshot()==future,"復帰後の召喚・号令と乱数消費が一致する")
	soldiers = cepheus_soldiers(core,king)
	bridge.command("dev_kill",{"entity_id":soldiers[0].id,"cause":"bullet"})
	for n in 4: core.step(0.05)
	check(cepheus_soldiers(core,king).size()==2,"倒れた兵の穴は次の増援まで残す")
	for tier in [2,3]:
		core.set_enemy_motion(king,{"fire_t":0.0})
		for n in 90:
			core.step(0.05)
			if pulse_motion(core,king).tier==tier and pulse_motion(core,king).mode==RunIds.EnemyModeId.Move: break
		check(cepheus_soldiers(core,king).size()==(5 if tier==2 else 7),"増援で%d体の隊列へ組み直す" % (5 if tier==2 else 7))
	var seven: Dictionary = bridge.checkpoint()
	core.set_motion_context(target+Vector2(10000,0),target,Vector2(100,100))
	var bolt_count: int = core.hostiles_snapshot().size()
	for n in 20: core.step(0.05)
	check(core.hostiles_snapshot().size()==bolt_count and cepheus_soldiers(core,king).all(func(row): return row.charge==0.0),"画面外の兵は予告をためず新しい弾を撃たない")
	bridge.restore(seven.value)
	core.set_motion_context(target,target,Vector2(640,360))
	bolt_count = core.hostiles_snapshot().size()
	var shots: Array[int] = []
	for n in 40:
		core.step(0.05)
		var count: int = core.hostiles_snapshot().size()
		if count>bolt_count:
			shots.append(count-bolt_count)
			bolt_count=count
			if shots.size()==2: break
	check(shots==[4,3],"7体隊列は前列4体と後列3体が交互に撃つ")
	bridge.restore(seven.value)
	soldiers = cepheus_soldiers(core,king)
	bridge.command("dev_kill",{"entity_id":king,"cause":"bullet"})
	check(soldiers.all(func(row): return pulse_motion(core,row.id).mode==RunIds.EnemyModeId.Recover and pulse_motion(core,row.id).timer>=0.4 and pulse_motion(core,row.id).timer<1.0),"王の途中撃破で生存兵全員が乱数付きの反乱へ入る")
	core.set_enemy_motion(soldiers[0].id,{"fire_t":0.0})
	core.step(0.01)
	var events: Array = bridge.read_frame().value.events
	check(events.any(func(event): return event.type==&"beam"),"反乱の射撃を既存の表示通知へ渡す")
	for n in 24: core.step(0.05)
	check(soldiers.all(func(row): return dolphin_enemy(core,row.id).dead),"反乱は正常に崩壊し兵の撃破で終了する")
	bridge.restore(seven.value)
	soldiers=cepheus_soldiers(core,king)
	core.remove_enemy(king)
	var replacement: int = core.spawn_enemy(&"cepheus",target-Vector2(400,0),{})
	core.remove_enemy(soldiers[1].id)
	core.step(0.01)
	check(pulse_motion(core,replacement).tier==1 and pulse_motion(core,soldiers[0].id).mode==RunIds.EnemyModeId.Recover,"王と相手の先行削除・王の行再利用でも古い兵を再所属させない")
	bridge.command("dev_kill",{"entity_id":replacement,"cause":"bullet"})
	for n in 150: core.step(0.01)
	check(cepheus_soldiers(core,replacement).is_empty(),"召喚途中で王を倒すと兵を後から生成しない")
	bridge.release_checkpoint(pending.value)
	bridge.release_checkpoint(seven.value)
	session.free()

func check_cpp_triangle_star() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 94
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["darter","triangle_star"])
	stage.enemy_tuning = {"darter":{"speed":0.0,"params.windup":0.05,"params.dash_speed":0.0,"params.dash_time":0.3}}
	var output := "res://.content/dev/run_triangle_star"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"三角形の星の部位とゲート".sha256_text())
	check(built==OK,"三角形の星の編集値と専用画像を生成する")
	if built!=OK: return
	var path := output.path_join("stage_94.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":941},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"星の部位と通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.configure_attack_budget({"enabled":false,"budget":4.0,"jitter":0.0})
	core.set_motion_context(target,target,Vector2(640,360))
	# 親triangleは別の移行単位。既存DASH種類で部位の親mode依存を確かめる。
	var parent: int = core.spawn_enemy(&"darter",target+Vector2(500,0),{})
	var at := target+Vector2(200,100)
	var made: Dictionary = bridge.command("dev_spawn_part",{"parent_id":parent,"definition_id":"triangle_star","position":at})
	check(made.ok,"既存の部位生成入口で星を登録する")
	if not made.ok:
		session.free()
		return
	var star: int = made.value
	check(pulse_motion(core,star).parent_id==parent,"星は世代付きの親と個体IDを保持する")
	var hit: Dictionary = bridge.command("dev_damage",{"entity_id":star,"amount":0.5,"cause":"shot","no_crit":true})
	check(hit.ok and hit.value.applied==0.5,"親が止まっている間は星へ通常の攻撃が通る")
	core.step(0.05)
	core.step(0.05)
	check(pulse_motion(core,parent).mode==RunIds.EnemyModeId.Dash and Vector2(dolphin_enemy(core,star).vel[0],dolphin_enemy(core,star).vel[1])==Vector2.ZERO,"星は独自に進まず親の辺移動を参照する")
	core.set_enemy_motion(parent,{"held":true})
	hit = bridge.command("dev_damage",{"entity_id":star,"amount":0.5,"cause":"shot","no_crit":true})
	check(hit.ok and hit.value.applied==0.0 and hit.value.reason==&"damage_gate","親が辺を移動中は星のゲートがダメージを止める")
	var hp: float = dolphin_enemy(core,star).hp
	core.rebuild_enemy_grid(cfg.grid_cell)
	bridge.command("dev_ship_motion",{"position":at+Vector2(5,0),"velocity":Vector2(1200,0)})
	core.collide_ship(at-Vector2(5,0),cfg.ship_radius)
	check(dolphin_enemy(core,star).hp==hp and core.ship_snapshot().ship_vel==Vector2(1200,0),"移動中の星を体当たりで通り抜け、反射もダメージも出さない")
	var wall: Dictionary = bridge.command("dev_fire_wall",{"position":at-Vector2(150,0),"angle":0.0,"length":150.0,"width":14.0,"delay":0.0,"active":0.5,"damage":3.0,"style":1,"attached":true,"owner_id":star})
	check(wall.ok,"既存の壁入口で星へ赤い軌跡を付ける")
	var pending: Dictionary = bridge.checkpoint()
	var before: Array = core.enemy_motion_snapshot()
	var hazards: Array = core.hazards_snapshot()
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(900,500),Vector2(1800,1000))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(frame.triangle_star.size()==5 and presentation.frame_view.apply_frame(frame),"星の画像と段差のある赤い軌跡を通常画面へ表示する")
	await get_tree().process_frame
	core.step_hazards(0.6)
	check(core.hazards_snapshot().is_empty(),"星の軌跡は自然寿命で終了する")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before and core.hazards_snapshot()==hazards,"親参照・ゲート・軌跡を値から復帰する")
	bridge.command("dev_kill",{"entity_id":star,"cause":"shot"})
	core.step_hazards(0.01)
	check(core.hazards_snapshot().is_empty() and not dolphin_enemy(core,parent).dead,"星の途中撃破で付属軌跡を終了し親へダメージを転送しない")
	bridge.restore(pending.value)
	core.remove_enemy(parent)
	var replacement: int = core.spawn_enemy(&"darter",target+Vector2(500,0),{})
	core.step(0.01)
	core.step_hazards(0.01)
	check(dolphin_enemy(core,star).dead and core.hazards_snapshot().is_empty() and replacement!=parent,"親の先行削除と行の再利用で古い星を新しい親へ結び付けない")
	core.remove_enemy(star)
	var alone: int = core.spawn_enemy(&"triangle_star",at,{})
	core.step(0.01)
	check(dolphin_enemy(core,alone).dead and not pulse_motion(core,alone).has("parent_id"),"親のない単体の星は古い親参照を持たず正常に退場する")
	bridge.release_checkpoint(pending.value)
	session.free()

func check_cpp_cepheus_notifications() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius=900.0
	cfg.planet_radius=0.0
	cfg.world_tick_div=1
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index=93
	stage.resources=StageResources.new()
	stage.resources.enemy_ids=PackedStringArray(["cepheus"])
	stage.enemy_tuning={"cepheus":{"speed":0.0,"params.summon_time":0.05}}
	var output := "res://.content/dev/run_cepheus_notifications"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"ケフェウスの固定更新から通知を配信する".sha256_text())
	if built!=OK:
		check(false,"通知確認用の固定入力を生成できる")
		return
	var path := output.path_join("stage_93.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":931},true)
	session.auto_step=false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null:
		check(false,"通知確認のランを準備できる")
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var events: Array=[]
	bridge.subscribe("cepheus_notifications",func(frame: Dictionary) -> bool:
		events.append_array(frame.events)
		return true)
	var target: Vector2=core.ship_snapshot().ship_pos
	core.spawn_enemy(&"cepheus",target+Vector2(400,0),{})
	var valid := true
	for n in 12:
		valid = bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)}).ok and valid
		valid = bridge.read_frame().ok and valid
	check(valid,"召喚前後の固定更新とread_frameの通知封筒を受け取れる")
	check(events.filter(func(event): return event.type==&"summon_mark").size()==3 and events.filter(func(event): return event.type==&"cepheus_summon").size()==1,"召喚予告3件と召喚1件を型付き通知で通常配信する")
	await get_tree().process_frame
	var presentation: RunPresentation=session.view.get_node("RunPresentation")
	check(presentation.frame_view._rings.any(func(ring): return ring.radius==70.0),"召喚通知を元の半径70の光の輪として表示する")
	session.free()

func ruler_tick(core, dt: float) -> void:
	core.step(dt)
	core.step_hazards(dt)
	core.advance_attack_budget(float(core.inspect().world_time))

func check_cpp_ruler() -> bool:
	var cfg: GameConfig=ContentManager.base.duplicate(true)
	cfg.start_radius=900.0
	cfg.planet_radius=0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage:=RuntimeStage.new()
	stage.index=101
	stage.resources=StageResources.new()
	stage.resources.enemy_ids=PackedStringArray(["ruler"])
	stage.enemy_tuning={"ruler":{"speed":0.0,"params.split_delay":0.1,"params.deploy_time":0.1,"params.deploy_speed":100.0,"params.telegraph":0.1,"params.beam_time":0.2}}
	var output:="res://.content/dev/run_ruler"
	var built: Error=preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"じょうぎ座の分裂と照射".sha256_text())
	check(built==OK,"じょうぎ座の編集値と上下の専用画像を生成する")
	if built!=OK: return false
	var path:=output.path_join("stage_101.json")
	var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession=RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":1011},true)
	session.auto_step=false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"じょうぎ座のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return false
	var bridge=session.bridge
	var core=bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
	var target: Vector2=core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	core.configure_attack_budget({"enabled":true,"budget":2.0,"jitter":0.0})
	var first: int=core.spawn_enemy(&"ruler",target+Vector2(400,50),{"attack_group":9,"attack_value":1.0,"attack_priority":3.0})
	var view:=Rect2(target-Vector2(900,600),Vector2(1800,1200))
	var frame: Dictionary=bridge.read_render(view).value
	var presentation: RunPresentation=session.view.get_node("RunPresentation")
	check(presentation.frame_view.apply_frame(frame),"分裂前の定規を共通表示へ渡す")
	var display= presentation.frame_view.enemy_frames.values()[0]
	check(display._parts.size()==2 and display._parts.all(func(part): return part.base._count==1),"分裂前は上下の絵を同じキャンバスに重ねる")
	await get_tree().process_frame
	ruler_tick(core,0.05)
	ruler_tick(core,0.05)
	var rows: Array=core.enemy_motion_snapshot()
	check(rows.size()==2 and rows[0].side==1 and rows[1].side==-1 and rows[1].age==0.0,"自己分裂を即時登録し同種の子は次tickから更新する")
	var second: int=rows[1].id
	check(is_equal_approx(rows[0].facing,PI) and rows[0].facing==rows[1].facing and rows.all(func(row): return row.attack_priority==3.0),"機体への縦横の大きい軸と親の攻撃設定を両側へ引き継ぐ")
	for n in 3: ruler_tick(core,0.05)
	check(pulse_motion(core,first).mode==RunIds.EnemyModeId.Windup and pulse_motion(core,first).charge>0.0,"展開から予告に入り編集された予告時間で構える")
	var pending: Dictionary=bridge.checkpoint()
	var before: Array=core.enemy_motion_snapshot()
	frame=bridge.read_render(view).value
	check(frame.ruler.size()==24 and presentation.frame_view.apply_frame(frame),"分離した半身と発射元の隙間を含む点線の予告を表示する")
	check(display._parts.all(func(part): return part.base._count==1),"分離後は各個体が上下どちらか片側だけを描く")
	await get_tree().process_frame
	if "--cpp-ruler-voices" in OS.get_cmdline_user_args():
		mute_checks=false
		bridge.command("set_ui_overlay",{"active":false})
		var packet: Dictionary=bridge.read_frame()
		check(packet.ok and packet.value.ui.laser_voices.size()==2,"両側の構えを既存のチャージ音の読取へ渡す")
		bridge.command("dev_kill",{"entity_id":first,"cause":"shot"})
		packet=bridge.read_frame()
		check(packet.ok and packet.value.ui.laser_voices.size()==1 and packet.value.ui.laser_voices[0].id==second,"途中撃破で倒れた側のチャージ音だけを止める")
		core.remove_enemy(second)
		bridge.command("set_ui_overlay",{"active":false})
		packet=bridge.read_frame()
		if not "--cpp-ruler-voice-fixes" in OS.get_cmdline_user_args(): check(packet.ok and packet.value.ui.laser_voices.is_empty(),"相手の削除でも残るチャージ音を止める")
		bridge.release_checkpoint(pending.value)
		session.free()
		return true
	ruler_tick(core,0.05)
	var walls: Array=core.hazards_snapshot()
	check(walls.size()==2 and walls.all(func(wall): return wall.blocking and wall.owner_id>0 and wall.token>0 and wall.style==2 and wall.length==2600.0 and wall.half_width==13.0),"両側から予算付きの長いビームの壁を発射する")
	for wall: Dictionary in walls:
		var enemy: Dictionary=dolphin_enemy(core,wall.owner_id)
		var expected: Vector2=Vector2(enemy.pos[0],enemy.pos[1])+Vector2.from_angle(enemy.facing)*(enemy.radius+13.0+80.0)
		check((wall.pos as Vector2).distance_to(expected)<3.0,"発射元は本体半径・半幅・編集した隙間から決まる")
	var output_frame: Dictionary=bridge.read_frame()
	check(output_frame.ok,"分裂と予告・発射の通知を固定の封筒で受け取れる")
	if output_frame.ok:
		check(output_frame.value.events.filter(func(event): return event.type==&"ruler_split").size()==1 and output_frame.value.events.filter(func(event): return event.type==&"enemy_laser_fire").size()==2,"分裂1件と両側の発射通知を生成する")
	frame=bridge.read_render(view).value
	check(presentation.frame_view.apply_frame(frame) and frame.shapes.any(func(shape): return shape.kind==0),"照射中の光の柱を既存の壁表示へ渡す")
	await get_tree().process_frame
	var fired: Dictionary=bridge.checkpoint()
	var future: Array=core.enemy_motion_snapshot()
	var future_walls: Array=core.hazards_snapshot()
	mute_checks=false
	for n in 5: ruler_tick(core,0.05)
	check(core.hazards_snapshot().is_empty() and float(core.attack_budget_snapshot().used)==0.0 and pulse_motion(core,first).mode==RunIds.EnemyModeId.Dash,"照射の正常終了で壁と攻撃予算を解放し再展開する")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before,"分裂後の左右・予告・予算を値から復帰する")
	ruler_tick(core,0.05)
	check(core.enemy_motion_snapshot()==future and core.hazards_snapshot()==future_walls,"復帰後の発射・壁の所有・乱数消費が一致する")
	bridge.command("dev_kill",{"entity_id":first,"cause":"shot"})
	core.step_hazards(0.01)
	core.advance_attack_budget(float(core.inspect().world_time)+0.01)
	check(core.hazards_snapshot().size()==1 and not dolphin_enemy(core,second).dead,"一方を途中撃破するとそのビームだけ終了し相手は残る")
	core.remove_enemy(second)
	core.advance_attack_budget(float(core.inspect().world_time)+1.0)
	check(core.hazards_snapshot().is_empty() and float(core.attack_budget_snapshot().used)==0.0 and core.attack_budget_snapshot().waiting.is_empty(),"相手の先行削除でも残る線と子の予算待ちを掃除する")
	core.remove_enemy(first)
	var replacement: int=core.spawn_enemy(&"ruler",target+Vector2(100,400),{})
	check(pulse_motion(core,replacement).side==0 and pulse_motion(core,replacement).beam_id==0,"行再利用で左右や古い壁の所有を引き継がない")
	bridge.release_checkpoint(pending.value)
	bridge.release_checkpoint(fired.value)
	session.free()
	return true

func triangle_parts(core, parent: int) -> Array:
	return core.enemy_motion_snapshot().filter(func(row): return row.get("parent_id",0)==parent and not dolphin_enemy(core,row.id).dead)

func triangle_vertices(core, parent: int, parts: Array, travel: float, span: float) -> bool:
	var body: Dictionary=dolphin_enemy(core,parent)
	var center:=Vector2(body.pos[0],body.pos[1])
	var motion: Dictionary=pulse_motion(core,parent)
	for k in parts.size():
		var a:=center+Vector2.from_angle(motion.spin+TAU*float((k+motion.buds)%3)/3.0)*span
		var b:=center+Vector2.from_angle(motion.spin+TAU*float((k+motion.buds+1)%3)/3.0)*span
		var star: Dictionary=dolphin_enemy(core,parts[k].id)
		if Vector2(star.pos[0],star.pos[1]).distance_to(a.lerp(b,travel))>0.001: return false
	return true

func check_cpp_triangle() -> bool:
	var cfg: GameConfig=ContentManager.base.duplicate(true)
	cfg.start_radius=900.0
	cfg.planet_radius=0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage:=RuntimeStage.new()
	stage.index=108
	stage.resources=StageResources.new()
	stage.resources.enemy_ids=PackedStringArray(["triangle","drifter"])
	stage.enemy_tuning={"triangle":{"speed":30.0,"params.move_time":0.2,"params.stop_time":0.1}}
	var output:="res://.content/dev/run_triangle"
	var built: Error=preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"三角形の星生成と辺移動".sha256_text())
	check(built==OK,"三角形と参照する3星を編集値から生成する")
	if built!=OK: return false
	var path:=output.path_join("stage_108.json")
	var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession=RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":1081},true)
	session.auto_step=false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"三角形の親と星の通常表示を準備する")
	if session.bridge==null:
		session.free()
		return false
	var bridge=session.bridge
	var core=bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
	var target: Vector2=core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	core.configure_attack_budget({"enabled":true,"budget":2.0,"jitter":0.0})
	var parent: int=core.spawn_enemy(&"triangle",target+Vector2(400,100),{"facing":PI})
	var parts: Array=triangle_parts(core,parent)
	check(parts.size()==3 and parts.all(func(row): return row.age==0.0) and triangle_vertices(core,parent,parts,0.0,150.0),"出生時に3星を共通部位へ登録し固定した三角の頂点へ置く")
	var view:=Rect2(target-Vector2(900,600),Vector2(1800,1200))
	var frame: Dictionary=bridge.read_render(view).value
	var ids:=PackedInt64Array()
	for batch: Dictionary in frame.batches: ids.append_array(batch.ids)
	var presentation: RunPresentation=session.view.get_node("RunPresentation")
	check(ids.size()==3 and not ids.has(parent) and presentation.frame_view.apply_frame(frame),"中心を描かず生成した3星だけを共通表示へ渡す")
	await get_tree().process_frame
	var original: Dictionary=dolphin_enemy(core,parent)
	ruler_tick(core,0.05)
	var body: Dictionary=dolphin_enemy(core,parent)
	check(Vector2(body.pos[0],body.pos[1]).distance_to(target)<Vector2(original.pos[0],original.pos[1]).distance_to(target) and triangle_vertices(core,parent,parts,0.0,150.0),"中心はゆっくり機体へ寄り星の停止位置も中心と一緒に動く")
	ruler_tick(core,0.05)
	check(pulse_motion(core,parent).mode==RunIds.EnemyModeId.Dash and core.hazards_snapshot().size()==3,"停止時間の終了で生存する星へ3本の軌跡を付ける")
	ruler_tick(core,0.05)
	check(triangle_vertices(core,parent,parts,0.25,150.0) and core.hazards_snapshot().all(func(wall): return wall.length>0 and wall.style==1 and wall.token>0),"星は辺の四分の一へ進みその後ろへ実際の長さの軌跡を伸ばす")
	var pending: Dictionary=bridge.checkpoint()
	var before: Array=core.enemy_motion_snapshot()
	var before_enemies: Array=core.enemies_snapshot()
	var before_walls: Array=core.hazards_snapshot()
	frame=bridge.read_render(view).value
	check(frame.triangle_star.size()==15 and presentation.frame_view.apply_frame(frame),"親の辺移動で3本の赤い軌跡を通常表示へ渡す")
	await get_tree().process_frame
	ruler_tick(core,0.05)
	var future: Array=core.enemy_motion_snapshot()
	var future_enemies: Array=core.enemies_snapshot()
	var future_walls: Array=core.hazards_snapshot()
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==before and core.enemies_snapshot()==before_enemies and core.hazards_snapshot()==before_walls,"親の固定角度・部位Handle・伸長中の線を値から復帰する")
	ruler_tick(core,0.05)
	check(core.enemy_motion_snapshot()==future and core.enemies_snapshot()==future_enemies and core.hazards_snapshot()==future_walls,"復帰後も同じ順で辺を進み保持元を変更しない")
	for n in 8:
		if pulse_motion(core,parent).mode==RunIds.EnemyModeId.Move: break
		ruler_tick(core,0.05)
	check(pulse_motion(core,parent).buds==1 and core.hazards_snapshot().is_empty() and triangle_vertices(core,parent,parts,0.0,150.0),"次の頂点に着くと線を終了して星を停止する")
	bridge.command("dev_kill",{"entity_id":parts[0].id,"cause":"shot"})
	core.remove_enemy(parts[0].id)
	var unrelated: int=core.spawn_enemy(&"drifter",target+Vector2(600,300),{})
	for n in 8:
		ruler_tick(core,0.05)
		if not core.hazards_snapshot().is_empty(): break
	check(triangle_parts(core,parent).size()==2 and core.hazards_snapshot().size()==2 and not pulse_motion(core,unrelated).has("parent_id"),"星の先行撃破と行再利用後は元の2星だけが辺を進む")
	for n in 8:
		if pulse_motion(core,parent).mode==RunIds.EnemyModeId.Move: break
		ruler_tick(core,0.05)
	for k in [1,2]: bridge.command("dev_kill",{"entity_id":parts[k].id,"cause":"shot"})
	ruler_tick(core,0.01)
	var result: Dictionary=bridge.read_frame()
	check(dolphin_enemy(core,parent).dead and core.hazards_snapshot().is_empty() and result.ok and result.value.events.filter(func(event): return event.type==&"kill" and event.payload.enemy_type==&"triangle" and event.payload.cause==&"collapse").size()==1,"全星の撃破で中心を崩壊として一度だけ撃破し線を掃除する")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":parent,"cause":"shot"})
	ruler_tick(core,0.01)
	check(parts.all(func(row): return dolphin_enemy(core,row.id).dead) and core.hazards_snapshot().is_empty(),"親の途中撃破で残った3星と軌跡を終了する")
	bridge.restore(pending.value)
	core.remove_enemy(parent)
	var replacement: int=core.spawn_enemy(&"triangle",target+Vector2(400,100),{})
	ruler_tick(core,0.01)
	check(replacement!=parent and parts.all(func(row): return dolphin_enemy(core,row.id).dead) and triangle_parts(core,replacement).size()==3 and core.hazards_snapshot().is_empty(),"親の先行削除と行再利用で旧星を新しい中心へ結び付けない")
	bridge.release_checkpoint(pending.value)
	session.free()
	return true
