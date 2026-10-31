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
const DEFAULT_RADII := {"first_inner_radius": 10.0, "first_outer_radius": 18.0, "second_inner_radius": 20.0, "second_outer_radius": 22.0}
const BOUNDARY_KEYS := ["first_inner_radius", "first_outer_radius", "second_inner_radius", "second_outer_radius"]
const MIN_BAND_WIDTH := 0.5
const MAX_RADIUS := 128.0

static func _number(values: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = values.get(key, fallback)
	return float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value)) else fallback

## 旧保存値の太さを半径へ解決する。実行中は保存元を書き換えない。
static func radii_for(values: Dictionary, radius := 14.0, gap := 7.0) -> Vector4:
	var first_width := clampf(_number(values, "first_ring_width", DEFAULT_WIDTHS.first_ring_width), 1.0, 12.0)
	var second_width := clampf(_number(values, "outer_ring_width", DEFAULT_WIDTHS.outer_ring_width), 0.5, 6.0)
	var first_inner := clampf(_number(values, "first_inner_radius", radius - first_width * 0.5), 0.0, MAX_RADIUS - MIN_BAND_WIDTH)
	var first_outer := clampf(_number(values, "first_outer_radius", radius + first_width * 0.5), first_inner + MIN_BAND_WIDTH, MAX_RADIUS)
	var second_inner := clampf(_number(values, "second_inner_radius", radius + gap - second_width * 0.5), 0.0, MAX_RADIUS - MIN_BAND_WIDTH)
	var second_outer := clampf(_number(values, "second_outer_radius", radius + gap + second_width * 0.5), second_inner + MIN_BAND_WIDTH, MAX_RADIUS)
	return Vector4(first_inner, first_outer, second_inner, second_outer)

static func migrated_values(values: Dictionary) -> Dictionary:
	var result := values.duplicate(true)
	var bounds := radii_for(values)
	for index in BOUNDARY_KEYS.size(): result[BOUNDARY_KEYS[index]] = bounds[index]
	result.erase("first_ring_width")
	result.erase("outer_ring_width")
	return result

## 動かした縁を優先し、同じ帯の反対側だけを補正する。色と他の設定は保持する。
static func edited_values(values: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := migrated_values(values)
	result[key] = value
	if key in BOUNDARY_KEYS:
		var index := BOUNDARY_KEYS.find(key)
		var inner_key: String = BOUNDARY_KEYS[index - index % 2]
		var outer_key: String = BOUNDARY_KEYS[index - index % 2 + 1]
		if index % 2 == 0:
			result[inner_key] = clampf(_number(result, key, DEFAULT_RADII[key]), 0.0, MAX_RADIUS - MIN_BAND_WIDTH)
			result[outer_key] = maxf(result[outer_key], result[inner_key] + MIN_BAND_WIDTH)
		else:
			result[outer_key] = clampf(_number(result, key, DEFAULT_RADII[key]), MIN_BAND_WIDTH, MAX_RADIUS)
			result[inner_key] = minf(result[inner_key], result[outer_key] - MIN_BAND_WIDTH)
	return result

static func draw(c: CanvasItem, at: Vector2, amount: float, capacity: float, min_charge: float,
		drawing: bool, usable: bool, flash: float, pulse: float, radius: float, gap: float) -> void:
	var colors := SETTINGS.values_for(KEY)
	var col: Color = colors.get("unavailable_color", DEFAULT_COLORS.unavailable_color) if amount < 0.25 else colors.get("normal_color", DEFAULT_COLORS.normal_color)
	if drawing: col = colors.get("path_color", DEFAULT_COLORS.path_color)
	var bounds := radii_for(colors, radius, gap)
	var first_width := bounds.y - bounds.x
	if flash > 0.0:
		col = col.lerp(colors.get("full_flash_color", DEFAULT_COLORS.full_flash_color), flash)
	var laps := ceili(capacity - 1e-6)
	if laps <= 0: return
	for lap in laps:
		var inside := bounds.x if lap == 0 else bounds.z + gap * (lap - 1)
		var outside := bounds.y if lap == 0 else bounds.w + gap * (lap - 1)
		var r := (inside + outside) * 0.5
		var lap_cap := minf(1.0, capacity - lap)
		var fill := clampf(amount - lap, 0.0, lap_cap)
		var width := outside - inside
		c.draw_arc(at, r, -PI / 2.0, -PI / 2.0 + TAU * lap_cap, 32, colors.get("background_color", DEFAULT_COLORS.background_color), width)
		if fill > 0.0: c.draw_arc(at, r, -PI / 2.0, -PI / 2.0 + TAU * fill, 32, col, minf(r * 2.0, width + 2.0 * flash))
	if not drawing:
		var tick := Vector2.from_angle(-PI / 2.0 + TAU * min_charge)
		var tick_color: Color = colors.get("ready_tick_color", DEFAULT_COLORS.ready_tick_color) if usable else colors.get("unavailable_tick_color", DEFAULT_COLORS.unavailable_tick_color)
		var tick_width := minf(maxf(0.5, _number(colors, "tick_width", DEFAULT_WIDTHS.tick_width)), first_width * 0.5)
		var half_stroke := tick_width * 0.5
		var outside := bounds.y
		# 線の角と端の半幅まで第一周の外縁へ収める。第二周には渡さない。
		var end := sqrt(maxf(0.0, outside * outside - half_stroke * half_stroke)) - half_stroke
		var start := bounds.x + half_stroke
		c.draw_line(at + tick * start, at + tick * maxf(start, end), tick_color, tick_width)
	if pulse >= 0.0:
		var pulse_color: Color = colors.get("ready_pulse_color", DEFAULT_COLORS.ready_pulse_color)
		pulse_color.a *= 1.0 - pulse
		var outermost := (bounds.x + bounds.y) * 0.5 if laps == 1 else (bounds.z + bounds.w) * 0.5 + gap * (laps - 2)
		c.draw_arc(at, outermost + 12.0 * pulse, 0, TAU, 32, pulse_color, 3.0)
