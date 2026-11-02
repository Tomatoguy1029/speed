## 英雄の開始時・発見時・解放後の誘導だけを短時間確認する。
## Godot --headless --path speed res://tests/hero_guidance.tscn
extends Node

class BlockedField:
	extends FieldSystem
	func body_gap(_p: Vector2, _radius: float) -> float:
		return 0.0

var failed := 0

func _ready() -> void:
	if "--cpp-h00-view" in OS.get_cmdline_user_args():
		await _cpp_h00_view()
		return
	if "--cpp-h00" in OS.get_cmdline_user_args():
		_cpp_h00()
		return
	var cfg: GameConfig = load("res://data/config.tres")
	var s := RunState.new()
	var h := HeroSystem.new()
	var field := FieldSystem.new()
	var blocked := BlockedField.new()
	var enemies := EnemySystem.new()
	var combat := CombatSystem.new()
	var context := RunContext.new()
	context.state = s
	context.cfg = cfg
	context.field = field
	context.enemies = enemies
	context.combat = combat
	context.heroes = h
	combat.setup(context)
	h.ctx = context
	h.state = s
	h.cfg = cfg
	var def: HeroDef = load("res://data/heroes/perseus.tres")
	var spawn := Vector2(-cfg.start_radius, 0.0)
	s.ship_pos = spawn
	# 修正前は2548.552の距離に配置され、最初の更新で発見される。
	s.rng.seed = 5
	h._place(def)
	h.tick(0.01, 0.01)
	_check(not h.seen and not h.revealed() and s.landmarks.is_empty(), "start hides the unvisited hero")
	_check(_discoveries(s) == 0, "hidden hero emits no discovery")
	var center := h.center
	s.ship_pos = center + Vector2(cfg.hero_glow_range - 1.0, 0.0)
	h.tick(0.01, 0.01)
	_check(h.seen and h.revealed() and h.is_captive(), "passing nearby reveals the captive hero")
	_check(_discoveries(s) == 1, "proximity announces discovery once")
	h.tick(0.01, 0.01)
	_check(_discoveries(s) == 1, "remaining nearby does not repeat the notification")
	s.ship_pos = spawn
	h.tick(0.01, 0.01)
	_check(h.revealed() and h.is_captive(), "guidance persists after leaving")
	_check(_discoveries(s) == 1, "leaving and returning preserves the discovery count")
	h.lit.fill(1)
	h._free()
	_check(h.revealed() and not h.is_captive() and s.hero_power == def.id, "freed hero keeps its map point and stops edge guidance")
	h._place(def)
	_check(not h.revealed() and not h.seen, "next hero clears discovery")
	s.landmarks.append(Vector2(100, 100))
	h.tick(0.01, 0.01)
	_check(not h.revealed(), "one recovered landmark leaves the hero hidden")
	_check(_discoveries(s) == 1, "one landmark does not announce a hidden hero")
	s.landmarks.append(Vector2(-100, 100))
	h.tick(0.01, 0.01)
	_check(h.revealed() and h.is_captive(), "two recovered landmarks enable guidance without a visit")
	_check(_discoveries(s) == 2, "the next hero can announce discovery from two landmarks")
	s.ship_pos = h.center
	h.tick(0.01, 0.01)
	_check(_discoveries(s) == 2, "later proximity does not repeat landmark discovery")
	# 障害物との間隔が成立しない場合も、最後の近すぎる候補を採用しない。
	context.field = blocked
	for seed_value in [0, 5, 19]:
		s.rng.seed = seed_value
		h._place(def)
		h.tick(0.01, 0.01)
		_check(s.ship_pos.distance_to(h.center) > cfg.hero_glow_range and not h.revealed(), "attempt limit stays undiscovered (seed %d)" % seed_value)
	for system in [h, field, blocked, enemies, combat]:
		system.dispose()
	print("[hero-guidance] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else:
		print("[hero-guidance] PASS ", label)

func _discoveries(s: RunState) -> int:
	return s.events.filter(func(e): return e.type == &"hero_discovered").size()

var _cpp_events: Array = []
var _cpp_visuals: Array[Dictionary] = []
func _cpp_check_frame(bridge) -> Dictionary:
	var frame: Dictionary = bridge.read_frame()
	_check(frame.ok,"C++の英雄状態と通知が読める")
	var delivered: Dictionary = bridge.collect_frame()
	_check(delivered.ok and bridge.delivery_error.get("ok",true),"英雄通知を全購読先へ届ける")
	return frame.value.ui.hero if frame.ok else {}

func _cpp_fixture(lab := false,armor := -1.0):
	var cfg: GameConfig = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.landmark_first_window = Vector2(0,1)
	cfg.landmark_second_window = Vector2(0,1)
	var actor: EnemyDef = load("res://data/enemies/drifter.tres").duplicate(true)
	if armor>=0.0: actor.armor = armor
	actor.rank = 2
	actor.max_alive = 2
	actor.speed = 0.0
	var stage := RuntimeStage.new()
	stage.index = 2
	var phase := PhaseDef.new()
	phase.mix = {actor.id:1.0}
	stage.phases = [phase]
	var builder = load("res://tools/content/build_run_content.gd")
	var package: Dictionary = builder.chase_package(actor,cfg,stage)
	var records: Dictionary = package.records
	_cpp_visuals.assign(package.visuals)
	records.PopulationDefinition[0].active = true
	records.PopulationPhase = [{"id":1,"external_id":"hero","start":0.0,"pop_from":1.0,"pop_to":1.0,"rate":1.0,"xp_bonus":1.0,"surge_interval":1.0,"surge_pop":0.0,"surge_ranged":0.0,"surge_elite":0.0,"wave_interval":0.0,"attack_budget":0,"wave_type":0}]
	records.PopulationType = [{"id":1,"enemy":1,"rank":2.0,"maximum":2.0,"ranged":false}]
	records.PopulationMix = [{"id":1,"phase":1,"enemy":1,"weight":1.0}]
	var bytes: PackedByteArray = builder.Schema.write_content(records,"0".repeat(64).hex_decode())
	_check(not bytes.is_empty(),"星・線・時間窓をResourceから型付き生成する")
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":280,"mode":1,"stage_id":"2","profile":{},"settings":{"hitstop":false}})
	_check(configured.ok,"C++が英雄の生成定義を読む: %s" % configured)
	if not configured.ok: get_tree().quit(1); return bridge
	bridge.subscribe("hero-test",func(frame): _cpp_events.append_array(frame.events); return true)
	_check(bridge.start(5,{"lab_mode":lab}).ok,"英雄のランを開始する")
	return bridge

func _cpp_tick(bridge,dt := 0.0,time := 0.0) -> Dictionary:
	_check(bridge.command("dev_tick_heroes",{"dt":dt,"run_time":time}).ok,"英雄の指定時点を進める")
	return _cpp_check_frame(bridge)

func _cpp_h00() -> void:
	var bridge = _cpp_fixture()
	var h: Dictionary = _cpp_check_frame(bridge)
	_check(h.id==&"perseus" and not h.revealed and h.times==PackedFloat64Array([0,0]),"開始時は未発見で目印二枠の予定時刻を持つ")
	h = _cpp_tick(bridge)
	_check(h.carriers[0]>0 and h.carriers[1]>0 and h.carriers[0]!=h.carriers[1],"候補なしでも独立した二体を補充する")
	var first: int = h.carriers[0]
	var second: int = h.carriers[1]
	_check(bridge.command("dev_remove",{"entity_id":first}).ok,"撃破せず目印持ちを退場させる")
	h = _cpp_tick(bridge)
	_check(h.carriers[0]!=first and h.done[0]==0 and h.landmarks.is_empty(),"退場は回収せず同じ枠を補充する")
	_check(bridge.command("dev_kill",{"entity_id":h.carriers[0],"cause":"shot"}).ok,"目印を撃破して回収する")
	h = _cpp_tick(bridge)
	_check(h.done[0]==1 and h.done[1]==0 and h.landmarks.size()==1,"撃破はdoneを残し他枠を保持する")
	var held: Dictionary = bridge.checkpoint()
	_check(held.ok,"目印二枠を途中保持できる")
	_check(bridge.command("dev_kill",{"entity_id":second,"cause":"shot"}).ok,"二体目を撃破する")
	h = _cpp_tick(bridge)
	_check(h.landmarks.size()==2 and h.revealed and h.captive,"二体を回収すると星座の場所を示す")
	_check(bridge.restore(held.value).ok,"一体回収時へ復帰できる")
	h = _cpp_check_frame(bridge)
	_check(h.done[0]==1 and h.done[1]==0 and h.landmarks.size()==1,"復帰で二枠・carrier・doneが戻る")
	_check(bridge.command("dev_ship_motion",{"position":h.center,"velocity":Vector2.ZERO}).ok,"星座の位置へ機体を移す")
	var before_guards: PackedInt64Array = bridge._core.enemy_order_snapshot()
	h = _cpp_tick(bridge)
	for guard_id in bridge._core.enemy_order_snapshot():
		if not guard_id in before_guards:
			_check(bridge.command("dev_kill",{"entity_id":guard_id,"cause":"shot"}).ok,"護衛の途中死亡を通常戦闘で処理する")
			break
	_check(h.guarded and h.seen,"接近で護衛を出し星座を発見する")
	var metrics: Dictionary = bridge.read_metrics()
	_check(metrics.ok and metrics.value.enemies>2,"護衛を通常の敵生成入口から出す")
	_check(bridge.command("dev_kill",{"entity_id":second,"cause":"shot"}).ok,"護衛がいる途中でも目印を回収する")
	for i in range(0,h.links.size(),2):
		var a: Vector2 = h.stars[h.links[i]]
		var b: Vector2 = h.stars[h.links[i+1]]
		_check(bridge.command("dev_hero_pass",{"from":a,"to":b,"dash":i}).ok,"隣り合う星を同じ突進で通る")
	h = _cpp_check_frame(bridge)
	_check(not h.captive and h.power==&"perseus" and h.cooldown==0.0,"全線をつなぐと力を救出する")
	_check(_cpp_events.any(func(e): return e.type=="hero_freed"),"救出通知を配信する")
	_check(bridge.command("abort",{"reason":0}).ok,"救出直後も正常に終了できる")
	_cpp_check_frame(bridge)
	bridge.dispose()
	var lab = _cpp_fixture(true)
	h = _cpp_tick(lab)
	_check(h.carriers==PackedInt64Array([0,0]),"実験場だけ自動目印を止める")
	lab.dispose()
	print("[cpp_h00] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _cpp_h00_view() -> void:
	var bridge = _cpp_fixture(true)
	var h: Dictionary = _cpp_check_frame(bridge)
	var scope := ContentResourceScope.new()
	for path in ["res://.content/hero_aura.res","res://.content/meteor_pieces.res","res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png","res://assets/pixel/airship_armor.png","res://assets/pixel/airship_mine.png"]:
		scope.provide(path,load(path))
	for visual: Dictionary in _cpp_visuals:
		if not String(visual.get("path","")).is_empty(): scope.provide(visual.path,load(visual.path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	view.setup(scope,_cpp_visuals,0.455)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(1280,720)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 100
	add_child(hud_layer)
	hud_layer.add_child(hud)
	var camera := Camera2D.new()
	add_child(camera)
	camera.position = h.center
	bridge.command("dev_ship_motion",{"position":h.center,"velocity":Vector2.ZERO})
	h = _cpp_tick(bridge)
	var frame: Dictionary = bridge.read_frame().value
	frame.ui.view_center = h.center
	frame.ui.view_half = Vector2(640,360)
	frame.camera.center = h.center
	frame.camera.zoom = 1.0
	view.update_effects(frame,0.0)
	hud.apply_snapshot(frame.ui)
	var render: Dictionary = bridge.read_render(Rect2(h.center-Vector2(640,360),Vector2(1280,720)),1.0)
	_check(render.ok and view.apply_frame(render.value),"C++表示配列を星座・護衛と一緒に受け取る")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(not image.is_empty() and image.save_png("/tmp/speed-heroes-h00.png")==OK,"金色の線・星・光雲と案内を描画する")
	for i in range(0,h.links.size(),2): bridge.command("dev_hero_pass",{"from":h.stars[h.links[i]],"to":h.stars[h.links[i+1]],"dash":i})
	_cpp_check_frame(bridge)
	await get_tree().process_frame
	_check(hud._rewards.is_active(),"救出通知が共通の英雄カットインへ届く")
	bridge.command("abort",{"reason":0})
	_cpp_check_frame(bridge)
	hud.queue_free()
	view.queue_free()
	await get_tree().process_frame
	bridge.dispose()
	print("[cpp_h00_view] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
