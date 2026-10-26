## 仮の星・瓦礫・夜空の一角獣。操作中も本番 World の上へ描き、場面を断絶させない。
## 星図の絵と色は IntroPresentation で差し替える。
extends Node2D

var intro: RefCounted
var distant_sky := false
var _sky_targets := PackedVector2Array()
var _mist: ColorRect

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if distant_sky:
		_prepare_sky()

func _draw() -> void:
	if intro == null or intro.run == null:
		return
	var beat: int = intro.beat
	var time: float = intro.beat_time
	var p: IntroPresentation = intro.presentation
	if distant_sky:
		if beat < intro.Beat.FLIGHT: _opening(beat,time)
		if beat >= intro.Beat.OMEN:
			_omen(time if beat == intro.Beat.OMEN else p.omen_time + time)
		return
	if beat == intro.Beat.TRANSFORM:
		var progress := clampf(time / p.transform_time, 0.0, 1.0) if beat == intro.Beat.TRANSFORM else 0.0
		for i in intro.practice.stars.size():
			var delay := float(i) * 0.04
			var k := clampf((progress - delay) / (1.0 - delay), 0.0, 1.0)
			_formation(intro.practice.stars[i], k)
	elif beat == intro.Beat.PRACTICE:
		_guide()
	elif beat == intro.Beat.RESTORE:
		var k := clampf(time / p.restore_time, 0.0, 1.0)
		for release: Dictionary in intro.practice.released:
			_rubble(release.from, k, 1.0 - k, p.aura_color)
			var at: Vector2 = release.from.lerp(release.to, smoothstep(0.0, 1.0, k))
			_star(at, smoothstep(0.0, 0.6, k), p.star_color)
	elif beat >= intro.Beat.OMEN:
		for at: Vector2 in intro.practice.stars:
			_star(at, 0.7, p.star_color)

func _formation(at: Vector2, progress: float) -> void:
	var p: IntroPresentation = intro.presentation
	var gather := smoothstep(0.08, 0.72, progress)
	var enemy_alpha := smoothstep(0.84, 1.0, progress)
	_star(at, 1.0 - smoothstep(0.65, 0.9, progress), p.star_color)
	var rubble_alpha := smoothstep(0.04, 0.18, progress) * (1.0 - enemy_alpha)
	for i in 18:
		var angle: float = float(i) * 2.399963 + intro.beat_time * 0.18 * (1.0 - gather)
		var initial := Vector2.from_angle(angle) * (95.0 + float(i % 5) * 13.0)
		var settled := Vector2.from_angle(float(i) * 2.399963) * (3.0 + float(i % 4) * 3.0)
		var center := (at + initial.lerp(settled, gather)).snapped(Vector2(2,2))
		var scale := 0.65 + float(i % 3) * 0.16
		if progress>0.5 and progress<0.85: draw_line(center,at,Color(0.65,0.75,1.0,(1.0-enemy_alpha)*0.12),2.0)
		var piece := PackedVector2Array([Vector2(-6, -4), Vector2(5, -5), Vector2(7, 5), Vector2(-3, 7)])
		for j in piece.size():
			piece[j] = center + piece[j].rotated(angle) * scale
		draw_colored_polygon(piece, Color(0.35 + float(i % 3) * 0.045, 0.42, 0.47, rubble_alpha))
	if progress>0.55 and progress<0.95:
		var pulse := sin((progress-0.55)/0.4*PI)
		draw_arc(at,18.0+pulse*25.0,0,TAU,24,Color(0.8,0.9,1.0,pulse*0.8),3.0)
	# 破片が核の周囲に固まってから、同じ位置の完成スプライトへ溶かして替える。
	if enemy_alpha > 0.0 and p.transform_texture != null:
		var dimensions: Vector2 = p.transform_texture.get_size() * intro.run.cfg.character_scale
		draw_set_transform(at, (intro.run.state.ship_pos - at).angle() + PI / 2.0)
		draw_texture_rect(p.transform_texture, Rect2(-dimensions * 0.5, dimensions), false, Color(1, 1, 1, enemy_alpha))
		draw_set_transform(Vector2.ZERO)

