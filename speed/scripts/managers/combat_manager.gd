## 戦闘の計算。当たり判定の格子・攻撃力・接触・クリティカル・ダメージ・撃破・範囲攻撃・ヒットストップ（仕様書 5）。
class_name CombatManager
extends RunSystem

## 吹き飛ばしが強く、生き残った雑魚が追跡をやめる攻撃（仕様書 9.4）
const FORCEFUL := [&"sonic", &"killSonic", &"critBeam"]

var enemies: EnemyManager
var ship: ShipManager
var build: BuildManager
var pickups: PickupManager
var projectiles: ProjectileManager
var field: FieldManager
var bosses: BossManager

var grid := SpatialGrid.new()
## 満タン突撃（特性 T04）による攻撃力の倍率と装甲無視。なぞりの間だけ有効
var burst_power := 1.0
var ignore_armor := false
## 1回の突進で使ったヒットストップの合計
var dash_stop := 0.0

var _buf: Array = []
var _hits: Array = []

func tick(real_dt: float, _world_dt: float) -> void:
	# 突進していない間、ヒットストップの上限が戻る（仕様書 5.4）
	if not state.tracing and dash_stop > 0.0:
		dash_stop = maxf(0.0, dash_stop - real_dt * cfg.kill_hitstop_regen)

func rebuild_grid() -> void:
	grid.build(enemies.list, cfg.grid_cell)

## 近くの敵（out に入れる）。
func nearby(p: Vector2, radius: float, out: Array) -> void:
	grid.query_radius(p, radius, cfg.max_enemy_radius, out)

## 範囲 lo〜hi の敵（out に入れる）。
func in_rect(lo: Vector2, hi: Vector2, out: Array) -> void:
	var pad := Vector2(cfg.max_enemy_radius, cfg.max_enemy_radius)
	grid.query(lo - pad, hi + pad, out)

# ── 攻撃力と装甲（仕様書 5.1・5.2・5.3） ──────────────────────────

func attack_power() -> float:
	return cfg.base_attack * state.stats.attack_mult * cfg.atk_scale * burst_power

func can_pierce(atk: float, e: Enemy, crit: bool) -> bool:
	return atk >= e.armor * (cfg.crit_armor if crit else 1.0)

## 背面の弱点に当たったか（装甲型と戦艦だけ）。
func is_weak_hit(e: Enemy, hit: Vector2) -> bool:
	if e.weak_arc <= 0.0:
		return false
	var a := (hit - e.pos).angle()
	return absf(Geom.angle_diff(a, e.facing + PI)) <= e.weak_arc

# ── 機体と敵の接触（仕様書 5.2） ──────────────────────────────────

