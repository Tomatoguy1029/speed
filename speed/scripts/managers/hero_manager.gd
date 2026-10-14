## 英雄の星座（仕様書 8.1・13.1）。フィールドの端に捕らわれた星座、解放、特別な枠の力。
##
## 星座の形と力の値は HeroDef（res://data/heroes/）。力が効いている間の中身は、
## 力を使う所（DrawManager・CombatManager など）が state.hero_power と state.hero_active_t を見て決める。
class_name HeroManager
extends RunSystem

var enemies: EnemyManager
var field: FieldManager
var combat: CombatManager

## ヘルクレス座の火の隕石：落ちてくる途中（位置と、落ちるまでの残り時間）と、燃えている跡（位置と残り時間）
var falls: Array[Vector3] = []
var burns: Array[Vector3] = []
var _fire_t := 0.0
var _burn_tick := 0.0

## 今フィールドにある英雄の星座（無ければ null）
var hero: HeroDef
var center := Vector2.ZERO
## 星の世界座標
var stars := PackedVector2Array()
## 星座線ごとに、光ったか（1 なら光った）
var lit := PackedByteArray()
var guarded := false
## 1回の突進の中で、最後に通った星（突進が変わると -1）
var _last_star := -1
var _last_dash := -1
var _prev_pos := Vector2.ZERO
## エンドレスモード：次の星座が現れるまでの時間（負なら待っていない）
var _next_t := -1.0

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
	hero = null
	_next_t = -1.0
	falls.clear()
	burns.clear()
	_prev_pos = state.ship_pos
	if state.endless:
		_place(_random_hero(&""))
		return
	for def: HeroDef in ConfigManager.heroes.values():
		if def.stage == state.stage_index:
			_place(def)

func _random_hero(except: StringName) -> HeroDef:
	var list: Array = ConfigManager.heroes.values().filter(func(d): return d.id != except)
	if list.is_empty():
		return null
	return list[state.rng.randi_range(0, list.size() - 1)]

## 星座をフィールドの端のほうの、機体から離れたランダムな位置に置く。
func _place(def: HeroDef) -> void:
	hero = def
	if def == null:
		return
	var rng := state.rng
	for attempt in 16:
		center = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(cfg.field_radius * 0.72, cfg.field_radius - 600.0)
		if center.distance_to(state.ship_pos) > 2500.0 and field.body_gap(center, 0.0) > 600.0:
			break
	var rot := rng.randf() * TAU
	stars = PackedVector2Array()
	for p in def.stars:
		stars.append(center + p.rotated(rot) * cfg.hero_scale)
	lit = PackedByteArray()
	lit.resize(def.links.size() / 2)
	guarded = false
	_last_star = -1

func tick(real_dt: float, _world_dt: float) -> void:
	if state.hero_cd > 0.0:
		state.hero_cd = maxf(0.0, state.hero_cd - real_dt)
	if state.hero_active_t > 0.0:
		state.hero_active_t = maxf(0.0, state.hero_active_t - real_dt)
		if state.hero_active_t <= 0.0:
			state.emit(&"hero_power_end", {"id": state.hero_power})
	if _next_t >= 0.0:
		_next_t -= real_dt
		if _next_t < 0.0:
			_place(_random_hero(state.hero_power))
	_tick_hercules(real_dt)
	var from := _prev_pos
	_prev_pos = state.ship_pos
	if hero == null or not is_captive():
		return
	if not guarded and state.ship_pos.distance_squared_to(center) < cfg.hero_guard_range * cfg.hero_guard_range:
		_spawn_guards()
	if not state.tracing:
		return
	if state.dash_id != _last_dash:
		_last_dash = state.dash_id
		_last_star = -1
	_pass_stars(from, state.ship_pos)

## まだ解放されていない星座がフィールドにあるか。
func is_captive() -> bool:
	return hero != null and lit.count(1) < lit.size()

## 突進で from から to へ動いた間に通った星を、通った順に調べる。
## 1回の突進で隣り合う2つの星を続けて通ると、その間の星座線が光る。
func _pass_stars(from: Vector2, to: Vector2) -> void:
	var reach := cfg.hero_star_radius + cfg.ship_radius
	var hits: Array = []
	for k in stars.size():
		var t := Geom.seg_circle_t(from, to, stars[k], reach)
		if t >= 0.0:
			hits.append([t, k])
	if hits.is_empty():
		return
	hits.sort_custom(func(a, b): return a[0] < b[0])
	for h in hits:
		var k: int = h[1]
		if k == _last_star:
			continue
		if _last_star >= 0:
			_light(_last_star, k)
		_last_star = k

func _light(a: int, b: int) -> void:
	var links := hero.links
	for n in lit.size():
		var p := links[n * 2]
		var q := links[n * 2 + 1]
		if lit[n] == 0 and ((p == a and q == b) or (p == b and q == a)):
			lit[n] = 1
			state.emit(&"hero_link", {"from": stars[a], "to": stars[b]})
			if lit.count(1) == lit.size():
				_free()
			return

