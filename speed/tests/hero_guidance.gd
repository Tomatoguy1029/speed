## 英雄の開始時・発見時・解放後の誘導だけを短時間確認する。
## Godot --headless --path speed res://tests/hero_guidance.tscn
extends Node

class BlockedField:
	extends FieldSystem
	func body_gap(_p: Vector2, _radius: float) -> float:
		return 0.0

var failed := 0

func _ready() -> void:
	var cfg: GameConfig = load("res://data/config.tres")
	var s := RunState.new()
	var h := HeroSystem.new()
	var field := FieldSystem.new()
	var blocked := BlockedField.new()
	var enemies := EnemySystem.new()
	var combat := CombatSystem.new()
	var context := RunContext.new()
	context.state = s
	context.cfg = cfg
	context.field = field
	context.enemies = enemies
	context.combat = combat
	context.heroes = h
	combat.setup(context)
	h.ctx = context
	h.state = s
	h.cfg = cfg
	var def: HeroDef = load("res://data/heroes/perseus.tres")
	var spawn := Vector2(-cfg.start_radius, 0.0)
	s.ship_pos = spawn
	# 修正前は2548.552の距離に配置され、最初の更新で発見される。
	s.rng.seed = 5
	h._place(def)
	h.tick(0.01, 0.01)
	_check(not h.seen and not h.revealed() and s.landmarks.is_empty(), "start hides the unvisited hero")
	_check(_discoveries(s) == 0, "hidden hero emits no discovery")
	var center := h.center
	s.ship_pos = center + Vector2(cfg.hero_glow_range - 1.0, 0.0)
	h.tick(0.01, 0.01)
	_check(h.seen and h.revealed() and h.is_captive(), "passing nearby reveals the captive hero")
	_check(_discoveries(s) == 1, "proximity announces discovery once")
	h.tick(0.01, 0.01)
	_check(_discoveries(s) == 1, "remaining nearby does not repeat the notification")
	s.ship_pos = spawn
	h.tick(0.01, 0.01)
	_check(h.revealed() and h.is_captive(), "guidance persists after leaving")
	_check(_discoveries(s) == 1, "leaving and returning preserves the discovery count")
	h.lit.fill(1)
	h._free()
	_check(h.revealed() and not h.is_captive() and s.hero_power == def.id, "freed hero keeps its map point and stops edge guidance")
	h._place(def)
	_check(not h.revealed() and not h.seen, "next hero clears discovery")
	s.landmarks.append(Vector2(100, 100))
	h.tick(0.01, 0.01)
	_check(not h.revealed(), "one recovered landmark leaves the hero hidden")
	_check(_discoveries(s) == 1, "one landmark does not announce a hidden hero")
	s.landmarks.append(Vector2(-100, 100))
	h.tick(0.01, 0.01)
	_check(h.revealed() and h.is_captive(), "two recovered landmarks enable guidance without a visit")
	_check(_discoveries(s) == 2, "the next hero can announce discovery from two landmarks")
	s.ship_pos = h.center
	h.tick(0.01, 0.01)
	_check(_discoveries(s) == 2, "later proximity does not repeat landmark discovery")
	# 障害物との間隔が成立しない場合も、最後の近すぎる候補を採用しない。
	context.field = blocked
	for seed_value in [0, 5, 19]:
		s.rng.seed = seed_value
		h._place(def)
		h.tick(0.01, 0.01)
		_check(s.ship_pos.distance_to(h.center) > cfg.hero_glow_range and not h.revealed(), "attempt limit stays undiscovered (seed %d)" % seed_value)
	for system in [h, field, blocked, enemies, combat]:
		system.dispose()
	print("[hero-guidance] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else:
		print("[hero-guidance] PASS ", label)

func _discoveries(s: RunState) -> int:
	return s.events.filter(func(e): return e.type == &"hero_discovered").size()
