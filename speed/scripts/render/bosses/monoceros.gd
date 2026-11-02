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
const PartsVisual = preload("res://scripts/bosses/monoceros_parts.gd")
const WARNING := Color("#f2b567")
const ENERGY := Color("#9fe8ff")
const REAR_LEGS := ["RearLeftLeg", "RearRightLeg"]
## 後ろ蹴りで畳んだ後脚の、付け根から蹄の付け根までの長さ（元絵の画素）
const KICK_FOLD := 18.0
## 攻撃時間のうち、蹄を伸ばしきるまでの割合
const KICK_EXTEND := 0.4
var state := {}
var technique := {}
var appearance := {}
var _world_clock := -1.0
var _leg_rest := {}
var hit := 0.0
var _body_facing := 0.0
var _neck_facing := 0.0
var _head_facing := 0.0
var _tail_facing := 0.0
var _flame_facing := 0.0
var _horn_source_seconds := 0.0
var _horn_durations: PackedFloat32Array
var _horn_lengths: PackedFloat32Array
@onready var parts: PartsVisual = $Parts
@onready var horn: Sprite2D = $Parts/Head/Lower/Horn

func _ready() -> void:
	EFFECT_SETTINGS.apply_key(self, "boss/body/monoceros")
	z_index = 8

## 表示用の値だけを読む。敵表・技Runnerへ書き戻す参照は持たない。
func apply_frame(body: Dictionary, attack: Dictionary = {}, colors: Dictionary = {}) -> void:
	var dt := maxf(0.0, float(body.clock)-_world_clock) if _world_clock>=0.0 else 0.0
	if _world_clock>float(body.clock):
		_body_facing = float(body.facing)
		_neck_facing = _body_facing
		_head_facing = _body_facing
		_tail_facing = _body_facing
		_flame_facing = _body_facing
	state = body
	technique = attack
	appearance = colors
	_world_clock = float(body.clock)
	position = body.position
	rotation = body.facing
	visible = body.mode<4
	if _horn_lengths.is_empty():
		_body_facing = body.facing
		_neck_facing = body.facing
		_head_facing = body.facing
		_tail_facing = body.facing
		_flame_facing = body.facing
		_horn_durations = horn.texture.get_meta("durations")
		_horn_lengths = horn.texture.get_meta("core_lengths")
		for i in range(1,_horn_durations.size()): _horn_source_seconds += _horn_durations[i]
		horn.material = parts.get_node("Head/Lower/Sprite/head_gold_armor").material.duplicate()
	hit = body.flash
	_sync_parts(dt)
	queue_redraw()

func _mode() -> StringName:
	if state.mode==0: return &"entrance"
	if state.mode==2: return &"phase"
	if state.mode==3: return &"final"
	if state.mode>=4: return &"defeated"
	return [&"windup",&"active",&"recovery",&"stuck",&"extract",&"idle",&"idle",&"idle"][int(technique.get("stage",5))]

func _sync_parts(dt: float) -> void:
	if state.is_empty(): return
	var k := float(state.radius) / 96.0
	parts.scale = Vector2.ONE * k
	parts.apply_appearance(appearance)
	# 角を使う全技で同じ光を絵に乗せ、首の振りと外観の位置補正へ追従させる。
	var horn_glow := _horn_glow()
	var horn_light := 1.0 + horn_glow * 3.0
	var horn_tint := Color(horn_light, horn_light, horn_light)
	parts.get_node("Head/Lower/Sprite/head_gold_armor").self_modulate = horn_tint
	_update_turn(dt)
	# 胴体中心を固定して見た目だけ遅らせる。移動・判定・予告線は役者の方向を使う。
	parts.rotation = -PI * 0.5 + angle_difference(float(state.facing), _body_facing)
	var reaction := {"white":float(state.flash>0.0),"angle":0.0,"offset":Vector2.ZERO}
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
	var moving: bool = state.velocity.length_squared() > 25.0
	parts.advance_gait(dt, moving and _mode() not in [&"windup", &"stuck", &"phase", &"final", &"defeated"])
	for path in REAR_LEGS:
		var leg := parts.get_node(path) as Node2D
		leg.rotation = 0.0
		leg.scale = Vector2.ONE
		var foot := leg.get_node("Foot") as Node2D
		if not _leg_rest.has(path): _leg_rest[path] = foot.position.y
		foot.position.y = float(_leg_rest[path])
	_kick_pose()
	_sync_horn(dt, k, horn_tint)

