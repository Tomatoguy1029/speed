extends Node
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void:
	if "--cpp-entrance-click" in OS.get_cmdline_user_args():
		call_deferred("entrance_click")
		return
	if "--cpp-draco-finale" in OS.get_cmdline_user_args():
		call_deferred("native_finale")
		return
	if "--cpp-draco-cycle" in OS.get_cmdline_user_args():
		call_deferred("native_cycle")
		return
	if "--cpp-draco-intro" in OS.get_cmdline_user_args() or "--cpp-draco-intro-position" in OS.get_cmdline_user_args():
		call_deferred("native_intro")
		return
	call_deferred("native_intro")

func native_intro() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	var package: Dictionary = builder.boss_body_package(load("res://data/bosses/draco.tres"),cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":188,"mode":1,"stage_id":"B_draco_intro","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"登場の編集値を生成データから読む")
	if not configured.ok: print(configured);get_tree().quit(1);return
	bridge.start(1605,{"position":Vector2(180,260),"lab_mode":true})
	bridge.subscribe("確認",func(_frame):return true)
	bridge._core.set_motion_context(Vector2(180,260),Vector2(60,180),Vector2(800,450))
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(180,260)}})
	var boss := 0
	var position_only := "--cpp-draco-intro-position" in OS.get_cmdline_user_args()
	if not position_only:
		for angle in [0.0,PI*0.5,PI,-PI*0.5]:
			var initial := Vector2(180,260)-Vector2.from_angle(angle)*700.0
			boss = bridge.command("dev_spawn_boss",{"definition":1,"position":initial,"entrance":false}).value
			bridge.command("dev_edit",{"kind":"camera","payload":{"center":Vector2(60,180),"size":Vector2(960,540),"zoom":0.6,"bars":0.0}})
			bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"begin"})
			bridge._core.step(1.0)
			var body: Dictionary = bridge.command("dev_boss_body_state").value[-1]
			check(absf(float(body.facing)-PI*0.5)<=PI*0.5*1e-9,"登場方向を四方から同じ対面構図に揃える")
			bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"cancel"})
			var frame: Dictionary = bridge.read_frame().value
			check(frame.camera.center.distance_to(Vector2(60,180))<=1e-4 and absf(float(frame.camera.zoom)-0.6)<=1e-9,"中断はカメラ中心と倍率を復元する")
			check(frame.camera.half.distance_to(Vector2(800,450))<=1e-4,"中断は入力用の表示範囲を返す")
			check(bridge.command("dev_boss_body_state").value[-1].position.distance_to(initial)<=1e-4,"中断は本体位置を戻す")
			check(not frame.ui.controls_locked and not frame.ui.cinematic_camera and frame.ui.cinematic_bars==0.0,"中断は操作とHUDを返す")
			bridge.command("dev_cancel_boss",{"entity_id":boss})
		boss = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(-500,-100),"entrance":true}).value
		bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"skip"})
		bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"skip"})
		check(bridge.command("dev_boss_body_state").value[-1].mode==1 and bridge.command("dev_boss_body_state").value[-1].guard==0.0 and not bridge.read_frame().value.ui.controls_locked,"二重スキップでも戦闘へ返す")
	if position_only: boss = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(-500,-100),"entrance":false}).value
	for ship_at in [Vector2(0,-9900),Vector2(9000,2500),Vector2(1200,1200)]:
		check(bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":ship_at}}).ok,"安全配置の自機位置を設定する")
		var planet: Vector2 = ship_at+Vector2.UP*430.0
		check(bridge.command("dev_edit",{"kind":"planet","payload":{"position":planet,"radius":300.0}}).ok,"安全配置の天体を置く")
		bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"begin"})
		bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"skip"})
		var body: Dictionary = bridge.command("dev_boss_body_state").value[-1]
		var head: Vector2 = body.position
		var margin: float = body.radius+40.0
		check(head.length()<=cfg.field_radius-margin+0.1 and head.distance_to(planet)>=300.0+margin-0.1,"頭を境界と天体から離す")
		check(bridge._core.ship_snapshot().ship_pos==ship_at,"対面のために自機を瞬間移動しない")
	if position_only:
		bridge.dispose()
		print("[B_draco_intro_position] failures=",failures)
		get_tree().quit(1 if failures else 0)
		return
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(180,260)}})
	bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"begin"})
	bridge._core.step(3.4)
	var scope := ContentResourceScope.new()
	for visual: Dictionary in package.visuals:
		if not visual.path.is_empty(): scope.provide(visual.path,load(visual.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value),"裂け目と出現を既存の描画経路へ渡す")
	await get_tree().process_frame
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"登場途中の値状態を保持する")
	bridge._core.step(1.0)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[-1]
	check(bridge.restore(held.value).ok,"登場途中を復帰する")
	bridge._core.step(1.0)
	check(bridge.command("dev_boss_body_state").value[-1]==expected,"復帰後も同じ位置・段階・時刻になる")
	bridge.release_checkpoint(held.value)
	bridge._core.step(10.0)
	check(not bridge.command("dev_boss_body_state").value[-1].intro.active and bridge.command("dev_boss_body_state").value[-1].mode==1,"登場は自然終了で戦闘へ渡す")
	view.free();bridge.dispose()
	print("[B_draco_intro] failures=",failures)
	get_tree().quit(1 if failures else 0)

