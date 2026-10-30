## 近傍探索の候補順と、更新間の個体再利用を本番の格子と照合する。
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
	if not core.has_method("rebuild_enemy_grid"):
		check(false, "接触の探索をネイティブ状態から行う")
	else:
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed": 1, "empty": true})
		var run: RunSimulation = lab.run
		var definition := run.enemies.def_of(&"drifter")
		core.configure(DATA.compile_enemy(definition, run.cfg))
		core.start(1, run.enemies._next_id)
		for pos in [Vector2(100, 0), Vector2(100, 0), Vector2(-45, 70), Vector2(700, -180), Vector2(-700, 160)]:
			run.enemies.spawn(definition, pos)
			core.spawn_enemy(&"drifter", pos)
		run.combat.rebuild_grid()
		check(core.rebuild_enemy_grid(run.cfg.grid_cell), "所有状態から格子を作る")
		compare_queries(core, run)
		var removed: int = run.enemies.table.id[1]
		run.enemies.mark_dead(1)
		run.enemies.cleanup()
		core.remove_enemy(removed)
		var fresh := Vector2(-900, 50)
		run.enemies.spawn(definition, fresh)
		core.spawn_enemy(&"drifter", fresh)
		compare_queries(core, run)
		# 再構築前に追加された行は検索されない。既存の空き行は元のセルで見つかる。
		fresh = Vector2(5000, 0)
		run.enemies.spawn(definition, fresh)
		core.spawn_enemy(&"drifter", fresh)
		compare_queries(core, run)
		run.combat.rebuild_grid()
		core.rebuild_enemy_grid(run.cfg.grid_cell)
		compare_queries(core, run)
		check(not core.rebuild_enemy_grid(0), "無効な格子幅を拒否する")
		core.close()
		check(core.query_enemy_ids(Vector2(-10000, -10000), Vector2(10000, 10000)).is_empty(), "終了後は古い候補を返さない")
		lab.free()
	print("[native_grid] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_queries(core, run: RunSimulation) -> void:
	for region in [Rect2(-2000,-2000,10000,4000), Rect2(90,-10,20,20), Rect2(-920,30,40,40), Rect2(4990,-10,20,20), Rect2(20000,20000,30,30)]:
		var rows := PackedInt32Array()
		run.combat.grid.query(region.position, region.end, rows)
		var expected := PackedInt64Array()
		for row in rows: expected.append(run.enemies.table.id[row])
		check(expected == core.query_enemy_ids(region.position, region.end), "接触候補と順序が一致する: %s" % region)
