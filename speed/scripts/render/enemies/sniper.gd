## ぼうえんきょう座の見た目。
extends EnemyVisual

func setup(render: RenderManager, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## ぼうえんきょう座：レンズから伸びるサーチライトの帯。狙いが溜まるほど細く赤くなり、本体の周りの輪が狙いの溜まり具合を示す。
## 光は隕石・惑星・月で遮られ、その裏には描かない（光線の束の届く長さで形を作る）。
## 機体が光の中にいる間は帯が明るくなる。撃ったあとの休みの間は暗い。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if not behavior.telescope_aiming(i):
		return
	var p := t.pos[i]
	var r := t.r[i]
	var dp: Dictionary = t.def[i].params
	var k := t.charge[i]
	var f := t.facing[i]
	var lens: Vector2 = behavior.telescope_lens(i)
	var half: float = behavior.telescope_half(i)
	var length := float(dp.band_len)
	var rays: PackedFloat32Array = behavior.telescope_rays(i)
	var col := Color(0.62, 0.9, 1.0).lerp(Color(1.0, 0.22, 0.2), k)
	var resting := t.mode[i] == EnemyTable.Mode.RECOVER
	var seen: bool = behavior.telescope_sight(i, state.ship_pos) == 1
	var a0 := (0.06 if resting else 0.16 + 0.22 * k) + (0.08 if seen else 0.0)
	var count: int = rays.size()
	if count < 2:
		return
	var pts := PackedVector2Array([lens])
	var cols := PackedColorArray([Color(col, a0)])
	for n in count:
		var reach: float = rays[n]
		pts.append(lens + Vector2.from_angle(f - half + 2.0 * half * n / float(count - 1)) * reach)
		cols.append(Color(col, a0 * (1.0 - reach / length)))
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		# レーザーの溜め：帯がすぼまって赤い照準線になり脈打つ。光の粒がレンズへ吸い込まれ、レンズの光が膨らむ
		var w := 1.0 - clampf(t.timer[i] / float(dp.laser_charge), 0.0, 1.0)
		var reach: float = behavior.telescope_reach(i, f)
		var pulse := 0.5 + 0.5 * sin(state.world_time * (30.0 + 40.0 * w))
		var tip: Vector2 = lens + Vector2.from_angle(f) * reach
		c.draw_line(lens, tip, Color(1.0, 0.25, 0.2, 0.25 + 0.35 * pulse), maxf(_px(2.0), 4.0 + 10.0 * w))
		c.draw_line(lens, tip, Color(1.0, 0.85, 0.8, 0.5 + 0.4 * pulse), maxf(_px(1.0), 1.5 + 2.0 * w))
		for n in 10:
			var fr := fmod(w * 3.0 + n / 10.0, 1.0)
			var q: Vector2 = lens + Vector2.from_angle(n * TAU / 10.0 + w * 4.0) * r * (2.4 - 2.2 * fr)
			c.draw_circle(q, maxf(_px(1.5), r * 0.07), Color(1.0, 0.45, 0.3, fr))
		c.draw_circle(lens, r * (0.35 + 0.6 * w), Color(1.0, 0.3, 0.22, 0.35 + 0.3 * pulse))
		c.draw_circle(lens, r * (0.18 + 0.3 * w), Color(1.0, 0.92, 0.85, 0.9))
		return
	c.draw_polygon(pts, cols)
	c.draw_line(lens, pts[1], Color(col, a0 * 1.6), _px(1.5))
	c.draw_line(lens, pts[count], Color(col, a0 * 1.6), _px(1.5))
	c.draw_circle(lens, _px(2.0) + r * (0.2 + 0.2 * k), Color(col, 0.5 + 0.4 * k))
	if k > 0.0:
		c.draw_arc(p, r * 1.35, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(col, 0.9), maxf(_px(2.0), r * 0.12))
