## 固定色の経験値結晶と、部品・修理キット・回収ビーコン・彗星限定武器のドロップと回収。
class_name PickupSystem
extends RunSystem

const XP_REWARD_VERSION := 2
enum GemKind { LOW, MID, HIGH }
const KIND_NAMES := ["low", "mid", "high"]
const CAP_MODE := "oldest_high_absorber"

signal xp_recorded(record: Dictionary)

var field: FieldSystem:
	get: return ctx.field
var ship: ShipSystem:
	get: return ctx.ship
var build: LoadoutSystem:
	get: return ctx.loadout
var enemies: EnemySystem:
	get: return ctx.enemies

## 位置・色・保持基準XPは独立して持つ。集約先の黄色だけが可変の保持XPを持つ。
var gem_alive := PackedByteArray()
var gem_pos := PackedVector2Array()
var gem_kind := PackedByteArray()
var gem_value := PackedFloat64Array()
var gem_pulled := PackedByteArray()
## 運搬と再ドロップでも保つ結晶ID。
var gem_seq := PackedInt64Array()
## 今回地面に置かれた順。最古の吸収先を選ぶ基準。
var gem_order := PackedInt64Array()
var gem_origin: Array[Dictionary] = []
var gem_vel := PackedVector2Array()
var gem_wait := PackedFloat32Array()
var gem_slots: RowSlots
var coin_alive := PackedByteArray()
var coin_pos := PackedVector2Array()
var coin_pulled := PackedByteArray()
var coin_slots: RowSlots
var capsules: Array = []

var _next_gem_id := 0
var _next_ground_order := 0
var _absorber_row := -1
var _absorber_id := -1
## 敵の安定ID → {row, crystals:[{id, kind, base_xp, origin}]}。
var _cargo: Dictionary = {}
var _supplied: Dictionary = {}
var _collected: Dictionary = {}
var _lost: Dictionary = {}
var _collected_actual_xp := 0.0
var _gold_eligible := 0
var _gold_won := 0

func setup(context: RunContext) -> void:
	super(context)
	assert(cfg.gem_max > 0, "結晶の保持上限は正の個数")
	gem_slots = RowSlots.new(self, "gem_")
	coin_slots = RowSlots.new(self, "coin_")
	assert(Columns.check_add(self, gem_slots.cols,
		func(): return _add_gem(Vector2.ONE, {"id": 0, "kind": GemKind.LOW, "base_xp": 1.0, "origin": {}}), gem_slots.release))
	_clear_gems()
	_next_gem_id = 0
	_next_ground_order = 0
	_cargo.clear()
	_supplied = _empty_counts()
	_collected = _empty_counts(true)
	_lost = _empty_counts()
	_collected_actual_xp = 0.0
	_gold_eligible = 0
	_gold_won = 0
	assert(Columns.check_add(self, coin_slots.cols, func(): return _add_coin(Vector2.ONE), coin_slots.release))
	coin_slots.clear()

func dispose() -> void:
	for item in _effects.values(): item.dispose()
	_effects.clear()
	_cargo.clear()
	for slots in [gem_slots, coin_slots]:
		if slots != null: slots.owner = null
	super()

func tick(_real_dt: float, world_dt: float) -> void:
	_prune_cargo()
	if world_dt <= 0.0: return
	var perf := ctx.perf
	var t0 := Time.get_ticks_usec()
	_collect_gems(world_dt)
	perf.since(&"pickups.gems", t0)
	t0 = Time.get_ticks_usec()
	_collect_coins(world_dt)
	perf.since(&"pickups.coins", t0)
	t0 = Time.get_ticks_usec()
	_collect_capsules(world_dt)
	perf.since(&"pickups.capsules", t0)

