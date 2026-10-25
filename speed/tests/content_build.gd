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