## 初回生成・通常採集・中断を同じ論理画面で確認する。
func native_cycle() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	var definition: BossDef = load("res://data/bosses/draco.tres").duplicate(true)
	definition.params.picaro_candidates = [&"biter"]
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var source: Dictionary = builder.chase_package(load("res://data/enemies/biter.tres"),cfg)
	var row: Dictionary = source.records.EnemyRecord[0].duplicate(true)
	row.id=2;row.visual_id=package.records.ResourceKey.size()+1
	package.records.EnemyRecord.append(row)
	package.records.StringEntry.append({"id":2,"value":"biter"})
	package.records.DefinitionIndex.append({"id":2,"enemy":2})
	package.records.PopulationType.append({"id":2,"enemy":2,"rank":1,"maximum":10,"ranged":false})
	for record: Dictionary in builder.Schema.SCHEMA.records:
		if record.fields[0].get("ref","")!="EnemyRecord": continue
		for original: Dictionary in source.records[record.name]:
			var item := original.duplicate(true);item.id=2;package.records[record.name].append(item)
	var hull: Dictionary = source.records.FriendHullLook[0].duplicate(true)
	hull.id=2;hull.enemy=2;package.records.FriendHullLook.append(hull)
	var visual: Dictionary = source.visuals[5].duplicate(true)
	visual.id=row.visual_id
	package.visuals.append(visual);package.records.ResourceKey.append({"id":visual.id,"role":visual.role})
	check(builder.append_draco_cycle(package.records,definition,1)==OK,"通常生成と同じ候補の順序・敵参照を作る")
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":189,"mode":1,"stage_id":"B_draco_cycle","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"採集・再生成の型付き編集値を読む")
	if not configured.ok: print(configured);get_tree().quit(1);return
	bridge.start(1605,{"position":Vector2(180,260),"lab_mode":true})
	bridge.subscribe("確認",func(_frame):return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(180,260)}})
	bridge._core.set_motion_context(Vector2(180,260),Vector2(60,180),Vector2(800,450))
	bridge.command("dev_edit",{"kind":"camera","payload":{"center":Vector2(60,180),"size":Vector2(960,540),"zoom":0.6,"bars":0.0}})
	var boss: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(-500,-100),"entrance":false}).value
	check(bridge.command("dev_draco_cycle",{"entity_id":boss,"operation":"initial"}).ok,"初回生成を始める")
	for frame in 1000:
		bridge._core.step(1.0/60.0)
		if bridge.command("dev_boss_body_state").value[0].cycle.stage==0:break
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.cycle.stage==0 and body.mode==1 and body.guard==0.0 and body.picaro.size()==3,"初回生成で3体を作り本体戦へ戻る")
	var frame: Dictionary = bridge.read_frame().value
	check(not frame.ui.controls_locked and not frame.ui.cinematic_camera and not frame.ui.encounter_protected,"初回のロックと保護を全て解放する")
	bridge.command("dev_draco_cycle",{"entity_id":boss,"operation":"deep"})
	check(not bridge.read_frame().value.ui.controls_locked and bridge.read_frame().value.ui.cinematic_bars==0.0,"通常採集では操作を止めない")
	for tick in 90: bridge._core.step(1.0/60.0)
	body=bridge.command("dev_boss_body_state").value[0]
	var held: Dictionary = bridge.checkpoint();check(held.ok,"採集中の段階・遠近・所有を保持する")
	bridge._core.step(0.4)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(bridge.restore(held.value).ok,"採集中を復元する")
	bridge._core.step(0.4)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"復元後の位置・判定・時刻を保つ")
	bridge.release_checkpoint(held.value)
	bridge.command("dev_draco_cycle",{"entity_id":boss,"operation":"cancel"})
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.perspective_scale==1.0 and body.alpha==1.0 and body.guard==0.0 and body.cycle.stage==0,"採集中断は遠近・透明度・保護を残さない")
	var scope := ContentResourceScope.new()
	for item: Dictionary in package.visuals:
		if not item.path.is_empty(): scope.provide(item.path,load(item.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary]=[];entries.assign(package.visuals);view.setup(scope,entries,cfg.character_scale)
	bridge.command("dev_draco_cycle",{"entity_id":boss,"operation":"deep"});bridge._core.step(0.5)
	check(view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value),"採集粒と遠近はGodotが状態を読むだけで表示する")
	await get_tree().process_frame
	bridge.command("dev_cancel_boss",{"entity_id":boss})
	check(not bridge.read_frame().value.ui.cinematic_camera and not bridge.read_frame().value.ui.controls_locked,"本体中断は演出の所有状態を返す")
	view.free();bridge.dispose()
	print("[B_draco_cycle] failures=",failures)
	get_tree().quit(1 if failures else 0)