## 機体が from から今の位置まで動いたときの、敵との接触。run はなぞり中の記録（なぞり中でなければ null）。
## 弾かれたら true を返す。
func collide_ship(from: Vector2, R: float, run: TraceRun) -> bool:
	var to := state.ship_pos
	var pad := Vector2(R + cfg.max_enemy_radius, R + cfg.max_enemy_radius)
	grid.query(from.min(to) - pad, from.max(to) + pad, _buf)
	_hits.clear()
	for e: Enemy in _buf:
		if run != null:
			if run.inside.has(e.id):
				continue
		elif e.hit_cd > 0.0:
			continue
		var t := Geom.seg_circle_t(from, to, e.pos, e.r + R)
		if t >= 0.0:
			_hits.append([t, e])
	if _hits.is_empty():
		return false
	_hits.sort_custom(func(a, b): return a[0] < b[0])
	for h in _hits:
		var e: Enemy = h[1]
		if e.dead:
			continue
		var hit_pos := from.lerp(to, h[0])
		var vel := state.ship_vel
		var sp := vel.length()
		var dir := vel / sp if sp > 0.0 else Vector2.ZERO
		var atk := attack_power()
		var crit := is_weak_hit(e, hit_pos) or state.rng.randf() < state.stats.crit_chance
		var fast := run != null or state.glide or sp >= state.stats.max_speed * cfg.ram_speed_ratio
		if not fast:
			# 普段の接触：攻撃にならず、敵の接触ダメージを受ける
			e.hit_cd = cfg.contact_cooldown
			ship.damage(e.contact, 0.1, StringName("contact:" + String(e.type)))
			if state.phase == RunState.Phase.PLAY:
				build.on_electric_contact(e)
			continue
		if ignore_armor or can_pierce(atk, e, crit):
			var dmg := atk * (state.stats.crit_mult if crit else 1.0)
			damage_enemy(e, dmg, {"crit": crit, "cause": &"ram", "dir": dir, "impact": hit_pos})
			if crit:
				state.emit(&"weak_impact", {"pos": hit_pos, "enemy_pos": e.pos, "r": e.r})
			e.hit_cd = cfg.contact_cooldown
			if run != null:
				run.inside[e.id] = e
				var n: int = run.passes.get(e.id, 0) + 1
				run.passes[e.id] = n
				if n > 1:
					state.emit(&"text", {"pos": e.pos + Vector2(e.r, -e.r - 16.0), "text": "×%d" % n,
						"color": Color("#ffe46b") if crit else Color.WHITE, "size": 22 + 4 * mini(n, 5)})
			# なぞり中と勢いの間は、雑魚を貫いても減速しない（仕様書 4.6）
			if not (state.glide or state.tracing):
				state.ship_vel *= _pierce_keep(e)
			build.on_contact(e, hit_pos, dir)
			if e.def != null and e.def.params.has("steal"):
				state.glide = false
				state.ship_vel *= 1.0 - float(e.def.params.steal)
				state.emit(&"drain", {"pos": e.pos})
			if crit:
				state.hitstop = maxf(state.hitstop, 0.05 if e.dead else 0.035)
			continue
		# 弾かれた（仕様書 4.5・5.2）
		state.glide = false
		var n := hit_pos - e.pos
		n = n.normalized() if n.length_squared() > 0.0 else -dir
		state.emit(&"block_impact", {"pos": hit_pos, "normal": n, "enemy_pos": e.pos, "r": e.r})
		state.ship_pos = e.pos + n * (e.r + R + 1.0)
		var vn := state.ship_vel.dot(n)
		if vn < 0.0:
			state.ship_vel -= n * 2.0 * vn
		state.ship_vel *= cfg.bounce_keep
		if state.ship_vel.length() < cfg.bounce_min_speed:
			state.ship_vel = n * cfg.bounce_min_speed
		state.ship_boost_t = 0.0
		damage_enemy(e, atk * 0.25, {"crit": crit, "cause": &"bump", "dir": -n})
		e.hit_cd = 0.25
		ship.damage(e.contact, 0.0, StringName("bump:" + String(e.type)))
		build.on_contact(e, hit_pos, dir)
		state.emit(&"bounce", {"pos": state.ship_pos})
		return true
	return false

func _pierce_keep(e: Enemy) -> float:
	var loss := (0.004 + e.r * 0.0006) if e.dead else (0.1 + e.r * 0.002)
	return 1.0 - minf(0.6, loss)

