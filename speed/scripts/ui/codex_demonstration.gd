## 試作の実演配置を固定データとして再生する。攻撃の部品は本番のBuildEffectsと同じものを使う。
extends Node2D
const FX := preload("res://scripts/render/build_effects.gd")
const FLAT := preload("res://shaders/codex_flat.gdshader")
const SHIP := preload("res://assets/pixel/airship.png")
const TEXTURES := {
	"ship": SHIP, "flame": preload("res://assets/pixel/airship_flame.png"),
	"canon": preload("res://assets/pixel/airship_canon.png"), "tbase": preload("res://assets/pixel/airship_turret_base.png"),
	"turret": preload("res://assets/pixel/airship_turret.png"), "armor": preload("res://assets/pixel/airship_armor.png"),
	"mine": preload("res://assets/pixel/airship_mine.png"), "probe": preload("res://assets/pixel/airship_electronic_probe.png"),
	"drone": preload("res://assets/pixel/drone.png"), "enemy_drifter": preload("res://assets/effects/build/codex_drifter.png"),
	"enemy_armored": preload("res://assets/effects/build/codex_armored.png")}
var animation: Resource
var fx: Node2D
var code := ""
var key := ""
var _sprites: Array[Sprite2D] = []
var _effects: Array[Dictionary] = []
var _rectangles: Array[InstanceBatch] = []
var _sprite_count := 0
var _effect_count := 0
var clock := 0.0

func _ready() -> void:
	fx = FX.new()
	fx.pixel = 1.0
	add_child(fx)

func setup(module: Resource, prepared_animation: Resource = null) -> void:
	code = String(module.code_id)
	key = ("weapon/" if String(module.id).begins_with("W") else "trait/") + code
	var path := "res://data/codex/%s.res" % code
	animation = prepared_animation if prepared_animation != null else load(path) if ResourceLoader.exists(path) else null
	clock = 0.0

func sample(time: float) -> void:
	if animation == null: return
	clock = fposmod(time, animation.period)
	var frame: Array = animation.frames[mini(animation.frames.size() - 1, floori(clock * 30.0))]
	_sprite_count = 0
	_effect_count = 0
	for batch in _rectangles: batch.begin()
	var order := 0
	for command: Array in frame:
		var opcode := int(command[0])
		var z := order
		order += 1
		match opcode:
			0:
				var tier := z / 64
				while _rectangles.size() <= tier:
					var batch := InstanceBatch.new()
					batch.setup_shader_quad()
					batch.z_index = _rectangles.size() * 64
					add_child(batch)
					_rectangles.append(batch)
				_rectangles[tier].add_rect(Vector2(command[1],command[2]), Vector2(command[3],command[4])*0.5, command[5], _color(command,6))
			1: _sprite(command,z)
			2: _primitive(9, Vector2(command[1],command[2]), command[3], z, {"c1":_color(command,4)})
			3: _primitive(10, Vector2(command[1],command[2]), command[3], z, {"width":command[4],"c1":_color(command,5)})
			4:
				var a := Vector2(command[1],command[2])
				var b := Vector2(command[3],command[4])
				_primitive(8,(a+b)*0.5,a.distance_to(b)*0.5,z,{"angle":(b-a).angle(),"width":command[5],"c1":_color(command,6)})
			5: _primitive(1,Vector2(command[1],command[2]),command[3],z,{"age":command[4],"duration":1.0,"noise_seed":command[21],"noise_origin":Vector2(command[1],command[2]),"c0":_color(command,5),"c1":_color(command,9),"c2":_color(command,13),"c3":_color(command,17)})
			6: _primitive(4,Vector2(command[1],command[2]),float(command[4])*0.5,z,{"angle":command[3],"width":command[5],"tint":Color(1,1,1,command[6]),"c2":Color("#dcaaff"),"c3":Color("#8f52d0")})
			7: _aura(command,z)
			8: _primitive(2,Vector2(command[1],command[2]),17,z,{"angle":command[3],"age":command[4],"duration":1.0,"width":command[5]})
			9:
				var item := _primitive(0,Vector2(command[1],command[2]),16,z,{})
				item.material.shader = FX.SHOT
				item.material.set_shader_parameter("style",0 if command[4]>=17 else 1)
				item.node.scale = Vector2.ONE*18.0
				item.node.modulate = Color(fposmod(float(command[3]),TAU)/TAU,1.0 if command[4]<=3 else 0.0,0,1)
			10,11:
				var radius: float = command[3]
				var item := _primitive(0,Vector2(command[1],command[2]),radius*7.0 if opcode==10 else radius+10.0,z,{})
				item.material.shader = preload("res://shaders/build_distortion.gdshader")
				item.material.set_shader_parameter("mode",1 if opcode==10 else 0)
				item.material.set_shader_parameter("age",0.2 if opcode==10 else 0.3)
				item.material.set_shader_parameter("duration",0.52 if opcode==10 else 0.58)
			12:
				_sprite([1,"echo",command[1],command[2]+2.0,31*0.55,70*0.55,float(command[3])+PI*0.5,command[6],0,0,31,70],z)
				_sprites[_sprite_count-1].modulate=Color(float(command[5])/8.0,0,0,command[6])
	for batch in _rectangles: batch.end()
	for i in _sprites.size(): _sprites[i].visible = i < _sprite_count
	for i in _effects.size(): _effects[i].node.visible = i < _effect_count

