## 結果表示の枠と文字。HUDの演出時間を使い、画面サイズに合わせて描く。
extends RefCounted

const CYAN := Color("#5bc8db")
const WHITE := Color("#f1fbff")
const GOLD := Color("#efcb70")
const PANEL := Color("#081722")

static func draw(canvas: Control, font: Font, text: String, progress: float, cleared: bool) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var scale := minf(canvas.size.x / 400.0, canvas.size.y / 320.0)
	var center := canvas.size * 0.5
	if not cleared:
		_draw_power_off(canvas, font, text, t, scale, center)
		return
	var enter := 1.0 - pow(1.0 - clampf(t / 0.26, 0.0, 1.0), 3.0)
	var exit := smoothstep(0.72, 0.98, t)
	var fade := 1.0 - smoothstep(0.82, 1.0, t)
	var accent := CYAN if cleared else CYAN.lerp(Color("#8296a2"), 0.6)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(PANEL, 0.35 * enter * fade))
	canvas.draw_set_transform(center, 0.0, Vector2.ONE * scale)
	# 太さのある円弧が集まり、終了時には外へ分かれる。
	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var direction := Vector2.from_angle(angle)
		var offset := direction * (18.0 * (1.0 - enter) + exit * 78.0)
		if enter > 0.001:
			canvas.draw_arc(offset, 116.0 * enter, angle - 0.3, angle + 0.3, 40, Color(CYAN, 0.12 * enter * fade), 22.0 * enter, true)
			canvas.draw_arc(offset, 127.0 * enter, angle - 0.3, angle + 0.3, 40, Color(CYAN, 0.65 * enter * fade), 1.2, true)
			canvas.draw_arc(offset, 116.0 * enter, angle - 0.3, angle - 0.1, 20, Color(WHITE, 0.28 * enter * fade), 3.0, true)
	var radius := lerpf(8.0, 108.0, enter)
	canvas.draw_circle(Vector2.ZERO, radius, Color(PANEL, 0.55 * enter * fade))
	for i in 3:
		var r := radius * (1.0 - i * 0.16)
		canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 128, Color(accent, fade * (0.42 - i * 0.12)), 1.0, true)
	var extent := lerpf(10.0, 143.0, enter)
	for inset in [0.0, 6.0]:
		var d: float = extent - inset
		var points := PackedVector2Array([Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0), Vector2(0, -d)])
		canvas.draw_polyline(points, Color(accent, fade * (0.5 if inset == 0.0 else 0.16)), 1.5 if inset == 0.0 else 0.8, true)
	# 目盛りは円と一緒に広がり、文字の帯より奥へ置く。
	for i in 12:
		var direction := Vector2.from_angle(TAU * i / 12.0)
		canvas.draw_line(direction * (radius + 4.0), direction * (radius + 8.0), Color(accent, enter * fade * 0.5), 1.0, true)
		var particle := direction.rotated(0.07 * sin(t * 4.0 + i)) * (radius + 16.0 + exit * (35.0 + i % 3 * 14.0))
		var particle_color := GOLD if i % 3 == 0 else WHITE
		canvas.draw_circle(particle, 5.0, Color(particle_color, enter * fade * 0.06), true, -1.0, true)
		canvas.draw_circle(particle, 1.5 if i % 3 == 0 else 0.8, Color(particle_color, enter * fade * 0.85), true, -1.0, true)
	var burst := clampf(t / 0.2, 0.0, 1.0)
	for i in 16:
		var direction := Vector2.from_angle(TAU * i / 16.0)
		canvas.draw_line(direction * radius, direction * (radius + 20.0 * burst), Color(WHITE, (1.0 - burst) * fade), 1.5, true)
	if cleared:
		var rail := smoothstep(0.08, 0.32, t)
		var half_width := 174.0 * rail * (1.0 - exit * 0.4)
		# 暗い帯で文字と背景の装飾を分け、上下の横線を前へ通す。
		canvas.draw_rect(Rect2(-half_width, -39.0, half_width * 2.0, 78.0), Color(PANEL, 0.96 * rail * fade))
		for side in [-1.0, 1.0]:
			var y: float = side * (40.0 + exit * 60.0)
			canvas.draw_line(Vector2(-half_width, y), Vector2(half_width, y), Color(accent, rail * fade * 0.08), 7.0, true)
			canvas.draw_line(Vector2(-half_width, y), Vector2(half_width, y), Color(accent, rail * fade), 1.5, true)
			canvas.draw_line(Vector2(-half_width * 0.9, y + side * 6.0), Vector2(half_width * 0.9, y + side * 6.0), Color(accent, rail * fade * 0.3), 0.8, true)
			for end in [-1.0, 1.0]:
				canvas.draw_circle(Vector2(end * half_width, y), 2.0, Color(WHITE, rail * fade), true, -1.0, true)
		for side in [-1.0, 1.0]:
			var at := Vector2(side * (153.0 + exit * 55.0), 0.0)
			var points := PackedVector2Array([at + Vector2(-side * 8, -14), at + Vector2(side * 5, 0), at + Vector2(-side * 8, 14), at])
			canvas.draw_colored_polygon(points, Color(CYAN, rail * fade))
		_draw_glint(canvas, Vector2(0, -66), 11.0, enter * fade)
		canvas.draw_arc(Vector2(0, -66), 18.0, PI * 0.15, PI * 0.85, 40, Color(GOLD, enter * fade * 0.5), 0.8, true)
		canvas.draw_arc(Vector2(0, -66), 18.0, PI * 1.15, PI * 1.85, 40, Color(GOLD, enter * fade * 0.5), 0.8, true)
	var text_in := smoothstep(0.18, 0.34, t)
	if text_in > 0.0:
		var zoom := lerpf(1.25, 1.0, text_in)
		var font_size := 44 if cleared else 30
		canvas.draw_set_transform(center, 0.0, Vector2(scale * zoom, scale * zoom * (1.0 - exit * 0.55)))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := Vector2(-width * 0.5, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
		canvas.draw_string_outline(font, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(PANEL, text_in * fade))
		canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 1, Color(WHITE, text_in * fade))
		canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(WHITE, text_in * fade))
	elif t > 0.0 and t < 0.18:
		var star := 24.0 * sin(PI * t / 0.18)
		var inner := star * 0.15
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -star), Vector2(inner, -inner), Vector2(star, 0), Vector2(inner, inner), Vector2(0, star), Vector2(-inner, inner), Vector2(-star, 0), Vector2(-inner, -inner)]), Color(WHITE, fade))
	canvas.draw_set_transform(Vector2.ZERO)

