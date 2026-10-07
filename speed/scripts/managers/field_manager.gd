## フィールド。惑星・周回する月・宇宙塵・外縁・危険度（仕様書 11）。
##
## 惑星と月は障害物で、機体・敵・弾・線を止める。ここでは位置と当たり判定だけを持ち、
## 当たったときの扱い（跳ね返りやダメージ）は、それぞれの Manager が決める。
class_name FieldManager
extends RunSystem

## 障害物1つ（惑星か月）
class Body:
	var pos := Vector2.ZERO
	var r := 0.0
	var is_planet := false
	var orbit := 0.0
	var a0 := 0.0
	var dir := 1.0

var planet: Body
var moons: Array[Body] = []
var bodies: Array[Body] = []
## 宇宙塵の雲（中心と半径）
var dust: Array[Vector3] = []

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
	_update_moons()

func tick(_real_dt: float, _world_dt: float) -> void:
	_update_moons()

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
