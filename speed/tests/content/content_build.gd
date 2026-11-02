## 同じ生成処理をCLIとエディターで使い、欠落した生成物を古いものとして扱う。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
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
