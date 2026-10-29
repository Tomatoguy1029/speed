## ミラージュの本体と、実際に通った位置へ残す市松の残光をまとめて描く。
extends Node2D
const SHIP := preload("res://assets/pixel/airship.png")
const SHADER := preload("res://shaders/afterimage.gdshader")
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
var _body: InstanceBatch
var _trail: InstanceBatch
var _seen: Dictionary = {}
var _marks: Array[Dictionary] = []
var _clock := 0.0
func _ready() -> void:
	_trail = _batch(true)
	_body = _batch(false)
func _batch(ghost: bool) -> InstanceBatch:
	var batch := InstanceBatch.new()
	batch.setup_texture(SHIP)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("ghost",ghost)
	mat.set_shader_parameter("noise_tex",preload("res://assets/effects/build/aura_noise.png"))
	batch.material = mat
	add_child(batch)
	return batch
func step(dt: float, state: RunState, cfg: GameConfig, weapon) -> void:
	if state.phase==RunState.Phase.PLAY and state.hitstop<=0.0: _clock+=dt
	else: dt=0.0
	var pixel := 1.82*cfg.character_scale
	for mark in _marks: mark.age+=dt
	_marks=_marks.filter(func(m):return m.age<0.3)
	_body.begin()
	_trail.begin()
	var live := {}
	if weapon!=null:
		for echo in weapon.echoes:
			for i in echo.copies.size():
				var copy: Dictionary=echo.copies[i]
				if copy.alpha<=0.0:continue
				var key := "%s/%d" % [echo.start,i]
				live[key]=true
				if not _seen.has(key):_seen[key]={"pos":copy.pos,"start":_clock}
				var previous: Dictionary=_seen[key]
				var distance: float=previous.pos.distance_to(copy.pos)
				var count := floori(distance/(5.0*pixel))
				for k in mini(count,64):
					var pos: Vector2=previous.pos.lerp(copy.pos,float(k+1)/maxi(count,1))
					_marks.append({"pos":pos,"dir":copy.dir,"age":0.0})
				if count>0:previous.pos=copy.pos
				var spread := (1.0-minf(1.0,(_clock-float(previous.start))/0.1))*6.0
				if copy.alpha<1.0:spread=(1.0-float(copy.alpha))*8.0
				var pos: Vector2=copy.pos+Vector2(0,5.0*cfg.character_scale).rotated(copy.dir.angle()+PI*0.5)
				_body.add(pos,copy.dir.angle()+PI*0.5,SHIP.get_height()*cfg.character_scale*0.5,Color(spread/8.0,0,0,float(copy.alpha)*SETTINGS.number("weapon/afterimage","body_opacity",0.85)))
	for key in _seen.keys():
		if not live.has(key):_seen.erase(key)
	if _marks.size()>512:_marks=_marks.slice(_marks.size()-512)
	for mark in _marks:
		var pos: Vector2=mark.pos+Vector2(0,5.0*cfg.character_scale).rotated(mark.dir.angle()+PI*0.5)
		_trail.add(pos,mark.dir.angle()+PI*0.5,SHIP.get_height()*cfg.character_scale*0.5,Color(0,float(mark.age)/0.3,0,0.55*(1.0-float(mark.age)/0.3)))
	for batch in [_body,_trail]:
		batch.material.set_shader_parameter("clock",_clock)
		batch.end()