## なぞりの線から出る波動（仕様書 4.5）。帯から一度外れた敵には、もう一度当たる。
func wave_along(run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	var W := cfg.wave_radius
	var length := p0.distance_to(p1)
	var n := maxi(1, ceili(length / minf(W, 40.0)))
	var dmg := attack_power() * cfg.wave_damage
	for k in range(1, n + 1):
		var p := p0.lerp(p1, float(k) / n)
		for id in run.wave_inside.keys():
			var inside: Enemy = run.wave_inside[id]
			if inside.dead or p.distance_to(inside.pos) > inside.r + W + 2.0:
				run.wave_inside.erase(id)
		grid.query_radius(p, W, cfg.max_enemy_radius, _buf)
		for e: Enemy in _buf:
			if run.wave_inside.has(e.id):
				continue
			run.wave_inside[e.id] = e
			var d := e.pos - p
			var dist := d.length()
			damage_enemy(e, dmg, {"cause": &"wave", "dir": d / dist if dist > 0.0 else Vector2.ZERO, "knock": 260.0, "impact": p})
			if state.phase != RunState.Phase.PLAY:
				return
		run.wave_acc += length / n
		if run.wave_acc >= 45.0:
			run.wave_acc = 0.0
			state.emit(&"ring", {"pos": p, "radius": W, "color": Color(0.51, 0.88, 1.0, 0.9), "life": 0.35})

# ── ダメージと撃破 ────────────────────────────────────────────────

## 敵にダメージを与える。opts：crit（なければ確率で判定）、no_crit、cause、dir、knock、impact。
func damage_enemy(e: Enemy, dmg: float, opts := {}) -> void:
	if e.dead or dmg <= 0.0 or state.phase != RunState.Phase.PLAY:
		return
	var crit: bool = opts.get("crit", false)
	if not opts.has("crit") and not opts.get("no_crit", false):
		crit = state.rng.randf() < state.stats.crit_chance
		if crit:
			dmg *= state.stats.crit_mult
	var fresh := e.hp >= e.max_hp - 1e-6
	# なぞり中は、波動が本体より少し先に当たる。一撃かどうかは、この突進で最初に触れた時点の HP で判定する
	if state.tracing:
		if e.dash_seen != state.dash_id:
			e.dash_seen = state.dash_id
			e.dash_fresh = fresh
		fresh = e.dash_fresh
	e.hp -= dmg
	e.flash = 0.12
	var cause: StringName = opts.get("cause", &"")
	state.emit(&"hit", {"pos": e.pos, "crit": crit, "dmg": dmg, "cause": cause})
	if crit:
		state.emit(&"text", {"pos": e.pos + Vector2(0, -e.r - 10.0), "text": "CRIT", "color": Color("#ffe46b"), "size": 16})
	if e.hp <= 0.0:
		if fresh and (cause == &"ram" or cause == &"wave"):
			_kill_stop(e, crit)
		kill_enemy(e, opts.merged({"crit": crit}))
	elif opts.has("dir"):
		var mass := maxf(1.0, e.r / 20.0)
		e.vel += opts.dir * float(opts.get("knock", 160.0)) / mass
		if FORCEFUL.has(cause) and not e.is_boss:
			e.knock_t = 0.3
	if crit and not opts.get("no_crit", false):
		build.on_critical(opts.get("impact", e.pos))

## 一撃で倒したときのヒットストップ（仕様書 5.4）。
func _kill_stop(e: Enemy, crit: bool) -> void:
	if dash_stop >= cfg.kill_hitstop_cap:
		return
	var t := cfg.kill_hitstop * (cfg.hitstop_big_mult if e.r > 25.0 else 1.0) * (cfg.hitstop_crit_mult if crit else 1.0)
	state.hitstop = maxf(state.hitstop, t)
	dash_stop += t

func kill_enemy(e: Enemy, opts := {}) -> void:
	if e.dead or state.phase != RunState.Phase.PLAY:
		return
	if e.is_boss:
		bosses.on_boss_defeated(e, opts)
		return
	e.dead = true
	enemies.dirty = true
	state.kills += 1
	var cause: StringName = opts.get("cause", &"")
	var dir: Vector2 = opts.get("dir", Vector2.ZERO)
	state.emit(&"kill", {"pos": e.pos, "r": e.r, "crit": opts.get("crit", false), "type": e.type,
		"elite": e.elite, "cause": cause, "dir": dir, "color": e.color})
	# 大型の敵の撃破では、攻撃する破片が飛ぶ（仕様書 9.5）
	if cause != &"hullDebris" and not (cause == &"ram" and state.weapons.has(&"W03")):
		var speed := cfg.hull_debris_force_speed if FORCEFUL.has(cause) else cfg.hull_debris_speed
		projectiles.scatter_hull(e, dir, speed, attack_power() * cfg.hull_debris_damage)
	enemies.on_enemy_death(e)
	pickups.on_enemy_killed(e)
	build.on_kill(cause)

## 中心 center・半径 radius の敵に、装甲を無視したダメージを与える。
func explode(center: Vector2, radius: float, dmg: float, opts := {}) -> void:
	var list: Array = []
	grid.query_radius(center, radius, cfg.max_enemy_radius, list)
	var knock: float = opts.get("knock", 300.0)
	for e: Enemy in list:
		if e.dead:
			continue
		var d := e.pos - center
		var dist := d.length()
		var o := opts.duplicate()
		o.dir = d / dist if dist > 0.0 else Vector2.ZERO
		o.knock = knock
		damage_enemy(e, dmg, o)
		if state.phase != RunState.Phase.PLAY:
			return
	state.emit(&"explode", {"pos": center, "radius": radius, "cause": opts.get("cause", &""),
		"color": opts.get("color", Color("#ffb36b")), "life": opts.get("life", 0.4)})
