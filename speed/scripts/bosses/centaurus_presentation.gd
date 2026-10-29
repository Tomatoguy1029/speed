## 攻撃の向きと進行を読み、パーツの弓差分を表示する。
extends Node2D
@export var pixel_size := 3.0
const PARTS = preload("res://scenes/bosses/centaurus_parts.tscn")
var _parts: Node2D
var actor: CentaurusBoss
var hit := 0.0
var pulse := 0.0
const STRING := Color("#f4ecd8")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const OPEN := Color("#9fe8ff")
## 背後攻撃の予告で本体に掛ける色
const REAR_GLOW := Color(1.9, 0.35, 0.35)
const LIGHT_ARROW := preload("res://scripts/render/attacks/light_arrow.gd")
## 矢の雨の矢の向き（画面の下向きから少し傾ける）
const RAIN_ANGLE := PI * 0.5 - 0.35
## 矢の雨のトレースと矢を描く層。本体の回転に付いていかないよう、ワールド座標で描く。
var _rain_layer := Node2D.new()

func bind_centaurus(owner_actor: CentaurusBoss) -> void:
	actor = owner_actor
	_parts = PARTS.instantiate()
	_parts.rotation = -PI * 0.5
	add_child(_parts)
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	z_index = 1
	_rain_layer.top_level = true
	_rain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rain_layer.draw.connect(_draw_rain)
	add_child(_rain_layer)

func _event(event: Dictionary) -> void:
	if event.cue == &"released": _parts.release_bow(float(actor.rule().get("interval", 0.4)))
	if event.cue == &"hit": hit = 0.18
	if event.cue in [&"alert", &"released", &"rain_started"]: pulse = 0.3
	queue_redraw()

func _advance(dt: float) -> void:
	hit = maxf(0.0, hit - dt)
	pulse = maxf(0.0, pulse - dt)
	_parts.visible = actor.has_body()
	if actor.has_body():
		_parts.scale = Vector2.ONE * actor.table.r[actor.body] / 135.0
		_parts.set_bow_pose(actor.technique, actor.mode, actor.table.charge[actor.body], dt)
	queue_redraw()
	_rain_layer.queue_redraw()

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
			_rain_layer.draw_polyline(center, Color(WARNING, 0.2), radius * 2.0, true)
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for j in center.size():
				var along := center[mini(j + 1, center.size() - 1)] - center[maxi(j - 1, 0)]
				var normal := along.normalized().orthogonal() * radius
				left.append(center[j] + normal)
				right.append(center[j] - normal)
			_rain_layer.draw_polyline(left, Color(WARNING, 0.6), pixel_size, true)
			_rain_layer.draw_polyline(right, Color(WARNING, 0.6), pixel_size, true)
		# 走っている円
		if head < length:
			_rain_layer.draw_arc(actor.trace_point(trace, head), radius, 0.0, TAU, 32, Color(WARNING, 0.95), pixel_size, true)
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
		LIGHT_ARROW.draw_arrow(_rain_layer, at, RAIN_ANGLE, 8.0, false, actor.clock, opacity)

## 弓を引く割合（0〜1）。
func draw_fraction() -> float:
	if actor.mode == &"windup": return actor.table.charge[actor.body]
	return 0.0

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var r := actor.table.r[actor.body]
	var k := r / 90.0
	# 照準線は本体の縮尺と別に、実際の射程で描く。
	if actor.mode == &"windup" and actor.technique == &"power_shot":
		var reach := float(actor.rule().get("travel", 1600.0))
		var width := float(actor.rule().get("radius", 30.0)) * 2.0
		var from := Vector2(r * float(actor.def.params.bow_reach), 0.0)
		var color := DANGER if actor.alerting else WARNING
		color.a = 0.85 if actor.alerting else 0.35 + draw_fraction() * 0.35
		draw_line(from, from + Vector2(reach, 0.0), color, width if actor.alerting else pixel_size * 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	var tint := Color(1.6, 1.6, 1.6) if hit > 0.0 else Color.WHITE
	# 背後攻撃は、構えの間ボスを赤く明滅させ、当たりが有効な間は赤く光らせ続ける。
	if actor.technique == &"rear_attack" and actor.mode in [&"windup", &"strike"]:
		var blink := 1.0 if actor.mode == &"strike" else 0.5 + 0.5 * sin(actor.clock * TAU * 6.0)
		tint = Color.WHITE.lerp(REAR_GLOW, blink)
	modulate = tint
	# 攻めどき（射終わりの硬直）は縁を光らせる。
	if actor.mode == &"recovery":
		var a := 0.45 + sin(actor.clock * 14.0) * 0.25
		draw_arc(Vector2(-6, 0), 96.0, 0.0, TAU, 32, Color(OPEN, a), pixel_size * 2.0)
	if pulse > 0.0:
		draw_arc(Vector2(62, 0), 30.0 + (0.3 - pulse) * 80.0, 0.0, TAU, 20, Color(STRING, pulse * 2.5), pixel_size)
	draw_set_transform(Vector2.ZERO)