func _guide() -> void:
	var points: PackedVector2Array = intro.practice.guide_points
	if points.size() < 2:
		return
	var p: IntroPresentation = intro.presentation
	var px: float = 1.0 / maxf(0.001, intro.run.state.camera_zoom)
	for i in points.size() - 1:
		if (i / 2) % 2 == 0:
			draw_line(points[i], points[i + 1], p.guide_color, px * 2.0)
		if i > 0 and i % 12 == 0:
			var direction := (points[i + 1] - points[i]).normalized()
			var side := Vector2(-direction.y, direction.x)
			draw_polyline(PackedVector2Array([points[i] - direction * px * 7.0 + side * px * 4.0, points[i], points[i] - direction * px * 7.0 - side * px * 4.0]), p.guide_color, px * 1.5)
	draw_circle(points[0], px * 3.0, p.guide_color)
	draw_arc(points[0], px * 8.0, 0, TAU, 24, p.guide_color, px)

func _star(at: Vector2, alpha: float, color: Color) -> void:
	for i in range(5, 0, -1):
		draw_circle(at, 5.0 + i * 5.0, Color(color, alpha * 0.025 * (6 - i)))
	draw_line(at - Vector2(0, 16), at + Vector2(0, 16), Color(color, alpha), 2.0)
	draw_line(at - Vector2(16, 0), at + Vector2(16, 0), Color(color, alpha), 2.0)
	draw_circle(at, 4.0, Color(1, 1, 1, alpha))

func _rubble(at: Vector2, spread: float, alpha: float, color: Color) -> void:
	for i in 16:
		var angle: float = i * TAU / 16.0 + intro.beat_time * 0.55
		var radius := 18.0 + spread * (95.0 + float(i % 3) * 28.0)
		var center := at + Vector2.from_angle(angle) * radius
		var triangle := PackedVector2Array([Vector2(-7, -4), Vector2(5, -6), Vector2(8, 7)])
		for j in triangle.size():
			triangle[j] = center + triangle[j].rotated(angle)
		draw_colored_polygon(triangle, Color(color.lerp(Color("577281"), 0.65), alpha))

## 星座は戦闘とは別の遠景。画面上方の小さな領域で、背景の星に重ねる。
func omen_rect() -> Rect2:
	var state: RunState = intro.run.state
	var p: IntroPresentation = intro.presentation
	var half := state.view_half
	var center := state.view_center + half * (p.sky_anchor * 2.0 - Vector2.ONE)
	var extent := minf(half.x, half.y) * 2.0 * p.sky_size
	return Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent)

## 既存の星座の絵から明るい部分を採り、瓦礫の行き先をその形に合わせる。
func _prepare_sky() -> void:
	_mist = ColorRect.new()
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist.show_behind_parent = true
	var mist_material := ShaderMaterial.new()
	mist_material.shader = preload("res://shaders/intro_sky_mist.gdshader")
	_mist.material = mist_material
	add_child(_mist)
	var texture: Texture2D = intro.presentation.unicorn_texture
	if texture == null:
		return
	var picture := texture.get_image()
	if picture.is_compressed():
		picture.decompress()
	var candidates := PackedVector2Array()
	for y in picture.get_height():
		for x in picture.get_width():
			var color := picture.get_pixel(x, y)
			if color.a > 0.25 and maxf(color.r, maxf(color.g, color.b)) > 0.25:
				candidates.append(Vector2(float(x) / picture.get_width(), float(y) / picture.get_height()) - Vector2.ONE * 0.5)
	if candidates.is_empty():
		return
	for i in 36:
		_sky_targets.append(candidates[mini(candidates.size() - 1, i * candidates.size() / 36)])

func _omen(time: float) -> void:
	var p: IntroPresentation = intro.presentation
	var bounds := omen_rect()
	var reveal := smoothstep(0.0, p.omen_time * 0.25, time)
	var gather := smoothstep(p.omen_time * 0.08, p.omen_time * 0.85, time)
	# 空の奥で固まる。前景へ近づく拡大・移動は付けない。
	var drift := Vector2(sin(time * 0.7), cos(time * 0.5)) * bounds.size.x * 0.012
	var center := bounds.get_center() + drift
	var pulse := 0.78 + sin(time * 2.6) * 0.22
	_sky_mist(center, bounds.size.x, time, reveal, pulse)
	if p.unicorn_texture == null:
		return
	var fit := minf(bounds.size.x / p.unicorn_texture.get_width(), bounds.size.y / p.unicorn_texture.get_height())
	var image_size := p.unicorn_texture.get_size() * fit
	_sky_rubble(center, image_size, bounds.size.x, time, gather, reveal)
	# 半透明の星の姿を明るく保ち、集合した瓦礫の中から輪郭を浮かせる。
	draw_texture_rect(p.unicorn_texture, Rect2(center - image_size * 0.5, image_size), false,
		Color(0.90, 0.05, 0.03, reveal * pulse * 0.86))

