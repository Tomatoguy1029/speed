## 制作済みの核と尾を再生する。画像の切り出し範囲と配色は素材側で確定する。
extends RefCounted

const TAILS := [preload("res://assets/fx/comets/normal_tail.png"), preload("res://assets/fx/comets/rare_tail.png")]
const CORES := [preload("res://assets/fx/comets/normal_core.tres"), preload("res://assets/fx/comets/rare_core.tres")]
const FRAME_SIZE := Vector2(248, 128)
const TAIL_ORIGIN := Vector2(190, 60)
const CORE_SIZE := Vector2(30, 24)

static func frame_at(age: float) -> int:
	return posmod(floori(maxf(0.0, age) * 30.0), 36)

static func sway_at(age: float) -> float:
	return roundf(2.0 * sin(maxf(0.0, age) * TAU / 3.6))

static func draw(c: CanvasItem, pos: Vector2, radius: float, velocity: Vector2, rare: bool, age: float) -> void:
	var variant := 1 if rare else 0
	var frame := frame_at(age)
	var source := Rect2(Vector2(frame % 5, frame / 5) * FRAME_SIZE, FRAME_SIZE)
	var angle := velocity.angle() if velocity.length_squared() > 1.0 else 0.0
	# 核の幅を当たり判定の直径に合わせ、尾と揺れも同じ比率で表示する。
	c.draw_set_transform(pos, angle, Vector2.ONE * (radius * 2.0 / CORE_SIZE.x))
	c.draw_texture_rect(CORES[variant], Rect2(-CORE_SIZE * 0.5 + Vector2(0, sway_at(age)), CORE_SIZE), false)
	# 核の上に、不透明度を変えずに冷気を重ねる。
	c.draw_texture_rect_region(TAILS[variant], Rect2(-TAIL_ORIGIN, FRAME_SIZE), source)
	c.draw_set_transform(Vector2.ZERO)
