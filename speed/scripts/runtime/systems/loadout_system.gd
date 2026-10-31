## 成長と装備。経験値・レベル・3択・能力値・武器と特性の発動（仕様書 8・9）。
##
## 武器・特性の発動は、持っているものの WeaponBehavior / TraitBehavior の入口を呼んで行う。
class_name LoadoutSystem
extends RunSystem

func dispose() -> void:
	_release_candidates()
	for scope: ContentResourceScope in _equipped_resources.values(): scope.cancel()
	_equipped_resources.clear()
	for behavior in weapon_behaviors.values() + trait_behaviors.values():
		behavior.ctx = null
	weapon_behaviors.clear()
	trait_behaviors.clear()
	for connection in cards_opened.get_connections():
		cards_opened.disconnect(connection.callable)
	post_max.ctx = null
	super()

var _candidate_resources: Dictionary = {}
var _equipped_resources: Dictionary = {}
var _pending_choice := -1
var _applied_post_max_hp := 0.0
var boost_distance := 0.0
var kill_position := Vector2.ZERO
var post_max := PostMaxProgression.new()

func resource_scopes() -> Array:
	return _candidate_resources.values() + _equipped_resources.values()

func resources_for_card(id: StringName) -> ContentResourceScope:
	return _candidate_resources.get(id)

func _release_candidates() -> void:
	for scope: ContentResourceScope in _candidate_resources.values(): scope.cancel()
	_candidate_resources.clear()
	_pending_choice = -1

func _publish_cards() -> void:
	_release_candidates()
	for card in state.cards:
		if card.kind == &"post_max" or card.kind == &"heal": continue
		var id: StringName = state.swap_pick if state.swap_pick != &"" else card.id
		var category: StringName = &"weapons" if state.swap_pick != &"" or card.kind == &"weapon" else &"traits"
		var entry := ContentManager.catalog.find(category, id)
		if entry != null and not _candidate_resources.has(id):
			_candidate_resources[id] = ContentManager.prepare_resources(entry.resources, DisplayServer.get_name() != "headless")
	cards_opened.emit(state.cards)

func poll_choice() -> Variant:
	if _pending_choice < 0: return null
	var index := _pending_choice
	var card: Dictionary = state.cards[index]
	var id: StringName = state.swap_pick if state.swap_pick != &"" else card.id
	var scope := resources_for_card(id)
	if scope != null and (not scope.is_ready() or not scope.warmup_complete): return null
	_pending_choice = -1
	return choose_card(index)

func _claim_resources(category: StringName, id: StringName) -> void:
	if _equipped_resources.has(id): return
	var scope := resources_for_card(id)
	if scope != null:
		_candidate_resources.erase(id)
	else:
		scope = ContentManager.prepare_resources(ContentManager.catalog.find(category, id).resources, false)
	_equipped_resources[id] = scope

signal cards_opened(cards: Array)
signal equipment_changed
## 記録中だけ購読する装備の差分。選択画面で時計が止まっていても即座に通知する。
signal loadout_recorded(change: Dictionary)
signal choice_recorded(card: Dictionary, source: StringName)

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
	post_max.setup(context)
	state.level = 0
	state.weapons = {}
	state.traits = {}
	state.post_max_stacks = {}
	refresh_stats()
	state.rerolls_left = cfg.reroll_count + roundi(float(ctx.profile.add.get(&"reroll", 0.0)))

# ── 能力値（設計書 8.2） ─────────────────────────────────────────

