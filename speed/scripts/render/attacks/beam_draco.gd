## りゅう座の吐き出しの光線。口元の光の溜めと、口から伸びる光線を専用の層とshaderで描く。
## 光線の長さは判定と同じ hazard_len を使うので、伸びていく見た目と当たりが一致する。
extends AttackVisual

## 光線が消えるときに薄れる時間
const FADE := 0.15
var _layer: DrawLayer

func setup(render: RunPresentation) -> void:
	super(render)
	# 頂点の色で描き方を渡すので、色を変える modulate の掛からない層にする
	_layer = DrawLayer.new()
	_layer.name = "DracoBeam"
	_layer.z_index = rm._layers.projectiles.z_index + 1
	_layer.draw_fn = Callable(self, "_draw_beams")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/draco_beam.gdshader")
	mat.set_shader_parameter("noise_tex", load("res://assets/fx/water_noise.png"))
	_layer.material = mat
	rm.get_node(rm.world_path).add_child(_layer)
	if not rm.pipeline.rich:
		_layer.visibility_layer = 1 | RenderPipeline.GLOW_LAYER

## 共通の弾の描画では描かず、専用の層に任せる。
func draw_hazard(_c: CanvasItem, _pr: ProjectileSystem, _i: int, _view: Rect2) -> void:
	pass

func update(_dt: float) -> void:
	_layer.queue_redraw()

func _draw_beams(c: CanvasItem) -> void:
	var pr := rm.run.projectiles
	var mat := _layer.material as ShaderMaterial
	# HDR の描画では頂点の色が線形に直されて届くので、shaderで元の値に戻す
	mat.set_shader_parameter("linear_colors", _layer.get_viewport().use_hdr_2d)
	mat.set_shader_parameter("clock", rm.state.world_time)
	mat.set_shader_parameter("pixel", _px(2.0))
	for i in pr.hazard_alive.size():
		if pr.hazard_visual[i] != null and pr.hazard_visual[i].resource_path != scene_file_path: continue
		if pr.hazard_alive[i] == 0 or pr.hazard_style[i] != ProjectileSystem.HazardStyle.DRACO:
			continue
		# 判定は幅の半分まで。光線の太い所が判定の幅と一致する。
		var half := pr.hazard_width[i] * 0.5
		var col: Color = pr.hazard_color[i]
		mat.set_shader_parameter("half0", half)
		mat.set_shader_parameter("tint", Vector3(col.r, col.g, col.b))
		var seed := float(i % 17) / 17.0
		var t := pr.hazard_t[i]
		var delay := pr.hazard_delay[i]
		var at := pr.hazard_pos[i]
		var angle := pr.hazard_angle[i]
		if t < delay:
			_orb(c, at, half, clampf(t / maxf(delay, 0.001), 0.0, 1.0), seed)
			continue
		var remaining := delay + pr.hazard_active[i] - t
		var strength := clampf(remaining / FADE, 0.0, 1.0)
		var length := pr.hazard_len[i]
		mat.set_shader_parameter("beam_len", length)
		if length > 1.0: _strip(c, at, angle, length, half, strength, seed)
		# 撃っている間も口元の光を残す
		_orb(c, at, half, strength, seed)

## 口元の光の溜め。口を中心にした正方形に描く。
func _orb(c: CanvasItem, at: Vector2, half: float, strength: float, seed: float) -> void:
	var size := half * 2.8
	var col := Color(0.0, strength, seed, 1.0)
	var corners := [Vector2(-size, -size), Vector2(size, -size), Vector2(size, size), Vector2(-size, size)]
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(at + corner)
		uvs.append(corner / 1000.0)
	c.draw_polygon(points, PackedColorArray([col, col, col, col]), uvs)

## 口から光線の先までの帯。横は判定の幅より少し広く取り、外側の揺らぎを描く余白にする。
func _strip(c: CanvasItem, at: Vector2, angle: float, length: float, half: float, strength: float, seed: float) -> void:
	var u := Vector2.from_angle(angle)
	var v := u.orthogonal()
	var h := half * 1.6
	var col := Color(1.0, strength, seed, 1.0)
	c.draw_polygon(PackedVector2Array([at - v * h, at + u * length - v * h, at + u * length + v * h, at + v * h]),
		PackedColorArray([col, col, col, col]),
		PackedVector2Array([Vector2(0.0, -h) / 1000.0, Vector2(length, -h) / 1000.0, Vector2(length, h) / 1000.0, Vector2(0.0, h) / 1000.0]))
