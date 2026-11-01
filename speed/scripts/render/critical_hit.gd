## 短い局所クリティカル。制作済みの星・弧・16本の火花と小さなCRITを再生する。
## pixelfx / Sprite Fusion impact (MIT)。素材ResourceにLICENSE・NOTICEを同梱。
extends RefCounted

const ASSETS: CriticalHitAssets = preload("res://data/visuals/critical_hit.tres")
const MAX_ACTIVE := 64
var _active: Array[Dictionary] = []

func add(pos: Vector2, label_pos: Vector2, direction: Vector2) -> void:
	if _active.size() >= MAX_ACTIVE:
		_active.pop_front()
	_active.append({"pos": pos, "label_pos": label_pos, "angle": direction.angle(), "age": 0.0})

func update(dt: float) -> void:
	for effect in _active:
		effect.age += dt
	_active = _active.filter(func(effect): return effect.age < ASSETS.effect_life)

func draw(c: CanvasItem, zoom: float) -> void:
	var pixel := 1.0 / maxf(zoom, 0.01)
	var size := Vector2(ASSETS.effect_frame_size) * ASSETS.effect_scale * pixel
	for effect in _active:
		var age: float = effect.age
		var frame := mini(int(age * ASSETS.fps), ASSETS.effect_frames - 1)
		c.draw_set_transform(effect.pos, effect.angle)
		var source := _frame_rect(frame, ASSETS.effect_frame_size)
		c.draw_texture_rect_region(ASSETS.texture, Rect2(-ASSETS.effect_origin * ASSETS.effect_scale * pixel, size), source)
		c.draw_set_transform(Vector2.ZERO)
		if age >= ASSETS.label_life:
			continue
		frame = mini(int(age * ASSETS.fps), ASSETS.label_frames - 1)
		source = _frame_rect(frame, ASSETS.label_frame_size)
		source.position += Vector2(ASSETS.label_atlas_origin)
		var label_size := Vector2(ASSETS.label_frame_size) * pixel
		var label_pos: Vector2 = effect.label_pos - Vector2(label_size.x * 0.5, label_size.y + ASSETS.label_rise * age * pixel)
		c.draw_texture_rect_region(ASSETS.texture, Rect2(label_pos, label_size), source)

func _frame_rect(frame: int, size: Vector2i) -> Rect2:
	var row := floori(float(frame) / ASSETS.columns)
	return Rect2(Vector2((frame % ASSETS.columns) * size.x, row * size.y), Vector2(size))