func _sky_rubble(center: Vector2, image_size: Vector2, extent: float, time: float, gather: float, reveal: float) -> void:
	var p: IntroPresentation = intro.presentation
	var px: float = 1.0 / maxf(0.001, intro.run.state.camera_zoom)
	for i in _sky_targets.size():
		var target := _sky_targets[i] * image_size
		var angle := float(i) * 2.399963 + time * 0.35 * (1.0 - gather)
		var outer := Vector2.from_angle(angle) * extent * (0.75 + float(i % 5) * 0.07)
		var pixel_step := px * 2.0
		var at := ((center + outer.lerp(target, gather)) / pixel_step).round() * pixel_step
		var direction := (center + target - at).normalized()
		var glow := p.sky_glow_color
		draw_line(at - direction * extent * 0.065 * (1.0 - gather), at,
			Color(glow, reveal * 0.28), px * 2.0)
		var scale := extent * (0.012 + float(i % 3) * 0.003)
		var piece := PackedVector2Array([Vector2(-1, -0.6), Vector2(0.6, -0.8), Vector2(1, 0.6), Vector2(-0.4, 1)])
		for j in piece.size():
			piece[j] = ((at + piece[j].rotated(angle) * scale) / pixel_step).round() * pixel_step
		draw_colored_polygon(piece, Color(0.32, 0.09, 0.055, reveal * (0.62 + gather * 0.15)))


## 黒いもやの中を深赤が流れる。固有の紋様を使わず、歪んだ縁の脈動で見せる。
func _sky_mist(center: Vector2, extent: float, time: float, reveal: float, _pulse: float) -> void:
	if _mist == null:
		return
	_mist.position = center - Vector2.ONE * extent * 0.84
	_mist.size = Vector2.ONE * extent * 1.68
	var mist_material := _mist.material as ShaderMaterial
	mist_material.set_shader_parameter("elapsed", time)
	mist_material.set_shader_parameter("reveal", reveal)
	mist_material.set_shader_parameter("ember_color", intro.presentation.sky_glow_color)

## 冒頭の影は仮素材。画面に対する比で構成し、正式な竜の絵へ差し替える。
func _opening(beat: int, time: float) -> void:
	var state: RunState=intro.run.state
	var focus := state.view_center+Vector2(-state.view_half.x*0.1,-state.view_half.y*0.48)
	var extent := minf(state.view_half.x,state.view_half.y)
	var progress := clampf(time/intro.presentation.devour_time,0.0,1.0) if beat==intro.Beat.DEVOUR else (1.0 if beat==intro.Beat.DEPART else 0.0)
	if beat==intro.Beat.FOCUS or (beat==intro.Beat.DEVOUR and progress<0.7): _star(focus,1.0,Color("#f3f7ff"))
	if beat==intro.Beat.FOCUS: return
	var depart := clampf(time/intro.presentation.depart_time,0.0,1.0) if beat==intro.Beat.DEPART else 0.0
	var grow := smoothstep(0.0,0.7,progress)*(1.0-depart*0.9)
	var head := focus+Vector2(extent*(1.0-progress)*2.0,-depart*extent)
	var body := PackedVector2Array()
	for j in 25:
		var t := j/24.0
		body.append(head+Vector2(t*extent*3.5,sin(t*TAU*1.5+time)*extent*0.4)*grow)
	if grow>0.01:
		draw_polyline(body,Color(0.025,0.015,0.065,1.0-depart),extent*0.24*grow,false)
		var jaw := extent*0.14*grow
		var mouth := PackedVector2Array([head+Vector2(jaw,-jaw),head-Vector2(jaw,0),head+Vector2(jaw,jaw)])
		draw_polyline(mouth,Color(0.035,0.02,0.08,1.0-depart),jaw*0.5,false)
		if progress>0.65:
			for side in [-1,1]: draw_circle(head+Vector2(jaw*0.1,side*jaw*0.38),maxf(2.0,jaw*0.08),Color(1,0.05,0.15,1.0-depart))
