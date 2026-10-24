## フィールド。惑星・周回する月・外縁・危険度（仕様書 13.1）。
##
## 惑星と月は障害物で、機体・敵・弾・線を止める。ここでは位置と当たり判定だけを持ち、
## 当たったときの扱い（跳ね返りやダメージ）は、それぞれの Manager が決める。
class_name FieldSystem
extends RunSystem

## 隕石1つの配置（仕様書 13.1）。kind は belt（地帯の岩、固定）、drift（漂流）、comet（彗星）、
## iron（鉄のがれき、固定）、saw（回る丸鋸、固定）。鉄のがれきと丸鋸も、隕石と同じしくみで敵の表に入る
class Rock:
	var kind: StringName
	## 実験場で手動配置した岩は、閲覧カメラから離れても表に残す。
	var lab_manual := false
	## 漂流は世界時刻0の位置、彗星は現れた時刻の位置
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var size := 40.0
	var facing := 0.0
	var spin := 0.0
	## 彗星：現れた世界時刻と、消える世界時刻
	var born := 0.0
	var gone := 0.0
	## レアな彗星が落とす、彗星限定の武器の管理 ID（レアでなければ空）
	var rare_weapon: StringName = &""
	var destroyed := false
	## 敵の表で使っている行と、その敵の id（画面の近くにいない間は -1）
	var row := -1
	var row_id := 0

## 重力1つ（仕様書 13.1）。現れてから life 世界秒で縮んで消える
class Well:
	var pos := Vector2.ZERO
	var born := 0.0
	var life := 3.0
	## 現れたときの届く半径と、中心の引き寄せる加速
	var radius := 0.0
	var pull := 0.0

## 障害物1つ（惑星か月）
class Body:
	var pos := Vector2.ZERO
	var r := 0.0
	var is_planet := false
	var orbit := 0.0
	var a0 := 0.0
	var dir := 1.0

var enemies: EnemySystem:
	get: return ctx.enemies
var projectiles: ProjectileSystem:
	get: return ctx.projectiles

var planet: Body
var moons: Array[Body] = []
var bodies: Array[Body] = []
## 月の軌道半径・大きさはラン中固定。半径帯ごとに確認候補を保持する。
const MOON_BAND_SIZE := 256.0
var _moon_bands: Array[Array] = []
const BODY_CELL_SIZE := 512.0
var _body_cells: Array[Array] = []
var _body_used: Array[int] = []
var _body_origin := Vector2.ZERO
var _body_width := 0
## 天体が動く速さの上限（月の公転）。弾の天体判定を省ける時間の見積もりに使う
var body_speed_max := 0.0
var rocks: Array[Rock] = []
## 次の彗星までの世界秒
var wells: Array[Well] = []
## ボス所有の固定外周。所有者の解放時に、その外周だけを取り除く。
var battle_arenas: Dictionary = {}
## ワープホールの位置と消える世界時刻（無ければ warp_gone が負）
var warp_pos := Vector2.ZERO
var warp_gone := -1.0

func setup(context: RunContext) -> void:
	super(context)
	planet = Body.new()
	planet.r = cfg.planet_radius
	planet.is_planet = true
	bodies.append(planet)
	_body_origin = Vector2.ONE * (-cfg.field_radius - BODY_CELL_SIZE)
	_body_width = ceili((cfg.field_radius * 2.0 + BODY_CELL_SIZE * 2.0) / BODY_CELL_SIZE)
	_body_cells.clear()
	_body_cells.resize(_body_width * _body_width)
	for i in _body_cells.size():
		_body_cells[i] = []
	_body_used.clear()
	for old in _gimmicks.values():
		old.dispose()
	_gimmicks.clear()
	for id in [&"moons", &"comets", &"meteors", &"warp", &"gravity"]:
		var part: FieldGimmick = load("res://scripts/gimmicks/%s.gd" % id).new()
		part.setup(ctx)
		_gimmicks[id] = part
	for id in [&"moons", &"meteors", &"comets", &"warp", &"gravity"]:
		_gimmicks[id].initialize()
	refresh_bodies()

