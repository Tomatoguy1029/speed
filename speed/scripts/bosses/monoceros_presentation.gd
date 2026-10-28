## パーツの走りは世界時間、向きは役者と同じ戦闘方向へ同期する。
extends Node2D
@export var pixel_size := 3.0
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
@onready var parts: PartsVisual = $Parts

func bind_monoceros(owner_actor: MonocerosBoss) -> void:
	actor = owner_actor
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
	# 元絵の下向きを役者の前方（+X）へ合わせ、胴体の中心を判定円へ置く。
	var reaction: Dictionary = actor.hit_feedback.sample(actor.body_id)
	parts.position = Vector2(37.0 * k, 0.0) + reaction.offset
	parts.rotation = -PI * 0.5 + reaction.angle
	parts.modulate = Color(1.35, 1.35, 1.35) if hit > 0.0 or reaction.white > 0.0 else Color.WHITE
	var moving := actor.table.vel[actor.body].length_squared() > 25.0
	parts.advance_gait(dt, moving and actor.mode not in [&"windup", &"stuck", &"phase", &"final", &"defeated"])
	for path in REAR_LEGS:
		var leg := parts.get_node(path) as Node2D
		leg.rotation = 0.0
		leg.scale = Vector2.ONE
	var pose: Dictionary = actor._runner_for().body_pose(actor, parts)
	parts.get_node("Head").rotation = pose.neck
	for leg_pose: Dictionary in pose.legs:
		var leg := parts.get_node(leg_pose.path) as Node2D
		leg.rotation = leg_pose.rotation
		leg.scale.y = leg_pose.stretch
		leg.get_node("Foot").position.y = leg_pose.foot
	var sword := parts.get_node("Head/SwordGlow") as Polygon2D
	sword.visible = actor.phase == 2
	sword.polygon = PackedVector2Array([Vector2(-4, 105), Vector2(-9, 111), Vector2(0, actor.horn_length() / k - 46), Vector2(9, 111), Vector2(4, 105)])
	parts.get_node("Head/SwordGlow/Guard").visible = sword.visible

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
	var length := (50.0 + sin(actor.clock * 27.0) * 9.0) * strength
	for layer in 3:
		var factor := 1.0 - float(layer) * 0.24
		for j in 12:
			var t := float(j) / 12.0
			var height := maxf(pixel_size, (24.0 - t * 22.0) * factor)
			var at := Vector2(-96.0 - length * t * factor, sin(actor.clock * 20.0 - t * 8.0) * 7.0 * t * factor - height * 0.5).snapped(Vector2.ONE * pixel_size)
			draw_rect(Rect2(at, Vector2(maxf(pixel_size, length * factor / 12.0), height)), [Color("#245c96"), Color("#61c9ff"), Color("#e0fbff")][layer])

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (actor.table.r[actor.body] / 96.0))
	_booster()
