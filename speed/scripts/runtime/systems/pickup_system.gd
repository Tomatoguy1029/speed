## ドロップと回収（仕様書 10）。経験値の結晶（大きい結晶を含む）・部品・修理キット・回収ビーコン・彗星限定の武器のカプセル。
class_name PickupSystem
extends RunSystem

## 開発版の記録だけが購読する。大きい結晶が落ちたとき。tier は 1〜3（小・中・大）、enemy は落とした敵の種類。
signal big_crystal_dropped(tier: int, xp: float, enemy: StringName)

var field: FieldSystem:
	get: return ctx.field
var ship: ShipSystem:
	get: return ctx.ship
var build: LoadoutSystem:
	get: return ctx.loadout
var enemies: EnemySystem:
	get: return ctx.enemies

## 経験値の結晶と部品は、1つごとの箱を作らず項目ごとの列で持つ。1行が1つで、行は前へ詰めない（設計書 6）。
## 1 なら使用中の行
var gem_alive := PackedByteArray()
var gem_pos := PackedVector2Array()
var gem_value := PackedFloat64Array()
## 吸い寄せが始まったか（1 なら始まった）
var gem_pulled := PackedByteArray()
## 落ちた順の通し番号。上限を超えたとき、いちばん古い結晶を選ぶのに使う
var gem_seq := PackedInt32Array()
## はじけ飛んでいる結晶の速さと、拾えるようになるまでの残り時間（分裂する雑魚の撃破など。ふつうは 0）
var gem_vel := PackedVector2Array()
var gem_wait := PackedFloat32Array()
var gem_slots: RowSlots
## 1 なら使用中の行
var coin_alive := PackedByteArray()
var coin_pos := PackedVector2Array()
var coin_pulled := PackedByteArray()
var coin_slots: RowSlots
var capsules: Array = []
## 結晶の落ちた順の待ち行列（行番号と通し番号）。拾われた結晶は取り出すときに読み飛ばす
var _gem_queue_row := PackedInt32Array()
var _gem_queue_seq := PackedInt32Array()
var _gem_queue_head := 0
var _gem_next_seq := 0

func setup(context: RunContext) -> void:
	super(context)
	gem_slots = RowSlots.new(self, "gem_")
	coin_slots = RowSlots.new(self, "coin_")
	# 追加の関数が、使い回す行の全部の列を書き直すか（デバッグ版だけ）
	assert(Columns.check_add(self, gem_slots.cols, func(): return _add_gem(Vector2.ONE, 1.0), gem_slots.release))
	_clear_gems()
	assert(Columns.check_add(self, coin_slots.cols, func(): return _add_coin(Vector2.ONE), coin_slots.release))
	coin_slots.clear()

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	_collect_gems(world_dt)
	_collect_coins(world_dt)
	_collect_capsules(world_dt)

# ── 落とす ────────────────────────────────────────────────────────

## 敵（行 i）を倒したときのドロップ。
func on_enemy_killed(i: int) -> void:
	var t := enemies.table
	var pos := t.pos[i]
	var phase := enemies.current_phase()
	var bonus := phase.xp_bonus if phase.xp_bonus > 0.0 else 1.0
	# 経験値をまとめて持つ敵（分裂する雑魚）は、gem_count 個の結晶に分けて、その場からはじけ飛ばす
	var value := t.xp[i] * state.stats.xp_mult * bonus
	state.xp_dropped += value
	var gems := int(t.def[i].params.get("gem_count", 1)) if t.def[i] != null else 1
	if gems > 1:
		for k in gems:
			var u := Vector2.from_angle(TAU * k / float(gems) + state.rng.randf() * 0.5)
			fling_gem(pos + u * t.r[i] * 0.3, value / float(gems), u * state.rng.randf_range(240.0, 380.0), 0.35)
		state.emit(&"gem_burst", {"pos": pos, "r": t.r[i]})
	else:
		drop_gem(pos, value)
	if t.carry[i] > 0.0:
		# からす座が運んでいた経験値を、倒した場所へまとめて落とす
		var n := clampi(t.buds[i], 1, 16)
		for k in n:
			drop_gem(pos + Vector2.from_angle(TAU * k / float(n)) * (10.0 + 4.0 * float(k % 3)), t.carry[i] / float(n))
	_drop_coins(i)
	if t.type[i] == &"meteor":
		if state.rng.randf() < cfg.meteor_heal_chance:
			_add_capsule(Pickup.Kind.HEAL, &"drop", pos)
		if state.rng.randf() < cfg.meteor_magnet_chance:
			_add_capsule(Pickup.Kind.MAGNET, &"drop", pos)
		# レアな彗星は、決まった彗星限定の武器のカプセルを必ず落とす
		var weapon := field.comet_weapon(t.meteor_index[i])
		if weapon != &"":
			_add_capsule(Pickup.Kind.COMET_WEAPON, &"comet", pos)
			capsules[capsules.size() - 1].weapon_id = weapon
	# 大きい結晶：レチクル座のように段の決まった敵は必ず、ほかは経験値の多い敵ほど高い確率で落とす
	var tier := int(t.def[i].params.get("big_crystal", 0)) if t.def[i] != null else 0
	if tier == 0 and state.rng.randf() < minf(cfg.drop_max, cfg.drop_base * pow(t.xp[i], cfg.drop_power_exp)):
		tier = _roll_big_crystal_tier()
	if tier > 0:
		var xp := cfg.big_crystal_xp[tier - 1]
		state.xp_dropped += xp
		drop_gem(pos, xp)
		if OS.is_debug_build() and big_crystal_dropped.has_connections():
			big_crystal_dropped.emit(tier, xp, t.type[i])

