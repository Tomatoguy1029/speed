extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var director = load("res://gyms/enemy_lab/attack_director.gd").new()
	director.configure({"enabled": true, "budget": 2, "gaps": {"beam": 0.5}})
	check(director.request("a", ["beam"], 0, 1, 1), "最初の攻撃を許可")
	check(not director.request("b", ["beam"], 1, 2, 1), "同じ分類の重複を拒否")
	check(not director.request("c", ["dash", "wave"], 2, 3, 1), "複合攻撃の一部だけを取得しない")
	check(director.groups.size() == 1, "失敗した要求が枠を奪わない")
	check(director.request("d", ["aimed"], 3, 4, 1), "独立した分類の攻撃を許可")
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty": true, "director": {"enabled": true, "budget": 1}})
	lab.perform("spawn", {"type": "beamer", "pos": [300, 0], "count": 6})
	for n in 360:
		lab.step()
		check(lab.run.projectiles.director.groups.size() <= 1, "本番ビームも同時枠を守る")
	lab.perform("boss", {"type": "hydra", "pos": [600, 0]})
	lab.perform("boss", {"type": "provisional", "pos": [-600, 0]})
	check(lab.run.bosses.lab_instances.size() == 2, "複数ボスを置いても所有者を分ける")
	lab.perform("spawn", {"type": "meteor", "pos": [-100, 50]})
	check(lab.run.enemies.table.meteor_index[lab.selected] >= 0, "実験の隕石も地形の行に登録する")
	var digest: String = lab.digest()
	await lab.seek(lab.tick)
	check(lab.digest() == digest, "攻撃管理と複数ボスを含め再現する")
	print("[lab_director] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