## 最終決着の指定された状態・中断・構図・HUDを同じラン入口で確認する。
func finale_fixture(size:=Vector2(1280,720),facing:=INF,move: BossTechnique=null) -> Dictionary:
	var ship_at:=Vector2(-300,200) if is_inf(facing) else Vector2(430,-220)+Vector2.from_angle(facing)*700.0
	var builder=load("res://tools/content/build_run_content.gd")
	var cfg: GameConfig=load("res://data/config.tres").duplicate(true)
	var package: Dictionary=builder.boss_body_package(load("res://data/bosses/draco.tres"),cfg) if move==null else builder.draco_technique_package(load("res://data/bosses/draco.tres"),move,cfg)
	var bridge=load("res://scripts/runtime/run_bridge.gd").new()
	var setup: Dictionary=bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":226,"mode":1,"stage_id":"B_draco_finale","profile":{},"settings":{"hitstop":false}})
	check(setup.ok,"決着の固定値と型付き編集値を生成して読む")
	if not setup.ok:return {}
	bridge.start(226,{"position":ship_at,"lab_mode":true})
	var events: Array=[]
	bridge.subscribe("決着確認",func(frame):events.append_array(frame.events);return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"position":ship_at,"invincible":false}})
	var boss: int=bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(430,-220),"entrance":false}).value
	bridge.command("dev_edit",{"kind":"camera","payload":{"center":ship_at,"size":size,"zoom":minf(size.x,size.y)/1100.0,"bars":0.0}})
	bridge._core.set_motion_context(ship_at,ship_at,size/(2.0*(minf(size.x,size.y)/1100.0)))
	return {"bridge":bridge,"boss":boss,"size":size,"events":events,"package":package}

func finale_body(f: Dictionary) -> Dictionary:
	return f.bridge.command("dev_boss_body_state").value[-1]

func finale_tick(f: Dictionary,intent: Intent=null) -> bool:
	if intent==null:intent=Intent.new()
	return f.bridge.step(1.0/120.0,f.bridge.pack_intent(intent),{"logical_size":f.size}).ok