## 後脚は表示専用。C++の進行値から同じ姿勢を組み直せる。
func _kick_pose() -> void:
	if technique.get("technique","")!="kick" or int(technique.get("stage",5))>2: return
	var stage: int = technique.stage
	var tip: Vector2 = (technique.horn[1]-state.position).rotated(-float(state.facing))
	var target := parts.transform.affine_inverse()*tip
	for path in REAR_LEGS:
		var leg := parts.get_node(path) as Node2D
		var foot := leg.get_node("Foot") as Node2D
		var hoof := foot.get_node("Sprite") as Node2D
		var art := hoof.get_node("Base") as Sprite2D
		var toward := target-leg.position
		var turn := wrapf(toward.angle()-PI*0.5,-TAU,0.0)
		var rest: float = _leg_rest[path]
		if stage==0:
			leg.rotation = lerpf(0.0,turn,float(technique.windup_progress))
			foot.position.y = lerpf(rest,KICK_FOLD,float(technique.windup_progress))
		else:
			var extend: float = technique.active_progress if stage==1 else 1.0
			var back: float = technique.settle_progress if stage==2 else 0.0
			var natural: float = rest+hoof.position.y+art.texture.get_height()
			leg.rotation = lerpf(turn,0.0,back)
			foot.position.y = lerpf(lerpf(KICK_FOLD,rest,extend),rest,back)
			leg.scale.y = lerpf(lerpf(1.0,maxf(1.0,toward.length()/natural),extend),1.0,back)

func _sync_horn(_dt: float, body_scale: float, tint: Color) -> void:
	var progress: float = state.phase_progress
	horn.frame = 0
	if state.phase>=2:
		var time := progress*_horn_source_seconds
		for i in range(1,_horn_durations.size()):
			horn.frame = i
			if time<_horn_durations[i]: break
			time -= _horn_durations[i]
	var root := to_local(horn.global_position)
	var axis := (to_local(horn.to_global(Vector2.DOWN))-root).normalized()
	horn.scale.y = maxf(1.0,float(state.horn_length)-root.dot(axis))/(body_scale*_horn_lengths[horn.frame])
	horn.self_modulate = tint
	var source := parts.get_node("Head/Lower/Sprite/head_gold_armor").material as ShaderMaterial
	for key in ["painted","paint"]: (horn.material as ShaderMaterial).set_shader_parameter(key,source.get_shader_parameter(key))

func _horn_glow() -> float:
	if technique.get("technique","")=="lance": return float(technique.get("glow",0.0)) if _mode() in [&"windup",&"active"] else 0.0
	if technique.get("technique","")=="kick": return 0.0
	if _mode()==&"active": return 1.0
	return float(state.charge) if _mode()==&"windup" else 0.0

func _update_turn(dt: float) -> void:
	var target := float(state.facing)
	var attacking := _mode() == &"active" or _mode() == &"stuck" or (_mode() == &"windup" and bool(technique.get("locked",false)))
	var sweeping: bool = StringName(technique.get("technique","")) == &"sweep" and _mode() in [&"windup", &"active"]
	_body_facing = _follow_angle(_body_facing, target, dt, body_follow_seconds * (0.3 if attacking else 1.0))
	_body_facing = _limit_angle(target, _body_facing, body_lag_degrees)
	if attacking or sweeping:
		# 角を使う技は見た目の遅れを頭に残さず、判定と同じ方向へ向ける。
		var points: PackedVector2Array = technique.get("horn",PackedVector2Array([state.position,state.position+Vector2.RIGHT.rotated(state.facing)]))
		_neck_facing = (points[1] - points[0]).angle() if StringName(technique.get("technique","")) != &"kick" else target
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
	return (world_point - state.position).rotated(-float(state.facing))

func booster_strength() -> float:
	if state.is_empty() or _mode() == &"defeated": return 0.0
	if _mode() == &"entrance": return 2.0
	if technique.has("booster"): return float(technique.booster)
	return 2.5 if _mode() == &"active" and StringName(technique.get("technique","")) in [&"charge", &"return_charge"] else 0.55

func _booster() -> void:
	var strength := booster_strength()
	if strength <= 0.0: return
	var nozzle := parts.get_node("TailBooster/Sprite/booster") as Node2D
	var anchor := to_local(nozzle.to_global(Vector2(37, 0))) / (float(state.radius) / 96.0)
	var length := (50.0 + sin(float(state.clock) * 27.0) * 9.0) * strength * booster_length_scale
	var root_angle := _tail_facing - float(state.facing) + PI
	var tip_angle := _flame_facing - float(state.facing) + PI
	for layer in 3:
		var factor := 1.0 - float(layer) * 0.24
		var center := anchor
		for j in 12:
			var t := float(j) / 12.0
			var height := maxf(pixel_size, (24.0 - t * 22.0) * factor)
			var direction := Vector2.from_angle(lerp_angle(root_angle, tip_angle, t * t))
			var next := center + direction * length * factor / 12.0
			var side := direction.orthogonal()
			var wobble := side * sin(float(state.clock) * 20.0 - t * 8.0) * 7.0 * t * factor
			var thickness := side.abs() * height
			var at := (center.min(next) + wobble - thickness * 0.5).snapped(Vector2.ONE * pixel_size)
			var size := ((next - center).abs() + thickness).snapped(Vector2.ONE * pixel_size).max(Vector2.ONE * pixel_size)
			draw_rect(Rect2(at, size), [Color("#245c96"), Color("#61c9ff"), booster_core_color][layer])
			center = next

func _draw() -> void:
	if state.is_empty(): return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (float(state.radius) / 96.0))
	_booster()
