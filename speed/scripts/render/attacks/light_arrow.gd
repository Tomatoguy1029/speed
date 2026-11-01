## 共通の輪郭を読み、通常色とコズミック色を描き分ける。時刻は世界秒を使う。
extends AttackVisual
@export_range(0.25, 4.0, 0.05) var shot_length_scale := 1.0
@export_range(0.25, 4.0, 0.05) var shot_width_scale := 1.0
@export_range(0.25, 4.0, 0.05) var core_width := 1.5
@export var arrow_color := Color("#ffe4a1")
@export var cosmic_color_a := Color("#9d70ff")
@export var cosmic_color_b := Color("#73dcff")
@export_range(0.0, 12.0, 0.1) var cosmic_speed := 3.0
@export_range(0, 8, 1) var cosmic_star_count := 3
var _style: Dictionary = {}

func _apply_effect_settings() -> void:
	super()
	_style = {"shot_length_scale": shot_length_scale, "shot_width_scale": shot_width_scale, "core_width": core_width, "arrow_color": arrow_color, "cosmic_color_a": cosmic_color_a, "cosmic_color_b": cosmic_color_b, "cosmic_speed": cosmic_speed, "cosmic_star_count": cosmic_star_count}

const TEXTURE := preload("res://assets/fx/light_arrow.svg")

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	draw_arrow(c, pos, pr.hostile_vel[i].angle(), pr.hostile_r[i] * flight_scale, false, state.world_time, 1.0, effect_tint, pr.hostile_length[i] * flight_scale, _style)
	return true

static func draw_arrow(c: CanvasItem, pos: Vector2, angle: float, radius: float,
		cosmic: bool, world_time: float, opacity := 1.0, effect_color := Color.WHITE, length := 0.0, style: Dictionary = {}) -> void:
	var scale := radius / 12.0
	var tint: Color = style.get("arrow_color", Color("ffe4a1"))
	if cosmic:
		var a: Color = style.get("cosmic_color_a", Color("9d70ff"))
		var b: Color = style.get("cosmic_color_b", Color("73dcff"))
		tint = a.lerp(b, 0.5 + sin(world_time * float(style.get("cosmic_speed", 3.0))) * 0.5)
	tint.a = opacity
	var tail_scale := length / 52.0 if length > 0.0 else scale
	c.draw_set_transform(pos, angle, Vector2(tail_scale * float(style.get("shot_length_scale", 1.0)), scale * float(style.get("shot_width_scale", 1.0))))
	c.draw_texture_rect(TEXTURE, Rect2(-52, -12, 64, 24), false, tint * effect_color)
	c.draw_line(Vector2(-32, 0), Vector2(4, 0), Color(0.94, 0.97, 1.0, opacity) * effect_color, float(style.get("core_width", 1.5)))
	if cosmic:
		# 光の尾に固定した星。画像の形はimportで準備し、実行時は色と明滅だけを変える。
		for n in int(style.get("cosmic_star_count", 3)):
			var p := Vector2(-12.0 - n * 11.0, -3.0 if n % 2 == 0 else 3.0)
			var a := (0.55 + sin(world_time * 6.0 + n * 2.0) * 0.35) * opacity
			c.draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE * 2.0), Color(0.87, 0.94, 1.0, a) * effect_color)
	c.draw_set_transform(Vector2.ZERO)
