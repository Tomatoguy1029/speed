## 二つのネイティブランの寿命と、無効な更新で状態が壊れないことを確かめる。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
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
