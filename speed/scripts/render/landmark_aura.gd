## 制作時に焼いた敵の距離場を使う目印。画像の取得・解析・生成を描画中に行わない。
extends Node2D
const ASSETS_PATH := "res://assets/effects/landmark/masks.tres"
const MATERIAL_PATH := "res://data/visuals/landmark_aura_material.tres"
var _assets: Resource
var _masks: Dictionary
var _sprites: Array[Sprite2D] = []
var _material: ShaderMaterial
var _clock := -INF
var _pump_full := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _count := 0

func setup(scope: ContentResourceScope) -> void:
	for path in [ASSETS_PATH, MATERIAL_PATH]:
		assert(scope.resources.has(path), "目印オーラの事前準備が必要: " + path)
	_assets = scope.resources.get(ASSETS_PATH)
	var template := scope.resources.get(MATERIAL_PATH) as ShaderMaterial
	if _assets == null or template == null: return
	_masks = _assets.get_meta("masks", {})
	# ランごとの時刻だけを独立させ、すべての可視部で同じmaterialを共有する。
	_material = template.duplicate() as ShaderMaterial
	_material.set_shader_parameter("linear_colors", RenderingServer.get_current_rendering_method() != "gl_compatibility")
	# 目印は同時に2体。三角2体でも、それぞれ3つの可視部へ表示する。
	for slot in 6:
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material = _material
		sprite.hide()
		add_child(sprite)
		_sprites.append(sprite)

## 編集画面も本番も同じマスクの寸法・変形条件を使う。
static func configure(sprite: Sprite2D, entry: Dictionary, instance_values := false) -> void:
	sprite.texture = entry.texture
	var values := {"mask_size": sprite.texture.get_size(), "mask_padding": float(entry.padding), "pump_mask": bool(entry.get("pump", false))}
	for key in values:
		if instance_values:
			sprite.set_instance_shader_parameter(key, values[key])
		else:
			(sprite.material as ShaderMaterial).set_shader_parameter(key, values[key])

func begin() -> void:
	_count = 0
	for sprite in _sprites: sprite.hide()

## Frameの本体と同じ姿勢・寸法を使う。分離部位はC++が個別の行で返す。
func add_body(body: Dictionary, clock: float) -> void:
	if _sprites.is_empty() or _count >= _sprites.size(): return
	var key: String = body.key
	if not _masks.has(key): return
	var entry: Dictionary = _masks[key]
	var slot := _count
	var sprite := _sprites[slot]
	_count += 1
	if sprite.texture != entry.texture: configure(sprite, entry, true)
	var pose: Transform2D = body.pose
	pose = pose.scaled_local(Vector2.ONE / float(entry.source_radius))
	sprite.transform = pose
	if _clock != clock:
		_clock = clock
		_material.set_shader_parameter("clock", _clock)
	var full: float = body.get("pump_full",0.0)
	if _pump_full[slot] != full:
		_pump_full[slot] = full
		sprite.set_instance_shader_parameter("pump_full", full)
	sprite.show()