## 実撃破の1回だけ呼ぶ。固定報酬は敵の定義を解決したときの値を使う。
func on_enemy_killed(i: int) -> void:
	var t := enemies.table
	if t.is_boss[i] != 0 or t.def[i] == null: return
	var reward := enemies.reward_of(t.def[i])
	var counts: PackedInt32Array = reward.counts
	var scattered := int(t.def[i].params.get("gem_count", 1)) > 1
	var count := counts[0] + counts[1] + counts[2]
	var index := 0
	for kind in KIND_NAMES.size():
		for _k in counts[kind]:
			if scattered:
				var u := Vector2.from_angle(TAU * index / float(maxi(count, 1)) + state.rng.randf() * 0.5)
				drop_crystal(t.pos[i] + u * t.r[i] * 0.3, kind, &"enemy", t.type[i], t.id[i],
					u * state.rng.randf_range(240.0, 380.0), 0.35)
			else:
				drop_crystal(t.pos[i], kind, &"enemy", t.type[i], t.id[i])
			index += 1
	if scattered and count > 0 and t.type[i] != &"splitter":
		state.emit(&"gem_burst", {"pos": t.pos[i], "r": t.r[i]})
	if reward.gold_eligible:
		_gold_eligible += 1
		var won := state.rng.randf() < cfg.strong_gold_chance
		if won: _gold_won += 1
		if records_xp(): record_xp({"type": "xp_gold_roll", "enemy": String(t.type[i]), "enemy_id": t.id[i],
			"chance": cfg.strong_gold_chance, "won": won})
		if won: drop_crystal(t.pos[i], GemKind.HIGH, &"strong_gold", t.type[i], t.id[i])
	_redrop_cargo(i)
	_drop_coins(i)
	enemies.extra_drops(self, i)

## 新規供給の入口。色の基準XPを1回だけ計上する。
func drop_crystal(p: Vector2, kind: int, source := &"direct", enemy := &"", enemy_id := -1,
		velocity := Vector2.ZERO, wait := 0.0) -> int:
	assert(kind >= GemKind.LOW and kind <= GemKind.HIGH)
	var value := cfg.xp_crystal_values[kind]
	var crystal := {"id": _next_gem_id, "kind": kind, "base_xp": value,
		"origin": {"source": String(source), "enemy": String(enemy), "enemy_id": enemy_id,
			"spawn_t": state.time, "spawn_world_t": state.world_time}}
	_next_gem_id += 1
	_count(_supplied, kind, value)
	state.xp_dropped += value
	return _place_crystal(p, crystal, true, source, velocity, wait)

## 空きだけ生成する。戻り値-1は新しい地面の個体を作らず吸収先へ加算したことを表す。
func _place_crystal(p: Vector2, crystal: Dictionary, new_supply: bool, source: StringName,
		velocity := Vector2.ZERO, wait := 0.0, carrier_id := -1) -> int:
	if gem_slots.live >= cfg.gem_max:
		var target := _ensure_absorber()
		assert(target >= 0, "満杯の地面には吸収先となる結晶がある")
		var before := gem_value[target]
		gem_value[target] += float(crystal.base_xp)
		if records_xp():
			var event := _crystal_record(crystal)
			event.merge({"type": "xp_absorb", "source": String(source), "new_supply": new_supply, "carrier_id": carrier_id,
				"target_id": gem_seq[target], "target_kind": "high", "before_base_xp": before,
				"after_base_xp": gem_value[target], "requested_pos": [p.x, p.y], "ground_count": gem_slots.live})
			record_xp(event)
		return -1
	var pos := p + Vector2.from_angle(state.rng.randf() * TAU) * 8.0
	var row := _add_gem(pos, crystal)
	gem_vel[row] = velocity
	gem_wait[row] = wait
	if records_xp():
		var event := _crystal_record(crystal)
		event.merge({"type": "xp_drop", "source": String(source), "new_supply": new_supply, "carrier_id": carrier_id,
			"pos": [pos.x, pos.y], "ground_count": gem_slots.live})
		record_xp(event)
	return row

