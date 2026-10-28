## パーツの走りは世界時間、向きは役者と同じ戦闘方向へ同期する。
extends Node2D
@export var pixel_size := 3.0
var lance_afterglow := 0.0
var lance_launched := false
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
@onready var parts: PartsVisual = $Parts

func bind_monoceros(owner_actor: MonocerosBoss) -> void:
	actor = owner_actor
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	material = actor.hit_feedback.make_material()
	z_index = 1
	_sync_parts(0.0)

func _event(event: Dictionary) -> void:
	if event.technique == &"lance":
		if event.cue == &"telegraph": lance_launched = false
		if event.cue == &"attack_started": lance_launched = true
	if event.cue == &"recovery_started" and event.technique == &"lance" and lance_launched:
		lance_launched = false
		lance_points = actor.horn_points()
		lance_afterglow = float(actor.def.params.get("lance_hold", 0.12)) + float(actor.def.params.get("lance_fade", 0.45))
	if event.cue == &"hit": hit = 0.18
	queue_redraw()

func _advance(dt: float) -> void:
	lance_afterglow = maxf(0.0, lance_afterglow - dt)
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
	_pose_kick()
	var neck_angle := 0.0
	if actor.technique == &"sweep" and actor.mode in [&"windup", &"active"]:
		var points := actor.horn_points()
		neck_angle = angle_difference(actor.table.facing[actor.body], (points[1] - actor.table.pos[actor.body]).angle())
	parts.get_node("Head").rotation = neck_angle
	var sword := parts.get_node("Head/SwordGlow") as Polygon2D
	sword.visible = actor.phase == 2
	sword.polygon = PackedVector2Array([Vector2(-4, 105), Vector2(-9, 111), Vector2(0, actor.horn_length() / k - 46), Vector2(9, 111), Vector2(4, 105)])
	parts.get_node("Head/SwordGlow/Guard").visible = sword.visible

## 後ろ蹴り：予告で後脚を蹴る向きへ畳み、攻撃で蹄を判定の先端まで伸ばす。
func _pose_kick() -> void:
	for path in REAR_LEGS:
		var leg := parts.get_node(path) as Node2D
		leg.rotation = 0.0
		leg.scale = Vector2.ONE
	if actor.technique != &"kick" or actor.mode not in [&"windup", &"active"]: return
	var rule := actor.rule()
	var warn := maxf(0.001, float(rule.warn))
	var elapsed := actor.timeline.current_animation_position
	# 判定の先端を、役者座標から元絵（下向きが前方）の座標へ戻す。
	var tip := Vector2.from_angle(angle_difference(actor.table.facing[actor.body], actor.direction.angle())) * float(rule.reach)
	var tip_in_parts := parts.transform.affine_inverse() * tip
	for path in REAR_LEGS:
		var leg := parts.get_node(path) as Node2D
		var foot := leg.get_node("Foot") as Node2D
		var hoof := foot.get_node("Sprite") as Sprite2D
		var toward := tip_in_parts - leg.position
		# 真後ろをまたいでも回る向きが反転しないよう、後ろ向きの回転を -2π〜0 へまとめる。
		var turn := wrapf(toward.angle() - PI * 0.5, -TAU, 0.0)
		var rest := foot.position.y
		if actor.mode == &"windup":
			var fold := clampf(elapsed / warn, 0.0, 1.0)
			leg.rotation = lerpf(0.0, turn, fold)
			foot.position.y = lerpf(rest, KICK_FOLD, fold)
		else:
			var extend := clampf((elapsed - warn) / maxf(0.001, float(rule.active) * KICK_EXTEND), 0.0, 1.0)
			var natural := rest + hoof.position.y + hoof.texture.get_height()
			leg.rotation = turn
			foot.position.y = lerpf(KICK_FOLD, rest, extend)
			leg.scale.y = lerpf(1.0, maxf(1.0, toward.length() / natural), extend)

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
		if actor.technique == &"kick" and actor.mode == &"active": return
		if actor.technique in [&"charge", &"return_charge", &"lance"] and actor.mode==&"windup":
			# 薄い進路は移動後の角先、太い角の光は実際の攻撃形状を示す。
			draw_line(a,_body_point(actor.warning_points()[1]),Color(color,0.3),6.0,false)
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
