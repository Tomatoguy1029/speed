## 閃光斬の保持中は、種類別の更新でも移動・攻撃を止める。
extends "res://tests/thrill_acceptance.gd"

func _ready() -> void:
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	scene = RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	scene.auto_step = false
	run = scene.sim
	for type in [&"drifter", &"swarm", &"armored", &"titan", &"splitling", &"volatile", &"biter", &"defender", &"hound"]:
		_clear()
		var i := _enemy(type, run.state.ship_pos + Vector2(200, 0))
		var t := run.enemies.table
		var behavior := run.enemies.behaviors[t.beh[i]]
		var at := t.pos[i]
		t.vel[i] = Vector2(100, 0)
		t.slash_hold[i] = 1
		t.mode[i] = EnemyTable.Mode.WINDUP
		t.timer[i] = 0.001
		t.flash[i] = 0.1
		var age := t.age[i]
		var timer := t.timer[i]
		behavior.tick_rows(PackedInt32Array([i]), 1.0 / 60.0)
		_check(t.pos[i] == at and t.vel[i] == Vector2.ZERO and t.timer[i] == timer, "%sの保持中は移動と行動を止める" % type)
		_check(t.age[i] > age and t.flash[i] < 0.1, "%sの共通時計は保持中も進む" % type)
		t.slash_hold[i] = 0
		t.mode[i] = EnemyTable.Mode.MOVE
		behavior.tick_rows(PackedInt32Array([i]), 1.0 / 60.0)
		_check(t.pos[i] != at, "%sは保持を解くと移動する" % type)
	await _close()
	print("[slash_hold] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