## 基礎値・特性・強化画面での強化から能力値を計算し直す（レベルでは変わらない）。
func refresh_stats() -> void:
	var s := state.stats
	var old_max := s.max_hp
	s.max_speed = cfg.base_max_speed * float(ctx.profile.mult.get(&"max_speed", 1.0)) * (1.0 + _trait_bonus(&"T10"))
	s.attack_mult = float(ctx.profile.mult.get(&"attack", 1.0)) * (1.0 + _trait_bonus(&"T11"))
	s.max_hp = cfg.base_hp + float(ctx.profile.add.get(&"max_hp", 0.0))
	s.capacity = 1.0 + _trait_bonus(&"T08")
	s.charge_time = cfg.dash_charge_time * float(ctx.profile.reduce.get(&"charge_time", 1.0)) / (1.0 + _trait_bonus(&"T07"))
	var crit_def := ContentManager.definition(&"traits", &"T09") as TraitDef
	s.crit_chance = minf(_trait_param(&"T09", "max", 1.0), cfg.base_crit_chance + (crit_def.stack_bonus(_n(&"T09")) if crit_def != null else 0.0))
	s.crit_mult = cfg.crit_mult
	s.pickup_radius = cfg.pickup_radius * float(ctx.profile.mult.get(&"pickup", 1.0)) * (1.0 + _trait_bonus(&"T12"))
	s.length_mult = float(ctx.profile.mult.get(&"length", 1.0)) * (1.0 + _trait_bonus(&"T14"))
	s.glide_duration_mult = 1.0 + _trait_bonus(&"T31")
	s.xp_mult = float(ctx.profile.mult.get(&"xp", 1.0))
	# HP増加は現在HPを維持。既存の永続HP変更時の差分回復だけを残す。
	var old_baseline_max := old_max - _applied_post_max_hp
	var baseline_max := s.max_hp
	_apply_post_max_stats()
	_applied_post_max_hp = s.max_hp - baseline_max
	if old_baseline_max > 0.0 and baseline_max > old_baseline_max:
		state.ship_hp += baseline_max - old_baseline_max
	state.ship_hp = minf(state.ship_hp, s.max_hp)

func _apply_post_max_stats() -> void:
	post_max.apply_stats()

## 満員の武器枠を基準にする。彗星限定も装備時から上限として数える。
func all_weapons_max() -> bool:
	if cfg.weapon_slots <= 0 or state.weapons.size() < cfg.weapon_slots:
		return false
	for id in state.weapons:
		if ContentManager.catalog.find(&"weapons", id) == null or int(state.weapons[id]) < cfg.weapon_max_level:
			return false
	return true

## 取得可能な特性枠が埋まり、所持している特性がすべて上限に達したか。
func all_traits_max() -> bool:
	if cfg.trait_slots <= 0 or state.traits.size() < cfg.trait_slots:
		return false
	for id in state.traits:
		if ContentManager.catalog.find(&"traits", id) == null or int(state.traits[id]) < cfg.trait_max_stacks:
			return false
	return true

func normal_progression_complete() -> bool:
	return all_weapons_max() and all_traits_max()

func _n(id: StringName) -> int:
	return state.traits.get(id, 0)

## 能力値を変える特性の値（.tres の params）。
func _trait_param(id: StringName, key: String, default := 0.0) -> float:
	var def := ContentManager.definition(&"traits", id) as TraitDef
	return float(def.params.get(key, default)) if def != null else default

func _trait_bonus(id: StringName) -> float:
	var def := ContentManager.definition(&"traits", id) as TraitDef
	return def.stack_bonus(_n(id)) if def != null else 0.0

# ── 経験値とレベル（仕様書 9.1） ──────────────────────────────────

func xp_needed() -> float:
	var L := float(state.level)
	return cfg.xp_base + cfg.xp_growth * L + cfg.xp_curve * L * L

func add_xp(v: float) -> void:
	v *= state.stats.xp_gain_mult
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
	if state.controls_locked: return
	var busy := state.drawing or state.tracing
	# 開発版の計測：武器・特性ごとの時間を build.<ID> に足す
	var perf := ctx.perf
	var t0 := Time.get_ticks_usec()
	ctx.projectiles.tick_attached(real_dt,world_dt)
	perf.since(&"build.attached", t0)
	if state.phase != RunState.Phase.PLAY or state.controls_locked:
		return
	for id: StringName in weapon_behaviors:
		t0 = Time.get_ticks_usec()
		weapon_behaviors[id].tick_real(real_dt)
		if perf.active:
			perf.since(StringName("build." + String(id)), t0)
		if state.phase != RunState.Phase.PLAY:
			return
	if world_dt > 0.0:
		for id: StringName in weapon_behaviors:
			t0 = Time.get_ticks_usec()
			weapon_behaviors[id].tick(world_dt, busy)
			if perf.active:
				perf.since(StringName("build." + String(id)), t0)
			if state.phase != RunState.Phase.PLAY:
				return
		for id: StringName in trait_behaviors:
			t0 = Time.get_ticks_usec()
			trait_behaviors[id].tick(world_dt, busy)
			if perf.active:
				perf.since(StringName("build." + String(id)), t0)

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
	if state.cards.is_empty():
		# 取得可能な候補が尽きた場合は空の選択画面で進行を止めない。
		state.pending_levels = 0
		return false
	_publish_cards()
	return true

