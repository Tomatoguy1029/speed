## 制作用の編集元。通常ランは読み込まない。保存後の最適化・定数化は別工程で行う。
class_name ComboTransitionSettings
extends Resource

@export_enum("Iris", "Star Iris", "Shatter Wipe") var kind := 0
@export_group("待機と再生")
@export_range(0.0, 4.0, 0.01) var selection_seconds := 0.60
@export_range(0.0, 4.0, 0.01) var anticipation_seconds := 0.22
@export_range(0.0, 4.0, 0.01) var hold_seconds := 1.50
## 旧制作ファイルの値を保持する。再生速度はtransportの共通操作へ分離した。
@export_storage var preview_speed := 1.0
@export_group("背景")
@export_range(0.0, 2.0, 0.01) var dim_delay := 0.0
@export_range(0.02, 2.0, 0.01) var cover_seconds := 0.10
@export var dim_color := Color.BLACK
@export_range(0.0, 1.0, 0.01) var background_dim := 0.54
@export_enum("直線", "素早く出て減速", "前後をなめらかに", "強く減速", "加速") var dim_easing := 2
@export_group("画面移行")
@export_range(0.0, 2.0, 0.01) var transition_delay := 0.0
@export_range(0.05, 4.0, 0.01) var opening_seconds := 0.56
@export_enum("元の動き", "直線", "素早く出て減速", "前後をなめらかに", "強く減速", "加速") var transition_easing := 0
@export_range(0.25, 4.0, 0.05) var easing_power := 1.0
@export var focus := Vector2(0.5, 0.44)
@export_range(1.0, 4.0, 1.0) var pixel_size := 2.0
@export_range(0.5, 8.0, 0.25) var rim_width := 3.0
@export_range(0.0, 2.0, 0.05) var glow_strength := 0.22
@export_range(1.0, 40.0, 0.5) var glow_width := 12.0
@export_range(0.0, 1.0, 0.01) var transition_opacity := 1.0
@export var transition_color := Color("#5bc8db")
@export var highlight_color := Color("#e0f7ff")
@export var ink_color := Color("#07101d")
@export_range(0.2, 0.8, 0.01) var inner_ratio := 0.46
@export_range(-2.0, 2.0, 0.01) var spin_turns := 0.32
@export_group("カード")
@export_range(-1.0, 2.0, 0.01) var card_delay := 0.0
@export var card_position := Vector2(0.5, 0.5)
@export var card_start_position := Vector2(0.5, 0.5)
@export var card_size := Vector2(144, 193)
@export_range(0.05, 2.0, 0.01) var card_start_scale := 0.30
@export_range(1.0, 1.6, 0.01) var card_overshoot := 1.05
@export_range(0.02, 2.0, 0.01) var card_zoom_seconds := 0.30
@export_range(0.02, 1.0, 0.01) var card_settle_seconds := 0.10
@export_enum("直線", "素早く出て減速", "前後をなめらかに", "強く減速", "加速") var card_easing := 1
@export_enum("直線", "素早く出て減速", "前後をなめらかに", "強く減速", "加速") var settle_easing := 1
@export_range(0.0, 1.0, 0.01) var card_start_opacity := 1.0
@export_range(0.0, 1.0, 0.01) var card_opacity := 1.0
@export_range(-180.0, 180.0, 1.0) var card_start_rotation := 0.0
@export_range(-180.0, 180.0, 1.0) var card_rotation := 0.0
@export var card_tint := Color.WHITE
@export var card_frame_color := Color("#5bc8db")
@export var card_fill_color := Color("#1f323d")
@export_range(5, 24, 1) var card_font_size := 10
@export var card_text_color := Color.WHITE
@export_range(0.0, 1.0, 0.01) var card_text_opacity := 1.0
@export_range(0.2, 2.0, 0.01) var card_icon_scale := 1.0
@export_range(0.0, 1.0, 0.01) var card_icon_opacity := 1.0
@export_group("着地フラッシュ")
@export_range(-1.0, 2.0, 0.01) var flash_delay := 0.0
@export_range(0.0, 1.0, 0.01) var flash_strength := 0.72
@export_range(0.02, 1.0, 0.01) var flash_seconds := 0.10
@export var flash_color := Color.WHITE
@export_enum("直線", "素早く出て減速", "前後をなめらかに", "強く減速", "加速") var flash_easing := 1
@export_group("Combo文字")
@export_range(-1.0, 3.0, 0.01) var badge_delay := 0.12
@export var badge_position := Vector2(0.715, 0.26)
@export_range(0.2, 3.0, 0.01) var badge_size := 1.0
@export_range(0.0, 1.0, 0.01) var badge_opacity := 1.0
@export_range(0.0, 1.5, 0.01) var badge_pop := 0.75
@export_range(0.0, 50.0, 0.5) var badge_spring_frequency := 38.0
@export_range(1.0, 60.0, 0.5) var badge_spring_decay := 26.0
@export_range(0.05, 2.0, 0.01) var badge_effect_seconds := 0.85
@export_range(0.0, 3.0, 0.5) var badge_outline_width := 2.0
@export var badge_face := Color("#5bc8db")
@export var badge_edge := Color("#e0f7ff")
@export var badge_under := Color("#367e92")
@export var badge_outline := Color("#071320")
@export var badge_shadow := Color("#071320")
@export var badge_tag := Color("#255969")
@export var badge_tag_edge := Color("#5bc8db")
@export var badge_tag_text := Color("#e0f7ff")
@export_range(0.0, 1.0, 0.01) var badge_lines_opacity := 0.7
@export_range(0.0, 2.0, 0.01) var badge_lines_size := 1.0
@export_range(0.02, 1.0, 0.01) var badge_lines_seconds := 0.24
@export var badge_lines_color := Color("#9bdfea")
@export_range(0, 32, 1) var badge_sparks := 10
@export_range(0.0, 1.0, 0.01) var badge_glow := 0.2
@export_range(10.0, 80.0, 1.0) var badge_glow_radius := 40.0
@export_group("割れ方")
@export_range(6, 24, 1) var ray_count := 13
@export_range(3, 12, 1) var band_count := 8
@export_range(0, 65535, 1) var pattern_seed := 9
@export_range(0.0, 0.4, 0.01) var angle_jitter := 0.20
@export_range(0.0, 0.3, 0.01) var radius_jitter := 0.12
@export_range(0.0, 0.85, 0.01) var ring_gap := 0.55
@export_range(0.6, 3.0, 0.05) var radius_distribution := 1.65
@export_range(0.08, 0.5, 0.01) var crack_fraction := 0.24
@export_range(0.005, 0.25, 0.005) var crack_flash_width := 0.045
@export_range(0.0, 1.0, 0.01) var crack_tint_strength := 0.14
@export_range(0.0, 1.0, 0.01) var shard_ink_mix := 0.12
@export_range(0.0, 0.95, 0.01) var shard_fade_start := 0.66
@export_range(0.0, 0.3, 0.01) var front_delay := 0.10
@export_range(0.0, 600.0, 5.0) var scatter_speed := 210.0
@export_range(0.0, 3000.0, 25.0) var fall_acceleration := 1450.0
@export_range(0.0, 12.0, 0.1) var spin_speed := 5.0

