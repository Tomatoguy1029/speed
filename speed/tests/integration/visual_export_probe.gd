## 配布presetの一時main sceneへ組み込み、release実行体で配布経路を検証する。
extends Node
var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	check(not OS.has_feature("editor"), "editor fallbackを持たない配布実行体で確認する")
	for path in ["res://tools/content/visual_transforms.gd", "res://scripts/render/armor_paint.gd", "res://.content/dev/armor_phoenix.res"]:
		check(not ResourceLoader.exists(path), "配布から解析・ライブ編集用データを除外: " + path)
	var started := Time.get_ticks_usec()
	var look_count := 0
	for index in range(1, 6):
		GameManager.run_stage = index
		var stage := ContentManager.runtime_stage(index)
		for placement in stage.backgrounds:
			check(placement.texture == null and placement.bounds().has_area(), "背景は生成済み範囲とパスを持つ")
			check(not ResourceLoader.has_cached(placement.texture_path), "ステージ取得だけでは背景画像を読み込まない")
		var session := RunManager.create_run()
		session.auto_step = false
		add_child(session)
		await session.started
		var render := session.view.get_node("RunPresentation") as RunPresentation
		for id in stage.resources.enemy_ids:
			var look := render.look_of(StringName(id))
			if look == null: continue
			look_count += 1
			check(session.resources.resources.has(look.resource_path) and look.prepared, "Scope内の生成済み外観を使用")
			check(not ResourceLoader.has_cached(look.source_path), "編集用外観を読み込まない")
			render._ensure_enemy_batch(StringName(id))
			check(render._enemy_texture(StringName(id)) != null, "固定塗装と船体合成を解析なしで取得")
		for placement in stage.backgrounds:
			check(session.resources.resources.has(placement.texture_path), "背景画像のScope準備を完了")
		await get_tree().process_frame
		var scope := session.resources
		session.free()
		await get_tree().process_frame
		check(scope.cancelled and scope.resources.is_empty(), "ステージ終了時に資源を解放")
	print("[visual_export_probe] 5 stages, ", look_count, " looks, ", (Time.get_ticks_usec() - started) / 1000.0, " ms, ", failed, " failures")
	get_tree().quit(1 if failed else 0)
