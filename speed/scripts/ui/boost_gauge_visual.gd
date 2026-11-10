## カーソルのブーストゲージ。本番HUDとビジュアル編集が同じ色・形を使う。
extends RefCounted
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

## 制作画面だけで現在の調整値を解決する。本番は保存済みのStyleを共有する。
static func style_for(values: Dictionary, radius := 14.0, gap := 7.0) -> BoostGaugeStyle:
	var style := BoostGaugeStyle.new()
	for key in DEFAULT_COLORS: style.set(key, values.get(key, DEFAULT_COLORS[key]))
	style.bounds = radii_for(values, radius, gap)
	style.tick_width = minf(maxf(0.5, _number(values, "tick_width", DEFAULT_WIDTHS.tick_width)), (style.bounds.y - style.bounds.x) * 0.5)
	var half_stroke := style.tick_width * 0.5
	style.tick_start = style.bounds.x + half_stroke
	style.tick_end = maxf(style.tick_start, sqrt(maxf(0.0, style.bounds.y * style.bounds.y - half_stroke * half_stroke)) - half_stroke)
	return style

static func draw(c: CanvasItem, at: Vector2, remaining: float, style: BoostGaugeStyle) -> void:
	var radius := (style.bounds.x+style.bounds.y)*0.5
	var width := style.bounds.y-style.bounds.x
	c.draw_arc(at,radius,-PI/2.0,-PI/2.0+TAU,48,style.background_color,width)
	if remaining>0.0:
		c.draw_arc(at,radius,-PI/2.0,-PI/2.0+TAU*clampf(remaining,0.0,1.0),48,style.path_color,width)
