## 成長と装備。経験値・レベル・3択・能力値・武器と特性の発動（仕様書 8・9）。
##
## 武器・特性の発動は、持っているものの WeaponBehavior / TraitBehavior の入口を呼んで行う。
class_name LoadoutSystem
extends RunSystem

func dispose() -> void:
	for behavior in weapon_behaviors.values() + trait_behaviors.values():
		behavior.ctx = null
	weapon_behaviors.clear()
	trait_behaviors.clear()
	for connection in cards_opened.get_connections():
		cards_opened.disconnect(connection.callable)
	super()

signal cards_opened(cards: Array)

var combat: CombatSystem:
	get: return ctx.combat
var projectiles: ProjectileSystem:
	get: return ctx.projectiles
var ship: ShipSystem:
	get: return ctx.ship
var enemies: EnemySystem:
	get: return ctx.enemies
var pickups: PickupSystem:
	get: return ctx.pickups
var field: FieldSystem:
	get: return ctx.field

## 管理 ID → 発動の処理
var weapon_behaviors: Dictionary = {}
var trait_behaviors: Dictionary = {}

func setup(context: RunContext) -> void:
	super(context)
	state.level = 0
	state.weapons = {}
	state.traits = {}
	refresh_stats()
	state.rerolls_left = cfg.reroll_count + roundi(_meta_add(&"reroll"))

# ── 能力値（設計書 8.2） ─────────────────────────────────────────

## 基礎値・特性・強化画面での強化から能力値を計算し直す（レベルでは変わらない）。
func refresh_stats() -> void:
	var s := state.stats
	var old_max := s.max_hp
	s.max_speed = cfg.base_max_speed * _meta_mult(&"max_speed") * (1.0 + _per(&"T10") * _n(&"T10"))
	s.attack_mult = _meta_mult(&"attack") * (1.0 + _per(&"T11") * _n(&"T11"))
	s.max_hp = cfg.base_hp + _meta_add(&"max_hp")
	s.capacity = 1.0 + _per(&"T08") * _n(&"T08")
	s.charge_time = cfg.dash_charge_time * _meta_reduce(&"charge_time") / (1.0 + _per(&"T07") * _n(&"T07"))
	s.crit_chance = minf(_trait_param(&"T09", "max", 1.0), cfg.base_crit_chance + _per(&"T09") * _n(&"T09"))
	s.crit_mult = cfg.crit_mult
	s.pickup_radius = cfg.pickup_radius * _meta_mult(&"pickup") * (1.0 + _per(&"T12") * _n(&"T12"))
	s.length_mult = _meta_mult(&"length") * (1.0 + _per(&"T14") * _n(&"T14"))
	s.glide_duration_mult = 1.0 + _per(&"T31") * _n(&"T31")
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
			var level := int(state.meta_override.get(String(def.id), 0)) if state.lab_mode else SaveManager.run_meta_level(def.id)
			out.append([def.per_level, level])
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

# ── 経験値とレベル（仕様書 9.1） ──────────────────────────────────

func xp_needed() -> float:
	var L := float(state.level)
	return cfg.xp_base + cfg.xp_growth * L + cfg.xp_curve * L * L

func add_xp(v: float) -> void:
	state.xp += v
	state.xp_gained += v
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
	ctx.projectiles.tick_attached(real_dt)
	if state.phase != RunState.Phase.PLAY:
		return
	var afterimage = weapon_behaviors.get(&"W27")
	if afterimage != null:
		afterimage.replay(real_dt)
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
## 拾った彗星限定の武器があれば、先に受け取る（枠が満員なら入れ替えを選ぶ）。
func try_open_cards() -> bool:
	if state.drawing or state.tracing:
		return false
	while not state.pending_comet_weapons.is_empty():
		var id: StringName = state.pending_comet_weapons.pop_front()
		if _receive_comet_weapon(id):
			return true
	if state.pending_levels <= 0:
		return false
	state.cards = roll_cards()
	cards_opened.emit(state.cards)
	return true

## ラン開始時に、最初の武器の候補を出す（仕様書 9.2）。
func open_start_cards() -> void:
	var out := roll_start_cards()
	if out.is_empty():
		return
	state.start_pick = true
	state.cards = out
	cards_opened.emit(state.cards)

## 最初の武器の候補：全武器からランダムに選ぶ。
func roll_start_cards() -> Array[Dictionary]:
	var ids: Array = ConfigManager.weapons.keys().filter(func(id): return not ConfigManager.weapons[id].comet_only)
	var out: Array[Dictionary] = []
	while out.size() < cfg.start_weapon_choices and not ids.is_empty():
		var id = ids.pop_at(state.rng.randi_range(0, ids.size() - 1))
		out.append({"kind": &"weapon", "id": id, "level": 1, "start": true})
	return out

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
			# 彗星限定の武器は3択に出さない（強化もない）
			if kind == &"weapon" and defs[id].comet_only:
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

