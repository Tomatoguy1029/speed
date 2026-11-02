## 囲い・予算・分離後の参加者を、本番C++の命令と観測で確認する。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
var helper
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func body(bridge) -> Dictionary:
	return bridge.command("dev_boss_body_state").value[0]
func enemy(core, id: int) -> Dictionary:
	for value: Dictionary in core.enemies_snapshot():
		if value.id==id: return value
	return {}
func _ready() -> void:
	helper = load("res://tests/runtime/boss_registry.gd").new()
	check_environment()
	check_budget()
	check_grid()
	check_separated()
	failed += helper.failed
	helper.free()
	print("[hydra_live] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func check_environment() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.planet_radius = 1.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 804
	stage.boss_id = &"hydra"
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["biter"])
	var output := "res://.content/dev/hydra_live"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,cfg,output,"ヒュドラの囲いと参加者".sha256_text())
	check(built==OK,"囲いの確認を通常の生成入口へ接続する")
	if built!=OK: return
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_804.json")))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(FileAccess.get_file_as_bytes(index.binary),{"api_version":1,"run_id":804,"mode":1,"stage_id":"hydra_live","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"囲い・通常敵・岩の定義を読む")
	if not configured.ok: bridge.dispose();return
	bridge.start(804,{"position":Vector2(400,0)})
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"position":Vector2(400,0),"auto_boss":true}})
	var core = bridge._core
	check(bridge.read_frame().value.ui.hero.guidance,"ボス開始前は英雄の誘導を表示する")
	var wall_enemy: int = core.spawn_enemy(&"biter",Vector2(1900,0))
	check(bridge.command("dev_add_rock",{"position":Vector2(1900,200),"kind":2,"manual":true}).ok,"鉄隕石を独立した生成元として置く")
	var gem: int = bridge.command("dev_drop_crystal",{"position":Vector2(1850,0),"kind":RunIds.GemKind.Mid}).value
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var moved := enemy(core,wall_enemy)
	check(moved.pos[0]<1800.0 and moved.pos[0]>0.0,"囲いの設置で壁に埋まる敵を内側へ移す")
	var gems: Array = core.pickups_snapshot().gems.filter(func(value): return value.id==gem)
	check(gems.size()==1 and gems[0].pos.x<1800.0 and gems[0].value==cfg.xp_crystal_values[RunIds.GemKind.Mid] and gems[0].kind==RunIds.GemKind.Mid,"囲いの設置で結晶の種類と経験値を保って内側へ移す")
	bridge.command("dev_stream_rocks",{"center":Vector2(400,0),"half":Vector2(2400,1800),"dt":0.02})
	var rocks: Array = bridge.command("dev_field_query",{"action":"rocks"}).value
	check(rocks.size()==1 and rocks[0].position.x<1800.0 and rocks[0].enemy_id>0 and enemy(core,rocks[0].enemy_id).pos[0]<1800.0,"岩の生成元と表示用の個体が同じ囲いの内側に残る")
	check(not bridge.read_frame().value.ui.hero.guidance,"ボス開始後は英雄の矢印と地図の誘導を隠す")
	bridge.command("dev_enemy_combat",{"entity_id":id,"guard":0.0})
	var hp: float = body(bridge).hp
	var damage: float = bridge.read_frame().value.ui.attack_power*0.7
	bridge.command("dev_damage",{"entity_id":id,"amount":damage,"cause":"shot"})
	check(body(bridge).hp>0.0 and is_equal_approx(hp-body(bridge).hp,damage),"通常武器の命中は本体を即死させず実ダメージを引く")
	hp = body(bridge).hp
	check(bridge.command("dev_fire_wave",{"position":Vector2.ZERO,"angle":0.0,"arc":TAU,"radius":300.0,"speed":600.0,"width":600.0,"delay":0.0,"damage":0.0,"enemy_damage":7.0}).ok,"実際の波動を本体へ発射する")
	for tick in 6: core.step_hazards(0.1)
	check(is_equal_approx(hp-body(bridge).hp,7.0),"一つの波動は寿命全体で本体へ一度だけ命中する")
	bridge.dispose()
