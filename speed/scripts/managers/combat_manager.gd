## 戦闘の計算。当たり判定の格子・攻撃力・接触・クリティカル・ダメージ・撃破・範囲攻撃・ヒットストップ（仕様書 7）。
class_name CombatManager
extends RunSystem

## 吹き飛ばしが強く、生き残った雑魚が追跡をやめる攻撃（仕様書 11.5）
const FORCEFUL := [&"sonic", &"killSonic", &"critBeam", &"bipolar", &"towShot"]

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
		elif t.hit_cd[i] > 0.0 and t.meteor_index[i] < 0 and t.beh[i] != EnemyTable.Beh.SHIELD:
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
		var fast := run != null or state.glide or sp >= state.stats.max_speed * cfg.ram_speed_ratio
		var shield_front := t.beh[i] == EnemyTable.Beh.SHIELD and t.stone[i] <= 0.0 \
			and enemies.shield_blocks(i, hit_pos, dir)
		if shield_front and (not fast or (run == null and t.hit_cd[i] > 0.0)):
			# 接触のクールダウン中も押し戻し、普通の移動で盾をすり抜けるのを防ぐ。
			_bump_obstacle(i, hit_pos, R, dir, false)
			return true
		if run == null and t.hit_cd[i] > 0.0 and t.meteor_index[i] < 0:
			continue
		var crit := is_weak_hit(i, hit_pos) or state.rng.randf() < state.stats.crit_chance
		if t.stone[i] > 0.0:
			# 石になった敵は、触れると装甲や倒し方に関係なく一撃で砕ける
			t.hit_cd[i] = cfg.contact_cooldown
			if run != null:
				run.inside[t.id[i]] = i
			state.emit(&"block_impact", {"pos": t.pos[i], "normal": -dir, "enemy_pos": t.pos[i], "r": t.r[i]})
			kill_enemy(i, {"cause": &"ram" if fast else &"touch", "dir": dir})
			continue
		if t.type[i] == &"saw":
			_launch_saw(i, dir if dir != Vector2.ZERO else (t.pos[i] - from).normalized(), sp)
			continue
		if not fast and t.meteor_index[i] >= 0:
			_bump_obstacle(i, hit_pos, R, dir)
			continue
		if not fast:
			# 普段の接触：弱い攻撃になる。機体は被弾しない
			t.hit_cd[i] = cfg.contact_cooldown
			damage_enemy(i, atk * cfg.touch_damage, {"cause": &"touch", "dir": dir, "no_crit": true, "impact": hit_pos})
			if state.phase == RunState.Phase.PLAY:
				build.on_electric_contact(i)
			continue
		var gate := enemies.gate_check(i, hit_pos, dir, &"ram")
		if gate == EnemyTable.GateResult.PASS:
			# 特殊な倒し方の条件を満たさない：貫通するが倒れない
			t.hit_cd[i] = cfg.contact_cooldown
			if run != null:
				run.inside[t.id[i]] = i
			continue
		# しし座の力が効いている間のなぞりは、装甲に関係なく貫く
		var leo := run != null and leo_width() > 1.0
		if gate == EnemyTable.GateResult.ALLOW and (ignore_armor or leo or can_pierce(atk, i, crit)):
			var dmg := atk * (state.stats.crit_mult if crit else 1.0)
			if t.beh[i] == EnemyTable.Beh.SHIELD and enemies.shield_rear(i, hit_pos):
				ship.steal_shield(i)
				dmg = maxf(dmg, t.hp[i])
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
				_stop(0.05 if t.dead[i] != 0 else 0.035)
			continue
		# 弾かれた（仕様書 6.5・7.2）
		state.glide = false
		var n := hit_pos - t.pos[i]
		n = n.normalized() if n.length_squared() > 0.0 else -dir
		state.emit(&"block_impact", {"pos": hit_pos, "normal": n, "enemy_pos": t.pos[i], "r": t.r[i]})
		# 押し出すのは機体の本体の大きさまで（なぞり中の太い当たり判定の分は押し出さない）
		state.ship_pos = t.pos[i] + n * (t.r[i] + cfg.ship_radius + 1.0)
		var vn := state.ship_vel.dot(n)
		if vn < 0.0:
			state.ship_vel -= n * 2.0 * vn
		state.ship_vel *= cfg.bounce_keep
		if state.ship_vel.length() < cfg.bounce_min_speed:
			state.ship_vel = n * cfg.bounce_min_speed
		state.ship_boost_t = 0.0
		if gate == EnemyTable.GateResult.ALLOW:
			damage_enemy(i, atk * 0.25, {"crit": crit, "cause": &"bump", "dir": -n})
		t.hit_cd[i] = 0.25
		# 弾かれるのは失敗で、被弾はしない
		build.on_contact(i, hit_pos, dir)
		state.emit(&"bounce", {"pos": state.ship_pos})
		return true
	return false

