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
	elif adapter == "draco":
		attack = _draco_attack(move.technique, p)
	elif adapter == "centaurus":
		attack = _centaurus_attack(move.technique, p)
	elif adapter == "canis_major":
		attack = _canis_attack(move.technique, p)
	else:
		attack = {"length": p.get("reach", p.get("distance", 180.0)), "width": 30.0, "angle": 180.0 if move.technique == &"kick" else 0.0}
	queue_redraw()

## りゅう座の判定が通る範囲。ボスの中心から正面（+X）を基準に、狙った自機の距離 D に合わせて形を作る。
static func _draco_attack(technique: StringName, p: Dictionary) -> Dictionary:
	var def: Resource = load("res://data/bosses/draco.tres")
	var scale := float(def.params.get("head_scale", 1.35))
	var head := 105.0 * scale
	var half := float(p.get("width", 45.0))
	match technique:
		&"bite":
			var reach := float(p.get("reach", 0.0)) + head
			return {"from": 0.0, "to": reach, "angle": 0.0, "width": half * 2.0, "length": reach}
		&"breath":
			var reach := float(p.get("reach", 0.0)) + head
			return {"from": 0.0, "to": reach, "angle": 0.0, "half_angle": rad_to_deg(float(p.get("sweep", 0.0)) + float(p.get("half_angle", 0.0))), "width": 0.0, "length": reach}
		&"tail_sweep":
			var shape: PackedVector2Array = preload("res://scripts/bosses/draco_tail_area.gd").area(Vector2.ZERO, 0.0, float(p.get("reach", 0.0)), float(p.get("half_angle", 1.3)))
			return {"polygon": shape, "length": float(p.get("reach", 0.0))}
		&"tail_slam":
			return {"targeted": true, "circle": true, "width": float(p.get("radius", 110.0)) * 2.0, "max_target": float(p.get("reach", 0.0)), "length": 0.0}
		&"charge":
			var overshoot := float(p.get("overshoot", 0.0))
			return {"length": 0.0, "builder": func(d: float) -> Array: return [_band(Vector2.ZERO, Vector2(d + overshoot, 0.0), half)]}
		&"leap":
			return {"length": 0.0, "builder": func(d: float) -> Array: return [_band(Vector2(-70.0 + head, 0.0), Vector2(d, 0.0), half)]}
		&"clones":
			return {"length": 0.0, "builder": func(d: float) -> Array: return [_band(Vector2.ZERO, Vector2(d, 0.0), half)]}
		&"rifts":
			var scratch := float(p.get("scratch_width", 30.0)) * 0.5
			return {"length": 0.0, "builder": func(d: float) -> Array:
				var shapes := []
				for side in [-1.0, 1.0]:
					for j in 3:
						var stripe: float = side * 135.0 + (j - 1) * 70.0
						shapes.append(_band(Vector2(125.0 * scale, stripe), Vector2(d + 125.0, stripe + side * 60.0), scratch))
				return shapes}
		&"picaro_wall":
			var radius := float(p.get("radius", 85.0))
			return {"length": 0.0, "builder": func(d: float) -> Array: return [_circle(Vector2(d, 0.0), radius)]}
		&"spiral":
			# 自機を中心に画面の長辺の半分ほどで2周巻く。外周の輪を胴の太さで示す。
			var ring := float(p.get("radius_factor", 0.8)) * 960.0
			var thickness := float(p.get("width", 154.0)) * 0.5
			return {"length": 0.0, "builder": func(d: float) -> Array:
				var shapes := []
				for j in 48: shapes.append(_band(Vector2(d, 0.0) + Vector2.from_angle(TAU * j / 48.0) * ring, Vector2(d, 0.0) + Vector2.from_angle(TAU * (j + 1) / 48.0) * ring, thickness))
				return shapes}
		&"inhale":
			return {"polygon": _circle(Vector2(head, 0.0), float(p.get("pull_range", 0.0))), "length": head + float(p.get("pull_range", 0.0))}
		&"meteor":
			var shapes := []
			var count := int(p.get("rocks", 3))
			for j in count:
				var side := float(j) - float(count - 1) * 0.5
				shapes.append(_circle(Vector2(head + float(p.get("rock_distance", 0.0)), side * float(p.get("rock_spacing", 0.0))), float(p.get("rock_radius", 78.0))))
			return {"polygons": shapes, "length": head + float(p.get("rock_distance", 0.0)) + float(p.get("rock_radius", 78.0))}
		&"star_fan":
			var shapes := []
			var arc := float(p.get("arc", 0.0))
			var count := int(p.get("count", 1))
			for j in count:
				var direction := Vector2.from_angle(lerpf(-arc, arc, float(j) / maxf(1.0, float(count) - 1.0)))
				shapes.append(_band(direction * float(p.get("radius", 0.0)), direction * float(p.get("reach", 0.0)), maxf(4.0, float(p.get("width", 9.0)))))
			return {"polygons": shapes, "length": float(p.get("reach", 0.0))}
	return {"dynamic": true, "length": 0.0}

## a から b への、半幅 half の帯。
static func _band(a: Vector2, b: Vector2, half: float) -> PackedVector2Array:
	var side := (b - a).normalized().orthogonal() * half
	return PackedVector2Array([a + side, b + side, b - side, a - side])

