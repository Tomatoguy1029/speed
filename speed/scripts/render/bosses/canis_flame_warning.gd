## 試作 canis.js / bosses_common.js の炎の予兆。
extends RefCounted

const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const SETTINGS := preload("res://data/visuals/fx_reference.tres")

static func _gather(canvas, at: Vector2, radius: float, charge: float, clock: float, palette: Array[Color], intensity: float, seed := 1) -> void:
	var origin: Vector2 = canvas.to_logical(at)
	for i in 28:
		var life := 0.4+FX.hash_value(i+seed)*0.55
		var phase := fposmod(clock/life+FX.hash_value(i*9+seed),1.0)
		var angle := FX.hash_value(i*19+seed)*TAU
		var point: Vector2 = origin+Vector2.from_angle(angle)*radius*canvas.world_scale*pow(1.0-phase,1.4)
		canvas.front.px(point.x,point.y,palette[3] if phase>0.6 else palette[1])
		canvas.front.light(point.x,point.y,palette[2],charge*phase*intensity*0.5)
	canvas.front.glow(origin.x,origin.y,radius*canvas.world_scale*0.6,palette[2],charge*intensity*0.32)

static func draw(canvas, body: Dictionary, attack: Dictionary) -> void:
	var name := str(attack.get("technique",""))
	if name not in ["sirius","sirius_flame","relay","hunt","blaze"]: return
	var settings: Dictionary = SETTINGS.for_id("O-"+name)
	var palette: Array[Color] = FX.ramp(Color(settings.color))
	var intensity := float(settings.intensity)
	var clock := float(body.clock)
	var radius := float(body.radius)
	var facing := float(body.facing)
	var mouth: Vector2 = body.position+Vector2.from_angle(facing)*radius*0.84
	var progress := float(attack.get("windup_progress",0.0))
	var windup := int(attack.get("stage",5))==0
	var aiming := windup and (name=="sirius" or name in ["relay","hunt"] and bool(attack.get("aiming",false)))
	if aiming:
		_gather(canvas,mouth,radius,progress,clock,palette,intensity)
		var origin: Vector2 = canvas.to_logical(mouth)
		var direction := Vector2.from_angle(facing)
		var normal := direction.orthogonal()
		var length: float = float(attack.warning_length)*canvas.world_scale
		var width: float = float(attack.beam_width)*canvas.world_scale
		for i in 65:
			var phase := fposmod(FX.hash_value(i*7)+clock*0.4,1.0)
			var distance := phase*length
			var spread := width*(0.5+FX.hash_value(i+1))
			var point := origin+direction*distance+normal*(FX.hash_value(i+8)-0.5)*spread
			canvas.back.glow(point.x,point.y,1.5+FX.hash_value(i)*2.0,palette[2],(0.06+progress*0.12)*intensity)
	if windup and name in ["sirius","sirius_flame","blaze"] and progress>0.0:
		_gather(canvas,mouth,radius*1.2,progress,clock,palette,intensity)
	if name=="relay":
		for warning: Dictionary in attack.get("warnings",[]):
			var hound_radius := float(warning.radius)
			var at: Vector2 = warning.position+Vector2.from_angle(float(warning.angle))*hound_radius
			var k := float(warning.progress)
			_gather(canvas,at,hound_radius*1.2,k,clock,palette,intensity,int(warning.index)+3)
			var point: Vector2 = canvas.to_logical(at)
			canvas.front.glow(point.x,point.y,2.0+5.0*k,Color("#a9dcff"),0.3+0.5*k)
			canvas.front.glow(point.x,point.y,1.0+2.0*k,Color.WHITE,0.5*k)
