## ゲージと描画・なぞり・勢い（仕様書 6）。
##
## 描画となぞりは実秒で進む。世界の速さ（描画中 0.1 倍、なぞり中は突進の速さに反比例）は
## world_scale() で RunManager に伝える。
class_name DrawSystem
extends RunSystem

var field: FieldSystem:
	get: return ctx.field
var combat: CombatSystem:
	get: return ctx.combat
var build: LoadoutSystem:
	get: return ctx.loadout
var ship: ShipSystem:
	get: return ctx.ship

var intent: Intent = Intent.new()
var run: TraceRun = null
## ふたご座の力：双子の機体のなぞりの記録と速さ
var twin_run: TraceRun = null
var _ready_emitted := true
var _pre_dash_speed := 0.0
## 線の最初の点を置いた時刻（ミリ秒）。確定を受け付けるまでの時間を数える
var _first_point_msec := 0

func setup(context: RunContext) -> void:
	super(context)
	state.gauge = 1.0

## 今の世界の速さ（仕様書 6.2・6.5）。
func world_scale() -> float:
	if state.drawing:
		return cfg.draw_time_scale
	if state.tracing and run != null:
		return clampf(cfg.draw_run_slow_ref / maxf(1.0, run.speed), cfg.draw_run_scale_min, 1.0)
	return 1.0

## 入力を受けて描き始める・描く・確定する。ヒットストップ中も呼ぶ（描き始めだけは止めない）。
func handle_input() -> void:
	var it := intent
	if not state.drawing and not state.tracing:
		if (it.press or it.alt_press) and state.gauge >= cfg.draw_min_charge:
			_start(it)
			return
	if state.drawing:
		_update_drawing(it)

func tick(real_dt: float, _world_dt: float) -> void:
	if state.tracing:
		_trace(real_dt)
	elif not state.drawing:
		_charge(real_dt)
	if state.twin_tracing and state.phase == RunState.Phase.PLAY:
		_trace_twin(real_dt)

# ── 充填（仕様書 6.1） ───────────────────────────────────────────

func _charge(real_dt: float) -> void:
	var before := state.gauge
	state.gauge = minf(1.0, state.gauge + real_dt / (state.stats.charge_time * state.stats.capacity))
	if before < 1.0 and state.gauge >= 1.0:
		state.emit(&"gauge_full")

# ── 描画（仕様書 6.2・6.3） ──────────────────────────────────────

## 描ける長さの上限。
func budget(gauge_amount: float) -> float:
	return cfg.draw_length * gauge_amount * (state.stats.max_speed / cfg.base_max_speed) * state.stats.length_mult

func _start(it: Intent) -> void:
	_pre_dash_speed = state.ship_vel.length()
	state.glide = false
	state.drawing = true
	state.draw_started = it.press
	state.draw_blocked = false
	state.trace_full_charge = state.gauge >= 1.0 - 1e-6
	state.draw_start_charge = state.gauge
	state.draw_gauge = state.stats.capacity * state.gauge
	state.draw_limit = budget(state.draw_gauge)
	state.draw_length = 0.0
	state.draw_points = PackedVector2Array()
	if it.press:
		state.draw_points.append(field.push_out(it.pen, cfg.ship_radius + 4.0))
		_first_point_msec = _clock_msec()
	state.emit(&"draw_start")

func _update_drawing(it: Intent) -> void:
	if not state.draw_started:
		if it.press:
			state.draw_started = true
			state.draw_points.append(field.push_out(it.pen, cfg.ship_radius + 4.0))
			_first_point_msec = _clock_msec()
		elif it.touch and it.pen_release:
			_cancel()
		return
	if it.has_cursor:
		_extend(it.pen)
	if it.touch and (it.pen_release or it.alt_press):
		if state.draw_points.size() >= 2:
			_commit(it)
		else:
			_cancel()
	elif state.draw_length >= state.draw_limit - 0.5 or state.draw_blocked:
		_commit(it)
	elif it.press and _can_confirm():
		_commit(it)

## クリックで確定できるか：描き始めから config.draw_confirm_delay 秒たち、線ができていること（仕様書 6.3）。
func _can_confirm() -> bool:
	return _clock_msec() - _first_point_msec >= cfg.draw_confirm_delay * 1000.0 and state.draw_points.size() >= 2

func _clock_msec() -> int:
	return roundi(state.sim_time * 1000.0) if state.lab_mode else Time.get_ticks_msec()

