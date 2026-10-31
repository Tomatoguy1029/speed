## Authored appearances must resolve in production and preserve the armor/normal masks.
extends Node
const IDS := [&"auriga", &"pump", &"crow", &"hound"]
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	for id in IDS:
		var look := RunPresentation.load_look(id)
		check(look != null and look.prepared, "生成済み外観を解決する: " + String(id))
		if look == null: continue
		check(look.size_from_collision and is_equal_approx(look.angle, PI * 0.5), "原画の正面と既存の判定寸法を維持する")
		var armor := look.armor.get_image()
		var normal := look.normal.get_image()
		check(look.base.get_size() == look.armor.get_size() and armor.get_size() == normal.get_size(), "全レイヤーのキャンバスを一致させる")
		for y in armor.get_height():
			for x in armor.get_width():
				check(armor.get_pixel(x, y).a == normal.get_pixel(x, y).a, "装甲と法線の透明度を一致させる: " + String(id))
	for index in [1, 3, 5]:
		var stage := ContentManager.runtime_stage(index)
		for id in IDS:
			if not stage.resources.enemy_ids.has(String(id)): continue
			var path: String = stage.resources.look_paths.get(String(id), "")
			check(not path.is_empty() and stage.resources.paths.has(path), "本番ステージの依存へ外観を含める: %d/%s" % [index, id])
	print("[enemy_authored_art] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
