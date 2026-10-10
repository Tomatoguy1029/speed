## W06 追走ドローン：周りを回って近くの敵を撃つ。駆け抜けた線を1機ごとに遅れて追い、触れた敵も攻撃する
## （一覧 docs/game/catalog/weapons.md）。
extends WeaponBehavior

## ドローン：pos、follow_until、serial（追い終えた区間）、hits（敵 → 次に当てられる時刻）
var drones: Array = []
## なぞった区間の記録：a、b、time、serial
var legs: Array = []
var _serial := 0
var _t := 0.0
var _buf := PackedInt32Array()

func count() -> int:
	return 1 + (tier() - 1) / 2

func on_trail(_run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	_serial += 1
	legs.append({"a": p0, "b": p1, "time": state.time, "serial": _serial})
	if legs.size() > 600:
		legs = legs.slice(legs.size() - 600)

func tick(dt: float, busy: bool) -> void:
	var now := state.time
	while drones.size() < count():
		drones.append({"pos": state.ship_pos, "follow_until": 0.0, "serial": _serial, "hits": {}})
	var n := drones.size()
	for i in n:
		var d: Dictionary = drones[i]
		var delay := float(p("delay")) * (i + 1)
		for leg in legs:
			if leg.serial <= d.serial or leg.time + delay > now:
				continue
			d.serial = leg.serial
			d.pos = leg.b
			d.follow_until = leg.time + delay + 0.25
			_hit_along(d, leg.a, leg.b, now)
			if state.phase != RunState.Phase.PLAY:
				return
		if d.follow_until < now:
			var a := now * 1.5 + i * TAU / n
			var target: Vector2 = state.ship_pos + Vector2.from_angle(a) * float(p("orbit"))
			d.pos += (target - d.pos) * 0.25
	legs = legs.filter(func(l): return l.time > now - 2.0)
	if busy:
		return
	_t += dt
	if _t < float(p("interval")) / rate_k():
		return
	_t = 0.0
	for d in drones:
		var target := _nearest(d.pos, float(p("range")))
		if target >= 0:
			build.projectiles.fire_shot(d.pos, (build.enemies.table.pos[target] - d.pos).angle(), atk() * float(p("damage")) * dmg_k(),
				{"color": Color("#a8ffdb"), "r": 4.0})

func _hit_along(d: Dictionary, a: Vector2, b: Vector2, now: float) -> void:
	var radius := 14.0 * cfg.character_scale
	var pad := Vector2.ONE * radius
	build.combat.in_rect(a.min(b) - pad, a.max(b) + pad, _buf)
	var t := build.enemies.table
	for i in _buf:
		if t.dead[i] != 0 or float(d.hits.get(t.id[i], -1.0)) > now:
			continue
		if Geom.seg_circle_t(a, b, t.pos[i], t.r[i] + radius) < 0.0:
			continue
		d.hits[t.id[i]] = now + float(p("contact_cd"))
		build.combat.damage_enemy(i, atk() * dmg_k() * float(p("contact_damage")), {"cause": &"drone"})

## 近くの敵の行番号（いなければ -1）。隕石は狙わない。
func _nearest(from: Vector2, range_r: float) -> int:
	build.combat.nearby(from, range_r, _buf)
	var t := build.enemies.table
	var best := -1
	var bd := range_r * range_r
	for i in _buf:
		var d := t.pos[i].distance_squared_to(from)
		if d < bd and t.meteor_index[i] < 0:
			bd = d
			best = i
	return best
