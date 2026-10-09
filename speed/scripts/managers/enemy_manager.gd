## 雑魚の配列・行動・出現・補充・再配置（仕様書 11、設計書 6・6.1）。
##
## 敵はノードではなく Enemy のデータとして配列で持つ。雑魚の行動は種類ごとの単純なステートマシン
## （例：ダーターの予告 → 突進 → 回復）。隕石とボスもこの配列に入るが、数え方と行動は別に扱う。
class_name EnemyManager
extends RunSystem

var field: FieldManager
var projectiles: ProjectileManager
var bosses: BossManager

## 開発用計測の差し込み口。通常プレイでは未設定。
var profile_tick_hook: Callable
var profile_survey_hook: Callable

const BEH := {&"chase": Enemy.Beh.CHASE, &"dash": Enemy.Beh.DASH, &"split": Enemy.Beh.SPLIT,
	&"gunner": Enemy.Beh.GUNNER, &"missile": Enemy.Beh.MISSILE,
	&"battleship": Enemy.Beh.BATTLESHIP, &"drift": Enemy.Beh.DRIFT}

var list: Array = []
var _new: Array = []
## 死んだ敵がいて、配列から外す必要があるか
var dirty := false
var _next_id := 1
var _spawn_acc := 0.0
var _wave_t := 0.0
var _edge_counts := [0, 0, 0, 0]
var _phase_id: StringName = &""

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
	state.enemy_aim = state.ship_pos

# ── 生成 ──────────────────────────────────────────────────────────

## 敵を作る（まだ配列には入れない）。opts：elite、size、facing、spin。仕様書 11.2 の補正をかける。
func create(def: EnemyDef, level: float, pos: Vector2, opts := {}) -> Enemy:
	var e := Enemy.new()
	e.id = _next_id
	_next_id += 1
	e.def = def
	e.type = def.id
	var L := maxf(1.0, level)
	e.level = L
	e.elite = opts.get("elite", false)
	var size: float = opts.get("size", def.radius)
	var z := size / def.radius
	e.r = size * (1.25 if e.elite else 1.0)
	# 手描き素材はエリートも同じ基準サイズで運用する。
	if def.id in RenderManager.NATIVE_SPRITES:
		e.r = def.radius
	if def.id != &"meteor":
		e.r *= cfg.character_scale
	e.max_hp = def.hp * z * z * (1.0 + 0.6 * (L - 1.0)) * cfg.enemy_hp_mult * (3.0 if e.elite else 1.0)
	e.hp = e.max_hp
	e.armor = def.armor * z * (1.0 + 0.35 * (L - 1.0)) * cfg.enemy_armor_mult * (1.3 if e.elite else 1.0)
	e.contact = def.contact * (1.0 + 0.2 * (L - 1.0))
	e.xp = def.xp * z * (1.0 + 0.5 * (L - 1.0)) * (4.0 if e.elite else 1.0)
	e.speed = def.speed * (1.0 + 0.04 * (L - 1.0))
	e.pos = pos
	e.facing = opts.get("facing", 0.0)
	e.spin = opts.get("spin", 0.0)
	e.weak_arc = def.weak_arc
	e.color = def.color
	var fire_interval: float = def.params.get("fire_interval", 0.0)
	e.fire_t = fire_interval * (0.5 + state.rng.randf() * 0.5)
	e.beh = BEH.get(def.behavior, Enemy.Beh.CHASE)
	e.roam_phase = e.id * 1.61803398875
	e.roam_angle = e.id * 2.39996322973
	e.roam_radius = (0.45 + 0.5 * sqrt(fmod(e.id * 0.61803398875, 1.0))) * minf(1.0, cfg.enemy_pursuit_spread / 480.0)
	e.accel = def.accel if def.accel > 0.0 else 2.0
	e.turn = def.turn if def.turn > 0.0 else 4.0
	return e

func add(e: Enemy) -> void:
	list.append(e)

## 分裂などで増える敵。更新の終わりに、個体数の上限の範囲で加える（仕様書 11.3）。
func add_later(e: Enemy) -> void:
	_new.append(e)

