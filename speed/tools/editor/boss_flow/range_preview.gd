@tool
extends Control
var gate: Dictionary = {}
var layers: Array = []
var coverage_mode := false
var gaps := PackedVector2Array()
var radius := 1800.0
var attack := {}
var arcs: Array = []
## true では発動条件（左）と攻撃範囲（右）を間を空けて並べる。false では1枚に重ねる。
var split := false
## 並べるときの2枚の図の間
const SPLIT_GAP := 24.0
const GATE_COLOR := Color(0.2, 0.65, 0.9)
const ATTACK_COLOR := Color(1.0, 0.65, 0.15)

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
	elif adapter == "monoceros":
		attack = _monoceros_attack(move.technique, p)
	else:
		attack = {"length": p.get("reach", p.get("distance", 180.0)), "width": 30.0, "angle": 180.0 if move.technique == &"kick" else 0.0}
	queue_redraw()

## 一角獣の角・蹄の判定が通る範囲。from〜to は本体の中心からの距離、angle と half_angle は度。
static func _monoceros_attack(technique: StringName, p: Dictionary) -> Dictionary:
	var def: Resource = load("res://data/bosses/monoceros.tres")
	var horn := float(def.radius) * float(def.params.horn_length_ratio)
	var root := float(def.radius) * 0.65
	var width := float(def.params.horn_width)
	match technique:
		&"sweep":
			return {"from": root, "to": horn, "angle": 0.0, "half_angle": rad_to_deg(float(p.get("arc", 0.0))) * 0.5, "width": width, "length": horn}
		&"kick":
			return {"from": root, "to": float(p.get("reach", horn)), "angle": 180.0, "width": width, "length": float(p.get("reach", horn))}
		&"lance":
			var reach := float(p.get("reach", horn)) + float(p.get("distance", 0.0))
			return {"from": root, "to": reach, "angle": 0.0, "width": width, "length": reach}
	var travel := float(p.get("distance", 0.0)) + horn
	return {"from": root, "to": travel, "angle": 0.0, "width": width, "length": travel}

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
		_boss_marker(center)
		return
	var maximum := maxf(1.0, minf(100000.0, maxf(float(gate.get("max", 600.0)), float(attack.get("length", 0.0)))))
	if split:
		# 2枚は同じ縮尺。左に発動条件、右に攻撃範囲を描く。
		var side := minf(size.y, (size.x - SPLIT_GAP) * 0.5)
		var scaling := side * 0.43 / maximum
		var left := Vector2(size.x * 0.5 - SPLIT_GAP * 0.5 - side * 0.5, size.y * 0.5)
		var right := Vector2(size.x * 0.5 + SPLIT_GAP * 0.5 + side * 0.5, size.y * 0.5)
		_sector(gate, left, scaling)
		_boss_marker(left)
		_caption(left - Vector2(side * 0.5, side * 0.5), "発動条件", GATE_COLOR)
		_attack_area(right, scaling, maximum)
		_boss_marker(right)
		_caption(right - Vector2(side * 0.5, side * 0.5), "攻撃範囲", ATTACK_COLOR)
		return
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
	_boss_marker(center)

## ボスの仮の姿。尖った先が正面（右）を向く三角形。
func _boss_marker(center: Vector2) -> void:
	var length := clampf(minf(size.x, size.y) * 0.09, 9.0, 18.0)
	var points := PackedVector2Array([center + Vector2(length, 0.0), center + Vector2(-length * 0.7, -length * 0.65), center + Vector2(-length * 0.35, 0.0), center + Vector2(-length * 0.7, length * 0.65)])
	draw_colored_polygon(points, Color(0.95, 0.95, 1.0))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.15, 0.15, 0.2), 1.5)

func _caption(corner: Vector2, text: String, color: Color) -> void:
	var font := get_theme_default_font()
	var font_size := maxi(10, int(get_theme_default_font_size() * 0.75))
	draw_string(font, corner + Vector2(2, font_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## 攻撃範囲を、発動条件の扇と同じ塗りで描く。扇の範囲は扇形、直線の判定は幅を持つ帯にする。
func _attack_area(center: Vector2, scaling: float, maximum: float) -> void:
	if attack.is_empty(): return
	if attack.get("dynamic", false):
		draw_string(get_theme_default_font(), center + Vector2(-30, 4), "配置で変化", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, int(get_theme_default_font_size() * 0.7)), ATTACK_COLOR)
		return
	var fill := Color(ATTACK_COLOR, 0.35)
	if attack.get("targeted", false):
		var at := center + Vector2.from_angle(deg_to_rad(float(gate.get("angle", 0.0)))) * (float(gate.get("min", 0.0)) + maximum) * 0.5 * scaling
		draw_circle(at, maxf(2.0, float(attack.width) * 0.5 * scaling), fill)
		return
	var start := float(attack.get("from", 0.0))
	var finish := float(attack.get("to", attack.get("length", 0.0)))
	var angle := deg_to_rad(float(attack.get("angle", 0.0)))
	var half := deg_to_rad(float(attack.get("half_angle", 0.0)))
	var width := float(attack.get("width", 30.0))
	if half > 0.0:
		# 扇の外周は判定の幅の半分だけ外へ広げる。
		var outer := (finish + width * 0.5) * scaling
		var inner := maxf(0.0, start - width * 0.5) * scaling
		var points := PackedVector2Array()
		for i in 49: points.append(center + Vector2.from_angle(angle - half + half * 2.0 * i / 48.0) * outer)
		for i in 49: points.append(center + Vector2.from_angle(angle + half - half * 2.0 * i / 48.0) * inner)
		draw_colored_polygon(points, fill)
		return
	var axis := Vector2.from_angle(angle)
	var side := axis.orthogonal() * maxf(1.0, width * 0.5 * scaling)
	var a := center + axis * start * scaling
	var b := center + axis * finish * scaling
	draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), fill)

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
