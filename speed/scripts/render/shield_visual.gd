## たて座の盾と、奪って機体に装備した盾。前面の板・移動・残り時間を同じ意匠で描く。
extends RefCounted

const STEEL := Color("#8db9cf")
const EDGE := Color("#bcefff")
const GUARD := Color("#65e8ff")

static func plate(c: CanvasItem, p: Vector2, facing: float, r: float, arc: float, flash := 0.0) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 17:
		var u := Vector2.from_angle(facing + lerpf(-arc, arc, k / 16.0))
		outer.append(p + u * r * 1.12)
		inner.append(p + u * r * 0.8)
	var shape := outer.duplicate()
	for k in range(inner.size() - 1, -1, -1):
		shape.append(inner[k])
	c.draw_colored_polygon(shape, STEEL.lerp(Color.WHITE, flash))
	c.draw_polyline(outer, EDGE, maxf(1.5, r * 0.07), true)
	c.draw_polyline(inner, Color("#34546d"), maxf(1.0, r * 0.04), true)
	for k in [0, 4, 8, 12, 16]:
		c.draw_line(inner[k], outer[k], Color("#d9f6ff"), maxf(1.0, r * 0.04), true)
	var u := Vector2.from_angle(facing)
	c.draw_circle(p + u * r * 0.95, r * 0.12, Color.WHITE if flash > 0.0 else GUARD)

static func enemy(c: CanvasItem, t: EnemyTable, i: int) -> void:
	plate(c, t.pos[i], t.facing[i], t.r[i], float(t.def[i].params.front_arc), minf(1.0, t.flash[i] * 10.0))

static func equipped(c: CanvasItem, state: RunState, ship_radius: float, scale: float) -> void:
	if state.ship_shield_t <= 0.0:
		return
	var fraction := clampf(state.ship_shield_t / maxf(0.01, state.ship_shield_max), 0.0, 1.0)
	var r := maxf(ship_radius * 2.5, 36.0 * scale)
	var p := state.ship_pos
	var flash := minf(1.0, state.ship_shield_flash * 8.0)
	var color := GUARD.lerp(Color.WHITE, flash)
	var alpha := 1.0 if fraction > 0.2 else 0.65 + 0.35 * sin(state.world_time * 24.0)
	c.draw_circle(p, r, Color(color, (0.07 + flash * 0.14) * alpha))
	c.draw_arc(p, r * 0.88, 0, TAU, 48, Color(color, 0.3 * alpha), 1.5 * scale, true)
	# 残り時間とともに外周の板が欠ける。最後の板が消えると盾が砕ける。
	for k in 8:
		var left := clampf(fraction * 8.0 - k, 0.0, 1.0)
		if left <= 0.0:
			continue
		var a := state.ship_heading.angle() + k * TAU / 8.0
		c.draw_arc(p, r, a + 0.07, a + 0.07 + (TAU / 8.0 - 0.14) * left, 8,
			Color(color, 0.9 * alpha), 4.0 * scale, true)
	plate(c, p, state.ship_heading.angle(), r * 0.9, 0.6, flash)

static func transfer(c: CanvasItem, effect: Dictionary, target: Vector2) -> void:
	var k := clampf(1.0 - float(effect.life) / float(effect.max), 0.0, 1.0)
	var p: Vector2 = effect.pos.lerp(target, k * (2.0 - k))
	var facing := lerp_angle(float(effect.facing), (target - effect.pos).angle(), k)
	plate(c, p, facing, float(effect.r) * (1.0 - k * 0.25), float(effect.arc), 1.0 - k)