func finale_to(f: Dictionary,target: String) -> bool:
	for tick in 4500:
		var body:=finale_body(f)
		if body.finale.stage==target:return true
		var input:=Intent.new()
		if body.finale.stage=="input":
			input.press=not body.finale.began;input.has_cursor=true;input.pen=Vector2(200,100);input.pen_release=body.finale.began
		if not finale_tick(f,input):return false
	return false

func native_finale() -> void:
	var group: String="all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--finale-group="):group=arg.get_slice("=",1)
	if group in ["all","motion","pose"]:native_finale_motion()
	if group in ["all","interrupt"]:native_finale_interrupt()
	if group in ["all","hud","render","entrance","bars"]:await native_finale_hud()
	if group in ["all","dedicated"]:native_finale_dedicated()
	if group in ["all","rifts"]:native_finale_rifts()
	print("[cpp_draco_finale] group=",group," failures=",failures)
	get_tree().quit(1 if failures else 0)

func native_finale_motion() -> void:
	var f:=finale_fixture()
	if f.is_empty():return
	check(f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"begin"}).ok,"本体の決着を型付き入口から始める")
	var before: Dictionary=f.bridge.read_lab().value
	var observed: Array[String]=[]
	var checkpoint_stages: Array[String]=[]
	for tick in 4500:
		var body:=finale_body(f)
		var current: String=body.finale.stage
		if not current in observed:observed.append(current)
		if not current in checkpoint_stages and current!="explode":
			var held: Dictionary=f.bridge.checkpoint()
			check(held.ok,"決着の段階を値保持する: "+current)
			if held.ok:
				check(finale_tick(f) and f.bridge.restore(held.value).ok,"決着の途中を保持した段階へ戻す: "+current)
				f.bridge.release_checkpoint(held.value)
			checkpoint_stages.append(current)
		if body.finale.completed:break
		var input:=Intent.new()
		if current=="input":input.press=not body.finale.began;input.has_cursor=true;input.pen=Vector2(200,100);input.pen_release=body.finale.began
		check(finale_tick(f,input),"実時間の決着更新が成功する")
		body=finale_body(f)
		if not body.finale.completed:
			check(f.bridge.read_lab().value.clock.time==before.clock.time and f.bridge.read_lab().value.clock.world_time==before.clock.world_time,"決着だけを実時間で進めランと戦闘の時計を止める")
	check(observed==["release","combine","pose","input","strikes","charge","flash","sight","explode"],"核解放から決着まで全9段階を通る")
	check((finale_body(f).finale.completed and f.bridge.read_frame().value.ui.draco_finish_done),"完走後に通常クリアへ渡す完了値を立てる")
	var count: int=f.events.filter(func(e):return e.type=="boss_defeated").size()
	finale_tick(f);finale_tick(f)
	check((count==1 and f.events.filter(func(e):return e.type=="boss_defeated").size()==1),"完了通知を二重に出さない")
	f.bridge.dispose()

func native_finale_interrupt() -> void:
	for target in ["release","combine","pose","input","strikes","charge","flash","sight"]:
		var f:=finale_fixture()
		if f.is_empty():return
		f.bridge._core.step_ship(0.05,0.05,{"has_cursor":true,"cursor":Vector2(1000,200)})
		var ship: Dictionary=f.bridge._core.ship_snapshot()
		var before: Dictionary=f.bridge.read_frame().value
		check(ship.ship_vel.length()>0.0,"中断確認を動いている機体から始める")
		f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"begin"})
		check(finale_to(f,target),"中断する段階まで到達する: "+target)
		if target in ["strikes","charge"]:
			for tick in 14:finale_tick(f)
			check(f.bridge._core.ship_snapshot().ship_pos!=ship.ship_pos,"連撃の実移動を経て中断する: "+target)
		f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"cancel"})
		var after: Dictionary=f.bridge._core.ship_snapshot()
		var camera: Dictionary=f.bridge.read_frame().value.camera
		check(after.ship_pos==ship.ship_pos and after.ship_vel==ship.ship_vel,"中断は実際の機体位置と速度を返す: "+target)
		check(camera==before.camera and not f.bridge.read_frame().value.ui.controls_locked and not f.bridge.read_frame().value.ui.cinematic_camera and float(f.bridge.read_frame().value.ui.world_scale)>0.0,"中断はカメラ/入力/世界の速さを返す: "+target)
		f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"begin"});f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"cancel"})
		check(f.bridge._core.ship_snapshot().ship_pos==ship.ship_pos and f.bridge._core.ship_snapshot().ship_vel==ship.ship_vel,"再生と再中断で基準をずらさない")
		f.bridge.dispose()
	var f:=finale_fixture()
	f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"begin"});check(finale_to(f,"input"),"自由描画へ進む")
	for tick in 600:finale_tick(f)
	check(finale_body(f).finale.stage=="input" and not f.bridge.read_frame().value.ui.controls_locked,"入力を待つ間に自動で確定しない")
	for tick in 3000:
		var input:=Intent.new();input.has_cursor=true;input.pen=Vector2(tick*10,0);input.press=tick==0;finale_tick(f,input)
	check(finale_body(f).finale.stage=="input" and finale_body(f).finale.strokes.size()==3000,"長い筆跡を切り詰めず入力を待ち続ける")
	check(not f.bridge.command("skip_finish").ok,"通常決着のskipで最終自由入力を飛ばさない")
	f.bridge.dispose()