## 機体が from から今の位置へ動く途中で、移動を止める壁（じょうぎ座のビーム）にぶつかったら、壁の手前で止めて弾く。
## 弾いたら true。弾かれるのは失敗で、被弾はしない。
func wall_bounce(from: Vector2) -> bool:
	var hit := projectiles.block_hit(from, state.ship_pos, cfg.ship_radius)
	if hit.is_empty():
		return false
	var n: Vector2 = hit.normal
	state.ship_pos = hit.pos
	var vn := state.ship_vel.dot(n)
	if vn < 0.0:
		state.ship_vel -= n * 2.0 * vn
	state.ship_vel *= cfg.bounce_keep
	if state.ship_vel.length() < cfg.bounce_min_speed:
		state.ship_vel = n * cfg.bounce_min_speed
	state.ship_boost_t = 0.0
	state.glide = false
	state.emit(&"block_impact", {"pos": state.ship_pos - n * cfg.ship_radius, "normal": n, "enemy_pos": state.ship_pos, "r": cfg.ship_radius})
	state.emit(&"bounce", {"pos": state.ship_pos})
	return true

func _pierce_keep(i: int) -> float:
	var r := enemies.table.r[i]
	var loss := (0.004 + r * 0.0006) if enemies.table.dead[i] != 0 else (0.1 + r * 0.002)
	return 1.0 - minf(0.6, loss)

## しし座の力が効いているときの、なぞりの当たり判定の太さの倍率（効いていなければ 1）。
func leo_width() -> float:
	if state.hero_active_t <= 0.0 or state.hero_power != &"leo":
		return 1.0
	var def: HeroDef = ConfigManager.heroes.get(&"leo")
	return float(def.params.get("width_mult", 1.0)) if def != null else 1.0

## なぞり中の機体の当たり判定の半径（仕様書 6.5）。線の左右この距離に触れた敵に、体当たりが当たる。
## しし座の力が効いている間は太くなる（仕様書 8.1）。
func trace_radius() -> float:
	return cfg.trace_radius * leo_width()

## ふたご座の双子の機体が from から to へ動いた：通った敵に体当たりと同じように当てる（弾かれず、被弾もしない）。
func twin_sweep(run: TraceRun, from: Vector2, to: Vector2) -> void:
	var t := enemies.table
	var R := trace_radius()
	var pad := Vector2(R + cfg.max_enemy_radius, R + cfg.max_enemy_radius)
	var rows := PackedInt32Array()
	grid.query(from.min(to) - pad, from.max(to) + pad, rows)
	var dir := (to - from).normalized()
	var atk := attack_power()
	for i in rows:
		if t.dead[i] != 0 or t.meteor_index[i] >= 0 or run.inside.has(t.id[i]):
			continue
		if Geom.seg_circle_t(from, to, t.pos[i], t.r[i] + R) < 0.0:
			continue
		run.inside[t.id[i]] = i
		if t.stone[i] > 0.0:
			kill_enemy(i, {"cause": &"ram", "dir": dir})
		elif enemies.gate_check(i, to, dir, &"ram", atk) == EnemyTable.GateResult.ALLOW \
				and (ignore_armor or leo_width() > 1.0 or can_pierce(atk, i, false)):
			damage_enemy(i, atk, {"cause": &"ram", "dir": dir, "impact": t.pos[i]})
		if state.phase != RunState.Phase.PLAY:
			return

# ── ダメージと撃破 ────────────────────────────────────────────────

## 行 i の敵にダメージを与える。opts：crit（体当たりで判定したクリティカル。武器などの当たりはクリティカルにならない）、no_crit、cause、dir、knock、impact。
func damage_enemy(i: int, dmg: float, opts := {}) -> void:
	var t := enemies.table
	if t.dead[i] != 0 or dmg <= 0.0 or state.phase != RunState.Phase.PLAY or t.guard[i] > 0.0:
		return
	var cause: StringName = opts.get("cause", &"")
	# 体当たりの通り抜けは collide_ship で扱う。ここでは、条件を満たさない攻撃のダメージを止める
	if cause != &"ram" and cause != &"bump" and enemies.gate_check(i, opts.get("impact", t.pos[i]),
			opts.get("dir", Vector2.ZERO), cause, dmg) != EnemyTable.GateResult.ALLOW:
		return
	if cause == &"fire":
		t.fire_hit[i] = state.world_time
	# 装甲を貫いた不死の首は、その1回で本体への攻撃になる。
	# 通常の頭の HP を繰り返し削る必要はない。
	if cause == &"ram" and t.gate[i] == EnemyTable.Gate.IMMORTAL:
		dmg = maxf(dmg, t.hp[i])
	var crit: bool = opts.get("crit", false)
	var fresh := t.hp[i] >= t.max_hp[i] - 1e-6
	# 一撃かどうかは、この突進で最初に触れた時点の HP で判定する
	if state.tracing:
		if t.dash_seen[i] != state.dash_id:
			t.dash_seen[i] = state.dash_id
			t.dash_fresh[i] = 1 if fresh else 0
		fresh = t.dash_fresh[i] != 0
	t.hp[i] -= dmg
	t.flash[i] = 0.12
	state.emit(&"hit", {"pos": t.pos[i], "crit": crit, "dmg": dmg, "cause": cause})
	if crit:
		state.emit(&"text", {"pos": t.pos[i] + Vector2(0, -t.r[i] - 10.0), "text": "CRIT", "color": Color("#ffe46b"), "size": 16})
	if t.hp[i] <= 0.0:
		if fresh and cause == &"ram":
			_kill_stop(i, crit)
		kill_enemy(i, opts.merged({"crit": crit}))
	elif opts.has("dir"):
		var mass := maxf(1.0, t.r[i] / 20.0)
		t.vel[i] += opts.dir * float(opts.get("knock", 160.0)) / mass
		if FORCEFUL.has(cause) and t.is_boss[i] == 0:
			t.knock_t[i] = 0.3
	if crit and not opts.get("no_crit", false):
		build.on_critical(opts.get("impact", t.pos[i]))

