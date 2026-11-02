## ケフェウス座の兵の見た目（王を失って崩れていく兵）。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	draw_view(c,t.pos[i],t.r[i],t.facing[i],t.mode[i],t.charge[i],0.5+0.5*sin(state.world_time*30.0+float(t.id[i])),_px(1.0))

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for n in range(0,values.size(),7): draw_view(c,Vector2(values[n],values[n+1]),values[n+2],values[n+3],int(values[n+4]),values[n+5],values[n+6],pixel)

static func draw_view(c: CanvasItem, p: Vector2, r: float, facing: float, mode: int, charge: float, flick: float, pixel: float) -> void:
	if charge>0.0:
		c.draw_circle(p+Vector2.from_angle(facing)*r,3.0*pixel+r*0.45*charge,Color(1.0,0.9,0.6,0.35+0.55*charge))
	if mode==EnemyTable.Mode.MOVE and charge>0.0:
		var direction := Vector2.from_angle(facing)
		var start := p+direction*r
		var glow := Color(1.0,0.88,0.48,0.25+0.55*charge)
		c.draw_line(start,start+direction*90.0,glow,2.0*pixel)
		c.draw_arc(p,r*1.4,0.0,TAU*charge,24,glow,2.0*pixel)
	if mode==EnemyTable.Mode.RECOVER: c.draw_arc(p,r*1.3,0.0,TAU,20,Color(1.0,0.3,0.3,0.4+0.4*flick),2.0*pixel)