func def_of(type: StringName) -> EnemyDef:
	return ConfigManager.enemies.get(type) as EnemyDef

## 負荷計測用。通常の出現上限を超え、画面内にランダムな通常敵を追加する。
func debug_spawn_random(count: int) -> void:
	if not OS.is_debug_build():
		return
	var choices: Array[EnemyDef] = []
	for def: EnemyDef in ConfigManager.sorted(ConfigManager.enemies):
		if def.id != &"meteor":
			choices.append(def)
	if choices.is_empty():
		return
	var view := state.view_rect()
	var level: float = _target().level
	for i in clampi(count, 1, 10000):
		var def := choices[state.rng.randi_range(0, choices.size() - 1)]
		var pos := Vector2(state.rng.randf_range(view.position.x, view.end.x),
			state.rng.randf_range(view.position.y, view.end.y))
		var opts := {"facing": (state.ship_pos - pos).angle()}
		if def.size_var:
			opts.size = def.radius * state.rng.randf_range(0.85, 1.45)
		var e := create(def, level + field.danger_at(pos.length()) * cfg.danger_level, pos, opts)
		e.pos = field.push_out(pos, e.r + 4.0)
		if e.pos.length() > cfg.field_radius - e.r:
			e.pos = e.pos.normalized() * (cfg.field_radius - e.r)
		add(e)

# ── 更新 ──────────────────────────────────────────────────────────

func tick(_real_dt: float, world_dt: float) -> void:
	if profile_tick_hook.is_valid():
		profile_tick_hook.call(_real_dt, world_dt)
		return
	if world_dt <= 0.0:
		return
	_update_aim(world_dt)
	var dt := world_dt
	var aim := state.enemy_aim
	var vc := state.view_center
	var vh := state.view_half
	var cycle_len := cfg.enemy_approach_cycle
	var appr := cfg.enemy_approach_time
	var blend := cfg.enemy_approach_blend
	var roam_turn := cfg.enemy_roam_turn
	for e: Enemy in list:
		if e.dead or e.is_boss or e.meteor_index >= 0:
			continue
		e.age += dt
		if e.hit_cd > 0.0:
			e.hit_cd -= dt
		if e.flash > 0.0:
			e.flash -= dt
		var from := e.pos
		if e.shove_time > 0.0 or e.knock_t > 0.0 or e.beh != Enemy.Beh.CHASE:
			_update(e, dt)
		else:
			# 追跡（いちばん多い雑魚）は関数を呼ばずにここで計算する（仕様書 11.5）
			var cycle := fmod(e.age + e.roam_phase, cycle_len)
			var roam := clampf(minf((cycle - appr) / blend, (cycle_len - cycle) / blend), 0.0, 1.0)
			var target := aim
			if roam > 0.0:
				var ang := e.roam_angle + e.age * roam_turn
				var ux := cos(ang)
				var uy := sin(ang)
				var edge := e.roam_radius / maxf(absf(ux), absf(uy))
				target = aim + (Vector2(vc.x + ux * edge * vh.x, vc.y + uy * edge * vh.y) - aim) * roam
			var d := target - e.pos
			var dist := d.length()
			if dist < 0.001:
				dist = 1.0
			var k := minf(1.0, e.accel * dt)
			e.vel += (d * (e.speed / dist) - e.vel) * k
			var to_aim := (aim - e.pos).angle()
			var turn_max := e.turn * dt
			e.facing += clampf(wrapf(to_aim - e.facing, -PI, PI), -turn_max, turn_max)
			e.pos += e.vel * dt
		if field.near_body(e.pos, e.r + e.vel.length() * dt):
			field.collide_enemy(e, from)
	_flush_new()

## 敵の狙い：機体の遅れた位置（仕様書 7.5）。
func _update_aim(dt: float) -> void:
	var d := state.ship_pos - state.enemy_aim
	var dist := d.length()
	var max_lag := maxf(300.0, state.view_half.length() * 0.55)
	if dist > max_lag:
		state.enemy_aim = state.ship_pos - d / dist * max_lag
		d = state.ship_pos - state.enemy_aim
		dist = max_lag
	if dist < 1e-6:
		return
	var step := minf(dist * (1.0 - exp(-dt / cfg.enemy_aim_lag)), cfg.enemy_aim_speed * dt)
	state.enemy_aim += d / dist * step

