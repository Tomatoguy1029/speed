## 成長と装備。経験値・レベル・3択・能力値・武器と特性の発動（仕様書 8・9）。
##
## 武器・特性の発動は、持っているものの WeaponBehavior / TraitBehavior の入口を呼んで行う。
class_name BuildManager
extends RunSystem

signal cards_opened(cards: Array)

var combat: CombatManager
var projectiles: ProjectileManager
var ship: ShipManager
var enemies: EnemyManager
var pickups: PickupManager
var field: FieldManager

## 管理 ID → 発動の処理
var weapon_behaviors: Dictionary = {}
var trait_behaviors: Dictionary = {}
var cores := 0
## 機体と一緒に進路を進む衝撃波（ソニックブームと連鎖ソニックで共通。一覧 W08・T05）
var sonic_waves: Array = []
var _buf: Array = []

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
	state.level = 0
	state.weapons = {}
	state.traits = {}
	refresh_stats()
	state.rerolls_left = cfg.reroll_count + roundi(_meta_add(&"reroll"))

# ── 能力値（設計書 8.2） ─────────────────────────────────────────

## 基礎値・レベル・特性・強化画面での強化・出力コアから能力値を計算し直す。
func refresh_stats() -> void:
	var s := state.stats
	var old_max := s.max_hp
	var lv := float(state.level)
	s.max_speed = cfg.base_max_speed * _meta_mult(&"max_speed") * (1.0 + cfg.level_speed_growth * lv) \
		* (1.0 + cfg.core_boost * cores) * (1.0 + _per(&"T10") * _n(&"T10"))
	s.attack_mult = _meta_mult(&"attack") * (1.0 + cfg.level_atk_growth * lv) * (1.0 + _per(&"T11") * _n(&"T11"))
	s.max_hp = cfg.base_hp + _meta_add(&"max_hp") + cfg.level_hp_growth * lv
	s.capacity = 1.0 + _per(&"T08") * _n(&"T08")
	s.charge_time = cfg.dash_charge_time * _meta_reduce(&"charge_time") / (1.0 + _per(&"T07") * _n(&"T07"))
	s.crit_chance = minf(_trait_param(&"T09", "max", 1.0), cfg.base_crit_chance + _per(&"T09") * _n(&"T09"))
	s.crit_mult = cfg.crit_mult
	s.pickup_radius = cfg.pickup_radius * _meta_mult(&"pickup") * (1.0 + _per(&"T12") * _n(&"T12"))
	s.length_mult = 1.0 + _per(&"T14") * _n(&"T14")
	s.xp_mult = _meta_mult(&"xp")
	if old_max > 0.0 and s.max_hp > old_max:
		state.ship_hp += s.max_hp - old_max
	state.ship_hp = minf(state.ship_hp, s.max_hp)

func _n(id: StringName) -> int:
	return state.traits.get(id, 0)

## 能力値を変える特性の値（.tres の params）。
func _trait_param(id: StringName, key: String, default := 0.0) -> float:
	var def: TraitDef = ConfigManager.traits.get(id)
	return float(def.params.get(key, default)) if def != null else default

func _per(id: StringName) -> float:
	return _trait_param(id, "per_stack")

## 強化画面での強化（仕様書 14）。
func _meta_level(stat: StringName) -> Array:
	var out := []
	for def: MetaUpgradeDef in ConfigManager.meta_upgrades.values():
		if def.stat == stat:
			out.append([def.per_level, SaveManager.meta_level(def.id)])
	return out

func _meta_mult(stat: StringName) -> float:
	var m := 1.0
	for pl in _meta_level(stat):
		m *= 1.0 + pl[0] * pl[1]
	return m

func _meta_add(stat: StringName) -> float:
	var a := 0.0
	for pl in _meta_level(stat):
		a += pl[0] * pl[1]
	return a

func _meta_reduce(stat: StringName) -> float:
	var m := 1.0
	for pl in _meta_level(stat):
		m *= pow(1.0 - pl[0], pl[1])
	return m

func add_core() -> void:
	cores += 1
	refresh_stats()

# ── 経験値とレベル（仕様書 9.1） ──────────────────────────────────

func xp_needed() -> float:
	var L := float(state.level)
	return cfg.xp_base + cfg.xp_growth * L + cfg.xp_curve * L * L

func add_xp(v: float) -> void:
	state.xp += v
	var need := xp_needed()
	while state.xp >= need:
		state.xp -= need
		state.level += 1
		state.pending_levels += 1
		state.ship_hp = minf(state.stats.max_hp, state.ship_hp + state.stats.max_hp * cfg.level_heal)
		state.emit(&"levelup", {"level": state.level})
		state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -34), "text": "Lv %d" % state.level, "color": Color("#6dffb0"), "size": 18})
		need = xp_needed()
		refresh_stats()

# ── 3択（仕様書 9.2・9.4） ─────────────────────────────────────────

