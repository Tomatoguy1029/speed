extends Node

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[lab_core] " + label)

func _ready() -> void:
	if not FileAccess.file_exists("res://gyms/enemy_lab/lab_session.gd"):
		check(false, "専用の実験セッションが存在する")
		get_tree().quit(1)
		return
	var script := load("res://gyms/enemy_lab/lab_session.gd")
	var lab = script.new()
	add_child(lab)
	var data_before := JSON.stringify(SaveManager.data)
	var config_before := ConfigManager.cfg.enemy_hp_mult
	await lab.reset({"seed": 932, "empty": true, "stage": 4})
	check(lab.run.state.stage.boss_id == &"hydra", "実験の基準はステージ4のヒュドラ")
	check(lab.run.state.phase == RunState.Phase.PLAY, "カード選択なしで実験できる")
	check(lab.run.cfg != ConfigManager.cfg, "設定を実験ごとに複製する")
	lab.perform("spawn", {"type": "gunner", "pos": [200, 0], "count": 3})
	check(lab.run.enemies.count() == 3, "好きな敵を複数出せる")
	for n in 120:
		lab.step()
	var digest: String = lab.digest()
	check(not digest.is_empty(), "比較用の戦闘状態を取得できる")
	await lab.seek(0)
	check(lab.tick == 0, "開始へ巻き戻す")
	for checkpoint in lab.checkpoints: checkpoint.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(120)
	check(lab.digest() == digest, "同じ時刻へ戻ると戦闘状態が一致する")
	check(JSON.stringify(SaveManager.data) == data_before and ConfigManager.cfg.enemy_hp_mult == config_before, "実験でセーブと本番設定を変えない")
	await lab.reset({"seed": 932, "empty": true})
	check(lab.run.enemies.count() == 0, "実験を空の状態へ戻せる")
	await lab.reset({"seed": 801, "empty": true, "stage": 4})
	lab.perform("boss", {"type": "hydra", "pos": [400, 0]})
	for n in 150:
		lab.step()
	var boss_digest: String = lab.digest()
	await lab.seek(0)
	for checkpoint in lab.checkpoints: checkpoint.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(150)
	check(lab.digest() == boss_digest, "うみへびの首と乱数も巻き戻して再現できる")
	await lab.seek(60)
	lab.perform("spawn", {"type": "rocket", "pos": [-300, 0]})
	check(lab.branches.size() == 1 and lab.furthest == 60, "過去を編集すると元の履歴を残して分岐する")
	lab.queue_free()
	await get_tree().process_frame
	print("[lab_core] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