func _update(e: Enemy, dt: float) -> void:
	if e.shove_time > 0.0:
		e.shove_from = e.pos
		e.shoved = true
		e.shove_time -= dt
		e.vel = e.shove_vel
		e.shove_vel *= exp(-dt * 0.8)
	elif e.knock_t > 0.0:
		e.knock_t -= dt
		e.vel *= exp(-dt * 2.0)
	else:
		match e.beh:
			Enemy.Beh.DASH:
				_dash(e, dt)
			Enemy.Beh.SPLIT:
				_chase(e, dt)
				_split(e, dt)
			Enemy.Beh.GUNNER:
				_keep_distance(e, dt)
				if _gun_timer(e, dt):
					projectiles.fire_enemy(e, (state.enemy_aim - e.pos).angle(), e.def.params.bullet_speed, &"bullet")
			Enemy.Beh.MISSILE:
				_keep_distance(e, dt)
				if _gun_timer(e, dt):
					projectiles.fire_enemy(e, e.facing, e.def.params.missile_speed, &"missile")
			Enemy.Beh.BATTLESHIP:
				_chase(e, dt)
				if _gun_timer(e, dt):
					fire_volley(e)
			Enemy.Beh.DRIFT:
				e.facing += e.spin * dt
			_:
				_chase(e, dt)
	e.pos += e.vel * dt

## 扇状に弾をばらまく（戦艦）。
func fire_volley(e: Enemy) -> void:
	var base := (state.enemy_aim - e.pos).angle()
	var n: int = e.def.params.volley
	var spread: float = e.def.params.spread
	for i in n:
		projectiles.fire_enemy(e, base + (float(i) / (n - 1) - 0.5) * spread, e.def.params.bullet_speed, &"bullet")

func _steer_to(e: Enemy, target: Vector2, speed: float, accel: float, dt: float) -> void:
	var d := target - e.pos
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var k := minf(1.0, accel * dt)
	e.vel += (d / dist * speed - e.vel) * k

func _turn_toward(e: Enemy, target: float, rate: float, dt: float) -> void:
	e.facing += clampf(Geom.angle_diff(target, e.facing), -rate * dt, rate * dt)

## 追跡：18秒の周期で「接近」と「広域移動」を切り替える（仕様書 11.5）。
func _chase(e: Enemy, dt: float) -> void:
	var aim := state.enemy_aim
	var cycle := fmod(e.age + e.roam_phase, cfg.enemy_approach_cycle)
	var roam := clampf(minf((cycle - cfg.enemy_approach_time) / cfg.enemy_approach_blend,
		(cfg.enemy_approach_cycle - cycle) / cfg.enemy_approach_blend), 0.0, 1.0)
	var ang := e.roam_angle + e.age * cfg.enemy_roam_turn
	var u := Vector2(cos(ang), sin(ang))
	var edge := e.roam_radius / maxf(absf(u.x), absf(u.y))
	var roam_target := state.view_center + Vector2(u.x * edge * state.view_half.x, u.y * edge * state.view_half.y)
	var target := aim + (roam_target - aim) * roam
	_steer_to(e, target, e.speed, e.accel, dt)
	_turn_toward(e, (aim - e.pos).angle(), e.turn, dt)