func _add_gem(p: Vector2, crystal: Dictionary) -> int:
	var i := gem_slots.take()
	gem_pos[i] = p
	gem_kind[i] = int(crystal.kind)
	gem_value[i] = float(crystal.base_xp)
	gem_pulled[i] = 0
	gem_seq[i] = int(crystal.id)
	gem_order[i] = _next_ground_order
	gem_origin[i] = crystal.origin.duplicate()
	gem_vel[i] = Vector2.ZERO
	gem_wait[i] = 0.0
	_next_ground_order += 1
	return i

func _valid_absorber() -> bool:
	return _absorber_row >= 0 and _absorber_row < gem_alive.size() and gem_alive[_absorber_row] != 0 \
		and gem_seq[_absorber_row] == _absorber_id and gem_kind[_absorber_row] == GemKind.HIGH

func _ensure_absorber() -> int:
	if _valid_absorber(): return _absorber_row
	var oldest := -1
	var oldest_high := -1
	for i in gem_alive.size():
		if gem_alive[i] == 0: continue
		if oldest < 0 or gem_order[i] < gem_order[oldest]: oldest = i
		if gem_kind[i] == GemKind.HIGH and (oldest_high < 0 or gem_order[i] < gem_order[oldest_high]): oldest_high = i
	var chosen := oldest_high if oldest_high >= 0 else oldest
	if chosen < 0: return -1
	var old_kind := gem_kind[chosen]
	gem_kind[chosen] = GemKind.HIGH
	_absorber_row = chosen
	_absorber_id = gem_seq[chosen]
	if records_xp(): record_xp({"type": "xp_absorber", "reason": "oldest_high" if oldest_high >= 0 else "oldest_promoted",
		"id": _absorber_id, "before_kind": KIND_NAMES[old_kind], "after_kind": "high",
		"before_base_xp": gem_value[chosen], "after_base_xp": gem_value[chosen]})
	return chosen

func _release_gem(i: int, reason: StringName) -> void:
	if gem_seq[i] == _absorber_id:
		var previous := _absorber_id
		_absorber_row = -1
		_absorber_id = -1
		if records_xp(): record_xp({"type": "xp_absorber", "reason": String(reason), "previous_id": previous, "id": -1})
	gem_slots.release(i)

func _clear_gems() -> void:
	gem_slots.clear()
	_absorber_row = -1
	_absorber_id = -1


## 地面の個体を1つ丸ごと運搬へ移す。指定吸収先なら地面から離れる時点で解除する。
func carry_crystal(enemy_row: int, crystal_row: int) -> void:
	var t := enemies.table
	if crystal_row < 0 or gem_alive[crystal_row] == 0 or t.alive[enemy_row] == 0 or t.dead[enemy_row] != 0: return
	var enemy_id := t.id[enemy_row]
	if not _cargo.has(enemy_id): _cargo[enemy_id] = {"row": enemy_row, "crystals": []}
	var crystal := _row_crystal(crystal_row)
	_cargo[enemy_id].crystals.append(crystal)
	t.carry[enemy_row] += float(crystal.base_xp)
	t.buds[enemy_row] += 1
	var was_absorber := int(crystal.id) == _absorber_id
	_release_gem(crystal_row, &"carried")
	if records_xp():
		var event := _crystal_record(crystal)
		event.merge({"type": "xp_transfer", "method": "crow", "enemy_id": enemy_id, "was_absorber": was_absorber})
		record_xp(event)

## 運搬者の撃破時に、盗んだ個体を色・実保持XP・元の出所のまま戻す。
func _redrop_cargo(enemy_row: int) -> void:
	var t := enemies.table
	var enemy_id := t.id[enemy_row]
	if not _cargo.has(enemy_id): return
	var crystals: Array = _cargo[enemy_id].crystals
	_cargo.erase(enemy_id)
	t.carry[enemy_row] = 0.0
	t.buds[enemy_row] = 0
	for k in crystals.size():
		var pos := t.pos[enemy_row] + Vector2.from_angle(TAU * k / float(crystals.size())) * (10.0 + 4.0 * float(k % 3))
		_place_crystal(pos, crystals[k], false, &"crow_carry", Vector2.ZERO, 0.0, enemy_id)

