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
	if core == null or not core.has_method("enemy_order_snapshot"):
		check(false, "ネイティブ側が敵の出現と移動を所有する")
	else:
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed": 932, "empty": true})
		var run: RunSimulation = lab.run
		var definition := run.enemies.def_of(&"drifter")
		var data := DATA.compile_enemy(definition, run.cfg)
		var shield: EnemyDef = run.enemies.def_of(&"shield")
		data.enemies.append_array(DATA.compile_enemy(shield, run.cfg).enemies)
		check(core.configure(data), "追跡敵と盾を生成データから準備する")
		check(core.configure_enemy_order(PackedStringArray(["chase"])), "初期化済みの行動の並びを渡す")
		check(not core.configure_enemy_order(PackedStringArray(["shield", "shield"])), "重複した登録順で準備を上書きしない")
		run.state.rng.seed = 932
		check(core.start(932, run.enemies._next_id), "同じ乱数と開始IDを使う")
		check(core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half), "追跡先と表示範囲を渡す")
		var early_shield := run.enemies.spawn(shield, Vector2(500,300))
		var early_shield_id: int = core.spawn_enemy(shield.id, Vector2(500,300))
		var early_chase := run.enemies.spawn(definition, Vector2(600,300))
		var early_chase_id: int = core.spawn_enemy(definition.id, Vector2(600,300))
		check(core.enemy_order_snapshot() == PackedInt64Array([run.enemies.table.id[early_chase],run.enemies.table.id[early_shield]]), "初期登録済みの空の行動を、最初に出た行動より前に保つ")
		run.enemies.mark_dead(early_shield)
		run.enemies.mark_dead(early_chase)
		run.enemies.cleanup()
		core.remove_enemy(early_shield_id)
		core.remove_enemy(early_chase_id)
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
		if not core.has_method("enemy_buffer"):
			check(false, "ネイティブ状態から表示用の一括データを作れる")
		else:
			var reference := InstanceBatch.new()
			reference.begin()
			var table := run.enemies.table
			var scale := 1.0 / definition.visual_value("collision_scale", 1.0)
			for i in table.alive.size():
				if table.alive[i] != 0:
					reference.add(table.pos[i], table.facing[i] + PI / 2.0, table.r[i] * scale, Color(0, 0, 0, 1))
			var buffer: PackedFloat32Array = core.enemy_buffer(&"drifter", scale, PI / 2.0)
			check(buffer == reference._buf.slice(0, run.enemies.count() * InstanceBatch.STRIDE), "表示用の位置・回転・大きさ・色が本番の一括描画と一致する")
			reference.free()
		var old_id: int = run.enemies.table.id[0]
		run.enemies.mark_dead(0)
		run.enemies.cleanup()
		check(core.remove_enemy(old_id), "個体IDで削除する")
		check(not core.remove_enemy(old_id), "削除済みのIDを拒否する")
		var row := run.enemies.spawn(definition, Vector2(100, 200))
		var new_id: int = core.spawn_enemy(&"drifter", Vector2(100, 200))
		check(new_id != old_id and new_id == run.enemies.table.id[row], "再利用後のIDを一致させる")
		check(comparison.difference(comparison.snapshot(run, [], 61).enemies, core.enemies_snapshot()).is_empty(), "再利用した個体に古い位置やHPを残さない")
		# 行動の登録順と、削除時の末尾入替を含む並びを比較する。
		for tick in 30:
			var def: EnemyDef = shield if tick % 3 == 0 else definition
			var at := Vector2(1000 + tick * 50, 300)
			row = run.enemies.spawn(def, at)
			core.spawn_enemy(def.id, at)
			if tick % 2 == 1:
				var target: int = run.enemies.beh_rows[0][0]
				var id: int = run.enemies.table.id[target]
				run.enemies.mark_dead(target)
				run.enemies.cleanup()
				check(core.remove_enemy(id), "途中の個体を解放する")
			var expected_order := PackedInt64Array()
			for rows in run.enemies.beh_rows:
				for index in rows: expected_order.append(run.enemies.table.id[index])
			check(core.enemy_order_snapshot() == expected_order, "行動の順と削除・再利用後の走査順を保つ")
		core.close()
		check(core.enemies_snapshot().is_empty(), "終了時に個体を解放する")
		lab.free()
	print("[native_motion] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