## 普段の速さで隕石・盾の前面に触れた：外へ押し出して跳ね返る。
## 隕石には攻撃力の 1/4 を与え、盾は接触を防ぐ。押し戻しはクールダウン中も毎回行う。
func _bump_obstacle(i: int, hit_pos: Vector2, R: float, dir: Vector2, damage := true) -> void:
	var t := enemies.table
	var n := hit_pos - t.pos[i]
	n = n.normalized() if n.length_squared() > 0.0 else -dir
	state.ship_pos = t.pos[i] + n * (t.r[i] + R + 1.0)
	var vn := state.ship_vel.dot(n)
	if vn < 0.0:
		state.ship_vel -= n * 2.0 * vn
		state.ship_vel *= cfg.bounce_keep
	if t.hit_cd[i] > 0.0:
		return
	t.hit_cd[i] = 0.25
	state.emit(&"block_impact", {"pos": hit_pos, "normal": n, "enemy_pos": t.pos[i], "r": t.r[i]})
	if damage:
		damage_enemy(i, attack_power() * 0.25, {"cause": &"bump", "dir": -n})

## 回る丸鋸（行 i）に触れた：丸鋸が機体の進んでいた向き u へ飛んでいき、その先の敵を巻き込む。1回で壊れる。
func _launch_saw(i: int, u: Vector2, ship_speed: float) -> void:
	var t := enemies.table
	var speed := maxf(cfg.saw_speed, ship_speed)
	projectiles.fire_saw(t.pos[i], u * speed, t.r[i], attack_power() * cfg.saw_power, cfg.saw_life)
	state.emit(&"block_impact", {"pos": t.pos[i], "normal": -u, "enemy_pos": t.pos[i], "r": t.r[i]})
	enemies.mark_dead(i)

## 一撃で倒したときのヒットストップ（仕様書 7.4）。
func _kill_stop(i: int, crit: bool) -> void:
	if dash_stop >= cfg.kill_hitstop_cap:
		return
	var big := enemies.table.r[i] > 25.0
	var stop := cfg.kill_hitstop * (cfg.hitstop_big_mult if big else 1.0) * (cfg.hitstop_crit_mult if crit else 1.0)
	_stop(stop)
	dash_stop += stop

## ヒットストップを seconds 実秒以上にする。設定で切っていれば止めない。
func _stop(seconds: float) -> void:
	if state.hitstop_enabled:
		state.hitstop = maxf(state.hitstop, seconds)

func kill_enemy(i: int, opts := {}) -> void:
	var t := enemies.table
	if t.dead[i] != 0 or state.phase != RunState.Phase.PLAY:
		return
	if t.is_boss[i] != 0:
		bosses.on_boss_defeated(i, opts)
		return
	enemies.mark_dead(i)
	state.kills += 1
	if t.landmark[i] != 0:
		# 目印の星を取り戻した
		state.landmarks.append(t.pos[i])
		state.emit(&"landmark", {"pos": t.pos[i]})
	var cause: StringName = opts.get("cause", &"")
	var dir: Vector2 = opts.get("dir", Vector2.ZERO)
	state.emit(&"kill", {"pos": t.pos[i], "r": t.r[i], "crit": opts.get("crit", false), "type": t.type[i],
		"enemy_type": t.type[i], "meteor_index": t.meteor_index[i], "facing": t.facing[i],
		"elite": t.elite[i] != 0, "cause": cause, "dir": dir, "color": t.color[i]})
	# 大型の敵の撃破では、攻撃する破片が飛ぶ（仕様書 11.6）
	# 質量牽引砲（W21）が船体を牽引したら、破片も死体も出さない
	if build.capture_hull(i, cause):
		t.hull_scattered[i] = 1
	elif cause != &"hullDebris" and cause != &"towShot" and not (cause == &"ram" and state.weapons.has(&"W03")):
		var speed := cfg.hull_debris_force_speed if FORCEFUL.has(cause) else cfg.hull_debris_speed
		projectiles.scatter_hull(i, dir, speed, attack_power() * cfg.hull_debris_damage)
	enemies.on_enemy_death(i, attack_power())
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