func _dash(e: Enemy, dt: float) -> void:
	var p := e.def.params
	var d := state.enemy_aim.distance_to(e.pos)
	e.timer -= dt
	match e.mode:
		Enemy.Mode.MOVE:
			_chase(e, dt)
			if d < float(p.range):
				e.mode = Enemy.Mode.WINDUP
				e.timer = p.windup
		Enemy.Mode.WINDUP:
			e.vel *= 1.0 - 4.0 * dt
			_turn_toward(e, (state.enemy_aim - e.pos).angle(), 6.0, dt)
			if e.timer <= 0.0:
				e.mode = Enemy.Mode.DASH
				e.timer = p.dash_time
				e.vel = Vector2.from_angle(e.facing) * float(p.dash_speed)
		Enemy.Mode.DASH:
			if e.timer <= 0.0:
				e.mode = Enemy.Mode.RECOVER
				e.timer = p.recover
		Enemy.Mode.RECOVER:
			e.vel *= 1.0 - 2.0 * dt
			if e.timer <= 0.0:
				e.mode = Enemy.Mode.MOVE

func _split(e: Enemy, dt: float) -> void:
	var p := e.def.params
	e.bud_t += dt
	if e.bud_t < float(p.bud_interval):
		return
	e.bud_t = 0.0
	if e.buds >= int(p.max_buds):
		return
	e.buds += 1
	var a := state.rng.randf() * TAU
	add_later(create(def_of(&"splitling"), e.level, e.pos + Vector2.from_angle(a) * e.r * 1.5, {"facing": a}))

## 射撃型・ミサイル艇：機体の周りの keep の距離を保ち、回り込む。
func _keep_distance(e: Enemy, dt: float) -> void:
	var aim := state.enemy_aim
	var d := e.pos - aim
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var u := d / dist
	var side := 1.0 if e.id % 2 == 1 else -1.0
	var keep: float = e.def.params.keep
	var target := aim + u * keep + Vector2(-u.y, u.x) * 200.0 * side
	_steer_to(e, target, e.speed, e.def.accel, dt)
	_turn_toward(e, (aim - e.pos).angle(), 3.0, dt)

## 発射までの時間を進める。予告の間は charge が 0〜1 で増える。撃つときに true。
func _gun_timer(e: Enemy, dt: float) -> bool:
	var p := e.def.params
	e.fire_t -= dt
	var tele: float = p.telegraph
	e.charge = 1.0 - maxf(0.0, e.fire_t) / tele if e.fire_t < tele else 0.0
	if e.fire_t <= 0.0:
		e.fire_t = p.fire_interval
		return true
	return false

## 撃破されたときの処理（分裂型は2体に分かれる）。
func on_enemy_death(e: Enemy) -> void:
	if e.type != &"splitter":
		return
	var n := maxi(1, int(e.def.params.get("death_split", 2)))
	for i in n:
		var a := e.facing + PI / 2.0 + TAU * float(i) / float(n) if n > 2 else e.facing + (1.0 if i == 1 else -1.0) * PI / 2.0
		var c := create(def_of(&"splitling"), e.level, e.pos + Vector2.from_angle(a) * e.r, {"facing": a})
		c.vel = Vector2.from_angle(a) * float(e.def.params.get("split_speed", 200.0))
		c.hit_cd = 0.35
		add_later(c)

## 分裂などで増えた敵を、個体数の上限の範囲で加える（仕様書 11.3）。
func _flush_new() -> void:
	if _new.is_empty():
		return
	var limit := ceili(_target().pop * (1.0 + cfg.enemy_split_overflow))
	var population := _count_population(false)
	for e in _new:
		if population >= limit:
			break
		list.append(e)
		population += 1
	_new.clear()

## 死んだ敵を配列から外す。
func cleanup() -> void:
	if not dirty:
		return
	dirty = false
	var alive: Array = []
	for e: Enemy in list:
		if not e.dead:
			alive.append(e)
	list = alive

# ── 出現と補充（仕様書 4.2・11.3・11.4） ─────────────────────────────

func current_phase() -> PhaseDef:
	var phases: Array = state.stage.phases
	for p: PhaseDef in phases:
		if state.time < p.end:
			return p
	return phases[phases.size() - 1]

func _target() -> Dictionary:
	var p := current_phase()
	var k := clampf((state.time - p.start) / maxf(0.001, p.end - p.start), 0.0, 1.0)
	return {"phase": p, "pop": lerpf(p.pop_from, p.pop_to, k) * cfg.density_mult, "level": lerpf(p.level_from, p.level_to, k)}

