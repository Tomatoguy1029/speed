## みずがめ座の集光と6本の水流。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const JET := preload("res://scripts/render/enemies/aquarius_jet.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-aquarius")
var _jet = JET.new()

func render(rows: Array, canvas, clock: float) -> void:
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	for row: Dictionary in rows:
		var time := float(row.time)
		var delay := float(row.delay)
		var index := int(row.index)
		var origin: Vector2 = row.pos
		var point: Vector2 = canvas.to_logical(origin)
		if time < delay:
			if index == 0:
				var k := clampf(time/delay, 0.0, 1.0)
				FX.gather(canvas.front, point, float(row.radius)*1.2*float(_settings.size)*canvas.world_scale, k*intensity, color, clock, 14, 4)
		elif time < delay + float(row.active):
			_jet.draw(canvas, origin, float(row.angle), float(row.length), float(row.half_width), tan(float(row.spread)), clock, 1.0, 7+index*13, color, minf(1.0,intensity))
			if index == 0 and time-delay < 0.2:
				var palette: Array[Color] = _jet._ramp(color)
				canvas.front.glow(point.x,point.y,float(row.radius)*canvas.world_scale*3.0,palette[6],0.8*(1.0-(time-delay)/0.2)*intensity)
