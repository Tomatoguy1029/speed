## 戦闘の計算。当たり判定の格子・攻撃力・接触・クリティカル・ダメージ・撃破・範囲攻撃・ヒットストップ（仕様書 7）。
class_name CombatManager
extends RunSystem

## 吹き飛ばしが強く、生き残った雑魚が追跡をやめる攻撃（仕様書 11.5）
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

var _buf := PackedInt32Array()
var _hits: Array = []

func tick(real_dt: float, _world_dt: float) -> void:
	# 突進していない間、ヒットストップの上限が戻る（仕様書 7.4）
	if not state.tracing and dash_stop > 0.0:
		dash_stop = maxf(0.0, dash_stop - real_dt * cfg.kill_hitstop_regen)

func rebuild_grid() -> void:
	grid.build(enemies.table, cfg.grid_cell)

## 近くの敵の行（out に入れる）。
func nearby(p: Vector2, radius: float, out: PackedInt32Array) -> void:
	grid.query_radius(p, radius, cfg.max_enemy_radius, out)

## 範囲 lo〜hi の敵の行（out に入れる）。
func in_rect(lo: Vector2, hi: Vector2, out: PackedInt32Array) -> void:
	var pad := Vector2(cfg.max_enemy_radius, cfg.max_enemy_radius)
	grid.query(lo - pad, hi + pad, out)

# ── 攻撃力と装甲（仕様書 7.1・7.2・7.3） ──────────────────────────

func attack_power() -> float:
	return cfg.base_attack * state.stats.attack_mult * cfg.atk_scale * burst_power

func can_pierce(atk: float, i: int, crit: bool) -> bool:
	return atk >= enemies.table.armor[i] * (cfg.crit_armor if crit else 1.0)

## 背面の弱点に当たったか（装甲型と戦艦だけ）。
func is_weak_hit(i: int, hit: Vector2) -> bool:
	var t := enemies.table
	if t.weak_arc[i] <= 0.0:
		return false
	var a := (hit - t.pos[i]).angle()
	return absf(Geom.angle_diff(a, t.facing[i] + PI)) <= t.weak_arc[i]

# ── 機体と敵の接触（仕様書 7.2） ──────────────────────────────────

## 機体が from から今の位置まで動いたときの、敵との接触。run はなぞり中の記録（なぞり中でなければ null）。
## 弾かれたら true を返す。
func collide_ship(from: Vector2, R: float, run: TraceRun) -> bool:
	var t := enemies.table
	var to := state.ship_pos
	var pad := Vector2(R + cfg.max_enemy_radius, R + cfg.max_enemy_radius)
	grid.query(from.min(to) - pad, from.max(to) + pad, _buf)
	_hits.clear()
	for i in _buf:
		if run != null:
			if run.inside.has(t.id[i]):
				continue
		elif t.hit_cd[i] > 0.0:
			continue
		var hit_t := Geom.seg_circle_t(from, to, t.pos[i], t.r[i] + R)
		if hit_t >= 0.0:
			_hits.append([hit_t, i])
	if _hits.is_empty():
		return false
	_hits.sort_custom(func(a, b): return a[0] < b[0])
	for h in _hits:
		var i: int = h[1]
		if t.dead[i] != 0:
			continue
		var hit_pos := from.lerp(to, h[0])
		var vel := state.ship_vel
		var sp := vel.length()
		var dir := vel / sp if sp > 0.0 else Vector2.ZERO
		var atk := attack_power()
		var crit := is_weak_hit(i, hit_pos) or state.rng.randf() < state.stats.crit_chance
		var fast := run != null or state.glide or sp >= state.stats.max_speed * cfg.ram_speed_ratio
		if not fast:
			# 普段の接触：攻撃にならず、敵の接触ダメージを受ける
			t.hit_cd[i] = cfg.contact_cooldown
			ship.damage(t.contact[i], 0.1, StringName("contact:" + String(t.type[i])))
			if state.phase == RunState.Phase.PLAY:
				build.on_electric_contact(i)
			continue
		if ignore_armor or can_pierce(atk, i, crit):
			var dmg := atk * (state.stats.crit_mult if crit else 1.0)
			damage_enemy(i, dmg, {"crit": crit, "cause": &"ram", "dir": dir, "impact": hit_pos})
			if crit:
				state.emit(&"weak_impact", {"pos": hit_pos, "enemy_pos": t.pos[i], "r": t.r[i]})
			t.hit_cd[i] = cfg.contact_cooldown
			if run != null:
				var id := t.id[i]
				run.inside[id] = i
				var n: int = run.passes.get(id, 0) + 1
				run.passes[id] = n
				if n > 1:
					state.emit(&"text", {"pos": t.pos[i] + Vector2(t.r[i], -t.r[i] - 16.0), "text": "×%d" % n,
						"color": Color("#ffe46b") if crit else Color.WHITE, "size": 22 + 4 * mini(n, 5)})
			# なぞり中と勢いの間は、雑魚を貫いても減速しない（仕様書 6.6）
			if not (state.glide or state.tracing):
				state.ship_vel *= _pierce_keep(i)
			build.on_contact(i, hit_pos, dir)
			if crit:
				state.hitstop = maxf(state.hitstop, 0.05 if t.dead[i] != 0 else 0.035)
			continue
		# 弾かれた（仕様書 6.5・7.2）
		state.glide = false
		var n := hit_pos - t.pos[i]
		n = n.normalized() if n.length_squared() > 0.0 else -dir
		state.emit(&"block_impact", {"pos": hit_pos, "normal": n, "enemy_pos": t.pos[i], "r": t.r[i]})
		state.ship_pos = t.pos[i] + n * (t.r[i] + R + 1.0)
		var vn := state.ship_vel.dot(n)
		if vn < 0.0:
			state.ship_vel -= n * 2.0 * vn
		state.ship_vel *= cfg.bounce_keep
		if state.ship_vel.length() < cfg.bounce_min_speed:
			state.ship_vel = n * cfg.bounce_min_speed
		state.ship_boost_t = 0.0
		damage_enemy(i, atk * 0.25, {"crit": crit, "cause": &"bump", "dir": -n})
		t.hit_cd[i] = 0.25
		ship.damage(t.contact[i], 0.0, StringName("bump:" + String(t.type[i])))
		build.on_contact(i, hit_pos, dir)
		state.emit(&"bounce", {"pos": state.ship_pos})
		return true
	return false