func check_budget() -> void:
	var c: Dictionary = helper.hydra_normal_case()
	if c.is_empty(): check(false,"通常技の試行を準備する");return
	var bridge = c.bridge
	bridge._core.set_attack_formation_mode(true)
	bridge._core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	var target: Dictionary = body(bridge).necks[0]
	bridge.command("dev_ship_motion",{"position":target.position+Vector2(100,0),"velocity":Vector2.ZERO})
	var attack: Dictionary = bridge.command("dev_boss_technique",{"entity_id":target.id,"definition":1})
	check(attack.ok,"通常敵の予算が0でもボスの通常技を開始する")
	if attack.ok: bridge.command("dev_cancel_technique",{"ticket":attack.value})
	bridge.dispose()
	c = helper.hydra_normal_case(true)
	if c.is_empty(): check(false,"共通フローの試行を準備する");return
	bridge = c.bridge
	bridge._core.set_attack_formation_mode(true)
	bridge._core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	var warnings: Array[int] = [0]
	bridge.subscribe("hydra_live",func(frame):
		for event: Dictionary in frame.events:
			if event.type=="hydra_cue" and event.payload.get("cue","")=="warning_started": warnings[0]+=1
		return true)
	for tick in 350:
		bridge._core.step(0.02)
		bridge.collect_frame()
	check(warnings[0]>0,"通常敵の予算が0でも共通フローから攻撃を開始する")
	bridge.dispose()
	c = helper.hydra_major_case("curve",{},false)
	if c.is_empty(): check(false,"大技の試行を準備する");return
	bridge = c.bridge
	bridge._core.set_attack_formation_mode(true)
	bridge._core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	bridge._core.step(4.0)
	check(bridge.command("dev_boss_technique",{"entity_id":c.id,"definition":1}).ok,"通常敵の予算が0でも大技を開始する")
	bridge.dispose()
func check_grid() -> void:
	var c: Dictionary = helper.hydra_major_case("grid",{},false,{}, {"planet_radius":1.0})
	if c.is_empty(): check(false,"格子の試行を準備する");return
	var bridge = c.bridge
	helper.hydra_grid_separate(c)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true}})
	var plan: Dictionary = bridge.command("dev_hydra_grid_plan",{"entity_id":c.id,"definition":1}).value
	check(not plan.is_empty(),"天体のない領域では格子の配置が成立する")
	if not plan.is_empty():
		check(bridge.command("dev_edit",{"kind":"planet","payload":{"position":plan.bearer,"radius":100.0}}).ok,"不死首の配置先に天体を置く")
		check(bridge.command("dev_hydra_grid_plan",{"entity_id":c.id,"definition":1}).value.is_empty(),"不死首の配置先が天体の中なら格子を開始しない")
	bridge.dispose()
func check_separated() -> void:
	var c: Dictionary = helper.hydra_normal_case(false,{}, {},"bite_thrust",{"planet_radius":1.0})
	if c.is_empty(): check(false,"分離後の試行を準備する");return
	var bridge = c.bridge
	helper.hydra_grid_separate(c)
	var value := body(bridge)
	bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":"clear_enemies","args":{}}})
	value = body(bridge)
	check(value.bearer.alive and value.necks.all(func(n): return n.alive),"通常敵の消去は生きている首と不死首を残す")
	for neck: Dictionary in value.necks: bridge.command("dev_damage",{"entity_id":neck.id,"amount":1000.0,"cause":"shot"})
	var target := Vector2(350,100)
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	var aimed := false
	for tick in 350:
		bridge._core.step(0.02)
		var actions: Array = bridge.command("dev_boss_state").value
		if actions.any(func(action): return action.actor==value.bearer.id and action.aim==target): aimed=true;break
	check(aimed,"不死首だけが残ると現在の機体位置を噛みつきの狙いへ固定する")
	value = body(bridge)
	bridge.command("dev_enemy_combat",{"entity_id":value.bearer.id,"guard":0.0})
	var hp: float = value.bearer.hp
	var damage: float = bridge.read_frame().value.ui.attack_power*0.7
	bridge.command("dev_damage",{"entity_id":value.bearer.id,"amount":damage,"cause":"shot"})
	check(body(bridge).bearer.hp>0.0 and is_equal_approx(hp-body(bridge).bearer.hp,damage),"通常武器の命中は不死首を即死させない")
	for action: Dictionary in bridge.command("dev_boss_state").value:
		bridge.command("dev_cancel_technique",{"ticket":action.id})
	value = body(bridge)
	var planet: Vector2 = value.bearer.position+Vector2(80,0)
	check(bridge.command("dev_edit",{"kind":"planet","payload":{"position":planet,"radius":130.0}}).ok,"泳いでいる不死首の近くに天体を置く")
	for tick in 100: bridge._core.step(0.02)
	value = body(bridge)
	var radius: float = enemy(bridge._core,value.bearer.id).radius
	check(value.bearer.position.distance_to(planet)>=130.0+radius-0.1,"不死首は天体の外側へ押し戻される")
	var definition: BossDef = load("res://data/bosses/hydra.tres")
	check(is_equal_approx(value.max_hp,float(definition.params.immortal_hp)*c.cfg.enemy_hp_mult),"分離後の本体HPは不死首の定義に従う")
	bridge.dispose()
