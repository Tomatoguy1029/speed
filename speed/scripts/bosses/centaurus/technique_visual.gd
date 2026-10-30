## 矢の予告と降下。ボス中心と正面+Xに合わせ、雨だけをワールド座標で描く。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
var visual_kind: StringName
@export var pixel_size := 3.0
var actor: CentaurusBoss
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const LIGHT_ARROW := preload("res://scripts/render/attacks/light_arrow.gd")
const RAIN_VISUAL := preload("res://scripts/bosses/centaurus/additional_technique_visual.gd")
func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
func update_technique() -> void:
	if visual_kind == &"rain":
		top_level = true
		global_transform = Transform2D.IDENTITY
func draw_fraction() -> float:
	return actor.table.charge[actor.body] if actor.mode == &"windup" else 0.0
func _draw() -> void:
	if actor == null or not actor.has_body() or actor.technique != technique_id: return
	if visual_kind == &"rain":
		_draw_rain()
		return
	var r := actor.table.r[actor.body]
	# 照準線は本体の縮尺と別に、実際の射程で描く。
	if actor.mode == &"windup" and visual_kind == &"power_shot":
		var reach := float(actor.rule().get("travel", 1600.0))
		var width := float(actor.rule().get("radius", 30.0)) * 2.0
		var from := Vector2(r * float(actor.def.params.bow_reach), 0.0)
		var color := DANGER if actor.alerting else WARNING
		color.a = 0.85 if actor.alerting else 0.35 + draw_fraction() * 0.35
		for offset in actor.power_offsets():
			draw_line(from, from + Vector2.from_angle(offset) * reach, color, width if actor.alerting else pixel_size * 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (r / 90.0))
	var pull := Vector2(62.0 + cos(1.1) * 26.0 - draw_fraction() * 34.0, 0.0)
	if actor.mode == &"windup":
		var glow := DANGER if actor.alerting else WARNING
		var length := 40.0 if actor._runner_for().kind() == &"power_shot" else 26.0
		draw_line(pull, pull + Vector2(length + 30.0, 0.0), glow, pixel_size * (3.0 if actor._runner_for().kind() == &"power_shot" else 1.5))
	draw_set_transform(Vector2.ZERO)

## まだ矢が着いていない帯を、円が走った跡として描く。矢は画面の上端の外から着弾点へ降る。
func _draw_rain() -> void:
	if actor == null or actor.mode != &"rain": return
	var r := actor.rule()
	var radius := float(r.circle_radius)
	var length := float(r.trace_length)
	var speed := maxf(float(r.trace_speed), 1.0)
	for trace in actor.rain_traces:
		var head := clampf((actor.clock - float(trace.t0)) * speed, 0.0, length)
		var landed := float(trace.landed)
		if head <= landed: continue
		var center := PackedVector2Array()
		var s := landed
		while s < head:
			center.append(actor.trace_point(trace, s))
			s += 14.0
		center.append(actor.trace_point(trace, head))
		if center.size() >= 2:
			draw_polyline(center, Color(WARNING, 0.2), radius * 2.0, true)
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for j in center.size():
				var along := center[mini(j + 1, center.size() - 1)] - center[maxi(j - 1, 0)]
				var normal := along.normalized().orthogonal() * radius
				left.append(center[j] + normal)
				right.append(center[j] - normal)
			draw_polyline(left, Color(WARNING, 0.6), pixel_size, true)
			draw_polyline(right, Color(WARNING, 0.6), pixel_size, true)
		# 走っている円
		if head < length:
			draw_arc(actor.trace_point(trace, head), radius, 0.0, TAU, 32, Color(WARNING, 0.95), pixel_size, true)
	var fall := maxf(float(r.fall), 0.001)
	var linger := float(r.linger)
	for arrow in actor.rain_arrows:
		var t := actor.clock - arrow.z
		if t < 0.0: continue
		var f := clampf(t / fall, 0.0, 1.0)
		# 画面外から加速して降り、判定の発生時刻に着弾する。
		var target := Vector2(arrow.x, arrow.y)
		var origin := RAIN_VISUAL.fall_origin(self, target, float(r.drop_height))
		var angle := (target - origin).angle()
		var at := origin.lerp(target, f * f)
		var opacity := clampf(t / maxf(minf(float(r.fade), 0.05), 0.001), 0.0, 1.0)
		if t > fall + linger: opacity *= clampf(1.0 - (t - fall - linger) / CentaurusBoss.RAIN_OUT, 0.0, 1.0)
		var scene: PackedScene = r.get("shot_visual")
		var shot_tint: Color = EFFECT_SETTINGS.values_for(scene.resource_path).get("effect_tint", Color.WHITE) if scene != null else Color.WHITE
		var library: Resource = actor.ctx.resources.resources.get("res://.content/attack_visuals.res")
		var mesh: Mesh = library.get_meta("looks", {}).get(scene.resource_path, {}).get("Flight") if library != null and scene != null else null
		var sprites: Array = library.get_meta("looks", {}).get(scene.resource_path, {}).get("Flight_sprites", []) if library != null and scene != null else []
		if mesh != null: draw_mesh(mesh, null, Transform2D(angle, Vector2.ONE * 2.5, 0.0, at), Color(1, 1, 1, opacity) * shot_tint)
		for piece: Dictionary in sprites: draw_mesh(piece.mesh, piece.texture, Transform2D(angle, Vector2.ONE * 2.5, 0.0, at), Color(1, 1, 1, opacity) * shot_tint)
		if mesh == null and sprites.is_empty(): LIGHT_ARROW.draw_arrow(self, at, angle, 18.0, false, actor.clock, opacity, shot_tint, 150.0)
