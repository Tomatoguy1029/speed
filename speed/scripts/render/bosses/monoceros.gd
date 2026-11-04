## 世界時間で頭から胴体・尾へ旋回を伝え、攻撃の向きは戦闘方向へ同期する。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const REFERENCE_SETTINGS := preload("res://data/visuals/fx_reference.tres")
const REFERENCE_BOOST := preload("res://scripts/render/bosses/monoceros_boost.gd")
const REFERENCE_SLASH := preload("res://scripts/render/bosses/monoceros_slash.gd")
const HORN_LIGHT_SHADER := preload("res://shaders/monoceros_horn_light.gdshader")
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
var hit_feedback: RefCounted
var _body_facing := 0.0
var _neck_facing := 0.0
var _head_facing := 0.0
var _tail_facing := 0.0
var _flame_facing := 0.0
var _horn_source_seconds := 0.0
var _horn_durations: PackedFloat32Array
var _horn_lengths: PackedFloat32Array
var _reference_canvas
var _reference_boost
var _reference_id := "I-charge"
var _horn_visual := 0.0
var _horn_overlay: Sprite2D
var _armor_overlay: Sprite2D
var _image_nodes: Array[Node2D] = []
var _image_sprites: Array[Sprite2D] = []
@onready var parts: PartsVisual = $Parts
@onready var horn: Sprite2D = $Parts/Head/Lower/Horn

func _ready() -> void:
	_collect_image_nodes(self)
	EFFECT_SETTINGS.apply_key(self, "boss/body/monoceros")
	z_index = 8
	_reference_boost = REFERENCE_BOOST.new()
	_reference_boost.z_index = -1
	add_child(_reference_boost)
	_horn_overlay = _make_light_overlay(horn)
	_armor_overlay = _make_light_overlay(parts.get_node("Head/Lower/Sprite/head_gold_armor") as Sprite2D)
	material = preload("res://scripts/bosses/boss_hit_feedback.gd").new().make_material()

## 生成時と同じ深さ優先順を、演出用子Spriteの追加前に記録する。
func _collect_image_nodes(parent: Node) -> void:
	for child in parent.get_children():
		if child is Node2D:
			_image_nodes.append(child)
			if child is Sprite2D: _image_sprites.append(child)
		_collect_image_nodes(child)

func _make_light_overlay(source: Sprite2D) -> Sprite2D:
	var light := Sprite2D.new()
	light.texture = source.texture
	light.centered = source.centered
	light.offset = source.offset
	light.flip_h = source.flip_h
	light.flip_v = source.flip_v
	light.hframes = source.hframes
	light.vframes = source.vframes
	light.frame = source.frame
	light.region_enabled = source.region_enabled
	light.region_rect = source.region_rect
	var shader := ShaderMaterial.new()
	shader.shader = HORN_LIGHT_SHADER
	light.material = shader
	light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	source.add_child(light)
	return light

func frame_event(event: Dictionary) -> void:
	if event.get("type",&"")==&"combat_damage":
		hit = 0.18
		_sync_parts(0.0)
		queue_redraw()

## 表示用の値だけを読む。敵表・技Runnerへ書き戻す参照は持たない。
func apply_frame(body: Dictionary, attack: Dictionary = {}, colors: Dictionary = {}) -> void:
	var dt := maxf(0.0, float(body.clock)-_world_clock) if _world_clock>=0.0 else 0.0
	if _world_clock>float(body.clock):
		_body_facing = float(body.facing)
		_neck_facing = _body_facing
		_head_facing = _body_facing
		_tail_facing = _body_facing
		_flame_facing = _body_facing
		_horn_visual = 0.0
	state = body
	technique = attack
	var move := String(attack.get("technique", ""))
	if not move.is_empty() and not REFERENCE_SETTINGS.for_id("I-" + move).is_empty(): _reference_id = "I-" + move
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
	hit = maxf(float(body.flash),hit-dt)
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
	_horn_visual = horn_glow if horn_glow > _horn_visual else maxf(horn_glow, _horn_visual-dt/0.22)
	var values: Dictionary = REFERENCE_SETTINGS.for_id(_reference_id)
	var brightness := _horn_visual * (float(values.hornBright) if int(state.phase) > 1 else 1.0) * 0.65
	(_horn_overlay.material as ShaderMaterial).set_shader_parameter("strength", brightness)
	(_armor_overlay.material as ShaderMaterial).set_shader_parameter("strength", brightness)
	_update_turn(dt)
	# 胴体中心を固定して見た目だけ遅らせる。移動・判定・予告線は役者の方向を使う。
	parts.rotation = -PI * 0.5 + angle_difference(float(state.facing), _body_facing)
	var reaction := {"white":0.0,"angle":0.0,"offset":Vector2.ZERO}
	if state.has("image_feedback"): reaction = state.image_feedback
	elif hit_feedback!=null: reaction = hit_feedback.sample(int(state.actor))
	material.set_shader_parameter("boss_hit_white",reaction.white)
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
	_charge_pose()
	_sync_horn(dt, k)
	_apply_image_pose(state.get("image_node_poses",[]),state.get("image_parts",[]),reaction)