func _cancel() -> void:
	state.drawing = false
	state.draw_points = PackedVector2Array()
	state.twin_first = PackedVector2Array()

func _extend(to: Vector2) -> void:
	var last := state.draw_points[state.draw_points.size() - 1]
	var d := to - last
	var length := d.length()
	if length < cfg.draw_step:
		return
	var remain := state.draw_limit - state.draw_length
	if remain <= 0.5:
		return
	var L := minf(length, remain)
	var u := d / length
	var hit = field.first_body_hit(last, last + u * L, cfg.ship_radius)
	if hit != null:
		L = maxf(0.0, hit.t * L - 2.0)
		state.draw_blocked = true
	if L < 1.0:
		return
	state.draw_points.append(last + u * L)
	state.draw_length += L
	_smooth_last_corner()

## 試用中：端点と鋭い折り返しを保ち、細かな揺れだけ最大2.5画面px抑える。
func _smooth_last_corner() -> void:
	var pts := state.draw_points
	if pts.size() < 3:
		return
	var i := pts.size() - 2
	var a := pts[i - 1]
	var b := pts[i]
	var c := pts[i + 1]
	if (b - a).normalized().dot((c - b).normalized()) < 0.5:
		return
	var offset := ((a + c) * 0.5 - b) * 0.5
	offset = offset.limit_length(2.5 / maxf(state.camera_zoom, 0.01))
	var corrected := b + offset
	# 補正で障害物へ入り込む形には変えない。
	if field.first_body_hit(a, corrected, cfg.ship_radius) != null \
		or field.first_body_hit(corrected, c, cfg.ship_radius) != null:
		return
	var old_length := a.distance_to(b) + b.distance_to(c)
	var new_length := a.distance_to(corrected) + corrected.distance_to(c)
	pts[i] = corrected
	state.draw_points = pts
	state.draw_length += new_length - old_length

## 線を確定して、なぞりを始める（仕様書 6.3〜4.5）。
func _commit(_it: Intent) -> void:
	if state.draw_points.size() < 2:
		# 線ができていない（描き始めの点がすぐ惑星・月に当たったとき）：描くのをやめ、ゲージは減らない
		_cancel()
		return
	if ctx.heroes != null and ctx.heroes.capture_first_trace():
		return
	var twin := state.twin_first
	if twin.is_empty():
		state.gauge = maxf(0.0, state.gauge - state.draw_start_charge * minf(1.0, state.draw_length / state.draw_limit))
	else:
		# 自分は1本目を、双子のもう1機は2本目を駆け抜ける
		state.twin_path = state.draw_points
		state.draw_points = twin
		state.twin_first = PackedVector2Array()
	if state.bonus_t > 0.0:
		# ボーナスステージ：放つとすぐ満タンに戻る
		state.gauge = 1.0
	var pts := state.draw_points
	# 今の位置から描き始めまでも、つながった移動として駆け抜ける（途中の敵にも壁にも当たる）
	if state.ship_pos.distance_to(pts[0]) > 1.0:
		pts.insert(0, state.ship_pos)
	var dir := (pts[1] - pts[0]).normalized()
	var speed := maxf(_launch_speed(dir, state.draw_gauge), 1.0)
	state.ship_vel = dir * speed
	state.ship_boost_t = cfg.boost_duration
	state.ship_fade_t = 0.0
	state.ship_heading = dir
	state.dash_id += 1
	var total := 0.0
	state.trace_lengths = PackedFloat32Array()
	for i in range(1, pts.size()):
		var l := pts[i].distance_to(pts[i - 1])
		state.trace_lengths.append(l)
		total += l
	run = TraceRun.new()
	run.speed = speed
	run.rate = maxf(speed, total / cfg.draw_run_time)
	state.trace_path = pts
	state.trace_total = total
	state.trace_progress = 0.0
	state.drawing = false
	state.tracing = true
	combat.dash_stop = 0.0
	if not twin.is_empty():
		twin_run = TraceRun.new()
		twin_run.speed = speed
		twin_run.rate = run.rate
		state.twin_pos = state.twin_path[0]
		state.twin_tracing = true
	build.on_launch(state.trace_full_charge)
	state.emit(&"launch", {"pos": state.ship_pos, "dir": dir, "gauge": state.draw_gauge})

