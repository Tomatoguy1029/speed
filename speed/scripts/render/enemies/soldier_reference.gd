## ケフェウス座の兵の集光と光弾。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-cepheus")

func render(soldiers: Array, bolts: Array, canvas, clock: float) -> void:
	var color := Color(_settings.color)
	var size := float(_settings.size)
	var intensity := float(_settings.intensity)
	var palette := FX.ramp(color)
	for soldier: Dictionary in soldiers:
		var direction := Vector2.from_angle(float(soldier.angle))
		var mouth: Vector2 = canvas.to_logical(soldier.pos + direction * float(soldier.radius))
		FX.gather(canvas.front, mouth, float(soldier.radius)*1.3*canvas.world_scale, float(soldier.charge)*intensity, color, clock, 6, int(soldier.slot)+3)
	for bolt: Dictionary in bolts:
		var angle := float(bolt.angle)
		var direction := Vector2.from_angle(angle)
		var end: Vector2 = canvas.to_logical(bolt.pos)
		var start: Vector2 = canvas.to_logical(bolt.pos-direction*46.0)
		canvas.front.beam(start.x,start.y,end.x,end.y,2.6*size,func(u: float, v: float): return palette[4] if u>0.8 else (palette[3] if v<0.4 else palette[2]),func(u: float): return minf(1.0,0.25+u))
		canvas.front.px(end.x,end.y,palette[4])
		canvas.front.px(end.x-direction.x,end.y-direction.y,palette[4])
		canvas.front.glow(end.x,end.y,4*size,palette[4],0.6*intensity)
		canvas.front.glow_line(start.x,start.y,end.x,end.y,4,palette[2],0.4*intensity)
		var age := float(bolt.age)
		if age < 0.08:
			var source: Vector2 = canvas.to_logical(bolt.pos-direction*float(bolt.speed)*age)
			FX.flare(canvas.front, source, 8*canvas.world_scale, color, clock, 1.0-age/0.08, 4)
