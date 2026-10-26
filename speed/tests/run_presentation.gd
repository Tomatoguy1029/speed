## 本番と実験場は、同じRunPresentationを表示の入口に使う。
extends Node
var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var path := "res://scripts/render/run_presentation.gd"
	if not ResourceLoader.exists(path):
		push_error("RunPresentationの入口が必要")
		get_tree().quit(1)
		return
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, true)
	session.auto_step = false
	var presentation := session.view.get_node_or_null("RunPresentation")
	var ok: bool = presentation != null and presentation.get_script().resource_path == path
	check(ok, "本番と実験場は同じ表示の入口を使う")
	var m := session.sim.enemies
	m.clear_all()
	var at := session.sim.state.ship_pos
	var body := session.sim.bosses.spawn_lab(&"hydra", at)
	check(body >= 0 and m.table.def[body] == null, "ボスの本体行はEnemyDefを持たず、役者が描く")
	m.spawn(m.def_of(&"drifter"), at + Vector2(120, 0))
	for frame in 3:
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	check(presentation._batches.has(&"drifter") and presentation._batches[&"drifter"].multimesh.visible_instance_count == 1,
		"ボス本体行を通ったあとも通常敵の描画を完了する")
	check(not presentation._batches.has(&"hydra"), "自分で描くボスを通常敵のbatchへ重複登録しない")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			check(get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture=")) == OK, "ボスと通常敵の描画を保存する")
	session.sim.bosses.remove_boss()
	m.cleanup()
	m.tick(0.01, 0.01)
	m.cleanup()
	for frame in 3:
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	check(presentation._batches.has(&"drifter") and presentation._batches[&"drifter"].multimesh.visible_instance_count == 1,
		"ボス退出・行解放後も通常敵を描く")
	session.free()
	await get_tree().process_frame
	print("[run_presentation] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
