## 英雄の開始時・発見時・解放後の誘導だけを短時間確認する。
## Godot --headless --path speed res://tests/hero_guidance.tscn
extends Node

class BlockedField:
	extends FieldManager
	func body_gap(_p: Vector2, _radius: float) -> float:
		return 0.0

var failed := 0

func _ready() -> void:
	var cfg: GameConfig = load("res://data/config.tres")
	var s := RunState.new()
	var h := HeroManager.new()
	var field := FieldManager.new()
	var blocked := BlockedField.new()
	var enemies := EnemyManager.new()
	var combat := CombatManager.new()
	combat.setup(s, cfg)
	h.state = s
	h.cfg = cfg
	h.field = field
	h.enemies = enemies
	h.combat = combat
	var def: HeroDef = load("res://data/heroes/perseus.tres")
	var spawn := Vector2(-cfg.start_radius, 0.0)
	s.ship_pos = spawn
	# 修正前は2548.552の距離に配置され、最初の更新で発見される。
	s.rng.seed = 5
	h._place(def)
	h.tick(0.01, 0.01)
	_check(not h.seen and not h.revealed() and s.landmarks.is_empty(), "start hides the unvisited hero")
	var center := h.center
	s.ship_pos = center + Vector2(cfg.hero_glow_range - 1.0, 0.0)
	h.tick(0.01, 0.01)
	_check(h.seen and h.revealed() and h.is_captive(), "passing nearby reveals the captive hero")
	s.ship_pos = spawn
	h.tick(0.01, 0.01)
	_check(h.revealed() and h.is_captive(), "guidance persists after leaving")
	h.lit.fill(1)
	h._free()
	_check(h.revealed() and not h.is_captive() and s.hero_power == def.id, "freed hero keeps its map point and stops edge guidance")
	h._place(def)
	_check(not h.revealed() and not h.seen, "next hero clears discovery")
	s.landmarks.append(Vector2(100, 100))
	_check(not h.revealed(), "one recovered landmark leaves the hero hidden")
	s.landmarks.append(Vector2(-100, 100))
	_check(h.revealed() and h.is_captive(), "two recovered landmarks enable guidance without a visit")
	# 障害物との間隔が成立しない場合も、最後の近すぎる候補を採用しない。
	h.field = blocked
	for seed_value in [0, 5, 19]:
		s.rng.seed = seed_value
		h._place(def)
		h.tick(0.01, 0.01)
		_check(s.ship_pos.distance_to(h.center) > cfg.hero_glow_range and not h.revealed(), "attempt limit stays undiscovered (seed %d)" % seed_value)
	h.free()
	field.free()
	blocked.free()
	enemies.free()
	combat.free()
	print("[hero-guidance] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else:
		print("[hero-guidance] PASS ", label)
