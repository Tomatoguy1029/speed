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

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for i in range(0,values.size(),14):
		var p := Vector2(values[i],values[i+1])
		var r := values[i+2]
		var toward := values[i+3]
		var mode := int(values[i+4])
		var charge := values[i+5]
		var center := p+Vector2.from_angle(toward)*(r+values[i+8]*0.5)
		var radius := values[i+8]*0.6
		var base := Color(values[i+9],values[i+10],values[i+11],values[i+12])
		var col := base.lightened(0.3)
		if values[i+13]>0.0:
			for side: float in [-1.0,1.0]:
				var open := mode==EnemyTable.Mode.WINDUP or mode==EnemyTable.Mode.RECOVER
				c.draw_circle(p+Vector2.from_angle(toward+side*(0.75 if open else 0.35))*r*1.15,r*0.38,col if open else base)
		if mode==EnemyTable.Mode.WINDUP:
			c.draw_circle(center,radius,Color(col,0.04+0.08*charge))
			c.draw_arc(center,radius,0.0,TAU,40,Color(col,0.35+0.4*charge),pixel*1.5)
			for side: float in [-1.0,1.0]:
				c.draw_circle(p+Vector2.from_angle(toward+side*0.7)*r,r*(0.12+0.3*charge),Color(col,0.3+0.5*charge))
		elif mode==EnemyTable.Mode.RECOVER:
			var k := clampf((values[i+7]-values[i+6])/0.25,0.0,1.0)
			if k>=1.0: continue
			for side: float in [-1.0,1.0]:
				var a := toward+side*lerpf(1.5,0.1,k)
				c.draw_arc(center,radius*0.9,a-0.35,a+0.35,16,Color(col,1.0-k),pixel*4.0)
