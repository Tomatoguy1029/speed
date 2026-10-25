@tool
extends Control
var gate: Dictionary = {}
var layers: Array = []
var coverage_mode := false
var gaps := PackedVector2Array()
var radius := 1800.0
var attack := {}
var arcs: Array = []

func set_attack(move: Resource, adapter: String) -> void:
	var p: Dictionary = move.parameters
	arcs=p.get("arcs",[])
	if adapter == "hydra" or move.get("head_kind") != null:
		p = load("res://data/bosses/hydra.tres").params.merged(p, true)
		var reach: Dictionary = preload("res://scripts/bosses/hydra_normals.gd").reach(move.technique, p)
		attack = {"length": reach.get("max", INF), "width": p.get("beam_width", p.get("bite_radius", 60.0)), "angle": 0.0}
		if not is_finite(float(attack.length)): attack = {"dynamic": true, "length": 0.0}
		if move.technique in [&"bite_thrust", &"thunder_headbutt"]: attack = {"targeted": true, "length": 0.0, "width": float(p.bite_radius)}
		if move.technique == &"thunder_drop": attack = {"targeted": true, "length": 0.0, "width": float(p.thunder_radius) * 2.0, "circle": true}
	else:
		attack = {"length": p.get("reach", p.get("distance", 180.0)), "width": 30.0, "angle": 180.0 if move.technique == &"kick" else 0.0}
	queue_redraw()

static func analyze(conditions: Array, limit: float) -> Dictionary:
	var missing := PackedVector2Array()
	for ring in 16:
		for angle in 64:
			var point := Vector2.from_angle(TAU * angle / 64.0) * limit * (ring + 0.5) / 16.0
			var found := false
			for condition in conditions:
				if covers(condition, point):
					found = true
					break
			if not found: missing.append(point)
	return {"holes": missing.size(), "points": missing}

static func covers(condition: Dictionary, point: Vector2) -> bool:
	var range_test := preload("res://scripts/bosses/flow/range_condition.gd")
	return range_test.allows_snapshot(condition, point) if condition.has("gate") else range_test.allows(condition, point - condition.get("offset", Vector2.ZERO))
func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO: custom_minimum_size = Vector2(180, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var center := size * 0.5
	if coverage_mode:
		var scaling := minf(size.x, size.y) * 0.43 / maxf(1.0, radius)
		for index in layers.size():
			var color := Color.from_hsv(fmod(index * 0.618, 1.0), 0.5, 0.9, 0.25)
			for ring in 16:
				for angle in 64:
					var direction := TAU * angle / 64.0
					if not covers(layers[index], Vector2.from_angle(direction) * radius * (ring + 0.5) / 16.0): continue
					var cell := PackedVector2Array()
					for corner in [Vector2(ring, -0.5), Vector2(ring + 1, -0.5), Vector2(ring + 1, 0.5), Vector2(ring, 0.5)]:
						if ring == 0 and cell.size() == 3: continue
						cell.append(center + Vector2.from_angle(direction + TAU * corner.y / 64.0) * radius * corner.x / 16.0 * scaling)
					draw_colored_polygon(cell, color)
		for point in gaps: draw_circle(center + point * scaling, 1.5, Color(0.95, 0.55, 0.2, 0.7))
		draw_circle(center, 5, Color(0.9, 0.5, 0.25))
		return
	var maximum := maxf(1.0, minf(100000.0, maxf(float(gate.get("max", 600.0)), float(attack.get("length", 0.0)))))
	var scale_factor := minf(size.x, size.y) * 0.43 / maximum
	_sector(gate, center, scale_factor)
	for arc: DracoExhaleArc in arcs:
		var origin: Vector2=center+arc.offset*scale_factor
		var angle := deg_to_rad(arc.angle_degrees)
		var spread := deg_to_rad(arc.spread_degrees)
		draw_arc(origin,arc.radius*scale_factor,angle-spread,angle+spread,32,Color(0.75,0.65,1.0,0.8),2.0)
		for j in arc.count:
			var direction := Vector2.from_angle(angle+lerpf(-spread,spread,j/maxf(1.0,arc.count-1.0)))
			draw_circle(origin+direction*arc.radius*scale_factor,2.0,Color("#c6bdff"))
	if not attack.is_empty() and not attack.get("dynamic", false):
		var length := float(attack.get("length", 0.0))
		if attack.get("targeted", false): length = (float(gate.get("min", 0.0)) + maximum) * 0.5
		var end := center + Vector2.from_angle(deg_to_rad(float(attack.get("angle", gate.get("angle", 0.0))))) * length * scale_factor
		if attack.get("circle", false): draw_circle(end, maxf(2.0, float(attack.width) * 0.5 * scale_factor), Color(1.0, 0.65, 0.15, 0.8), false, 2.0)
		else: draw_line(center, end, Color(1.0, 0.65, 0.15, 0.9), maxf(2.0, float(attack.get("width", 30.0)) * scale_factor))
	elif attack.get("dynamic", false):
		draw_string(get_theme_default_font(), Vector2(4, size.y - 3), "配置で変化", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, int(get_theme_default_font_size() * 0.7)), Color(1.0, 0.65, 0.15))
	draw_circle(center, 5, Color(0.9, 0.5, 0.25))
	draw_line(center, center + Vector2(18, 0), Color(0.9, 0.5, 0.25), 2)

func _sector(value: Dictionary, center: Vector2, scale_factor: float) -> void:
	var maximum := float(value.get("max", 600.0))
	var points := PackedVector2Array()
	var half := deg_to_rad(float(value.get("half_angle", 180.0)))
	var angle := deg_to_rad(float(value.get("angle", 0.0)))
	var minimum := float(value.get("min", 0.0))
	if maximum < minimum: return
	if maximum == minimum or half <= 0.0:
		draw_line(center + Vector2.from_angle(angle) * minimum * scale_factor, center + Vector2.from_angle(angle) * maximum * scale_factor, Color(0.2, 0.65, 0.9), 1.0)
		return
	for distance in [maximum, float(value.get("min", 0.0))]:
		for i in 49:
			var k := i if distance == maximum else 48 - i
			points.append(center + Vector2.from_angle(angle - half + half * 2.0 * k / 48.0) * distance * scale_factor)
	draw_colored_polygon(points, Color(0.2, 0.65, 0.9, 0.25))
