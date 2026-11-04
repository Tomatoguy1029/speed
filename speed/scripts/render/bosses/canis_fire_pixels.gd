## 本番が作った炎の密度画素を、同じworld位置に表示する。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const BASE := Color("#80c8ff")
const RAMP := [Color("#2a66c4"),Color("#a9dcff"),Color.WHITE]

static func _hsl(c: Color) -> Vector3:
	var mx := maxf(c.r,maxf(c.g,c.b))
	var mn := minf(c.r,minf(c.g,c.b))
	var light := (mx+mn)*0.5
	var d := mx-mn
	if is_zero_approx(d): return Vector3(0,0,light)
	var sat := d/(1.0-absf(2.0*light-1.0))
	var hue := fposmod((c.g-c.b)/d+6.0,6.0) if mx==c.r else (c.b-c.r)/d+2.0 if mx==c.g else (c.r-c.g)/d+4.0
	return Vector3(hue*60.0,sat,light)

static func _from_hsl(h: float, s: float, l: float) -> Color:
	var c := (1.0-absf(2.0*l-1.0))*s
	var x := c*(1.0-absf(fposmod(h/60.0,2.0)-1.0))
	var m := l-c/2.0
	var rgb: Vector3 = [Vector3(c,x,0),Vector3(x,c,0),Vector3(0,c,x),Vector3(0,x,c),Vector3(x,0,c),Vector3(c,0,x)][floori(fposmod(h,360.0)/60.0)]
	return Color(roundf(clampf(rgb.x+m,0.0,1.0)*255.0)/255.0,roundf(clampf(rgb.y+m,0.0,1.0)*255.0)/255.0,roundf(clampf(rgb.z+m,0.0,1.0)*255.0)/255.0)

static func _palette(tint: Color) -> Array[Color]:
	var base := _hsl(BASE)
	var selected := _hsl(tint)
	var colors: Array[Color] = []
	for c: Color in RAMP:
		var hsl := _hsl(c)
		colors.append(_from_hsl(fposmod(hsl.x+selected.x-base.x+360.0,360.0),clampf(hsl.y*selected.y/base.y,0.0,1.0),hsl.z))
	return colors

static func draw(canvas, rows: Array) -> void:
	for row: Dictionary in rows:
		var cell := float(row.cell)
		if cell<=0.0: continue
		var params := SETTINGS.for_id(str(row.settings))
		if params.is_empty(): continue
		var colors := _palette(Color(str(params.color)))
		var alpha := minf(1.0,float(params.intensity))
		var pixels: PackedInt32Array = row.pixels
		var origin: Vector2 = row.field_origin
		var old_fade: float = canvas.front.fade
		canvas.front.fade *= alpha
		for i in range(0,pixels.size(),3):
			var x := pixels[i]
			var y := pixels[i+1]
			var layer := pixels[i+2]
			var point: Vector2 = canvas.to_logical(origin+Vector2(x+0.5,y+0.5)*cell)
			var color: Color = colors[layer]
			canvas.front.px(point.x,point.y,color)
			if (x&3)==0 and (y&3)==0: canvas.front.glow(point.x,point.y,2.0,color,0.10 if layer==2 else 0.05 if layer==1 else 0.02)
		canvas.front.fade = old_fade
