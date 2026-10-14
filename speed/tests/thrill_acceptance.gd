## スリルと寄り道の受け入れ確認。セーブはメモリだけで扱う。
## Godot --headless --log-file /tmp/speed-acceptance.log --path speed res://tests/thrill_acceptance.tscn
extends Node

class MemorySave:
	extends "res://scripts/managers/save_manager.gd"
	func save() -> void:
		save_changed.emit()

var scene: Node
var run: RunManager
var passed := 0
var failed := 0

func _ready() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	await _start(4)
	_test_fire_regrowth()
	await _close()
	print("[acceptance] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _start(stage: int) -> void:
	ConfigManager.reset_runtime()
	SaveManager.data = SaveManager.default_data()
	GameManager.run_stage = stage
	GameManager.run_endless = false
	scene = load("res://scenes/run/run.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("Managers/RunManager")
	run.set_physics_process(false)
	run.input.set_process_input(false)
	run.input.set_process_unhandled_input(false)
	await get_tree().process_frame
	run.command(&"choose_card", {"index": 0})
	run.build.reset_loadout()
	run.state.hitstop_enabled = false
	run.state.rng.seed = 401
	run.state.ship_vel = Vector2.ZERO
	_clear()

func _close() -> void:
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _clear() -> void:
	run.enemies.clear_regular()
	run.enemies.cleanup()
	run.projectiles.clear_hostile()
	run.projectiles.friend_slots.clear()
	run.field.wells.clear()
	run.combat.rebuild_grid()
	run.state.events.clear()
	run.state.phase = RunState.Phase.PLAY
	run.state.ship_invuln = 0.0

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[acceptance] OK ", label)
	else:
		failed += 1
		push_error("[acceptance] FAIL " + label)

func _test_fire_regrowth() -> void:
	run.bosses.spawn()
	var boss = run.bosses.actor
	var t := run.enemies.table
	run.state.world_time = 10.0
	for neck in boss.necks:
		run.combat.damage_enemy(neck.row, t.hp[neck.row] + 1.0, {"cause": &"fire", "no_crit": true})
	boss.sim_tick(0.01, 0.01)
	_check(boss.exposed_t > 0.0, "全頭を落とすと不死の首が現れる")
	_check(boss.necks.all(func(n): return n.burned), "火で落とした頭は再生が止まる")
	boss._tick_immortal(float(boss.def.params.expose_time) + 0.1)
	boss.sim_tick(1.0, 1.0)
	_check(boss.necks.all(func(n): return n.row < 0 and n.burned), "不死の首の露出が終わっても焼いた頭は次段階まで戻らない")
	t.hp[boss.body] = t.max_hp[boss.body] * 0.74
	boss.sim_tick(0.01, 0.01)
	_check(boss.count == 5 and boss.necks.all(func(n): return n.row >= 0 and not n.burned), "次段階で焼いた頭も戻り、新しい首が加わる")
