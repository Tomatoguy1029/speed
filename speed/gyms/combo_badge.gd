## Crit number のbitmap字形・傾斜・硬いspringを使う制作描画。消失せず保持する。
## Adapted from pixelfx a841596 font.js / ui/crit-number.js, Patch / Hugo Duprez, MIT.
## See assets/ui/rewards/pixelfx_LICENSE.txt and pixelfx_NOTICE.txt.
extends Control

const BIG := {
	"×": ".....|.....|#...#|.#.#.|..#..|.#.#.|#...#",
	"2": ".###.|#...#|....#|...#.|..#..|.#...|#####",
	"3": "#####|...#.|..#..|...#.|....#|#...#|.###.",
	"4": "...#.|..##.|.#.#.|#..#.|#####|...#.|...#.",
}
const MINI := {
	"C": ".##|#..|#..|#..|.##", "O": ".#.|#.#|#.#|#.#|.#.",
	"M": "#.#|###|###|#.#|#.#", "B": "##.|#.#|##.|#.#|##.",
}
var settings: ComboTransitionSettings
var step := 2
var age := -1.0
var _number: Array[Vector2] = []
var _word: Array[Vector2] = []

func configure(value: ComboTransitionSettings, count: int) -> void:
	settings = value
	step = count
	_number = _pixels("×" + str(step), BIG, 4.0, 1.0)
	_word = _pixels("COMBO", MINI, 2.0, 0.5)
	queue_redraw()

func set_age(value: float) -> void:
	age = value
	visible = age >= 0.0
	queue_redraw()

func _pixels(text: String, glyphs: Dictionary, pixel: float, lean: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var x := 0.0
	for letter in text:
		var rows: PackedStringArray = String(glyphs[letter]).split("|")
		for y in rows.size():
			for col in rows[y].length():
				if rows[y][col] == "#": points.append(Vector2(x + col * pixel + (rows.size() - 1 - y) * lean, y * pixel))
		x += (rows[0].length() + 1) * pixel
	for i in points.size(): points[i].x -= (x - pixel) * 0.5
	return points

func _draw() -> void:
	if settings == null or age < 0.0: return
	var spring := settings.badge_pop * exp(-age * settings.badge_spring_decay) * cos(age * settings.badge_spring_frequency)
	var factor := settings.badge_size * maxf(0.05, 1.0 + spring)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * factor)
	var glow := settings.badge_face
	glow.a *= settings.badge_glow * 0.035
	for i in 4: draw_circle(Vector2(0, -2), settings.badge_glow_radius * (1.0 - i * 0.15), glow)
	var speed := clampf(age / settings.badge_lines_seconds, 0.0, 1.0)
	if speed > 0.0 and speed < 1.0:
		for i in 10:
			var direction := Vector2.from_angle(i * TAU / 10.0 + 0.1)
			var start := direction * Vector2(35, 25) * (1.0 + speed * 0.5)
			var color := settings.badge_lines_color
			color.a *= settings.badge_lines_opacity * (1.0 - speed)
			draw_line(start, start + direction * 12.0 * (1.0 - speed) * settings.badge_lines_size, color)
	for i in settings.badge_sparks:
		var life := settings.badge_effect_seconds
		var t := age - float(i % 4) * 0.025
		if t < 0.0 or t >= life: continue
		var direction := Vector2.from_angle(i * 2.39996 + step)
		var point := direction * Vector2(31.0 + t * 20.0, 22.0 + t * 15.0)
		var color := settings.badge_lines_color
		color.a *= settings.badge_lines_opacity * (1.0 - t / life)
		draw_rect(Rect2(point.floor(), Vector2.ONE * maxf(1.0, 2.0 * settings.badge_lines_size)), color)
	var number_at := Vector2(-3, -11)
	_paint(_number, 4.0, number_at + Vector2(2, 3), settings.badge_shadow, 0.0)
	_paint(_number, 4.0, number_at, settings.badge_outline, settings.badge_outline_width)
	for p in _number:
		var color := settings.badge_edge if p.y <= 4 else settings.badge_under if p.y >= 20 else settings.badge_face
		if age < 0.045: color = settings.badge_edge
		draw_rect(Rect2(number_at + p, Vector2(4, 4)), color)
	# The mini label and its leaning plate retain the Crit number hierarchy.
	var tag_at := Vector2(-6, -29)
	var tag_color := settings.badge_tag
	draw_colored_polygon(PackedVector2Array([tag_at + Vector2(-23, -3), tag_at + Vector2(26, -3), tag_at + Vector2(23, 13), tag_at + Vector2(-26, 13)]), tag_color)
	draw_line(tag_at + Vector2(-23, -3), tag_at + Vector2(26, -3), settings.badge_tag_edge, 2.0)
	_paint(_word, 2.0, tag_at, settings.badge_tag_text, 0.0)
	draw_set_transform(Vector2.ZERO)

func _paint(pixels: Array[Vector2], size_px: float, at: Vector2, color: Color, outline: float) -> void:
	for p in pixels: draw_rect(Rect2(at + p - Vector2.ONE * outline, Vector2.ONE * (size_px + outline * 2.0)), color)
