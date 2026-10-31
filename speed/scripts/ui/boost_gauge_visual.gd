## カーソルのブーストゲージ。本番HUDとビジュアル編集が同じ色・形を使う。
extends RefCounted
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
const KEY := "hud/boost_gauge"
const DEFAULT_COLORS := {
	"normal_color": Color("#5dffa0"),
	"path_color": Color("#c8f7ff"),
	"ready_pulse_color": Color(0.36, 1.0, 0.63, 1.0),
	"background_color": Color(1, 1, 1, 0.15),
	"ready_tick_color": Color(1, 1, 1, 0.9),
	"unavailable_tick_color": Color(1, 1, 1, 0.5),
	"full_flash_color": Color.WHITE,
}

static func draw(c: CanvasItem, at: Vector2, amount: float, capacity: float, min_charge: float,
		drawing: bool, usable: bool, flash: float, pulse: float, radius: float, gap: float) -> void:
	var colors := SETTINGS.values_for(KEY)
	var col: Color = colors.get("normal_color", DEFAULT_COLORS.normal_color)
	if not usable: col.a *= 0.4
	if drawing: col = colors.get("path_color", DEFAULT_COLORS.path_color)
	var width := 4.0
	if flash > 0.0:
		col = col.lerp(colors.get("full_flash_color", DEFAULT_COLORS.full_flash_color), flash)
		width += 2.0 * flash
	var laps := ceili(capacity - 1e-6)
	for lap in laps:
		var r := radius + gap * lap
		var lap_cap := minf(1.0, capacity - lap)
		var fill := clampf(amount - lap, 0.0, lap_cap)
		c.draw_arc(at, r, -PI / 2.0, -PI / 2.0 + TAU * lap_cap, 32, colors.get("background_color", DEFAULT_COLORS.background_color), 4.0)
		if fill > 0.0: c.draw_arc(at, r, -PI / 2.0, -PI / 2.0 + TAU * fill, 32, col, width)
	if not drawing:
		var tick := Vector2.from_angle(-PI / 2.0 + TAU * min_charge)
		var tick_color: Color = colors.get("ready_tick_color", DEFAULT_COLORS.ready_tick_color) if usable else colors.get("unavailable_tick_color", DEFAULT_COLORS.unavailable_tick_color)
		c.draw_line(at + tick * (radius - 4.0), at + tick * (radius + 5.0), tick_color, 2.0)
	if pulse >= 0.0:
		var pulse_color: Color = colors.get("ready_pulse_color", DEFAULT_COLORS.ready_pulse_color)
		pulse_color.a *= 1.0 - pulse
		c.draw_arc(at, radius + gap * (laps - 1) + 12.0 * pulse, 0, TAU, 32, pulse_color, 3.0)