## なぞりの開始時の速さ：最高速度 × launch_ratio × 充填 ＋ 同じ向きの今の速さ × carry（上限あり）。
func _launch_speed(dir: Vector2, gauge_amount: float) -> float:
	var v := state.ship_vel
	var sp := v.length()
	var c := maxf(0.0, v.dot(dir) / sp) if sp > 0.0 else 0.0
	var carried := sp * cfg.carry * c
	var thrust := state.stats.max_speed * cfg.launch_ratio * gauge_amount
	var limit := state.stats.max_speed * maxf(1.0, gauge_amount)
	return maxf(minf(carried + thrust, limit), sp * c)

# ── なぞり（仕様書 6.5・6.6） ────────────────────────────────────

func _trace(real_dt: float) -> void:
	var pts := state.trace_path
	var dist := run.rate * real_dt
	# なぞり中の当たり判定は、線の左右の帯の太さ
	var R := combat.trace_radius()
	while dist > 1e-9 and run.seg < pts.size() - 1:
		var a := pts[run.seg]
		var b := pts[run.seg + 1]
		var seg_len := a.distance_to(b)
		if seg_len < 1e-6:
			run.seg += 1
			run.seg_pos = 0.0
			continue
		var u := (b - a) / seg_len
		var move := minf(dist, seg_len - run.seg_pos)
		var from := state.ship_pos
		# 本体から離れた敵には、もう一度当てられる
		var et := combat.enemies.table
		for id in run.inside.keys():
			var i: int = run.inside[id]
			if not combat.enemies.is_same(i, id) or et.dead[i] != 0 or not combat.contains_target(i,from,R+2.0):
				run.inside.erase(id)
		run.seg_pos += move
		dist -= move
		state.ship_pos = a + u * run.seg_pos
		state.ship_vel = u * run.speed
		state.ship_heading = u
		if combat.wall_bounce(from):
			_end_trace(false)
			return
		if combat.collide_ship(from, R, run):
			build.on_trail(run, from, state.ship_pos)
			_end_trace(false)
			return
		build.on_trail(run, from, state.ship_pos)
		if state.phase != RunState.Phase.PLAY:
			return
		var sp := state.ship_vel.length()
		if sp < run.speed:
			run.speed = sp
		if run.seg_pos >= seg_len - 1e-9:
			run.seg += 1
			run.seg_pos = 0.0
	state.trace_progress = clampf(float(run.seg) / maxf(1.0, pts.size() - 1), 0.0, 1.0)
	if run.seg >= pts.size() - 1:
		_end_trace(true)

## 双子の機体が2本目の線を、自分と同じ速さで駆け抜ける。敵には体当たりと同じように当たり、弾かれない。
func _trace_twin(real_dt: float) -> void:
	var pts := state.twin_path
	var dist := twin_run.rate * real_dt
	while dist > 1e-9 and twin_run.seg < pts.size() - 1:
		var a := pts[twin_run.seg]
		var b := pts[twin_run.seg + 1]
		var seg_len := a.distance_to(b)
		var move := minf(dist, seg_len - twin_run.seg_pos)
		var from := state.twin_pos
		twin_run.seg_pos += move
		dist -= move
		state.twin_pos = a + (b - a) / maxf(seg_len, 1e-6) * twin_run.seg_pos
		combat.twin_sweep(twin_run, from, state.twin_pos)
		if state.phase != RunState.Phase.PLAY:
			return
		if twin_run.seg_pos >= seg_len - 1e-9:
			twin_run.seg += 1
			twin_run.seg_pos = 0.0
	if twin_run.seg >= pts.size() - 1:
		state.twin_tracing = false
		state.twin_path = PackedVector2Array()
		twin_run = null

## なぞりの終わり。最後まで走り切ったら勢いを残す（glide）。
func _end_trace(completed: bool) -> void:
	state.tracing = false
	var speed := maxf(state.ship_vel.length(), _pre_dash_speed)
	var direction := state.ship_vel.normalized() if not state.ship_vel.is_zero_approx() else state.ship_heading
	state.ship_vel = direction * speed
	state.ship_heading = direction
	if completed:
		# 勢いは突進より遅くし、巡航の速さより下にはしない（仕様書 6.6）
		state.glide = true
		state.glide_t = 0.0
		state.glide_speed = maxf(speed * cfg.glide_speed_ratio, state.stats.max_speed * cfg.steer_cruise)
		state.ship_vel = direction * state.glide_speed
		state.ship_boost_t = cfg.boost_duration
	build.on_end()
	run = null
	state.emit(&"trace_end", {"completed": completed})
