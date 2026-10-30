## 全ステージの目標人数・強化帯・ボーナス配分を生成データの保存前後で比較する。
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
	var probe = comparison.create_native()
	if not probe.has_method("configure_spawn_timeline"):
		check(false, "生成した時間帯と曲線をネイティブで参照する")
	else:
		for stage in range(1,6): await compare_stage(comparison, stage)
		var builder = load("res://addons/content_build/builder.gd")
		check(builder.is_current(), "共通生成の出力が現在の入力に一致する")
		var path := "res://.content/dev/native_spawn_1.bin"
		if FileAccess.file_exists(path):
			check(DirAccess.rename_absolute(path, path + ".missing") == OK, "生成物の欠落条件を作る")
			check(not builder.is_current(), "バイナリの出力欠落も検出する")
			check(DirAccess.rename_absolute(path + ".missing", path) == OK and builder.is_current(), "生成物を戻して更新判定を復元する")
	probe.close()
	print("[native_spawn_timeline] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_stage(comparison, index: int) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 716, "empty": true, "stage": index})
	var run: RunSimulation = lab.run
	var original: StageDef = run.state.stage
	for mode in ["curves", "mix", "empty_curves"]:
		var stage: StageDef = original.duplicate(true)
		if mode == "mix": stage.zako_curves = []
		elif mode == "empty_curves":
			for curve in stage.zako_curves: curve.points = PackedVector2Array()
		run.state.stage = stage
		var raw := DATA.compile_spawn_timeline(stage, run.cfg)
		check(raw.has("clip_bundle"), "全クリップの周期と配置を生成データへ含める")
		if raw.has("clip_bundle"):
			var bundle: Dictionary = raw.clip_bundle
			check(bundle.clips.size() == stage.clips.size() and bundle.base_view == run.cfg.base_view, "クリップ数と画面の基準を保つ")
			var next := 0
			for i in stage.clips.size():
				var source: RuntimeClip = stage.clips[i]
				var clip: Dictionary = bundle.clips[i]
				var refs := []
				for prepared in source.prepared:
					refs.append(next)
					check(comparison.difference(bundle.formations[next], DATA.compile_formation(prepared)).is_empty(), "配置と出現位置を同じ固定変換で生成する")
					next += 1
				var types := []
				for type in source.types: types.append(String(type))
				var expected := {"start": source.time, "end": source.end_time(), "groups": source.groups, "interval": source.interval, "priority": source.attack_priority, "types": types, "formations": refs}
				check(comparison.difference(expected,clip).is_empty(), "クリップの編集値と配置の順番を保つ")
			check(next == bundle.formations.size(), "参照されない配置を生成物へ残さない")
		if mode == "curves":
			var generated_path := "res://.content/dev/native_spawn_%d.bin" % index
			check(FileAccess.file_exists(generated_path), "共通生成の出力に出現タイムラインがある")
			if FileAccess.file_exists(generated_path):
				var generated := FileAccess.open(generated_path, FileAccess.READ)
				# 共通生成は保存済みRuntimeStageを入力にする。実験場の再展開とは、テキスト保存を挟む回数が異なる。
				var saved_stage := ResourceLoader.load("res://.content/stage_%d.tres" % index, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RuntimeStage
				var difference: String = comparison.difference(DATA.compile_spawn_timeline(saved_stage, run.cfg), generated.get_var())
				check(difference.is_empty(), "共通生成の出現タイムラインが保存済みの実行用ステージと一致する: " + difference)
				generated.close()
		var path := "/tmp/speed-native-timeline-test.bin"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_var(raw)
		file.close()
		file = FileAccess.open(path, FileAccess.READ)
		var saved: Dictionary = file.get_var()
		file.close()
		check(comparison.difference(raw, saved).is_empty(), "曲線の値と傾きを丸めずに保存・読込する")
		var core = comparison.create_native()
		check(core.configure_spawn_timeline(saved), "保存後の時間帯・曲線・強化帯を読み込む")
		var broken := saved.duplicate(true)
		broken.density = NAN
		check(not core.configure_spawn_timeline(broken), "不正な生成値で既存の準備を上書きしない")
		check(core.start(716), "目標人数の参照を開始する")
		var times := [0.0, 0.001, stage.boss_start(run.cfg), stage.boss_start(run.cfg)+500.0]
		for window in stage.surge_windows(run.cfg):
			for edge in [window.x, window.y]:
				if is_finite(edge):
					for delta in [-0.001, 0.0, 0.001]: times.append(maxf(0.0, edge + delta))
		for phase: PhaseDef in stage.phases:
			for multiple in [1,2,3]:
				for delta in [-0.001,0.0,0.001]: times.append(phase.start + maxf(1.0, phase.surge_value("surge_interval", run.cfg)) * multiple + delta)
			for delta in [-0.001, 0.0, 0.001, 8.125]: times.append(maxf(0.0, phase.start + delta))
		for curve: SpawnCurve in stage.zako_curves:
			for point in curve.points:
				for delta in [-0.001, 0.0, 0.001, 5.25]: times.append(maxf(0.0, point.x + delta))
		for bonus in [false,true]:
			run.state.bonus_t = 1.0 if bonus else 0.0
			for time in times:
				run.state.time = time
				var old := run.spawn.target()
				var expected := {"phase": String(old.phase.id), "pop": old.pop, "surge": old.surge,
					"rate": old.phase.rate, "xp_bonus": old.phase.xp_bonus, "attack_budget": old.phase.attack_budget}
				if old.has("per_type"): expected.per_type = old.per_type
				var difference: String = comparison.difference(comparison.plain(expected), comparison.plain(core.spawn_target(time, bonus)))
				check(difference.is_empty(), "目標人数が一致する S%d %s bonus%s t%.3f: %s" % [index,mode,bonus,time,difference])
				if not difference.is_empty(): break
		core.close()
	lab.free()
