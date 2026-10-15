## 本番の敵・弾・範囲を表示する、実験場の編集キャンバス。
extends Control

signal picked(row: int)
signal route_edited

var session
var mode := 0 # 0 選択、1 配置、2 線、3 試遊
var spawn_type := "drifter"
var spawn_count := 1
var spawn_level := 1.0
var center := Vector2.ZERO
var zoom := 0.6
var show_ranges := true
var show_ids := true
var route := PackedVector2Array()
var result: Dictionary = {}
var _textures: Dictionary = {}
var _drag_id := -1
var _drag_point := -1
var _dragging := false
var _pan := false
var _ghost := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(300, 240)

func world(p: Vector2) -> Vector2:
	return (p - size / 2.0) / zoom + center

func screen(p: Vector2) -> Vector2:
	return (p - center) * zoom + size / 2.0

func texture_for(id: String) -> Texture2D:
	if not _textures.has(id):
		var path := "res://assets/pixel/%s.png" % id
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[id]

func _gui_input(event: InputEvent) -> void:
	if session == null or not is_instance_valid(session.run) or session.seeking:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var old := world(event.position)
			zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.08, 3.0)
			center += old - world(event.position)
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				var p := world(event.position)
				if mode == 1:
					var kind := "boss" if ConfigManager.bosses.has(StringName(spawn_type)) else "spawn"
					session.perform(kind, {"type": spawn_type, "pos": [p.x, p.y], "count": spawn_count, "level": spawn_level})
					picked.emit(session.selected)
				elif mode == 2:
					_drag_point = -1
					for i in route.size():
						if screen(route[i]).distance_to(event.position) < 12:
							_drag_point = i
					if _drag_point < 0:
						route.append(p)
						_drag_point = route.size() - 1
					result.clear()
					route_edited.emit()
				elif mode == 3:
					session.perform("input", {"cursor": [p.x, p.y], "press": true})
				else:
					var row := _pick(p)
					session.selected = row
					picked.emit(row)
					if row >= 0:
						_drag_id = session.run.enemies.table.id[row]
						_ghost = p
						_dragging = true
			else:
				if _dragging and _drag_id >= 0:
					var p := world(event.position)
					session.perform("move", {"id": _drag_id, "pos": [p.x, p.y]})
				_dragging = false
				_drag_point = -1
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and mode == 2:
			if not route.is_empty():
				route.remove_at(route.size() - 1)
				result.clear()
				route_edited.emit()
			queue_redraw()
	elif event is InputEventMouseMotion:
		if _pan:
			center -= event.relative / zoom
		if _dragging:
			_ghost = world(event.position)
		if _drag_point >= 0:
			route[_drag_point] = world(event.position)
			result.clear()
			route_edited.emit()
		if mode == 3:
			var p := world(event.position)
			session.perform("input", {"cursor": [p.x, p.y]})
		queue_redraw()