## 本番が画像境界に使った全関節を、そのまま表示とFXの基点にも使う。
func _apply_image_pose(node_poses: Array, sprites: Array, reaction: Dictionary) -> void:
	if node_poses.is_empty(): return
	for entry: Dictionary in node_poses:
		var index := int(entry.node)-1
		if index < 0 or index >= _image_nodes.size(): continue
		_image_nodes[index].global_transform = entry.transform
		_image_nodes[index].visible = bool(entry.visible)
	for entry: Dictionary in sprites:
		var index := int(entry.part)-1
		if index < 0 or index >= _image_sprites.size(): continue
		var sprite := _image_sprites[index]
		var region := Rect2(entry.region)
		if sprite == horn:
			var frame_width := horn.texture.get_width()/float(horn.hframes)
			horn.frame = clampi(floori(region.position.x/frame_width),0,horn.hframes-1)
			_horn_overlay.frame = horn.frame
		elif sprite.get_parent().name == &"Sprite" and sprite.get_parent().get_parent().name == &"Foot":
			var animation := &"armor" if sprite.name == &"Armor" else &"run"
			for frame in parts.gait.get_frame_count(animation):
				var texture := parts.gait.get_frame_texture(animation,frame)
				if texture is AtlasTexture and texture.region == region:
					sprite.texture = texture
					break
	_tail_facing = (parts.get_node("TailBooster") as Node2D).global_rotation + PI*0.5 - float(reaction.angle)

## 突進の構えと発進は本体と足の見た目だけを動かす。
func _charge_pose() -> void:
	var move := String(technique.get("technique", ""))
	var aimed := move in ["charge", "return_charge", "horn_dance"]
	var prepare := smoothstep(0.0, 0.62, float(technique.get("windup_progress", 0.0))) if aimed and _mode() == &"windup" and int(technique.get("sequence_stage", 0)) == 0 else 0.0
	var elapsed := float(technique.get("fx_boost_elapsed", 0.0))
	var release := 1.0 - smoothstep(0.035, 0.14, elapsed) if aimed and String(technique.get("fx_boost_stage", "")) == "run" else 0.0
	var head := parts.get_node("Head") as Node2D
	var body := parts.get_node("Body") as Node2D
	head.position = parts.rest_position("Head") + Vector2(0, -prepare*5.0 + release*3.0)
	body.position = parts.rest_position("Body") + Vector2(0, -prepare*2.0 + release*2.0)
	for path: String in ["FrontLeftLeg/Foot", "FrontRightLeg/Foot"]:
		var foot := parts.get_node(path) as Node2D
		foot.position += Vector2(0, -prepare*7.0 + release*3.0)

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

func _sync_horn(_dt: float, body_scale: float) -> void:
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
	_horn_overlay.texture = horn.texture
	_horn_overlay.hframes = horn.hframes
	_horn_overlay.vframes = horn.vframes
	_horn_overlay.frame = horn.frame
	var source := parts.get_node("Head/Lower/Sprite/head_gold_armor").material as ShaderMaterial
	for key in ["painted","paint"]: (horn.material as ShaderMaterial).set_shader_parameter(key,source.get_shader_parameter(key))

func _horn_glow() -> float:
	if technique.get("technique","") in ["lance","return_charge","horn_wave","horn_dance","sword_flash"]: return float(technique.get("glow",0.0)) if _mode() in [&"windup",&"active"] else 0.0
	if technique.get("technique","")=="kick": return 0.0
	if _mode()==&"active": return 1.0
	return float(state.charge) if _mode()==&"windup" else 0.0

