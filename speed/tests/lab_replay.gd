extends Node
const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const IO := preload("res://gyms/enemy_lab/lab_io.gd")
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func cold_seek(lab, target: int) -> void:
	for item in lab.checkpoints: item.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(0)
	for item in lab.checkpoints: item.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(target)
func _ready() -> void:
	var lab = SESSION.new()
	add_child(lab)
	await lab.reset({"seed": 901, "empty": true, "director": {"enabled": true, "budget": 8}})
	var index := 0
	for def: EnemyDef in ConfigManager.sorted(ConfigManager.enemies):
		if def.behavior == &"part": continue
		var point := Vector2.from_angle(float(index) * 0.45) * (450 + 25 * index)
		lab.perform("spawn", {"type": String(def.id), "pos": [point.x, point.y]})
		index += 1
	lab.perform("boss", {"type": "hydra", "pos": [700, 300]})
	lab.perform("boss", {"type": "provisional", "pos": [-700, 300]})
	lab.perform("hero", {"id": "perseus"})
	lab.perform("input", {"has_cursor": false, "hero": true})
	lab.perform("boss_parameter", {"type": "hydra", "key": "params.attack_cd", "value": 1.5})
	check(ConfigManager.bosses[&"hydra"].params.attack_cd != 1.5, "ボスの数値を本番定義から隔離する")
	for n in 420: lab.step()
	var expected: String = lab.digest()
	await cold_seek(lab, 420)
	check(lab.digest() == expected, "全敵・複数ボス・英雄・攻撃管理を最初から再現する")
	var record := IO.record(lab, PackedVector2Array(), {}, [])
	check(IO.validate(record).is_empty(), "混成実験の記録を検証できる")
	IO.save_json("/private/tmp/speed-mixed-record.json", record)
	record = IO.read_json("/private/tmp/speed-mixed-record.json")
	check(not record.has("error"), "混成実験を JSON に書いて読み戻せる")
	await lab.reset(record.spec)
	lab.history.assign(record.history)
	lab.furthest = int(record.end)
	await lab.seek(int(record.tick))
	check(lab.digest() == expected, "履歴を差し替えた後に古いチェックポイントを使わない")
	var node_count := get_tree().get_node_count()
	for n in 5:
		await lab.seek(120)
		await lab.seek(420)
		await get_tree().process_frame
	check(lab.checkpoints.size() <= 3 and get_tree().get_node_count() <= node_count + 180, "チェックポイントと役者を上限付きで回収する")
	lab.queue_free()
	await get_tree().process_frame
	print("[lab_replay] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