## 曲線で絞った四芒星と控えめな周辺光を、文字と同じ滑らかさで描く。
static func _draw_glint(canvas: Control, at: Vector2, radius: float, alpha: float) -> void:
	canvas.draw_circle(at, radius * 1.6, Color(GOLD, alpha * 0.04), true, -1.0, true)
	canvas.draw_circle(at, radius * 0.9, Color(GOLD, alpha * 0.08), true, -1.0, true)
	var points := PackedVector2Array()
	for i in 64:
		var angle := TAU * i / 64.0
		var x := cos(angle)
		var y := sin(angle)
		points.append(at + Vector2(x * x * x, y * y * y * 1.25) * radius)
	canvas.draw_colored_polygon(points, Color(GOLD, alpha))
	points.append(points[0])
	canvas.draw_polyline(points, Color(WHITE, alpha * 0.65), 0.7, true)
	canvas.draw_circle(at, 1.4, Color(WHITE, alpha), true, -1.0, true)

## 全画面を上下から閉じ、中央の走査線を光点へ縮めて暗転を保つ。
static func _draw_power_off(canvas: Control, font: Font, text: String, t: float, scale: float, center: Vector2) -> void:
	var appear := smoothstep(0.02, 0.16, t)
	var collapse := smoothstep(0.58, 0.8, t)
	var pinch := smoothstep(0.8, 0.94, t)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(PANEL, 0.7 * appear))
	var opening := canvas.size.y * 0.5 * (1.0 - collapse)
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(canvas.size.x, center.y - opening)), Color.BLACK)
	canvas.draw_rect(Rect2(Vector2(0, center.y + opening), Vector2(canvas.size.x, center.y - opening)), Color.BLACK)
	canvas.draw_set_transform(center, 0.0, Vector2(scale, scale * maxf(0.003, 1.0 - collapse)))
	if t < 0.8:
		var jitter := 2.0 * sin(t * 170.0) if t > 0.5 else 0.0
		canvas.draw_rect(Rect2(-163, -39, 326, 78), Color(PANEL, appear))
		for side in [-1.0, 1.0]:
			canvas.draw_line(Vector2(-160, side * 42), Vector2(160, side * 42), Color(CYAN, appear * 0.65), 2.0, false)
		var font_size := 32
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := Vector2(-width * 0.5 + jitter, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
		canvas.draw_string(font, pos + Vector2(2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(CYAN, 0.45 * appear))
		canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(WHITE, appear))
	canvas.draw_set_transform(Vector2.ZERO)
	if t > 0.08 and t < 0.8:
		for i in 22:
			var y := fposmod(i * 19.0 + t * 90.0, canvas.size.y)
			if absf(y - center.y) < opening:
				canvas.draw_line(Vector2(0, y), Vector2(canvas.size.x, y), Color(CYAN, 0.06 * appear), 1.0, false)
	if t >= 0.58:
		var half_width := canvas.size.x * 0.42 * (1.0 - pinch)
		var light := 1.0 - smoothstep(0.94, 1.0, t)
		canvas.draw_line(center - Vector2(half_width, 0), center + Vector2(half_width, 0), Color(CYAN, light * collapse * 0.35), 6.0, false)
		canvas.draw_line(center - Vector2(half_width, 0), center + Vector2(half_width, 0), Color(WHITE, light * collapse), 2.0, false)
		if t >= 0.9:
			canvas.draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), Color(WHITE, light))
