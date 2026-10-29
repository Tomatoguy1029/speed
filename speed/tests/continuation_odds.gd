## 通常カード選択から自動強化の段数分布と、継続画面の「4連続」を独立して確認する。
## Godot --headless --log-file /tmp/speed-continuation.log --path speed res://tests/continuation_odds.tscn
extends Node

func _ready() -> void:
	_check()

func _check() -> void:
	var cfg: GameConfig = ContentManager.cfg.duplicate(true)
	var session: RunSession = RunManager.create_session(self, {"lab": true, "seed": 30491, "config": cfg}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	var counts := [0, 0, 0, 0]
	var failed := 0
	var first := cfg.levelup_bonus_chance
	var second := first * cfg.levelup_bonus_more
	var fourth := second * cfg.levelup_bonus_last
	var run_27 := 1.0 - pow(1.0 - fourth, 27)
	if absf(first - 0.12280138) > 0.000001 or absf(cfg.levelup_bonus_more - 0.2) > 0.000001: failed += 1
	if absf(cfg.levelup_bonus_last - 0.1) > 0.000001 or absf(run_27 - (1.0 - pow(1.0 - 0.12280138 * 0.2 * 0.1, 27))) > 0.000001: failed += 1
	for trial in 2000:
		sim.state.weapons = {&"W01": 1}
		sim.state.traits = {}
		sim.state.events = []
		sim.state.cards = [{"kind": &"weapon", "id": &"W01", "level": 2}]
		sim.state.pending_levels = 1
		sim.loadout.choose_card(0)
		var bonuses: Array = sim.state.events.filter(func(event): return event.type == &"level_bonus")
		if bonuses.size() > 3:
			failed += 1
		else:
			counts[bonuses.size()] += 1
		for j in bonuses.size():
			if int(bonuses[j].count) != j + 1: failed += 1
	print("[continuation] 2000 choices; bonus 0/1/2/3 = %s; fourth=%.6f run27=%.4f; invalid=%d" % [counts, fourth, run_27, failed])
	if absf(float(counts[0]) / 2000.0 - (1.0 - first)) > 0.03: failed += 1
	if absf(float(counts[1]) / 2000.0 - (first - second)) > 0.03: failed += 1
	if absf(float(counts[2]) / 2000.0 - (second - fourth)) > 0.03: failed += 1
	if absf(float(counts[3]) / 2000.0 - fourth) > 0.02: failed += 1
	session.free()
	var certain: GameConfig = ContentManager.cfg.duplicate(true)
	certain.levelup_bonus_chance = 1.0
	certain.levelup_bonus_more = 1.0
	certain.levelup_bonus_last = 1.0
	var visible: RunSession = RunManager.create_session(self, {"lab": true, "seed": 14, "config": certain}, true)
	visible.auto_step = false
	var run: RunSimulation = visible.sim
	var hud = visible.view.get_node("Hud/HudRoot")
	run.loadout.grant(&"weapon", &"W01")
	run.state.cards = [{"kind": &"weapon", "id": &"W01", "level": 2}]
	run.state.pending_levels = 2
	run.set_phase(RunState.Phase.LEVELUP)
	run.command(&"choose_card", {"index": 0})
	run.flush_events()
	var rewards = hud._rewards
	if run.state.pending_levels != 1 or run.state.cards.is_empty(): failed += 1
	for step in [2, 3, 4]:
		if not rewards.is_active() or int(rewards._current.count) != step - 1 or not rewards._count.text.contains(str(step)):
			failed += 1
		if step < 4: rewards.advance_bonus()
	var before: Array = run.state.cards.duplicate(true)
	run.command(&"choose_card", {"index": 0})
	if run.state.cards != before or run.state.pending_levels != 1: failed += 1
	rewards.advance_bonus()
	if rewards.is_active() or run.ui_reward_active: failed += 1
	print("[continuation] HUD steps=2,3,4; queued_level=1; final_failures=%d" % failed)
	visible.free()
	get_tree().quit(0 if failed == 0 else 1)
