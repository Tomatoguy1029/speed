extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty": true})
	lab.perform("spawn", {"type": "drifter", "pos": [0, 0]})
	lab.perform("input", {"cursor": [1000, 1000]})
	var before: String = lab.digest()
	if not FileAccess.file_exists("res://gyms/enemy_lab/route_trial.gd"):
		check(false, "線の隔離評価が存在する")
	else:
		var trial = load("res://gyms/enemy_lab/route_trial.gd").new()
		add_child(trial)
		var result: Dictionary = await trial.evaluate(lab, PackedVector2Array([Vector2(-200, 0), Vector2(200, 0)]), 0.5)
		check(result.get("status") == "replayed", "本番の線を隔離して再生できる")
		check(result.get("success", false), "単純な弱い敵を貫く線の成功を確認する")
		check(result.get("kills", 0) > 0, "弱い敵を貫通して倒した結果を取得できる")
		check(lab.digest() == before, "線の評価で編集元の状態を変えない")
		lab.perform("ship", {"pos": [0, 0], "gauge": 0.01})
		var low: Dictionary = await trial.evaluate(lab, PackedVector2Array([Vector2(-200, 0), Vector2(200, 0)]), 0.5)
		check(low.status == "invalid", "本番で描けない充填率を成功にしない")
		trial.queue_free()
	lab.queue_free()
	await get_tree().process_frame
	var ui_lab = load("res://gyms/enemy_lab/enemy_lab.tscn").instantiate()
	add_child(ui_lab)
	await get_tree().create_timer(0.4).timeout
	ui_lab.session.perform("spawn", {"type": "drifter", "pos": [-250, -80], "count": 18, "spacing": 70})
	ui_lab.session.perform("spawn", {"type": "beamer", "pos": [300, -140], "count": 3})
	ui_lab.session.perform("spawn", {"type": "armored", "pos": [150, 200], "count": 4})
	ui_lab.canvas.route = PackedVector2Array([Vector2(-450,-100), Vector2(-100,0), Vector2(300,150)])
	ui_lab._refresh()
	ui_lab.inspector.refresh(true)
	await ui_lab._evaluate()
	check(ui_lab.canvas.result.get("status") == "replayed", "実験場の画面から線を評価できる")
	ui_lab.pattern = ui_lab.generator.capture(ui_lab.session, ui_lab.canvas.route, 20)
	ui_lab.canvas.pattern = ui_lab.pattern
	var record: Dictionary = ui_lab.IO.record(ui_lab.session, ui_lab.canvas.route, ui_lab.pattern, ui_lab.comparisons)
	var record_path := "/tmp/speed-ui-record.json"
	ui_lab.IO.save_json(record_path, record)
	var expected: String = ui_lab.session.digest()
	await ui_lab._load_file(record_path)
	check(ui_lab.session.run.enemies.count() == 25 and ui_lab.session.digest() == expected, "実験場の画面から記録を読み直して状態を復元できる")
	ui_lab.queue_free()
	await get_tree().process_frame
	print("[lab_route] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
