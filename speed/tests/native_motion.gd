## 地形のない固定条件で、追跡の出現・LOD移動・個体再利用を本番処理と照合する。
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
	var core = comparison.create_native()
	if core == null or not core.has_method("spawn_enemy"):
		check(false, "ネイティブ側が敵の出現と移動を所有する")
	else:
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed": 932, "empty": true})
		var run: RunSimulation = lab.run
		var definition := run.enemies.def_of(&"drifter")
		check(core.configure(DATA.compile_enemy(definition, run.cfg)), "追跡敵を生成データから準備する")
		run.state.rng.seed = 932
		check(core.start(932, run.enemies._next_id), "同じ乱数と開始IDを使う")
		check(core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half), "追跡先と表示範囲を渡す")
		for pos in [Vector2(500, 0), Vector2(-500, 100), Vector2(3000, 0), Vector2.ZERO]:
			var row := run.enemies.spawn(definition, pos)
			check(core.spawn_enemy(&"drifter", pos) == run.enemies.table.id[row], "出現したIDが一致する")
		var before: Dictionary = core.inspect()
		check(core.spawn_enemy(&"未対応", Vector2.ZERO) == -1 and core.inspect() == before, "不明な敵でIDや乱数を消費しない")
		for tick in 60:
			if tick in [20, 40]:
				run.state.ship_pos = Vector2(100, -50) if tick == 20 else Vector2(-70, 80)
				core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
			var dt := 1.0 / 60.0
			run.state.world_time += dt
			run.enemies.tick(dt, dt)
			core.step(dt)
			var expected: Dictionary = comparison.snapshot(run, [], tick)
			var difference: String = comparison.difference(expected.enemies, core.enemies_snapshot())
			check(difference.is_empty(), "追跡と画面外の移動が一致する: " + difference)
			check(str(run.state.rng.state) == core.inspect().rng_state, "乱数の消費が一致する")
		var old_id: int = run.enemies.table.id[0]
		run.enemies.mark_dead(0)
		run.enemies.cleanup()
		check(core.remove_enemy(old_id), "個体IDで削除する")
		check(not core.remove_enemy(old_id), "削除済みのIDを拒否する")
		var row := run.enemies.spawn(definition, Vector2(100, 200))
		var new_id: int = core.spawn_enemy(&"drifter", Vector2(100, 200))
		check(new_id != old_id and new_id == run.enemies.table.id[row], "再利用後のIDを一致させる")
		check(comparison.difference(comparison.snapshot(run, [], 61).enemies, core.enemies_snapshot()).is_empty(), "再利用した個体に古い位置やHPを残さない")
		core.close()
		check(core.enemies_snapshot().is_empty(), "終了時に個体を解放する")
		lab.free()
	print("[native_motion] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
