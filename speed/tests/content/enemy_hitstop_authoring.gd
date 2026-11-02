extends Node

const IO := preload("res://scripts/dev/stage_enemy_edit.gd")
const BUILD := preload("res://tools/content/build_runtime_stage.gd")
const FIELDS := preload("res://scripts/dev/stage_enemy_fields.gd")
const KEY := "hitstop_multiplier"
var failures := 0
var fixture_root := "res://.godot/hitstop-tests-%d" % OS.get_process_id()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(fixture_root)
	var common := IO.definition("drifter")
	check(KEY in StageEnemyTuning.keys_for(common), "敵種類の調整項目に停止時間倍率を公開")
	check(StageEnemyTuning.base_value(common, KEY, ContentManager.cfg) == 1.0, "未指定の共通値は1")
	check(FIELDS.category(KEY) == "ヒットストップ", "命中演出の分類に表示")
	for value in [0.0, 0.1, 1.0, 2.0]:
		check(IO.validate({"drifter": {KEY: value}}).is_empty(), "保存時に有効な倍率を受け付ける")
		var def := common.duplicate(true) as EnemyDef
		def.hitstop_multiplier = value
		var path := fixture_root.path_join("definition.tres")
		check(ResourceSaver.save(def, path) == OK, "共通の敵定義を書き出す")
		var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EnemyDef
		check(loaded.hitstop_multiplier == value, "共通定義のゼロ・既定・小数を再読込")
		DirAccess.remove_absolute(path)
	for value in [0.0, 1.0, 2.0]:
		var boss := load("res://data/bosses/draco.tres").duplicate(true) as BossDef
		boss.hitstop_multiplier = value
		var path := fixture_root.path_join("boss.tres")
		check(ResourceSaver.save(boss, path) == OK, "ボス定義を書き出す")
		check(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE).hitstop_multiplier == value, "ボス定義を再読込")
		DirAccess.remove_absolute(path)
	for bad in [-0.1, INF, NAN]:
		check(not IO.validate({"drifter": {KEY: bad}}).is_empty(), "ステージの不正な倍率を保存前に拒否")
	var source := ContentManager.stage(1).duplicate(true) as StageDef
	source.enemy_tuning = {}
	var stage_path := fixture_root.path_join("stage.tres")
	ResourceSaver.save(source, stage_path)
	var values := {"drifter": {KEY: 0.0}, "armored": {KEY: 0.25}}
	check(IO.save(stage_path, values, {}).has("stage"), "既存の保存境界から敵種類ごとの差分を保存")
	var saved := IO.read_stage(stage_path)
	check(saved.enemy_tuning == values, "保存したステージの倍率を再読込")
	var generated := BUILD.compile(saved)
	var generated_path := fixture_root.path_join("runtime.tres")
	check(generated != null and ResourceSaver.save(generated, generated_path) == OK, "正規変換で実行用ステージを生成")
	generated = ResourceLoader.load(generated_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RuntimeStage
	check(generated.enemy_tuning == values, "生成物の再読込で敵別倍率を保持")
	var run_session := RunManager.create_session(self, {"stage": generated, "seed": 42}, false)
	run_session.auto_step = false
	var enemies := run_session.sim.enemies
	var row := enemies.spawn(enemies.def_of(&"drifter"), Vector2(100, 100))
	check(enemies.table.def[row].hitstop_multiplier == 0.0, "生成済みステージから出現へ倍率を適用")
	check(enemies.def_of(&"armored").hitstop_multiplier == 0.25, "種類ごとに別の値を使用")
	check(enemies.def_of(&"swarm").hitstop_multiplier == 1.0, "未指定の種類は従来値のまま")
	enemies.update_stage_tuning({"drifter": {KEY: 0.5}})
	check(enemies.table.def[row].hitstop_multiplier == 0.5, "ライブ編集を既存個体へ反映")
	enemies.update_stage_tuning({})
	check(enemies.table.def[row].hitstop_multiplier == common.hitstop_multiplier, "上書き解除は共通値を継承")
	check(IO.definition("drifter").hitstop_multiplier == 1.0, "共通ファイルは変更しない")
	run_session.free()
	var panel := load("res://scripts/dev/stage_enemy_panel.gd").new() as Control
	panel.stage_path = stage_path
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.call("_select_enemy", "drifter")
	panel.set("_category", "ヒットストップ")
	panel.call("_refresh_rows")
	var controls: Array = panel.get("_row_controls")[KEY]
	var spin := FIELDS.editor(controls)
	check(spin.min_value == 0.0 and spin.value == 0.0, "UIは停止なしのゼロを編集・表示")
	spin.value = 0.2
	check(panel.get("values").drifter[KEY] == 0.2, "UI入力が敵種類の差分になる")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(panel.get("_status").get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "ヒットストップ編集欄と保存状態が画面内に収まる")
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	panel.call("_toggle_override", false, KEY, 1.0)
	check(not panel.get("values").has("drifter"), "チェックOFFで共通値へ戻す")
	panel.free()
	DirAccess.remove_absolute(stage_path)
	DirAccess.remove_absolute(generated_path)
	await get_tree().process_frame
	DirAccess.remove_absolute(fixture_root)
	print("[enemy_hitstop_authoring] failures=", failures)
	get_tree().quit(1 if failures else 0)
