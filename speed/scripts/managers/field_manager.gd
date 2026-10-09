## フィールド。惑星・周回する月・宇宙塵・外縁・危険度（仕様書 13.1）。
##
## 惑星と月は障害物で、機体・敵・弾・線を止める。ここでは位置と当たり判定だけを持ち、
## 当たったときの扱い（跳ね返りやダメージ）は、それぞれの Manager が決める。
class_name FieldManager
extends RunSystem

## 隕石1つの配置（仕様書 13.1）。kind は belt（地帯の岩、固定）、drift（漂流）、comet（彗星）
class Rock:
	var kind: StringName
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var size := 40.0
	var facing := 0.0
	var spin := 0.0
	var angle := 0.0
	var offset := 0.0
	var period := 0.0
	var phase := 0.0
	var destroyed := false
	var entity: Enemy = null

## 障害物1つ（惑星か月）
class Body:
	var pos := Vector2.ZERO
	var r := 0.0
	var is_planet := false
	var orbit := 0.0
	var a0 := 0.0
	var dir := 1.0

var enemies: EnemyManager

var planet: Body
var moons: Array[Body] = []
var bodies: Array[Body] = []
## 宇宙塵の雲（中心と半径）
var dust: Array[Vector3] = []
var rocks: Array[Rock] = []
var _stream_t := 0.0

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
	var rng := state.rng
	planet = Body.new()
	planet.r = cfg.planet_radius
	planet.is_planet = true
	bodies.append(planet)
	for i in cfg.moon_count:
		var m := Body.new()
		m.orbit = rng.randf_range(1500.0, cfg.field_radius - 600.0)
		m.a0 = float(i) / cfg.moon_count * TAU + rng.randf_range(-0.3, 0.3)
		m.dir = -1.0 if rng.randf() < 0.5 else 1.0
		m.r = rng.randf_range(110.0, 180.0)
		moons.append(m)
		bodies.append(m)
	for i in cfg.dust_count:
		var a := rng.randf() * TAU
		var d := rng.randf_range(cfg.planet_radius + 600.0, cfg.field_radius - 200.0)
		dust.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(250.0, 620.0)))
	_place_rocks(rng)
	_update_moons()

func tick(_real_dt: float, world_dt: float) -> void:
	_update_moons()
	if world_dt > 0.0:
		_stream_rocks(world_dt)

# ── 隕石（仕様書 13.1） ─────────────────────────────────────────────

## ラン開始時に、世界の決まった位置へ隕石を置く：地帯・漂流・彗星。
func _place_rocks(rng: RandomNumberGenerator) -> void:
	var n := cfg.meteor_count
	for i in roundi(n * 0.45):
		var center := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1100.0, cfg.field_radius - 650.0)
		for j in 8:
			_add_rock(rng, center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 380.0, &"belt", Vector2.ZERO)
	for i in roundi(n * 2.5):
		var d := sqrt(rng.randf_range(800.0 * 800.0, pow(cfg.field_radius - 300.0, 2.0)))
		var heading := rng.randf() * TAU
		_add_rock(rng, Vector2.from_angle(rng.randf() * TAU) * d, &"drift", Vector2.from_angle(heading) * rng.randf_range(15.0, 35.0))
	if n > 0:
		for i in 3:
			var r := Rock.new()
			r.kind = &"comet"
			r.angle = rng.randf() * TAU
			r.offset = rng.randf_range(1200.0, 4500.0) * (-1.0 if rng.randf() < 0.5 else 1.0)
			r.period = rng.randf_range(42.0, 65.0)
			r.phase = rng.randf() * 40.0
			r.size = rng.randf_range(35.0, 55.0)
			r.facing = r.angle
			r.spin = 0.4
			rocks.append(r)

func _add_rock(rng: RandomNumberGenerator, p: Vector2, kind: StringName, vel: Vector2) -> void:
	var r := p.length()
	if r < cfg.planet_radius + 200.0 or r > cfg.field_radius - 100.0:
		return
	var rock := Rock.new()
	rock.kind = kind
	rock.pos = p
	rock.vel = vel
	rock.size = rng.randf_range(24.0, 65.0)
	rock.facing = rng.randf() * TAU
	rock.spin = rng.randf_range(-0.5, 0.5)
	rocks.append(rock)

## 時刻 t の隕石の位置と速度。
func _rock_at(rock: Rock, t: float) -> Array:
	if rock.kind == &"comet":
		var along := fmod(t + rock.phase, rock.period) * 950.0 - cfg.field_radius - 500.0
		var u := Vector2.from_angle(rock.angle)
		return [u * along + Vector2(-u.y, u.x) * rock.offset, u * 950.0]
	var diameter := cfg.field_radius * 2.0
	var p := rock.pos + rock.vel * t
	p = Vector2(fposmod(p.x + cfg.field_radius, diameter) - cfg.field_radius, fposmod(p.y + cfg.field_radius, diameter) - cfg.field_radius)
	return [p, rock.vel]