## 全部の星座線が光った：特別な枠に、その星座の力が入る。
func _free() -> void:
	state.hero_power = hero.id
	state.hero_cd = 0.0
	state.hero_active_t = 0.0
	state.emit(&"hero_freed", {"id": hero.id, "pos": center})
	if state.endless:
		_next_t = cfg.hero_next_time

## 星座の周りに、そのステージの強敵を出して守らせる。
func _spawn_guards() -> void:
	guarded = true
	var types: Array[StringName] = []
	var phases: Array = state.stage.phases if state.stage != null else []
	for p: PhaseDef in phases:
		for k in p.mix:
			var def := enemies.def_of(StringName(k))
			if def != null and def.max_alive > 0 and def.radius < 50.0 and not types.has(def.id):
				types.append(def.id)
	if types.is_empty():
		return
	for n in cfg.hero_guards:
		var def := enemies.def_of(types[state.rng.randi_range(0, types.size() - 1)])
		var p := center + Vector2.from_angle(TAU * n / float(cfg.hero_guards)) * 420.0
		enemies.spawn(def, enemies.spawn_level(), p, {"facing": (state.ship_pos - p).angle()})

## 特別な枠の力を使う（Q）。使えなければ何もしない。
func activate() -> void:
	if state.hero_power == &"" or state.hero_cd > 0.0:
		return
	var def: HeroDef = ConfigManager.heroes.get(state.hero_power)
	if def == null:
		return
	state.hero_cd = def.cooldown
	state.hero_active_t = def.duration
	state.emit(&"hero_power", {"id": def.id, "pos": state.ship_pos})

# ── ヘルクレス座：火の隕石（仕様書 8.1） ─────────────────────────────

## 効いている間、間隔ごとに機体の周りへ火の隕石を落とす。落ちた所で爆発し、跡はしばらく燃える。
func _tick_hercules(dt: float) -> void:
	var def: HeroDef = ConfigManager.heroes.get(&"hercules")
	if def == null:
		return
	var p := def.params
	if active_power() == &"hercules":
		_fire_t -= dt
		if _fire_t <= 0.0:
			_fire_t = float(p.interval)
			var at := _fire_target()
			falls.append(Vector3(at.x, at.y, float(p.fall_time)))
	var dmg := combat.attack_power() * float(p.power)
	for k in range(falls.size() - 1, -1, -1):
		var f := falls[k]
		f.z -= dt
		if f.z > 0.0:
			falls[k] = f
			continue
		falls.remove_at(k)
		var at := Vector2(f.x, f.y)
		_burn_enemies(at, float(p.radius), dmg)
		state.emit(&"explode", {"pos": at, "radius": float(p.radius), "cause": &"fire", "color": Color("#ff7a2e"), "life": 0.45})
		burns.append(Vector3(at.x, at.y, float(p.burn_time)))
	_burn_tick -= dt
	var tick := _burn_tick <= 0.0
	if tick:
		_burn_tick = 0.25
	for k in range(burns.size() - 1, -1, -1):
		var b := burns[k]
		b.z -= dt
		if b.z <= 0.0:
			burns.remove_at(k)
			continue
		burns[k] = b
		if tick:
			_burn_enemies(Vector2(b.x, b.y), float(p.radius) * 0.8, dmg * float(p.burn_power))

## 火の隕石を落とす位置：機体の周り（画面の半分くらいの範囲）のランダムな位置。敵がいれば、その位置に寄せる。
func _fire_target() -> Vector2:
	var half := state.view_half * 0.5
	var rows := PackedInt32Array()
	combat.grid.query_radius(state.ship_pos, half.length(), cfg.max_enemy_radius, rows)
	var t := enemies.table
	for attempt in 6:
		if rows.is_empty():
			break
		var i := rows[state.rng.randi_range(0, rows.size() - 1)]
		if t.dead[i] == 0 and t.meteor_index[i] < 0:
			return t.pos[i] + Vector2.from_angle(state.rng.randf() * TAU) * state.rng.randf() * 40.0
	return state.ship_pos + Vector2(state.rng.randf_range(-half.x, half.x), state.rng.randf_range(-half.y, half.y))

## 範囲の敵を、装甲に関係なく焼く。
func _burn_enemies(center: Vector2, radius: float, dmg: float) -> void:
	var rows := PackedInt32Array()
	combat.grid.query_radius(center, radius, cfg.max_enemy_radius, rows)
	var t := enemies.table
	for i in rows:
		if t.dead[i] == 0 and t.meteor_index[i] < 0 and t.pos[i].distance_to(center) <= radius + t.r[i]:
			combat.damage_enemy(i, dmg, {"cause": &"fire", "no_crit": true, "knock": 80.0,
				"dir": (t.pos[i] - center).normalized(), "impact": center})
			if state.phase != RunState.Phase.PLAY:
				return

## 効いている力（無ければ空）。
func active_power() -> StringName:
	return state.hero_power if state.hero_active_t > 0.0 else &""
