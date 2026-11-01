## 生成済み外観とRenderFrameの値だけで、装甲と噛みつきの顎を描く。
extends Node2D
var _canvas: CanvasLayer
var _parts: Array[Dictionary] = []
var _sparks: InstanceBatch
var _biter := false
var _biting := false
var _glows := PackedFloat32Array()
const SNAP := 0.034
const CLOSED_HOLD := 0.051
const RETURN_TIME := 0.12
const SPARK_TIME := 0.11

func setup(scope: ContentResourceScope, entry: Dictionary) -> void:
	var look := scope.resources[entry.path] as EnemyLook
	_canvas = CanvasLayer.new()
	_canvas.layer = int(entry.id)-5
	_canvas.follow_viewport_enabled = true
	add_child(_canvas)
	var paint: Texture2D = look.painted_armors[entry.paint]
	var settings: Dictionary = entry.settings
	for i in range(2):
		var light := DirectionalLight2D.new()
		var prefix := "key_" if i==0 else "fill_"
		light.energy = settings[prefix+"energy"]
		light.rotation_degrees = settings[prefix+"angle"]
		light.height = settings.height
		light.range_layer_min = _canvas.layer
		light.range_layer_max = _canvas.layer
		_canvas.add_child(light)
	var parts_path: String = entry.get("biter_parts","")
	_biter = not parts_path.is_empty()
	_biting = entry.get("biting",false)
	if _biter:
		var assets: Resource = scope.resources[parts_path]
		for part: Dictionary in assets.get_meta("parts",[]):
			_add_part(part.name,part.base,part.armor,part.normal,part.pivot-Vector2(10,17),paint,settings)
	else:
		_add_part("body",look.base_texture(),paint,look.normal,Vector2.ZERO,paint,settings)
	if _biting:
		_sparks = InstanceBatch.new()
		_sparks.setup_shader_quad()
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/biter_sparks.gdshader")
		_sparks.material = material
		_canvas.add_child(_sparks)

func _add_part(name: String, base_texture: Texture2D, armor_texture: Texture2D, normal: Texture2D, pivot: Vector2, paint: Texture2D, settings: Dictionary) -> void:
	var base := InstanceBatch.new()
	base.setup_texture(base_texture)
	var base_material := ShaderMaterial.new()
	base_material.shader = load("res://shaders/pixel_sprite.gdshader")
	base.material = base_material
	_canvas.add_child(base)
	var armor := InstanceBatch.new()
	var texture := CanvasTexture.new()
	texture.diffuse_texture = armor_texture
	texture.normal_texture = normal
	armor.setup_texture(texture)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/biter_part_armor.gdshader" if _biter else "res://shaders/pixel_armor.gdshader")
	material.set_shader_parameter("ambient",settings.ambient)
	material.set_shader_parameter("normal_strength",settings.normal_strength)
	if _biter: material.set_shader_parameter("paint_tex",paint)
	armor.material = material
	_canvas.add_child(armor)
	_parts.append({"name":name,"base":base,"armor":armor,"pivot":pivot})

func begin() -> void:
	_glows.clear()
	queue_redraw()
	for part: Dictionary in _parts:
		part.base.begin()
		part.armor.begin()
	if _sparks!=null: _sparks.begin()

func _jaw(mode: int, charge: float, timer: float, rest: float) -> float:
	if mode==1: return -8.0*smoothstep(0.0,1.0,charge)
	if mode!=3: return 0.0
	var age := maxf(0.0,rest-timer)
	if age<SNAP: return lerpf(-8.0,12.0,smoothstep(0.0,SNAP,age))
	if age<SNAP+CLOSED_HOLD: return 12.0
	return 12.0*(1.0-smoothstep(SNAP+CLOSED_HOLD,SNAP+CLOSED_HOLD+RETURN_TIME,age))

func apply_frame(row: Dictionary) -> void:
	_glows = row.get("glows",PackedFloat32Array())
	queue_redraw()
	for i in row.ids.size():
		var n: int = i*6
		var radius := Vector2(row.transforms[n],row.transforms[n+1]).length()
		var angle := atan2(row.transforms[n+1],row.transforms[n])
		var position := Vector2(row.transforms[n+4],row.transforms[n+5])
		var jaw := 0.0
		if _biting:
			var values: Dictionary = row.biter
			if _biter: jaw = deg_to_rad(_jaw(values.modes[i],values.charges[i],values.timers[i],values.rests[i]))
			if values.modes[i]==3:
				var spark_age: float = values.rests[i]-values.timers[i]-SNAP
				if spark_age>=0.0 and spark_age<SPARK_TIME:
					var direction := Vector2.from_angle(angle-PI/2.0)
					var mouth := position+direction*radius*(16.0/17.0)
					_sparks.add(mouth+direction*12.0*(radius/17.0),angle-PI/2.0,32.0*(radius/17.0),Color(spark_age/SPARK_TIME,0,0,1))
		for part: Dictionary in _parts:
			var turn := jaw if part.name=="jaw_left" else -jaw if part.name=="jaw_right" else 0.0
			var pivot: Vector2 = part.pivot*(radius/17.0)
			var center := position+(pivot-pivot.rotated(turn)).rotated(angle)
			part.base.add(center,angle+turn,radius,row.colors[i])
			part.armor.add(center,angle+turn,radius,row.colors[i])

func end() -> void:
	for part: Dictionary in _parts:
		part.base.end()
		part.armor.end()
	if _sparks!=null: _sparks.end()

func _draw() -> void:
	for i in range(0,_glows.size(),3):
		for layer in range(3,0,-1):
			draw_circle(Vector2(_glows[i],_glows[i+1]),_glows[i+2]*(1.0+layer*0.22),Color(1,1,1,0.08))

func set_death_brightness(value: float) -> void:
	for part: Dictionary in _parts:
		part.base.material.set_shader_parameter("brightness",value)
		part.armor.material.set_shader_parameter("brightness",value)
