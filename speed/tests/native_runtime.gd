## 二つのネイティブランの寿命と、無効な更新で状態が壊れないことを確かめる。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--schema-section-ids" in OS.get_cmdline_user_args():
		check(check_schema_section_ids(),"区画の番号と件数を分けた読込確認を最後まで実施する")
		print("[schema_section_ids] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--assets-only" in OS.get_cmdline_user_args() or "--assets-loading-only" in OS.get_cmdline_user_args():
		check(await check_run_assets("--assets-loading-only" in OS.get_cmdline_user_args()),"表示資源の生成・準備・取消と保持を最後まで確認する")
		print("[run_assets] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--lifecycle-only" in OS.get_cmdline_user_args() or "--lifecycle-display-only" in OS.get_cmdline_user_args():
		check(await check_run_lifecycle("--lifecycle-display-only" in OS.get_cmdline_user_args()),"終了結果と保存を最後まで確認する")
		print("[run_lifecycle] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--hound-only" in OS.get_cmdline_user_args() or "--hound-bite-only" in OS.get_cmdline_user_args():
		check(check_hound_groups("--hound-bite-only" in OS.get_cmdline_user_args()),"猟犬の群れ・指示・離脱と復帰を最後まで確認する")
		print("[hound_groups] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--choice-only" in OS.get_cmdline_user_args():
		check(check_run_choices(),"カード選択と資源保持を最後まで確認する")
		print("[run_choices] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--geometry-only" in OS.get_cmdline_user_args() or "--geometry-sweep-only" in OS.get_cmdline_user_args():
		check(check_contact_geometry("--geometry-sweep-only" in OS.get_cmdline_user_args()),"攻撃の形と共通被弾を最後まで確認する")
		print("[run_geometry] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--events-only" in OS.get_cmdline_user_args():
		check(check_run_events(), "通知の配信と受領確認を最後まで確認する")
		print("[run_events] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--attack-owner-only" in OS.get_cmdline_user_args():
		check(check_attack_owners(), "攻撃の所有と終了条件を最後まで確認する")
		print("[attack_owner] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--render-only" in OS.get_cmdline_user_args() or "--render-enemies-only" in OS.get_cmdline_user_args():
		check(await check_run_render("--render-enemies-only" in OS.get_cmdline_user_args()), "描画付きの代表経路を最後まで確認する")
		print("[run_render] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--timer-only" in OS.get_cmdline_user_args():
		check(check_run_timers(), "タイマーと境界の確認を最後まで完了する")
		print("[run_timer] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--combat-only" in OS.get_cmdline_user_args():
		check(check_run_combat(), "共通戦闘の固定場面を最後まで確認する")
		print("[run_combat] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
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
	bad.EnemyRecord[0].extra = 1
	check(schema.write_content(bad, signature).is_empty(), "未登録フィールドを生成時に拒否する")
	bad = data.duplicate(true)
	bad.EnemyRecord[0].hp = NAN
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
	check(row.pos[0]>0 and row.hp==data.EnemyRecord[0].hp, "移植したHPと移動速度が実行へ反映する")
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

func combat_fixture(hp := 100.0, armor := 0.0):
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.kill_hitstop = 0.0
	config.ram_speed_ratio = 0.0
	config.strong_gold_chance = 0.0
	config.base_attack = 10.0
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.stage_hp = hp
	definition.xp_reward_counts = PackedInt32Array([1,0,0])
	definition.armor = armor
	definition.speed = 0.0
	return clock_fixture(config,definition)

func combat_enemy(bridge, position := Vector2(100,0)) -> int:
	var spawn: Dictionary = bridge.command("dev_spawn",{"definition_id":"drifter","position":position})
	check(spawn.ok, "戦闘の固定対象を出す")
	return int(spawn.value) if spawn.ok else 0

func check_run_combat() -> bool:
	var bridge = combat_fixture()
	var id: int = combat_enemy(bridge)
	for guard in ["controls_locked","encounter_protected"]:
		check(bridge._core.set_run_guards({guard:true}), "保護を有効にする")
		var hit: Dictionary = bridge.command("dev_damage",{"entity_id":id,"amount":200.0})
		var kill: Dictionary = bridge.command("dev_kill",{"entity_id":id})
		check(hit.ok and hit.value.reason==guard and hit.value.applied==0.0 and not kill.value.killed, "保護は通常命中と直接撃破の両方を止める")
		bridge._core.set_run_guards({guard:false})
	check(bridge.command("dev_enemy_combat",{"entity_id":id,"guard":1.0}).ok, "敵自身の保護を設定する")
	check(bridge.command("dev_kill",{"entity_id":id}).value.reason=="guard", "直接撃破も敵の保護を読む")
	bridge.command("dev_enemy_combat",{"entity_id":id,"guard":0.0})
	var part: int = combat_enemy(bridge,Vector2(150,0))
	check(bridge.command("dev_enemy_combat",{"entity_id":part,"damage_target":id}).ok, "HPを共有する部位を設定する")
	var transferred: Dictionary = bridge.command("dev_damage",{"entity_id":part,"amount":30.0}).value
	check(transferred.struck_id==part and transferred.target_id==id and transferred.applied==30.0, "当たった部位とHP転送先を両方残す")
	check(bridge._core.enemies_snapshot()[0].hp==70.0 and bridge._core.enemies_snapshot()[1].hp==100.0, "共有先だけのHPを減らす")
	var dead: Dictionary = bridge.command("dev_damage",{"entity_id":part,"amount":90.0}).value
	check(dead.killed and dead.applied==70.0 and dead.overkill==20.0, "実際のHP減少と過剰な量を分ける")
	var count: int = bridge._core.pickups_snapshot().gems.size()
	var supplied: float = bridge._core.pickups_snapshot().xp_dropped
	check(count>0 and supplied>0.0, "通常入口から撃破報酬を生成する")
	check(not bridge.command("dev_kill",{"entity_id":id}).value.killed and bridge._core.combat_snapshot().kills==1, "同tickの二重撃破を拒否する")
	check(bridge._core.pickups_snapshot().gems.size()==count and bridge._core.pickups_snapshot().xp_dropped==supplied, "二度目の撃破は供給を増やさない")
	var trace: Array = bridge.read_frame().value.events
	check(trace.any(func(e): return e.get("type")==&"combat_damage" and e.get("struck_id")==part and e.get("target_id")==id and e.get("applied")==70.0), "転送と実ダメージを観測へ残す")
	clock_step(bridge)
	check(bridge._core.enemies_snapshot().size()==1 and not bridge._core.valid_enemy_handle(PackedInt64Array([0,1])), "撃破した行を所定のcleanupで回収する")
	var before: int = bridge._core.combat_snapshot().kills
	check(bridge.command("dev_remove",{"entity_id":part}).ok and bridge._core.combat_snapshot().kills==before and bridge._core.pickups_snapshot().xp_dropped==supplied, "退場は撃破数と報酬を増やさない")
	bridge.dispose()
	for armor in [0.0,100000.0]:
		var contact = combat_fixture(100.0,armor)
		var ship: Vector2 = contact.read_frame().value.ui.ship.ship_pos
		var boundary: int = combat_enemy(contact,ship+Vector2(100,0))
		var row: Dictionary = contact._core.enemies_snapshot()[0]
		var radius: float = 100.0-float(row.radius)
		check(radius>=0.0, "境界場面の半径を構成する")
		var bounced: bool = contact._core.collide_ship(ship,radius)
		check(bounced==(armor>0.0), "境界ちょうどの接触でも装甲を判定する")
		var hit_events: Array = contact._core.drain_events()
		check(hit_events.any(func(e): return e.get("type")==&"hit" and e.get("id")==boundary), "境界接触を命中通知へ届ける")
		contact.dispose()
	var ship_run = combat_fixture()
	var hp: float = ship_run.read_frame().value.ui.ship.ship_hp
	ship_run._core.set_run_guards({"encounter_protected":true})
	var rejected: Dictionary = ship_run.command("dev_ship_damage",{"amount":2.0,"cause":"shot"}).value
	check(not rejected.accepted and rejected.reason=="encounter_protected" and rejected.hp_after==hp, "機体の保護中の被弾も拒否理由を残す")
	ship_run._core.set_run_guards({"encounter_protected":false})
	var accepted: Dictionary = ship_run.command("dev_ship_damage",{"amount":2.0,"cause":"shot"}).value
	check(accepted.accepted and accepted.hp_after==hp-2.0, "機体のHPを共通窓口で減らす")
	var repeated: Dictionary = ship_run.command("dev_ship_damage",{"amount":2.0,"cause":"shot"}).value
	check(not repeated.accepted and repeated.reason=="invulnerability", "被弾後の無敵を二重に通らない")
	trace = ship_run.read_frame().value.events
	check(trace.filter(func(e): return e.get("type")==&"combat_player_damage").size()==3, "受理と拒否の全試行を記録する")
	ship_run.dispose()
	return true

func timing_fixture(formations := [], forward := {}):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.draw_time_scale = 1.0
	var bytes: PackedByteArray = builder.compile_chase(definition,config,schema.sha256("タイマーの固定入力".to_utf8_buffer()))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(bytes,{"api_version":1,"run_id":61,"mode":1,"stage_id":"timing","profile":{},"settings":{}}).ok, "時間の固定条件を設定する")
	if not formations.is_empty(): check(bridge._core.configure_formations(formations,2000.0), "重みの境界を持つ編成を準備する")
	if not forward.is_empty(): check(bridge._core.configure_forward(forward,1,1.0), "射撃の端数が出る周期を設定する")
	check(bridge.start(42).ok, "時間の固定場面を開始する")
	return bridge

func check_run_timers() -> bool:
	var forward := {"interval_by_level":[0.01,0.02],"damage_by_level":[0.0,0.0],"pierce_by_level":[0,0],"life":1.0,"spread_step":0.0,"knock":0.0}
	var firing = timing_fixture([],forward)
	clock_step(firing)
	check(firing._core.projectiles_snapshot().is_empty(), "射撃間隔の直前は撃たない")
	clock_step(firing)
	check(firing._core.projectiles_snapshot().size()==1 and absf(firing._core.forward_snapshot().elapsed-1.0/150.0)<1e-9, "間隔を跨いだ負の余りを次へ繰り越す")
	check(firing._core.set_forward_level(2), "発射待ちを保って間隔を変える")
	clock_step(firing)
	check(firing._core.projectiles_snapshot().size()==1, "間隔変更で発射待ちを戻さない")
	clock_step(firing)
	check(firing._core.projectiles_snapshot().size()==2, "変更した周期で次の一発を撃つ")
	var busy := Intent.new()
	busy.press = true
	busy.pen = firing.read_frame().value.ui.ship.ship_pos
	clock_step(firing,busy)
	var elapsed: float = firing._core.forward_snapshot().elapsed
	busy.press = false
	for i in range(16): clock_step(firing,busy)
	check(firing._core.forward_snapshot().recoil==0.0 and firing._core.forward_snapshot().elapsed==elapsed, "発射休止中も反動の残り時間を0で止める")
	firing.dispose()
	forward.interval_by_level = [0.001]
	var short_interval = timing_fixture([],forward)
	clock_step(short_interval)
	check(short_interval._core.projectiles_snapshot().size()==1 and absf(short_interval._core.forward_snapshot().elapsed-fmod(1.0/120.0,0.001))<1e-9, "W01は複数周期を跨いでも一度だけ撃ち、端数を残す")
	short_interval.dispose()
	var deadline = timing_fixture()
	var enemy: int = combat_enemy(deadline)
	check(deadline._core.request_attack("期限",PackedStringArray(["zone"]),enemy,0.1,0.0,1.0), "期限付きの攻撃を予約する")
	check(deadline._core.advance_attack_budget(0.1-1e-12) and deadline._core.owns_attack("期限",enemy), "期限の手前では所有を保つ")
	check(deadline._core.advance_attack_budget(0.1) and not deadline._core.owns_attack("期限",enemy), "期限ちょうどで攻撃の所有を外す")
	deadline.dispose()
	# seed42の最初のPCG32出力3270867926。境界そのものは次の重みへ進む。
	var roll := 3270867926.0/4294967296.0
	for delta in [0.0,-1.0/4294967296.0,1.0/4294967296.0]:
		var marker := {"type":"drifter","offset":Vector2.ZERO,"rotation":0.0}
		var formations := [{"version":2,"entries":[{"weight":roll+delta,"pos":Vector2(-100,0)},{"weight":1.0-roll-delta,"pos":Vector2(100,0)}],
			"layouts":[{"weight":1.0,"value":-1.0,"types":["drifter"],"placements":[[marker],[marker]]}]}]
		var weighted = timing_fixture(formations)
		var ship: Vector2 = weighted.read_frame().value.ui.ship.ship_pos
		check(weighted._core.set_motion_context(ship,Vector2.ZERO,Vector2(1000,1000)), "重み境界の配置領域を設定する")
		var ids: PackedInt64Array = weighted._core.spawn_formation(0,0,-1,PackedStringArray(),-1.0,null,null)
		check(ids.size()==1, "重みで配置を一つ選ぶ")
		var expected: float = -100.0 if delta>0 else 100.0
		check(absf(float(weighted._core.enemies_snapshot()[0].pos[0])-ship.x-expected)<1e-5, "抽選の重みを引いた値が0のときは次へ進む")
		weighted.dispose()
	return true

func render_batch(frame: Dictionary, id: int) -> Dictionary:
	for batch: Dictionary in frame.batches:
		if batch.visual_id==id: return batch
	return {}

func check_run_render(enemies_only := false) -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.world_tick_div = 1
	config.kill_hitstop = 0.0
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.stage_hp = 1.0
	definition.armor = 0.0
	definition.speed = 30.0
	definition.xp_reward_counts = PackedInt32Array([1,0,0])
	var stage := RuntimeStage.new()
	stage.index = 80
	stage.enemy_tuning = {"drifter":{"hp":1.0}}
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_render"
	if builder.build(stage,config,output,"表示経路の固定入力".sha256_text(),{&"drifter":definition})!=OK: return false
	var path := output.path_join("stage_80.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":42},true)
	session.auto_step = false
	if session.bridge==null or session.view==null: return false
	var bridge = session.bridge
	clock_step(bridge)
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	if enemies_only:
		var ship_position: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
		bridge.command("dev_spawn",{"definition_id":"drifter","position":ship_position+Vector2(100,0)})
		await get_tree().process_frame
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
		check(presentation.frame_view.batches.has(6) and presentation.frame_view.batches[6].multimesh.visible_instance_count==1,"追跡敵の画像を通常画面のMultiMeshへ投入する")
		if DisplayServer.get_name()!="headless": get_viewport().get_texture().get_image().save_png("/tmp/speed-cpp-r04-enemies.png")
		session.free()
		return true
	check(presentation.frame_view!=null and presentation.frame_view.parts.size()==2,"通常画面が機体とW01の砲身を表示する")
	var camera: Dictionary = bridge.read_frame().value.camera
	var viewport := Rect2(camera.center-Vector2(250,180),Vector2(500,360))
	var position: Vector2 = camera.center+Vector2(100,0)
	var entity: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":position}).value
	var initial: Dictionary = bridge.read_render(viewport,1.0).value
	check(render_batch(initial,6).ids.has(entity),"生成直後の敵を表示する")
	clock_step(bridge)
	var before: Dictionary = bridge._core.inspect()
	var old: Dictionary = bridge.read_render(viewport,0.0).value
	var half: Dictionary = bridge.read_render(viewport,0.5).value
	var current: Dictionary = bridge.read_render(viewport,1.0).value
	var t0: PackedFloat32Array = render_batch(old,6).transforms
	var t1: PackedFloat32Array = render_batch(current,6).transforms
	var th: PackedFloat32Array = render_batch(half,6).transforms
	check(absf(t0[4]-position.x)<0.001 and absf(th[4]-(t0[4]+t1[4])*0.5)<0.001,"表示だけで前回と今回の座標を補間する")
	check(before==bridge._core.inspect() and render_batch(old,6).transforms==t0,"表示の読取は戦闘状態と保持中の配列を変更しない")
	for batch: Dictionary in current.batches:
		check(batch.ids.size()*6==batch.transforms.size() and batch.colors.size()==batch.ids.size() and batch.flags.size()==batch.ids.size(),"表示のPacked配列の長さが一致する")
	var radius: float = bridge._core.enemies_snapshot()[0].radius
	var edge: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(viewport.end.x+radius*0.5,viewport.get_center().y)}).value
	var outside: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(viewport.end.x+radius*4.0,viewport.get_center().y)}).value
	var visible: Dictionary = bridge.read_render(viewport,1.0).value
	check(render_batch(visible,6).ids.has(edge) and not render_batch(visible,6).ids.has(outside),"画面端に重なる敵を残し、離れた敵だけを表示から外す")
	var bad := visible.duplicate(true)
	bad.batches[0].transforms = PackedFloat32Array([0.0])
	check(not presentation.frame_view.apply_frame(bad),"長さの壊れた表示データを投入しない")
	for id in [entity,edge,outside]: bridge.command("dev_remove",{"entity_id":id})
	for i in range(49): clock_step(bridge)
	var shots: Array = bridge._core.projectiles_snapshot()
	check(not shots.is_empty(),"生成したW01の定義から発射する")
	if shots.is_empty(): return false
	var shot: Dictionary = shots.back()
	var target: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":shot.pos+shot.vel.normalized()*8.0}).value
	clock_step(bridge)
	var events: Array = bridge.read_frame().value.events
	check(events.any(func(e): return e.type==&"shot_hit") and events.any(func(e): return e.type==&"kill" and e.get("id")==target),"W01の命中から共通撃破へ進む")
	presentation._present_cpp(0.0)
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/speed-cpp-r04-scene.png")
	check(presentation.frame_view.batches.has(3),"撃破後の結晶を通常画面へ渡す")
	print("[run_render] build_us=%d submit_us=%d" % [presentation.frame_view.build_us,presentation.frame_view.submit_us])
	var world: WeakRef = weakref(session.view.get_node("World"))
	session.free()
	await get_tree().process_frame
	check(world.get_ref()==null and not bridge.read_render(viewport,1.0).ok,"解放したランの表示と資源を残さない")
	return true

func attack_fixture():
	var config: GameConfig = ContentManager.base.duplicate(true)
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.speed = 0.0
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.compile_chase(definition,config,schema.sha256("攻撃所有の固定入力".to_utf8_buffer()))
	check(bridge.configure(bytes,{"api_version":1,"run_id":71,"mode":1,"stage_id":"attack","profile":{},"settings":{}}).ok,"攻撃所有の固定条件を設定する")
	check(bridge._core.configure_bite_zone({"version":1,"duration":0.5,"hit":false,"fade":false,"scene":"res://scenes/attacks/zone.tscn"}),"範囲攻撃の寿命を設定する")
	check(bridge.start(42).ok,"攻撃所有の固定場面を開始する")
	return bridge

func owned_attack(bridge, options: Dictionary) -> Dictionary:
	var args := {"pool":1,"position":Vector2(1000,500),"life":0.3,"policies":1}
	args.merge(options,true)
	var result: Dictionary = bridge.command("dev_emit_attack",args)
	check(result.ok,"所有・終了条件を指定して実際の攻撃を出す")
	return result.value if result.ok else {}

func attack_ids(bridge) -> Array:
	return bridge._core.attack_snapshot().map(func(a): return a.id)

func budget_has(bridge, token: int) -> bool:
	return bridge._core.attack_budget_snapshot().groups.any(func(g): return g.token==token)

func check_attack_owners() -> bool:
	var run = attack_fixture()
	var owner: int = combat_enemy(run,Vector2(900,500))
	check(run._core.request_attack("残留",PackedStringArray(["bullet"]),owner,0.05,0.0,1.0),"残留攻撃の予算を確保する")
	var token: int = run._core.attack_token("残留")
	var first := owned_attack(run,{"owner_id":owner,"budget":token,"life":0.1})
	var second := owned_attack(run,{"owner_id":owner,"budget":token,"life":0.1})
	var attached := owned_attack(run,{"pool":2,"owner_id":owner,"budget":token,"attached":true,"policies":8})
	check(run._core.attack_snapshot()[0].residuals==3,"同じ予算の残留参照を生成時に増やす")
	check(run.command("dev_kill",{"entity_id":owner}).value.killed,"発生元を撃破する")
	var active: Array = run._core.attack_snapshot()
	check(active.size()==2 and active.all(func(a): return a.source_id==owner and not a.source_alive and a.residuals==2),"発生元の生存参照を切り、残留弾の予算を保つ")
	check(not attack_ids(run).has(attached.id),"発生元に付いた範囲だけを死亡時に外す")
	check(run._core.advance_attack_budget(0.1) and budget_has(run,token),"発生元と予告が終わっても残留弾が枠を保つ")
	check(run.command("dev_end_attack",{"handle":first.handle}).value,"一つ目の残留弾を終了する")
	check(run._core.attack_snapshot()[0].residuals==1,"一つ残っている間は予算を保つ")
	check(not run.command("dev_end_attack",{"handle":first.handle}).value,"二度目の終了で参照を減らさない")
	check(run._core.step_hostiles(0.2) and run._core.attack_snapshot().is_empty(),"最後の弾を自然寿命で回収する")
	check(run._core.advance_attack_budget(0.2) and not budget_has(run,token),"所定の予算更新で最後の保持を解放する")
	var replacement := owned_attack(run,{})
	check(replacement.id>second.id and not run.command("dev_end_attack",{"handle":second.handle}).value and attack_ids(run).has(replacement.id),"再利用した攻撃へ古い参照を適用しない")
	run.dispose()
	var scoped = attack_fixture()
	var scope := PackedInt64Array([7,1])
	var entries := {}
	for flags in [1,2,4,8,16,32]: entries[flags] = owned_attack(scoped,{"policies":flags,"technique":scope,"participant":scope,"boss":scope})
	scoped.command("dev_attack_scope",{"event":"technique_end","handle":PackedInt64Array([7,2])})
	check(attack_ids(scoped).size()==6,"世代の違う技の終了を適用しない")
	scoped.command("dev_attack_scope",{"event":"technique_end","handle":scope})
	check(not attack_ids(scoped).has(entries[4].id) and attack_ids(scoped).has(entries[2].id),"技の自然終了は取消時だけ消す攻撃を残す")
	scoped.command("dev_attack_scope",{"event":"technique_cancel","handle":scope})
	check(not attack_ids(scoped).has(entries[2].id) and attack_ids(scoped).has(entries[1].id),"技の取消でも通常の残留弾を残す")
	scoped.command("dev_attack_scope",{"event":"participant_end","handle":scope})
	check(not attack_ids(scoped).has(entries[8].id),"参加者終了の条件を独立して適用する")
	scoped.command("dev_attack_scope",{"event":"boss_end","handle":scope})
	check(not attack_ids(scoped).has(entries[16].id) and attack_ids(scoped).has(entries[32].id),"ボス終了とボーナス消去を混同しない")
	scoped.command("dev_attack_scope",{"event":"bonus"})
	check(attack_ids(scoped)==[entries[1].id],"ボーナスで指定した攻撃だけを消す")
	check(scoped._core.step_hostiles(0.5) and scoped._core.attack_snapshot().is_empty(),"通常の残留弾を寿命まで進める")
	scoped.dispose()
	var moving = attack_fixture()
	owner = combat_enemy(moving,Vector2(900,500))
	var fixed := owned_attack(moving,{"pool":2,"owner_id":owner,"attached":true})
	var flying := owned_attack(moving,{"owner_id":owner})
	moving.command("dev_attack_scope",{"event":"relocate","owner_id":owner})
	check(not attack_ids(moving).has(fixed.id) and attack_ids(moving).has(flying.id),"再配置は付いた攻撃を消し、飛んでいる弾を残す")
	moving.dispose()
	var clearing = attack_fixture()
	owned_attack(clearing,{"pool":1})
	owned_attack(clearing,{"pool":2})
	check(clearing.command("dev_attack_update",{"begin":true}).ok,"敵弾の更新手順を開始する")
	check(clearing.command("dev_clear_hostile").ok,"更新中の全消去を受け付ける")
	check(clearing._core.hostiles_snapshot().size()==1 and clearing._core.hazards_snapshot().is_empty(),"範囲は即時、更新中の敵弾は更新後に回収する")
	owned_attack(clearing,{"pool":1})
	check(clearing.command("dev_attack_update",{"begin":false}).ok and clearing._core.attack_snapshot().is_empty(),"更新中に増えた敵弾も最後の全消去で回収する")
	clearing.dispose()
	var hazards = attack_fixture()
	owned_attack(hazards,{"pool":2,"life":0.5})
	owned_attack(hazards,{"pool":2,"life":0.5})
	hazards.command("pause",{"paused":true})
	check(hazards._core.step_hazards(0.1),"ランが止まった範囲更新を受け付ける")
	var zones: Array = hazards._core.hazards_snapshot()
	check(zones.size()==2 and is_equal_approx(zones[0].time,0.1) and zones[1].time==0.0 and not zones[0].hit,"hazardのfalseで残り全体を打ち切る")
	hazards.dispose()
	return true

func check_run_events() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.world_tick_div = 1
	config.kill_hitstop = 0.0
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.stage_hp = 1.0
	definition.armor = 0.0
	definition.speed = 0.0
	var bridge = clock_fixture(config,definition)
	if not bridge.has_method("collect_frame"):
		bridge.dispose()
		return false
	var view = load("res://scripts/render/run_frame_view.gd").new()
	var recorder = load("res://scripts/dev/play_recorder.gd").new()
	# 実際の録画の書込経路を独立した一時ファイルへつなぐ。
	recorder._cpp_session_id = 51
	recorder._file = FileAccess.open("/tmp/speed-cpp-m02-events.jsonl",FileAccess.WRITE)
	var received := [[],[],[]]
	var reject := [false]
	var reentry := []
	var callbacks := [view.receive_frame,AudioManager.consume_cpp_frame,recorder.consume_cpp_frame]
	for i in range(3):
		var consumer: Callable = callbacks[i]
		check(bridge.subscribe("受信%d" % i,func(frame: Dictionary) -> bool:
			if i==2 and reject[0]: return false
			received[i].append(frame.duplicate(true))
			reentry.append(bridge.command("pause",{"paused":true}).code)
			return consumer.call(frame)),"表示・音・録画を同じ窓口へ登録する")
	check(bridge.collect_frame().ok,"初期通知を全購読者へ配信する")
	for i in range(60): clock_step(bridge)
	var shots: Array = bridge._core.projectiles_snapshot()
	if shots.is_empty():
		bridge.dispose()
		view.free()
		recorder._file.close()
		recorder._file = null
		recorder.free()
		return false
	var shot: Dictionary = shots.back()
	var target: int = combat_enemy(bridge,shot.pos+shot.vel.normalized()*8.0)
	# 一購読者が受理しなければ、受理済みの相手を重複配信せず再送する。
	reject[0] = true
	var response: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	check(response.ok and not bridge.read_frame().value.events.is_empty(),"更新成功を再実行させず、受理待ち通知を保持する")
	var raw: Dictionary = bridge._core.frame_run()
	check(raw==bridge._core.frame_run(),"複数回の読取で通知とUI差分を消費しない")
	var pending: Array = raw.value.events
	var last: int = pending.back().sequence
	check(bridge.ack_frame(bridge._epoch,last+1).code==1,"未公開番号のackを拒否する")
	var counts := [received[0].size(),received[1].size()]
	reject[0] = false
	check(bridge.collect_frame().ok and bridge.read_frame().value.events.is_empty(),"全員の受理後に通知を解放する")
	check(counts==[received[0].size(),received[1].size()],"再送では受領済みの購読者を重複配信しない")
	for rows: Array in received:
		var hits := []
		for frame: Dictionary in rows:
			for event: Dictionary in frame.events:
				if event.type==&"hit" and event.payload.id==target: hits.append(event)
		check(hits.size()==1,"一命中を各購読者が一度だけ受ける")
		if hits.size()==1: check(hits[0].tick==61 and hits[0].has("t") and hits[0].has("world_t"),"命中時刻と完了固定更新番号を持つ")
	check(received[0]==received[1] and received[1]==received[2],"全購読者が同じ通知batchを受ける")
	check(reentry.all(func(code): return code==7),"配信中の更新命令を拒否する")
	check(bridge.ack_frame(bridge._epoch,last).code==3,"重複ackを拒否する")
	var metrics: Dictionary = bridge.read_metrics()
	check(metrics.ok and metrics==bridge.read_metrics() and metrics.value.events_emitted==metrics.value.events_acked,"複数計測者の読取で累積値をresetしない")
	var saved: int = bridge.checkpoint().value
	var epoch: int = bridge._epoch
	check(bridge.restore(saved).ok and bridge.ack_frame(epoch,last).code==3,"復帰前のepochのackを拒否する")
	check(bridge.read_metrics().value.events_emitted==metrics.value.events_emitted,"復帰で観測の累積値を巻き戻さない")
	bridge.release_checkpoint(saved)
	var core = bridge._core
	check(bridge.dispose().ok and not bridge.read_frame().ok and not bridge.read_metrics().ok and not core.frame_run().ok and not core.ack_frame_run(epoch,last).ok,"破棄後の読取とackを拒否する")
	recorder._file.flush()
	recorder._file.close()
	recorder._file = null
	var recorded_hits := 0
	for line in FileAccess.get_file_as_string("/tmp/speed-cpp-m02-events.jsonl").split("\n",false):
		var row: Dictionary = JSON.parse_string(line)
		if row.type=="hit" and row.payload.id==target: recorded_hits += 1
	check(recorded_hits==1,"録画ファイルにも一命中を一度だけ残す")
	recorder._cpp_session_id = 0
	recorder.free()
	view.free()
	return true

func contact_attack(bridge, definition: int, owner: int = 0, pool: int = 1) -> PackedInt64Array:
	var result: Dictionary = bridge.command("dev_emit_attack",{"pool":pool,"position":Vector2(10000,0),"contact_definition":definition,"cause":"rain","owner_id":owner})
	check(result.ok,"型付きの接触定義から攻撃を生成する")
	return result.value.handle if result.ok else PackedInt64Array()

func contact_query(bridge, definition: int, shape: Dictionary, expected: bool, label: String) -> void:
	var handle := contact_attack(bridge,definition)
	var payload := shape.duplicate(true)
	payload.handle = handle
	var result: Dictionary = bridge.command("dev_contact",payload)
	check(result.ok and result.value.touching==expected,label)
	if definition in range(10,17): check(result.ok and result.value.half_width==1.0,"全幅から片側幅への変換を生成時に一度だけ行う")
	bridge.command("dev_end_attack",{"handle":handle})

func check_contact_geometry(sweep_only := false) -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 0.0
	config.world_tick_div = 1
	config.invuln_time = 0.0
	config.atk_scale = 2.0
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	var records: Dictionary = builder.chase_records(definition,config)
	for kind in range(7): records.ContactDefinition.append({"id":10+kind,"shape":kind,"scale":0,"hit_policy":3,"add_ship_radius":false,"ship_sweep":false,"width":2.0})
	for entry in [[30,true,false],[31,false,true],[32,false,false]]:
		records.ContactDefinition.append({"id":entry[0],"shape":0,"scale":0,"hit_policy":3,"add_ship_radius":entry[1],"ship_sweep":entry[2],"width":0.0})
	for policy in range(4): records.ContactDefinition.append({"id":40+policy,"shape":0,"scale":0,"hit_policy":policy,"add_ship_radius":false,"ship_sweep":false,"width":0.0})
	records.ContactDefinition.append({"id":44,"shape":0,"scale":1,"hit_policy":3,"add_ship_radius":false,"ship_sweep":false,"width":0.0})
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = schema.write_content(records,"形状の固定入力".sha256_buffer())
	check(bridge.configure(bytes,{"api_version":1,"run_id":81,"mode":1,"stage_id":"geometry","profile":{},"settings":{}}).ok and bridge.start(42).ok,"形と倍率・一回制限を共通スキーマから読む")
	if sweep_only:
		check_contact_sweep(bridge)
		bridge.dispose()
		return true
	contact_query(bridge,10,{"center":Vector2(2,0),"radius":2.0},true,"円の境界は当たる")
	contact_query(bridge,10,{"center":Vector2(2.001,0),"radius":2.0},false,"円の外側は当たらない")
	contact_query(bridge,11,{"points":PackedVector2Array([Vector2(-5,1),Vector2(5,1)])},true,"線分の片側幅の境界は当たる")
	contact_query(bridge,11,{"points":PackedVector2Array([Vector2(-5,1.001),Vector2(5,1.001)])},false,"線分の片側幅の外は当たらない")
	contact_query(bridge,12,{"before":PackedVector2Array([Vector2(-2,-2),Vector2(2,-2)]),"points":PackedVector2Array([Vector2(-2,2),Vector2(2,2)])},true,"移動した線分が作る四角形の内側を拾う")
	contact_query(bridge,13,{"points":PackedVector2Array([Vector2(-3,1),Vector2.ZERO,Vector2(3,1)])},true,"折れ線の各区間と頂点を拾う")
	contact_query(bridge,14,{"center":Vector2(-2,0),"radius":2.0,"angle":0.0,"arc":0.0},true,"扇の半径と角度の境界は当たる")
	contact_query(bridge,14,{"center":Vector2(-2,0.01),"radius":3.0,"angle":0.0,"arc":0.0},false,"扇の角度の外は当たらない")
	contact_query(bridge,15,{"center":Vector2(-4,0),"radius":3.0},true,"輪の外側の境界は当たる")
	contact_query(bridge,15,{"center":Vector2(-2,0),"radius":3.0},true,"輪の内側の境界は当たる")
	contact_query(bridge,15,{"center":Vector2(-1.999,0),"radius":3.0},false,"輪の内側の空洞は当たらない")
	contact_query(bridge,15,{"center":Vector2(-3,0),"radius":3.0,"gap_angle":0.0,"gap_arc":0.2},false,"輪の切れ目では当たらない")
	contact_query(bridge,16,{"center":Vector2(1,0),"half":Vector2.ONE},true,"矩形の境界は当たる")
	contact_query(bridge,16,{"center":Vector2(1.001,0),"half":Vector2.ONE},false,"矩形の外は当たらない")
	contact_query(bridge,10,{"center":Vector2(1.0+config.ship_radius,0),"radius":1.0},false,"機体半径を足さない攻撃を保つ")
	contact_query(bridge,30,{"center":Vector2(1.0+config.ship_radius,0),"radius":1.0},true,"機体半径を足す攻撃の境界を拾う")
	var owner: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(10000,10000)}).value
	for policy in range(4):
		var attack := contact_attack(bridge,40+policy,owner)
		bridge.command("pause",{"paused":true})
		var data := {"handle":attack,"radius":1.0,"amount":2.0,"apply":true}
		var refused: Dictionary = bridge.command("dev_contact",data)
		check(refused.ok and refused.value.attempted and not refused.value.damage.accepted and refused.value.damage.reason=="run_phase","拒否された被弾試行も共通経路で記録する")
		bridge.command("pause",{"paused":false})
		var again: Dictionary = bridge.command("dev_contact",data)
		check(again.ok and again.value.attempted==(policy>=2),"当たり済みにする条件を攻撃ごとに保つ")
		var third: Dictionary = bridge.command("dev_contact",data)
		check(third.ok and third.value.attempted==(policy==3),"every_tickだけは繰り返し判定する")
		bridge.command("dev_end_attack",{"handle":attack})
	var scaled := contact_attack(bridge,44,owner)
	var result: Dictionary = bridge.command("dev_contact",{"handle":scaled,"radius":1.0,"amount":3.0,"apply":true})
	check(result.ok and result.value.damage.amount==6.0 and result.value.damage.hp_before-result.value.damage.hp_after==6.0,"定義が選んだ攻撃だけatk_scaleを掛ける")
	var damage_events: Array = bridge.read_frame().value.events.filter(func(e):return e.type==&"combat_player_damage")
	check(damage_events.size()==8 and damage_events.all(func(e):return e.payload.cause==&"rain" and e.payload.source==&"drifter"),"原因名・発生元・実HP減少と拒否理由を同じ通知へ残す")
	bridge.command("dev_end_attack",{"handle":scaled})
	check_contact_sweep(bridge)
	bridge.dispose()
	return true

func check_contact_sweep(bridge) -> void:
	var from: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
	var sweep_attack := contact_attack(bridge,31,0,0)
	var point_attack := contact_attack(bridge,32,0,0)
	clock_step(bridge)
	clock_step(bridge)
	var to: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
	for entry in [[sweep_attack,true],[point_attack,false]]:
		var response: Dictionary = bridge.command("dev_contact",{"handle":entry[0],"center":from.lerp(to,0.25),"radius":0.0001})
		check(response.ok and response.value.touching==entry[1],"前の判定位置から機体を掃引し、点判定の攻撃は通過を拾わない")
		bridge.command("dev_end_attack",{"handle":entry[0]})

func choice_fixture(initial := false) -> Dictionary:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.xp_base = 10.0
	config.xp_growth = 0.0
	config.xp_curve = 0.0
	config.levelup_bonus_chance = 0.0
	config.reroll_count = 3
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var definition: EnemyDef = ContentManager.enemies[&"drifter"]
	var records: Dictionary = builder.chase_records(definition,config)
	var bytes: PackedByteArray = schema.write_content(records,schema.sha256("カードと準備の固定入力".to_utf8_buffer()))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	if not bridge.configure(bytes,{"api_version":1,"run_id":58,"mode":1,"stage_id":"choice","profile":{},"settings":{}}).ok: return {}
	if not bridge.start(41,{"equipment":[]} if initial else {}).ok: return {}
	var assets = load("res://tools/content/run_resources.gd").new()
	for row: Dictionary in builder.chase_package(definition,config).visuals:
		if not row.path.is_empty():
			assets.keys[row.id] = row.path
			assets.order.append(row.path)
	return {"bridge":bridge,"resources":assets}

func check_run_choices() -> bool:
	var fixture := choice_fixture()
	if fixture.is_empty(): return false
	var bridge = fixture.bridge
	check(bridge.command("dev_add_xp",{"amount":10.0}).ok,"最終取得XPをC++の成長へ渡す")
	clock_step(bridge)
	var ui: Dictionary = bridge.read_frame().value.ui
	check(ui.level==1 and ui.xp==0 and ui.cards.candidates.size()==1 and ui.weapon_levels[0].level==1,"経験値からカードを開き、選択前は装備を変えない")
	var offer: int = ui.cards.offer_id
	var candidate: int = ui.cards.candidates[0].candidate_id
	var request: int = ui.cards.candidates[0].request_id
	check(bridge.command("choose_card",{"offer_id":offer,"candidate_id":candidate}).ok,"準備中の選択は保持する")
	clock_step(bridge)
	check(bridge.read_frame().value.ui.weapon_levels[0].level==1,"準備中は確定しない")
	check(bridge.command("resources_complete",{"request_id":request,"status":-1}).ok,"準備の失敗を記録する")
	ui = bridge.read_frame().value.ui
	check(ui.cards.selected_id==candidate and ui.cards.error_code==-1,"失敗時も同じ候補と選択を保持する")
	check(bridge.command("retry_resources",{"request_id":request}).ok,"同じ候補で準備を再試行する")
	ui = bridge.read_frame().value.ui
	var retry: int = ui.cards.candidates[0].request_id
	check(retry>request and ui.cards.offer_id==offer and ui.cards.selected_id==candidate,"再試行は新要求番号だけを発行する")
	check(not bridge.command("resources_complete",{"request_id":request,"status":1}).ok,"失敗した旧要求への遅い成功を拒否する")
	check(bridge.command("pause",{"paused":true}).ok,"準備中のカード画面を停止する")
	check(bridge.command("resources_complete",{"request_id":retry,"status":1}).ok,"停止中も成功の到着を記録する")
	clock_step(bridge)
	check(bridge.read_frame().value.ui.weapon_levels[0].level==1,"停止中の成功で装備を確定しない")
	bridge.command("pause",{"paused":false})
	bridge.command("set_ui_overlay",{"active":true})
	clock_step(bridge)
	check(bridge.read_frame().value.ui.weapon_levels[0].level==1,"UI停止中も確定しない")
	bridge.command("set_ui_overlay",{"active":false})
	bridge.command("set_ui_reward",{"active":true})
	clock_step(bridge)
	check(bridge.read_frame().value.ui.weapon_levels[0].level==1,"報酬演出中も確定しない")
	bridge.command("set_ui_reward",{"active":false})
	clock_step(bridge)
	ui = bridge.read_frame().value.ui
	check(ui.weapon_levels[0].level==2 and ui.cards.offer_id==0 and ui.phase==RunState.Phase.PLAY,"停止条件を通過したLEVELUPで一度だけ確定し戦闘へ戻る")
	check(not bridge.command("choose_card",{"offer_id":offer,"candidate_id":candidate}).ok and not bridge.command("resources_complete",{"request_id":retry,"status":1}).ok,"確定後の重複選択と通知で二重取得しない")
	bridge.command("dev_add_xp",{"amount":10.0})
	clock_step(bridge)
	ui = bridge.read_frame().value.ui
	offer = ui.cards.offer_id
	request = ui.cards.candidates[0].request_id
	bridge.command("choose_card",{"offer_id":offer,"candidate_id":candidate})
	check(bridge.command("cancel_choice",{"offer_id":offer}).ok,"未確定の選択を取り消す")
	check(bridge.read_frame().value.ui.cards.selected_id==0 and bridge.read_frame().value.ui.cards.offer_id==offer,"取消は装備や候補を消さない")
	check(bridge.command("reroll",{"offer_id":offer}).ok,"カードを引き直す")
	check(bridge.read_frame().value.ui.cards.offer_id>offer and not bridge.command("resources_complete",{"request_id":request,"status":1}).ok,"引き直し前の要求を無効にする")
	var saved: Dictionary = bridge.checkpoint()
	request = bridge.read_frame().value.ui.cards.candidates[0].request_id
	check(saved.ok and bridge.restore(saved.value).ok,"選択画面の保持点へ復帰する")
	check(bridge.read_frame().value.ui.cards.candidates[0].request_id>request,"復帰では到着状態を戻さず資源を新しく要求する")
	bridge._core.release_checkpoint(saved.value)
	bridge.dispose()
	check(not bridge.command("resources_complete",{"request_id":request,"status":1}).ok,"退出後に到着した通知を拒否する")
	return check_choice_scopes()

func check_choice_scopes() -> bool:
	var fixture := choice_fixture(true)
	if fixture.is_empty(): return false
	var bridge = fixture.bridge
	var owner = load("res://scripts/runtime/run_choice_resources.gd").new()
	var prepared: Array[ContentResourceScope] = []
	owner.prepare = func(_paths: PackedStringArray):
		var scope := ContentResourceScope.new()
		scope.pending.append("準備待ち")
		prepared.append(scope)
		return scope
	owner.attach(bridge,fixture.resources,self)
	check(bridge.collect_frame().ok,"通常の資源購読口へカードを届ける")
	owner.poll()
	check(owner.candidates.size()==1 and owner.equipped.is_empty(),"候補資源と確定装備の資源を区別する")
	var first: ContentResourceScope = prepared[0]
	var ui: Dictionary = bridge.read_frame().value.ui
	bridge.command("reroll",{"offer_id":ui.cards.offer_id})
	owner.poll()
	check(first.cancelled and owner.candidates.size()==1,"引き直しで古い候補Scopeだけ解放する")
	var selected: ContentResourceScope = prepared.back()
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.card_input_delay = 0.0
	add_child(hud)
	hud.apply_snapshot(bridge.read_frame().value.ui)
	check(hud._cards_box.visible and hud._cards_row.get_child_count()==1,"C++の候補を通常カード部品で表示する")
	hud._card_command(&"choose_card",{"index":0})
	ui = bridge.read_frame().value.ui
	check(ui.cards.selected_id!=0 and ui.weapon_levels.is_empty(),"HUDの選択は準備中のままC++へ届く")
	selected.provide("準備待ち",Resource.new())
	owner.poll()
	clock_step(bridge)
	owner.poll()
	check(owner.candidates.is_empty() and owner.equipped.get("weapon:W01")==selected and not selected.cancelled,"確定した装備のScopeだけをランへ移す")
	bridge.command("dev_add_xp",{"amount":10.0})
	clock_step(bridge)
	owner.poll()
	check(owner.candidates.size()==1 and owner.equipped["weapon:W01"]==selected,"取得済み装備の資源を候補へ貸して保持する")
	ui = bridge.read_frame().value.ui
	bridge.command("reroll",{"offer_id":ui.cards.offer_id})
	owner.poll()
	check(not selected.cancelled and owner.equipped["weapon:W01"]==selected,"貸したScopeは引き直しても解放しない")
	owner.close()
	check(selected.cancelled and owner.candidates.is_empty() and owner.equipped.is_empty(),"退出時に候補と装備を解放する")
	var late: ContentResourceScope = first
	late.provide("遅い到着",Resource.new())
	check(late.resources.is_empty(),"取消後のScopeは遅い資源を保持しない")
	hud.free()
	bridge.dispose()
	return true

func hound_row(bridge, id: int) -> Dictionary:
	for row: Dictionary in bridge._core.enemies_snapshot():
		if row.id==id: return row
	return {}

func hound_order(bridge, id: int, action: String, values := {}) -> bool:
	var payload: Dictionary = values.duplicate()
	payload.entity_id = id
	payload.action = action
	return bridge.command("dev_hound_order",payload).ok

func check_hound_groups(bite_only := false) -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.world_tick_div = 1
	config.start_radius = 0.0
	var definition: EnemyDef = ContentManager.enemies[&"hound"].duplicate(true)
	definition.params.pack_count = 3
	var bridge = clock_fixture(config,definition)
	var spawned: Dictionary = bridge.command("dev_spawn",{"definition_id":"hound","position":Vector2(500,500)})
	if not spawned.ok: return false
	var root: int = spawned.value
	if bite_only:
		check_hound_bite(bridge,root)
		bridge.dispose()
		return true
	var pack: Dictionary = bridge._core.hound_snapshot().packs[0]
	check(pack.id==root and pack.members.size()==3,"生成で親と随伴を同じ群れへ登録する")
	var member: int = pack.members[1]
	check(bridge.command("dev_kill",{"entity_id":pack.members[2]}).ok,"群れの一部を実撃破する")
	check(bridge._core.hound_snapshot().packs[0].members.size()==2,"撃破した構成員を一度だけ外す")
	check(hound_order(bridge,member,"follow",{"goal":Vector2(800,900),"until":5.0,"scale":1.7}),"個体への走行先を型付きで保持する")
	var saved: Dictionary = bridge.checkpoint()
	if not saved.ok: return false
	check(bridge.command("dev_remove",{"entity_id":root}).ok,"最初に生成した個体を失わせる")
	pack = bridge._core.hound_snapshot().packs[0]
	check(pack.id==root and pack.members==[member],"群れ番号は生存する親を必要としない")
	var row: Dictionary = hound_row(bridge,member)
	var at := Vector2(row.pos[0],row.pos[1])
	check(hound_order(bridge,member,"quiet",{"until":5.0,"velocity":Vector2.ZERO}),"噛みつきを始めない静止指示を受ける")
	clock_step(bridge)
	row = hound_row(bridge,member)
	check(Vector2(row.pos[0],row.pos[1]).is_equal_approx(at),"quietの速度指定でその場に止まる")
	check(hound_order(bridge,member,"release"),"個体への指示を解除する")
	check(bridge._core.hound_snapshot().follows.is_empty(),"解除で走行先も消す")
	var steering := {"arrive":20.0,"decel":500.0,"face_turn":5.0,"turn_slow":2.0,"turn_fast":7.0,"turn_switch":100.0,"max_speed":250.0,"accel":500.0}
	check(hound_order(bridge,member,"steer",{"goal":at+Vector2(0,200),"face":Vector2.ZERO,"until":5.0,"config":steering}),"到着・旋回・加減速の指示を受ける")
	check(hound_order(bridge,member,"mark",{"until":5.0}),"予告の期限を個体に付ける")
	clock_step(bridge)
	row = hound_row(bridge,member)
	check(Vector2(row.vel[0],row.vel[1]).length()>0.0,"操舵指示の向きへ加速する")
	var render: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	var glow_count := 0
	for batch: Dictionary in render.batches: glow_count += batch.get("glows",PackedFloat32Array()).size()/3
	check(glow_count==1,"指示された個体だけ予告の表示値を出す")
	check(bridge.restore(saved.value).ok,"群れと共有指示を保持点へ戻す")
	check(bridge._core.hound_snapshot().packs[0].members.size()==2 and bridge._core.hound_snapshot().follows.size()==1,"親・残る構成員・走行先を復帰する")
	var before: Array = bridge._core.enemies_snapshot()
	clock_step(bridge)
	var after: Array = bridge._core.enemies_snapshot()
	var groups: Dictionary = bridge._core.hound_snapshot()
	check(bridge.restore(saved.value).ok,"同じ保持点を再利用する")
	check(bridge._core.enemies_snapshot()==before,"保持点の値は更新側から独立している")
	clock_step(bridge)
	check(bridge._core.enemies_snapshot()==after and bridge._core.hound_snapshot()==groups,"復帰後も同じ指示と更新結果になる")
	check(hound_order(bridge,member,"release"),"復帰した個体の指示を解除する")
	check(bridge.command("dev_relocate",{"entity_id":member,"position":Vector2(50,0)}).ok,"再配置で群れを保つ")
	check(bridge._core.set_enemy_motion(member,{"slash_hold":true}),"閃光斬の停止条件を設定する")
	row = hound_row(bridge,member)
	at = Vector2(row.pos[0],row.pos[1])
	clock_step(bridge)
	row = hound_row(bridge,member)
	check(row.vel==[0.0,0.0] and Vector2(row.pos[0],row.pos[1])==at,"猟犬もslash_holdで移動と噛みつきを止める")
	bridge._core.set_enemy_motion(member,{"slash_hold":false})
	check_hound_bite(bridge,member)
	for id in bridge._core.hound_snapshot().packs[0].members.duplicate(): bridge.command("dev_remove",{"entity_id":id})
	check(bridge._core.hound_snapshot().packs.is_empty() and bridge._core.hound_snapshot().follows.is_empty(),"全員の離脱で群れと指示を破棄する")
	check(not hound_order(bridge,member,"mark",{"until":8.0}),"死亡した個体への古い指示を拒否する")
	var next: Dictionary = bridge.command("dev_spawn",{"definition_id":"hound","position":Vector2(700,700)})
	check(next.ok and next.value>root and bridge._core.hound_snapshot().follows.is_empty(),"行を再利用しても旧群れの指示を引き継がない")
	bridge._core.release_checkpoint(saved.value)
	bridge.dispose()
	return true

func check_hound_bite(bridge, member: int) -> void:
	var ship: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
	bridge.command("dev_relocate",{"entity_id":member,"position":ship+Vector2(50,0)})
	var observed: Array = []
	bridge.subscribe("hound_observe",func(frame: Dictionary):
		observed.append_array(frame.events)
		return true)
	var emitted := false
	var hazards := {}
	for tick in 90:
		clock_step(bridge)
		if not bridge._core.hazards_snapshot().is_empty(): emitted = true
		for attack: Dictionary in bridge._core.attack_snapshot():
			if attack.pool==2: hazards[attack.id] = true
	check(emitted,"共通の噛みつきの攻撃を生成する")
	var retired := false
	for event: Dictionary in observed:
		if event.type=="attack_retired" and hazards.has(event.payload.id) and event.payload.reason=="lifetime": retired = true
	check(retired,"噛みつきの攻撃を自然寿命で解放する")

func check_run_lifecycle(display_only := false) -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.death_freeze_time = 0.02
	config.death_explosion_time = 0.02
	config.death_game_over_time = 0.02
	var stage := RuntimeStage.new()
	stage.index = 1
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var builder = load("res://tools/content/build_run_content.gd")
	var output := "res://.content/dev/run_lifecycle"
	if builder.build(stage,config,output,"終了と保存の固定入力".sha256_text())!=OK: return false
	var index_path := output.path_join("stage_1.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var options := {"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":42,"manage_result":true}
	if display_only: return await check_death_display(options,config)
	var initial_runs := int(SaveManager.data.best.runs)
	var initial_clears := int(SaveManager.data.best.clears)
	var initial_coins := SaveManager.coins()
	var previous_id := 0
	for kind in ["Death","Abort","Clear"]:
		var session: RunSession = RunManager.create_session(self,options,true)
		session.auto_step = false
		if session.bridge==null: return false
		var bridge = session.bridge
		check(session.id>previous_id,"連続出撃で新しいランIDを使う")
		previous_id = session.id
		var terminal: Array = []
		session.cpp_finished.connect(func(value: Dictionary): terminal.append(value))
		bridge.command("pause",{"paused":true})
		bridge.command("pause",{"paused":false})
		check(bridge.read_frame().value.ui.phase==RunState.Phase.PLAY,"停止前のPLAYへ戻す")
		if kind=="Death":
			check(bridge.command("dev_ship_damage",{"amount":1000000.0,"cause":"shot"}).ok,"致死被弾を共通ダメージへ通す")
			clock_step(bridge)
			check(bridge.read_frame().value.ui.phase==RunState.Phase.DYING,"C++が敗北の演出へ移る")
			var frozen: Dictionary = bridge.read_frame().value.ui
			bridge.command("pause",{"paused":true})
			clock_step(bridge)
			bridge.command("pause",{"paused":false})
			check(bridge.read_frame().value.ui.phase==RunState.Phase.DYING,"停止前のDYINGへ戻す")
			for tick in 10: clock_step(bridge)
			check(bridge.read_frame().value.ui.run_time==frozen.run_time and bridge.read_frame().value.ui.world_time==frozen.world_time,"敗北の演出中に戦闘の時計を進めない")
		elif kind=="Abort":
			check(bridge.command("abort",{"reason":0}).ok,"中断結果を一度確定する")
		else:
			check(bridge.command("dev_finish",{"cleared":true}).ok,"通常クリアの確定境界を通す")
		var result: Dictionary = bridge.read_frame().value.result
		check(result.kind==kind and result.result_id>0 and bridge.read_frame().value.ui.phase==RunState.Phase.ENDED,"種類を区別したResultIdで終了する")
		check(not bridge.command("abort",{"reason":0}).ok and not bridge.command("dev_finish",{"cleared":true}).ok,"確定後の終了命令で結果を書き換えない")
		if kind=="Death": check(result.last_damage.cause=="shot" and result.last_damage.accepted,"最後の致死被弾を結果へ残す")
		check(terminal.is_empty(),"Bridge配信中に画面遷移を呼ばない")
		session.flush_cpp_result()
		bridge.collect_frame()
		session.flush_cpp_result()
		check(terminal.size()==1,"再表示と再通知で終了を二重送信しない")
		var runs := int(SaveManager.data.best.runs)
		var coins := SaveManager.coins()
		GameManager.finish_cpp_run(result)
		check(int(SaveManager.data.best.runs)==runs and SaveManager.coins()==coins,"同じ結果をGameManagerへ再通知しても報酬を増やさない")
		if kind=="Abort":
			check(not SaveManager.record_run(result) and runs==initial_runs+1 and coins==initial_coins,"中断は保存と報酬の対象にしない")
		else:
			check(not SaveManager.record_run(GameManager.last_result),"SaveManagerも同じResultIdを二重記録しない")
			var screen = load("res://scenes/app/result.tscn").instantiate()
			add_child(screen)
			check(screen.get_node("%Heading").text==tr("result.cleared" if kind=="Clear" else "result.failed"),"今の結果画面が終了結果を表示する")
			await get_tree().process_frame
			screen.free()
		var root_scope: ContentResourceScope = session.resources
		var closed: Array = []
		session.closing.connect(func(_reason: String):
			closed.append(bridge.read_frame().ok and not bridge.command("pause",{"paused":true}).ok and not root_scope.cancelled))
		var disposed_id := session.id
		session.free()
		check(closed==[true] and root_scope.cancelled and RunManager.session(disposed_id)==null,"受付停止と記録終端を資源解放より先に届け、最後に登録解除する")
		check(not bridge.read_frame().ok and bridge.dispose().ok,"解放後の旧窓口を使わせず繰返し解放も安全にする")
	check(int(SaveManager.data.best.runs)==initial_runs+2 and int(SaveManager.data.best.clears)==initial_clears+1,"3出撃のうち敗北とクリアだけ保存する")
	check(SaveManager.coins()==initial_coins+config.clear_bonus,"クリアの報酬を一度だけ保存する")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	check(int(disk.best.runs)==initial_runs+2 and int(disk.coins)==SaveManager.coins(),"独立セーブのファイルにも同じ結果を書き込む")
	return true

func check_death_display(options: Dictionary, config: GameConfig) -> bool:
	options.manage_result = false
	var session: RunSession = RunManager.create_session(self,options,true)
	session.auto_step = false
	if session.bridge==null: return false
	var bridge = session.bridge
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var hud = session.view.get_node("Hud/HudRoot")
	bridge.command("dev_ship_damage",{"amount":1000000.0,"cause":"shot"})
	clock_step(bridge)
	presentation._present_cpp(0.0)
	check(bridge.read_frame().value.ui.presentation_frozen and presentation.frame_view._dim_strength==config.death_world_dim,"敗北直後は演出を止め、生成値どおり暗くする")
	var any_visible := false
	for sprite: Sprite2D in presentation.frame_view.parts.values(): any_visible = any_visible or sprite.visible
	check(any_visible,"爆発前の機体は表示する")
	for tick in 3: clock_step(bridge)
	presentation._present_cpp(1.0/60.0)
	var all_hidden := true
	for sprite: Sprite2D in presentation.frame_view.parts.values(): all_hidden = all_hidden and not sprite.visible
	check(all_hidden and not bridge.read_frame().value.ui.presentation_frozen,"爆発時刻を越えたら機体を消し、演出時計だけ再開する")
	check(presentation.pipeline.sparks.available() or not presentation.frame_view._particles.is_empty(),"GPUまたは簡易表示で機体の爆発を描く")
	for tick in 3: clock_step(bridge)
	presentation._present_cpp(1.0/60.0)
	check(hud._banner==tr("hud.game_over"),"game_over通知をHUDへ表示する")
	await get_tree().process_frame
	session.free()
	return true

func check_run_assets(loading_only := false) -> bool:
	var stage := RuntimeStage.new()
	stage.index = 82
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var builder = load("res://tools/content/build_run_content.gd")
	var output := "res://.content/dev/run_assets"
	if builder.build(stage,ContentManager.base,output,"表示資源の固定入力".sha256_text())!=OK: return false
	var index_path := output.path_join("stage_82.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var loader = load("res://scripts/runtime/run_content_loader.gd")
	var bundle: Dictionary = loader.read_bundle(index_path,index.input_sha256)
	if bundle.is_empty(): return false
	var assets: Resource = bundle.resources
	if not loading_only:
		check(not bundle.bytes.hex_encode().contains("7265733a2f2f"),"C++のバイナリは資源パスを持たずキーだけを持つ")
		for path in ["res://assets/pixel/xp_crystal_facets.tres","res://assets/pixel/beamer/base.png","res://assets/pixel/beamer/armor.png",
			"res://assets/pixel/beamer/normal.png","res://assets/pixel/saw.png","res://assets/pixel/monoceros/horn/horn.tres",
			"res://assets/ui/combat/speed_indicator_meter.png"]:
			check(assets.dependencies.has(path),"必要な表示依存を生成時に追跡する: "+path)
		for key in ["weapon:W07","weapon:W29","trait:T03"]:
			check(assets.equipment.has(key) and not assets.equipment[key].is_empty(),"最新catalogの資源キーを持つ: "+key)
	else:
		check(assets.dependencies.has("res://assets/ui/combat/speed_indicator_meter.png"),"速度計のpreload画像を生成時に追跡する")
	var scene_position: int = assets.paths.find(RunSession.VIEW_PATH)
	var texture_position: int = assets.paths.find("res://assets/ui/combat/speed_indicator_meter.png")
	check(texture_position>=0 and texture_position<scene_position,"静的preloadの画像を画面Sceneより前に準備する")
	if not loading_only:
		check(loader.read_bundle(index_path,"0".repeat(64)).is_empty(),"古い入力署名の出撃を拒否する")
		var missing := "res://assets/pixel/beamer/normal.png"
		var bytes := FileAccess.get_file_as_bytes(missing)
		var temporary := ProjectSettings.globalize_path(missing)+".asset_check_hidden"
		check(DirAccess.rename_absolute(ProjectSettings.globalize_path(missing),temporary)==OK,"独立コピーだけで欠落条件を作る")
		check(loader.read_bundle(index_path,index.input_sha256).is_empty(),"生成後に欠けた画像を拒否し起動中に合成しない")
		DirAccess.rename_absolute(temporary,ProjectSettings.globalize_path(missing))
		check(FileAccess.get_file_as_bytes(missing)==bytes,"確認に使った元画像を戻す")
		var shader := "res://shaders/pixel_sprite.gdshader"
		var original := FileAccess.get_file_as_bytes(shader)
		var file := FileAccess.open(shader,FileAccess.WRITE)
		file.store_buffer(original)
		file.store_string("\n")
		file.close()
		check(loader.read_bundle(index_path,index.input_sha256).is_empty(),"shaderの古い依存署名を拒否する")
		file = FileAccess.open(shader,FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	var held := ContentResourceScope.new()
	held.pending.append("表示の準備待ち")
	var session := RunSession.new()
	session.cpp_prepare = func(_paths: PackedStringArray): return held
	add_child(session)
	check(session.start_cpp_content(index_path,index.input_sha256,42,true)==OK,"読込中のSessionを作る")
	var waiting: RefCounted = session._pending_cpp_bridge
	check(session.bridge==null and session.view==null and session._sim==null and not waiting.read_frame().ok,"資源準備前にはゲーム・表示・旧シミュレーションを開始しない")
	var old_id := session.id
	session.free()
	held.provide("表示の準備待ち",Resource.new())
	check(held.cancelled and held.resources.is_empty() and not waiting.read_frame().ok and RunManager.session(old_id)==null,"読込中取消と遅い到着を無効にする")
	if not loading_only:
		var lighting := "res://data/visuals/enemy_lighting.tres"
		var raw := FileAccess.get_file_as_bytes(lighting)
		var stamp := FileAccess.get_sha256(lighting)
		var first := ContentManager.prepare_resources(PackedStringArray([lighting]),false,{lighting:stamp})
		var second := ContentManager.prepare_resources(PackedStringArray([lighting]),false,{lighting:stamp})
		check(first.is_ready() and first.resources[lighting]==second.resources[lighting],"同じ版の再出撃は資源を共有する")
		var old_light: Resource = first.resources[lighting]
		var old_energy: float = old_light.key_energy
		var changed: Resource = old_light.duplicate(true)
		changed.key_energy = old_energy+0.25
		check(ResourceSaver.save(changed,lighting)==OK,"独立コピーだけで次の表示版を作る")
		var third := ContentManager.prepare_resources(PackedStringArray([lighting]),false,{lighting:FileAccess.get_sha256(lighting)})
		check(third.resources[lighting]!=old_light and third.resources[lighting].key_energy==old_energy+0.25 and old_light.key_energy==old_energy,"新しい版を取得しても旧Scopeの資源を書き換えない")
		third.cancel()
		check(not first.cancelled and first.resources[lighting]==old_light,"新しいScopeの取消は古い利用者を壊さない")
		var file := FileAccess.open(lighting,FileAccess.WRITE)
		file.store_buffer(raw)
		file.close()
		first.cancel()
		second.cancel()
	var live := RunSession.new()
	add_child(live)
	live.auto_step = false
	check(live.start_cpp_content(index_path,index.input_sha256,43,true)==OK,"準備済みの一覧から通常表示を開始する")
	for frame in 240:
		if live.bridge!=null or live.cpp_error!=OK: break
		await get_tree().process_frame
	check(live.bridge!=null and live.view!=null and live._sim==null,"資源とGPU準備の後でC++と表示だけを公開する")
	if live.bridge!=null: check(live.bridge.read_frame().value.tick==0,"準備中に戦闘の時間を消費しない")
	live.free()
	return true

func check_schema_section_ids() -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var records: Dictionary = builder.chase_records(ContentManager.enemies[&"drifter"],ContentManager.base)
	var bytes: PackedByteArray = schema.write_content(records,"区画番号の読込".sha256_buffer())
	check(not bytes.is_empty(),"既知の区画を共通スキーマから生成する")
	if bytes.is_empty(): return false
	var maximum := 0
	var count := int(bytes.decode_u32(16))
	for index in count: maximum=maxi(maximum,int(bytes.decode_u32(88+32*index)))
	print("[schema_section_ids] count=%d max_id=%d" % [count,maximum])
	var comparison = load("res://tools/compare_runtime.gd").new()
	var core = comparison.create_native()
	check(core.configure_content(bytes),"件数より大きい既知IDも生成形式に従って読み込む")
	core.close()
	var damaged := bytes.duplicate()
	damaged.encode_u32(88,0xffffffff)
	var invalid = comparison.create_native()
	check(not invalid.configure_content(resign_content(damaged,schema)),"未知IDは共通readerが拒否する")
	invalid.close()
	return true
