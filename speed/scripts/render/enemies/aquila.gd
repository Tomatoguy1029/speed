## 本体から伸びる予告線を、固定した実際の突進終点まで描く。
extends EnemyVisual

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if t.mode[i] != EnemyTable.Mode.WINDUP: return
	var radius := t.r[i]
	var charge := t.charge[i]
	c.draw_arc(t.pos[i], radius * 1.18, 0, TAU * maxf(0.12, charge), 36, Color(Color("#e1f7ff"), 0.55 + 0.4 * charge), _px(3.0))

func draw_layer(c: CanvasItem, _view: Rect2) -> void:
	if state.cinematic_hide_enemies: return
	var t := run.enemies.table
	var view := rm.view_rect().grow(-_px(48.0))
	for i in behavior.rows():
		if t.dead[i] != 0 or t.mode[i] != EnemyTable.Mode.WINDUP or t.charge[i] <= 0.0 or t.held[i] != 0 or t.stone[i] > 0.0:
			continue
		var path := preload("res://scripts/render/enemies/marlin.gd").clip_warning(t.pos[i], t.anchor[i], view)
		if path.is_empty(): continue
		var from := path[0]
		var to := path[1]
		c.draw_line(from, to, Color(Color("#e1f7ff"), 0.65 + 0.3 * t.charge[i]), _px(4.0))
		c.draw_circle(from, _px(4.0), Color("#fff1cc"))
		var p: Dictionary = t.def[i].params
		var direction := (t.anchor[i] - t.pos[i]).normalized()
		var spacing := float(p.dash_speed) * float(p.drop_step)
		var distance := 0.0
		while distance <= t.pos[i].distance_to(t.anchor[i]) + 0.001:
			var at := t.pos[i] + direction * distance
			if view.grow(float(p.blast_radius)).has_point(at):
				c.draw_arc(at, float(p.blast_radius), 0.0, TAU, 40,
					Color(Color("#e1f7ff"), 0.35 + 0.4 * t.charge[i]), _px(2.0))
			distance += spacing
		var last_drop := floorf(t.pos[i].distance_to(t.anchor[i]) / spacing) * spacing
		if t.pos[i].distance_to(t.anchor[i]) - last_drop > spacing * 0.25:
			c.draw_arc(t.anchor[i], float(p.blast_radius), 0.0, TAU, 40,
				Color(Color("#e1f7ff"), 0.35 + 0.4 * t.charge[i]), _px(2.0))