## ラン開始時に、最初の武器の候補を出す（仕様書 9.2）。
func open_start_cards() -> void:
	var out := roll_start_cards()
	if out.is_empty():
		return
	state.start_pick = true
	state.cards = out
	_publish_cards()

## 最初の武器の候補：全武器からランダムに選ぶ。
func roll_start_cards() -> Array[Dictionary]:
	var ids: Array = ContentManager.catalog.table(&"weapons").keys().filter(func(id): return not ContentManager.catalog.find(&"weapons", id).comet_only)
	var out: Array[Dictionary] = []
	while out.size() < cfg.start_weapon_choices and not ids.is_empty():
		var id = ids.pop_at(state.rng.randi_range(0, ids.size() - 1))
		out.append({"kind": &"weapon", "id": id, "level": 1, "start": true})
	return out

func roll_cards() -> Array[Dictionary]:
	var enhanced := normal_progression_complete()
	var pool: Array = post_max.cards() if enhanced else []
	for kind in [&"weapon", &"trait"]:
		var defs := ContentManager.catalog.table(&"weapons" if kind == &"weapon" else &"traits")
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
	# 通常育成が完了したら、毎回少なくとも1枚の追加強化を提示する。
	if enhanced:
		var enhancements := pool.filter(func(c): return c.kind == &"post_max")
		if not enhancements.is_empty():
			var first: Dictionary = enhancements[state.rng.randi_range(0, enhancements.size() - 1)]
			out.append(first)
			pool.erase(first)
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
	return out

## 表示中のカードを引き直す（仕様書 9.3）。最初の武器の選択でも使える。回数が残っていなければ false。
func reroll_cards() -> bool:
	if state.cards.is_empty() or state.rerolls_left <= 0 or state.swap_pick != &"":
		return false
	var next := roll_start_cards() if state.start_pick else roll_cards()
	if next.is_empty(): return false
	state.rerolls_left -= 1
	state.cards = next
	state.emit(&"reroll", {})
	_publish_cards()
	return true

## 3択のカードを選ぶ。次の3択があれば作り直し、なければ false を返す。
func choose_card(index: int) -> bool:
	if index < 0 or index >= state.cards.size():
		return state.pending_levels > 0
	var c: Dictionary = state.cards[index]
	var selection: StringName = state.swap_pick if state.swap_pick != &"" else c.id
	var preparation := resources_for_card(selection)
	if c.kind != &"keep" and preparation != null and preparation.failed:
		push_error("装備の資源を準備できないため、選択を保留します: %s" % selection)
		_pending_choice = -1
		return true
	if c.kind != &"keep" and preparation != null and (not preparation.is_ready() or not preparation.warmup_complete):
		_pending_choice = index
		return true
	if state.swap_pick != &"":
		if choice_recorded.has_connections(): choice_recorded.emit(c, &"comet_swap")
		if c.kind == &"swap":
			remove_weapon(c.id, &"comet_swap")
			grant(&"weapon", state.swap_pick, cfg.weapon_max_level, &"comet_swap")
			state.emit(&"upgrade", {"card": c})
		state.swap_pick = &""
		_release_candidates()
		state.cards = []
		return try_open_cards()
	if state.start_pick:
		if choice_recorded.has_connections(): choice_recorded.emit(c, &"initial_choice")
		state.start_pick = false
		grant(c.kind, c.id, 1, &"initial_choice")
		_release_candidates()
		state.cards = []
		return false
	if c.kind == &"post_max":
		if not post_max.select(c.id):
			state.cards = roll_cards()
			_publish_cards()
			return true
		refresh_stats()
	if c.kind == &"heal":
		ship.heal(state.stats.max_hp * cfg.fallback_heal)
	elif c.kind != &"post_max":
		grant(c.kind, c.id, 1, &"card")
	if choice_recorded.has_connections(): choice_recorded.emit(c, &"card")
	state.emit(&"upgrade", {"card": c})
	if c.kind == &"weapon" or c.kind == &"trait":
		_level_bonus()
	state.pending_levels = maxi(0, state.pending_levels - 1)
	if state.pending_levels > 0:
		state.cards = roll_cards()
		if not state.cards.is_empty():
			_publish_cards()
			return true
		state.pending_levels = 0
	_release_candidates()
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
		grant(pick.kind, pick.id, 1, &"level_bonus")
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
func grant(kind: StringName, id: StringName, levels := 1, source := &"direct") -> bool:
	var weapon := kind == &"weapon"
	var category: StringName = &"weapons" if weapon else &"traits"
	var def := ContentManager.definition(category, id)
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
	_claim_resources(category, id)
	_sync_behavior(weapon, id, def, owned[id])
	if id == &"T34": refresh_sonic_wave_speed()
	refresh_stats()
	_record_change(kind, id, lv, int(owned[id]), source)
	equipment_changed.emit()
	return true

