## みなみのかんむり座の渦と、選ばれた個体へ流れる光。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const WHITE := preload("res://shaders/cepheus_summon_white.gdshader")
var _settings: Dictionary = SETTINGS.for_id("G12-corona")
var _parent: Node2D
var _scope: ContentResourceScope
var _visuals: Dictionary
var _flashes := {}

func setup(parent: Node2D, scope: ContentResourceScope, visuals: Dictionary) -> void:
	_parent = parent
	_scope = scope
	_visuals = visuals

func render(owners: PackedFloat64Array, selected: Array, canvas, clock: float) -> void:
	var vortex := FX.ramp(Color("b6a2db"))
	for i in range(0, owners.size(), 7):
		var center: Vector2 = canvas.to_logical(Vector2(owners[i],owners[i+1]))
		var radius: float = owners[i+2]*canvas.world_scale
		var rotation: float = owners[i+3]
		for particle in range(70):
			var r := radius*(0.55+0.6*FX.hash_value(particle))
			var angle := rotation*(0.8+0.4*FX.hash_value(particle+9))+FX.hash_value(particle*3)*TAU
			for s in range(4):
				canvas.back.dot(center.x+cos(angle-s*0.08)*r,center.y+sin(angle-s*0.08)*r,vortex[3] if s<1 else vortex[2],0.55-0.12*s)
	var present := {}
	var palette := FX.ramp(Color(_settings.color))
	for row: Dictionary in selected:
		var id := int(row.id)
		present[id] = true
		var k := float(row.charge)
		var a: Vector2 = canvas.to_logical(row["from"])
		var b: Vector2 = canvas.to_logical(row.pos)
		var delta := b-a
		var normal := Vector2(-delta.y,delta.x)/maxf(delta.length(),0.000001)
		for i in range(14):
			var f := fposmod(FX.hash_value(i*3.1)+clock*2.6,1.0)
			var wave := (FX.hash_value(i*7.7)-0.5)*10.0*sin(PI*f)
			var point := a+delta*f+normal*wave
			canvas.front.dot(point.x,point.y,palette[4] if f>0.7 else palette[3],k*(0.4+0.6*f))
		canvas.front.glow(b.x,b.y,float(row.radius)*canvas.world_scale*1.4,palette[2],0.4*k*float(_settings.intensity))
		_flash(row,k*(0.35+0.35*sin(clock*30.0)))
	for id in _flashes.keys():
		if not present.has(id):
			_flashes[id].queue_free()
			_flashes.erase(id)

func _flash(row: Dictionary, alpha: float) -> void:
	var visual_id := int(row.visual_id)
	if not _visuals.has(visual_id): return
	var entry: Dictionary = _visuals[visual_id]
	var look := _scope.resources.get(entry.path) as EnemyLook
	var preview: String = entry.get("hull_preview", "")
	if look == null or not look.previews.has(preview): return
	var texture := look.previews[preview] as Texture2D
	if texture == null: return
	var id := int(row.id)
	if not _flashes.has(id):
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = WHITE
		sprite.material = mat
		sprite.z_index = 0
		_parent.add_child(sprite)
		_flashes[id] = sprite
	var sprite: Sprite2D = _flashes[id]
	sprite.texture = texture
	sprite.position = row.pos
	sprite.rotation = look.angle if look.fixed_angle else float(row.angle)+look.angle
	sprite.scale = Vector2.ONE*(2.0*float(row.sprite_radius)/maxf(texture.get_width(),texture.get_height()))
	sprite.modulate = Color(1,1,1,alpha)
