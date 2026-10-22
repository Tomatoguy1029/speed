## 波動の敵の見た目。
extends EnemyVisual

func setup(render: RenderManager, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## 波動の敵：次の輪までの溜まり具合で中心の光が強まり、構えると光の輪が中心へ縮んで集まる。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var dp: Dictionary = t.def[i].params
	var col := t.color[i].lightened(0.4)
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		var k := 1.0 - clampf(t.timer[i] / float(dp.telegraph), 0.0, 1.0)
		for n in 3:
			var f := fmod(k * 1.5 + n / 3.0, 1.0)
			c.draw_arc(p, r * (2.4 - 2.0 * f), 0, TAU, 32, Color(col, f * 0.8), _px(2.0))
		c.draw_circle(p, r * (0.25 + 0.2 * k), Color(1, 1, 1, 0.6 + 0.4 * k))
		return
	var ready := 1.0 - clampf(t.fire_t[i] / float(dp.fire_interval), 0.0, 1.0)
	c.draw_circle(p, r * (0.12 + 0.14 * ready), Color(col, 0.3 + 0.6 * ready))
	var spin := state.world_time * 2.0
	for n in 3:
		var a := spin + n * TAU / 3.0
		c.draw_arc(p, r * 1.18, a, a + 0.8 * ready, 8, Color(col, 0.6 * ready), _px(2.0))
