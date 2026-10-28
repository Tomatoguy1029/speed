## 世界時間で頭から胴体・尾へ旋回を伝え、攻撃の向きは戦闘方向へ同期する。
extends Node2D
@export var pixel_size := 3.0
@export_group("Turning")
@export_range(0.01, 0.5) var body_follow_seconds := 0.16
@export_range(0.01, 0.5) var neck_follow_seconds := 0.075
@export_range(0.01, 0.5) var head_follow_seconds := 0.035
@export_range(0.01, 0.5) var tail_follow_seconds := 0.14
@export_range(0.01, 0.5) var flame_follow_seconds := 0.22
@export_range(0.0, 45.0) var body_lag_degrees := 24.0
@export_range(0.0, 45.0) var head_turn_degrees := 32.0
@export_range(0.0, 30.0) var tail_turn_degrees := 18.0
var lance_afterglow := 0.0
var lance_points := PackedVector2Array()
const PartsVisual = preload("res://scripts/bosses/monoceros_parts.gd")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const ENERGY := Color("#9fe8ff")
var actor: MonocerosBoss
var hit := 0.0
var _body_facing := 0.0
var _neck_facing := 0.0
var _head_facing := 0.0
var _tail_facing := 0.0
var _flame_facing := 0.0
@onready var parts: PartsVisual = $Parts

func bind_monoceros(owner_actor: MonocerosBoss) -> void:
	actor = owner_actor
	_body_facing = actor.table.facing[actor.body]
	_neck_facing = _body_facing
	_head_facing = _body_facing
	_tail_facing = _body_facing
	_flame_facing = _body_facing
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	z_index = 1
	_sync_parts(0.0)

func _event(event: Dictionary) -> void:
	if event.cue == &"recovery_started" and event.technique == &"lance":
		lance_points = actor.horn_points()
		lance_afterglow = float(actor.def.params.get("lance_hold", 0.12)) + float(actor.def.params.get("lance_fade", 0.45))
	if event.cue == &"hit": hit = 0.18
	queue_redraw()

func _advance(dt: float) -> void:
	lance_afterglow = maxf(0.0, lance_afterglow - dt)
	hit = maxf(0.0, hit - dt)
	_sync_parts(dt)
	queue_redraw()

func _sync_parts(dt: float) -> void:
	if actor == null or not actor.has_body(): return
	var k := actor.table.r[actor.body] / 96.0
	parts.scale = Vector2.ONE * k
	parts.apply_appearance(actor.def.part_appearance)
	_update_turn(dt)
	# 胴体中心を固定して見た目だけ遅らせる。移動・判定・予告線は役者の方向を使う。
	parts.rotation = -PI * 0.5 + angle_difference(actor.table.facing[actor.body], _body_facing)
	parts.position = -Vector2(0, -37).rotated(parts.rotation) * k
	parts.get_node("Head").rotation = angle_difference(_body_facing, _neck_facing)
	parts.get_node("Head/Lower").rotation = angle_difference(_neck_facing, _head_facing)
	var tail := parts.get_node("TailBooster") as Node2D
	tail.rotation = angle_difference(_body_facing, _tail_facing)
	# 根元を支点にするが、既存の編集キーと保存済み配置は動かさない。
	var tail_pivot := Vector2(0, 26)
	tail.position = parts.rest_position("TailBooster") + tail_pivot - tail_pivot.rotated(tail.rotation)
	parts.modulate = Color(1.35, 1.35, 1.35) if hit > 0.0 else Color.WHITE
	var moving := actor.table.vel[actor.body].length_squared() > 25.0
	parts.advance_gait(dt, moving and actor.mode not in [&"windup", &"stuck", &"phase", &"final", &"defeated"])
	var sword := parts.get_node("Head/Lower/SwordGlow") as Polygon2D
	sword.visible = actor.phase == 2
	sword.polygon = PackedVector2Array([Vector2(-4, 105), Vector2(-9, 111), Vector2(0, actor.horn_length() / k - 46), Vector2(9, 111), Vector2(4, 105)])
	parts.get_node("Head/Lower/SwordGlow/Guard").visible = sword.visible

func _update_turn(dt: float) -> void:
	if dt <= 0.0: return
	var target := actor.table.facing[actor.body]
	var attacking := actor.mode == &"active" or actor.mode == &"stuck" or (actor.mode == &"windup" and actor.locked)
	var sweeping := actor.technique == &"sweep" and actor.mode in [&"windup", &"active"]
	_body_facing = _follow_angle(_body_facing, target, dt, body_follow_seconds * (0.3 if attacking else 1.0))
	_body_facing = _limit_angle(target, _body_facing, body_lag_degrees)
	if attacking or sweeping:
		# 角を使う技は見た目の遅れを頭に残さず、判定と同じ方向へ向ける。
		var points := actor.horn_points()
		_neck_facing = (points[1] - points[0]).angle() if actor.technique != &"kick" else target
		_head_facing = _neck_facing
	else:
		_neck_facing = _follow_angle(_neck_facing, target, dt, neck_follow_seconds)
		_neck_facing = _limit_angle(_body_facing, _neck_facing, head_turn_degrees * 0.55)
		_head_facing = _follow_angle(_head_facing, target, dt, head_follow_seconds)
		_head_facing = _limit_angle(_body_facing, _head_facing, head_turn_degrees)
		_head_facing = _limit_angle(_neck_facing, _head_facing, head_turn_degrees * 0.55)
	_tail_facing = _follow_angle(_tail_facing, _body_facing, dt, tail_follow_seconds)
	_tail_facing = _limit_angle(_body_facing, _tail_facing, tail_turn_degrees)
	_flame_facing = _follow_angle(_flame_facing, _tail_facing, dt, flame_follow_seconds)
	_flame_facing = _limit_angle(_tail_facing, _flame_facing, tail_turn_degrees * 1.5)

