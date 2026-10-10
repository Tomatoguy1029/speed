## ドロップと回収（仕様書 10）。経験値の結晶・部品・経験値カプセル・漂流カプセル・修理キット・回収ビーコン・出力コア。
class_name PickupManager
extends RunSystem

var field: FieldManager
var ship: ShipManager
var build: BuildManager
var enemies: EnemyManager

## 経験値の結晶と部品は、1つごとの箱を作らず項目ごとの列で持つ。1行が1つで、行は前へ詰めない（設計書 6）。
## 1 なら使用中の行
var gem_alive := PackedByteArray()
var gem_pos := PackedVector2Array()
var gem_value := PackedFloat64Array()
## 吸い寄せが始まったか（1 なら始まった）
var gem_pulled := PackedByteArray()
## 落ちた順の通し番号。上限を超えたとき、いちばん古い結晶を選ぶのに使う
var gem_seq := PackedInt32Array()
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
var _capsule_t := 0.0
var _core_t := 0.0
var _cores_started := false

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
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
	if gem_slots.live > cfg.gem_max:
		# いちばん古い結晶を、新しい結晶にまとめる
		var oldest := _pop_oldest_gem()
		if oldest >= 0:
			v += gem_value[oldest]
			gem_slots.release(oldest)
	_add_gem(p + Vector2.from_angle(state.rng.randf() * TAU) * 8.0, v)

## 結晶を1行加え、その行番号を返す。空いた行を使い回すので、gem_ の全部の列をここで書き直す。
func _add_gem(p: Vector2, v: float) -> int:
	var i := gem_slots.take()
	gem_pos[i] = p
	gem_value[i] = v
	gem_pulled[i] = 0
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
		_add_coin(e.pos + Vector2.from_angle(state.rng.randf() * TAU) * state.rng.randf() * e.r)

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
	# 吸い寄せも回収もされない遠くの結晶は、平方根を使わない距離比較だけで飛ばす
	var far := maxf(radius, reach)
	var far_sq := far * far
	var ship_pos := state.ship_pos
	for i in gem_alive.size():
		if gem_alive[i] == 0:
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
			for i in gem_alive.size():
				if gem_alive[i] != 0:
					xp += gem_value[i]
			_clear_gems()
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