func _record_change(kind: StringName, id: StringName, previous: int, current: int, source: StringName) -> void:
	if OS.is_debug_build() and loadout_recorded.has_connections():
		loadout_recorded.emit({"type": "loadout", "t": state.time, "world_t": state.world_time,
			"kind": String(kind), "id": String(id), "previous": previous, "current": current,
			"source": String(source), "level": state.level})

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
		if id == &"W08": refresh_sonic_wave_speed()
	else:
		table[id].n = lv

func refresh_sonic_wave_speed() -> void:
	var sonic = weapon_behaviors.get(&"W08")
	if sonic != null and sonic.has_method(&"refresh_wave_speed"): sonic.refresh_wave_speed()

## 武器を外す（彗星限定の武器と入れ替えるとき）。
func remove_weapon(id: StringName, source := &"direct") -> void:
	var previous := int(state.weapons.get(id, 0))
	if _equipped_resources.has(id):
		_equipped_resources[id].cancel()
		_equipped_resources.erase(id)
	state.weapons.erase(id)
	if previous > 0: _record_change(&"weapon", id, previous, 0, source)
	if weapon_behaviors.has(id): weapon_behaviors[id].dispose()
	weapon_behaviors.erase(id)
	refresh_stats()
	equipment_changed.emit()

## 彗星限定の武器を受け取る（仕様書 8）。強化はなく、Lv の上限で装備する。持っていれば何もしない。
## 枠が満員なら、入れ替える武器を選ぶカードを開いて true を返す。
func _receive_comet_weapon(id: StringName) -> bool:
	if state.weapons.has(id):
		return false
	if state.weapons.size() < cfg.weapon_slots:
		grant(&"weapon", id, cfg.weapon_max_level, &"comet")
		state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -60), "text": ContentManager.catalog.find(&"weapons", id).get_display_name(),
			"color": Color("#efcb70"), "size": 24})
		return false
	state.swap_pick = id
	var out: Array[Dictionary] = []
	for owned in state.weapons:
		out.append({"kind": &"swap", "id": owned, "level": state.weapons[owned], "new": id})
	out.append({"kind": &"keep", "id": &"keep", "level": 1, "new": id})
	state.cards = out
	_publish_cards()
	return true

## 質量牽引砲（W21）が、行 i の敵の船体を牽引するか。牽引したら true。
func capture_hull(i: int) -> bool:
	var tow = weapon_behaviors.get(&"W21")
	return tow != null and tow.capture(i)