func tick(real_dt: float, world_dt: float) -> void:
	var busy := state.drawing or state.tracing
	_update_sonic(real_dt)
	if state.phase != RunState.Phase.PLAY:
		return
	if world_dt > 0.0:
		for b in weapon_behaviors.values():
			b.tick(world_dt, busy)
			if state.phase != RunState.Phase.PLAY:
				return
		for b in trait_behaviors.values():
			b.tick(world_dt, busy)

## 保留中のレベルアップがあり、描画中・なぞり中でなければ3択を開く。開いたら true。
func try_open_cards() -> bool:
	if state.pending_levels <= 0 or state.drawing or state.tracing:
		return false
	state.cards = roll_cards()
	cards_opened.emit(state.cards)
	return true

## ラン開始時に、最初の武器の候補を出す（仕様書 9.2）。
func open_start_cards() -> void:
	var ids: Array = ConfigManager.weapons.keys()
	var out: Array[Dictionary] = []
	while out.size() < cfg.start_weapon_choices and not ids.is_empty():
		var id = ids.pop_at(state.rng.randi_range(0, ids.size() - 1))
		out.append({"kind": &"weapon", "id": id, "level": 1, "start": true})
	if out.is_empty():
		return
	state.start_pick = true
	state.cards = out
	cards_opened.emit(state.cards)

func roll_cards() -> Array[Dictionary]:
	var pool: Array = []
	for kind in [&"weapon", &"trait"]:
		var defs: Dictionary = ConfigManager.weapons if kind == &"weapon" else ConfigManager.traits
		var owned: Dictionary = state.weapons if kind == &"weapon" else state.traits
		var slots := cfg.weapon_slots if kind == &"weapon" else cfg.trait_slots
		var max_lv := cfg.weapon_max_level if kind == &"weapon" else cfg.trait_max_stacks
		var free := owned.size() < slots
		for id in defs:
			var lv: int = owned.get(id, 0)
			if lv >= max_lv or (lv == 0 and not free):
				continue
			pool.append({"kind": kind, "id": id, "level": lv + 1, "weight": cfg.owned_card_bias if lv > 0 else 1.0})
	var out: Array[Dictionary] = []
	while out.size() < 3 and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += c.weight
		var roll := state.rng.randf() * total
		var i := 0
		while i < pool.size() - 1 and roll >= pool[i].weight:
			roll -= pool[i].weight
			i += 1
		out.append(pool[i])
		pool.remove_at(i)
	while out.size() < 3:
		out.append({"kind": &"heal", "id": StringName("heal%d" % out.size()), "level": 1})
	return out

## 3択のカードを引き直す（仕様書 9.2）。回数が残っていなければ false。
func reroll_cards() -> bool:
	if state.cards.is_empty() or state.rerolls_left <= 0 or state.start_pick:
		return false
	state.rerolls_left -= 1
	state.cards = roll_cards()
	state.emit(&"reroll", {})
	cards_opened.emit(state.cards)
	return true

## 3択のカードを選ぶ。次の3択があれば作り直し、なければ false を返す。
func choose_card(index: int) -> bool:
	if index < 0 or index >= state.cards.size():
		return state.pending_levels > 0
	var c: Dictionary = state.cards[index]
	if state.start_pick:
		state.start_pick = false
		grant(c.kind, c.id)
		state.cards = []
		return false
	if c.kind == &"heal":
		ship.heal(state.stats.max_hp * cfg.fallback_heal)
	else:
		grant(c.kind, c.id)
	state.emit(&"upgrade", {"card": c})
	state.pending_levels = maxi(0, state.pending_levels - 1)
	if state.pending_levels > 0:
		state.cards = roll_cards()
		cards_opened.emit(state.cards)
		return true
	state.cards = []
	return false

# ── 装備（仕様書 8） ─────────────────────────────────────────────

## 武器・特性を levels 段階手に入れる。枠が満員か上限なら false。
func grant(kind: StringName, id: StringName, levels := 1) -> bool:
	var weapon := kind == &"weapon"
	var defs: Dictionary = ConfigManager.weapons if weapon else ConfigManager.traits
	var def = defs.get(id)
	if def == null:
		return false
	var owned: Dictionary = state.weapons if weapon else state.traits
	var max_lv := cfg.weapon_max_level if weapon else cfg.trait_max_stacks
	var slots := cfg.weapon_slots if weapon else cfg.trait_slots
	var lv: int = owned.get(id, 0)
	if lv == 0 and owned.size() >= slots:
		return false
	if lv >= max_lv:
		return false
	owned[id] = mini(max_lv, lv + levels)
	if not state.modules_obtained.has(id):
		state.modules_obtained.append(id)
	_sync_behavior(weapon, id, def, owned[id])
	refresh_stats()
	return true

