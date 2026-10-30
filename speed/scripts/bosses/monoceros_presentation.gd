## 世界時間で頭から胴体・尾へ旋回を伝え、攻撃の向きは戦闘方向へ同期する。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var pixel_size := 3.0
@export var booster_length_scale := 1.0
@export var booster_core_color := Color("#e0fbff")
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
const REAR_LEGS := ["RearLeftLeg", "RearRightLeg"]
## 後ろ蹴りで畳んだ後脚の、付け根から蹄の付け根までの長さ（元絵の画素）
const KICK_FOLD := 18.0
## 攻撃時間のうち、蹄を伸ばしきるまでの割合
const KICK_EXTEND := 0.4
var actor: MonocerosBoss
var hit := 0.0
var _body_facing := 0.0
var _neck_facing := 0.0
var _head_facing := 0.0
var _tail_facing := 0.0
var _flame_facing := 0.0
@onready var parts: PartsVisual = $Parts

func _ready() -> void:
	EFFECT_SETTINGS.apply_key(self, "boss/body/monoceros")

func bind_monoceros(owner_actor: MonocerosBoss) -> void:
	actor = owner_actor
	_body_facing = actor.table.facing[actor.body]
	_neck_facing = _body_facing
	_head_facing = _body_facing
	_tail_facing = _body_facing
	_flame_facing = _body_facing
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	material = actor.hit_feedback.make_material()
	z_index = 1
	_sync_parts(0.0)

func _event(event: Dictionary) -> void:
	if event.cue == &"hit": hit = 0.18
	queue_redraw()

func _advance(dt: float) -> void:
	hit = maxf(0.0, hit - dt)
	_sync_parts(dt)
	queue_redraw()

func _process(_dt: float) -> void:
	if actor == null or not actor.has_body(): return
	var reaction: Dictionary = actor.hit_feedback.sample(actor.body_id)
	material.set_shader_parameter("boss_hit_white", reaction.white)
	_sync_parts(0.0)
	queue_redraw()

func _sync_parts(dt: float) -> void:
	if actor == null or not actor.has_body(): return
	var k := actor.table.r[actor.body] / 96.0
	parts.scale = Vector2.ONE * k
	parts.apply_appearance(actor.def.part_appearance)
	_update_turn(dt)
	# 胴体中心を固定して見た目だけ遅らせる。移動・判定・予告線は役者の方向を使う。
	parts.rotation = -PI * 0.5 + angle_difference(actor.table.facing[actor.body], _body_facing)
	var reaction: Dictionary = actor.hit_feedback.sample(actor.body_id)
	parts.rotation += reaction.angle
	parts.position = -Vector2(0, -37).rotated(parts.rotation) * k + reaction.offset
	parts.get_node("Head").rotation = angle_difference(_body_facing, _neck_facing)
	parts.get_node("Head/Lower").rotation = angle_difference(_neck_facing, _head_facing)
	var tail := parts.get_node("TailBooster") as Node2D
	tail.rotation = angle_difference(_body_facing, _tail_facing)
	# 根元を支点にするが、既存の編集キーと保存済み配置は動かさない。
	var tail_pivot := Vector2(0, 26)
	tail.position = parts.rest_position("TailBooster") + tail_pivot - tail_pivot.rotated(tail.rotation)
	parts.modulate = Color(1.35, 1.35, 1.35) if hit > 0.0 or reaction.white > 0.0 else Color.WHITE
	var moving := actor.table.vel[actor.body].length_squared() > 25.0
	parts.advance_gait(dt, moving and actor.mode not in [&"windup", &"stuck", &"phase", &"final", &"defeated"])
	for path in REAR_LEGS:
		var leg := parts.get_node(path) as Node2D
		leg.rotation = 0.0
		leg.scale = Vector2.ONE
	var pose: Dictionary = actor._runner_for().body_pose(actor, parts)
	for leg_pose: Dictionary in pose.legs:
		var leg := parts.get_node(leg_pose.path) as Node2D
		leg.rotation = leg_pose.rotation
		leg.scale.y = leg_pose.stretch
		leg.get_node("Foot").position.y = leg_pose.foot
	var sword := parts.get_node("Head/Lower/SwordGlow") as Polygon2D
	sword.visible = actor.phase == 2
	sword.polygon = PackedVector2Array([Vector2(-4, 105), Vector2(-9, 111), Vector2(0, actor.horn_length() / k - 46), Vector2(9, 111), Vector2(4, 105)])
	parts.get_node("Head/Lower/SwordGlow/Guard").visible = sword.visible

func _update_turn(dt: float) -> void:
	if dt <= 0.0: return
	var target := actor.table.facing[actor.body]
	var attacking := actor.mode == &"active" or actor.mode == &"stuck" or (actor.mode == &"windup" and actor.locked)
	var sweeping: bool = (actor.technique == &"sweep" or (actor._runner != null and actor._runner.sequenced())) and actor.mode in [&"windup", &"active"]
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
	if actor._runner != null and actor._runner.sequenced() and actor.mode in [&"windup", &"active"]:
		var strength: float = actor._runner.booster(actor)
		if strength >= 0.0: return strength
	return 2.5 if actor.mode == &"active" and actor.technique in [&"charge", &"return_charge"] else 0.55

func _booster() -> void:
	var strength := booster_strength()
	if strength <= 0.0: return
	var nozzle := parts.get_node("TailBooster/Sprite/booster") as Node2D
	var anchor := to_local(nozzle.to_global(Vector2(37, 0))) / (actor.table.r[actor.body] / 96.0)
	var length := (50.0 + sin(actor.clock * 27.0) * 9.0) * strength * booster_length_scale
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
			draw_rect(Rect2(at, size), [Color("#245c96"), Color("#61c9ff"), booster_core_color][layer])
			center = next

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (actor.table.r[actor.body] / 96.0))
	_booster()
