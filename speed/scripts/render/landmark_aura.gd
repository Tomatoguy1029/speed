## 制作時に焼いた敵の距離場を使う目印。画像の取得・解析・生成を描画中に行わない。
extends Node2D
const ASSETS_PATH := "res://assets/effects/landmark/masks.tres"
const SETTINGS_PATH := "res://data/visuals/landmark_mark.tres"
const SHADER := preload("res://shaders/build_aura.gdshader")
const NOISE := preload("res://assets/effects/build/aura_noise.png")
var _rm: RunPresentation
var _assets: Resource
var _settings: EnemyMarkSettings
var _masks: Dictionary
var _sprites: Array[Sprite2D] = []
var _count := 0

func setup(render: RunPresentation) -> void:
	_rm = render
	var scope := render.run.ctx.resources
	for path in [ASSETS_PATH, SETTINGS_PATH]:
		if not scope.resources.has(path) and render.state.lab_mode:
			# 実験場だけは任意の追加対象を開始時に取得し、同じScopeへ渡す。
			scope.provide(path, load(path))
		assert(scope.resources.has(path), "目印オーラの事前準備が必要: " + path)
	_assets = scope.resources.get(ASSETS_PATH)
	_settings = scope.resources.get(SETTINGS_PATH) as EnemyMarkSettings
	if _assets == null or _settings == null: return
	_masks = _assets.get_meta("masks", {})
	# 目印は同時に1体。見えない三角の中心だけは3つの可視部へ表示する。
	for slot in 3:
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("noise_tex", NOISE)
		_settings.apply_aura_to(mat)
		sprite.material = mat
		sprite.hide()
		add_child(sprite)
		_sprites.append(sprite)

## 編集画面も本番も同じマスクの寸法・変形条件を使う。
static func configure(sprite: Sprite2D, entry: Dictionary) -> void:
	sprite.texture = entry.texture
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("mask_size", sprite.texture.get_size())
	mat.set_shader_parameter("mask_padding", float(entry.padding))
	mat.set_shader_parameter("pump_mask", bool(entry.get("pump", false)))

func begin() -> void:
	_count = 0
	for sprite in _sprites: sprite.hide()

func add_enemy(t: EnemyTable, row: int, deformation: Dictionary = {}) -> void:
	if _sprites.is_empty(): return
	if t.def[row] != null and t.def[row].behavior == &"triangle":
		var parts := t.parts[row]
		for n in range(0, parts.size(), 2):
			var child := parts[n]
			if _rm.run.enemies.is_same(child, parts[n + 1]) and t.dead[child] == 0:
				_add_body(t, child, {})
	else:
		_add_body(t, row, deformation)

func _add_body(t: EnemyTable, row: int, deformation: Dictionary) -> void:
	var type := t.type[row]
	var look := _rm.look_of(type)
	var key: String
	var angle := _rm._enemy_sprite_angle(type, t.facing[row])
	if look != null:
		if look.split_other != null:
			if t.buds[row] == 1: look = look.split_other
			angle = t.facing[row] + look.angle
		key = look.source_path
		if look.split_other != null and t.buds[row] == 0: key += ":joined"
	else:
		key = "sprite:" + String(type)
		if not _masks.has(key):
			key = "shape:" + String(t.def[row].shape)
			angle = t.facing[row]
	assert(_masks.has(key), "目印マスクのベイクが必要: " + key)
	if not _masks.has(key) or _count >= _sprites.size(): return
	var entry: Dictionary = _masks[key]
	var scale_px := _rm.enemy_sprite_radius(type, t.r[row]) / float(entry.source_radius)
	var full := 0.0
	if entry.get("pump", false):
		var visual := _rm._visual_of(t, row)
		scale_px = visual._source_scale(t, row)
		full = 1.0 if t.mode[row] == EnemyTable.Mode.WINDUP else clampf((t.r[row] / maxf(visual._base_radius(t, row), 0.001) - 1.0) / maxf(float(t.def[row].params.grow), 0.001), 0.0, 1.0)
	var sprite := _sprites[_count]
	_count += 1
	if sprite.texture != entry.texture: configure(sprite, entry)
	var pose := Transform2D(angle, t.pos[row]).scaled_local(Vector2.ONE * scale_px)
	if not deformation.is_empty():
		var radial: Vector2 = deformation.direction
		if radial.length_squared() >= 0.0001:
			var n := radial.normalized()
			var side := n.orthogonal()
			for column in 2:
				var basis := pose[column]
				pose[column] = n * basis.dot(n) * (1.0 - 0.5 * deformation.amount) + side * basis.dot(side) * (1.0 + 0.6 * deformation.amount)
	sprite.transform = pose
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("clock", _rm.state.world_time)
	mat.set_shader_parameter("pump_full", full)
	sprite.show()
