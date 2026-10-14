## フィールド。惑星・周回する月・宇宙塵・外縁・危険度（仕様書 13.1）。
##
## 惑星と月は障害物で、機体・敵・弾・線を止める。ここでは位置と当たり判定だけを持ち、
## 当たったときの扱い（跳ね返りやダメージ）は、それぞれの Manager が決める。
class_name FieldManager
extends RunSystem

## 隕石1つの配置（仕様書 13.1）。kind は belt（地帯の岩、固定）、drift（漂流）、comet（彗星）、
## iron（鉄のがれき、固定）、saw（回る丸鋸、固定）。鉄のがれきと丸鋸も、隕石と同じしくみで敵の表に入る
class Rock:
	var kind: StringName
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

var enemies: EnemyManager
var projectiles: ProjectileManager

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
## 宇宙塵の雲（中心と半径）
var dust: Array[Vector3] = []
var rocks: Array[Rock] = []
var _stream_t := 0.0
## 次の彗星までの世界秒
var _comet_t := 0.0
var wells: Array[Well] = []
## ワープホールの位置と消える世界時刻（無ければ warp_gone が負）
var warp_pos := Vector2.ZERO
var warp_gone := -1.0
var _well_t := 0.0

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
	_build_moon_bands()
	body_speed_max = 0.0
	for m in moons:
		body_speed_max = maxf(body_speed_max, absf(cfg.moon_orbit_speed) * m.orbit)
	_body_origin = Vector2.ONE * (-cfg.field_radius - BODY_CELL_SIZE)
	_body_width = ceili((cfg.field_radius * 2.0 + BODY_CELL_SIZE * 2.0) / BODY_CELL_SIZE)
	_body_cells.clear()
	_body_cells.resize(_body_width * _body_width)
	for i in _body_cells.size():
		_body_cells[i] = []
	_body_used.clear()
	_place_rocks(rng)
	_update_moons()
	wells.clear()
	warp_gone = -1.0
	_well_t = rng.randf_range(cfg.gravity_interval_min, cfg.gravity_interval_max)

func tick(_real_dt: float, world_dt: float) -> void:
	_update_moons()
	if world_dt > 0.0:
		_tick_comets(world_dt)
		_stream_rocks(world_dt)
		_tick_wells(world_dt)

# ── 隕石（仕様書 13.1） ─────────────────────────────────────────────

## ラン開始時に、世界の決まった位置へ隕石を置く：地帯・漂流。彗星はラン中に現れる（_tick_comets）。
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
	# 鉄のがれきと回る丸鋸（置き方は仮：フィールドの全体に散らす）
	for i in cfg.iron_count:
		var center := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1100.0, cfg.field_radius - 650.0)
		for j in rng.randi_range(3, 5):
			_add_rock(rng, center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 240.0, &"iron", Vector2.ZERO)
	for i in cfg.saw_count:
		var d := sqrt(rng.randf_range(900.0 * 900.0, pow(cfg.field_radius - 400.0, 2.0)))
		_add_rock(rng, Vector2.from_angle(rng.randf() * TAU) * d, &"saw", Vector2.ZERO)
	_comet_t = rng.randf_range(cfg.comet_interval_min, cfg.comet_interval_max)

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
	if kind == &"iron":
		rock.size = rng.randf_range(30.0, 50.0)
	elif kind == &"saw":
		rock.size = 30.0
		rock.spin = 8.0
	rocks.append(rock)

## 世界時刻 t の隕石の位置と速度。
func _rock_at(rock: Rock, t: float) -> Array:
	if rock.kind == &"comet":
		return [rock.pos + rock.vel * (t - rock.born), rock.vel]
	var diameter := cfg.field_radius * 2.0
	var p := rock.pos + rock.vel * t
	p = Vector2(fposmod(p.x + cfg.field_radius, diameter) - cfg.field_radius, fposmod(p.y + cfg.field_radius, diameter) - cfg.field_radius)
	return [p, rock.vel]

func _near(p: Vector2, extra: float) -> bool:
	var d := (p - state.view_center).abs()
	var r := p.length()
	return d.x < state.view_half.x + extra and d.y < state.view_half.y + extra \
		and r > cfg.planet_radius + 100.0 and r < cfg.field_radius + 100.0

