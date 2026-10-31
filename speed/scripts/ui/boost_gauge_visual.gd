## カーソルのブーストゲージ。本番HUDとビジュアル編集が同じ色・形を使う。
extends RefCounted
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
const KEY := "hud/boost_gauge"
const DEFAULT_COLORS := {
	"normal_color": Color("#5dffa0"),
	"unavailable_color": Color("#ffb35c"),
	"path_color": Color("#c8f7ff"),
	"ready_pulse_color": Color(0.36, 1.0, 0.63, 1.0),
	"background_color": Color(1, 1, 1, 0.15),
	"ready_tick_color": Color(1, 1, 1, 0.9),
	"unavailable_tick_color": Color(1, 1, 1, 0.5),
	"full_flash_color": Color.WHITE,
}
const DEFAULT_WIDTHS := {"first_ring_width": 8.0, "outer_ring_width": 2.0, "tick_width": 2.0}

static func draw(c: CanvasItem, at: Vector2, amount: float, capacity: float, min_charge: float,
		drawing: bool, usable: bool, flash: float, pulse: float, radius: float, gap: float) -> void:
	var colors := SETTINGS.values_for(KEY)
	var col: Color = colors.get("unavailable_color", DEFAULT_COLORS.unavailable_color) if amount < 0.25 else colors.get("normal_color", DEFAULT_COLORS.normal_color)
	if drawing: col = colors.get("path_color", DEFAULT_COLORS.path_color)
	var first_width := clampf(float(colors.get("first_ring_width", DEFAULT_WIDTHS.first_ring_width)), 1.0, 12.0)
	var outer_width := clampf(float(colors.get("outer_ring_width", DEFAULT_WIDTHS.outer_ring_width)), 0.5, 6.0)
	if flash > 0.0:
		col = col.lerp(colors.get("full_flash_color", DEFAULT_COLORS.full_flash_color), flash)
	var laps := ceili(capacity - 1e-6)
	for lap in laps:
		var r := radius + gap * lap
		var lap_cap := minf(1.0, capacity - lap)
		var fill := clampf(amount - lap, 0.0, lap_cap)
		var width := first_width if lap == 0 else outer_width
		c.draw_arc(at, r, -PI / 2.0, -PI / 2.0 + TAU * lap_cap, 32, colors.get("background_color", DEFAULT_COLORS.background_color), width)
		if fill > 0.0: c.draw_arc(at, r, -PI / 2.0, -PI / 2.0 + TAU * fill, 32, col, width + 2.0 * flash)
	if not drawing:
		var tick := Vector2.from_angle(-PI / 2.0 + TAU * min_charge)
		var tick_color: Color = colors.get("ready_tick_color", DEFAULT_COLORS.ready_tick_color) if usable else colors.get("unavailable_tick_color", DEFAULT_COLORS.unavailable_tick_color)
		var tick_width := clampf(float(colors.get("tick_width", DEFAULT_WIDTHS.tick_width)), 0.5, first_width * 0.5)
		var half_stroke := tick_width * 0.5
		var outside := radius + first_width * 0.5
		# 線の角と端の半幅まで第一周の外縁へ収める。第二周には渡さない。
		var end := sqrt(maxf(0.0, outside * outside - half_stroke * half_stroke)) - half_stroke
		var start := radius - first_width * 0.5 + half_stroke
		c.draw_line(at + tick * start, at + tick * maxf(start, end), tick_color, tick_width)
	if pulse >= 0.0:
		var pulse_color: Color = colors.get("ready_pulse_color", DEFAULT_COLORS.ready_pulse_color)
		pulse_color.a *= 1.0 - pulse
		c.draw_arc(at, radius + gap * (laps - 1) + 12.0 * pulse, 0, TAU, 32, pulse_color, 3.0)
