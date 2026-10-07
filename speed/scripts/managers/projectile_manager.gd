## 弾と破片（設計書 4.3）。味方の弾・敵の弾・大型の敵の破片（仕様書 6・9.5）。
##
## 物理的な弾と破片は、惑星と月で止まる。波動・範囲攻撃・ビームはここでは扱わない。
class_name ProjectileManager
extends RunSystem

var field: FieldManager
var combat: CombatManager
var ship: ShipManager
var build: BuildManager

var friendly: Array = []
var hostile: Array = []
var _buf: Array = []

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	_update_friendly(world_dt)
	if state.phase != RunState.Phase.PLAY:
		return
	_update_hostile(world_dt)

# ── 味方の弾と破片 ───────────────────────────────────────────────

## 味方の弾を撃つ。opts：speed、r、life、pierce_left、color、cause。
func fire_shot(from: Vector2, angle: float, dmg: float, opts := {}) -> void:
	var s := Shot.new()
	s.kind = &"shot"
	s.cause = opts.get("cause", &"shot")
	var speed: float = opts.get("speed", 1300.0)
	s.pos = from
	s.vel = Vector2.from_angle(angle) * speed
	s.r = opts.get("r", 5.0)
	s.dmg = dmg
	s.life = opts.get("life", 0.9)
	s.max_life = s.life
	s.pierce_left = opts.get("pierce_left", 0)
	s.color = opts.get("color", Color("#ffe46b"))
	friendly.append(s)

## 撃破された大型の敵から、攻撃する破片を飛ばす（仕様書 9.5）。
func scatter_hull(e: Enemy, dir: Vector2, speed: float, dmg: float, knock := -1.0) -> bool:
	if e.r < cfg.hull_debris_min_radius or e.meteor_index >= 0 or e.is_boss or e.hull_scattered:
		return false
	e.hull_scattered = true
	var count := mini(cfg.hull_debris_max_pieces, maxi(6, ceili(e.r / 12.0)))
	var directed := dir.length() > 0.01
	var base := dir.angle() if directed else e.facing
	var spread := deg_to_rad(cfg.hull_debris_spread) if directed else TAU
	for i in count:
		var a := base + ((float(i) / (count - 1) - 0.5) if directed else float(i) / count) * spread
		var u := Vector2.from_angle(a)
		var v := speed * (0.85 + (i % 3) * 0.12)
		var s := Shot.new()
		s.kind = &"debris"
		s.cause = &"hullDebris"
		s.no_crit = true
		s.pos = e.pos + u * e.r * 0.3
		s.vel = u * v
		s.r = clampf(e.r * 0.17, 10.0, 20.0)
		s.dmg = dmg
		s.life = cfg.hull_debris_life
		s.max_life = s.life
		s.pierce = true
		s.hit[e.id] = true
		s.color = e.color
		s.knock = cfg.hull_debris_knock if knock < 0.0 else knock
		s.angle = state.rng.randf() * TAU
		s.spin = 10.0 * (1.0 if i % 2 == 0 else -1.0)
		friendly.append(s)
	state.emit(&"hull_scatter", {"pos": e.pos, "count": count})
	return true

## 敵の死体を1つ飛ばす（吹き飛ばし衝角で小型の敵を倒したとき）。
func fling_corpse(e: Enemy, vel: Vector2, dmg: float) -> void:
	var s := Shot.new()
	s.kind = &"debris"
	s.cause = &"corpse"
	s.pos = e.pos
	s.vel = vel
	s.r = maxf(10.0, e.r * 0.6)
	s.dmg = dmg
	s.life = 0.9
	s.max_life = s.life
	s.pierce = true
	s.hit[e.id] = true
	s.color = e.color
	s.angle = state.rng.randf() * TAU
	s.spin = 10.0
	friendly.append(s)

