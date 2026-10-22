## 同じ生成処理をCLIとエディターで使い、欠落した生成物を古いものとして扱う。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
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
	print("[content_build] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
