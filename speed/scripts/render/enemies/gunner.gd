## 射撃型の予告。通常表示とC++の表示用の値で同じ砲口の光を使う。
extends EnemyVisual

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	draw_warning(c,t.pos[i],t.facing[i],t.r[i],t.charge[i],_px(1.0))

static func draw_warning(c: CanvasItem, position: Vector2, angle: float, radius: float, charge: float, pixel: float) -> void:
	if charge<=0.0: return
	var muzzle := position+Vector2.from_angle(angle)*radius
	c.draw_circle(muzzle,3.0*pixel+radius*0.45*charge,Color(1.0,0.9,0.6,0.35+0.55*charge))

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for i in range(0,values.size(),5):
		draw_warning(c,Vector2(values[i],values[i+1]),values[i+3],values[i+2],values[i+4],pixel)
