## タイトルの起動では索引だけを持ち、個別の定義は要求したときに読む。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var content := get_node_or_null("/root/ContentManager")
	check(content != null, "ContentManagerを起動する")
	for path in ["res://data/stages/stage_1.tres", "res://data/weapons/W01_forward.tres", "res://data/enemies/drifter.tres"]:
		check(not ResourceLoader.has_cached(path), "要求前の定義を読まない: " + path)
	if content != null:
		var entry: Resource = content.catalog.find(&"weapons", &"W01")
		check(entry != null and entry.id == &"W01", "索引からIDで項目を引ける")
		check(entry.get_display_name() == tr("weapon.W01.name"), "索引でも名前の翻訳を保つ")
		var definition: Resource = content.definition(&"weapons", &"W01")
		check(definition is WeaponDef and definition.id == entry.id, "要求した定義を読める")
		var before: StageDef = content.stage(1)
		check(content.reload_experiment_data(), "実験場向けに編集元を読み直せる")
		check(content.stage(1) != before and content.stage(1) == content.stages[1], "再読込した新しいステージをID検索にも反映する")
	print("[content_catalog] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
