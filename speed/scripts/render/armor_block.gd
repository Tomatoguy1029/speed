## 採用した pixelfx Parry B の直進火花。固定の色・粒・光は制作済みのコマ画像から再生する。
## pixelfx / Sprite Fusion impact (MIT)。画像と同じフォルダーへLICENSE・NOTICEを同梱。
extends RefCounted

const TEXTURE := preload("res://assets/effects/armor_block/armor_block.png")
const FRAME_SIZE := Vector2(160, 160)
const ORIGIN := Vector2(80.4, 80)
const COLUMNS := 7
const FRAME_COUNT := 21
const FPS := 50.0
const LIFE := FRAME_COUNT / FPS
const MAX_ACTIVE := 64
var _active: Array[Dictionary] = []

func add(pos: Vector2, normal: Vector2) -> void:
	if _active.size() >= MAX_ACTIVE:
		_active.pop_front()
	# 制作済み画像は左へ散る。法線へ向け、接触面の原点を保つ。
	_active.append({"pos": pos, "angle": normal.angle() - PI, "age": 0.0})

func update(dt: float) -> void:
	var kept := 0
	for effect in _active:
		effect.age += dt
		if effect.age < LIFE:
			_active[kept] = effect
			kept += 1
	_active.resize(kept)

func draw(c: CanvasItem) -> void:
	for effect in _active:
		var frame := mini(int(effect.age * FPS), FRAME_COUNT - 1)
		var source := Rect2(Vector2(frame % COLUMNS, floori(float(frame) / COLUMNS)) * FRAME_SIZE, FRAME_SIZE)
		c.draw_set_transform(effect.pos, effect.angle)
		c.draw_texture_rect_region(TEXTURE, Rect2(-ORIGIN, FRAME_SIZE), source)
	c.draw_set_transform(Vector2.ZERO)
