## やまねこ座の見た目。
extends EnemyVisual

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for n in range(0,values.size(),6): draw_view(c,Vector2(values[n],values[n+1]),values[n+2],values[n+3],values[n+4],values[n+5],pixel)

static func draw_view(c: CanvasItem, p: Vector2, r: float, f: float, k: float, side: float, pixel: float) -> void:
	if k<=0.0: return
	var u := Vector2.from_angle(f)
	var paw := p+u*r*0.55+Vector2(-u.y,u.x)*side*r*0.6
	c.draw_circle(paw,r*(0.25+0.35*k),Color(1.0,0.55,0.2,0.25*k))
	preload("res://scripts/render/attacks/slash.gd").draw_claws_view(c,paw,f,r*(0.5+0.5*k),side,0.3+0.7*k,pixel)
