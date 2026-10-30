## たて座の生成・追跡・旋回を、本番の編集値と更新へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var comparison = COMPARE.new()
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 287, "empty": true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	var definition := run.enemies.def_of(&"shield")
	var data := DATA.compile_enemy(definition, run.cfg)
	check(not data.is_empty(), "たて座の編集値を実行用データへ生成できる")
	if not data.is_empty():
		var core = comparison.create_native()
		check(core.configure(data), "たて座を対応する行動として読み込む")
		core.start(287, run.enemies._next_id)
		run.state.rng.seed = 287
		core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
		for position in [Vector2(500,100), Vector2(2500,200), Vector2(-2000,-300)]:
			run.enemies.spawn(definition, position)
			core.spawn_enemy(&"shield", position)
		for tick in 90:
			if tick in [20,50]: run.state.ship_pos = Vector2(130,180) if tick == 20 else Vector2(-170,400)
			core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
			var dt := 1.0/60.0
			run.state.world_time += dt
			run.enemies.tick(dt,dt)
			core.step(dt)
			var difference: String = comparison.difference(comparison.snapshot(run, [], tick).enemies, core.enemies_snapshot())
			check(difference.is_empty(), "追跡・旋回・遠方の更新が一致する: %d %s" % [tick,difference])
			check(str(run.state.rng.state) == core.inspect().rng_state, "敵の移動で乱数消費を変えない")
		core.close()
	lab.free()
	print("[native_shield] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
