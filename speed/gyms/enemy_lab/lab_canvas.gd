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
var exit_clearance := 0.0
var show_ranges := true
var show_ids := true
var route := PackedVector2Array()
var result: Dictionary = {}
var pattern: Dictionary = {}
var candidate: Dictionary = {}
var comparisons: Array = []
var selection: Array[int] = []
var _group_origin := Vector2.ZERO
var _drag_positions: Dictionary = {}
var selected_region := -1
var _region := -1
var _resize_region := false
var _drag_route := false
var _route_origin := PackedVector2Array()
var route_undo: Array[PackedVector2Array] = []
var route_redo: Array[PackedVector2Array] = []
var _range_drag := false
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
				if mode == 5:
					_range_drag = session.selected >= 0
					_ghost = p
				elif mode == 4:
					_region = -1
					var anchor: Vector2 = session.vector(pattern.get("anchor", [0, 0]))
					for k in pattern.get("regions", []).size():
						var region: Dictionary = pattern.regions[k]
						if p.distance_to(anchor + session.vector(region.pos)) <= maxf(15 / zoom, float(region.jitter)):
							_region = k
					selected_region = _region
					_resize_region = event.alt_pressed
				elif mode == 1:
					var kind := "boss" if ConfigManager.bosses.has(StringName(spawn_type)) else "spawn"
					session.perform(kind, {"type": spawn_type, "pos": [p.x, p.y], "count": spawn_count, "level": spawn_level})
					picked.emit(session.selected)
				elif mode == 2:
					_remember_route()
					if event.alt_pressed:
						_drag_route = true
						_group_origin = p
						_route_origin = route.duplicate()
						return
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
					var row := _pick(p, event.alt_pressed)
					session.selected = row
					picked.emit(row)
					if row >= 0:
						_drag_id = session.run.enemies.table.id[row]
						if not event.shift_pressed:
							if not selection.has(_drag_id): selection.clear()
						if not selection.has(_drag_id): selection.append(_drag_id)
						_group_origin = p
						_drag_positions.clear()
						for id in selection:
							var j: int = session.row_for_id(id)
							if j >= 0: _drag_positions[id] = session.run.enemies.table.pos[j]
						_ghost = p
						_dragging = true
			else:
				if _range_drag and session.selected >= 0:
					var t: EnemyTable = session.run.enemies.table
					var row: int = session.selected
					var delta := world(event.position) - t.pos[row]
					var key := range_parameter(session.definition_for_row(row))
					if not key.is_empty(): session.perform("edit_range", {"id": t.id[row], "key": key, "length": delta.length(), "angle": delta.angle()})
				_range_drag = false
				if _dragging and _drag_id >= 0:
					var p := world(event.position)
					for id in _drag_positions:
						var to: Vector2 = _drag_positions[id] + p - _group_origin
						session.perform("move", {"id": id, "pos": [to.x, to.y]})
				_dragging = false
				_drag_point = -1
				_region = -1
				_drag_route = false
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and mode == 2:
			if not route.is_empty():
				_remember_route()
				var point := _nearest_route_point(event.position)
				route.remove_at(point if point >= 0 else route.size() - 1)
				result.clear()
				route_edited.emit()
			queue_redraw()
	elif event is InputEventMouseMotion:
		if _range_drag: _ghost = world(event.position)
		if _region >= 0:
			var region: Dictionary = pattern.regions[_region]
			var anchor: Vector2 = session.vector(pattern.get("anchor", [0, 0]))
			if _resize_region:
				region.jitter = world(event.position).distance_to(anchor + session.vector(region.pos))
			else:
				var offset := world(event.position) - anchor
				region.pos = [offset.x, offset.y]
		if _drag_route:
			for k in route.size(): route[k] = _route_origin[k] + world(event.position) - _group_origin
			result.clear()
			route_edited.emit()
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
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			if mode == 2:
				undo_route(event.shift_pressed)
			elif event.shift_pressed: await session.redo_edit()
			else: await session.undo_edit()
		elif mode == 3 and event.keycode == KEY_Q:
			session.perform("input", {"has_cursor": false, "hero": true})
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			for id in selection: session.perform("delete", {"id": id})
			selection.clear()
		elif event.keycode in [KEY_Q, KEY_E]:
			for id in selection:
				var row: int = session.row_for_id(id)
				if row >= 0:
					var t: EnemyTable = session.run.enemies.table
					session.perform("move", {"id": id, "pos": [t.pos[row].x, t.pos[row].y], "angle": t.facing[row] + deg_to_rad(-15 if event.keycode == KEY_Q else 15)})
		elif event.keycode == KEY_D and event.ctrl_pressed:
			var t: EnemyTable = session.run.enemies.table
			for id in selection.duplicate():
				var row: int = session.row_for_id(id)
				if row >= 0:
					var point := t.pos[row] + Vector2(60, 60)
					session.perform("boss" if t.is_boss[row] else "spawn", {"type": String(t.type[row]), "pos": [point.x, point.y], "level": t.level[row], "elite": t.elite[row] != 0, "angle": t.facing[row]})
		elif event.keycode == KEY_SPACE:
			session.playing = not session.playing
		elif event.keycode == KEY_ESCAPE:
			_dragging = false
			_drag_point = -1
			_drag_route = false
			_region = -1
		accept_event()

