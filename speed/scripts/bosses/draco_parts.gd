## Authored armor follows the existing spine; the final two pieces are reserved for the tail.
extends Node2D
const FORM = preload("res://scripts/bosses/draco_form.gd")
const ARM_ROOT := Vector2(11, 5)
const ARM_WRIST := Vector2(27, 33)
const SHADER = preload("res://shaders/draco_part.gdshader")
const LIGHT = preload("res://shaders/draco_entrance_light.gdshader")
const PICARO_SHADER = preload("res://shaders/picaro.gdshader")
const PICARO_LOOK = preload("res://scripts/render/picaro_look.gd")
const TEXTURES = {
	&"head": [preload("res://assets/pixel/draco/head.png"), preload("res://assets/pixel/draco/head_normal.png")],
	&"arm": [preload("res://assets/pixel/draco/arm.png"), preload("res://assets/pixel/draco/arm_normal.png")],
	&"claw": [preload("res://assets/pixel/draco/claw.png"), preload("res://assets/pixel/draco/claw_normal.png")],
	&"body_a": [preload("res://assets/pixel/draco/body_a.png"), preload("res://assets/pixel/draco/body_a_normal.png")],
	&"body_b": [preload("res://assets/pixel/draco/body_b.png"), preload("res://assets/pixel/draco/body_b_normal.png")],
	&"body_c": [preload("res://assets/pixel/draco/body_c.png"), preload("res://assets/pixel/draco/body_c_normal.png")],
	&"body_d": [preload("res://assets/pixel/draco/body_d.png"), preload("res://assets/pixel/draco/body_d_normal.png")],
	&"body_e": [preload("res://assets/pixel/draco/body_e.png"), preload("res://assets/pixel/draco/body_e_normal.png")],
	&"tail_joint": [preload("res://assets/pixel/draco/tail_joint.png"), preload("res://assets/pixel/draco/tail_joint_normal.png")],
	&"tail_tip": [preload("res://assets/pixel/draco/tail_tip.png"), preload("res://assets/pixel/draco/tail_tip_normal.png")],
}
var _segments: Array[Sprite2D] = []
var _head: Sprite2D
var _arms: Array[Sprite2D] = []
var _claws: Array[Sprite2D] = []
var _entrance_materials := {}
var _entrance_distances := {}
var _entrance_length := 1.0
var _entrance_width := 1.0
var _entrance_head_scale := 1.0
var _entrance_on := false
var _eye_copy: BackBufferCopy
var _eye_light: Sprite2D
## 登場中の胸の位置（この節点の座標）。
var entrance_chest := Vector2.ZERO
var _lighting: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _lighting == null:
		_lighting = ShaderMaterial.new()
		_lighting.shader = SHADER
	_lighting.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
	_head = _sprite(&"head")
	_head.z_index = 1
	# The snout stays aligned with the existing mouth origin (120 * head_scale).
	_head.offset = Vector2(0, 14)
	_build_eye_light()
	# Keep limbs on the body layer: negative Z falls behind the combat background.
	for _i in 4:
		var arm := _sprite(&"arm")
		arm.centered = false
		arm.offset = -ARM_ROOT
		_arms.append(arm)
		var claw := _sprite(&"claw")
		claw.centered = false
		claw.offset = -Vector2(13, 16)
		_claws.append(claw)

## 全身複製はピカロの一種なので、全部の部位を敵のピカロと同じシェーダーで描く。
## 絵の腕だけを根元から回す量（ラジアン）。
var arm_turns := [0.0,0.0,0.0,0.0]
func use_picaro(seed: float) -> void:
	var noise: Texture2D = PICARO_LOOK.noise_texture()
	_lighting = ShaderMaterial.new()
	_lighting.shader = PICARO_SHADER
	_lighting.set_shader_parameter("noise_smooth", noise)
	_lighting.set_shader_parameter("noise_dots", noise)
	_lighting.set_shader_parameter("seed", seed)
	if is_inside_tree(): _lighting.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
	for child in get_children():
		if child is Sprite2D: child.material = _lighting

## 決着の閃光のあいだだけ、竜の色と切り口を決着の表示から受け取る。
func set_finale_tone(tone: Dictionary) -> void:
	_lighting.set_shader_parameter("finale_tone",tone.get("on",false))
	_lighting.set_shader_parameter("finale_gray",tone.get("gray",0.0))
	_lighting.set_shader_parameter("finale_lit",tone.get("lit",0.0))
	_lighting.set_shader_parameter("finale_gap",tone.get("gap",0.0))
	_lighting.set_shader_parameter("finale_center",tone.get("center",Vector2.ZERO))