## 通常の敵の数。in_view が true なら、再配置の範囲の中だけを数える。
func _count_population(in_view: bool) -> int:
	var n := 0
	var lim := state.view_half * cfg.spawn_recycle_scale + Vector2(200, 200)
	for e: Enemy in list:
		if e.dead or e.is_boss or e.meteor_index >= 0:
			continue
		if in_view:
			var d := (e.pos - state.view_center).abs()
			if d.x > lim.x or d.y > lim.y:
				continue
		n += 1
	return n

## 補充と再配置。更新の終わりに呼ぶ。
func spawner_tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	var t := _target()
	var phase: PhaseDef = t.phase
	if phase.id != _phase_id:
		_phase_id = phase.id
		state.emit(&"phase", {"id": phase.id})
	var alive := _survey()
	var deficit := maxf(0.0, t.pop - alive)
	var rate := maxf(phase.rate * cfg.density_mult, deficit / cfg.spawn_refill_time)
	var cap := maxf(8.0, 8.0 * cfg.density_mult)
	_spawn_acc = minf(_spawn_acc + rate * world_dt, cap)
	var attempts := 0
	while _spawn_acc >= 1.0 and alive < t.pop and attempts < cap:
		attempts += 1
		_spawn_acc -= 1.0
		if _spawn_one(t):
			alive += 1
	if phase.wave_interval > 0.0:
		_wave_t += world_dt
		if _wave_t >= phase.wave_interval:
			_wave_t = 0.0
			if alive < t.pop:
				_spawn_wave(t, t.pop - alive)

var _type_counts: Dictionary = {}
var _far_enemies: Array[Enemy] = []

## 1回の走査で、外周の辺ごとの数・種類ごとの数・再配置の範囲の中の数を数え、遠くの敵を再配置する。
## 戻り値は再配置の範囲の中の通常の敵の数。
func _survey() -> int:
	if profile_survey_hook.is_valid():
		return profile_survey_hook.call()
	_edge_counts.fill(0)
	_type_counts.clear()
	var battleships := 0
	var titans := 0
	var vc := state.view_center
	var vh := state.view_half
	var lim := vh * cfg.spawn_recycle_scale + Vector2(200, 200)
	var alive := 0
	var center_x := vh.x * 0.45
	var center_y := vh.y * 0.45
	_far_enemies.clear()
	for e: Enemy in list:
		if e.dead or e.is_boss or e.meteor_index >= 0:
			continue
		# 種類別上限を使う2種類だけ集計。全種類の辞書更新は不要。
		var type := e.type
		if type == &"battleship":
			battleships += 1
		elif type == &"titan":
			titans += 1
		var rel := e.pos - vc
		if absf(rel.x) > lim.x or absf(rel.y) > lim.y:
			_far_enemies.append(e)
			continue
		alive += 1
		var ax := absf(rel.x)
		var ay := absf(rel.y)
		if ax < center_x and ay < center_y:
			continue
		# 正規化した距離の比較を交差乗算にし、個体ごとの除算を省く。
		var side := (0 if rel.x < 0.0 else 1) if ax * vh.y > ay * vh.x else (2 if rel.y < 0.0 else 3)
		_edge_counts[side] += 1
	_type_counts[&"battleship"] = battleships
	_type_counts[&"titan"] = titans
	for e: Enemy in _far_enemies:
		if _recycle(e):
			alive += 1
	return alive

## 画面の四辺の外の出現位置。外周の敵が少ない辺を優先する。
func spawn_point(extra := 0.0) -> Variant:
	var view_c := state.view_center
	var half := state.view_half
	for i in 24:
		var weights := []
		var total := 0.0
		for edge in 4:
			var w: float = (half.y if edge < 2 else half.x) / (_edge_counts[edge] + 8)
			weights.append(w)
			total += w
		var roll := state.rng.randf() * total
		var side := 0
		while side < 3 and roll >= weights[side]:
			roll -= weights[side]
			side += 1
		var margin := cfg.spawn_margin + extra + state.rng.randf() * 80.0
		var along := state.rng.randf() * 2.0 - 1.0
		var p := view_c
		if side < 2:
			p += Vector2((-1.0 if side == 0 else 1.0) * (half.x + margin), along * half.y)
		else:
			p += Vector2(along * half.x, (-1.0 if side == 2 else 1.0) * (half.y + margin))
		var r := p.length()
		if r < cfg.field_radius + 200.0 and r > cfg.planet_radius + 150.0:
			_edge_counts[side] += 1
			return p
	return null

