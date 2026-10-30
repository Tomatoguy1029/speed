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
		var mouth := actor.power_aim_origin()
		var from := to_local(mouth)
		var color := DANGER if actor.alerting else WARNING
		for offset in actor.power_offsets():
			var end := to_local(mouth + Vector2.from_angle(actor.power_aim_angle() + offset) * reach)
			draw_line(from, end, Color(color, 0.12), 8.0)
			draw_line(from, end, Color(color, 0.95 if actor.alerting else 0.6), 2.0)
			draw_line(from, end, Color(1.0, 0.75 if actor.alerting else 0.95, 0.6, 0.8), 0.8)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (r / 90.0))
	var pull := Vector2(62.0 + cos(1.1) * 26.0 - draw_fraction() * 34.0, 0.0)
	if actor.mode == &"windup":
		var glow := DANGER if actor.alerting else WARNING
		var length := 40.0 if actor._runner_for().kind() == &"power_shot" else 26.0
		draw_line(pull, pull + Vector2(length + 30.0, 0.0), glow, pixel_size * (3.0 if actor._runner_for().kind() == &"power_shot" else 1.5))
	draw_set_transform(Vector2.ZERO)

## 着弾予定の範囲へ光の粉を落とす。矢は画面上端の外から降る。
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
		# 帯の輪郭を描かず、これから着弾する範囲へ光の筋をまばらに落とす。
		var spacing := maxf(70.0, radius)
		var sample_index := ceili(landed / spacing)
		while sample_index * spacing <= head:
			var distance := sample_index * spacing
			var age := actor.clock - float(trace.t0) - distance / speed
			RAIN_VISUAL.draw_powder(self, actor.trace_point(trace, distance), radius, age, clampf(age / 0.12, 0.0, 1.0), float(trace.t0) + sample_index)
			sample_index += 1
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
		RAIN_VISUAL.draw_rain_arrow(self, actor, at, angle, opacity)
		if t >= fall: RAIN_VISUAL.draw_powder(self, target, 12.0, t, opacity * 0.4, arrow.z)
