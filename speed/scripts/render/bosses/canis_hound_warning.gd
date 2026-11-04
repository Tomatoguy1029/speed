## canisHoundWarning。実際の猟犬画像を足先ごとに描き直す。
extends Node2D

const BODY_SHADER := preload("res://shaders/canis_hound_warning_body.gdshader")
const GLOW_SHADER := preload("res://shaders/canis_hound_warning_glow.gdshader")
const FEET := [Rect2(2,11,5,10),Rect2(13,11,5,10),Rect2(1,21,6,10),Rect2(13,21,6,10)]
var _base: Texture2D
var _armor: Texture2D
var _actors := {}
var _world_time := 0.0

func setup(base: Texture2D, armor: Texture2D) -> void:
	_base = base
	_armor = armor
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _new_actor() -> Dictionary:
	var root := Node2D.new()
	add_child(root)
	var body := Node2D.new()
	root.add_child(body)
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	for texture: Texture2D in [_base,_armor]:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.material = material
		body.add_child(sprite)
	var feet := Node2D.new()
	root.add_child(feet)
	feet.draw.connect(_draw_feet.bind(feet))
	var glow := Node2D.new()
	add_child(glow)
	for i in 3:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := ShaderMaterial.new()
		shader.shader = GLOW_SHADER
		shader.set_shader_parameter("eye",i!=0)
		rect.material = shader
		glow.add_child(rect)
	var sparks := Node2D.new()
	add_child(sparks)
	sparks.draw.connect(_draw_sparks.bind(sparks))
	return {"root":root,"body":body,"feet":feet,"glow":glow,"sparks":sparks}

func apply_frame(rows: Array, world_time: float) -> void:
	_world_time = world_time
	var live := {}
	if _base==null or _armor==null: return
	for row: Dictionary in rows:
		var id := int(row.id)
		live[id] = true
		if not _actors.has(id): _actors[id] = _new_actor()
		var actor: Dictionary = _actors[id]
		var root: Node2D = actor.root
		var body: Node2D = actor.body
		var feet: Node2D = actor.feet
		var strength := clampf(float(row.progress),0.0,1.0)
		var brace := smoothstep(0.02,0.72,strength)
		root.position = row.position
		root.rotation = float(row.facing)+PI/2.0
		root.scale = Vector2.ONE*float(row.sprite_radius)*2.0/maxf(_base.get_width(),_base.get_height())
		body.position = Vector2(0,brace*2.2)
		body.scale = Vector2(1.0+brace*0.025,1.0-brace*0.045)
		feet.set_meta("brace",brace)
		feet.set_meta("strength",strength)
		feet.queue_redraw()
		var radius := float(row.radius)
		var direction := Vector2.from_angle(float(row.facing))
		var side := direction.orthogonal()
		var head: Vector2 = row.position+direction*radius*0.55
		var blink := 0.55+0.45*sin(world_time*(10.0+30.0*strength))
		var k := smoothstep(0.05,0.6,strength)*(0.7+0.3*blink)
		var glow: Node2D = actor.glow
		for i in 3:
			var center := head if i==0 else head+side*radius*0.22*(-1.0 if i==1 else 1.0)
			var glow_radius := radius*1.3 if i==0 else maxf(1.6,radius*0.12)*2.4
			var rect := glow.get_child(i) as ColorRect
			rect.position = center-Vector2.ONE*glow_radius
			rect.size = Vector2.ONE*glow_radius*2.0
			rect.modulate.a = k
		var sparks: Node2D = actor.sparks
		sparks.set_meta("row",row)
		sparks.set_meta("strength",strength)
		sparks.queue_redraw()
	for id in _actors.keys():
		if live.has(id): continue
		var actor: Dictionary = _actors[id]
		actor.root.queue_free()
		actor.glow.queue_free()
		actor.sparks.queue_free()
		_actors.erase(id)

func _draw_feet(node: Node2D) -> void:
	var brace: float = node.get_meta("brace")
	var strength: float = node.get_meta("strength")
	var half := _base.get_size()*0.5
	for i in FEET.size():
		var source: Rect2 = FEET[i]
		var front := i<2
		var side := -1.0 if i%2==0 else 1.0
		var offset := Vector2(side*brace*(0.7 if front else 1.0),brace*(-0.7 if front else 1.2))
		var destination := Rect2(source.position-half+offset,source.size)
		for texture: Texture2D in [_base,_armor]: node.draw_texture_rect_region(texture,destination,source)
	if strength>0.25:
		var alpha := smoothstep(0.25,0.75,strength)*0.85
		for side in [-1,1]:
			var x := roundf(side*(7.0+brace*0.7))
			node.draw_rect(Rect2(x,-3,1,2+roundf(brace*2.0)),Color(0.604,0.376,0.31,alpha))
			node.draw_rect(Rect2(x,-3,1,1),Color(0.941,0.733,0.498,alpha))

func _draw_sparks(node: Node2D) -> void:
	var row: Dictionary = node.get_meta("row")
	var strength: float = node.get_meta("strength")
	if strength<=0.35: return
	var direction := Vector2.from_angle(float(row.facing))
	var side := direction.orthogonal()
	var radius := float(row.radius)
	for i in 6:
		var phase := fposmod(_world_time*3.0+i/6.0,1.0)
		var p: Vector2 = row.position-direction*radius*(0.6+phase*1.6)+side*(_hash(i*3.7)-0.5)*radius*1.2
		var color := Color(1.0,(180.0-phase*80.0)/255.0,80.0/255.0,(1.0-phase)*smoothstep(0.35,0.8,strength))
		node.draw_rect(Rect2(p-Vector2.ONE,Vector2(2,2)),color)

func _hash(value: float) -> float:
	var n := sin(value*127.1+311.7)*43758.5453
	return n-floorf(n)