func _near(p: Vector2, extra: float) -> bool:
	var d := (p - state.view_center).abs()
	var r := p.length()
	return d.x < state.view_half.x + extra and d.y < state.view_half.y + extra \
		and r > cfg.planet_radius + 100.0 and r < cfg.field_radius + 100.0

## 画面の近くの隕石だけを敵の配列に入れる。壊した隕石はそのランの間は戻らない。
func _stream_rocks(dt: float) -> void:
	var t := state.time
	for rock in rocks:
		var e := rock.entity
		if e == null:
			continue
		if e.dead:
			if not e.hull_scattered:
				rock.destroyed = true
			rock.entity = null
			continue
		var pv := _rock_at(rock, t)
		e.pos = pv[0]
		e.vel = pv[1]
		e.facing = rock.facing + rock.spin * t
		if not _near(e.pos, 650.0):
			e.dead = true
			enemies.dirty = true
			rock.entity = null
	_stream_t -= dt
	if _stream_t > 0.0:
		return
	_stream_t = 0.2
	var def: EnemyDef = ConfigManager.enemies.get(&"meteor")
	for i in rocks.size():
		var rock := rocks[i]
		if rock.destroyed or rock.entity != null:
			continue
		var pv := _rock_at(rock, t)
		if not _near(pv[0], 300.0):
			continue
		var sprite_radius := 60.0 if i % 2 == 0 else 40.0
		var e := enemies.create(def, 1.0, pv[0], {"size": sprite_radius, "facing": rock.facing, "spin": rock.spin})
		e.meteor_index = i
		e.vel = pv[1]
		rock.entity = e
		enemies.add(e)

func _update_moons() -> void:
	for m in moons:
		var a := m.a0 + m.dir * cfg.moon_orbit_speed * state.world_time
		m.pos = Vector2(cos(a), sin(a)) * m.orbit

## 中心からの距離 r の危険度（0〜1）。中間の環で 0、惑星の表面と外縁に向かって 1。
func danger_at(r: float) -> float:
	if r < cfg.zone_inner:
		return clampf((cfg.zone_inner - r) / (cfg.zone_inner - cfg.planet_radius), 0.0, 1.0)
	if r > cfg.zone_outer:
		return clampf((r - cfg.zone_outer) / (cfg.field_radius - cfg.zone_outer), 0.0, 1.0)
	return 0.0

func dust_drag_at(p: Vector2) -> float:
	for d in dust:
		if p.distance_squared_to(Vector2(d.x, d.y)) < d.z * d.z:
			return cfg.dust_drag
	return 0.0

## 外縁の外へ出ようとするときの押し戻しの加速度。
func boundary_accel(p: Vector2) -> Vector2:
	var r := p.length()
	if r <= cfg.field_radius:
		return Vector2.ZERO
	return -p / r * (cfg.boundary_push + (r - cfg.field_radius) * 4.0)

## 線分 p0→p1（太さ radius）が最初に当たる障害物。当たらなければ null。
## 戻り値は { body, t, point }。
func first_body_hit(p0: Vector2, p1: Vector2, radius := 0.0) -> Variant:
	var found = null
	var earliest := INF
	for b in bodies:
		var rr := b.r + radius
		if maxf(p0.x, p1.x) < b.pos.x - rr or minf(p0.x, p1.x) > b.pos.x + rr \
				or maxf(p0.y, p1.y) < b.pos.y - rr or minf(p0.y, p1.y) > b.pos.y + rr:
			continue
		var t := Geom.seg_circle_t(p0, p1, b.pos, rr)
		if t >= 0.0 and t < earliest:
			earliest = t
			found = {"body": b, "t": t, "point": p0.lerp(p1, t)}
	return found

## 点 p を障害物の外へ押し出した位置（線の描き始めなどに使う）。
func push_out(p: Vector2, margin: float) -> Vector2:
	var q := p
	for b in bodies:
		var d := q - b.pos
		var dist := d.length()
		var min_d := b.r + margin
		if dist < min_d:
			q = b.pos + (d / dist if dist > 0.001 else Vector2.RIGHT) * min_d
	return q

## 点 p（余白 margin）の近くに障害物があるか。敵の当たり判定を省くための速い判定。
func near_body(p: Vector2, margin: float) -> bool:
	var r := p.length()
	if r < planet.r + margin + 4.0:
		return true
	for m in moons:
		if absf(r - m.orbit) < m.r + margin + 4.0 and p.distance_squared_to(m.pos) < pow(m.r + margin + 4.0, 2.0):
			return true
	return false

## 敵が障害物をすり抜けないよう、表面で止めて横方向の速度だけ残す。
func collide_enemy(e: Enemy, from: Vector2) -> void:
	var hit = first_body_hit(from, e.pos, e.r)
	if hit == null:
		return
	var b: Body = hit.body
	var n: Vector2 = hit.point - b.pos
	if n.length_squared() < 1e-6:
		n = from - b.pos
	n = n.normalized() if n.length_squared() > 0.0 else Vector2.RIGHT
	e.pos = b.pos + n * (b.r + e.r + 0.01)
	var vn := e.vel.dot(n)
	if vn < 0.0:
		e.vel -= n * vn
	if e.shove_time > 0.0:
		e.shove_vel = e.vel
