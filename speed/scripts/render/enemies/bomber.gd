## 自爆する雑魚の見た目。
extends EnemyVisual

## カウントダウンの予告は装甲の赤い明滅で示す。移動中は導火線の火花を描く。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var u := Vector2.from_angle(t.facing[i])
	var fuse := p - u * r * 0.95
	var now := state.world_time
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		c.draw_circle(fuse, maxf(_px(1.5), r * 0.12) * (0.7 + 0.3 * sin(now * 30.0 + float(t.id[i]))), Color("#ffd36b"))
		return