## 画面の近くの隕石だけを敵の表に入れる。壊した隕石はそのランの間は戻らない。
func _stream_rocks(dt: float) -> void:
	var t := state.world_time
	var table := enemies.table
	for rock in rocks:
		var i := rock.row
		if i < 0:
			continue
		# 撃破されて空きに戻った行は、別の敵に使い回されていることがある
		if not enemies.is_same(i, rock.row_id) or table.dead[i] != 0:
			if not enemies.is_same(i, rock.row_id) or table.hull_scattered[i] == 0:
				rock.destroyed = true
			rock.row = -1
			continue
		var pv := _rock_at(rock, t)
		table.pos[i] = pv[0]
		table.vel[i] = pv[1]
		table.facing[i] = rock.facing + rock.spin * t
		if rock.kind == &"comet" and t >= rock.gone:
			rock.destroyed = true
		if rock.destroyed or not _near(pv[0], 650.0):
			enemies.mark_dead(i)
			rock.row = -1
	_stream_t -= dt
	if _stream_t > 0.0:
		return
	_stream_t = 0.2
	var defs := {&"iron": ConfigManager.enemies.get(&"iron"), &"saw": ConfigManager.enemies.get(&"saw")}
	var meteor: EnemyDef = ConfigManager.enemies.get(&"meteor")
	for k in rocks.size():
		var rock := rocks[k]
		if rock.destroyed or rock.row >= 0:
			continue
		if rock.kind == &"comet" and t >= rock.gone:
			rock.destroyed = true
			continue
		var pv := _rock_at(rock, t)
		if not _near(pv[0], 300.0):
			continue
		var def: EnemyDef = defs.get(rock.kind, meteor)
		var sprite_radius := rock.size if def != meteor or rock.kind == &"comet" else (60.0 if k % 2 == 0 else 40.0)
		var i := enemies.spawn(def, 1.0, pv[0], {"size": sprite_radius, "facing": rock.facing, "spin": rock.spin,
			"meteor_index": k, "vel": pv[1]})
		rock.row = i
		rock.row_id = table.id[i]

# ── 重力（仕様書 13.1） ─────────────────────────────────────────────

## 重力を出し、敵・敵の弾・遅い機体を引き寄せる。高速の機体には効かない。
func _tick_wells(dt: float) -> void:
	_well_t -= dt
	if _well_t <= 0.0:
		_well_t = state.rng.randf_range(cfg.gravity_interval_min, cfg.gravity_interval_max)
		spawn_well()
	var now := state.world_time
	for k in range(wells.size() - 1, -1, -1):
		if now - wells[k].born >= wells[k].life:
			wells.remove_at(k)
	if wells.is_empty():
		return
	var fast := state.tracing or state.glide or state.ship_vel.length() >= state.stats.max_speed * cfg.ram_speed_ratio
	var t := enemies.table
	for w in wells:
		var k := 1.0 - (now - w.born) / w.life
		var reach := w.radius * k
		var pull := w.pull * k * dt
		if not fast:
			state.ship_vel += _well_pull(w.pos, state.ship_pos, reach, pull)
		for i in t.alive.size():
			if t.alive[i] != 0 and t.dead[i] == 0 and t.is_boss[i] == 0 and t.meteor_index[i] < 0 and t.parent[i] < 0:
				t.vel[i] += _well_pull(w.pos, t.pos[i], reach, pull)
		var hostile_alive := projectiles.hostile_alive
		for i in hostile_alive.size():
			if hostile_alive[i] != 0:
				projectiles.hostile_vel[i] += _well_pull(w.pos, projectiles.hostile_pos[i], reach, pull)

## 重力の中心 center が、位置 p のものに与える速度の変化（届かなければ 0）。
func _well_pull(center: Vector2, p: Vector2, reach: float, pull: float) -> Vector2:
	var d := center - p
	var dist := d.length()
	if dist >= reach or dist < 1.0:
		return Vector2.ZERO
	return d / dist * pull * (1.0 - dist / reach)

## 画面の中の、機体から少し離れた位置に重力を1つ出す。
func spawn_well() -> void:
	var w := Well.new()
	for attempt in 8:
		var p := state.view_center + Vector2(state.rng.randf_range(-0.7, 0.7) * state.view_half.x,
			state.rng.randf_range(-0.7, 0.7) * state.view_half.y)
		w.pos = p
		if p.distance_to(state.ship_pos) > 300.0 and body_gap(p, 0.0) > 100.0:
			break
	w.born = state.world_time
	w.life = cfg.gravity_life
	w.radius = cfg.gravity_radius
	w.pull = cfg.gravity_pull
	wells.append(w)

## 位置 pos に、引き寄せる領域を1つ置く（うみへび座の渦の首の渦など）。重力と同じく、縮んで消える。
func add_well(pos: Vector2, life: float, radius: float, pull: float) -> void:
	var w := Well.new()
	w.pos = pos
	w.born = state.world_time
	w.life = life
	w.radius = radius
	w.pull = pull
	wells.append(w)

# ── 彗星（仕様書 13.1） ─────────────────────────────────────────────

