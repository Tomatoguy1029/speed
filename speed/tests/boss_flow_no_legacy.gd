## 公開コンテンツと起動時の型登録から、廃止したAI・仮ボスを除く。
extends SceneTree
var failed := 0
func check(ok: bool, text: String) -> void:
	if not ok:
		failed += 1
		push_error(text)
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	var content = root.get_node("ContentManager")
	check(not FileAccess.file_exists("res://addons/limboai/bin/limboai.gdextension"), "LimboAI拡張をプロジェクトから削除する")
	check(not ClassDB.class_exists("BTTask"), "起動時にLimboAIの型を登録しない")
	check(not content.bosses.has(&"provisional"), "仮ボスをコンテンツ一覧から除く")
	for index in [2, 3]:
		var stage = content.stage(index)
		check(stage.boss_id == &"" and not stage.boss_enabled, "未実装ステージに仮ボス参照を残さない: " + str(index))
	check(content.stage(5).boss_id==&"draco" and content.stage(5).boss_enabled,"ステージ5には専用の竜を接続する")
	for id in [&"hydra", &"monoceros", &"draco"]:
		var definition: BossDef = content.bosses[id]
		var scene := load(definition.scene_path) as PackedScene
		check(scene != null, "専用ボスを読み込める: " + String(id))
		if scene != null:
			var actor := scene.instantiate()
			check(actor.get_node_or_null("LimboHSM") == null, "専用ボスのシーンにLimboHSMを残さない")
			actor.free()
	print("[boss-no-legacy] failures=", failed)
	quit(1 if failed else 0)