## 大きい結晶の段（1〜3）。重みはラン開始の値から終わりの値へ、ラン秒でまっすぐ移る。
func _roll_big_crystal_tier() -> int:
	var f := clampf(state.time / cfg.big_crystal_shift_time, 0.0, 1.0)
	var weights := PackedFloat32Array()
	var total := 0.0
	for k in cfg.big_crystal_xp.size():
		var w := lerpf(cfg.big_crystal_weights_start[k], cfg.big_crystal_weights_end[k], f)
		weights.append(w)
		total += w
	var roll := state.rng.randf() * total
	for k in weights.size():
		roll -= weights[k]
		if roll < 0.0:
			return k + 1
	return weights.size()

func drop_gem(p: Vector2, v: float) -> int:
	if gem_slots.live > cfg.gem_max:
		# いちばん古い結晶を、新しい結晶にまとめる
		var oldest := _pop_oldest_gem()
		if oldest >= 0:
			v += gem_value[oldest]
			gem_slots.release(oldest)
	return _add_gem(p + Vector2.from_angle(state.rng.randf() * TAU) * 8.0, v)

## 結晶を p から速さ vel ではじけ飛ばす。wait 世界秒たつまでは拾えず、勢いが落ちながら散らばる。
func fling_gem(p: Vector2, v: float, vel: Vector2, wait: float) -> void:
	var i := drop_gem(p, v)
	gem_vel[i] = vel
	gem_wait[i] = wait

## 結晶を1行加え、その行番号を返す。空いた行を使い回すので、gem_ の全部の列をここで書き直す。
func _add_gem(p: Vector2, v: float) -> int:
	var i := gem_slots.take()
	gem_pos[i] = p
	gem_value[i] = v
	gem_pulled[i] = 0
	gem_vel[i] = Vector2.ZERO
	gem_wait[i] = 0.0
	gem_seq[i] = _gem_next_seq
	_gem_queue_row.append(i)
	_gem_queue_seq.append(_gem_next_seq)
	_gem_next_seq += 1
	return i

## 残っている結晶のうち、いちばん古いものの行番号（無ければ -1）。待ち行列から取り出す。
func _pop_oldest_gem() -> int:
	while _gem_queue_head < _gem_queue_row.size():
		var i := _gem_queue_row[_gem_queue_head]
		var seq := _gem_queue_seq[_gem_queue_head]
		_gem_queue_head += 1
		if gem_alive[i] != 0 and gem_seq[i] == seq:
			_trim_gem_queue()
			return i
	_trim_gem_queue()
	return -1

## 取り出し済みの部分が長くなったら、待ち行列を前へ詰める。
func _trim_gem_queue() -> void:
	if _gem_queue_head < 1024 or _gem_queue_head * 2 < _gem_queue_row.size():
		return
	_gem_queue_row = _gem_queue_row.slice(_gem_queue_head)
	_gem_queue_seq = _gem_queue_seq.slice(_gem_queue_head)
	_gem_queue_head = 0

func _clear_gems() -> void:
	gem_slots.clear()
	_gem_queue_row.clear()
	_gem_queue_seq.clear()
	_gem_queue_head = 0

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
	elif t.type[i] == &"meteor":
		n = (1 + state.rng.randi_range(0, 2)) if state.rng.randf() < cfg.meteor_coin_chance else 0
	elif state.rng.randf() < 0.03:
		n = 1
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
	var radius := state.stats.pickup_radius
	var step := (700.0 + state.ship_vel.length() * 1.2) * dt
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
			build.add_xp(gem_value[i])
			state.emit(&"pickup", {"kind": &"gem"})
			gem_slots.release(i)

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
			state.coins += 1
			state.emit(&"pickup", {"kind": &"coin"})
			coin_slots.release(i)

func _collect_capsules(dt: float) -> void:
	var reach := 22.0 + cfg.ship_radius + 14.0
	var pull_r := state.stats.pickup_radius * 1.6
	for c: Pickup in capsules:
		if c.taken:
			continue
		c.age += dt
		var can := c.kind != Pickup.Kind.HEAL or state.ship_hp < state.stats.max_hp
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

func _apply(c: Pickup) -> void:
	match c.kind:
		Pickup.Kind.COMET_WEAPON:
			state.pending_comet_weapons.append(c.weapon_id)
		Pickup.Kind.HEAL:
			var before := state.ship_hp
			ship.heal(state.stats.max_hp * cfg.meteor_heal_frac)
			state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -40), "text": "HP +%d" % roundi(state.ship_hp - before), "color": Color("#67e8b1"), "size": 18})
		Pickup.Kind.MAGNET:
			var xp := 0.0
			for i in gem_alive.size():
				if gem_alive[i] != 0:
					xp += gem_value[i]
			_clear_gems()
			build.add_xp(xp)
			state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -45), "text": "XP +%d" % roundi(xp), "color": Color("#b8a0ff"), "size": 22})
	state.emit(&"pickup", {"kind": Pickup.Kind.keys()[c.kind].to_lower()})
	state.emit(&"ring", {"pos": c.pos, "radius": 70.0 if c.kind == Pickup.Kind.HEAL else 120.0, "color": _ring_color(c.kind), "life": 0.5})

func _ring_color(kind: Pickup.Kind) -> Color:
	match kind:
		Pickup.Kind.COMET_WEAPON:
			return Color("#ffd24a")
		Pickup.Kind.HEAL:
			return Color("#67e8b1")
		_:
			return Color("#b8a0ff")