func native_finale_hud() -> void:
	if "--finale-group=bars" in OS.get_cmdline_user_args():
		get_window().size=Vector2i(1280,720)
		await finale_hud_case(Vector2(1280,720),0.0)
		return
	var render_only: bool="--finale-group=render" in OS.get_cmdline_user_args() or "--finale-group=bars" in OS.get_cmdline_user_args()
	var entrance_only: bool="--finale-group=entrance" in OS.get_cmdline_user_args()
	if not render_only:finale_entrance_hud()
	if entrance_only:return
	for size in [Vector2(1280,720),Vector2(900,900),Vector2(720,1280)]:
		get_window().size=Vector2i(size)
		await get_tree().process_frame
		for angle in [0.0,PI*0.5,PI,-PI*0.5]:await finale_hud_case(size,angle)


func finale_entrance_hud() -> void:
	var f:=finale_fixture()
	if f.is_empty():return
	var hud=load("res://scripts/ui/hud.gd").new();hud.bridge=f.bridge;hud.size=f.size;add_child(hud)
	f.bridge.command("dev_draco_intro",{"entity_id":f.boss,"operation":"begin"})
	f.bridge._core.step(0.5);f.bridge.command("dev_boss_body_state")
	hud.apply_snapshot(f.bridge.read_frame().value.ui);hud._update_cpp_cinematic()
	check(hud._entrance_skip.visible and not hud._can_show_draw_button(true),"登場の明示skipと黒帯中の操作表示を保つ")
	f.bridge.command("skip_boss_entrance")
	check(not finale_body(f).intro.active,"登場skipで戦闘へ返す")
	hud.free();f.bridge.dispose()

func entrance_click() -> void:
	var f := finale_fixture()
	if f.is_empty(): get_tree().quit(1);return
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = f.bridge
	hud.size = get_viewport().get_visible_rect().size
	add_child(hud)
	f.bridge.command("dev_draco_intro",{"entity_id":f.boss,"operation":"begin"})
	f.bridge._core.step(0.5)
	f.bridge.command("dev_boss_body_state")
	hud.apply_snapshot(f.bridge.read_frame().value.ui)
	hud._update_cpp_cinematic()
	await get_tree().process_frame
	var button: Button = hud._entrance_skip
	check(button.is_visible_in_tree(),"登場スキップを正式HUDに表示する")
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		get_viewport().push_input(event,true)
	check(not finale_body(f).intro.active,"スキップの実クリックで登場を終える")
	check(f.bridge.read_frame().value.ui.input_enabled,"登場スキップ後に戦闘入力を戻す")
	hud.free()
	f.bridge.dispose()
	print("[登場スキップの実操作] 失敗=%d" % failures)
	get_tree().quit(1 if failures else 0)

