## 同じ生成処理をCLIとエディターで使い、欠落した生成物を古いものとして扱う。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cache-scope-only" in OS.get_cmdline_user_args():
		check_cache_scope()
		print("[生成キャッシュの依存範囲] failed=",failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--editor-process-only" in OS.get_cmdline_user_args():
		check_editor_process()
		print("[起動前の別プロセス生成] failed=",failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--startup-only" in OS.get_cmdline_user_args():
		_startup_only()
		return
	if "--incremental-current-only" in OS.get_cmdline_user_args():
		var builder = load("res://addons/content_build/builder.gd")
		var began := Time.get_ticks_usec()
		check(builder.build_all()==OK,"描画ありでも変更のない生成を再利用する")
		check(builder.last_build_report.all(func(row): return not row.rebuilt),"ボスを含めて変更のない単位を読み直さない")
		print("[rendered_incremental] ms=",(Time.get_ticks_usec()-began)/1000.0," failed=",failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--incremental-only" in OS.get_cmdline_user_args():
		check_incremental()
		print("[incremental_build] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--run-content-only" in OS.get_cmdline_user_args():
		check(check_run_content(), "ステージ生成の確認が最後まで完了する")
		print("[run_content] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var path := "res://addons/content_build/builder.gd"
	check(ResourceLoader.exists(path), "共通の生成処理がある")
	if ResourceLoader.exists(path):
		var builder = load(path)
		var output := "/tmp/speed-content-build-fixture"
		check(builder.build_all(true, output) == OK, "全ステージを一から生成できる")
		check(builder.is_current(output), "生成直後は現在の編集元と一致する")
		DirAccess.remove_absolute(output + "/stage_1.tres")
		check(not builder.is_current(output), "生成物の欠落を検出する")
		check(builder.build_all(false, output) == OK and builder.is_current(output), "欠落した生成物を作り直せる")
		DirAccess.remove_absolute(output + "/dev/stage_1.json")
		check(not builder.is_current(output), "開発用の名前の対応表の欠落も検出する")
		check(builder.build_all(false, output) == OK and builder.is_current(output), "欠落した対応表を作り直せる")
		DirAccess.remove_absolute(output + "/look_phoenix.res")
		check(not builder.is_current(output), "固定画像の欠落を検出する")
		check(builder.build_all(false, output) == OK and builder.is_current(output), "固定画像を再生成する")
		DirAccess.remove_absolute(output + "/dev/armor_phoenix.res")
		check(not builder.is_current(output), "開発用の装甲領域の欠落を検出する")
		check(builder.build_all(false, output) == OK and builder.is_current(output), "装甲領域を再生成する")
		DirAccess.remove_absolute(output + "/hero_aura.res")
		check(not builder.is_current(output), "英雄の光雲の生成物欠落を検出する")
		check(builder.build_all(false, output) == OK and builder.is_current(output), "英雄の光雲を共通工程で再生成する")
		var aura := load(output + "/hero_aura.res") as HeroAuraAssets
		check(aura != null and aura.mesh != null and aura.material != null, "共通の光雲の形状とmaterialを保持する")
		var before: String = builder.signature()
		var probe := "res://assets/pixel/visual_signature_probe.png"
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.save_png(probe)
		check(builder.signature() != before, "画像の追加を更新判定に含める")
		var imported: String = builder.signature()
		FileAccess.open(probe + ".import", FileAccess.WRITE).store_string("[params]\ncompress/mode=0\n")
		check(builder.signature() != imported, "import設定を更新判定に含める")
		DirAccess.remove_absolute(probe + ".import")
		DirAccess.remove_absolute(probe)
		check(builder.signature() == before, "入力を戻した後の署名が一致する")
	print("[content_build] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func check_run_content() -> bool:
	var builder = load("res://addons/content_build/builder.gd")
	var loader = load("res://scripts/runtime/run_content_loader.gd")
	var config := ContentManager.base.duplicate(true) as GameConfig
	# 追跡敵だけの代表経路。地形の種類はFタスクで登録する。
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := StageDef.new()
	stage.index = 77
	stage.enemies = [&"drifter"]
	var saved_path := "res://.content/dev/cpp_build_probe.tres"
	check(ResourceSaver.save(stage,saved_path)==OK, "制作ステージを保存できる")
	stage = ResourceLoader.load(saved_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.rank = 4
	definition.xp_reward_counts = PackedInt32Array([0,2,0])
	var definitions := {&"drifter":definition}
	check(builder.build_cpp_stage(stage,config,"res://.content",definitions)==OK, "共通生成入口から保存したステージを生成できる")
	var path := "res://.content/run/stage_77.json"
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var prepared: Dictionary = loader.read_bundle(path,first.input_sha256)
	check(not prepared.is_empty(), "索引・バイナリ・資源一覧が同じ版で読める")
	var session := RunSession.new()
	check(session.start_cpp_content(path,first.input_sha256,932)==OK, "Sessionの同じ開始経路からC++ランを始める")
	check(session.cpp_core.spawn_enemy(&"drifter",Vector2.ZERO,{})>0, "保存したステージの敵を生成できる")
	var previous_hp: float = session.cpp_core.enemies_snapshot()[0].hp
	var original_counts: PackedInt32Array = definition.resolve_xp_reward().counts.duplicate()
	definition.xp_reward_counts = PackedInt32Array([0,0,0])
	check(definition.resolve_xp_reward().counts != original_counts, "動的な報酬上書きも同じ解決経路へ通る")
	stage.enemy_tuning = {"drifter":{"hp":100.0}}
	check(ResourceSaver.save(stage,saved_path)==OK, "ステージの調整値を保存する")
	stage = ResourceLoader.load(saved_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	check(builder.build_cpp_stage(stage,config,"res://.content",definitions)==OK, "調整値を再生成する")
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(first.input_sha256!=second.input_sha256, "入力の値変更で生成署名が変わる")
	var next := RunSession.new()
	check(next.start_cpp_content(path,second.input_sha256,932)==OK, "再生成後も同じ開始経路を使う")
	check(next.cpp_core.spawn_enemy(&"drifter",Vector2.ZERO,{})>0, "再生成後の敵を生成する")
	check(next.cpp_core.enemies_snapshot()[0].hp!=previous_hp and session.cpp_core.enemies_snapshot()[0].hp==previous_hp, "新しいランだけが変更後の値を使う")
	var before := FileAccess.get_file_as_string(path)
	var compiled = load("res://tools/content/build_runtime_stage.gd").compile(stage,"res://.content",config)
	compiled.resources.paths.append("res://存在しない生成用資源.png")
	check(load("res://tools/content/build_run_content.gd").build(compiled,config,"res://.content/run",builder.signature(),definitions)!=OK, "途中の資源検査の失敗を検出する")
	check(FileAccess.get_file_as_string(path)==before, "途中失敗で公開索引を変更しない")
	check(loader.read_bundle(path,first.input_sha256).is_empty(), "古い期待署名では開始しない")
	definition.behavior = &"未対応"
	check(builder.build_cpp_stage(stage,config,"res://.content",definitions)!=OK and FileAccess.get_file_as_string(path)==before, "未対応種類で失敗し旧索引を保つ")
	next.free()
	session.free()
	DirAccess.remove_absolute(saved_path)
	return true

## 独立コピーでF5前の生成だけを確認し、変更を元に戻す。
func check_editor_process() -> void:
	var builder = load("res://addons/content_build/builder.gd")
	var started := Time.get_ticks_usec()
	check(builder.build_for_editor()==OK,"新しいプロセスで起動前の生成を完了する")
	check(not builder.last_build_report.is_empty(),"子プロセスの生成結果を受け取る")
	print("[起動前の更新あり] ms=",(Time.get_ticks_usec()-started)/1000.0)
	started = Time.get_ticks_usec()
	check(builder.build_for_editor()==OK,"変更なしでも同じ入口から開始できる")
	check(builder.last_build_report.size()==1 and builder.last_build_report[0].unit=="all" and not builder.last_build_report[0].rebuilt,"変更なしでは全体を再利用する")
	print("[起動前の変更なし] ms=",(Time.get_ticks_usec()-started)/1000.0)
	# 独立コピーで入力を壊し、失敗を起動成功として扱わないことを確認する。
	var path := "res://data/stages/stage_1.tres"
	var original := FileAccess.get_file_as_string(path)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("invalid resource")
	file.close()
	var error: Error = builder.build_for_editor()
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(original)
	file.close()
	check(error!=OK,"生成の失敗を親プロセスへ返して起動を止める")
	check(not builder.last_build_report.is_empty(),"途中で失敗しても実施した単位の結果を失わない")

func check_incremental() -> void:
	var builder = load("res://addons/content_build/builder.gd")
	var generator = load("res://tools/content/build_run_content.gd")
	var before := {}
	for number in range(1,6):
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.content/run/stage_%d.json" % number))
		before[number] = index.payload_sha256
	var started := Time.get_ticks_usec()
	check(builder.build_all()==OK,"差分生成の初回キャッシュを作る")
	print("[incremental initial_ms] ",(Time.get_ticks_usec()-started)/1000.0)
	for number in range(1,6):
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.content/run/stage_%d.json" % number))
		check(index.payload_sha256==before[number],"生成方法を変えても戦闘データは変わらない: %d" % number)
	started = Time.get_ticks_usec()
	check(builder.build_all()==OK,"変更なしで実行前の生成を呼べる")
	check(builder.last_build_report.all(func(row): return not row.rebuilt),"変更なしでは全ての生成を再利用する")
	print("[incremental unchanged_ms] ",(Time.get_ticks_usec()-started)/1000.0," units=",builder.last_build_report)
	var source_path := "res://data/stages/stage_1.tres"
	var original_stage := FileAccess.get_file_as_string(source_path)
	var stage: StageDef = ResourceLoader.load(source_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	stage.time_limit += 1.0
	check(ResourceSaver.save(stage,source_path)==OK,"独立コピーのステージ1だけを調整する")
	started = Time.get_ticks_usec()
	check(builder.build_all()==OK,"変更したステージを生成する")
	for row: Dictionary in builder.last_build_report:
		if row.unit.begins_with("stage_"): check(row.rebuilt==(row.unit=="stage_1"),"ステージ1の変更で他のステージを作り直さない: "+row.unit)
	print("[incremental stage1_ms] ",(Time.get_ticks_usec()-started)/1000.0," units=",builder.last_build_report)
	DirAccess.remove_absolute("res://.content/dev/stage_1.json")
	check(not builder.is_current(),"生成物の欠落を検出する")
	var prepared_before: int = generator.preparation_build_count
	check(builder.build_all()==OK and builder.is_current(),"欠落した記録名を再生成する")
	check(generator.preparation_build_count==prepared_before,"欠落の修復でも計算済みの戦闘を再利用する")
	var ui_path := "res://scripts/ui/hud.gd"
	var original_ui := FileAccess.get_file_as_string(ui_path)
	FileAccess.open(ui_path,FileAccess.WRITE).store_string(original_ui+"\n# 差分生成の確認用。\n")
	prepared_before = generator.preparation_build_count
	started = Time.get_ticks_usec()
	check(builder.build_all()==OK,"UI変更後の資源情報を更新する")
	check(generator.preparation_build_count==prepared_before,"UI変更で戦闘データを計算し直さない")
	print("[incremental ui_ms] ",(Time.get_ticks_usec()-started)/1000.0," units=",builder.last_build_report)
	FileAccess.open(ui_path,FileAccess.WRITE).store_string(original_ui)
	FileAccess.open(source_path,FileAccess.WRITE).store_string(original_stage)
	check(builder.build_all()==OK and builder.is_current(),"確認用の入力を元に戻して生成物をそろえる")

## 通常起動から裏の資源準備の完了までを測り、出撃と保存は行わない。
func _startup_only() -> void:
	RenderingServer.frame_post_draw.connect(func(): print("[startup_first_draw] engine_ms=",Time.get_ticks_msec()),CONNECT_ONE_SHOT)
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	while not app.get("startup_complete") and not app.get("startup_failed"):
		await get_tree().process_frame
	print("[startup_title] engine_ms=",Time.get_ticks_msec()," complete=",app.get("startup_complete")," timings=",ContentManager.startup_timings)
	get_tree().quit(0 if app.get("startup_complete") else 1)

## 独立コピーの既存生成物を使い、入口・報告と実データの変更だけを照合する。
func check_cache_scope() -> void:
	var builder = load("res://addons/content_build/builder.gd")
	var generator = load("res://tools/content/build_run_content.gd")
	var incremental = load("res://addons/content_build/incremental.gd")
	var before := {}
	for number in range(1,6):
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.content/run/stage_%d.json" % number))
		before[number] = [index.payload_sha256,index.resources_sha256]
	var compiled: RuntimeStage = load("res://.content/stage_1.tres")
	var config := load("res://data/config.tres") as GameConfig
	var prepared_key: String = generator.preparation_signature(compiled,config,{},[],{},{})
	var started := Time.get_ticks_usec()
	var changed := {}
	for path in ["res://addons/content_build/builder.gd","res://addons/content_build/incremental.gd","res://addons/content_build/plugin.gd","res://addons/content_build/export.gd","res://tools/content/build_all.gd"]:
		changed[path] = FileAccess.get_file_as_string(path)
		FileAccess.open(path,FileAccess.WRITE).store_string(changed[path]+"\n# 入口・報告だけの変更。\n")
	check(builder.build_for_editor()==OK,"入口・報告の変更後も通常の生成入口が成功する")
	check(builder.last_build_report.size()>1 and builder.last_build_report.all(func(row): return not row.rebuilt),"入口・報告だけなら全単位を再利用する")
	check(generator.preparation_signature(compiled,config,{},[],{},{})==prepared_key,"入口・報告は準備キャッシュを無効にしない")
	print("[入口・報告変更] ms=",(Time.get_ticks_usec()-started)/1000.0," units=",builder.last_build_report)
	for number in range(1,6):
		var path := "res://.content/run/stage_%d.json" % number
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check([index.payload_sha256,index.resources_sha256]==before[number],"戦闘データと資源表を保持する: %d" % number)
		check(not load("res://scripts/runtime/run_content_loader.gd").read_bundle(path,index.input_sha256).is_empty(),"再利用したデータを通常の読込経路で検査する: %d" % number)
	for path: String in changed: FileAccess.open(path,FileAccess.WRITE).store_string(changed[path])
	# 小さい音の生成単位で、実際の生成処理の変更と出力欠落を確かめる。
	var audio_path := "res://tools/content/build_audio.gd"
	var original_audio := FileAccess.get_file_as_string(audio_path)
	FileAccess.open(audio_path,FileAccess.WRITE).store_string(original_audio+"\n# 音の生成処理の変更。\n")
	started = Time.get_ticks_usec()
	check(builder.build_for_editor()==OK,"音の生成処理の変更を反映する")
	for row: Dictionary in builder.last_build_report:
		check(row.rebuilt==(row.unit=="audio"),"音の生成処理変更が無関係な生成単位へ波及しない: "+row.unit)
	print("[音の生成処理変更] ms=",(Time.get_ticks_usec()-started)/1000.0)
	# 同じ生成入口で、実データ変更が対象のステージにだけ届くことも確かめる。
	var stage_path := "res://data/stages/stage_1.tres"
	var original_stage := FileAccess.get_file_as_string(stage_path)
	var stage: StageDef = ResourceLoader.load(stage_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	stage.time_limit += 1.0
	check(ResourceSaver.save(stage,stage_path)==OK,"独立コピーのステージ1の値を変更する")
	started = Time.get_ticks_usec()
	check(builder.build_for_editor()==OK,"変更した実データを生成する")
	for row: Dictionary in builder.last_build_report:
		check(row.rebuilt==(row.unit in ["catalog","stage_1"]),"ステージ1の値変更では索引と対象ステージだけ作り直す: "+row.unit)
	print("[ステージ1の値変更] ms=",(Time.get_ticks_usec()-started)/1000.0)
	FileAccess.open(stage_path,FileAccess.WRITE).store_string(original_stage)
	FileAccess.open(audio_path,FileAccess.WRITE).store_string(original_audio)
	# 全体生成を回さず、欠落した単位の再生成を既存キャッシュ経路で確かめる。
	var cache = incremental.new()
	var output := "res://.content/dev/cache_scope_probe.txt"
	var callback := func():
		FileAccess.open(output,FileAccess.WRITE).store_string("生成物")
		return {"error":OK,"outputs":PackedStringArray([output])}
	check(cache.run("probe",PackedStringArray([audio_path]),callback)==OK,"確認用の小さい出力を生成する")
	DirAccess.remove_absolute(output)
	check(cache.run("probe",PackedStringArray([audio_path]),callback)==OK and cache.report[-1].rebuilt,"出力欠落は入力が同じでも作り直す")
	DirAccess.remove_absolute(output)