var _gimmicks: Dictionary = {}

func gimmick(id: StringName) -> FieldGimmick:
	return _gimmicks.get(id)

func tick(real_dt: float, world_dt: float) -> void:
	for part in _gimmicks.values():
		part.tick(real_dt, world_dt)

func dispose() -> void:
	for part in _gimmicks.values():
		part.dispose()
	_gimmicks.clear()
	super()

func refresh_bodies() -> void:
	gimmick(&"moons").update()

func rock_at(rock: Rock, time: float) -> Array:
	return gimmick(&"meteors")._rock_at(rock, time)

func spawn_well() -> void:
	gimmick(&"gravity").spawn_well()

func add_well(pos: Vector2, life: float, radius: float, pull: float) -> void:
	gimmick(&"gravity").add_well(pos, life, radius, pull)

func spawn_comet(rare: bool) -> void:
	gimmick(&"comets").spawn_comet(rare)

func comet_at(index: int) -> Rock:
	return gimmick(&"comets").comet_at(index)

func rare_comet_positions() -> PackedVector2Array:
	return gimmick(&"comets").rare_comet_positions()

func comet_weapon(index: int) -> StringName:
	return gimmick(&"comets").comet_weapon(index)

func spawn_warp() -> void:
	gimmick(&"warp").spawn_warp()

func take_warp() -> bool:
	return gimmick(&"warp").take_warp()

func _update_body_grid() -> void:
	# 少数の天体を格子へ登録し、各弾が全天体を調べることを避ける。
	for cell in _body_used:
		_body_cells[cell].clear()
	_body_used.clear()
	for b in bodies:
		var lo := Vector2i(((b.pos - Vector2.ONE * b.r - _body_origin) / BODY_CELL_SIZE).floor())
		var hi := Vector2i(((b.pos + Vector2.ONE * b.r - _body_origin) / BODY_CELL_SIZE).floor())
		for y in range(maxi(0, lo.y), mini(_body_width - 1, hi.y) + 1):
			for x in range(maxi(0, lo.x), mini(_body_width - 1, hi.x) + 1):
				var cell := y * _body_width + x
				if _body_cells[cell].is_empty():
					_body_used.append(cell)
				_body_cells[cell].append(b)

func boundary_accel(p: Vector2) -> Vector2:
	if not battle_arenas.is_empty(): return Vector2.ZERO
	var r := p.length()
	if r <= cfg.field_radius:
		return Vector2.ZERO
	return -p / r * (cfg.boundary_push + (r - cfg.field_radius) * 4.0)

func first_body_hit(p0: Vector2, p1: Vector2, radius := 0.0) -> Variant:
	var found: Body = null
	var earliest := INF
	var lo := Vector2i(((p0.min(p1) - Vector2.ONE * radius - _body_origin) / BODY_CELL_SIZE).floor())
	var hi := Vector2i(((p0.max(p1) + Vector2.ONE * radius - _body_origin) / BODY_CELL_SIZE).floor())
	# 長い描画経路は全7天体の走査の方が安い。弾の短い線分は格子で候補を絞る。
	if lo.x < 0 or lo.y < 0 or hi.x >= _body_width or hi.y >= _body_width \
			or (hi.x - lo.x + 1) * (hi.y - lo.y + 1) > 4:
		for b in bodies:
			var t := Geom.seg_circle_t(p0, p1, b.pos, b.r + radius)
			if t >= 0.0 and t < earliest:
				earliest = t
				found = b
	else:
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				for b: Body in _body_cells[y * _body_width + x]:
					var t := Geom.seg_circle_t(p0, p1, b.pos, b.r + radius)
					if t >= 0.0 and t < earliest:
						earliest = t
						found = b
	var arena := arena_hit(p0, p1, radius)
	if not arena.is_empty() and arena.t < earliest:
		return arena
	return null if found == null else {"body": found, "t": earliest, "point": p0.lerp(p1, earliest)}

