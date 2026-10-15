extends Node

func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/enemy_lab.tscn").instantiate()
	add_child(lab)
	await get_tree().create_timer(0.4).timeout
	lab.session.perform("spawn", {"type": "drifter", "pos": [-250, -80], "count": 18, "spacing": 70})
	lab.session.perform("spawn", {"type": "beamer", "pos": [300, -140], "count": 3})
	lab.session.perform("spawn", {"type": "armored", "pos": [150, 200], "count": 4})
	lab.canvas.route = PackedVector2Array([Vector2(-450,-100), Vector2(-100,0), Vector2(300,150)])
	lab._refresh()
	lab.inspector.refresh(true)
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	get_viewport().get_texture().get_image().save_png("/private/tmp/speed-lab-first.png")
	await lab._evaluate()
	if lab.canvas.result.get("status") != "replayed": push_error("線の評価が画面から実行できない")
	lab.pattern = lab.generator.capture(lab.session, lab.canvas.route, 20)
	lab.canvas.pattern = lab.pattern
	lab.canvas.mode = 4
	lab.workspace.open_settings(3)
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	get_viewport().get_texture().get_image().save_png("/private/tmp/speed-lab-patterns.png")
	var data: Dictionary = lab.IO.record(lab.session, lab.canvas.route, lab.pattern, lab.comparisons)
	lab.IO.save_json("/private/tmp/speed-ui-record.json", data)
	var expected: String = lab.session.digest()
	await lab._load_file("/private/tmp/speed-ui-record.json")
	if lab.session.run.enemies.count() != 25 or lab.session.digest() != expected: push_error("記録の再読込で戦闘状態が違う")
	lab.controls.name_field.text = "qa-fixture"
	await lab._export()
	DisplayServer.window_set_size(Vector2i(960, 720))
	lab._left.hide()
	lab._right.hide()
	lab.workspace.settings.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	get_viewport().get_texture().get_image().save_png("/private/tmp/speed-lab-small.png")
	await lab.session.reset({"empty": true})
	lab.session.perform("boss", {"type": "hydra", "pos": [300, 0]})
	for n in 90: lab.session.step()
	lab.canvas.center = Vector2(250, 0)
	lab.canvas.zoom = 0.5
	lab.canvas.pattern.clear()
	lab.canvas.route.clear()
	lab.canvas.comparisons.clear()
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	get_viewport().get_texture().get_image().save_png("/private/tmp/speed-lab-hydra.png")
	await lab.session.reset({"empty": true})
	lab.session.perform("spawn", {"type": "drifter", "pos": [0, 0], "count": 3})
	lab.canvas.route = PackedVector2Array([Vector2(-300, 0), Vector2(300, 0)])
	lab.pattern = lab.generator.capture(lab.session, lab.canvas.route, 20)
	lab.canvas.pattern = lab.pattern
	lab.canvas.center = Vector2.ZERO
	lab._right.show()
	lab.workspace.open_settings(3)
	await lab._generate_candidates()
	lab.controls.get_children()[3].scroll_vertical = 1200
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	get_viewport().get_texture().get_image().save_png("/private/tmp/speed-lab-candidates.png")
	await lab._reload_data()
	print("[lab_visual] workflow completed")
	get_tree().quit()
