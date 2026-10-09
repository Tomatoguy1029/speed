## ドロップと回収（仕様書 10）。経験値の結晶・部品・経験値カプセル・漂流カプセル・修理キット・回収ビーコン・出力コア。
class_name PickupManager
extends RunSystem

var field: FieldManager
var ship: ShipManager
var build: BuildManager
var enemies: EnemyManager

## 経験値の結晶と部品は、1つごとの箱を作らず項目ごとの列で持つ。i 番目は各列の i 番目（設計書 6）。
var gem_pos := PackedVector2Array()
var gem_value := PackedFloat64Array()
## 吸い寄せが始まったか（1 なら始まった）
var gem_pulled := PackedByteArray()
var coin_pos := PackedVector2Array()
var coin_pulled := PackedByteArray()
var capsules: Array = []
var _capsule_t := 0.0
var _core_t := 0.0
var _cores_started := false

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	_spawn_field_capsules(world_dt)
	_spawn_cores(world_dt)
	_collect_gems(world_dt)
	_collect_coins(world_dt)
	_collect_capsules(world_dt)

# ── 落とす ────────────────────────────────────────────────────────

## 敵を倒したときのドロップ。
func on_enemy_killed(e: Enemy) -> void:
	var danger := field.danger_at(e.pos.length())
	var phase := enemies.current_phase()
	var bonus := phase.xp_bonus if phase.xp_bonus > 0.0 else 1.0
	drop_gem(e.pos, e.xp * state.stats.xp_mult * bonus * (1.0 + danger))
	_drop_coins(e, danger)
	if e.type == &"meteor":
		if state.rng.randf() < cfg.meteor_heal_chance:
			_add_capsule(Pickup.Kind.HEAL, &"drop", e.pos, 0.0)
		if state.rng.randf() < cfg.meteor_magnet_chance:
			_add_capsule(Pickup.Kind.MAGNET, &"drop", e.pos, 0.0)
	var chance := minf(cfg.drop_max, cfg.drop_base * pow(e.xp, cfg.drop_power_exp))
	if state.rng.randf() < chance:
		_add_capsule(Pickup.Kind.CACHE, &"drop", e.pos, build.xp_needed() * cfg.capsule_xp_frac)

func drop_gem(p: Vector2, v: float) -> void:
	if gem_pos.size() > cfg.gem_max:
		# いちばん古い結晶を、新しい結晶にまとめる
		v += gem_value[0]
		gem_pos.remove_at(0)
		gem_value.remove_at(0)
		gem_pulled.remove_at(0)
	gem_pos.append(p + Vector2.from_angle(state.rng.randf() * TAU) * 8.0)
	gem_value.append(v)
	gem_pulled.append(0)

func _drop_coins(e: Enemy, danger: float) -> void:
	var n := 0
	if e.type == &"battleship":
		n = 12
	elif e.elite:
		n = 3 + state.rng.randi_range(0, 3)
	elif e.type == &"meteor":
		n = (1 + state.rng.randi_range(0, 2)) if state.rng.randf() < cfg.meteor_coin_chance else 0
	elif state.rng.randf() < 0.03 * (1.0 + danger * 2.0):
		n = 1
	for i in n:
		coin_pos.append(e.pos + Vector2.from_angle(state.rng.randf() * TAU) * state.rng.randf() * e.r)
		coin_pulled.append(0)

func _add_capsule(kind: Pickup.Kind, src: StringName, p: Vector2, xp: float) -> void:
	var c := Pickup.new()
	c.kind = kind
	c.src = src
	c.pos = p
	c.value = xp
	capsules.append(c)

## 漂流カプセル：フィールドに最大 n 個。16秒ごとに補充（仕様書 10）。
func _spawn_field_capsules(dt: float) -> void:
	var view_r := state.view_half.length()
	var kept: Array = []
	for c: Pickup in capsules:
		if c.src != &"field" or c.pos.distance_to(state.ship_pos) < view_r * 2.0:
			kept.append(c)
	capsules = kept
	_capsule_t += dt
	var count := 0
	for c: Pickup in capsules:
		if c.src == &"field":
			count += 1
	if count >= cfg.drift_capsule_count or not (state.time < 2.0 or _capsule_t >= cfg.drift_capsule_interval):
		return
	_capsule_t = 0.0
	var distance := maxf(200.0, view_r * (0.25 + state.rng.randf() * 0.3))
	for i in 16:
		var p := state.ship_pos + Vector2.from_angle(state.rng.randf() * TAU) * distance
		var r := p.length()
		if r > cfg.planet_radius + 100.0 and r < cfg.field_radius - 100.0:
			_add_capsule(Pickup.Kind.CACHE, &"field", p, build.xp_needed() * cfg.drift_capsule_xp_frac)
			return

## 出力コア：脱出期に、中心付近へ最大3個（仕様書 10）。
func _spawn_cores(dt: float) -> void:
	if not enemies.current_phase().cores:
		return
	_core_t += dt
	var cores := 0
	for c: Pickup in capsules:
		if c.kind == Pickup.Kind.CORE:
			cores += 1
	if cores >= 3 or (_cores_started and _core_t < 20.0):
		return
	_core_t = 0.0
	var r := state.rng.randf_range(cfg.planet_radius + 250.0, cfg.zone_inner - 300.0)
	_add_capsule(Pickup.Kind.CORE, &"core", Vector2.from_angle(state.rng.randf() * TAU) * r, 0.0)
	if not _cores_started or cores >= 2:
		_cores_started = true
	state.emit(&"core")