func _follow_angle(current: float, target: float, dt: float, seconds: float) -> float:
	return lerp_angle(current, target, 1.0 - exp(-dt / maxf(seconds, 0.001)))

func _limit_angle(center: float, value: float, degrees: float) -> float:
	return center + clampf(angle_difference(center, value), -deg_to_rad(degrees), deg_to_rad(degrees))

func _body_point(world_point: Vector2) -> Vector2:
	# 旋回したフレームも、役者ノードの描画更新を待たず戦闘方向を使う。
	return (world_point - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body])

func booster_strength() -> float:
	if actor == null or actor.mode == &"defeated": return 0.0
	if actor.mode == &"entrance": return 2.0
	return 2.5 if actor.mode == &"active" and actor.technique in [&"charge", &"return_charge"] else 0.55

func _booster() -> void:
	var strength := booster_strength()
	if strength <= 0.0: return
	var nozzle := parts.get_node("TailBooster/Sprite/booster") as Node2D
	var anchor := to_local(nozzle.to_global(Vector2(37, 0))) / (actor.table.r[actor.body] / 96.0)
	var length := (50.0 + sin(actor.clock * 27.0) * 9.0) * strength
	var root_angle := _tail_facing - actor.table.facing[actor.body] + PI
	var tip_angle := _flame_facing - actor.table.facing[actor.body] + PI
	for layer in 3:
		var factor := 1.0 - float(layer) * 0.24
		var center := anchor
		for j in 12:
			var t := float(j) / 12.0
			var height := maxf(pixel_size, (24.0 - t * 22.0) * factor)
			var direction := Vector2.from_angle(lerp_angle(root_angle, tip_angle, t * t))
			var next := center + direction * length * factor / 12.0
			var side := direction.orthogonal()
			var wobble := side * sin(actor.clock * 20.0 - t * 8.0) * 7.0 * t * factor
			var thickness := side.abs() * height
			var at := (center.min(next) + wobble - thickness * 0.5).snapped(Vector2.ONE * pixel_size)
			var size := ((next - center).abs() + thickness).snapped(Vector2.ONE * pixel_size).max(Vector2.ONE * pixel_size)
			draw_rect(Rect2(at, size), [Color("#245c96"), Color("#61c9ff"), Color("#e0fbff")][layer])
			center = next

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (actor.table.r[actor.body] / 96.0))
	_booster()
	# 正確な攻撃線をワールド→役者座標へ戻す。警告と攻撃の幅は共通。
	draw_set_transform(Vector2.ZERO)
	_lance_remnants()
	if actor.mode in [&"windup", &"active"]:
		var color := DANGER if actor.mode==&"active" else WARNING
		var width := float(actor.def.params.horn_width)
		if actor.technique==&"sweep" and actor.mode==&"windup":
			var arc := PackedVector2Array()
			for j in 25:
				var points := actor.horn_points(float(j)/24.0)
				arc.append(_body_point(points[-1]))
			draw_polyline(arc, Color(color,0.65), 7.0, false)
			for f in [0.0,1.0]:
				var edge := actor.horn_points(f)
				draw_line(_body_point(edge[0]),_body_point(edge[1]),Color(color,0.5),4.0,false)
		var points := actor.horn_points()
		var a := _body_point(points[0])
		var b := _body_point(points[1])
		if actor.technique in [&"charge", &"return_charge"] and actor.mode==&"windup":
			var end := actor.table.pos[actor.body]+actor.direction*float(actor.rule().distance)
			# 薄い進路は移動方向、太い角の光は実際の攻撃形状を示す。
			draw_line(a,_body_point(end),Color(color,0.3),6.0,false)
		draw_line(a,b,Color(color,0.3),width,false)
		draw_line(a,b, ENERGY if actor.technique==&"lance" else color, 7.0 if actor.mode==&"windup" else 13.0,false)
		if actor.locked:
			draw_rect(Rect2(b-Vector2(6,6),Vector2(12,12)),color)
	if actor.mode==&"stuck":
		var at := _body_point(actor.table.pos[actor.body]+actor.direction*actor.horn_length())
		for j in 3:
			draw_line(at+Vector2(-15,j*10-10),at+Vector2(15,j*10-10),WARNING,3.0,false)

func _lance_remnants() -> void:
	if lance_afterglow <= 0.0 or lance_points.size() != 2: return
	var fade := maxf(0.01, float(actor.def.params.get("lance_fade", 0.45)))
	var a := _body_point(lance_points[0])
	var b := _body_point(lance_points[1])
	if lance_afterglow > fade:
		draw_line(a, b, Color("#eaffff"), 13.0, false)
		return
	var progress := 1.0 - lance_afterglow / fade
	var side := (b-a).normalized().orthogonal()
	for j in 32:
		var t := float(j) / 31.0
		var spread := sin(float(j) * 17.3) * 90.0 * progress
		var at := (a.lerp(b,t) + side * spread).snapped(Vector2.ONE * pixel_size)
		draw_rect(Rect2(at,Vector2.ONE * (6.0 - progress * 3.0)), Color(ENERGY, 1.0-progress))