func _pick(pos: Vector2, cycle := false) -> int:
	var t = session.run.enemies.table
	var best := -1
	var choices: Array[int] = []
	var distance := INF
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i]:
			var d: float = pos.distance_to(t.pos[i])
			if d < maxf(t.r[i], 12 / zoom): choices.append(i)
			if d < maxf(t.r[i], 12 / zoom) and d < distance:
				distance = d
				best = i
	if cycle and not choices.is_empty(): return choices[(choices.find(session.selected) + 1) % choices.size()]
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
	for entry in session.schedule:
		if entry.get("enabled", true):
			var point := screen(session.vector(entry.get("pos", [0, 0])))
			draw_arc(point, maxf(8, float(entry.get("radius", 0)) * zoom), 0, TAU, 32, Color("#9d8ccf"), 1)
			draw_string(ThemeDB.fallback_font, point + Vector2(8, 8), "%s ×%d / %.1fs" % [String(entry.get("type", "")), int(entry.get("count", 1)), float(entry.get("interval", 1))], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#c0b0e2"))
	_draw_projectiles(run.projectiles)
	var drawn_bodies := {}
	for instance in run.bosses.lab_instances:
		if instance.boss_alive() and is_instance_valid(instance.actor) and instance.actor.has_method("draw_on"):
			draw_set_transform(screen(run.enemies.table.pos[instance.boss_row]), 0, Vector2.ONE * zoom)
			instance.actor.draw_on(self)
			draw_set_transform(Vector2.ZERO)
			drawn_bodies[instance.boss_row] = true
	var t := run.enemies.table
	for i in t.alive.size():
		if not t.alive[i] or t.dead[i]:
			continue
		var pos := screen(t.pos[i])
		var radius := maxf(3, t.r[i] * zoom)
		if not Rect2(Vector2.ZERO, size).grow(radius + 200).has_point(pos):
			continue
		var selected: bool = session.selected == i or selection.has(t.id[i])
		var def: EnemyDef = t.def[i]
		if show_ranges and def != null and selected:
			var key := range_parameter(def)
			var length := float(def.params.get(key, 0))
			if length > 0:
				draw_arc(pos, length * zoom, 0, TAU, 64, Color(0.98, 0.65, 0.3, 0.35), 1.5)
				var end := pos + Vector2.from_angle(t.facing[i]) * length * zoom
				draw_line(pos, end, Color(0.98, 0.65, 0.3, 0.5), 2)
				draw_circle(end, 6, Color.ORANGE, false, 2)
		var tex := texture_for(String(t.type[i]))
		if drawn_bodies.has(i):
			pass
		elif tex != null:
			draw_set_transform(pos, t.facing[i], Vector2.ONE)
			var dimensions := Vector2(tex.get_size())
			dimensions *= radius * 2 / maxf(dimensions.x, dimensions.y)
			draw_texture_rect(tex, Rect2(-dimensions / 2, dimensions), false)
			draw_set_transform(Vector2.ZERO)
		else:
			if def != null:
				var polygon := RenderManager._placeholder_points(def.shape)
				for k in polygon.size(): polygon[k] = pos + (polygon[k] * radius).rotated(t.facing[i])
				draw_colored_polygon(polygon, t.color[i])
			else:
				draw_circle(pos, radius, t.color[i])
			draw_line(pos, pos + Vector2.from_angle(t.facing[i]) * radius, Color.WHITE, 2)
		var reason: String = run.projectiles.director.reasons.get(str(t.id[i]), "")
		if show_ranges and not reason.is_empty():
			draw_arc(pos, radius + 6, -PI / 2, PI, 12, Color("#7d8b9d"), 2)
			if selected: draw_string(ThemeDB.fallback_font, pos + Vector2(-radius, radius + 22), reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a5b4cb"))
		if t.charge[i] > 0:
			draw_arc(pos, radius + 5, 0, TAU, 24, Color("#ffbf63"), 2)
		if selected:
			draw_arc(pos, radius + 9, 0, TAU, 32, Color("#71e4e0"), 2)
			var width := radius * 2
			draw_rect(Rect2(pos + Vector2(-radius, -radius - 18), Vector2(width, 4)), Color("#354052"))
			draw_rect(Rect2(pos + Vector2(-radius, -radius - 18), Vector2(width * t.hp[i] / maxf(1, t.max_hp[i]), 4)), Color("#88d8a0"))
		if show_ids or selected:
			draw_string(ThemeDB.fallback_font, pos + Vector2(radius + 3, 0), "%s #%d" % [t.type[i], t.id[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b8c6da"))
	var ship := screen(run.state.ship_pos)
	var angle := run.state.ship_heading.angle()
	var triangle := PackedVector2Array([ship + Vector2.from_angle(angle) * 14, ship + Vector2.from_angle(angle + 2.5) * 10, ship + Vector2.from_angle(angle - 2.5) * 10])
	draw_colored_polygon(triangle, Color("#d8f2ff"))
	if run.state.tracing:
		_draw_route(run.state.trace_path, Color("#6db9ff"), 2)
	if not route.is_empty():
		if exit_clearance > 0: draw_arc(screen(route[route.size() - 1]), (session.run.cfg.ship_radius + exit_clearance) * zoom, 0, TAU, 40, Color("#77e4bc"), 1.5)
		_draw_route(route, Color("#77e4bc"), 3)
	for comparison in comparisons:
		if comparison.get("route") is PackedVector2Array:
			_draw_route(comparison.route, Color(0.7, 0.65, 1.0, 0.25), 1)
	if candidate.has("route"):
		_draw_route(candidate.route, Color("#d4b1ff"), 2)
		for blocker in candidate.get("validation", {}).get("blockers", []):
			var point := screen(session.vector(blocker.pos))
			draw_line(point - Vector2(6, 6), point + Vector2(6, 6), Color.SALMON, 2)
			draw_line(point - Vector2(-6, 6), point + Vector2(-6, 6), Color.SALMON, 2)
		for command in candidate.get("commands", []):
			draw_circle(screen(session.vector(command.args.pos)), 14, Color("#d4b1ff"), false, 2)
	if mode == 4:
		var anchor: Vector2 = session.vector(pattern.get("anchor", [0, 0]))
		for region in pattern.get("regions", []):
			var point := screen(anchor + session.vector(region.pos))
			var color := Color("#87d4af") if region.get("role") == "fodder" else Color("#e5aa7b")
			draw_string(ThemeDB.fallback_font, point + Vector2(8, -8), "%s %d–%d" % [region.type, int(region.get("min_count", 1)), int(region.get("max_count", 1))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
			draw_circle(point, maxf(5, float(region.jitter) * zoom), Color(color, 0.08))
			draw_arc(point, maxf(5, float(region.jitter) * zoom), 0, TAU, 40, color, 1.5)
			draw_line(point - Vector2(6, 0), point + Vector2(6, 0), color, 2)
			draw_line(point - Vector2(0, 6), point + Vector2(0, 6), color, 2)
	for blocker in result.get("blockers", []):
		var point := screen(session.vector(blocker.pos))
		draw_line(point - Vector2(8, 8), point + Vector2(8, 8), Color.SALMON, 3)
		draw_line(point - Vector2(-8, 8), point + Vector2(-8, 8), Color.SALMON, 3)
	for event in result.get("events", []):
		if event.has("pos"):
			draw_circle(screen(session.vector(event.pos)), 5, Color.LIGHT_GREEN if event.get("type") == &"kill" else Color.SALMON, false, 2)
	if _range_drag and session.selected >= 0:
		draw_line(screen(run.enemies.table.pos[session.selected]), screen(_ghost), Color.ORANGE, 2)
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
		draw_polyline(pts, Color(color, 0.2), maxf(2, session.run.cfg.ship_radius * 2 * zoom), true)
		draw_polyline(pts, color, width, true)
	for i in pts.size():
		draw_circle(pts[i], 5, color)
		draw_string(ThemeDB.fallback_font, pts[i] + Vector2(7, -7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func _draw_projectiles(p: ProjectileManager) -> void:
	if show_ranges and p.director != null:
		for i in p.hazard_alive.size():
			if p.hazard_alive[i]: _source_line(p, int(p.lab_hazard_group.get(i, 0)), p.hazard_pos[i])
		for i in p.hostile_alive.size():
			if p.hostile_alive[i]: _source_line(p, int(p.lab_hostile_group.get(i, 0)), p.hostile_pos[i])
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

func _source_line(p: ProjectileManager, token: int, at: Vector2) -> void:
	if token == 0 or not p.director.groups.has(token): return
	var group: Dictionary = p.director.groups[token]
	var row: int = session.row_for_id(int(group.id))
	var from := screen(session.run.enemies.table.pos[row] if row >= 0 else group.get("pos", at))
	var to := screen(at)
	if row >= 0:
		draw_line(from, to, Color(0.94, 0.69, 0.4, 0.3), 1)
	else:
		draw_dashed_line(from, to, Color(0.94, 0.69, 0.4, 0.3), 1, 6)
		draw_circle(from, 5, Color.ORANGE, false, 1)
		draw_string(ThemeDB.fallback_font, from + Vector2(7, -7), "%s #%d %s" % [String(group.get("type", "")), int(group.id), tr("lab.status_residue")], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.ORANGE)
	var direction := (to - from).normalized()
	draw_line(to, to - direction.rotated(0.5) * 7, Color.ORANGE, 1)
	draw_line(to, to - direction.rotated(-0.5) * 7, Color.ORANGE, 1)

func _nearest_route_point(at: Vector2) -> int:
	for i in route.size():
		if screen(route[i]).distance_to(at) < 16: return i
	return -1

func cancel_gesture() -> void:
	_range_drag = false
	_dragging = false
	_drag_point = -1
	_drag_route = false
	_region = -1
	_pan = false

static func range_parameter(definition: Resource) -> String:
	if definition == null: return ""
	for key in ["beam_len", "wave_radius", "blast_radius", "range", "reach", "stream_len", "wall_len", "neck_rest"]:
		if definition.params.has(key): return key
	return ""

func _remember_route() -> void:
	route_undo.append(route.duplicate())
	if route_undo.size() > 50: route_undo.pop_front()
	route_redo.clear()

func clear_route() -> void:
	_remember_route()
	route.clear()
	result.clear()
	route_edited.emit()
	queue_redraw()

func undo_route(redo := false) -> void:
	var source := route_redo if redo else route_undo
	var target := route_undo if redo else route_redo
	if source.is_empty(): return
	target.append(route.duplicate())
	route = source.pop_back()
	result.clear()
	route_edited.emit()
	queue_redraw()