func _sync_behavior(weapon: bool, id: StringName, def: Resource, lv: int) -> void:
	var table := weapon_behaviors if weapon else trait_behaviors
	if not table.has(id):
		var path := "res://scripts/%s/%s.gd" % ["weapons" if weapon else "traits", def.code_id]
		var b
		if ResourceLoader.exists(path):
			b = load(path).new()
		else:
			b = WeaponBehavior.new() if weapon else TraitBehavior.new()
		b.setup(self, def)
		table[id] = b
	if weapon:
		table[id].level = lv
	else:
		table[id].n = lv

## 装備をすべて外す（調整パネル用）。
func reset_loadout() -> void:
	state.weapons = {}
	state.traits = {}
	weapon_behaviors = {}
	trait_behaviors = {}
	refresh_stats()

# ── 衝撃波（W08・T05 で共通） ───────────────────────────────────

## 機体の位置に衝撃波を出す。0.5実秒、機体と一緒に進路を進み、同じ波動では各敵に1回だけ当たる。
func run_sonic(cause: StringName, radius: float, dmg: float, knock: float, travel: float) -> void:
	var wave := {"pos": state.ship_pos, "radius": radius, "dmg": dmg, "cause": cause, "knock": knock,
		"life": travel, "hits": {}}
	sonic_waves.append(wave)
	if sonic_waves.size() > 4:
		sonic_waves.pop_front()
	_sweep_sonic(wave, state.ship_pos, state.ship_pos)
	state.emit(&"ring", {"pos": state.ship_pos, "radius": radius, "color": Color("#c8f7ff"), "life": 0.5})
	state.emit(&"sonic", {"pos": state.ship_pos, "radius": radius})

func _sweep_sonic(wave: Dictionary, p0: Vector2, p1: Vector2) -> void:
	var steps := maxi(1, ceili(p0.distance_to(p1) / (wave.radius * 0.3)))
	for i in range(1, steps + 1):
		if state.phase != RunState.Phase.PLAY:
			return
		var p := p0.lerp(p1, float(i) / steps)
		combat.nearby(p, wave.radius, _buf)
		for e: Enemy in _buf:
			if e.dead or wave.hits.has(e.id):
				continue
			wave.hits[e.id] = true
			var d := e.pos - p
			var dist := d.length()
			combat.damage_enemy(e, wave.dmg, {"cause": wave.cause, "dir": d / dist if dist > 0.0 else Vector2.ZERO, "knock": wave.knock})
			if state.phase != RunState.Phase.PLAY:
				return
	wave.pos = p1

func _update_sonic(real_dt: float) -> void:
	for wave in sonic_waves.duplicate():
		if state.phase != RunState.Phase.PLAY:
			return
		if not state.tracing:
			_sweep_sonic(wave, wave.pos, state.ship_pos)
		wave.life -= real_dt
	sonic_waves = sonic_waves.filter(func(w): return w.life > 0.0)

# ── 発動のきっかけ（CombatManager・DrawManager・ShipManager から呼ばれる） ─

func on_launch(full: bool) -> void:
	for b in trait_behaviors.values():
		b.on_launch(full)
	for b in weapon_behaviors.values():
		b.on_launch(full)

func on_trail(run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	# なぞった区間ごとに、衝撃波も角を含めて進める
	for wave in sonic_waves.duplicate():
		_sweep_sonic(wave, p0, p1)
		if state.phase != RunState.Phase.PLAY:
			return
	for b in weapon_behaviors.values():
		b.on_trail(run, p0, p1)
		if state.phase != RunState.Phase.PLAY:
			return
	for b in trait_behaviors.values():
		b.on_trail(run, p0, p1)
		if state.phase != RunState.Phase.PLAY:
			return

func on_contact(e: Enemy, hit: Vector2, dir: Vector2) -> void:
	on_electric_contact(e)
	for b in weapon_behaviors.values():
		if state.phase != RunState.Phase.PLAY:
			return
		b.on_contact(e, hit, dir)

## 普段の接触でも発動するもの（接触電撃）。
func on_electric_contact(e: Enemy) -> void:
	for b in weapon_behaviors.values():
		if state.phase != RunState.Phase.PLAY:
			return
		b.on_any_contact(e)

func on_kill(cause: StringName) -> void:
	for b in trait_behaviors.values():
		b.on_kill(cause)
	for b in weapon_behaviors.values():
		b.on_kill(cause)

func on_critical(p: Vector2) -> void:
	for b in trait_behaviors.values():
		b.on_critical(p)

func on_hurt() -> void:
	for b in trait_behaviors.values():
		b.on_hurt()

## なぞりの終わり（なぞり終えた、または弾かれた）。
func on_end() -> void:
	for b in weapon_behaviors.values():
		b.on_end()
	for b in trait_behaviors.values():
		if state.phase != RunState.Phase.PLAY:
			return
		b.on_end()
	combat.burst_power = 1.0
	combat.ignore_armor = false