func arena_hit(from: Vector2, to: Vector2, radius: float) -> Dictionary:
	var result: Dictionary = {}
	for bounds: Rect2 in battle_arenas.values():
		var safe := bounds.grow(-radius)
		var start := from.clamp(safe.position, safe.end)
		if start != from:
			# 外側に残った敵・弾を、囲いの内側へ転送しない。
			return {"body":null,"t":0.0,"point":from,"pos":from,"normal":(from-start).normalized()}
		var delta := to-from
		for axis in 2:
			if is_zero_approx(delta[axis]): continue
			var edge: float = safe.end[axis] if delta[axis]>0.0 else safe.position[axis]
			var fraction: float = (edge-from[axis])/delta[axis]
			if fraction < 0.0 or fraction > 1.0: continue
			if not result.is_empty() and fraction >= float(result.t): continue
			var normal := Vector2.ZERO
			normal[axis] = -signf(delta[axis])
			var point := from.lerp(to,fraction)
			result = {"body":null,"t":fraction,"point":point,"pos":point+normal*0.01,"normal":normal}
	return result

func body_gap(p: Vector2, radius: float) -> float:
	var gap := INF
	for bounds: Rect2 in battle_arenas.values():
		gap = minf(gap,minf(minf(p.x-bounds.position.x,bounds.end.x-p.x),minf(p.y-bounds.position.y,bounds.end.y-p.y))-radius)
	for b in bodies:
		gap = minf(gap, p.distance_to(b.pos) - b.r - radius)
	return gap

func push_out(p: Vector2, margin: float) -> Vector2:
	var q := p
	for bounds: Rect2 in battle_arenas.values():
		var safe := bounds.grow(-margin)
		q = q.clamp(safe.position,safe.end)
	for b in bodies:
		var d := q - b.pos
		var dist := d.length()
		var min_d := b.r + margin
		if dist < min_d:
			q = b.pos + (d / dist if dist > 0.001 else Vector2.RIGHT) * min_d
	return q

func _build_moon_bands() -> void:
	_moon_bands.clear()
	var outer := 0.0
	for moon in moons:
		outer = maxf(outer, moon.orbit + moon.r + 4.0)
	_moon_bands.resize(int(outer / MOON_BAND_SIZE) + 1)
	for i in _moon_bands.size():
		_moon_bands[i] = []
	for moon in moons:
		var first := maxi(0, int((moon.orbit - moon.r - 4.0) / MOON_BAND_SIZE))
		var last := int((moon.orbit + moon.r + 4.0) / MOON_BAND_SIZE)
		for i in range(first, last + 1):
			_moon_bands[i].append(moon)

func near_body(p: Vector2, margin: float) -> bool:
	var r := p.length()
	if r < planet.r + margin + 4.0:
		return true
	var first := maxi(0, int((r - margin) / MOON_BAND_SIZE))
	var last := mini(_moon_bands.size() - 1, int((r + margin) / MOON_BAND_SIZE))
	for i in range(first, last + 1):
		for moon: Body in _moon_bands[i]:
			var limit := moon.r + margin + 4.0
			if absf(r - moon.orbit) < limit and p.distance_squared_to(moon.pos) < limit * limit:
				return true
	return false

func collide_enemy(i: int, from: Vector2) -> void:
	var table := enemies.table
	var r := table.r[i]
	var hit = first_body_hit(from, table.pos[i], r)
	if hit == null:
		return
	var n: Vector2
	if hit.has("normal"):
		n = hit.normal
		table.pos[i] = hit.pos
	else:
		var b: Body = hit.body
		n = hit.point - b.pos
		if n.length_squared() < 1e-6:
			n = from - b.pos
		n = n.normalized() if n.length_squared() > 0.0 else Vector2.RIGHT
		table.pos[i] = b.pos + n * (b.r + r + 0.01)
	var v := table.vel[i]
	var vn := v.dot(n)
	if vn < 0.0:
		v -= n * vn
		table.vel[i] = v
	if table.shove_time[i] > 0.0:
		table.shove_vel[i] = v