func lose_carried(enemy_row: int, reason: StringName = &"retreat") -> void:
	var t := enemies.table
	if enemy_row >= 0 and enemy_row < t.id.size(): _lose_cargo(t.id[enemy_row], reason)

func lose_all_carried(reason: StringName = &"cleared") -> void:
	for enemy_id in _cargo.keys(): _lose_cargo(enemy_id, reason)

func _lose_cargo(enemy_id: int, reason: StringName) -> void:
	if not _cargo.has(enemy_id): return
	var cargo: Dictionary = _cargo[enemy_id]
	_cargo.erase(enemy_id)
	var row: int = cargo.row
	if enemies.is_same(row, enemy_id):
		enemies.table.carry[row] = 0.0
		enemies.table.buds[row] = 0
	for crystal: Dictionary in cargo.crystals:
		_count(_lost, int(crystal.kind), float(crystal.base_xp))
		if records_xp():
			var event := _crystal_record(crystal)
			event.merge({"type": "xp_lost", "method": "crow", "enemy_id": enemy_id, "reason": String(reason)})
			record_xp(event)

## 非撃破の行整理・再利用を補完する。実撃破ではon_enemy_killedが先に運搬分を戻す。
func _prune_cargo() -> void:
	if ctx == null or ctx.enemies == null: return
	for enemy_id in _cargo.keys():
		var row: int = _cargo[enemy_id].row
		if not enemies.is_same(row, enemy_id) or enemies.table.dead[row] != 0:
			_lose_cargo(enemy_id, &"owner_removed")

## ビーコンは呼出し開始時の地面の全個体と倍率を一度だけ確定する。
func collect_all_gems(method: StringName = &"magnet") -> float:
	var rows := PackedInt32Array()
	for i in gem_alive.size():
		if gem_alive[i] != 0: rows.append(i)
	return _collect_gem_rows(rows, method)

## 通常回収とビーコン共通の取得入口。1回の回収中のレベル変化で倍率を読み直さない。
func _collect_gem_rows(rows: PackedInt32Array, method: StringName) -> float:
	var multiplier := build.crystal_multiplier()
	var base_total := 0.0
	var details: Array = []
	var count := 0
	var recording := records_xp()
	for row in rows:
		if row < 0 or row >= gem_alive.size() or gem_alive[row] == 0: continue
		var value := gem_value[row]
		var kind := gem_kind[row]
		base_total += value
		count += 1
		_count(_collected, kind, value, value * multiplier)
		if recording:
			var item := _crystal_record(_row_crystal(row))
			item["actual_xp"] = value * multiplier
			item["was_absorber"] = gem_seq[row] == _absorber_id
			details.append(item)
		_release_gem(row, &"collected")
	if count == 0: return 0.0
	var actual := build.add_crystal_xp(base_total, multiplier)
	_collected_actual_xp += actual
	state.emit(&"pickup", {"kind": &"gem"})
	if recording:
		var event := {"type": "xp_collect", "method": String(method), "base_xp": base_total,
			"xp": base_total, "actual_xp": actual, "multiplier": multiplier, "count": count, "gems": details}
		if count == 1:
			event["id"] = details[0].id
			event["kind"] = details[0].kind
			event["origin"] = details[0].origin
		record_xp(event)
	return actual

func _row_crystal(i: int) -> Dictionary:
	return {"id": gem_seq[i], "kind": int(gem_kind[i]), "base_xp": gem_value[i], "origin": gem_origin[i].duplicate()}

func _crystal_record(crystal: Dictionary) -> Dictionary:
	return {"id": int(crystal.id), "kind": KIND_NAMES[int(crystal.kind)], "base_xp": float(crystal.base_xp),
		"xp": float(crystal.base_xp), "origin": crystal.origin.duplicate()}

static func _empty_counts(actual := false) -> Dictionary:
	var result := {}
	for kind in KIND_NAMES:
		result[kind] = {"count": 0, "base_xp": 0.0}
		if actual: result[kind]["actual_xp"] = 0.0
	return result