func _pierce_keep(i: int) -> float:
	var r := enemies.table.r[i]
	var loss := (0.004 + r * 0.0006) if enemies.table.dead[i] != 0 else (0.1 + r * 0.002)
	return 1.0 - minf(0.6, loss)

## なぞりの線から出る波動（仕様書 6.5）。帯から一度外れた敵には、もう一度当たる。
func wave_along(run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	var t := enemies.table
	var W := cfg.wave_radius
	var length := p0.distance_to(p1)
	var n := maxi(1, ceili(length / minf(W, 40.0)))
	var dmg := attack_power() * cfg.wave_damage
	for k in range(1, n + 1):
		var p := p0.lerp(p1, float(k) / n)
		for id in run.wave_inside.keys():
			var inside: int = run.wave_inside[id]
			if not enemies.is_same(inside, id) or t.dead[inside] != 0 \
					or p.distance_to(t.pos[inside]) > t.r[inside] + W + 2.0:
				run.wave_inside.erase(id)
		grid.query_radius(p, W, cfg.max_enemy_radius, _buf)
		for i in _buf:
			var id := t.id[i]
			if run.wave_inside.has(id):
				continue
			run.wave_inside[id] = i
			var d := t.pos[i] - p
			var dist := d.length()
			damage_enemy(i, dmg, {"cause": &"wave", "dir": d / dist if dist > 0.0 else Vector2.ZERO, "knock": 260.0, "impact": p})
			if state.phase != RunState.Phase.PLAY:
				return
		run.wave_acc += length / n
		if run.wave_acc >= 45.0:
			run.wave_acc = 0.0
			state.emit(&"ring", {"pos": p, "radius": W, "color": Color(0.51, 0.88, 1.0, 0.9), "life": 0.35})

# ── ダメージと撃破 ────────────────────────────────────────────────

## 行 i の敵にダメージを与える。opts：crit（なければ確率で判定）、no_crit、cause、dir、knock、impact。
func damage_enemy(i: int, dmg: float, opts := {}) -> void:
	var t := enemies.table
	if t.dead[i] != 0 or dmg <= 0.0 or state.phase != RunState.Phase.PLAY:
		return
	var crit: bool = opts.get("crit", false)
	if not opts.has("crit") and not opts.get("no_crit", false):
		crit = state.rng.randf() < state.stats.crit_chance
		if crit:
			dmg *= state.stats.crit_mult
	var fresh := t.hp[i] >= t.max_hp[i] - 1e-6
	# なぞり中は、波動が本体より少し先に当たる。一撃かどうかは、この突進で最初に触れた時点の HP で判定する
	if state.tracing:
		if t.dash_seen[i] != state.dash_id:
			t.dash_seen[i] = state.dash_id
			t.dash_fresh[i] = 1 if fresh else 0
		fresh = t.dash_fresh[i] != 0
	t.hp[i] -= dmg
	t.flash[i] = 0.12
	var cause: StringName = opts.get("cause", &"")
	state.emit(&"hit", {"pos": t.pos[i], "crit": crit, "dmg": dmg, "cause": cause})
	if crit:
		state.emit(&"text", {"pos": t.pos[i] + Vector2(0, -t.r[i] - 10.0), "text": "CRIT", "color": Color("#ffe46b"), "size": 16})
	if t.hp[i] <= 0.0:
		if fresh and (cause == &"ram" or cause == &"wave"):
			_kill_stop(i, crit)
		kill_enemy(i, opts.merged({"crit": crit}))
	elif opts.has("dir"):
		var mass := maxf(1.0, t.r[i] / 20.0)
		t.vel[i] += opts.dir * float(opts.get("knock", 160.0)) / mass
		if FORCEFUL.has(cause) and t.is_boss[i] == 0:
			t.knock_t[i] = 0.3
	if crit and not opts.get("no_crit", false):
		build.on_critical(opts.get("impact", t.pos[i]))

## 一撃で倒したときのヒットストップ（仕様書 7.4）。
func _kill_stop(i: int, crit: bool) -> void:
	if dash_stop >= cfg.kill_hitstop_cap:
		return
	var big := enemies.table.r[i] > 25.0
	var stop := cfg.kill_hitstop * (cfg.hitstop_big_mult if big else 1.0) * (cfg.hitstop_crit_mult if crit else 1.0)
	state.hitstop = maxf(state.hitstop, stop)
	dash_stop += stop

func kill_enemy(i: int, opts := {}) -> void:
	var t := enemies.table
	if t.dead[i] != 0 or state.phase != RunState.Phase.PLAY:
		return
	if t.is_boss[i] != 0:
		bosses.on_boss_defeated(i, opts)
		return
	enemies.mark_dead(i)
	state.kills += 1
	var cause: StringName = opts.get("cause", &"")
	var dir: Vector2 = opts.get("dir", Vector2.ZERO)
	state.emit(&"kill", {"pos": t.pos[i], "r": t.r[i], "crit": opts.get("crit", false), "type": t.type[i],
		"enemy_type": t.type[i], "meteor_index": t.meteor_index[i], "facing": t.facing[i],
		"elite": t.elite[i] != 0, "cause": cause, "dir": dir, "color": t.color[i]})
	# 大型の敵の撃破では、攻撃する破片が飛ぶ（仕様書 11.6）
	if cause != &"hullDebris" and not (cause == &"ram" and state.weapons.has(&"W03")):
		var speed := cfg.hull_debris_force_speed if FORCEFUL.has(cause) else cfg.hull_debris_speed
		projectiles.scatter_hull(i, dir, speed, attack_power() * cfg.hull_debris_damage)
	enemies.on_enemy_death(i)
	pickups.on_enemy_killed(i)
	build.on_kill(cause)

## 中心 center・半径 radius の敵に、装甲を無視したダメージを与える。
func explode(center: Vector2, radius: float, dmg: float, opts := {}) -> void:
	var t := enemies.table
	var rows := PackedInt32Array()
	grid.query_radius(center, radius, cfg.max_enemy_radius, rows)
	var knock: float = opts.get("knock", 300.0)
	for i in rows:
		if t.dead[i] != 0:
			continue
		var d := t.pos[i] - center
		var dist := d.length()
		var o := opts.duplicate()
		o.dir = d / dist if dist > 0.0 else Vector2.ZERO
		o.knock = knock
		damage_enemy(i, dmg, o)
		if state.phase != RunState.Phase.PLAY:
			return
	state.emit(&"explode", {"pos": center, "radius": radius, "cause": opts.get("cause", &""),
		"color": opts.get("color", Color("#ffb36b")), "life": opts.get("life", 0.4)})
