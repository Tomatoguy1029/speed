## G10の接触点の光と、停止後の入口・出口の火花。時刻はC++が所有する。
## 元: centaurus.js G10-boss-hit.draw、fxlib.js ramp/sparks。
extends RefCounted
const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _serial := -1
var _cut := {}
var _epoch := -1

func white(values: Dictionary) -> float:
	if values.is_empty(): return 0.0
	var params: Dictionary = SETTINGS.for_id("G10-boss-hit")
	if bool(values.get("pending",false)): return 0.7 * float(params.intensity)
	var released := float(values.get("released_at",-1.0))
	if released < 0.0: return 0.0
	var age := (float(values.clock)-released)/float(params.timing)
	return 0.45*(1.0-age/0.12)*float(params.intensity) if age>=0.0 and age<0.12 else 0.0

func render(values: Dictionary, body: Node2D, canvas, epoch: int) -> void:
	if epoch != _epoch:
		_epoch = epoch
		_serial = -1
		_cut.clear()
	if values.is_empty() or int(values.get("serial",0))<=0 or body == null: return
	var serial := int(values.serial)
	if serial != _serial:
		_serial = serial
		_cut.clear()
		if values.has("cut_exit"):
			_cut = {"enter":values.entry,"exit":values.cut_exit}
	if _cut.is_empty(): return
	var params: Dictionary = SETTINGS.for_id("G10-boss-hit")
	var color := Color(params.color)
	var pal: Array[Color] = FX.ramp(color)
	var p = canvas.front
	var at: Vector2 = canvas.to_logical(_cut.enter)
	var direction: Vector2 = values.direction
	var angle := direction.angle()
	var size := float(params.size)
	var intensity := float(params.intensity)
	if bool(values.pending):
		for a: float in [angle+PI/2.0,angle-PI/2.0,angle+PI*0.8,angle-PI*0.8]:
			var end := at+Vector2.from_angle(a)*10.0*size
			p.line(at.x,at.y,end.x,end.y,func(u:float): return pal[4] if u<0.4 else pal[3],func(u:float): return 1.0-u)
		p.glow(at.x,at.y,22.0*size,pal[3],intensity)
		p.glow(at.x,at.y,8.0,pal[4],intensity)
		return
	if float(values.released_at)<0.0: return
	var age := (float(values.clock)-float(values.released_at))/float(params.timing)
	if age<0.0 or age>0.6: return
	FX.sparks(p,at,age,3.0,26,color,85.0,0.4,angle+PI,1.3)
	if age<0.1: p.glow(at.x,at.y,16.0*size,pal[3],(1.0-age/0.1)*intensity)
	var end: Vector2 = canvas.to_logical(_cut.exit)
	FX.sparks(p,end,age,7.0,30,color,110.0,0.5,angle,0.75)
	var q := age/0.6
	for i in 10:
		var a := angle+(FX.hash_value(i)-0.5)*1.4
		var distance := 46.0*q*(0.6+FX.hash_value(i+2))
		var point := end+Vector2.from_angle(a)*distance+Vector2(0,16.0*q*q)
		p.rect(point.x-1,point.y-1,2,2,Color("#5a6f93"),1.0)
		p.px(point.x-1,point.y-1,Color("#c7a24a"))
	if age<0.1:
		p.glow(end.x,end.y,24.0*size,pal[3],(1.0-age/0.1)*intensity)
		p.glow(end.x,end.y,8.0,pal[4],(1.0-age/0.1)*intensity)
