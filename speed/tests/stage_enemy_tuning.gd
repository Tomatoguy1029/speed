## ステージ局所の敵調整の保存・生成・ライブ反映を、ソースを書き換えずに確認する。
extends Node
const IO := preload("res://scripts/dev/stage_enemy_edit.gd")
const BUILD := preload("res://tools/content/build_runtime_stage.gd")
var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var common := IO.definition("telescope")
	var cfg := ContentManager.cfg.duplicate(true) as GameConfig
	var hp := common.base_hp(cfg)
	var damage: float = common.params.bullet_dmg
	var source := ContentManager.stage(4).duplicate(true) as StageDef
	source.enemy_tuning = {"telescope": {"hp": hp * 2.0, "params.bullet_dmg": damage + 3.0, "params.cooldown": 2.0}}
	check(IO.validate(source.enemy_tuning).is_empty(), "星のHPと敵固有数値を検証できる")
	check(not IO.validate({"telescope": {"xp": 5.0}}).is_empty(), "共通のXPを編集対象から外す")
	check(not IO.validate({"telescope": {"params.cooldown": 0.0}}).is_empty(), "不正な攻撃間隔を拒否する")
	check(not IO.validate({"telescope": {"hp": NAN}}).is_empty(), "非有限値を拒否する")
	var path := "/tmp/speed-stage-enemy-tuning-fixture.tres"
	ResourceSaver.save(source, path)
	var initial := IO.read_stage(path)
	check(initial.enemy_tuning == source.enemy_tuning, "ステージに差分を保存・再読込できる")
	# 他のステージ設定の編集と共存し、敵調整の同時編集は検出する。
	initial.boss_time = 123.0
	ResourceSaver.save(initial, path)
	var edited := source.enemy_tuning.duplicate(true)
	edited.telescope["params.bullet_dmg"] = damage + 8.0
	check(IO.save(path, edited, source.enemy_tuning).has("stage"), "敵調整だけを保存できる")
	check(IO.read_stage(path).boss_time == 123.0, "保存時に他のステージ設定を維持する")
	check(IO.save(path, {}, source.enemy_tuning).has("error"), "別の敵調整を古い状態で上書きしない")
	var panel = load("res://scripts/dev/stage_enemy_panel.gd").new()
	panel.stage_path = path
	add_child(panel)
	panel._select_enemy("telescope")
	panel._edit_value(hp * 4.0, "hp", hp)
	check(panel.is_dirty(), "UIの数値変更を未保存の試行として保持する")
	panel.open_stage(path)
	check(panel.values.telescope.hp == hp * 4.0, "同じステージの再選択で試行を失わない")
	panel.reload_stage()
	check(not panel.is_dirty() and panel.values == edited, "UIの再読込で保存済み設定へ戻せる")
	panel.free()
	var runtime := BUILD.compile(IO.read_stage(path))
	check(runtime.enemy_tuning == edited, "buildでRuntimeStageに差分を反映する")
	var baked_path := "/tmp/speed-stage-enemy-tuning-runtime.tres"
	ResourceSaver.save(runtime, baked_path)
	runtime = IO.read_stage(baked_path)
	check(runtime.enemy_tuning == edited, "生成物の再読込でも差分を保持する")
	var session := RunManager.create_session(self, {"stage": runtime, "stage_index": 4, "config": cfg, "seed": 42}, false)
	session.auto_step = false
	var enemies := session.sim.enemies
	var def := enemies.def_of(&"telescope")
	check(is_equal_approx(def.base_hp(cfg), hp * 2.0), "星からの計算後のHPへ上書きを適用する")
	check(def.params.bullet_dmg == damage + 8.0, "敵固有の攻撃力へ適用する")
	var row := enemies.spawn(def, Vector2(300, 200))
	var t := enemies.table
	t.hp[row] = t.max_hp[row] * 0.25
	var id := t.id[row]
	var old_hp := t.max_hp[row]
	t.timer[row] = 1.25
	var live := edited.duplicate(true)
	live.telescope.hp = hp * 3.0
	live.telescope["params.bullet_dmg"] = damage + 12.0
	enemies.update_stage_tuning(live)
	check(is_equal_approx(t.hp[row] / t.max_hp[row], 0.25) and t.max_hp[row] > old_hp, "ライブHP変更で残HP割合を保つ")
	check(t.id[row] == id and t.pos[row] == Vector2(300, 200) and t.timer[row] == 1.25, "位置・個体ID・行動状態を維持する")
	check(t.def[row].params.bullet_dmg == damage + 12.0, "既存個体が次の攻撃に新しい値を使う")
	check(enemies.def_of(&"telescope") == t.def[row], "新しい出現にもライブ値を使う")
	var direct := enemies.spawn(common, Vector2.ZERO)
	check(t.def[direct].params.bullet_dmg == damage + 12.0, "共通定義を直接渡す出現にもステージ値を使う")
	session.sim.projectiles.fire_enemy(row, 0.0, 10.0, &"bullet")
	var shot := session.sim.projectiles.hostile_alive.find(1)
	check(shot >= 0 and session.sim.projectiles.hostile_dmg[shot] == damage + 12.0, "発射した弾の攻撃力にライブ値が入る")
	check(runtime.enemy_tuning == edited, "未保存の試行でRuntimeStageを書き換えない")
	enemies.update_stage_tuning({})
	check(enemies.def_of(&"telescope").base_hp(cfg) == hp and t.def[row].params.bullet_dmg == damage, "リセットで共通値へ戻る")
	check(is_equal_approx(t.hp[row] / t.max_hp[row], 0.25), "リセットでも残HP割合を保つ")
	check(IO.definition("telescope").params.bullet_dmg == damage, "共通の敵ファイルへ波及しない")
	var other_stage := ContentManager.stage(2).duplicate(true) as StageDef
	other_stage.enemy_tuning = {}
	var other := RunManager.create_session(self, {"stage": BUILD.compile(other_stage), "stage_index": 2, "seed": 42}, false)
	other.auto_step = false
	check(other.sim.enemies.def_of(&"telescope").base_hp(cfg) == hp, "同じ敵を使う別ステージへ波及しない")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			var overlay = load("res://scripts/dev/stage_enemy_overlay.gd").new()
			overlay.run = session.sim
			add_child(overlay)
			overlay.show()
			overlay.panel._select_enemy("telescope")
			overlay.panel._search.text = "bullet"
			overlay.panel._refresh_rows()
			await get_tree().process_frame
			overlay._fit()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(overlay.panel._status.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "保存・状態表示が画面内に収まる")
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
			overlay.free()
	other.free()
	session.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(baked_path)
	await get_tree().process_frame
	print("[stage_enemy_tuning] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
