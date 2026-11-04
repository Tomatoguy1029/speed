## monoDanceBurn の熱から煤へ変わる跡。位置と年齢は戦闘状態から受け取る。
extends RefCounted
const SLASH := preload("res://scripts/render/bosses/monoceros_slash.gd")

static func _mix(a: Color, b: Color, amount: float) -> Color:
	return Color(floorf(lerpf(roundf(a.r*255.0),roundf(b.r*255.0),amount))/255.0,floorf(lerpf(roundf(a.g*255.0),roundf(b.g*255.0),amount))/255.0,floorf(lerpf(roundf(a.b*255.0),roundf(b.b*255.0),amount))/255.0)

static func draw(canvas, position: Vector2, age: float, params: Dictionary) -> void:
	if age<0.0 or age>2.5: return
	var outer := Color(params.tailOuterColor)
	var inner := Color(params.tailJetColor)
	var core := Color(params.tailCoreColor)
	var black := Color("#05030a")
	var heat := [core,_mix(core,inner,0.5),inner,_mix(inner,outer,0.5),outer,_mix(outer,black,0.3),_mix(outer,black,0.6),_mix(outer,black,0.8)]
	var soot := [_mix(outer,black,0.88),_mix(outer,black,0.78)]
	var origin: Vector2 = canvas.to_logical(position)
	var radius := 3.2*float(params.size)
	if radius<=0.0: return
	var fade := 1.0-smoothstep(1.4,2.5,age)
	for y in range(-ceili(radius),floori(radius)+1):
		for x in range(-ceili(radius),floori(radius)+1):
			var k := SLASH._hash((floorf(origin.x+0.5)+x)*12.9898+(floorf(origin.y+0.5)+y)*78.233)
			var distance := Vector2(x,y).length()/radius
			if distance>0.7+0.5*k or k>fade*0.95: continue
			var temperature := pow(clampf(1.0-age/0.9,0.0,1.0),1.3)*(1.1-distance)-k*0.35
			if temperature>0.1:
				var index := mini(heat.size()-1,floori((1.0-minf(1.0,temperature))*(heat.size()-1)))
				canvas.back.px(origin.x+x,origin.y+y,heat[index])
			else:
				canvas.back.blend(origin.x+x,origin.y+y,soot[0 if k<0.5 else 1],0.7)