func _color(data: Array, at: int) -> Color:
	return Color(float(data[at]),float(data[at+1]),float(data[at+2]),float(data[at+3]))

func _primitive(mode: int, pos: Vector2, radius: float, z: int, options: Dictionary) -> Dictionary:
	if _effects.size() <= _effect_count:
		var item: Dictionary = fx.effect(mode,pos,maxf(radius,0.1),1.0,key)
		fx.effects.erase(item)
		_effect_count += 1
		_effects.append(item)
		return _configure(item,mode,pos,radius,z,options)
	var item := _effects[_effect_count]
	_effect_count += 1
	return _configure(item,mode,pos,radius,z,options)

func _configure(item: Dictionary, mode: int, pos: Vector2, radius: float, z: int, options: Dictionary) -> Dictionary:
	item.node.visible = true
	item.node.position = pos
	item.node.z_index = mini(z,4095)
	item.node.scale = Vector2.ONE * (maxf(radius,0.1)+2.0)
	item.node.modulate = Color.WHITE
	item.material.shader = FX.EFFECT
	var defaults := {"mode":mode,"extent":item.node.scale*2.0,"pixel":1.0,"age":0.0,"duration":1.0,"width":1.0,"angle":0.0,"tint":Color.WHITE,"c0":Color.WHITE,"c1":Color("#d8f6ff"),"c2":Color("#7fd8ff"),"c3":Color("#3a9cf0")}
	for name in defaults: item.material.set_shader_parameter(name,defaults[name])
	for name in options: item.material.set_shader_parameter(name,options[name])
	return item

func _sprite(c: Array, z: int) -> void:
	while _sprites.size() <= _sprite_count:
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_sprites.append(sprite)
	var sprite := _sprites[_sprite_count]
	_sprite_count += 1
	var name := String(c[1])
	var echo := name.begins_with("echo")
	sprite.texture = TEXTURES.get(name,SHIP)
	sprite.region_enabled = not echo
	sprite.region_rect = Rect2(float(c[8]),float(c[9]),float(c[10]),float(c[11]))
	var source := Vector2(31,70) if echo else Vector2(c[10],c[11])
	sprite.scale = Vector2(c[4],c[5])/source
	sprite.position = Vector2(c[2],c[3])
	sprite.rotation = c[6]
	sprite.modulate = Color(1,1,1,c[7])
	sprite.z_index = mini(z,4095)
	if name == "flame": sprite.material = null
	else:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/afterimage.gdshader") if echo else FLAT
		if echo:
			mat.set_shader_parameter("clock",clock)
			mat.set_shader_parameter("noise_tex",FX.NOISE)
			mat.set_shader_parameter("ghost",name!="echo")
			sprite.modulate=Color(0,0.0 if name=="echo0" else 0.5 if name=="echo1" else 0.9 if name=="echo2" else 0.0,0,c[7])
		else: mat.set_shader_parameter("ink",Color("#2456c8") if name.begins_with("enemy_") else Color("#e8f4ff"))
		sprite.material = mat

func _aura(c: Array, z: int) -> void:
	_sprite([1,"aura",c[1],float(c[2])+3.0,83*0.55,122*0.55,float(c[3])+PI*0.5,1,0,0,83,122],z)
	var sprite := _sprites[_sprite_count-1]
	sprite.texture = preload("res://assets/effects/build/airship_aura_mask.png")
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/build_aura.gdshader")
	mat.set_shader_parameter("noise_tex",FX.NOISE)
	mat.set_shader_parameter("strength",c[4])
	mat.set_shader_parameter("pop",c[7])
	mat.set_shader_parameter("clock",c[6])
	sprite.material = mat
