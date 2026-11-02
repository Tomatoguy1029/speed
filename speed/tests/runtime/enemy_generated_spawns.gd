## 敵の技・構成員生成は通常出現の上限でも成立し、通常補充は止まる。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS

var passed := 0
var failed := 0
var mute_checks := false
var split_finished := false
var defender_finished := false
var crow_finished := false

func check(ok: bool, label: String) -> void:
	if mute_checks: return
	if ok: passed += 1
	else:
		failed += 1
		push_error("[enemy_generated_spawns] " + label)

func _ready() -> void:
	if "--cpp-crow" in OS.get_cmdline_user_args():
		mute_checks = "--cpp-crow-gather" in OS.get_cmdline_user_args()
		await check_cpp_crow()
		mute_checks = false
		check(crow_finished,"からす座の確認本体が最後まで進んだ")
		print("[cpp_crow] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-defender" in OS.get_cmdline_user_args():
		await check_cpp_defender()
		check(defender_finished,"守る雑魚の確認本体が最後まで進んだ")
		print("[cpp_defender] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-split" in OS.get_cmdline_user_args():
		mute_checks = "--cpp-split-priority" in OS.get_cmdline_user_args()
		await check_cpp_split()
		mute_checks = false
		check(split_finished,"分裂の確認本体が最後まで進んだ")
		print("[cpp_split] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	await check_cpp_crow()
	print("[enemy_generated_spawns] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func split_entity(core,id: int,motion := false) -> Dictionary:
	for item: Dictionary in (core.enemy_motion_snapshot() if motion else core.enemies_snapshot()):
		if item.id==id: return item
	return {}

func split_children(core) -> Array:
	return core.enemies_snapshot().filter(func(e): return e.type=="splitling" and not e.dead)

func check_cpp_split() -> void:
	var cfg := ContentManager.base.duplicate(true) as GameConfig
	cfg.start_radius = 1200.0
	cfg.planet_radius = 0.0
	cfg.world_tick_div = 1
	cfg.spawn_total_cap = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 95
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["splitter","drifter"])
	var definition := load("res://data/enemies/splitter.tres").duplicate(true) as EnemyDef
	definition.params.bud_interval = 0.1
	definition.params.max_buds = 2
	var output := "res://.content/dev/run_split"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"分裂と親の先行退場".sha256_text(),{&"splitter":definition})
	check(built==OK,"分裂の編集値と分裂体の資源を生成する")
	if built!=OK: return
	var path := output.path_join("stage_95.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":955},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"親と分裂体の通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var at := target+Vector2(220,0)
	var parent: int = core.spawn_enemy(&"splitter",at,{"facing":0.0,"attack_priority":4.0})
	core.set_enemy_motion(parent,{"held":true})
	core.step(0.1)
	check(split_children(core).is_empty() and split_entity(core,parent,true).bud_t==0.0,"保持中は芽の時計を止める")
	core.set_enemy_motion(parent,{"held":false,"stone":0.1})
	core.step(0.1)
	check(split_children(core).is_empty() and split_entity(core,parent,true).bud_t==0.0,"石化中は芽を出さない")
	core.set_enemy_motion(parent,{"slash_hold":true})
	core.step(0.1)
	check(split_entity(core,parent,true).bud_t==0.0,"斬撃保持中も芽の時計を進めない")
	core.set_enemy_motion(parent,{"slash_hold":false})
	var saved: Dictionary = bridge.checkpoint()
	core.step(0.1)
	var children := split_children(core)
	var angle := float(parent)*2.39996322973
	var radius: float = split_entity(core,parent).radius
	var expected := at+Vector2.from_angle(angle)*radius*1.2
	check(children.size()==1 and Vector2(children[0].pos[0],children[0].pos[1]).is_equal_approx(expected) and is_equal_approx(Vector2(children[0].vel[0],children[0].vel[1]).length(),160.0) and split_entity(core,children[0].id,true).age==0.0,"芽を同じ角度と速度で生成しその更新では行動させない")
	var future: Array = core.enemies_snapshot()
	check(bridge.restore(saved.value).ok,"途中の芽の数と時間を値から復帰する")
	core.set_motion_context(target,target,Vector2(640,360))
	core.step(0.1)
	check(core.enemies_snapshot()==future,"途中復帰から同じ個体ID・位置の分裂へ進む")
	core.step(0.1)
	core.step(0.1)
	check(split_children(core).size()==2 and split_entity(core,parent,true).buds==2,"生存中の分裂は編集した上限で止まる")
	var view: Dictionary = bridge.read_render(Rect2(target-Vector2(700,400),Vector2(1400,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(presentation.frame_view.apply_frame(view) and view.batches.any(func(b): return b.ids.has(parent)) and view.batches.any(func(b): return b.ids.has(children[0].id)),"親と分裂体の画像を通常表示へ渡す")
	var frame: Dictionary = bridge.read_frame().value
	check(frame.events.filter(func(e): return e.type==&"bud").size()==2,"芽を出した二回の出来事を表示へ渡す")
	presentation.frame_view.receive_frame(frame)
	presentation.frame_view.update_effects(frame,0.0)
	check(presentation.frame_view._rings.size()>=2,"芽の輪と粒子を通常画面へ表示する")
	await get_tree().process_frame
	var before: int = split_children(core).size()
	var body: Dictionary = split_entity(core,parent)
	var killed: Dictionary = bridge.command("dev_kill",{"entity_id":parent,"cause":"bullet"})
	check(killed.ok and killed.value.killed and split_children(core).size()==before,"撃破時は分裂を予約して現在の反復へ追加しない")
	var pending: Dictionary = bridge.checkpoint()
	check(pending.ok,"親の死亡後の分裂予約を保持する")
	bridge.command("dev_retreat",{"entity_id":parent})
	var replacement: int = core.spawn_enemy(&"splitter",at,{"attack_priority":9.0})
	core.set_enemy_motion(replacement,{"held":true})
	check(split_entity(core,replacement,true).buds==0 and split_entity(core,replacement,true).bud_t==0.0,"親の行を再利用しても芽の数と時計を持ち越さない")
	core.step(0.01)
	children = split_children(core)
	check(children.size()==before+2,"親を先に消しても値で保持した撃破分裂を一度だけ生成する")
	var newborns: Array = children.filter(func(e): return split_entity(core,e.id,true).age==0.0)
	check(newborns.size()==2 and newborns.all(func(e): return is_equal_approx(Vector2(e.vel[0],e.vel[1]).length(),420.0) and split_entity(core,e.id,true).knock_t==0.5),"撃破分裂の速度と吹き飛び保護を編集値から引き継ぐ")
	var was_muted := mute_checks
	mute_checks = false
	check(newborns.all(func(e): return split_entity(core,e.id,true).guard==0.5 and split_entity(core,e.id,true).hit_cd==0.35 and split_entity(core,e.id,true).attack_priority==4.0),"死亡時に確定した保護・接触待ち・優先度を子へ渡す")
	mute_checks = was_muted
	var guarded: Dictionary = bridge.command("dev_damage",{"entity_id":newborns[0].id,"amount":10000.0,"cause":"bullet"})
	check(guarded.ok and guarded.value.reason=="guard","分裂直後の子は設定した保護時間で守る")
	core.step(0.01)
	check(split_children(core).size()==before+2,"予約済み分裂を二度実行しない")
	check(bridge.restore(pending.value).ok,"死亡後の分裂予約も途中復帰する")
	core.set_motion_context(target,target,Vector2(640,360))
	core.step(0.01)
	check(split_children(core).size()==before+2,"復帰後も死亡分裂を一度だけ出す")
	var interrupted: int = core.spawn_enemy(&"splitter",at,{})
	bridge.command("dev_kill",{"entity_id":interrupted,"cause":"bullet"})
	core.step(0.01)
	check(split_children(core).size()==before+4,"芽が育つ前の撃破でも死亡分裂を保つ")
	bridge.release_checkpoint(saved.value)
	bridge.release_checkpoint(pending.value)
	split_finished = true
	session.free()

func defender_step(bridge) -> void:
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)}).ok,"守る雑魚を通常Runnerで進める")

func check_cpp_defender() -> void:
	var cfg := ContentManager.base.duplicate(true) as GameConfig
	cfg.start_radius = 1200.0
	cfg.planet_radius = 0.0
	cfg.world_tick_div = 1
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 97
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter","defender","hydra_bite"])
	var strong := load("res://data/enemies/drifter.tres").duplicate(true) as EnemyDef
	strong.rank = 3
	strong.speed = 0.0
	var part := load("res://data/enemies/hydra_bite.tres").duplicate(true) as EnemyDef
	part.rank = 5
	var output := "res://.content/dev/run_defender"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"守備の並びと相手の喪失".sha256_text(),{&"drifter":strong,&"hydra_bite":part})
	check(built==OK,"守備と噛みつきの編集値・資源を生成する")
	if built!=OK: return
	var path := output.path_join("stage_97.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":977},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"守備と噛みつきのある通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	defender_step(bridge)
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var guarded: int = core.spawn_enemy(&"drifter",target+Vector2(400,0),{})
	var held: int = core.spawn_enemy(&"drifter",target+Vector2(250,0),{})
	core.set_enemy_motion(held,{"held":true})
	var child: int = bridge.command("dev_spawn_part",{"parent_id":guarded,"definition_id":"hydra_bite","position":target+Vector2(230,0)}).value
	var ids: Array[int] = []
	for y in [-42,0,42]: ids.append(core.spawn_enemy(&"defender",target+Vector2(250,y),{"facing":PI}))
	bridge.command("dev_retreat",{"entity_id":ids[1]})
	var reused: int = core.spawn_enemy(&"defender",target+Vector2(250,0),{"facing":PI})
	ids = [ids[0],ids[2],reused]
	core.step(0.1)
	var radius: float = split_entity(core,ids[0]).radius
	var spacing := maxf(42.0,radius*2.0)
	var offset := minf(split_entity(core,guarded).radius+radius+90.0,200.0)
	for k in ids.size():
		var actual := split_entity(core,ids[k],true)
		var expected := target+Vector2(400.0-offset,-(k-1)*spacing)
		check(actual.guard_target_id==guarded and actual.guard_goal.is_equal_approx(expected),"保持中の相手・部位を除き、再利用した行も個体ID順の列へ割り当てる")
		check(actual.mode==0 and actual.timer==0.0 and actual.charge==0.0,"持ち場へ進む間は噛みつきを休む")
	var boosted: int = ids[0]
	var until: float = core.inspect().world_time+0.15
	check(bridge.command("dev_defender_boost",{"entity_id":boosted,"speed":350.0,"wobble":20.0,"until":until,"phase":0.3}).ok,"個体へ世界秒の速度と揺れを指示する")
	core.set_enemy_motion(boosted,{"vel":Vector2.ZERO})
	var saved: Dictionary = bridge.checkpoint()
	var before: Dictionary = split_entity(core,boosted)
	var at := Vector2(before.pos[0],before.pos[1])
	core.step(0.1)
	var boosted_state := split_entity(core,boosted,true)
	var now: float = core.inspect().world_time
	var goal: Vector2 = boosted_state.guard_goal+Vector2(sin(now*1.3+0.3),cos(now*1.1+0.3))*20.0
	var speed := 350.0*minf(at.distance_to(goal)/60.0,1.0)
	var expected_velocity := (goal-at).normalized()*speed*0.25
	var actual_body := split_entity(core,boosted)
	check(Vector2(actual_body.vel[0],actual_body.vel[1]).is_equal_approx(expected_velocity) and boosted_state.boost_active,"世界時計の位相と編集値の加速で整列する")
	var future: Array = core.enemies_snapshot()
	check(bridge.restore(saved.value).ok,"整列途中と有効な速度指示を値から復帰する")
	core.set_motion_context(target,target,Vector2(640,360))
	core.step(0.1)
	check(core.enemies_snapshot()==future,"復帰後も持ち場を再構成して同じ位置へ進む")
	core.step(0.1)
	check(not split_entity(core,boosted,true).boost_active,"期限が過ぎた速度指示を外す")
	core.set_enemy_motion(boosted,{"held":true})
	var frozen: Dictionary = split_entity(core,boosted)
	core.step(0.1)
	check(split_entity(core,boosted)==frozen,"保持中の守る雑魚を整列で動かさない")
	core.set_enemy_motion(boosted,{"held":false,"slash_hold":true})
	core.step(0.1)
	check(Vector2(split_entity(core,boosted).vel[0],split_entity(core,boosted).vel[1])==Vector2.ZERO,"斬撃保持中は整列の速度を止める")
	core.set_enemy_motion(boosted,{"slash_hold":false})
	check(bridge.command("dev_defender_clear_boost",{"entity_id":boosted}).ok,"ボス側から速度指示を明示解除できる")
	bridge.command("dev_retreat",{"entity_id":guarded})
	var replacement: int = core.spawn_enemy(&"drifter",target+Vector2(2000,0),{})
	core.step(0.01)
	check(split_entity(core,boosted,true).guard_target_id==0 and replacement!=guarded,"守る相手の行を再利用しても古い相手を守り続けない")
	for id in ids.slice(1): bridge.command("dev_retreat",{"entity_id":id})
	bridge.command("dev_relocate",{"entity_id":boosted,"position":target+Vector2(30,0)})
	core.set_enemy_motion(boosted,{"facing":PI,"vel":Vector2.ZERO})
	defender_step(bridge)
	check(split_entity(core,boosted,true).mode==1,"守る相手がいないと通常Runnerで噛みつきの予告へ入る")
	bridge.command("dev_kill",{"entity_id":boosted,"cause":"bullet"})
	core.step(0.4)
	check(core.hazards_snapshot().is_empty(),"予告の途中撃破では噛みつきを出さない")
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	var attacker: int = core.spawn_enemy(&"defender",target+Vector2(30,0),{"facing":PI,"attack_group":123,"attack_managed":true,"attack_value":1.0})
	core.step(0.01)
	check(split_entity(core,attacker,true).mode==0 and not core.attack_budget_snapshot().waiting.is_empty(),"相手がいないときの噛みつきは攻撃予算を待つ")
	core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	core.advance_attack_budget(core.inspect().world_time)
	core.step(0.01)
	core.step(0.15)
	check(split_entity(core,attacker,true).mode==1 and is_equal_approx(split_entity(core,attacker,true).charge,0.5),"予算が空いたら編集値の予告を進める")
	var render: Dictionary = bridge.read_render(Rect2(target-Vector2(700,400),Vector2(1400,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(render.batches.any(func(b): return b.ids.has(attacker) and b.get("gunner",PackedFloat32Array()).size()==5) and presentation.frame_view.apply_frame(render),"本体と噛みつきの予告光を通常表示へ渡す")
	await get_tree().process_frame
	core.step(0.15)
	var bites: Array = core.hazards_snapshot()
	check(bites.size()==1 and bites[0].kind==1 and bites[0].style==3 and bites[0].radius==26.0 and split_entity(core,attacker,true).mode==3,"編集値の噛みつきの円を一つ生成して回復へ入る")
	render = bridge.read_render(Rect2(target-Vector2(700,400),Vector2(1400,800))).value
	check(render.shapes.any(func(shape): return shape.get("zone_style",-1)==3) and presentation.frame_view.apply_frame(render),"守る雑魚の噛みつきを共通のあごの輪で表示する")
	await get_tree().process_frame
	var hp: float = core.ship_snapshot().ship_hp
	core.step_hazards(0.01)
	var hurt: float = core.ship_snapshot().ship_hp
	core.step_hazards(0.01)
	check(hurt<hp and core.ship_snapshot().ship_hp==hurt,"噛みつきが機体に一度だけ命中する")
	bridge.command("dev_kill",{"entity_id":attacker,"cause":"bullet"})
	check(core.hazards_snapshot().size()==1,"発生後の噛みつきは発生元を失っても自然寿命まで残る")
	core.step_hazards(0.3)
	core.advance_attack_budget(core.inspect().world_time+2.0)
	check(core.hazards_snapshot().is_empty() and core.attack_budget_snapshot().used==0.0,"自然終了で噛みつきと攻撃予算を解放する")
	bridge.command("dev_retreat",{"entity_id":attacker})
	var fresh: int = core.spawn_enemy(&"defender",target+Vector2(100,0),{})
	check(not split_entity(core,fresh,true).boost_active and split_entity(core,fresh,true).guard_target_id==0,"死亡した行を再利用しても速度指示と持ち場を残さない")
	bridge.release_checkpoint(saved.value)
	defender_finished = true
	session.free()

func crow_gem(bridge,at: Vector2,kind: int) -> int:
	var result: Dictionary = bridge.command("dev_drop_crystal",{"position":at,"kind":kind})
	check(result.ok,"からす座の回収対象の結晶を供給する")
	return int(result.value)

func crow_ground(core,id: int) -> Dictionary:
	for gem: Dictionary in core.pickups_snapshot().gems:
		if gem.id==id: return gem
	return {}

func check_cpp_crow() -> void:
	var cfg := ContentManager.base.duplicate(true) as GameConfig
	cfg.start_radius = 1200.0
	cfg.planet_radius = 0.0
	cfg.world_tick_div = 1
	cfg.gem_max = 100
	cfg.strong_gold_chance = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var definition := load("res://data/enemies/crow.tres").duplicate(true) as EnemyDef
	definition.params.aim_spread = 0.0
	definition.xp_reward_counts = PackedInt32Array([1,0,0])
	var stage := RuntimeStage.new()
	stage.index = 96
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["crow"])
	var output := "res://.content/dev/run_crow"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"からす座の群れと結晶運搬".sha256_text(),{&"crow":definition})
	check(built==OK,"群れ・回収・退場の編集値と資源を生成する")
	if built!=OK: return
	var path := output.path_join("stage_96.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":966},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"からす座の本体と束の通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	defender_step(bridge)
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	var at := target-Vector2(500,0)
	var leader: int = core.spawn_enemy(&"crow",at,{"facing":0.0,"attack_priority":4.0})
	var flock: Array = core.enemies_snapshot().filter(func(e): return e.type=="crow")
	var offsets := [Vector2.ZERO,Vector2(-1,-1.1),Vector2(-1.1,1),Vector2(-2.1,0.2)]
	check(flock.size()==4,"通常の生成入口から四羽の群れを作る")
	for k in flock.size():
		var e: Dictionary = flock[k]
		check(Vector2(e.pos[0],e.pos[1]).is_equal_approx(at+offsets[k]*56.0) and e.facing==0.0 and split_entity(core,e.id,true).mode==2 and split_entity(core,e.id,true).attack_priority==4.0,"四つの星の配置と同じ向き・優先度を子へ引き継ぐ")
	bridge.command("dev_retreat",{"entity_id":leader})
	core.step(0.1)
	check(core.attack_budget_snapshot().waiting.is_empty() and core.enemies_snapshot().filter(func(e): return e.type=="crow" and not e.dead).size()==3,"先頭を先に消しても仲間は攻撃枠を待たず独立して横断する")
	for e: Dictionary in flock.slice(1):
		var actual := split_entity(core,e.id)
		check(Vector2(actual.pos[0],actual.pos[1]).is_equal_approx(Vector2(e.pos[0],e.pos[1])+Vector2(15,0)),"群れの横断を機体の追跡へ変えない")
		bridge.command("dev_retreat",{"entity_id":e.id})
	at = target+Vector2(300,0)
	var carrier: int = core.spawn_enemy(&"crow",at,{"facing":0.0,"flock_member":true})
	var radius: float = split_entity(core,carrier).radius
	bridge.command("dev_pickup_rates",{"ship":0.0,"run":0.0})
	var pickup_ui: Dictionary = bridge.read_frame().value.ui
	var pulled_pos := target-Vector2(200,0)
	var pulled: int = crow_gem(bridge,pulled_pos,0)
	var separation: float = (pickup_ui.ship_radius+14.0+pickup_ui.xp_pickup_radius)*0.5
	bridge.command("dev_ship_motion",{"position":pulled_pos-Vector2(separation,0),"velocity":Vector2.ZERO})
	core.step_pickups(0.001)
	check(not crow_ground(core,pulled).is_empty() and crow_ground(core,pulled).pulled,"機体が吸い寄せ始めた結晶を用意する")
	var pulled_at: Vector2 = crow_ground(core,pulled).pos
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	bridge.command("dev_relocate",{"entity_id":carrier,"position":pulled_at+Vector2(radius*0.62,0)})
	core.set_enemy_motion(carrier,{"facing":0.0})
	core.step_pickups(0.001)
	check(not crow_ground(core,pulled).is_empty() and core.pickups_snapshot().cargo.is_empty(),"機体が吸い寄せている結晶は足元でも横取りしない")
	bridge.command("dev_collect_gems",{})
	bridge.command("dev_relocate",{"entity_id":carrier,"position":at})
	core.set_enemy_motion(carrier,{"facing":0.0})
	var feet := at-Vector2(radius*0.62,0)
	var ids: Array[int] = []
	for kind in 3: ids.append(crow_gem(bridge,feet+Vector2(-kind*10,(kind-1)*10),kind))
	var front: int = crow_gem(bridge,at+Vector2(radius*0.3+20,0),0)
	var side: int = crow_gem(bridge,at+Vector2(0,100),0)
	var behind: int = crow_gem(bridge,at-Vector2(140,0),0)
	var supplied: Dictionary = core.pickups_snapshot()
	var originals: Array = supplied.gems.filter(func(gem): return gem.id in ids)
	core.step_pickups(0.1)
	var carried: Dictionary = core.pickups_snapshot()
	var muted_before := mute_checks
	mute_checks = false
	check(carried.cargo.size()==1 and carried.cargo[0].crystals.size()==3 and carried.cargo[0].crystals.map(func(gem): return gem.id)==ids,"横から後ろの結晶を保存した個体IDごと運搬へ移す")
	check(not crow_ground(core,front).is_empty() and not crow_ground(core,side).is_empty() and not crow_ground(core,behind).is_empty(),"前方・横幅外・後ろの範囲外を回収しない")
	mute_checks = muted_before
	for original: Dictionary in originals:
		var stored: Dictionary = carried.cargo[0].crystals.filter(func(gem): return gem.id==original.id)[0]
		check(stored.kind==original.kind and stored.base_xp==original.base_xp and stored.origin==original.origin,"色・実保持経験値・出所を保存し直さず保つ")
	check(carried.xp_statistics.supplied==supplied.xp_statistics.supplied,"運搬を新しい経験値の供給へ数えない")
	var moving: int = crow_gem(bridge,at+Vector2(-90,65),0)
	var from: Vector2 = crow_ground(core,moving).pos
	core.step_pickups(0.01)
	check(is_equal_approx(crow_ground(core,moving).pos.distance_to(from),9.0),"回収まで離れた結晶は設定速度で足元へ進める")
	var held_gem: int = crow_gem(bridge,feet,0)
	core.set_enemy_motion(carrier,{"held":true})
	core.step_pickups(0.02)
	mute_checks = false
	check(crow_ground(core,held_gem).is_empty() and split_entity(core,carrier,true).buds==4,"保持中も現行と同じ順で結晶の回収を続ける")
	mute_checks = muted_before
	core.set_enemy_motion(carrier,{"held":false})
	var render: Dictionary = bridge.read_render(Rect2(target-Vector2(700,400),Vector2(1400,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(render.crows.values.size()==6 and render.crows.values[5]==4.0 and render.crows.time==core.inspect().world_time and presentation.frame_view.apply_frame(render),"運搬表から束の量と個数を求め共通描画へ渡す")
	await get_tree().process_frame
	var saved: Dictionary = bridge.checkpoint()
	var pending: Dictionary = core.pickups_snapshot()
	bridge.command("dev_kill",{"entity_id":carrier,"cause":"bullet"})
	var dropped: Dictionary = core.pickups_snapshot()
	check(dropped.cargo.is_empty(),"撃破時は運搬表を一度だけ空にする")
	for original: Dictionary in pending.cargo[0].crystals:
		var returned := crow_ground(core,original.id)
		check(not returned.is_empty() and returned.kind==original.kind and returned.base_xp==original.base_xp and returned.origin==original.origin,"撃破で保存した結晶を同じ意味のまま地面へ戻す")
	check(bridge.restore(saved.value).ok and core.pickups_snapshot()==pending,"運搬途中の全結晶と個体の状態へ値から復帰する")
	core.set_motion_context(target,target,Vector2(640,360))
	bridge.command("dev_relocate",{"entity_id":carrier,"position":target+Vector2(1160,0)})
	core.set_enemy_motion(carrier,{"facing":PI})
	core.step(0.01)
	check(not split_entity(core,carrier).dead,"画面外でも内側へ進むからす座を退場させない")
	core.set_enemy_motion(carrier,{"facing":0.0})
	var kills: int = bridge.read_frame().value.ui.kills
	var ground: Array = core.pickups_snapshot().gems
	core.step(0.01)
	check(split_entity(core,carrier).dead and bridge.read_frame().value.ui.kills==kills and core.pickups_snapshot().gems==ground and core.pickups_snapshot().cargo.is_empty(),"画面外へ離れると運搬分を失い撃破報酬を出さず退場する")
	var lost: Array = core.pickups_snapshot().xp_statistics.lost
	check(lost.reduce(func(sum,kind): return sum+kind.count,0)==4,"退場で運搬していた四個だけを損失へ数える")
	bridge.command("dev_retreat",{"entity_id":carrier})
	var fresh: int = core.spawn_enemy(&"crow",at,{"facing":0.0,"flock_member":true})
	check(split_entity(core,fresh,true).carry==0.0 and split_entity(core,fresh,true).buds==0,"行を再利用しても運搬量と個数を持ち越さない")
	bridge.release_checkpoint(saved.value)
	crow_finished = true
	session.free()