## 表示中のカードを引き直す（仕様書 9.3）。最初の武器の選択でも使える。回数が残っていなければ false。
func reroll_cards() -> bool:
	if state.cards.is_empty() or state.rerolls_left <= 0 or state.swap_pick != &"":
		return false
	state.rerolls_left -= 1
	state.cards = roll_start_cards() if state.start_pick else roll_cards()
	state.emit(&"reroll", {})
	cards_opened.emit(state.cards)
	return true

## 3択のカードを選ぶ。次の3択があれば作り直し、なければ false を返す。
func choose_card(index: int) -> bool:
	if index < 0 or index >= state.cards.size():
		return state.pending_levels > 0
	var c: Dictionary = state.cards[index]
	if state.swap_pick != &"":
		if c.kind == &"swap":
			remove_weapon(c.id)
			grant(&"weapon", state.swap_pick, cfg.weapon_max_level)
			state.emit(&"upgrade", {"card": c})
		state.swap_pick = &""
		state.cards = []
		return try_open_cards()
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
	if c.kind != &"heal":
		_level_bonus()
	state.pending_levels = maxi(0, state.pending_levels - 1)
	if state.pending_levels > 0:
		state.cards = roll_cards()
		cards_opened.emit(state.cards)
		return true
	state.cards = []
	return false

## レベルアップのおまけ（仕様書 9.2）：選んだあと、確率で持っているものが自動で上がる。
## 起きたら次の確率で続けて判定し、4つ目（選んだ1枚を含めて）で止まる。
func _level_bonus() -> void:
	var count := 0
	for chance: float in [cfg.levelup_bonus_chance, cfg.levelup_bonus_more, cfg.levelup_bonus_last]:
		if state.rng.randf() >= chance:
			return
		var pick := _bonus_target()
		if pick.is_empty():
			return
		grant(pick.kind, pick.id)
		count += 1
		var owned: Dictionary = state.weapons if pick.kind == &"weapon" else state.traits
		state.emit(&"level_bonus", {"kind": pick.kind, "id": pick.id, "level": owned[pick.id], "count": count})

## おまけで上げる候補：持っている武器・特性のうち、上限に達していないものからランダムに1つ。なければ空。
func _bonus_target() -> Dictionary:
	var items: Array[Dictionary] = []
	for id in state.weapons:
		if state.weapons[id] < cfg.weapon_max_level:
			items.append({"kind": &"weapon", "id": id})
	for id in state.traits:
		if state.traits[id] < cfg.trait_max_stacks:
			items.append({"kind": &"trait", "id": id})
	if items.is_empty():
		return {}
	return items[state.rng.randi_range(0, items.size() - 1)]

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
		b.setup(ctx, def)
		table[id] = b
	if weapon:
		table[id].level = lv
	else:
		table[id].n = lv

## 武器を外す（彗星限定の武器と入れ替えるとき）。
func remove_weapon(id: StringName) -> void:
	state.weapons.erase(id)
	weapon_behaviors.erase(id)
	refresh_stats()

## 彗星限定の武器を受け取る（仕様書 8）。強化はなく、Lv の上限で装備する。持っていれば何もしない。
## 枠が満員なら、入れ替える武器を選ぶカードを開いて true を返す。
func _receive_comet_weapon(id: StringName) -> bool:
	if state.weapons.has(id):
		return false
	if state.weapons.size() < cfg.weapon_slots:
		grant(&"weapon", id, cfg.weapon_max_level)
		state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -60), "text": ConfigManager.weapons[id].get_display_name(),
			"color": Color("#efcb70"), "size": 24})
		return false
	state.swap_pick = id
	var out: Array[Dictionary] = []
	for owned in state.weapons:
		out.append({"kind": &"swap", "id": owned, "level": state.weapons[owned], "new": id})
	out.append({"kind": &"keep", "id": &"keep", "level": 1, "new": id})
	state.cards = out
	cards_opened.emit(state.cards)
	return true

## 質量牽引砲（W21）が、行 i の敵の船体を牽引するか。牽引したら true。
func capture_hull(i: int) -> bool:
	var tow = weapon_behaviors.get(&"W21")
	return tow != null and tow.capture(i)

## 装備をすべて外す（調整パネル用）。
func reset_loadout() -> void:
	state.weapons = {}
	state.traits = {}
	weapon_behaviors = {}
	trait_behaviors = {}
	refresh_stats()

# ── 発動のきっかけ（CombatSystem・DrawSystem・ShipSystem から呼ばれる） ─

func on_launch(full: bool) -> void:
	for b in trait_behaviors.values():
		b.on_launch(full)
	for b in weapon_behaviors.values():
		b.on_launch(full)

func on_trail(run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	ctx.projectiles.trail_attached(p0, p1)
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

## 高速で敵（行 i）に触れた。
func on_contact(i: int, hit: Vector2, dir: Vector2) -> void:
	on_electric_contact(i)
	for b in weapon_behaviors.values():
		if state.phase != RunState.Phase.PLAY:
			return
		b.on_contact(i, hit, dir)

## 普段の接触でも発動するもの（接触電撃）。
func on_electric_contact(i: int) -> void:
	for b in weapon_behaviors.values():
		if state.phase != RunState.Phase.PLAY:
			return
		b.on_any_contact(i)

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