static func _count(counts: Dictionary, kind: int, base: float, actual := 0.0) -> void:
	var entry: Dictionary = counts[KIND_NAMES[kind]]
	entry.count += 1
	entry.base_xp += base
	if entry.has("actual_xp"): entry.actual_xp += actual

func _cap_snapshot() -> Dictionary:
	return {"mode": CAP_MODE, "limit": cfg.gem_max, "absorber_id": _absorber_id if _valid_absorber() else -1}

func xp_summary() -> Dictionary:
	_prune_cargo()
	var ground := _empty_counts()
	for i in gem_alive.size():
		if gem_alive[i] != 0: _count(ground, gem_kind[i], gem_value[i])
	var carried := _empty_counts()
	for cargo: Dictionary in _cargo.values():
		for crystal: Dictionary in cargo.crystals: _count(carried, int(crystal.kind), float(crystal.base_xp))
	return {"supplied": _supplied.duplicate(true), "collected": _collected.duplicate(true), "lost": _lost.duplicate(true),
		"collected_actual_xp": _collected_actual_xp, "gold_rolls": {"eligible": _gold_eligible, "won": _gold_won},
		"ground": ground, "carried": carried, "cap": _cap_snapshot()}

func xp_snapshot() -> Dictionary:
	_prune_cargo()
	var ground := []
	for i in gem_alive.size():
		if gem_alive[i] == 0: continue
		ground.append({"id": gem_seq[i], "kind": KIND_NAMES[gem_kind[i]], "base_xp": gem_value[i],
			"pos": [gem_pos[i].x, gem_pos[i].y], "absorber": gem_seq[i] == _absorber_id})
	var carried := []
	for enemy_id in _cargo:
		var crystals := []
		for crystal: Dictionary in _cargo[enemy_id].crystals:
			crystals.append({"id": int(crystal.id), "kind": KIND_NAMES[int(crystal.kind)], "base_xp": float(crystal.base_xp)})
		carried.append({"enemy_id": enemy_id, "crystals": crystals})
	return {"ground": ground, "carried": carried, "cap": _cap_snapshot()}


## 部品を1行加え、その行番号を返す。空いた行を使い回すので、coin_ の全部の列をここで書き直す。
func _add_coin(p: Vector2) -> int:
	var i := coin_slots.take()
	coin_pos[i] = p
	coin_pulled[i] = 0
	return i

func _drop_coins(i: int) -> void:
	var t := enemies.table
	var n := 0
	if t.elite[i] != 0:
		n = 3 + state.rng.randi_range(0, 3)
	else:
		var behavior := enemies.row_behavior(i)
		n = behavior.coin_count(i) if behavior != null else (1 if state.rng.randf() < 0.03 else 0)
	var pos := t.pos[i]
	var r := t.r[i]
	for k in n:
		_add_coin(pos + Vector2.from_angle(state.rng.randf() * TAU) * state.rng.randf() * r)

func _add_capsule(kind: Pickup.Kind, src: StringName, p: Vector2) -> void:
	var c := Pickup.new()
	c.kind = kind
	c.src = src
	c.pos = p
	capsules.append(c)

# ── 拾う ──────────────────────────────────────────────────────────

func _collect_gems(dt: float) -> void:
	_fly_gems(dt)
	enemies.gather_pickups(self, dt)
	var reach := cfg.ship_radius + 14.0
	var radius := state.stats.xp_pickup_radius
	var step := (700.0 + state.ship_vel.length() * 1.2) * state.stats.pickup_speed_mult * dt
	# 吸い寄せも回収もされない遠くの結晶は、平方根を使わない距離比較だけで飛ばす
	var far := maxf(radius, reach)
	var far_sq := far * far
	var ship_pos := state.ship_pos
	for i in gem_alive.size():
		if gem_alive[i] == 0:
			continue
		if gem_wait[i] > 0.0:
			continue
		var p := gem_pos[i]
		var pulled := gem_pulled[i]
		if pulled == 0 and ship_pos.distance_squared_to(p) >= far_sq:
			continue
		var d := ship_pos - p
		var dist := d.length()
		if dist < radius or pulled != 0:
			gem_pulled[i] = 1
			gem_pos[i] = p + d / maxf(dist, 1.0) * minf(step, dist)
		if dist < reach:
			_collect_gem_rows(PackedInt32Array([i]), &"ship")

