## みずがめ座の水流。専用の層とshaderは初回使用時に作る。
extends AttackVisual

const FLOOD_TAIL := 1.4
var floods: Array = []
var _flood_layer: DrawLayer

func setup(render: RenderManager) -> void:
	super(render)
	# みずがめ座の水はシェーダーで描く。頂点の色で描き方を渡すので、色を変える modulate の掛からない層にする
	_flood_layer = DrawLayer.new()
	_flood_layer.name = "Flood"
	_flood_layer.z_index = rm._layers.projectiles.z_index + 1
	_flood_layer.draw_fn = Callable(self, "_draw_floods")
	var flood_mat := ShaderMaterial.new()
	flood_mat.shader = load("res://shaders/water_flood.gdshader")
	# ノイズは作っておいた画像を使い回す
	flood_mat.set_shader_parameter("noise_tex", load("res://assets/fx/water_noise.png"))
	_flood_layer.material = flood_mat
	rm.get_node(rm.world_path).add_child(_flood_layer)
	if not rm.pipeline.rich:
		_flood_layer.visibility_layer = 1 | RenderPipeline.GLOW_LAYER

func aim(ev: Dictionary) -> void:
	var f := ev.duplicate()
	f.t = 0.0
	f.end = float(ev.delay) + float(ev.active)
	f.fired = false
	floods.append(f)

func update(dt: float) -> void:
	_update_floods(dt)
	_flood_layer.queue_redraw()

func _update_floods(dt: float) -> void:
	var enemies := rm.run.enemies
	for f in floods:
		f.t += dt
		var alive: bool = enemies.is_same(int(f.row), int(f.id)) and enemies.table.dead[int(f.row)] == 0
		if not f.fired:
			if not alive:
				f.t = 1e9
				continue
			if f.t >= float(f.delay):
				f.fired = true
				var col: Color = f.color
				rm.shake = maxf(rm.shake, 16.0)
				rm.pipeline.add_wave(f.pos, 800.0, 0.7)
				rm._burst(f.pos, col.lightened(0.3), 36, Vector2.ZERO, 760.0)
		elif f.t < float(f.end):
			if not alive:
				f.end = f.t
			else:
				rm.shake = maxf(rm.shake, 3.5)
	floods = floods.filter(func(f): return f.t < float(f.end) + FLOOD_TAIL and f.t < 1e8)

func _flood_half(width: float, spread: float, d: float) -> float:
	return width * 0.5 + maxf(d, 0.0) * tan(spread)

func _draw_floods(c: CanvasItem) -> void:
	var pr := rm.run.projectiles
	var mat := _flood_layer.material as ShaderMaterial
	# HDR の描画では頂点の色が線形に直されて届くので、シェーダーで元の値に戻す
	mat.set_shader_parameter("linear_colors", _flood_layer.get_viewport().use_hdr_2d)
	var shaped := false
	for i in pr.hazard_alive.size():
		if pr.hazard_alive[i] == 0 or pr.hazard_style[i] != ProjectileSystem.HazardStyle.FLOOD:
			continue
		if not shaped:
			# ビームの形（みずがめ座はみな同じ形）
			mat.set_shader_parameter("half0", pr.hazard_width[i] * 0.5)
			mat.set_shader_parameter("slope", tan(pr.hazard_arc[i]))
			mat.set_shader_parameter("beam_len", pr.hazard_len[i])
			shaped = true
		var t := pr.hazard_t[i]
		var delay := pr.hazard_delay[i]
		var charging := t < delay
		var k := clampf(t / maxf(delay, 0.001), 0.0, 1.0) if charging else 1.0
		_water_strip(c, pr.hazard_pos[i], pr.hazard_angle[i], pr.hazard_len[i], pr.hazard_width[i], pr.hazard_arc[i],
			0.0 if charging else 1.0 / 3.0, k, float(i % 17) / 17.0)
	for f in floods:
		if f.t < float(f.end):
			continue
		var age: float = f.t - float(f.end)
		var collapse := clampf(1.0 - age / 0.35, 0.0, 1.0)
		var life := clampf(1.0 - age / FLOOD_TAIL, 0.0, 1.0)
		var n := int(f.count)
		for k in n:
			var a := float(f.angle) + k * TAU / n
			var seed := float((int(f.id) * 7 + k) % 17) / 17.0
			if collapse > 0.0:
				_water_strip(c, f.pos, a, float(f.length), float(f.width), float(f.spread), 1.0 / 3.0, collapse, seed)
			_water_strip(c, f.pos, a, float(f.length), float(f.width), float(f.spread), 1.0, life * (1.0 - collapse * 0.6), seed)

func _water_strip(c: CanvasItem, p: Vector2, angle: float, length: float, width: float, spread: float,
		mode: float, strength: float, seed: float) -> void:
	const MARGIN := 1.12
	var u := Vector2.from_angle(angle)
	var v := Vector2(-u.y, u.x)
	var h := _flood_half(width, spread, length) * MARGIN
	var col := Color(mode, strength, seed, 1.0)
	c.draw_polygon(PackedVector2Array([p, p + u * length + v * h, p + u * length - v * h]),
		PackedColorArray([col, col, col]),
		PackedVector2Array([Vector2.ZERO, Vector2(length, h) / 1000.0, Vector2(length, -h) / 1000.0]))

