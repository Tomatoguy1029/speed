## ゲージと描画・なぞり・勢い（仕様書 4）。
##
## 描画となぞりは実秒で進む。世界の速さ（描画中 0.1 倍、なぞり中は突進の速さに反比例）は
## world_scale() で RunManager に伝える。
class_name DrawManager
extends RunSystem

var field: FieldManager
var combat: CombatManager
var build: BuildManager
var ship: ShipManager

var intent: Intent = Intent.new()
var run: TraceRun = null
var _ready_emitted := true

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
	state.gauge = 1.0

## 今の世界の速さ（仕様書 4.2・4.5）。
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

# ── 充填（仕様書 4.1） ───────────────────────────────────────────

func _charge(real_dt: float) -> void:
	var before := state.gauge
	state.gauge = minf(1.0, state.gauge + real_dt / (state.stats.charge_time * state.stats.capacity))
	if before < 1.0 and state.gauge >= 1.0:
		state.emit(&"gauge_full")

# ── 描画（仕様書 4.2・4.3） ──────────────────────────────────────

## 描ける長さの上限。
func budget(gauge_amount: float) -> float:
	return cfg.draw_length * gauge_amount * (state.stats.max_speed / cfg.base_max_speed) * state.stats.length_mult

func _start(it: Intent) -> void:
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
	state.emit(&"draw_start")

func _update_drawing(it: Intent) -> void:
	if not state.draw_started:
		if it.press:
			state.draw_started = true
			state.draw_points.append(field.push_out(it.pen, cfg.ship_radius + 4.0))
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
	elif it.press or state.draw_length >= state.draw_limit - 0.5 or state.draw_blocked:
		_commit(it)

func _cancel() -> void:
	state.drawing = false
	state.draw_points = PackedVector2Array()

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

## 線を確定して、なぞりを始める（仕様書 4.3〜4.5）。
func _commit(it: Intent) -> void:
	if state.draw_points.size() < 2:
		# 何も描かなかった：描き始めの点（なければ機体の位置）から、まっすぐ上限の長さだけ進む
		var u := state.ship_heading
		if state.draw_points.is_empty():
			state.draw_points.append(state.ship_pos)
		var o := state.draw_points[0]
		var tgt := o if o.distance_to(state.ship_pos) > 1.0 else it.pen
		var d := tgt - state.ship_pos
		if d.length() > 1.0:
			u = d.normalized()
		_extend(o + u * state.draw_limit)
		if state.draw_points.size() < 2:
			_cancel()
			return
	state.gauge = maxf(0.0, state.gauge - state.draw_start_charge * minf(1.0, state.draw_length / state.draw_limit))
	var pts := state.draw_points
	_warp(pts[0])
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

## 線の始点へ跳ぶ。跡を残す。
func _warp(to: Vector2) -> void:
	var from := state.ship_pos
	if from.distance_to(to) < 1.0:
		return
	state.emit(&"warp", {"from": from, "to": to})
	state.ship_pos = to

# ── なぞり（仕様書 4.5・4.6） ────────────────────────────────────

func _trace(real_dt: float) -> void:
	var pts := state.trace_path
	var dist := run.rate * real_dt
	var R := cfg.ship_radius
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
		for id in run.inside.keys():
			var e: Enemy = run.inside[id]
			if e.dead or from.distance_to(e.pos) > e.r + R + 2.0:
				run.inside.erase(id)
		run.seg_pos += move
		dist -= move
		state.ship_pos = a + u * run.seg_pos
		state.ship_vel = u * run.speed
		combat.wave_along(run, from, state.ship_pos)
		if state.phase != RunState.Phase.PLAY:
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

## なぞりの終わり。最後まで走り切ったら勢いを残す（glide）。
func _end_trace(completed: bool) -> void:
	state.tracing = false
	if completed:
		state.glide = true
		state.ship_boost_t = cfg.boost_duration
	build.on_end()
	run = null
	state.emit(&"trace_end", {"completed": completed})
