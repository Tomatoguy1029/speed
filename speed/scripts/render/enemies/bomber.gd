## 自爆する雑魚の見た目。
extends EnemyVisual

## 自爆する雑魚：カウントダウンに入ると赤く膨らむ光と、残り時間の輪、後ろの導火線の火花が強まる。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var u := Vector2.from_angle(t.facing[i])
	var fuse := p - u * r * 0.95
	var now := state.world_time
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		c.draw_circle(fuse, maxf(_px(1.5), r * 0.12) * (0.7 + 0.3 * sin(now * 30.0 + float(t.id[i]))), Color("#ffd36b"))
		return
	var k := t.charge[i]
	var throb := 0.5 + 0.5 * sin(state.world_time * (10.0 + 20.0 * k))
	c.draw_arc(p, r * (1.05 + 0.25 * k * throb), 0, TAU, 32, Color(1.0, 0.3, 0.2, 0.35 + 0.45 * k), maxf(_px(2.0), r * (0.15 + 0.2 * k)))
	c.draw_arc(p, r * 1.45, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - k), 32, Color(1.0, 0.85, 0.5, 0.9), maxf(_px(2.0), r * 0.18))
	for n in 4:
		var q := fuse + Vector2.from_angle(now * 25.0 + n * 1.7) * r * (0.25 + 0.35 * k)
		c.draw_circle(q, maxf(_px(1.5), r * (0.08 + 0.1 * k)), Color(1.0, 0.8 - 0.4 * float(n % 2), 0.3))