func _sprite(part: StringName) -> Sprite2D:
	var sprite := Sprite2D.new()
	var texture := CanvasTexture.new()
	texture.diffuse_texture = TEXTURES[part][0]
	texture.normal_texture = TEXTURES[part][1]
	sprite.texture = texture
	if part == &"tail_tip": sprite.offset.y = texture.get_height() * 0.5
	sprite.material = _lighting
	sprite.set_meta(&"part", part)
	add_child(sprite)
	return sprite

func pose(points: PackedVector2Array, width: float, head_scale: float, alpha := 1.0, cosmic := false, hit := 0.0, split_origin := Vector2.ZERO, split_axis := Vector2.ZERO) -> void:
	visible = points.size() >= 2 and alpha > 0.001
	if not visible: return
	modulate.a = alpha
	_lighting.set_shader_parameter("cosmic", cosmic)
	_lighting.set_shader_parameter("boss_hit_white", hit)
	var total := FORM.length(points)
	_entrance_length = maxf(1.0,total)
	_entrance_width = width
	_entrance_head_scale = head_scale
	_entrance_distances.clear()
	var distances := PackedFloat32Array()
	var body_end := maxf(0.0, total - width * 0.70)
	var cursor := minf(body_end, width * 0.43)
	while cursor < body_end:
		distances.append(cursor)
		cursor += maxf(1.0, width * 0.43 * FORM.taper(cursor / maxf(1.0, total)))
	if distances.is_empty() or body_end - distances[-1] > width * 0.08:
		distances.append(body_end)
	distances.append(maxf(body_end, total - width * 0.42))
	distances.append(total)
	var count := distances.size()
	if _segments.size() != count:
		for sprite in _segments:
			_entrance_materials.erase(sprite.get_instance_id())
			sprite.free()
		_segments.clear()
		for i in count:
			var part: StringName
			if i == count - 1: part = &"tail_tip"
			elif i == count - 2: part = &"tail_joint"
			else: part = [&"body_e", &"body_c", &"body_b", &"body_a", &"body_d"][mini(4, int(i * 5.0 / maxi(1, count - 2)))]
			_segments.append(_sprite(part))
	var samples := _sample_positions(points, distances)
	for i in count:
		var sprite := _segments[i]
		_entrance_distances[sprite] = distances[i]
		var t := distances[i] / maxf(1.0, total)
		var at := samples[i + 1]
		var direction := at - samples[i]
		# The final authored arrow points up; all preceding plates point down.
		sprite.rotation = direction.angle() + (PI * 0.5 if i == count - 1 else -PI * 0.5)
		var part_width := float(sprite.texture.get_width())
		sprite.scale = Vector2.ONE * width * FORM.taper(t) / part_width
		sprite.position = _split(at, split_origin, split_axis)
	_entrance_distances[_head] = 0.0
	_head.position = _split(points[0], split_origin, split_axis)
	_head.rotation = -PI * 0.5
	_head.scale = Vector2.ONE * head_scale * 2.0
	_pose_arms(points, width, total, split_origin, split_axis)

func _pose_arms(points: PackedVector2Array, width: float, total: float, split_origin: Vector2, split_axis: Vector2) -> void:
	for i in 4:
		var distance := minf(total, width * 0.9) if i < 2 else total * 0.66
		var samples := _sample_positions(points, PackedFloat32Array([distance, minf(total, distance + 2.0)]))
		var tangent := (samples[2] - samples[1]).normalized()
		var normal := tangent.orthogonal()
		var unit := width * FORM.taper(distance / maxf(1.0, total)) / 57.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var arm := _arms[i]
		var direction := (normal * side - tangent * 0.3).normalized()
		var wrist := (ARM_WRIST - ARM_ROOT) * Vector2(-side, 1)
		arm.rotation = direction.angle() - wrist.angle() + arm_turns[i]
		arm.scale = Vector2(-side, 1) * unit
		arm.position = _split(samples[1] + normal * side * width * FORM.taper(distance / maxf(1.0, total)) * 0.32, split_origin, split_axis)
		_entrance_distances[arm] = distance
		var claw := _claws[i]
		_entrance_distances[claw] = distance
		claw.rotation = arm.rotation
		claw.scale = arm.scale
		claw.position = arm.position + wrist.rotated(arm.rotation) * unit

func _split(point: Vector2, origin: Vector2, axis: Vector2) -> Vector2:
	return point + axis * (-1.0 if (point - origin).dot(axis) < 0.0 else 1.0)

