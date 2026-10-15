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
	var before: String = lab.digest()
	if not FileAccess.file_exists("res://gyms/enemy_lab/route_trial.gd"):
		check(false, "線の隔離評価が存在する")
	else:
		var trial = load("res://gyms/enemy_lab/route_trial.gd").new()
		add_child(trial)
		var result: Dictionary = await trial.evaluate(lab, PackedVector2Array([Vector2(-200, 0), Vector2(200, 0)]), 0.5)
		check(result.get("status") == "replayed", "本番の線を隔離して再生できる")
		check(result.get("kills", 0) > 0, "弱い敵を貫通して倒した結果を取得できる")
		check(lab.digest() == before, "線の評価で編集元の状態を変えない")
		trial.queue_free()
	print("[lab_route] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
