## 既存の本体・装甲・法線を保ち、進む方向の薙ぎの予告と振りを重ねる。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_body(_c: CanvasItem, t: EnemyTable, i: int, pos: Vector2) -> bool:
	if rm.look_of(t.type[i]) == null:
		return false
	var batch := rm._ensure_enemy_batch(t.type[i])
	var angle := rm._enemy_sprite_angle(t.type[i], t.facing[i])
	var col := Color(1.0 if t.flash[i] > 0.0 else 0.0, 0.0, 0.0, 1.0)
	batch.add(pos, angle, sprite_radius(t, i), col)
	rm._armor_batches[t.type[i]].add(pos, angle, sprite_radius(t, i), col)
	return true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var col := t.color[i].lightened(0.3)
	var params: Dictionary = t.def[i].params
	var toward: float = behavior.walk_direction(i).angle()
	if rm.look_of(t.type[i]) == null:
		for side: float in [-1.0, 1.0]:
			var open := t.mode[i] == EnemyTable.Mode.WINDUP or t.mode[i] == EnemyTable.Mode.RECOVER
			var a := toward + side * (0.75 if open else 0.35)
			c.draw_circle(p + Vector2.from_angle(a) * r * 1.15, r * 0.38, col if open else t.color[i])
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		var k := t.charge[i]
		var center: Vector2 = behavior.sweep_center(i)
		var radius: float = behavior.sweep_radius(i)
		c.draw_circle(center, radius, Color(col, 0.04 + 0.08 * k))
		c.draw_arc(center, radius, 0.0, TAU, 40, Color(col, 0.35 + 0.4 * k), _px(1.5))
		for side: float in [-1.0, 1.0]:
			var claw := p + Vector2.from_angle(toward + side * 0.7) * r
			c.draw_circle(claw, r * (0.12 + 0.3 * k), Color(col, 0.3 + 0.5 * k))
	elif t.mode[i] == EnemyTable.Mode.RECOVER:
		var elapsed := float(params.open_time) - t.timer[i]
		var k := clampf(elapsed / 0.25, 0.0, 1.0)
		if k >= 1.0:
			return
		var center: Vector2 = behavior.sweep_center(i)
		var radius: float = behavior.sweep_radius(i)
		for side: float in [-1.0, 1.0]:
			var a := toward + side * lerpf(1.5, 0.1, k)
			c.draw_arc(center, radius * 0.9, a - 0.35, a + 0.35, 16, Color(col, 1.0 - k), _px(4.0))
