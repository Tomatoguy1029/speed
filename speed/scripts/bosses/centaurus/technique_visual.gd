## 矢の予告と降下。ボス中心と正面+Xに合わせ、雨だけをワールド座標で描く。
extends Node2D
@export var technique_id: StringName
@export var pixel_size := 3.0
var actor: CentaurusBoss
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const LIGHT_ARROW := preload("res://scripts/render/attacks/light_arrow.gd")
const RAIN_ANGLE := PI * 0.5 - 0.35
func update_technique() -> void:
	if technique_id == &"rain":
		top_level = true
		global_transform = Transform2D.IDENTITY
func draw_fraction() -> float:
	return actor.table.charge[actor.body] if actor.mode == &"windup" else 0.0
func _draw() -> void:
	if actor == null or not actor.has_body() or actor.technique != technique_id: return
	if technique_id == &"rain":
		_draw_rain()
		return
	var r := actor.table.r[actor.body]
	# 照準線は本体の縮尺と別に、実際の射程で描く。
	if actor.mode == &"windup" and actor.technique == &"power_shot":
		var reach := float(actor.rule().get("travel", 1600.0))
		var width := float(actor.rule().get("radius", 30.0)) * 2.0
		var from := Vector2(r * float(actor.def.params.bow_reach), 0.0)
		var color := DANGER if actor.alerting else WARNING
		color.a = 0.85 if actor.alerting else 0.35 + draw_fraction() * 0.35
		for offset in actor.power_offsets():
			draw_line(from, from + Vector2.from_angle(offset) * reach, color, width if actor.alerting else pixel_size * 2.0)
## まだ矢が着いていない帯を、円が走った跡として描く。矢は着弾点の上から降り、透明から不透明へ変わる。
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
	var fade := maxf(float(r.fade), 0.001)
	var linger := float(r.linger)
	var down := Vector2.from_angle(RAIN_ANGLE)
	for arrow in actor.rain_arrows:
		var t := actor.clock - arrow.z
		if t < 0.0: continue
		var f := clampf(t / fall, 0.0, 1.0)
		# 落ちるほど速く降り、不透明へはキリっと切り替わる。
		var at := Vector2(arrow.x, arrow.y) - down * float(r.drop_height) * (1.0 - f * f)
		var opacity := pow(clampf(t / fade, 0.0, 1.0), 3.0)
		if t > fall + linger: opacity *= clampf(1.0 - (t - fall - linger) / CentaurusBoss.RAIN_OUT, 0.0, 1.0)
		LIGHT_ARROW.draw_arrow(self, at, RAIN_ANGLE, 8.0, false, actor.clock, opacity)
