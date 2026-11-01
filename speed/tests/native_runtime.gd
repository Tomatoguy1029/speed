## 二つのネイティブランの寿命と、無効な更新で状態が壊れないことを確かめる。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--restore-only" in OS.get_cmdline_user_args():
		check(check_runtime_restore(), "保持と復帰の確認が最後まで完了する")
		print("[run_restore] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--schema-only" in OS.get_cmdline_user_args():
		check(check_schema(), "スキーマ確認が最後まで完了する")
		print("[run_schema] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var comparison = load("res://tools/compare_runtime.gd").new()
	var first = comparison.create_native()
	if first == null:
		check(false, "ネイティブランを読み込める")
	else:
		var second = comparison.create_native()
		check(not first.step(0.01), "開始前の更新を拒否する")
		check(first.start(932) and second.start(933), "別々のランを開始する")
		check(not first.start(934), "開始済みのランを再初期化しない")
		var before: Dictionary = first.inspect()
		for delta in [0.0, -1.0, INF, NAN]:
			check(not first.step(delta), "無効な経過時間を拒否する")
		check(first.inspect() == before, "拒否した更新で状態を変えない")
		check(first.step(0.5), "開始したランを更新する")
		check(first.inspect().time == 0.5 and second.inspect().time == 0.0, "ランの時計を共有しない")
		check(first.inspect().rng_state != second.inspect().rng_state, "ランごとの乱数を持つ")
		first.close()
		first.close()
		check(not first.step(0.1) and not first.start(932), "終了後の更新と再開始を拒否する")
		first = null
		check(second.step(0.25) and second.inspect().time == 0.25, "別ランの解放後も更新できる")
		var data_path := "res://tools/content/build_native_data.gd"
		if not ResourceLoader.exists(data_path) or not second.has_method("configure"):
			check(false, "編集データをネイティブ実行データへ変換できる")
		else:
			var compiler = load(data_path)
			var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
			var data: Dictionary = compiler.compile_enemy(definition, ContentManager.base)
			check(data.enemies[0].has("xp") and data.enemies[0].has("knockback") and data.enemies[0].has("hitstop_multiplier"), "撃破報酬・押出し・停止倍率を編集元から渡す")
			if not compiler.has_method("build_probe"):
				check(false, "比較用データを共通生成から保存できる")
			else:
				var path := "/tmp/speed-native-generated-probe.json"
				check(compiler.build_probe(path) == OK, "編集元の実行データを生成する")
				var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
				check(saved.has("forward") and configured_forward(comparison, saved), "W01の生成値を保存後に読み込める")
				check(saved is Dictionary and saved.version == 2 and saved.enemies.size() == 1 and saved.has("config") and saved.config.has("world_tick_div"), "保存結果を再読込できる")
			var configured = comparison.create_native()
			check(configured.configure(data), "追跡敵の定義を読み込める")
			var broken := data.duplicate(true)
			broken.version = 1.5
			check(not configured.configure(broken), "形式の版を切り捨てて受け付けない")
			broken = data.duplicate(true)
			broken.enemies[0].speed = NAN
			check(not configured.configure(broken), "不正な数値を拒否する")
			broken = data.duplicate(true)
			broken.enemies[0].behavior = "未対応"
			check(not configured.configure(broken), "未対応の行動を拒否する")
			broken = data.duplicate(true)
			broken.enemies.append(broken.enemies[0].duplicate(true))
			check(not configured.configure(broken), "重複した定義IDを拒否する")
			definition.speed += 20.0
			var changed: Dictionary = compiler.compile_enemy(definition, ContentManager.base)
			check(changed.enemies[0].speed == data.enemies[0].speed + 20.0, "制作データの数値変更が生成結果へ反映する")
			check(configured.start(932) and not configured.configure(data), "開始後に定義を差し替えない")
			var enemy_type: StringName = data.enemies[0].id
			check(configured.set_motion_context(Vector2(100, 0), Vector2.ZERO, Vector2(1000, 1000)), "追跡敵の更新入力を渡せる")
			var enemy_id: int = configured.spawn_enemy(enemy_type, Vector2.ZERO, {})
			var old_handle: PackedInt64Array = configured.enemy_handle(enemy_id)
			check(enemy_id > 0 and configured.valid_enemy_handle(old_handle), "生成した敵を世代付き参照で取得できる")
			var independent = comparison.create_native()
			check(independent.configure(data) and independent.start(932), "同じ定義から独立したランを作れる")
			check(configured.step(0.01) and independent.enemies_snapshot().is_empty(), "片方の敵更新が別のランへ漏れない")
			check(configured.remove_enemy(enemy_id) and not configured.valid_enemy_handle(old_handle), "回収した敵の古い参照を拒否する")
			var replacement_id: int = configured.spawn_enemy(enemy_type, Vector2.ZERO, {})
			var replacement_handle: PackedInt64Array = configured.enemy_handle(replacement_id)
			check(replacement_id > enemy_id and replacement_handle[0] == old_handle[0] and replacement_handle[1] > old_handle[1], "同じ行を再利用してもIDと世代を進める")
			check(not configured.valid_enemy_handle(old_handle) and configured.valid_enemy_handle(replacement_handle), "再利用後も古い参照が復活しない")
			var limit = comparison.create_native()
			check(limit.configure(data) and limit.start(932, 9223372036854775807), "上限の開始番号を指定できる")
			check(limit.spawn_enemy(enemy_type, Vector2.ZERO, {}) == -1 and limit.enemies_snapshot().is_empty(), "ID上限で周回せず生成を拒否する")
			limit.close()
			independent.close()
			configured.close()
		second.close()
	print("[native_runtime] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func configured_forward(comparison, data: Dictionary) -> bool:
	var core = comparison.create_native()
	var accepted: bool = core.configure_forward(data.forward, 5, data.config.character_scale)
	core.close()
	return accepted

func check_schema() -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var comparison = load("res://tools/compare_runtime.gd").new()
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	var data: Dictionary = builder.chase_records(definition, ContentManager.base)
	var signature: PackedByteArray = schema.sha256("追跡敵の固定入力".to_utf8_buffer())
	var bytes: PackedByteArray = schema.write_content(data, signature)
	var core = comparison.create_native()
	check(not bytes.is_empty() and core.configure_content(bytes), "共通スキーマの生成物をC++が読める")
	var bad: Dictionary = data.duplicate(true)
	bad.ChaseDefinition[0].extra = 1
	check(schema.write_content(bad, signature).is_empty(), "未登録フィールドを生成時に拒否する")
	bad = data.duplicate(true)
	bad.ChaseDefinition[0].hp = NAN
	check(schema.write_content(bad, signature).is_empty(), "非有限値を生成時に拒否する")
	bad = data.duplicate(true)
	bad.DefinitionIndex[0].enemy = 99
	check(schema.write_content(bad, signature).is_empty(), "存在しない参照を生成時に拒否する")
	var damaged := bytes.duplicate()
	damaged.encode_u32(8, 2)
	check(not core.configure_content(damaged), "形式の版不一致を開始前に拒否する")
	damaged = bytes.duplicate()
	damaged.encode_u64(96, bytes.size()+1)
	check(not core.configure_content(damaged), "セクションの範囲外offsetを拒否する")
	damaged = bytes.duplicate()
	damaged.encode_u64(104, 9223372036854775807)
	check(not core.configure_content(damaged), "長さの範囲超過を拒否する")
	damaged = bytes.duplicate()
	damaged[damaged.size()-1] ^= 1
	check(not core.configure_content(damaged), "内容署名の不一致を拒否する")
	var enemy_offset: int = bytes.decode_u64(88+3*32+8)
	damaged = bytes.duplicate()
	damaged.encode_u64(enemy_offset+4, 9221120237041090560)
	check(not core.configure_content(resign_content(damaged, schema)), "署名が正しくても非有限の読込を拒否する")
	var index_offset: int = bytes.decode_u64(88+2*32+8)
	damaged = bytes.duplicate()
	damaged.encode_u32(index_offset+4, 99)
	check(not core.configure_content(resign_content(damaged, schema)), "署名が正しくても参照不正を拒否する")
	check(core.start(932) and core.set_motion_context(Vector2(100,0),Vector2.ZERO,Vector2(1000,1000)), "検査失敗後も直前の有効な定義を保つ")
	var id: int = core.spawn_enemy(definition.id,Vector2.ZERO,{})
	check(id>0 and core.step(0.1), "Resourceから生成した追跡敵を更新できる")
	var row: Dictionary = core.enemies_snapshot()[0]
	check(row.pos[0]>0 and row.hp==data.ChaseDefinition[0].hp, "移植したHPと移動速度が実行へ反映する")
	core.close()
	return true

func resign_content(bytes: PackedByteArray, schema) -> PackedByteArray:
	var signature: PackedByteArray = schema.sha256(bytes.slice(88+32*bytes.decode_u32(16)))
	for i in range(32): bytes[56+i] = signature[i]
	return bytes

func check_runtime_restore() -> bool:
	var comparison = load("res://tools/compare_runtime.gd").new()
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	var signature: PackedByteArray = schema.sha256("復帰前の定義".to_utf8_buffer())
	var bytes: PackedByteArray = builder.compile_chase(definition,ContentManager.base,signature)
	var original = comparison.create_native()
	check(original.configure_content(bytes) and original.start(41), "生成した定義から保持対象を開始する")
	check(original.set_motion_context(Vector2(200,0),Vector2.ZERO,Vector2(1000,1000)), "更新の入力を設定する")
	var enemy_id: int = original.spawn_enemy(definition.id,Vector2.ZERO,{})
	check(enemy_id>0 and original.step(0.1), "保持前に敵を移動する")
	var expected: Array = original.enemies_snapshot()
	var saved_handle: PackedInt64Array = original.enemy_handle(enemy_id)
	var checkpoint_id: int = original.hold_checkpoint()
	check(checkpoint_id>0, "保持番号を取得する")
	original.close()
	original = null
	var restored = comparison.create_native()
	var epoch: int = restored.current_epoch()
	check(restored.restore_checkpoint(checkpoint_id), "元のラン破棄後も保持点から復帰できる")
	check(restored.current_epoch()>epoch and restored.enemies_snapshot()==expected, "保持時の敵へ戻し外部の世代を進める")
	check(restored.valid_enemy_handle(saved_handle), "保存した個体の世代を保つ")
	var independent = comparison.create_native()
	check(independent.restore_checkpoint(checkpoint_id), "同じ保持点から別のランへ復帰する")
	check(restored.step(0.1) and independent.enemies_snapshot()==expected, "復帰したランを別々に進められる")
	var current: Array = restored.enemies_snapshot()
	epoch = restored.current_epoch()
	check(not restored.restore_checkpoint(-1) and restored.enemies_snapshot()==current and restored.current_epoch()==epoch, "不正復帰で現在の状態と世代を変えない")
	definition.speed += 20.0
	var next_bytes: PackedByteArray = builder.compile_chase(definition,ContentManager.base,schema.sha256("変更後の定義".to_utf8_buffer()))
	var changed = comparison.create_native()
	check(changed.configure_content(next_bytes) and changed.start(41) and changed.restore_checkpoint(checkpoint_id), "違う定義のランを保持時の定義へ戻せる")
	var clone_id: int = changed.spawn_enemy(definition.id,Vector2.ZERO,{})
	check(clone_id>enemy_id and changed.step(0.1), "復帰した定義で新しい敵を動かす")
	var rows: Array = changed.enemies_snapshot()
	var clone: Dictionary = rows[rows.size()-1]
	check(absf(float(clone.pos[0])-float(expected[0].pos[0]))<0.0001, "復帰後の生成は変更前の速度を使う")
	check(changed.release_checkpoint(checkpoint_id), "保持点を解除できる")
	current = changed.enemies_snapshot()
	check(not changed.restore_checkpoint(checkpoint_id) and not changed.release_checkpoint(checkpoint_id) and changed.enemies_snapshot()==current, "解除した保持点を拒否する")
	check(independent.enemies_snapshot()==expected, "保持点の解除が復帰済みランへ漏れない")
	changed.close()
	restored.close()
	independent.close()
	return true
