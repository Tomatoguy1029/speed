## 二つのネイティブランの寿命と、無効な更新で状態が壊れないことを確かめる。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--clock-only" in OS.get_cmdline_user_args():
		check(check_run_clock(), "時計と世界更新の確認が最後まで完了する")
		print("[run_clock] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--bridge-only" in OS.get_cmdline_user_args():
		check(check_run_bridge(), "入力接続の確認が最後まで完了する")
		print("[run_bridge] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--random-only" in OS.get_cmdline_user_args():
		check(check_run_random(), "戦闘乱数の確認が最後まで完了する")
		print("[run_random] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
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

func check_run_random() -> bool:
	var comparison = load("res://tools/compare_runtime.gd").new()
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	var bytes: PackedByteArray = builder.compile_chase(definition,ContentManager.base,schema.sha256("乱数の固定入力".to_utf8_buffer()))
	var first = comparison.create_native()
	var second = comparison.create_native()
	check(first.configure_content(bytes) and second.configure_content(bytes) and first.start(42) and second.start(42), "同じ定義とseedで開始する")
	check(first.inspect().rng_state=="-7531428700269491564", "PCG32の規定のseed初期化を使う")
	first.set_motion_context(Vector2(300,0),Vector2.ZERO,Vector2(1000,1000))
	second.set_motion_context(Vector2(300,0),Vector2.ZERO,Vector2(1000,1000))
	for tick in range(20):
		check(first.spawn_enemy(definition.id,Vector2(tick*3,0),{})==second.spawn_enemy(definition.id,Vector2(tick*3,0),{}), "同じ入力で生成IDが一致する")
		check(first.step(0.01) and second.step(0.01), "固定入力を更新できる")
		check(first.inspect().rng_state==second.inspect().rng_state and first.enemies_snapshot()==second.enemies_snapshot(), "同じ入力の乱数と戦闘結果が再現する")
	var saved: int = first.hold_checkpoint()
	check(saved>0 and second.restore_checkpoint(saved), "乱数を含めて保持・復帰する")
	for tick in range(10):
		first.spawn_enemy(definition.id,Vector2(tick,20),{})
		second.spawn_enemy(definition.id,Vector2(tick,20),{})
		first.step(0.01)
		second.step(0.01)
		check(first.inspect().rng_state==second.inspect().rng_state and first.enemies_snapshot()==second.enemies_snapshot(), "復帰後も乱数の消費位置と結果が一致する")
	check(first.release_checkpoint(saved), "確認に使った保持点を解除する")
	first.close()
	second.close()
	return true

func check_run_bridge() -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var stage := RuntimeStage.new()
	stage.index = 79
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_bridge"
	var signature := "入力接続の固定入力".sha256_text()
	if builder.build(stage,ContentManager.base,output,signature)!=OK: return false
	var path := output.path_join("stage_79.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var options := {"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":42}
	var session: RunSession = RunManager.create_session(self,options,false)
	session.auto_step = false
	if session.bridge == null: return false
	var bridge = session.bridge
	check(bridge.read_frame().ok, "通常SessionがC++の窓口を所有する")
	var initial: Dictionary = bridge.read_frame().value
	var input := Intent.new()
	input.has_cursor = true
	input.cursor = Vector2(2000,0)
	for tick in range(30):
		check(bridge.step(1.0/120.0,bridge.pack_intent(input),{"logical_size":Vector2(640,480)}).ok, "固定更新で移動入力を届ける")
	var moved: Dictionary = bridge.read_frame().value
	check(moved.tick==30 and moved.ui.ship.ship_pos!=initial.ui.ship.ship_pos, "120Hzの更新を一度ずつ実行する")
	var pen: Vector2 = moved.ui.ship.ship_pos
	input.press = true
	input.pen = pen
	input.touch = true
	check(bridge.step(1.0/120.0,bridge.pack_intent(input),{"logical_size":Vector2(640,480)}).ok and bridge.read_frame().value.ui.draw.drawing, "押下で描線を始める")
	input.press = false
	input.pen_release = true
	input.pen = pen+Vector2(100,0)
	check(bridge.step(1.0/120.0,bridge.pack_intent(input),{"logical_size":Vector2(640,480)}).ok, "ペンの移動と解放を届ける")
	check(not bridge.read_frame().value.ui.draw.drawing, "タッチの解放で描線を確定する")
	var envelope := {"run_id":session.id,"epoch":bridge._epoch,"command_id":1,"kind":"pause","payload":{"paused":true}}
	var first: Dictionary = bridge.send_envelope(envelope)
	var revision: int = bridge.read_frame().value.state_revision
	check(first.ok and bridge.send_envelope(envelope)==first and bridge.read_frame().value.state_revision==revision, "同じ命令番号は同じ返答で二重適用しない")
	var invalid := envelope.duplicate(true)
	invalid.epoch -= 1
	check(bridge.send_envelope(invalid).code==3, "古い世代の命令を拒否する")
	var prior: Dictionary = bridge.read_frame().value
	check(bridge.step(1.0/60.0,bridge.pack_intent(input),{"logical_size":Vector2(640,480)}).code==1 and bridge.read_frame().value==prior, "不正dtを変更前に拒否する")
	var malformed: Dictionary = bridge.pack_intent(input)
	malformed.hero_press = 1
	check(bridge.step(1.0/120.0,malformed,{"logical_size":Vector2(640,480)}).code==1, "入力の全フィールドを型で検査する")
	check(bridge.step(1.0/120.0,bridge.pack_intent(input),{"logical_size":Vector2(640,480),"zoom":1.0}).code==1, "カメラ倍率を外部から渡さない")
	check(bridge.command("pause",{"paused":false}).ok, "入力の再入確認前にPLAYへ戻す")
	var reentry := []
	var provider := func() -> Intent:
		reentry.append(bridge.command("pause",{"paused":false}).code)
		return Intent.new()
	check(bridge.poll_and_step(1.0/120.0,provider,Vector2(640,480)).ok and reentry==[7], "入力取得中の再入を拒否する")
	check(bridge.dispose().ok and bridge.dispose().ok and not bridge.read_frame().ok, "破棄は繰り返し安全で旧窓口は使えない")
	var previous_id := session.id
	session.free()
	var next: RunSession = RunManager.create_session(self,options,false)
	next.auto_step = false
	check(next.id>previous_id and next.bridge!=null and next.bridge.read_frame().value.tick==0, "再出撃は別のランIDと状態を使う")
	next.free()
	return true

func clock_fixture(config: GameConfig, definition: EnemyDef, combat := false, split := false):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var bytes: PackedByteArray = builder.compile_chase(definition,config,schema.sha256("時計の固定入力".to_utf8_buffer()))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(bytes,{"api_version":1,"run_id":51,"mode":1,"stage_id":"clock","profile":{},"settings":{}}).ok, "時計の固定条件を読み込む")
	if combat:
		# 未移行の戦闘サービスは既存の設定口から試験条件だけを渡す。
		var combat_config := {}
		for key in load("res://tests/native_combat.gd").COMBAT_CONFIG: combat_config[key] = config.get(key)
		combat_config.ram_speed_ratio = 0.0
		check(bridge._core.configure_combat(combat_config,{"attack_mult":1.0,"crit_chance":0.0,"crit_mult":config.crit_mult}), "停止を起こす戦闘の固定条件を設定する")
		check(bridge._core.configure_pickups({"xp_bonus":1.0,"gem_max":10,"drop_base":0.0,"drop_max":0.0,"drop_power_exp":0.0,"big_crystal_shift_time":1.0,
			"big_crystal_xp":config.xp_crystal_values,"big_crystal_weights_start":[1.0,0.0,0.0],"big_crystal_weights_end":[1.0,0.0,0.0]},
			{"xp_mult":1.0,"xp_pickup_radius":1.0,"pickup_radius":1.0,"pickup_speed_mult":1.0}), "戦闘の依存条件を設定する")
	if split:
		check(bridge._core.configure_projectiles({"hull_debris_life":1.0,"hull_debris_knock":0.0,"corpse_trail_points":0},
			{"chance":1.0,"damage":1.0,"angle_min":0.0,"angle_max":0.0,"generations":1,"max":100}), "反復中の追加を起こす固定条件を設定する")
	check(bridge.start(41).ok, "時計の確認用ランを開始する")
	return bridge

func clock_step(bridge, intent: Intent = null) -> void:
	if intent == null: intent = Intent.new()
	check(bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(640,480)}).ok, "時計の固定更新を進める")

func check_run_clock() -> bool:
	var dt := 1.0/120.0
	var config := ContentManager.base.duplicate(true) as GameConfig
	config.world_tick_div = 3
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.speed = 100.0
	var bridge = clock_fixture(config,definition)
	var ship: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
	check(bridge.command("dev_spawn",{"definition_id":String(definition.id),"position":ship+Vector2(200,0)}).ok, "開発命令から敵と検索索引を更新する")
	var before: Array = bridge._core.enemies_snapshot()
	clock_step(bridge)
	clock_step(bridge)
	var pending: Dictionary = bridge._core.inspect()
	check(pending.world_updates==0 and absf(pending.world_real_accum-2*dt)<1e-9 and absf(pending.world_dt_accum-2*dt)<1e-9, "世界更新の前は二つのdtを保存する")
	check(bridge._core.enemies_snapshot()==before, "間引き中に敵を更新しない")
	var point: int = bridge.checkpoint().value
	clock_step(bridge)
	var after: Array = bridge._core.enemies_snapshot()
	var boundary: Dictionary = bridge._core.inspect()
	check(boundary.world_updates==1 and boundary.world_steps==0 and boundary.world_real_accum==0.0 and boundary.world_dt_accum==0.0, "境界で蓄積を一度だけ渡してリセットする")
	check(after!=before and absf(boundary.last_world_real_dt-3*dt)<1e-9, "敵へ蓄積した時間を渡す")
	check(bridge.restore(point).ok, "境界直前の保持点へ復帰する")
	clock_step(bridge)
	check(bridge._core.enemies_snapshot()==after and bridge._core.inspect().world_updates==1, "復帰した二つのdtで同じ境界を再現する")
	bridge.release_checkpoint(point)
	check(bridge.command("set_ui_overlay",{"active":true}).ok, "UI停止を設定する")
	var stopped: Dictionary = bridge._core.inspect()
	var polls := []
	var provider := func() -> Intent:
		polls.append(true)
		return Intent.new()
	check(bridge.poll_and_step(dt,provider,Vector2(640,480)).ok and polls.is_empty(), "UI停止中は入力を消費しない")
	var frozen: Dictionary = bridge._core.inspect()
	check(frozen.time==stopped.time and frozen.sim_time==stopped.sim_time and frozen.world_time==stopped.world_time and frozen.world_real_accum==stopped.world_real_accum, "UI停止中は時計と蓄積を保つ")
	bridge.command("set_ui_overlay",{"active":false})
	bridge.command("set_ui_reward",{"active":true})
	clock_step(bridge)
	check(bridge._core.inspect().sim_time==stopped.sim_time, "報酬表示中もPLAYの時計を止める")
	bridge.command("set_ui_reward",{"active":false})
	bridge.command("pause",{"paused":true})
	clock_step(bridge)
	check(bridge._core.inspect().sim_time==stopped.sim_time, "PAUSEDでは時計を止める")
	bridge.command("pause",{"paused":false})
	clock_step(bridge)
	check(bridge._core.inspect().sim_time>stopped.sim_time, "再開後に一度だけ時間を進める")
	bridge.dispose()
	config.world_tick_div = 2
	config.draw_time_scale = 0.25
	var slow = clock_fixture(config,definition)
	var draw := Intent.new()
	draw.press = true
	draw.has_cursor = true
	draw.pen = slow.read_frame().value.ui.ship.ship_pos
	clock_step(slow,draw)
	draw.press = false
	clock_step(slow,draw)
	var scaled: Dictionary = slow._core.inspect()
	check(absf(scaled.last_world_real_dt-2*dt)<1e-9 and absf(scaled.last_world_dt-0.5*dt)<1e-9, "描線スローでも実dtと世界dtを混同しない")
	slow.dispose()
	config.world_tick_div = 1
	definition.stage_hp = 0.1
	definition.speed = 0.0
	var hit = clock_fixture(config,definition,true)
	ship = hit.read_frame().value.ui.ship.ship_pos
	hit.command("dev_spawn",{"definition_id":String(definition.id),"position":ship})
	clock_step(hit)
	check(hit._core.combat_snapshot().hitstop>0, "体当たりの停止を発生させる")
	var hit_before: Dictionary = hit._core.inspect()
	draw = Intent.new()
	draw.press = true
	draw.pen = ship
	clock_step(hit,draw)
	var hit_after: Dictionary = hit._core.inspect()
	check(hit_after.sim_time>hit_before.sim_time and hit_after.time==hit_before.time and hit_after.world_time==hit_before.world_time and hit.read_frame().value.ui.draw.drawing, "ヒットストップ中も入力を受け、ランと世界の時計は進めない")
	hit.dispose()
	definition.stage_hp = 1000000.0
	for reuse in [false,true]:
		var shots = clock_fixture(config,definition,true,true)
		shots.command("dev_spawn",{"definition_id":String(definition.id),"position":Vector2(100,0)})
		if reuse: check(shots._core.fire_shot(Vector2.ZERO,0.0,0.0,{"speed":120.0,"life":0.0}), "先に通過する空き行を作る")
		check(shots._core.fire_shot(Vector2(100,0),0.0,0.0,{"speed":120.0,"life":0.5}), "後方追加を起こす弾を作る")
		clock_step(shots)
		var children: Array = shots._core.projectiles_snapshot()
		check(children.size()==2, "更新中に作られた二つの行を保持する")
		if children.size()==2:
			check(absf(children[0].age-(dt if reuse else 2*dt))<1e-6 and absf(children[1].age-2*dt)<1e-6, "後ろへ足した行と通過済み空き行の再利用を区別する")
		shots.dispose()
	return true
