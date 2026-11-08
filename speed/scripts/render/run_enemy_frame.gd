## 生成済み外観とRenderFrameの値だけで、装甲と噛みつきの顎を描く。
extends Node2D
var perf := PerfLog.new()
var _death_masks: Dictionary = {}
var _death_map: Texture2D
var _pump: EnemyVisual
var _canvas: CanvasLayer
var _parts: Array[Dictionary] = []
var _sparks: InstanceBatch
var _biter := false
var _biting := false
var _ruler:=false
var _glows := PackedFloat32Array()
var _previous_row: Dictionary = {}
var _seen := false
var _dirty := false
var _brightness := -1.0
const SNAP := 0.034
const CLOSED_HOLD := 0.051
const RETURN_TIME := 0.12
const SPARK_TIME := 0.11

func setup(scope: ContentResourceScope, entry: Dictionary, death_masks: Dictionary = {}) -> void:
	_death_masks = death_masks
	var look := scope.resources[entry.path] as EnemyLook
	_death_map = death_masks.get(look.source_path)
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
	if entry.get("pump",false):
		_pump = preload("res://scripts/render/enemies/pump.gd").new()
		_pump.setup_frame(_canvas,look,paint,settings,_death_map,entry.paint)
	elif _biter:
		var assets: Resource = scope.resources[parts_path]
		if not look.outlined_parts.is_empty() and look.outlined_armors.has(entry.paint):
			for part: Dictionary in look.outlined_parts:
				_add_outlined_part(part.name,part.base,part.armor,part.normal,look.outlined_armors[entry.paint],part.pivot-Vector2(10,17),settings)
		else:
			for part: Dictionary in assets.get_meta("parts",[]):
				_add_part(part.name,part.base,part.armor,part.normal,part.pivot-Vector2(10,17),paint,settings)
	else:
		_add_part("body",look.base_texture(),paint,look.normal,Vector2.ZERO,paint,settings,look,entry.paint)
		_ruler=entry.get("ruler",false) and look.split_other!=null
		if _ruler:
			var lower: EnemyLook=look.split_other
			var lower_paint: Texture2D=lower.painted_armors[entry.lower_paint]
			_death_map = death_masks.get(lower.source_path)
			_add_part("lower",lower.base_texture(),lower_paint,lower.normal,Vector2.ZERO,lower_paint,settings,lower,entry.lower_paint)
			_parts.back().angle=lower.angle-look.angle
	if _biting:
		_sparks = InstanceBatch.new()
		_sparks.setup_shader_quad()
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/biter_sparks.gdshader")
		_sparks.material = material
		_canvas.add_child(_sparks)

## look があり縁を焼き込んだ絵を持つときは、下地と装甲を1つの束で1体ずつ描く。
func _add_part(name: String, base_texture: Texture2D, armor_texture: Texture2D, normal: Texture2D, pivot: Vector2, paint: Texture2D, settings: Dictionary, look: EnemyLook = null, paint_key := "") -> void:
	if look!=null and look.outlined_base!=null and look.outlined_normal!=null and look.outlined_armors.has(paint_key):
		_add_outlined_part(name,look.outlined_base,look.outlined_armors[paint_key],look.outlined_normal,null,pivot,settings)
		return
	var base := InstanceBatch.new()
	base.setup_texture(base_texture)
	var base_material := ShaderMaterial.new()
	base_material.shader = load("res://shaders/pixel_sprite.gdshader")
	base_material.set_shader_parameter("stone_enabled",true)
	# ペルセウス座の石の色は、HDR の画面（Compatibility 以外）ではリニアで出す
	var hdr := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	base_material.set_shader_parameter("stone_linear",hdr)
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
	material.set_shader_parameter("stone_linear",hdr)
	if _biter: material.set_shader_parameter("paint_tex",paint)
	if _death_map != null:
		for shader_material: ShaderMaterial in [base_material,material]:
			shader_material.set_shader_parameter("death_enabled",true)
			shader_material.set_shader_parameter("death_map",_death_map)
	armor.material = material
	_canvas.add_child(armor)
	_parts.append({"name":name,"base":base,"armor":armor,"pivot":pivot})

## paint があるときは、装甲の色を共通の確定塗装から取る（部位に分けた絵）。
func _add_outlined_part(name: String, base_texture: Texture2D, armor_texture: Texture2D, normal: Texture2D, paint: Texture2D, pivot: Vector2, settings: Dictionary) -> void:
	var batch := InstanceBatch.new()
	var texture := CanvasTexture.new()
	texture.diffuse_texture = armor_texture
	texture.normal_texture = normal
	batch.setup_texture(texture,Rect2(),EnemyLook.OUTLINE_PAD)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/pixel_enemy.gdshader")
	material.set_shader_parameter("base_tex",base_texture)
	if paint!=null:
		material.set_shader_parameter("use_paint",true)
		material.set_shader_parameter("paint_tex",paint)
	material.set_shader_parameter("outline_pad",float(EnemyLook.OUTLINE_PAD))
	material.set_shader_parameter("ambient",settings.ambient)
	material.set_shader_parameter("normal_strength",settings.normal_strength)
	# ペルセウス座の石の色は、HDR の画面（Compatibility 以外）ではリニアで出す
	material.set_shader_parameter("stone_linear",RenderingServer.get_current_rendering_method() != "gl_compatibility")
	if _death_map != null:
		material.set_shader_parameter("death_enabled",true)
		material.set_shader_parameter("death_map",_death_map)
	batch.material = material
	_canvas.add_child(batch)
	_parts.append({"name":name,"base":batch,"armor":null,"pivot":pivot})