func _pick(pos: Vector2) -> int:
	var t = session.run.enemies.table
	var best := -1
	var distance := INF
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i]:
			var d: float = pos.distance_to(t.pos[i])
			if d < maxf(t.r[i], 12 / zoom) and d < distance:
				distance = d
				best = i
	return best

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#090f1a"))
	var grid := 200.0 * zoom
	var offset := screen(Vector2.ZERO)
	for x in range(ceili(size.x / grid) + 1):
		var a := fposmod(offset.x, grid) + x * grid
		draw_line(Vector2(a, 0), Vector2(a, size.y), Color("#172131"))
	for y in range(ceili(size.y / grid) + 1):
		var a := fposmod(offset.y, grid) + y * grid
		draw_line(Vector2(0, a), Vector2(size.x, a), Color("#172131"))
	if session == null or not is_instance_valid(session.run):
		return
	var run: RunManager = session.run
	for body in run.field.bodies:
		draw_circle(screen(body.pos), maxf(body.r * zoom, 1), Color("#333f59"))
	_draw_projectiles(run.projectiles)
	var t := run.enemies.table
	for i in t.alive.size():
		if not t.alive[i] or t.dead[i]:
			continue
		var pos := screen(t.pos[i])
		var radius := maxf(3, t.r[i] * zoom)
		if not Rect2(Vector2.ZERO, size).grow(radius + 200).has_point(pos):
			continue
		var selected: bool = session.selected == i
		var def: EnemyDef = t.def[i]
		if show_ranges and def != null and selected:
			var length := float(def.params.get("beam_len", def.params.get("wave_radius", def.params.get("reach", def.params.get("range", 0)))))
			if length > 0:
				draw_arc(pos, length * zoom, 0, TAU, 64, Color(0.98, 0.65, 0.3, 0.35), 1.5)
				var end := pos + Vector2.from_angle(t.facing[i]) * length * zoom
				draw_line(pos, end, Color(0.98, 0.65, 0.3, 0.5), 2)
		var tex := texture_for(String(t.type[i]))
		if tex != null:
			draw_set_transform(pos, t.facing[i], Vector2.ONE)
			var dimensions := Vector2(tex.get_size())
			dimensions *= radius * 2 / maxf(dimensions.x, dimensions.y)
			draw_texture_rect(tex, Rect2(-dimensions / 2, dimensions), false)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(pos, radius, t.color[i])
			draw_line(pos, pos + Vector2.from_angle(t.facing[i]) * radius, Color.WHITE, 2)
		if t.charge[i] > 0:
			draw_arc(pos, radius + 5, 0, TAU, 24, Color("#ffbf63"), 2)
		if selected:
			draw_arc(pos, radius + 9, 0, TAU, 32, Color("#71e4e0"), 2)
			var width := radius * 2
			draw_rect(Rect2(pos + Vector2(-radius, -radius - 18), Vector2(width, 4)), Color("#354052"))
			draw_rect(Rect2(pos + Vector2(-radius, -radius - 18), Vector2(width * t.hp[i] / maxf(1, t.max_hp[i]), 4)), Color("#88d8a0"))
		if show_ids:
			draw_string(ThemeDB.fallback_font, pos + Vector2(radius + 3, 0), "%s #%d" % [t.type[i], t.id[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b8c6da"))
	var ship := screen(run.state.ship_pos)
	var angle := run.state.ship_heading.angle()
	var triangle := PackedVector2Array([ship + Vector2.from_angle(angle) * 14, ship + Vector2.from_angle(angle + 2.5) * 10, ship + Vector2.from_angle(angle - 2.5) * 10])
	draw_colored_polygon(triangle, Color("#d8f2ff"))
	if run.state.tracing:
		_draw_route(run.state.trace_path, Color("#6db9ff"), 2)
	if not route.is_empty():
		_draw_route(route, Color("#77e4bc"), 3)
	if _dragging:
		draw_circle(screen(_ghost), 20, Color(0.4, 1, 1, 0.25))
	if result.has("end"):
		draw_circle(screen(Vector2(result.end[0], result.end[1])), 12, Color("#ffca6e"), false, 3)

func _draw_route(points: PackedVector2Array, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(screen(p))
	if pts.size() >= 2:
		draw_polyline(pts, Color(color, 0.13), maxf(3, session.run.cfg.wave_radius * 2 * zoom), true)
		draw_polyline(pts, color, width, true)
	for i in pts.size():
		draw_circle(pts[i], 5, color)
		draw_string(ThemeDB.fallback_font, pts[i] + Vector2(7, -7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func _draw_projectiles(p: ProjectileManager) -> void:
	for i in p.hostile_alive.size():
		if p.hostile_alive[i]:
			draw_circle(screen(p.hostile_pos[i]), maxf(2, p.hostile_r[i] * zoom), Color("#ff9c83"))
	for i in p.friend_alive.size():
		if p.friend_alive[i]:
			draw_circle(screen(p.friend_pos[i]), maxf(1.5, p.friend_r[i] * zoom), Color("#8bd7ff"))
	for i in p.hazard_alive.size():
		if not p.hazard_alive[i]:
			continue
		var charging := p.hazard_t[i] < p.hazard_delay[i]
		var color := Color("#e6b969") if charging else Color("#ff6b7a")
		var pos := screen(p.hazard_pos[i])
		var kind := p.hazard_kind[i]
		if charging and not show_ranges:
			draw_circle(pos, 6, color)
			continue
		if kind == ProjectileManager.HazardKind.BEAM or kind == ProjectileManager.HazardKind.WALL:
			var end := pos + Vector2.from_angle(p.hazard_angle[i]) * p.hazard_len[i] * zoom
			draw_line(pos, end, Color(color, 0.18 if charging else 0.55), maxf(2, p.hazard_width[i] * zoom), true)
			draw_line(pos, end, color, 1.5, true)
		elif kind == ProjectileManager.HazardKind.ZONE:
			draw_circle(pos, p.hazard_len[i] * zoom, Color(color, 0.13))
			draw_arc(pos, p.hazard_len[i] * zoom, 0, TAU, 48, color, 2)
		else:
			var radius := p.hazard_len[i] if charging else p.wave_radius(i)
			var pts := PackedVector2Array()
			for k in 97:
				var angle := p.hazard_angle[i] - p.hazard_arc[i] + 2 * p.hazard_arc[i] * k / 96.0
				var in_gap := p.hazard_gap_w[i] > 0 and absf(angle_difference(angle, p.hazard_gap[i])) < p.hazard_gap_w[i]
				if in_gap:
					if pts.size() > 1:
						draw_polyline(pts, color, maxf(2, p.hazard_width[i] * zoom), true)
					pts.clear()
				else:
					pts.append(pos + Vector2.from_angle(angle) * radius * zoom)
			if pts.size() > 1:
				draw_polyline(pts, color, maxf(2, p.hazard_width[i] * zoom), true)
