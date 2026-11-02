## いるか座の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## いるか座：構えている間、撃つ向きへ扇の輪郭と数層の弧が伸びていき、撃つ向きを予告する。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		return
	draw_view(c,t.pos[i],t.r[i],t.charge[i],t.facing[i],float(t.def[i].params.wave_arc),_px(1.0))

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for n in range(0,values.size(),6): draw_view(c,Vector2(values[n],values[n+1]),values[n+2],values[n+4],values[n+3],values[n+5],pixel)

static func draw_view(c: CanvasItem, p: Vector2, r: float, k: float, f: float, arc: float, pixel: float) -> void:
	var col := Color(1.0,0.3,0.25)
	var reach := r*(2.0+4.0*k)
	for side: float in [-1.0,1.0]: c.draw_line(p,p+Vector2.from_angle(f+side*arc)*reach,Color(col,0.25+0.4*k),2.0*pixel)
	for n in 3:
		var fr := fmod(k*2.0+n/3.0,1.0)
		preload("res://scripts/render/attacks/wave.gd").draw_round_arc(c,p,r*(1.2+3.5*fr),f-arc,f+arc,24,Color(col,(1.0-fr)*(0.3+0.5*k)),3.0*pixel)
	c.draw_circle(p+Vector2.from_angle(f)*r,r*(0.2+0.25*k),Color(1,1,1,0.5+0.4*k))