func begin() -> void:
	_seen = false
	_dirty = false

func _begin_buffers() -> void:
	for part: Dictionary in _parts: part.base.begin()
	if _sparks!=null: _sparks.begin()

func _set_glows(values: PackedFloat32Array) -> void:
	if values==_glows: return
	_glows = values
	queue_redraw()

static func jaw_angle(mode: int, charge: float, timer: float, rest: float) -> float:
	if mode==1: return -8.0*smoothstep(0.0,1.0,charge)
	if mode!=3: return 0.0
	var age := maxf(0.0,rest-timer)
	if age<SNAP: return lerpf(-8.0,12.0,smoothstep(0.0,SNAP,age))
	if age<SNAP+CLOSED_HOLD: return 12.0
	return 12.0*(1.0-smoothstep(SNAP+CLOSED_HOLD,SNAP+CLOSED_HOLD+RETURN_TIME,age))

func apply_frame(row: Dictionary) -> void:
	_seen = true
	if _pump!=null: _pump.apply_frame(row); return
	if row==_previous_row: return
	_previous_row = row
	_dirty = true
	_begin_buffers()
	_set_glows(row.get("glows",PackedFloat32Array()))
	for i in row.ids.size():
		var n: int = i*6
		var radius := Vector2(row.transforms[n],row.transforms[n+1]).length()
		var angle := atan2(row.transforms[n+1],row.transforms[n])
		var position := Vector2(row.transforms[n+4],row.transforms[n+5])
		var deformation: PackedFloat32Array = row.get("deformations",PackedFloat32Array())
		if not deformation.is_empty():
			radius = deformation[i*5]
			angle = deformation[i*5+1]
		var jaw := 0.0
		if _biting:
			var values: Dictionary = row.biter
			if _biter: jaw = deg_to_rad(jaw_angle(values.modes[i],values.charges[i],values.timers[i],values.rests[i]))
			if values.modes[i]==3 and _death_masks.is_empty():
				var spark_age: float = values.rests[i]-values.timers[i]-SNAP
				if spark_age>=0.0 and spark_age<SPARK_TIME:
					var direction := Vector2.from_angle(angle-PI/2.0)
					var mouth := position+direction*radius*(16.0/17.0)
					_sparks.add(mouth+direction*12.0*(radius/17.0),angle-PI/2.0,32.0*(radius/17.0),Color(spark_age/SPARK_TIME,0,0,1))
		for part: Dictionary in _parts:
			if _ruler and row.ruler_sides[i]!=0 and row.ruler_sides[i]!=(-1 if part.name=="body" else 1): continue
			var turn := jaw if part.name=="jaw_left" else -jaw if part.name=="jaw_right" else 0.0
			turn+=float(part.get("angle",0.0))
			var pivot: Vector2 = part.pivot*(radius/17.0)
			var center := position+(pivot-pivot.rotated(turn)).rotated(angle)
			var began := Time.get_ticks_usec() if perf.active else 0
			part.base.add(center,angle+turn,radius,row.colors[i])
			if not deformation.is_empty(): part.base.deform_last(Vector2(deformation[i*5+2],deformation[i*5+3]),deformation[i*5+4])
			perf.since(&"enemies.body",began)

func end() -> void:
	if _pump!=null:
		if not _seen: _pump.apply_frame({})
		return
	if not _seen:
		if _previous_row.is_empty(): return
		_previous_row = {}
		_dirty = true
		_begin_buffers()
		_set_glows(PackedFloat32Array())
	if not _dirty: return
	for part: Dictionary in _parts:
		var began := Time.get_ticks_usec() if perf.active else 0
		part.base.end()
		perf.since(&"enemies.body",began)
		if part.armor==null: continue
		began = Time.get_ticks_usec() if perf.active else 0
		part.armor.apply_shared_frame(part.base)
		perf.since(&"enemies.armor",began)
	if _sparks!=null: _sparks.end()

func _draw() -> void:
	var began := Time.get_ticks_usec() if perf.active else 0
	for i in range(0,_glows.size(),3):
		for layer in range(3,0,-1):
			draw_circle(Vector2(_glows[i],_glows[i+1]),_glows[i+2]*(1.0+layer*0.22),Color(1,1,1,0.08))

	perf.since(&"view_draw.enemy_decorations",began)

func set_death_brightness(value: float) -> void:
	if value==_brightness: return
	_brightness = value
	if _pump!=null: _pump.frame_brightness(value)
	for part: Dictionary in _parts:
		part.base.material.set_shader_parameter("brightness",value)
		if part.armor!=null: part.armor.material.set_shader_parameter("brightness",value)

func frame_event(event: Dictionary, texture: Texture2D) -> void:
	if _pump!=null: _pump.frame_event(event,texture)