func _update_turn(dt: float) -> void:
	var target := float(state.facing)
	var attacking := _mode() == &"active" or _mode() == &"stuck" or (_mode() == &"windup" and bool(technique.get("locked",false)))
	var sweeping: bool = StringName(technique.get("technique","")) in [&"sweep",&"lance",&"return_charge",&"horn_wave",&"horn_dance",&"sword_flash"] and _mode() in [&"windup", &"active"]
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

## 共通ホストから画素変換を受け取り、技の値と本体の姿勢を同じフレームで描く。
func set_reference_canvas(canvas) -> void:
	_reference_canvas = canvas

func draw_reference(canvas, _real_dt: float) -> void:
	if state.is_empty() or not is_instance_valid(_reference_boost): return
	var move := String(technique.get("technique", ""))
	if not move.is_empty() and not REFERENCE_SETTINGS.for_id("I-" + move).is_empty(): _reference_id = "I-" + move
	var values: Dictionary = REFERENCE_SETTINGS.for_id(_reference_id)
	_draw_charge_tell(canvas, move)
	var slash_values: Dictionary = REFERENCE_SETTINGS.for_id("I-sword_flash")
	for slash: Dictionary in state.get("sword_slashes",[]):
		REFERENCE_SLASH.draw(canvas,slash.from,slash.to,float(slash.width),float(state.clock)-float(slash.started),0.6,float(slash.seed),slash_values)
	var nozzle := parts.get_node("TailBooster/Sprite/booster") as Node2D
	var overlap := Vector2.from_angle(_tail_facing) * (24.0 * float(state.radius) / 96.0)
	var anchor := to_local(nozzle.to_global(Vector2(37, 0)) + overlap)
	_reference_boost.apply_reference_frame(float(state.clock), float(state.radius), move,
		String(technique.get("fx_boost_stage", "other")), state.velocity,
		float(technique.get("fx_boost_travel", 0.0)), float(technique.get("fx_boost_run_speed", 0.0)),
		float(technique.get("fx_boost_approach_speed_max", 0.0)), values, float(canvas.world_scale),
		anchor, _tail_facing - float(state.facing))

## 試作のmulberry32を、足ごと・時刻ごとの同じ種で使う。
func _charge_random(state0: int) -> Array:
	var a := (state0 + 0x6d2b79f5) & 0xffffffff
	var t := ((a ^ (a >> 15)) * (a | 1)) & 0xffffffff
	t = (t ^ (t + (((t ^ (t >> 7)) * (t | 61)) & 0xffffffff))) & 0xffffffff
	return [a, float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0]

func _draw_charge_tell(canvas, move: String) -> void:
	if move not in ["charge", "return_charge", "horn_dance"] or _mode() != &"windup" or int(technique.get("sequence_stage", 0)) != 0: return
	var charge := smoothstep(0.0, 0.62, float(technique.get("windup_progress", 0.0)))
	var clock := float(state.clock)
	var back := -Vector2.from_angle(float(state.facing))
	for path: String in ["FrontLeftLeg/Foot", "FrontRightLeg/Foot"]:
		var foot := parts.get_node(path) as Node2D
		var at: Vector2 = canvas.to_logical(foot.global_position)
		canvas.back.glow(at.x, at.y, 3.0, Color("#f2a03a"), charge*0.35)
		for j in 5:
			var seed := floori(clock*12.0)*13+j+path.length()*7
			var first := _charge_random(seed if seed != 0 else 1)
			var second := _charge_random(first[0])
			var age := fposmod(clock*12.0,1.0)/12.0+j*0.02
			var distance := lerpf(4.0,14.0,first[1])*charge
			var angle := back.angle()+lerpf(-0.6,0.6,second[1])
			var direction := Vector2.from_angle(angle)
			var point := at+direction*distance
			if charge > 0.15:
				canvas.back.line(point.x-direction.x*2.0,point.y-direction.y*2.0,point.x,point.y,func(u: float): return Color("#fff3c0") if u > 0.5 else Color("#f2a03a"),charge*(1.0-age*4.0))
	var tail: Vector2 = canvas.to_logical(state.position - Vector2.from_angle(float(state.facing))*float(state.radius)*0.95)
	var pulse := 0.6 + 0.4*sin(clock*(12.0+20.0*charge))
	canvas.front.glow(tail.x,tail.y,5.0+9.0*charge*pulse,Color("#6fc4ff"),(0.3+0.5*charge)*pulse)
	canvas.front.glow(tail.x,tail.y,2.0+3.0*charge,Color("#e4f6ff"),0.6*charge)