func _tick_comets(dt: float) -> void:
	_comet_t -= dt
	if _comet_t > 0.0:
		return
	_comet_t = state.rng.randf_range(cfg.comet_interval_min, cfg.comet_interval_max)
	if state.bonus_t <= 0.0 and not state.boss_spawned and warp_gone < 0.0 and state.time >= cfg.rare_comet_after \
			and state.rng.randf() < cfg.warp_chance:
		spawn_warp()
		return
	spawn_comet(state.time >= cfg.rare_comet_after and state.rng.randf() < cfg.rare_comet_chance)

# ── ワープホール（仕様書 13.1） ───────────────────────────────────────

## 画面の端の近くにワープホールを出す。
func spawn_warp() -> void:
	for attempt in 8:
		var u := Vector2.from_angle(state.rng.randf() * TAU)
		var edge := minf(state.view_half.x / maxf(absf(u.x), 0.001), state.view_half.y / maxf(absf(u.y), 0.001))
		warp_pos = state.view_center + u * edge * 0.8
		if body_gap(warp_pos, cfg.warp_radius) > 50.0 and warp_pos.length() < cfg.field_radius - 200.0:
			break
	warp_gone = state.world_time + cfg.warp_life

## 機体がワープホールに触れたか。触れたらワープホールは消える。
func take_warp() -> bool:
	if warp_gone < 0.0:
		return false
	if state.world_time >= warp_gone:
		warp_gone = -1.0
		return false
	var reach := cfg.warp_radius + cfg.ship_radius
	if state.ship_pos.distance_squared_to(warp_pos) > reach * reach:
		return false
	warp_gone = -1.0
	return true

## 画面の端の近くを横切る彗星を1つ出す。惑星を通らない向きを選ぶ。
func spawn_comet(rare: bool) -> void:
	var rng := state.rng
	var vc := state.view_center
	var vh := state.view_half
	var lead := vh.length() + 700.0
	for attempt in 12:
		var u := Vector2.from_angle(rng.randf() * TAU)
		var side := Vector2(-u.y, u.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var edge := absf(side.x) * vh.x + absf(side.y) * vh.y
		var start := vc - u * lead + side * edge * rng.randf_range(0.55, 0.9)
		var end := start + u * lead * 2.0
		if Geom.seg_circle_t(start, end, Vector2.ZERO, cfg.planet_radius + 150.0) >= 0.0 and attempt < 11:
			continue
		var r := Rock.new()
		r.kind = &"comet"
		r.pos = start
		r.vel = u * cfg.comet_speed
		r.born = state.world_time
		r.gone = state.world_time + lead * 2.0 / cfg.comet_speed
		r.size = rng.randf_range(35.0, 55.0)
		r.facing = u.angle()
		if rare:
			# まだ持っていない彗星限定の武器から選ぶ。すべて持っていれば普通の彗星にする
			var ids: Array = ConfigManager.weapons.keys().filter(func(id):
				return ConfigManager.weapons[id].comet_only and not state.weapons.has(id))
			if not ids.is_empty():
				r.rare_weapon = ids[rng.randi_range(0, ids.size() - 1)]
		rocks.append(r)
		_stream_t = 0.0
		return

## 隕石の配置の番号 index が彗星なら、その彗星の情報を返す（彗星でなければ null）。
func comet_at(index: int) -> Rock:
	if index < 0 or index >= rocks.size() or rocks[index].kind != &"comet":
		return null
	return rocks[index]

## 隕石の配置の番号 index がレアな彗星なら、落とす彗星限定の武器の管理 ID（そうでなければ空）。
func comet_weapon(index: int) -> StringName:
	var c := comet_at(index)
	return c.rare_weapon if c != null else &""

func _update_moons() -> void:
	for m in moons:
		var a := m.a0 + m.dir * cfg.moon_orbit_speed * state.world_time
		m.pos = Vector2(cos(a), sin(a)) * m.orbit
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

## 中心からの距離 r の危険度（0〜1）。中間の環で 0、惑星の表面と外縁に向かって 1。
func danger_at(r: float) -> float:
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
	return null if found == null else {"body": found, "t": earliest, "point": p0.lerp(p1, earliest)}

## 半径 radius の円が、いちばん近い障害物の表面に触れるまでの距離（重なっていれば 0 以下）。
func body_gap(p: Vector2, radius: float) -> float:
	var gap := INF
	for b in bodies:
		gap = minf(gap, p.distance_to(b.pos) - b.r - radius)
	return gap

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

## 軌道の半径帯に月を登録。月が周回しても所属帯は変わらない。
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

## 元の近傍条件を維持し、該当する半径帯の月だけを確認する。
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

## 敵（行 i）が障害物をすり抜けないよう、表面で止めて横方向の速度だけ残す。
func collide_enemy(i: int, from: Vector2) -> void:
	var table := enemies.table
	var r := table.r[i]
	var hit = first_body_hit(from, table.pos[i], r)
	if hit == null:
		return
	var b: Body = hit.body
	var n: Vector2 = hit.point - b.pos
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