## One pass over the spine keeps the narrow tail plates close without repeated path scans.
func _sample_positions(points: PackedVector2Array, distances: PackedFloat32Array) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	var segment := 0
	var traversed := 0.0
	for distance in distances:
		var span := points[segment].distance_to(points[segment + 1])
		while segment < points.size() - 2 and distance > traversed + span:
			traversed += span
			segment += 1
			span = points[segment].distance_to(points[segment + 1])
		result.append(points[segment].lerp(points[segment + 1], clampf((distance - traversed) / maxf(0.001, span), 0.0, 1.0)))
	return result

## 登場：頭が通った道を全身が順に抜ける。道の負の位置は裂け目の奥で、遠近で小さく暗くなり、裂け目の内側だけに見える。
## 値と式は承認済みの試作のまま。rift は裂け目shaderへ渡した ends・shape・viewport。
func entrance(intro: Dictionary, rift: Dictionary, quiet: float) -> void:
	if not intro.get("active",false) or not intro.has("path"):
		if _entrance_on:
			_entrance_on = false
			for sprite: Sprite2D in _entrance_distances:
				sprite.material = _lighting
				sprite.z_index = 1 if sprite==_head else 0
			_eye_copy.visible = false
			_eye_light.visible = false
		return
	_entrance_on = true
	var path: PackedVector2Array = intro.path
	var step := float(intro.path_step)
	var head_s := float(intro.head_s)
	var clock := float(intro.time)-quiet+1.2
	var eyes := minf(1.0,float(intro.eyes))
	var spin := global_rotation
	var head := _entrance_point(path,step,head_s,clock)
	_entrance_place(_head,head_s,head.z,rift,eyes)
	_head.position = to_local(Vector2(head.x,head.y))
	_head.scale *= _entrance_near(head.z)
	_head.z_index += 1
	var previous := Vector2(head.x,head.y)
	var count := _segments.size()
	for i in count:
		var sprite := _segments[i]
		var s := head_s-float(_entrance_distances[sprite])
		var at := _entrance_point(path,step,s,clock)
		var here := Vector2(at.x,at.y)
		var angle := -PI*0.5 if here.distance_to(previous)<0.5 else (here-previous).angle()
		sprite.rotation = angle+(PI*0.5 if i==count-1 else -PI*0.5)-spin
		sprite.position = to_local(here)
		sprite.scale *= _entrance_near(at.z)
		_entrance_place(sprite,s,at.z,rift,0.0)
		previous = here
	for i in 4:
		var arm := _arms[i]
		var claw := _claws[i]
		var distance := float(_entrance_distances[arm])
		var s := head_s-distance
		var at := _entrance_point(path,step,s,clock)
		var near := _entrance_near(at.z)
		# 手は体が進む道の向きだけで決める。奥では出口の向きに固定する。
		var tangent := Vector2.UP
		if s>1.0:
			var back := _entrance_point(path,step,s-1.0,clock)
			var ahead := _entrance_point(path,step,s+1.0,clock)
			tangent = (Vector2(back.x,back.y)-Vector2(ahead.x,ahead.y)).normalized()
		var normal := tangent.orthogonal()
		var girth := _entrance_width*FORM.taper(distance/_entrance_length)
		var unit := girth/57.0*near
		var side := -1.0 if i%2==0 else 1.0
		var wrist := (ARM_WRIST-ARM_ROOT)*Vector2(-side,1)
		arm.rotation = (normal*side-tangent*0.3).angle()-wrist.angle()+arm_turns[i]-spin
		arm.scale = Vector2(-side,1)*unit
		arm.position = to_local(Vector2(at.x,at.y)+normal*side*girth*0.32*near)
		claw.rotation = arm.rotation
		claw.scale = arm.scale
		claw.position = arm.position+wrist.rotated(arm.rotation)*unit
		_entrance_place(arm,s-0.5,at.z,rift,0.0)
		_entrance_place(claw,s-0.5,at.z,rift,0.0)
	var chest := _entrance_point(path,step,head_s-110.0*_entrance_head_scale,clock)
	entrance_chest = to_local(Vector2(chest.x,chest.y))
	_eye_copy.visible = eyes>0.001
	_eye_light.visible = eyes>0.001
	var light: ShaderMaterial = _eye_light.material
	light.set_shader_parameter("strength",eyes)
	light.set_shader_parameter("behind",head_s<0.0)
	light.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
	light.set_shader_parameter("rift_viewport",rift.viewport)
	light.set_shader_parameter("rift_ends",rift.ends)
	light.set_shader_parameter("rift_shape",rift.shape)