# ── 拾う ──────────────────────────────────────────────────────────

func _collect_gems(dt: float) -> void:
	var reach := cfg.ship_radius + 14.0
	var radius := state.stats.pickup_radius
	var step := (700.0 + state.ship_vel.length() * 1.2) * dt
	# 吸い寄せも回収もされない遠くの結晶は、平方根を使わない距離比較だけで残す
	var far := maxf(radius, reach)
	var far_sq := far * far
	var ship_pos := state.ship_pos
	var n := gem_pos.size()
	var w := 0
	for i in n:
		var p := gem_pos[i]
		var pulled := gem_pulled[i]
		if pulled != 0 or ship_pos.distance_squared_to(p) < far_sq:
			var d := ship_pos - p
			var dist := d.length()
			if dist < radius or pulled != 0:
				pulled = 1
				p += d / maxf(dist, 1.0) * minf(step, dist)
			if dist < reach:
				build.add_xp(gem_value[i])
				state.emit(&"pickup", {"kind": &"gem"})
				continue
		# 残る結晶を前へ詰める
		gem_pos[w] = p
		gem_value[w] = gem_value[i]
		gem_pulled[w] = pulled
		w += 1
	# 回収の処理中に落ちた結晶も残す
	for j in range(n, gem_pos.size()):
		gem_pos[w] = gem_pos[j]
		gem_value[w] = gem_value[j]
		gem_pulled[w] = gem_pulled[j]
		w += 1
	gem_pos.resize(w)
	gem_value.resize(w)
	gem_pulled.resize(w)

func _collect_coins(dt: float) -> void:
	var reach := cfg.ship_radius + 14.0
	var radius := state.stats.pickup_radius * 1.3
	var step := (700.0 + state.ship_vel.length() * 1.2) * dt
	var far := maxf(radius, reach)
	var far_sq := far * far
	var ship_pos := state.ship_pos
	var n := coin_pos.size()
	var w := 0
	for i in n:
		var p := coin_pos[i]
		var pulled := coin_pulled[i]
		if pulled != 0 or ship_pos.distance_squared_to(p) < far_sq:
			var d := ship_pos - p
			var dist := d.length()
			if dist < radius or pulled != 0:
				pulled = 1
				p += d / maxf(dist, 1.0) * minf(step, dist)
			if dist < reach:
				state.coins += 1
				state.emit(&"pickup", {"kind": &"coin"})
				continue
		coin_pos[w] = p
		coin_pulled[w] = pulled
		w += 1
	for j in range(n, coin_pos.size()):
		coin_pos[w] = coin_pos[j]
		coin_pulled[w] = coin_pulled[j]
		w += 1
	coin_pos.resize(w)
	coin_pulled.resize(w)

func _collect_capsules(dt: float) -> void:
	var reach := 22.0 + cfg.ship_radius + 14.0
	var pull_r := state.stats.pickup_radius * 1.6
	for c: Pickup in capsules:
		if c.taken:
			continue
		c.age += dt
		var can := c.kind != Pickup.Kind.HEAL or state.ship_hp < state.stats.max_hp
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

func _apply(c: Pickup) -> void:
	match c.kind:
		Pickup.Kind.CORE:
			build.add_core()
			state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -50), "text": "出力 +%d%%" % roundi(cfg.core_boost * 100.0), "color": Color("#ffd24a"), "size": 18})
		Pickup.Kind.HEAL:
			var before := state.ship_hp
			ship.heal(state.stats.max_hp * cfg.meteor_heal_frac)
			state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -40), "text": "HP +%d" % roundi(state.ship_hp - before), "color": Color("#67e8b1"), "size": 18})
		Pickup.Kind.MAGNET:
			var xp := 0.0
			for v in gem_value:
				xp += v
			gem_pos.clear()
			gem_value.clear()
			gem_pulled.clear()
			for other: Pickup in capsules:
				if other.kind == Pickup.Kind.CACHE and not other.taken:
					xp += other.value
					other.taken = true
			build.add_xp(xp)
			state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -45), "text": "XP +%d" % roundi(xp), "color": Color("#b8a0ff"), "size": 22})
		Pickup.Kind.CACHE:
			build.add_xp(c.value)
			state.emit(&"text", {"pos": c.pos, "text": "XP", "color": Color("#b8a0ff"), "size": 16})
	state.emit(&"pickup", {"kind": Pickup.Kind.keys()[c.kind].to_lower()})
	state.emit(&"ring", {"pos": c.pos, "radius": 70.0 if c.kind == Pickup.Kind.HEAL else 120.0, "color": _ring_color(c.kind), "life": 0.5})

func _ring_color(kind: Pickup.Kind) -> Color:
	match kind:
		Pickup.Kind.CORE:
			return Color("#ffd24a")
		Pickup.Kind.HEAL:
			return Color("#67e8b1")
		_:
			return Color("#b8a0ff")