func records_xp() -> bool:
	return OS.is_debug_build() and xp_recorded.has_connections()

func record_xp(record: Dictionary) -> void:
	if not records_xp(): return
	record["xp_reward_version"] = XP_REWARD_VERSION
	record["cap_mode"] = CAP_MODE
	record["cap_limit"] = cfg.gem_max
	record["absorber_id"] = _absorber_id if _valid_absorber() else -1
	record["t"] = state.time
	record["world_t"] = state.world_time
	xp_recorded.emit(record)

## はじけ飛んでいる結晶を動かす。勢いは落ちていき、拾えるようになるまでの時間を減らす。
func _fly_gems(dt: float) -> void:
	for i in gem_alive.size():
		if gem_alive[i] == 0 or gem_wait[i] <= 0.0:
			continue
		gem_pos[i] += gem_vel[i] * dt
		gem_vel[i] *= exp(-dt * 5.0)
		gem_wait[i] -= dt

func _collect_coins(dt: float) -> void:
	var reach := cfg.ship_radius + 14.0
	var radius := state.stats.pickup_radius * 1.3
	var step := (700.0 + state.ship_vel.length() * 1.2) * dt
	var far := maxf(radius, reach)
	var far_sq := far * far
	var ship_pos := state.ship_pos
	for i in coin_alive.size():
		if coin_alive[i] == 0:
			continue
		var p := coin_pos[i]
		var pulled := coin_pulled[i]
		if pulled == 0 and ship_pos.distance_squared_to(p) >= far_sq:
			continue
		var d := ship_pos - p
		var dist := d.length()
		if dist < radius or pulled != 0:
			coin_pulled[i] = 1
			coin_pos[i] = p + d / maxf(dist, 1.0) * minf(step, dist)
		if dist < reach:
			collect(&"coin")
			coin_slots.release(i)

func _collect_capsules(dt: float) -> void:
	var reach := 22.0 + cfg.ship_radius + 14.0
	var pull_r := state.stats.pickup_radius * 1.6
	for c: Pickup in capsules:
		if c.taken:
			continue
		c.age += dt
		var can := effect(StringName(Pickup.Kind.keys()[c.kind].to_lower())).can_collect(c)
		# 彗星限定の武器のカプセルは吸い寄せない（自分で触って拾う）
		if c.src == &"drop" and can:
			var d := state.ship_pos - c.pos
			var dist := d.length()
			if dist < pull_r and dist > 1.0:
				c.pos += d / dist * minf((600.0 + state.ship_vel.length()) * dt, dist)
		if can and c.pos.distance_squared_to(state.ship_pos) < reach * reach:
			c.taken = true
			_apply(c)
		elif c.src == &"drop" and c.age > cfg.pickup_life:
			c.taken = true
	var kept: Array = []
	for c: Pickup in capsules:
		if not c.taken:
			kept.append(c)
	capsules = kept

var _effects: Dictionary = {}

func effect(kind: StringName) -> PickupEffect:
	if not _effects.has(kind):
		var item: PickupEffect = load("res://scripts/pickups/%s.gd" % kind).new()
		item.setup(ctx)
		_effects[kind] = item
	return _effects[kind]

func collect(kind: StringName, value := 0.0, pickup: Pickup = null) -> void:
	var item := effect(kind)
	item.apply(value, pickup)
	state.emit(&"pickup", {"kind": kind})
	if pickup != null:
		state.emit(&"ring", {"pos": pickup.pos, "radius": item.ring_radius, "color": item.ring_color, "life": 0.5})

func _apply(c: Pickup) -> void:
	collect(StringName(Pickup.Kind.keys()[c.kind].to_lower()), 0.0, c)
