## 出現・攻撃・被弾・撃破を拡大縮小・横移動できるトラックに表示する。
extends Control
signal seek_requested(tick: int)
const LANES := [["lab.message_26fa279ba2", [&"lab_spawn", &"boss_spawn"]], ["lab.message_63d8f43c5b", [&"attack_start", &"shoot"]], ["lab.message_1c155a99a1", [&"hurt", &"crash", &"ship_hit", &"damage", &"bounce"]], ["lab.message_c3775f8a58", [&"kill", &"boss_defeated"]]]
const GUTTER := 64.0
const RULER := 20.0
var session
var zoom := 1.0
var view_start := 0.0
var _panning := false

func _ready() -> void:
	custom_minimum_size = Vector2(240, 100)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	tooltip_text = tr("lab.ui.track_help")

func visible_span() -> float:
	return maxf(1, session.furthest) / zoom if session != null else 1.0

func sync_view(follow := false) -> void:
	if session == null: return
	zoom = clampf(zoom, 1, maxf(1, minf(64, session.furthest / 6.0)))
	var span := visible_span()
	if follow and (session.tick < view_start or session.tick > view_start + span): view_start = session.tick - span
	view_start = clampf(view_start, 0, maxf(0, session.furthest - span))

func zoom_at(factor: float, fraction := 0.5) -> void:
	if session == null: return
	session.playing = false
	var anchor := view_start + visible_span() * fraction
	zoom *= factor
	sync_view()
	view_start = anchor - visible_span() * fraction
	sync_view()
	queue_redraw()

func reset_view() -> void:
	zoom = 1
	view_start = 0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if session == null: return
	if event is InputEventMouseButton:
		var fraction := clampf((event.position.x - GUTTER) / maxf(1, size.x - GUTTER), 0, 1)
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			if event.shift_pressed:
				session.playing = false
				view_start += visible_span() * (-0.125 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.125)
				sync_view()
			else:
				zoom_at(1.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.5, fraction)
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			session.playing = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.position.x >= GUTTER:
			grab_focus()
			seek_requested.emit(roundi(view_start + fraction * visible_span()))
			accept_event()
	elif event is InputEventMouseMotion and _panning:
		view_start -= event.relative.x / maxf(1, size.x - GUTTER) * visible_span()
		sync_view()
		queue_redraw()
		accept_event()

## least 以上で、1・2・5 × 10の累乗のうちいちばん小さい間隔（秒）。
static func _nice_step(least: float) -> float:
	var base := pow(10.0, floorf(log(maxf(least, 1e-4)) / log(10.0)))
	for k in [1.0, 2.0, 5.0, 10.0]:
		if base * k >= least - 1e-9:
			return base * k
	return base * 10.0

func _x(tick: float) -> float:
	return GUTTER + (tick - view_start) / visible_span() * (size.x - GUTTER)

func _duration(start: float, end: float, lane_height: float) -> void:
	var left := maxf(GUTTER, _x(start))
	var right := minf(size.x, _x(end))
	if right <= left: return
	draw_rect(Rect2(left, RULER + lane_height * 1.65, right - left, maxf(3, lane_height * 0.2)), Color(1, 0.65, 0.35, 0.55))

func _draw() -> void:
	if session == null: return
	sync_view()
	var font := get_theme_default_font()
	var lane_height := (size.y - RULER) / LANES.size()
	# 目盛りは切りのいい間隔（0.1・0.2・0.5・1・2・5・10…秒）で、ちょうどの時刻に打つ。80px に1本くらいになる間隔を選ぶ
	var seconds: float = visible_span() * session.DT
	var step := _nice_step(seconds * 80.0 / maxf(1.0, size.x - GUTTER))
	var decimals := 0 if step >= 1.0 else (1 if step >= 0.1 else 2)
	var first := ceilf(view_start * session.DT / step - 1e-6)
	var last := floorf((view_start + visible_span()) * session.DT / step + 1e-6)
	for n in range(int(first), int(last) + 1):
		var x := _x(n * step / session.DT)
		draw_line(Vector2(x, RULER), Vector2(x, size.y), Color("#243248"))
		var caption := tr("lab.ui.track_time") % String.num(n * step, decimals)
		draw_string(font, Vector2(clampf(x - 20, GUTTER, maxf(GUTTER, size.x - 44)), 13), caption, HORIZONTAL_ALIGNMENT_LEFT, 64, 11, Color("#9daec3"))
	for lane in LANES.size():
		var y := RULER + float(lane) * lane_height
		draw_string(font, Vector2(0, y + lane_height * 0.5 + 4), tr(LANES[lane][0]), HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 4, 11)
		draw_line(Vector2(GUTTER, y + lane_height - 1), Vector2(size.x, y + lane_height - 1), Color("#243248"))
		for event in session.events:
			if event.get("type") in LANES[lane][1]:
				var x := _x(event.tick)
				if x < GUTTER or x > size.x: continue
				draw_rect(Rect2(x, y + 3, 3, maxf(4, lane_height - 6)), [Color.SKY_BLUE, Color.ORANGE, Color.SALMON, Color.LIGHT_GREEN][lane])
	var starts := {}
	for event in session.events:
		if event.get("type") == &"attack_start": starts[int(event.token)] = int(event.tick)
		elif event.get("type") == &"attack_end" and starts.has(int(event.token)):
			_duration(starts[int(event.token)], event.tick, lane_height)
			starts.erase(int(event.token))
	for start in starts.values(): _duration(start, session.tick, lane_height)
	var cursor := _x(session.tick)
	if cursor >= GUTTER and cursor <= size.x: draw_line(Vector2(cursor, RULER), Vector2(cursor, size.y), Color.WHITE, 1.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _panning = false
