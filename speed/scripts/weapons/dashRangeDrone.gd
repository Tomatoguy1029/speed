## W26 突進範囲ドローン。左右の編隊で経路の外側を掃く。
## 編隊全体で敵IDを共有し、同じ突進では追加直撃を一度だけ与える。
extends WeaponBehavior

var drones: Array[Dictionary] = []
var active := false
var _hit_ids: Dictionary = {}
var _dash_id := -1
var _distance := 0.0
var _normals: Array[Vector2] = []
var _rows := PackedInt32Array()

func level_value(key: String) -> float:
	var values: Array = p(key, [])
	return float(values[clampi(level - 1, 0, values.size() - 1)]) if not values.is_empty() else 0.0

func _sync() -> void:
	var count := int(level_value("drones_per_side_by_level")) * 2
	while drones.size() < count:
		var i := drones.size()
		drones.append({"pos": _idle(i), "dir": state.ship_heading, "trail": [], "break_trail": true})
	if drones.size() > count:
		drones.resize(count)

func _idle(i: int) -> Vector2:
	var rank := i / 2 + 1
	var side := -1.0 if i % 2 == 0 else 1.0
	var dir := state.ship_heading
	return state.ship_pos + (dir.orthogonal() * side * float(p("idle_spacing")) * rank \
		- dir * (float(p("idle_back")) + rank * 7.0)) * cfg.character_scale

func on_launch(_full: bool) -> void:
	_sync()
	active = true
	_hit_ids.clear()
	_dash_id = state.dash_id
	_distance = 0.0
	_normals.clear()
	var pts := state.trace_path
	for i in pts.size():
		var before := (pts[i] - pts[i - 1]).normalized() if i > 0 else (pts[1] - pts[0]).normalized()
		var after := (pts[i + 1] - pts[i]).normalized() if i < pts.size() - 1 else before
		# 平均を正規化せず、鋭角ほど幅を畳む。Uターンの頂点では中心へ戻る。
		_normals.append((before.orthogonal() + after.orthogonal()) * 0.5)
	for d in drones:
		d.trail.clear()
		d.break_trail = true

func on_end() -> void:
	active = false

func tick(dt: float, _busy: bool) -> void:
	_sync()
	active = active and state.tracing and state.phase == RunState.Phase.PLAY
	for i in drones.size():
		var d := drones[i]
		for point in d.trail:
			point.life -= dt
		d.trail = d.trail.filter(func(point): return point.life > 0.0)
		if not active:
			# 復帰中は攻撃・光跡追加を行わない。
			d.pos = d.pos.lerp(_idle(i), 1.0 - exp(-float(p("return_rate")) * dt))
			d.dir = d.dir.lerp(state.ship_heading, 1.0 - exp(-12.0 * dt)).normalized()

func _formation_offset(i: int, normal: Vector2, dir: Vector2, distance: float) -> Vector2:
	var rank := i / 2 + 1
	var side := -1.0 if i % 2 == 0 else 1.0
	var deploy := clampf(distance / (float(p("deploy_distance")) * cfg.character_scale), 0.0, 1.0)
	deploy = smoothstep(0.0, 1.0, deploy)
	var idle := dir.orthogonal() * side * float(p("idle_spacing")) * rank \
		- dir * (float(p("idle_back")) + rank * 7.0)
	var wide := normal * side * level_value("half_span_by_level") * rank / (drones.size() / 2)
	return idle.lerp(wide, deploy) * cfg.character_scale

func on_trail(run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	if run == null or not state.tracing or state.phase != RunState.Phase.PLAY:
		return
	if _dash_id != state.dash_id:
		on_launch(false)
	var pts := state.trace_path
	if run.seg >= pts.size() - 1 or _normals.size() != pts.size():
		return
	var a := pts[run.seg]
	var b := pts[run.seg + 1]
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var dir := (b - a) / length
	var moved := p0.distance_to(p1)
	var end_t := clampf((p1 - a).dot(dir) / length, 0.0, 1.0)
	var start_t := clampf((p0 - a).dot(dir) / length, 0.0, 1.0)
	for i in drones.size():
		var start := p0 + _formation_offset(i, _normals[run.seg].lerp(_normals[run.seg + 1], start_t), dir, _distance)
		var end := p1 + _formation_offset(i, _normals[run.seg].lerp(_normals[run.seg + 1], end_t), dir, _distance + moved)
		var d := drones[i]
		# 角での待機向きの変更は横断攻撃に含めず、新しい区間だけを判定する。
		if d.break_trail or d.pos.distance_to(start) > 4.0 * cfg.character_scale:
			d.trail.append({"pos": start, "life": 0.22, "join": false})
		d.trail.append({"pos": end, "life": 0.22, "join": true})
		if d.trail.size() > 96:
			d.trail = d.trail.slice(d.trail.size() - 96)
		d.pos = end
		d.dir = dir
		d.break_trail = false
		_hit_along(start, end, dir)
		if state.phase != RunState.Phase.PLAY:
			return
	_distance += moved

func _hit_along(a: Vector2, b: Vector2, dir: Vector2) -> void:
	var radius := float(p("drone_hit_radius")) * cfg.character_scale
	var pad := Vector2.ONE * radius
	build.combat.in_rect(a.min(b) - pad, a.max(b) + pad, _rows)
	var t := build.enemies.table
	for i in _rows:
		if t.dead[i] != 0 or _hit_ids.has(t.id[i]):
			continue
		var hit_t := Geom.seg_circle_t(a, b, t.pos[i], t.r[i] + radius)
		if hit_t < 0.0:
			continue
		_hit_ids[t.id[i]] = true
		build.combat.damage_enemy(i, atk() * level_value("damage_by_level"), \
			{"cause": &"dashRangeDrone", "dir": dir, "impact": a.lerp(b, hit_t), "knock": 0.0, "no_crit": true})
		if state.phase != RunState.Phase.PLAY:
			return