func _update_friendly(dt: float) -> void:
	var keep: Array = []
	var trail_points := cfg.corpse_trail_points
	for s: Shot in friendly:
		var from := s.pos
		s.pos += s.vel * dt
		s.life -= dt
		s.angle += s.spin * dt
		if s.kind == &"debris":
			s.trail.append(s.pos)
			if s.trail.size() > trail_points:
				s.trail.remove_at(0)
		var body_hit = field.first_body_hit(from, s.pos, s.r)
		var to: Vector2 = s.pos if body_hit == null else body_hit.point
		var pad := Vector2(s.r + cfg.max_enemy_radius, s.r + cfg.max_enemy_radius)
		combat.grid.query(from.min(to) - pad, from.max(to) + pad, _buf)
		var hits: Array = []
		for e: Enemy in _buf:
			if s.hit.has(e.id):
				continue
			var t := Geom.seg_circle_t(from, to, e.pos, s.r + e.r)
			if t >= 0.0:
				hits.append([t, e])
		hits.sort_custom(func(a, b): return a[0] < b[0])
		var sp := s.vel.length()
		for h in hits:
			var e: Enemy = h[1]
			if s.life <= 0.0 or e.dead:
				continue
			s.hit[e.id] = true
			combat.damage_enemy(e, s.dmg, {"cause": s.cause, "no_crit": s.no_crit, "dir": s.vel / sp if sp > 0.0 else Vector2.ZERO, "knock": s.knock})
			if state.phase != RunState.Phase.PLAY:
				return
			if not s.pierce:
				if s.pierce_left > 0:
					s.pierce_left -= 1
				else:
					s.life = 0.0
		if body_hit != null:
			s.pos = body_hit.point
			s.life = 0.0
			state.emit(&"ring", {"pos": s.pos, "radius": 22.0, "color": Color("#ffd19a"), "life": 0.18})
		if s.life > 0.0:
			keep.append(s)
		elif s.kind == &"debris" and s.trail.size() > 1:
			state.emit(&"debris_trail", {"points": s.trail, "color": s.color})
	friendly = keep

# ── 敵の弾 ────────────────────────────────────────────────────────

## 敵の弾を撃つ（射撃型・ミサイル艇・戦艦・ボス）。
func fire_enemy(e: Enemy, angle: float, speed: float, kind: StringName, params := {}) -> void:
	var p: Dictionary = params if not params.is_empty() else e.def.params
	var s := Shot.new()
	s.kind = kind
	s.pos = e.pos + Vector2.from_angle(angle) * e.r
	s.vel = Vector2.from_angle(angle) * speed
	s.speed = speed
	s.r = 9.0 if kind == &"missile" else 7.0
	s.dmg = float(p.get("bullet_dmg", 7.0)) * (1.0 + 0.25 * (e.level - 1.0))
	s.slow = p.get("slow", 0.0)
	s.life = 4.5 if kind == &"missile" else 4.0
	s.max_life = s.life
	s.turn = p.get("missile_turn", 0.0)
	hostile.append(s)
	state.emit(&"shoot", {"pos": e.pos, "kind": kind})

func _update_hostile(dt: float) -> void:
	var keep: Array = []
	var R := cfg.ship_radius
	for s: Shot in hostile:
		if s.life <= 0.0:
			continue
		if s.kind == &"missile":
			var want := (state.enemy_aim - s.pos).angle()
			var cur := s.vel.angle()
			var a := cur + clampf(Geom.angle_diff(want, cur), -s.turn * dt, s.turn * dt)
			s.vel = Vector2.from_angle(a) * s.speed
		var from := s.pos
		s.pos += s.vel * dt
		s.life -= dt
		var body_hit = field.first_body_hit(from, s.pos, s.r)
		var t := Geom.seg_circle_t(from, s.pos, state.ship_pos, s.r + R)
		if t >= 0.0 and (body_hit == null or t < body_hit.t):
			ship.damage(s.dmg, s.slow, s.kind)
			s.life = 0.0
		if body_hit != null:
			s.life = 0.0
		if s.life > 0.0:
			keep.append(s)
	hostile = keep

## 機体の周り radius に入った敵の弾を1つ消す（バリアシステム）。消したら true。
func block_one(center: Vector2, radius: float) -> bool:
	for s: Shot in hostile:
		if s.life > 0.0 and s.pos.distance_to(center) <= radius + s.r:
			s.life = 0.0
			state.emit(&"ring", {"pos": s.pos, "radius": 32.0, "color": Color("#76aaff"), "life": 0.25})
			return true
	return false

## ボスの撃破などで、敵の弾をすべて消す。
func clear_hostile() -> void:
	hostile.clear()