func finale_hud_case(size: Vector2,angle: float) -> void:
	var f:=finale_fixture(size,angle)
	if f.is_empty():return
	var render_only: bool="--finale-group=render" in OS.get_cmdline_user_args() or "--finale-group=bars" in OS.get_cmdline_user_args()
	var layer:=CanvasLayer.new();add_child(layer)
	var hud=load("res://scripts/ui/hud.gd").new();hud.bridge=f.bridge;hud.size=size;layer.add_child(hud)
	var camera:=Camera2D.new();add_child(camera);camera.make_current()
	f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"begin"})
	var parent:=Node2D.new();add_child(parent)
	var display=load("res://scripts/render/bosses/draco.gd").new();parent.add_child(display)
	var visible_all:=true
	for tick in 900:
		finale_tick(f)
		var body:=finale_body(f);display.apply_frame(body)
		var frame: Dictionary=f.bridge.read_frame().value;camera.zoom=Vector2.ONE*float(frame.camera.zoom);camera.position=frame.camera.center
		if body.finale.stage=="combine" and float(body.finale.time)>0.6:
			for at in [frame.ui.ship.ship_pos]:
				var pixel: Vector2=(at-frame.camera.center)*float(frame.camera.zoom)+size*0.5
				if not Rect2(size*Vector2(0.04,0.12),size*Vector2(0.92,0.76)).has_point(pixel):visible_all=false
	hud.apply_snapshot(f.bridge.read_frame().value.ui);hud._update_cpp_cinematic()
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	check(render_only or visible_all,"構図は合体する機体を画面内へ収める: "+str(size))
	check(render_only or hud._cpp_ui.get("final_modules",[]).size()==4,"黒帯中も実際の4部品を武器欄へ渡す")
	check(display._parts.visible,"決着の点列と核/分裂を正式な表示へ渡す")
	if DisplayServer.get_name()!="headless":
		var image:=get_viewport().get_texture().get_image()
		if "--finale-group=bars" in OS.get_cmdline_user_args():
			var pixel:=image.get_pixel(image.get_width()/2,2)
			check(pixel.r+pixel.g+pixel.b<0.2,"黒帯を実際の画面へ描画する")
		image.save_png("/tmp/speed-draco-finale-%dx%d-%s.png"%[size.x,size.y,str(angle)])
	layer.free();camera.free();parent.free();f.bridge.dispose()

func native_finale_dedicated() -> void:
	var f:=finale_fixture()
	if f.is_empty():return
	f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"begin"})
	check(finale_to(f,"input"),"専用入力の待機へ進む")
	var input: Dictionary=f.bridge.pack_intent(Intent.new())
	input.finale_pressed=true;input.finale_pen=Vector2(200,100);input.pen=Vector2(-200,0)
	check(f.bridge.step(1.0/120.0,input,{"logical_size":f.size}).ok,"通常入力と独立した決着の押下を受ける")
	check(finale_body(f).finale.strokes[0]==Vector2(200,100),"専用入力の座標を筆跡へ渡す")
	input.finale_pressed=false;input.finale_released=true
	check(f.bridge.step(1.0/120.0,input,{"logical_size":f.size}).ok and finale_body(f).finale.stage=="strikes","専用解放で固定の決着へ進む")
	f.bridge.dispose()

func native_finale_rifts() -> void:
	var f:=finale_fixture(Vector2(1280,720),INF,load("res://data/bosses/draco_moves/rifts.tres"))
	if f.is_empty():return
	check(f.bridge.command("dev_boss_technique",{"entity_id":f.boss,"definition":1}).ok,"決着前の実在する裂け目を作る")
	var opened:=false
	for tick in 2400:
		f.bridge._core.step(1.0/120.0)
		if not finale_body(f).rift_walls.is_empty():opened=true;break
	check(opened,"決着へ渡す裂け目が実際に存在する")
	f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"begin"})
	check(int(finale_body(f).closing_walls)>0,"決着の開始で裂け目を修復へ渡す")
	var before: Dictionary=f.bridge.read_lab().value.clock
	for tick in 60:finale_tick(f)
	check(finale_body(f).rift_walls.is_empty() and f.bridge.read_lab().value.clock.world_time==before.world_time,"世界を止めた決着中も裂け目を実時間で修復する")
	f.bridge.dispose()