func _spawn_one(t: Dictionary) -> bool:
	var p = spawn_point()
	if p == null:
		return false
	var phase: PhaseDef = t.phase
	var danger := field.danger_at(p.length())
	var type := _pick_type(phase, danger)
	if type == &"battleship" and _type_counts.get(type, 0) >= cfg.battleship_max:
		return false
	if type == &"titan" and _type_counts.get(type, 0) >= cfg.titan_max:
		return false
	var def := def_of(type)
	if def == null:
		return false
	var late := phase.id == &"tension" or phase.id == &"escape"
	var elite := type != &"battleship" and state.rng.randf() < 0.01 + 0.06 * danger + (0.02 if late else 0.0)
	var level: float = t.level + danger * cfg.danger_level
	var opts := {"elite": elite, "facing": (state.ship_pos - p).angle()}
	if def.size_var:
		opts.size = def.radius * (0.85 + state.rng.randf() * 0.45)
	add(create(def, level, p, opts))
	_type_counts[type] = _type_counts.get(type, 0) + 1
	return true

func _pick_type(phase: PhaseDef, danger: float) -> StringName:
	var items: Array = []
	var total := 0.0
	for k in phase.mix:
		items.append([StringName(k), float(phase.mix[k])])
	if danger > 0.25:
		var ramp := clampf(state.time / 150.0, 0.15, 1.0)
		items.append([&"armored", 2.0 * danger])
		items.append([&"gunner", danger * ramp])
		items.append([&"missile", 0.7 * danger * ramp])
	for it in items:
		total += it[1]
	var roll := state.rng.randf() * total
	for it in items:
		if roll < it[1]:
			return it[0]
		roll -= it[1]
	return items[items.size() - 1][0]

## 無双期の群れ：環状に囲むか、一方向から流れ込む。
func _spawn_wave(t: Dictionary, remaining: float) -> void:
	var n := mini(roundi(30 * cfg.density_mult), ceili(remaining))
	var def := def_of(&"swarm")
	var half := state.view_half
	if state.rng.randf() < 0.5:
		for i in n:
			var a := (i + state.rng.randf()) / n * TAU
			var u := Vector2(cos(a), sin(a))
			var d := minf((half.x + cfg.spawn_margin) / maxf(0.0001, absf(u.x)), (half.y + cfg.spawn_margin) / maxf(0.0001, absf(u.y))) + state.rng.randf() * 90.0
			add(create(def, t.level, state.view_center + u * d, {"facing": a + PI}))
	else:
		var a := state.rng.randf() * TAU
		var u := Vector2(cos(a), sin(a))
		for i in n:
			var d := minf(half.x / maxf(0.0001, absf(u.x)), half.y / maxf(0.0001, absf(u.y))) + cfg.spawn_margin + i * 12.0
			var off := (state.rng.randf() - 0.5) * 120.0
			add(create(def, t.level, state.ship_pos + u * d + Vector2(-u.y, u.x) * off, {"facing": a + PI}))
	state.emit(&"wave")

## 遠くへ離れた敵を、画面外の出現位置へ移す。HP などは保ち、撃破・経験値・ドロップは発生しない。
func _recycle(e: Enemy) -> bool:
	var p = spawn_point()
	if p == null:
		return false
	e.pos = p
	var to_ship: Vector2 = (state.ship_pos - e.pos).normalized()
	e.vel = to_ship * e.speed
	e.facing = to_ship.angle()
	e.mode = Enemy.Mode.MOVE
	e.timer = 0.0
	e.charge = 0.0
	e.fire_t = e.def.params.get("fire_interval", 0.0)
	return true