static func eased(u: float, mode: int) -> float:
	u = clampf(u, 0.0, 1.0)
	match mode:
		1: return 1.0 - pow(1.0 - u, 3.0)
		2: return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0
		3: return 1.0 - pow(1.0 - u, 4.0)
		4: return u * u * u
	return u

func opening_at() -> float:
	return selection_seconds + dim_delay + cover_seconds + anticipation_seconds + transition_delay

func landing_at() -> float:
	return card_at() + card_zoom_seconds + card_settle_seconds

func card_at() -> float:
	return maxf(0.0, opening_at() + card_delay)

func badge_at() -> float:
	return maxf(0.0, opening_at() + badge_delay)

func flash_at() -> float:
	return maxf(0.0, landing_at() + flash_delay)

func motion_end_at() -> float:
	var spring_seconds := maxf(0.0, log(maxf(0.001, badge_pop) / 0.001) / badge_spring_decay)
	var badge_seconds := maxf(maxf(badge_effect_seconds, badge_lines_seconds), spring_seconds)
	return maxf(maxf(opening_at() + opening_seconds, flash_at() + flash_seconds), maxf(landing_at(), badge_at() + badge_seconds))

func duration() -> float:
	return motion_end_at() + hold_seconds

## 作成・値変更時だけ呼ぶ。毎フレームは時刻progressだけを送る。
func apply_to(material: ShaderMaterial) -> void:
	var properties: Dictionary = {}
	for property in get_property_list(): properties[property.name] = true
	for info in material.shader.get_shader_uniform_list():
		var key: String = info.name
		if key in ["progress", "design_size", "edge_pass"]: continue
		if properties.has(key): material.set_shader_parameter(key, get(key))

func validation_error() -> String:
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE): continue
		var value: Variant = get(property.name)
		if value is float and not is_finite(value): return "有限の数値を入力してください: " + property.name
		if value is Vector2 and (not is_finite(value.x) or not is_finite(value.y)): return "座標に有限の数値を入力してください: " + property.name
		if value is Color and (not is_finite(value.r) or not is_finite(value.g) or not is_finite(value.b) or not is_finite(value.a)): return "色に有限の数値を入力してください: " + property.name
		if property.hint == PROPERTY_HINT_RANGE and (value is int or value is float):
			var limits: PackedStringArray = String(property.hint_string).split(",")
			if value < float(limits[0]) or value > float(limits[1]): return "調整範囲を超えています: " + property.name
		if property.hint == PROPERTY_HINT_ENUM and value is int:
			if value < 0 or value >= String(property.hint_string).split(",").size(): return "選択値が不正です: " + property.name
	if kind < 0 or kind > 2: return "移行の種類が不正です。"
	if minf(card_size.x, card_size.y) <= 0.0: return "カードの幅と高さは0より大きくしてください。"
	if minf(minf(opening_seconds, cover_seconds), minf(card_zoom_seconds, card_settle_seconds)) <= 0.0: return "移行・暗転・ズーム・着地時間は0より大きくしてください。"
	if flash_seconds <= 0.0: return "フラッシュ時間は0より大きくしてください。"
	return ""