static func _circle(at: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for j in 48: points.append(at + Vector2.from_angle(TAU * j / 48.0) * radius)
	return points

## ケンタウルス座の判定が通る範囲。矢は弓から射程まで飛ぶ帯、背後攻撃は背中の後ろの円。
static func _centaurus_attack(technique: StringName, p: Dictionary) -> Dictionary:
	var def: Resource = load("res://data/bosses/centaurus.tres")
	match technique:
		&"volley", &"power_shot":
			var start := float(def.radius) * float(def.params.get("bow_reach", 0.9))
			var reach := start + float(p.get("travel", 0.0))
			return {"from": start, "to": reach, "angle": 0.0, "width": float(p.get("radius", 12.0)) * 2.0, "length": reach}
		&"rear_attack":
			var circle := PackedVector2Array()
			var at := Vector2(-float(p.get("back_offset", 0.0)), 0.0)
			for j in 48: circle.append(at + Vector2.from_angle(TAU * j / 48.0) * float(p.get("range_radius", 0.0)))
			return {"polygon": circle, "length": float(p.get("back_offset", 0.0)) + float(p.get("range_radius", 0.0))}
		&"rain":
			# 自機の先 forward から自機を通って後ろへ、矢を落とす円が軌跡を走る。
			var forward := float(p.get("forward", 0.0))
			var trace := float(p.get("trace_length", 0.0))
			var radius := float(p.get("circle_radius", 100.0))
			return {"length": 0.0, "builder": func(d: float) -> Array: return [_band(Vector2(d + forward, 0.0), Vector2(d + forward - trace, 0.0), radius)]}
	return {"dynamic": true, "length": 0.0}

## おおいぬ座の判定が通る範囲。飛びかかりは狙った位置の先まで体が通る帯、シリウスは口からの光の帯。
static func _canis_attack(technique: StringName, p: Dictionary) -> Dictionary:
	var def: Resource = load("res://data/bosses/canis_major.tres")
	match technique:
		&"pounce":
			return {"to_target": true, "extra": float(p.get("overshoot", 0.0)), "angle": 0.0, "width": float(def.radius) * 2.0, "length": 0.0}
		&"sirius":
			return {"from": 0.0, "to": float(p.get("beam_length", 0.0)), "angle": 0.0, "width": float(p.get("beam_width", 50.0)), "length": float(p.get("beam_length", 0.0))}
		&"command":
			# 率いる群れが自機へ飛び出す。群れの通り道を本体から自機の先までの帯で示す。
			var lunge := float(p.get("lunge_speed", 0.0)) * float(p.get("lunge_time", 0.0))
			return {"length": 0.0, "builder": func(d: float) -> Array: return [_band(Vector2.ZERO, Vector2(maxf(d, lunge), 0.0), float(def.radius) * 1.5)]}
		&"howl":
			# 自機を囲む猟犬の輪が ring_radius から ring_close まで縮む。縮みきった輪を示す。
			var ring := float(p.get("ring_close", 0.0))
			var outer := float(p.get("ring_radius", 0.0))
			return {"length": 0.0, "builder": func(d: float) -> Array:
				var shapes := []
				for j in 48:
					shapes.append(_band(Vector2(d, 0.0) + Vector2.from_angle(TAU * j / 48.0) * ring, Vector2(d, 0.0) + Vector2.from_angle(TAU * (j + 1) / 48.0) * ring, 40.0))
					shapes.append(_band(Vector2(d, 0.0) + Vector2.from_angle(TAU * j / 48.0) * outer, Vector2(d, 0.0) + Vector2.from_angle(TAU * (j + 1) / 48.0) * outer, 6.0))
				return shapes}
	return {"dynamic": true, "length": 0.0}

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
	var maximum := maxf(1.0, minf(100000.0, maxf(float(gate.get("max", 600.0)), _attack_extent())))
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
	_attack_area(center, scale_factor, maximum)
	_boss_marker(center)

## 攻撃範囲がボスの中心から届く一番遠い距離。縮尺を決めるのに使う。
func _attack_extent() -> float:
	var far := float(attack.get("length", 0.0))
	var shapes: Array = attack.get("polygons", [])
	if attack.has("polygon"): shapes = [attack.polygon]
	if attack.has("builder"): shapes = attack.builder.call((float(gate.get("min", 0.0)) + minf(100000.0, float(gate.get("max", 600.0)))) * 0.5)
	for points: PackedVector2Array in shapes:
		for point in points: far = maxf(far, point.length())
	return far

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
	# 自機を狙う技は、発動条件の距離の真ん中にいる自機を狙ったときの形で描く。
	var target_distance := (float(gate.get("min", 0.0)) + minf(maximum, float(gate.get("max", maximum)))) * 0.5
	if attack.get("targeted", false):
		var distance := minf(target_distance, float(attack.get("max_target", INF)))
		var at := center + Vector2.from_angle(deg_to_rad(float(gate.get("angle", 0.0)))) * distance * scaling
		draw_circle(at, maxf(2.0, float(attack.width) * 0.5 * scaling), fill)
		return
	var shapes: Array = attack.get("polygons", [])
	if attack.has("polygon"): shapes = [attack.polygon]
	if attack.has("builder"): shapes = attack.builder.call(target_distance)
	if not shapes.is_empty():
		for points: PackedVector2Array in shapes:
			var shape := PackedVector2Array()
			for point: Vector2 in points: shape.append(center + point * scaling)
			draw_colored_polygon(shape, fill)
		return
	var start := float(attack.get("from", 0.0))
	var finish := target_distance + float(attack.get("extra", 0.0)) if attack.get("to_target", false) else float(attack.get("to", attack.get("length", 0.0)))
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