## 装備をすべて外す（調整パネル用）。
func reset_loadout() -> void:
	for kind in [&"weapon", &"trait"]:
		var owned: Dictionary = state.weapons if kind == &"weapon" else state.traits
		for id in owned: _record_change(kind, id, int(owned[id]), 0, &"reset")
	_release_candidates()
	for scope: ContentResourceScope in _equipped_resources.values(): scope.cancel()
	_equipped_resources.clear()
	combat.burst_power=1.0
	combat.ignore_armor=false
	for b in weapon_behaviors.values(): b.dispose()
	state.weapons = {}
	state.traits = {}
	state.post_max_stacks = {}
	weapon_behaviors = {}
	trait_behaviors = {}
	refresh_stats()
	equipment_changed.emit()

# ── 発動のきっかけ（CombatSystem・DrawSystem・ShipSystem から呼ばれる） ─

func on_launch(full: bool) -> void:
	boost_distance = 0.0
	for b in trait_behaviors.values():
		b.on_launch(full)
	for b in weapon_behaviors.values():
		b.on_launch(full)

func on_trail(run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	boost_distance += p0.distance_to(p1)
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
func on_contact(i: int, hit: Vector2, dir: Vector2, damage := 0.0) -> void:
	on_electric_contact(i)
	for b in weapon_behaviors.values():
		if state.phase != RunState.Phase.PLAY:
			return
		b.on_contact(i, hit, dir)
		b.on_ram_hit(i, hit, dir, damage)
	for b in trait_behaviors.values():
		b.on_contact(i, hit, dir, damage)

## 普段の接触でも発動するもの（接触電撃）。
func on_electric_contact(i: int) -> void:
	for b in weapon_behaviors.values():
		if state.phase != RunState.Phase.PLAY:
			return
		b.on_any_contact(i)

func on_kill(cause: StringName, pos := Vector2.ZERO) -> void:
	kill_position = pos
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

func on_phase_changed(phase: RunState.Phase) -> void:
	for behavior in weapon_behaviors.values():
		behavior.on_phase_changed(phase)

## 攻撃範囲・弾数・射撃頻度は、装備を選んだ時点の共通値から求める。
func area_multiplier() -> float:
	return 1.0 + _trait_bonus(&"T34")

func shot_count(base: int) -> int:
	var amount := base * (1.0 + _trait_bonus(&"T35"))
	var count := floori(amount)
	return count + (1 if state.rng.randf() < amount - count else 0)

func shooting_rate() -> float:
	if _n(&"T36") == 0 or state.gauge < 1.0: return 1.0
	return 1.0 + (_trait_param(&"T36", "rate_base") + _trait_param(&"T36", "rate_per") * _n(&"T36")) * state.gauge

func damage_multiplier() -> float:
	var rampage = trait_behaviors.get(&"T33")
	return rampage.multiplier() if rampage != null else 1.0

## 弾・星屑・槍は同じ確率と同時数の上限を共有する。
func split_vectors(velocity: Vector2, generation: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := _n(&"T37")
	if n == 0: return out
	var d: TraitDef = trait_behaviors[&"T37"].def if trait_behaviors.has(&"T37") else ContentManager.definition(&"traits", &"T37") as TraitDef
	if generation >= int(d.params.generations) or projectiles.flying_count() + 2 > int(d.params.max): return out
	if state.rng.randf() >= float(d.params.chance_by_level[n - 1]): return out
	for side in [-1.0, 1.0]:
		var angle: float = deg_to_rad(state.rng.randf_range(float(d.params.angle_min), float(d.params.angle_max))) * side
		out.append(velocity.rotated(angle) * state.rng.randf_range(0.9, 1.1))
	return out

func split_damage() -> float:
	var d: TraitDef = trait_behaviors[&"T37"].def if trait_behaviors.has(&"T37") else ContentManager.definition(&"traits", &"T37") as TraitDef
	return float(d.params.damage_by_level[_n(&"T37") - 1]) if _n(&"T37") > 0 else 1.0

func prepare_ram(extra_distance: float) -> float:
	var distance := boost_distance + extra_distance
	var gear = trait_behaviors.get(&"T04")
	if gear != null: combat.burst_power = gear.multiplier(distance) if state.tracing else 1.0
	var run_up = trait_behaviors.get(&"T32")
	return run_up.multiplier(distance) if state.tracing and run_up != null else 1.0