## 道の上の点（x・y はワールド座標、z は奥行き）。奥ではゆっくりうねる。
func _entrance_point(path: PackedVector2Array, step: float, s: float, clock: float) -> Vector3:
	if s>=0.0:
		var f := minf(s/step,float(path.size()-1))
		var i := mini(int(f),path.size()-2)
		var p := path[i].lerp(path[i+1],f-float(i))
		return Vector3(p.x,p.y,0.0)
	var z := -s
	var near := _entrance_near(z)
	var settle := smoothstep(0.0,260.0,z)
	var x := (sin(z*0.0045+clock*1.1)*150.0+sin(z*0.011-clock*0.7)*40.0)*settle
	var y := (-z*0.18+cos(z*0.0038+clock*0.8)*70.0)*settle
	return Vector3(path[0].x+x*near,path[0].y+y*near,z)

func _entrance_near(z: float) -> float:
	return 1.0/(1.0+z/650.0)

## 奥の部位ほど下に重ね、出た部位はいつもの順でその上に重ねる。
func _entrance_place(sprite: Sprite2D, s: float, z: float, rift: Dictionary, eyes: float) -> void:
	var id := sprite.get_instance_id()
	if not _entrance_materials.has(id):
		_entrance_materials[id] = _lighting.duplicate()
	var mat: ShaderMaterial = _entrance_materials[id]
	sprite.material = mat
	sprite.visible = true
	sprite.z_index = 400 if s>=0.0 else 1+clampi(int((s+2600.0)/8.0),0,324)
	mat.set_shader_parameter("boss_hit_white",_lighting.get_shader_parameter("boss_hit_white"))
	mat.set_shader_parameter("entrance",true)
	mat.set_shader_parameter("entrance_head",sprite==_head)
	mat.set_shader_parameter("entrance_behind",s<0.0)
	mat.set_shader_parameter("entrance_dark",pow(clampf(z/700.0,0.0,1.0),0.6)*0.97)
	mat.set_shader_parameter("entrance_eyes",eyes)
	mat.set_shader_parameter("rift_viewport",rift.viewport)
	mat.set_shader_parameter("rift_ends",rift.ends)
	mat.set_shader_parameter("rift_shape",rift.shape)

## 光を重ねる板を作る。直前に画面を写し、板のshaderがその写しへ光を足す。
static func light_plate(parent: Node, size: Vector2, blobs: Array, tints: Array, cross := Vector3.ZERO) -> Array:
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	copy.visible = false
	parent.add_child(copy)
	var dot := Image.create(1,1,false,Image.FORMAT_RGBA8)
	dot.fill(Color.WHITE)
	var plate := Sprite2D.new()
	plate.texture = ImageTexture.create_from_image(dot)
	plate.scale = size
	var mat := ShaderMaterial.new()
	mat.shader = LIGHT
	var packed_blobs := PackedVector4Array(blobs)
	var packed_tints := PackedVector4Array(tints)
	mat.set_shader_parameter("count",blobs.size())
	packed_blobs.resize(4)
	packed_tints.resize(4)
	mat.set_shader_parameter("blobs",packed_blobs)
	mat.set_shader_parameter("tints",packed_tints)
	mat.set_shader_parameter("star_cross",cross)
	plate.material = mat
	plate.visible = false
	parent.add_child(plate)
	return [copy,plate]

## 顔の絵の赤い画素を左右の目に分け、それぞれへ小さい光と大きい光を重ねる。
func _build_eye_light() -> void:
	var image: Image = TEXTURES[&"head"][0].get_image()
	var boxes := [Rect2i(),Rect2i()]
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x,y)
			if c.a<=0.0 or not (c.r>0.2 and c.r>c.g*1.6 and c.r>c.b*1.4): continue
			var k := 0 if x<image.get_width()/2 else 1
			var cell := Rect2i(x,y,1,1)
			boxes[k] = cell if boxes[k].size==Vector2i.ZERO else boxes[k].merge(cell)
	var lights := []
	var area := Rect2()
	for box: Rect2i in boxes:
		if box.size==Vector2i.ZERO: continue
		var center := Vector2(box.position)+Vector2(box.size)*0.5
		for spread: Vector3 in [Vector3(3.0,3.4,0.85),Vector3(6.4,6.8,0.4)]:
			var half := Vector2(box.size)*Vector2(spread.x,spread.y)*0.5
			lights.append([center,half,spread.z])
			var reach := Rect2(center-half,half*2.0)
			area = reach if area.size==Vector2.ZERO else area.merge(reach)
	var blobs := []
	var tints := []
	for light: Array in lights:
		var at: Vector2 = (light[0]-area.position)/area.size
		var half: Vector2 = light[1]/area.size
		blobs.append(Vector4(at.x,at.y,half.x,half.y))
		tints.append(Vector4(1.0,0.125,0.22,light[2]))
	var made := light_plate(_head,area.size,blobs,tints)
	_eye_copy = made[0]
	_eye_light = made[1]
	_eye_light.position = area.get_center()-Vector2(image.get_size())*0.5+_head.offset
