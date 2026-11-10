## 既存の本体・塗装・法線を使い、後部だけを膨らませる。
extends EnemyVisual
const BODY_SHADER := preload("res://shaders/pump_reservoir.gdshader")
const WIND_SHADER := preload("res://shaders/pump_wind.gdshader")
const SWALLOW_SECONDS := 0.2
const ENEMIES := [preload("res://assets/pixel/bomber.png"), preload("res://assets/pixel/splitter.png"), preload("res://assets/pixel/splitling.png")]
var swallows: Array[Dictionary] = []
var _bodies: Array[MeshInstance2D] = []
var _winds: Array[MeshInstance2D] = []
var _count := 0
var _body_mesh: QuadMesh
var _wind_mesh: QuadMesh

var _frame_parent: Node
var _frame_look: EnemyLook
var _frame_paint: Texture2D
var _frame_outlined := false
var _frame_settings: Dictionary
var _frame_targets := {}
var _frame_swallow: DrawLayer
var _frame_clock := -1.0
var _frame_brightness_value := 1.0
var _death_map: Texture2D

func setup_frame(parent: Node, look: EnemyLook, paint: Texture2D, settings: Dictionary, death_map: Texture2D = null, paint_key := "") -> void:
	_death_map = death_map
	_frame_parent = parent
	_frame_look = look
	_frame_paint = paint
	_frame_outlined = look.outlined_base!=null and look.outlined_normal!=null and look.outlined_armors.has(paint_key)
	if _frame_outlined: _frame_paint = look.outlined_armors[paint_key]
	_frame_settings = settings
	_body_mesh = QuadMesh.new()
	_body_mesh.size = Vector2(44,54)
	_wind_mesh = QuadMesh.new()
	_wind_mesh.size = Vector2(150,150)
	_frame_swallow = DrawLayer.new()
	_frame_swallow.draw_fn = _draw_frame_swallow
	parent.add_child(_frame_swallow)

func _frame_nodes() -> void:
	if _count<_bodies.size(): return
	var body := MeshInstance2D.new()
	body.mesh = _body_mesh
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	if _death_map != null:
		material.set_shader_parameter("death_enabled",true)
		material.set_shader_parameter("death_map",_death_map)
	material.set_shader_parameter("brightness",_frame_brightness_value)
	material.set_shader_parameter("base_tex",_frame_look.outlined_base if _frame_outlined else _frame_look.base)
	material.set_shader_parameter("armor_tex",_frame_paint)
	material.set_shader_parameter("normal_tex",_frame_look.outlined_normal if _frame_outlined else _frame_look.normal)
	if _frame_outlined:
		material.set_shader_parameter("pad",float(EnemyLook.OUTLINE_PAD))
		var outline := EnemyLook.OUTLINE_COLOR
		material.set_shader_parameter("outline_color",Vector3(outline.r,outline.g,outline.b))
	for k in 3: material.set_shader_parameter("enemy%d" % k,ENEMIES[k])
	for key in ["normal_strength","ambient"]: material.set_shader_parameter(key,_frame_settings[key])
	body.material = material
	_frame_parent.add_child(body)
	_bodies.append(body)
	var wind := MeshInstance2D.new()
	wind.mesh = _wind_mesh
	var wind_material := ShaderMaterial.new()
	wind_material.shader = WIND_SHADER
	wind.material = wind_material
	_frame_parent.add_child(wind)
	_winds.append(wind)

func apply_frame(row: Dictionary) -> void:
	_count = 0
	_frame_targets.clear()
	var values: PackedFloat32Array = row.get("pump",PackedFloat32Array())
	if not values.is_empty():
		var now := values[6]
		if now<_frame_clock: swallows.clear()
		var elapsed := maxf(0.0,now-_frame_clock) if _frame_clock>=0.0 else 0.0
		_frame_clock = now
		for sw: Dictionary in swallows: sw.life-=elapsed
		swallows = swallows.filter(func(sw): return sw.life>0.0)
	for i: int in row.get("ids",PackedInt64Array()).size():
		_frame_nodes()
		var n := i*9
		var p := Vector2(values[n],values[n+1])
		var angle := values[n+2]
		var scale_px := values[n+3]
		var facing := angle-_frame_look.angle
		var body := _bodies[_count]
		body.position = p+Vector2(0,8.5*scale_px).rotated(angle)
		body.rotation = angle
		body.scale = Vector2.ONE*scale_px
		body.show()
		var material := body.material as ShaderMaterial
		if _death_map != null: material.set_shader_parameter("death_age",row.colors[i].a)
		material.set_shader_parameter("full",values[n+4])
		material.set_shader_parameter("stored_full",values[n+5])
		material.set_shader_parameter("clock",values[n+6])
		material.set_shader_parameter("flash",values[n+7])
		var wind := _winds[_count]
		wind.position = p+Vector2.from_angle(facing)*(15.725+75.0)*scale_px
		wind.rotation = facing
		wind.scale = Vector2.ONE*scale_px
		wind.visible = values[n+8]>0.0
		(wind.material as ShaderMaterial).set_shader_parameter("clock",values[n+6])
		_frame_targets[row.ids[i]] = {"pos":p,"facing":facing,"scale":scale_px,"stored":values[n+5]}
		_count+=1
	for n in range(_count,_bodies.size()): _bodies[n].hide(); _winds[n].hide()
	_frame_swallow.queue_redraw()

func frame_event(event: Dictionary, texture: Texture2D) -> void:
	if event.type!=&"swallow" or not _frame_targets.has(event.id) or texture==null or swallows.size()>=120: return
	var sw := event.duplicate()
	sw.life = SWALLOW_SECONDS
	sw.texture = texture
	swallows.append(sw)
	_frame_swallow.queue_redraw()

func frame_brightness(value: float) -> void:
	_frame_brightness_value = value
	for body in _bodies: body.material.set_shader_parameter("brightness",value)

func _draw_frame_swallow(c: CanvasItem) -> void:
	for sw: Dictionary in swallows:
		if not _frame_targets.has(sw.id) or _frame_targets[sw.id].stored<=0.0: continue
		var owner: Dictionary = _frame_targets[sw.id]
		var k := clampf(1.0-float(sw.life)/SWALLOW_SECONDS,0.0,1.0)
		var u := Vector2.from_angle(owner.facing)
		var mouth: Vector2 = owner.pos+u*15.725*owner.scale
		var rear: Vector2 = owner.pos-u*8.5*owner.scale
		var at: Vector2 = sw.pos.lerp(mouth,pow(minf(k/0.625,1.0),2.0)) if k<0.625 else mouth.lerp(rear,(k-0.625)/0.375)
		var texture: Texture2D = sw.texture
		var radius: float = sw.sprite_radius*lerpf(1.0,0.12,minf(k/0.625,1.0))
		var size := texture.get_size()/maxf(texture.get_width(),texture.get_height())*radius*2.0
		c.draw_set_transform(at,sw.sprite_angle)
		c.draw_texture_rect(texture,Rect2(-size/2,size),false,Color(1,1,1,minf(1.0,(1.0-k)*5.0)))
		c.draw_set_transform(Vector2.ZERO)
