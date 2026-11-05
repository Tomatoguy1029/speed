## ケフェウス座から兵の位置へ流れる召喚の光。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const WHITE := preload("res://shaders/cepheus_summon_white.gdshader")
var _settings: Dictionary = SETTINGS.for_id("G12-cepheus")
var _parent: Node2D
var _scope: ContentResourceScope
var _visuals: Dictionary
var _marks := {}
var _sprites := {}
var _last_time := -1.0

func setup(parent: Node2D, scope: ContentResourceScope, visuals: Dictionary) -> void:
	_parent = parent
	_scope = scope
	_visuals = visuals

func render(actors: Array, rows: Array, canvas, clock: float) -> void:
	if _last_time >= 0.0 and clock < _last_time:
		_marks.clear()
		for pair: Array in _sprites.values():
			for sprite: Sprite2D in pair: sprite.queue_free()
		_sprites.clear()
	_last_time = clock
	var gold := Color(_settings.gold)
	var palette := FX.ramp(gold)
	var intensity := float(_settings.intensity)
	for actor: Dictionary in actors:
		var direction := Vector2.from_angle(float(actor.angle))
		var origin: Vector2 = canvas.to_logical(actor.pos - direction * float(actor.radius) * 0.55)
		FX.gather(canvas.front,origin,float(actor.radius)*1.4*canvas.world_scale,float(actor.charge)*intensity,gold,clock,12,3)
	var present := {}
	for row: Dictionary in rows:
		var key := "%s/%s/%s" % [row.id,row.tick,row.slot]
		present[key] = true
		_marks[key] = {"row":row,"clock":clock}
	for sprite_pair: Array in _sprites.values():
		for sprite: Sprite2D in sprite_pair: sprite.hide()
	for key in _marks.keys():
		var saved: Dictionary = _marks[key]
		var row: Dictionary = saved.row
		var age := float(row.age) + maxf(0.0,clock-float(saved.clock))
		var life := float(row.life)
		if not present.has(key) and age >= life + 0.45:
			_marks.erase(key)
			if _sprites.has(key):
				for sprite: Sprite2D in _sprites[key]: sprite.queue_free()
				_sprites.erase(key)
			continue
		var from: Vector2 = canvas.to_logical(row["from"])
		var target: Vector2 = canvas.to_logical(row.pos)
		var delta := target-from
		var distance := maxf(0.000001,delta.length())
		var normal := Vector2(-delta.y,delta.x)/distance
		for i in range(40):
			var born := float(i)/40.0*life*0.92
			var f := (age-born)/0.45
			if f < 0 or f > 1: continue
			var ease := f*f*(3.0-2.0*f)
			var wave := (FX.hash_value(i*5.1+int(row.slot))-0.5)*14.0*sin(PI*ease)
			var point := from+delta*ease+normal*wave
			canvas.back.dot(point.x,point.y,palette[4] if f>0.75 else palette[3],0.4+0.6*f)
		var glow := clampf(age/life,0.0,1.0) if age < life else 1.0-_smooth(life,life+0.35,age)
		if glow > 0: canvas.back.glow(target.x,target.y,float(row.radius)*canvas.world_scale*1.6,palette[2],0.35*glow*intensity)
		var k := age/life
		if present.has(key) and k > 0.25:
			_draw_sprite(key,row,_smooth(0.25,1.0,k)*0.8,1.0-0.6*_smooth(0.6,1.0,k))

func _draw_sprite(key: String, row: Dictionary, alpha: float, white: float) -> void:
	var id := int(row.visual_id)
	if not _visuals.has(id): return
	var entry: Dictionary = _visuals[id]
	var look := _scope.resources.get(entry.path) as EnemyLook
	var preview: String = entry.get("hull_preview", "")
	if look == null or not look.previews.has(preview): return
	var texture := look.previews[preview] as Texture2D
	if texture == null: return
	if not _sprites.has(key):
		var base := Sprite2D.new()
		base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		base.z_index = -2
		_parent.add_child(base)
		var flash := Sprite2D.new()
		flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flash.z_index = -2
		var mat := ShaderMaterial.new()
		mat.shader = WHITE
		flash.material = mat
		_parent.add_child(flash)
		_sprites[key] = [base,flash]
	var pair: Array = _sprites[key]
	for sprite: Sprite2D in pair:
		sprite.texture = texture
		sprite.position = row.pos
		sprite.rotation = look.angle if look.fixed_angle else float(row.angle)+look.angle
		sprite.scale = Vector2.ONE * (2.0*float(row.sprite_radius)/maxf(texture.get_width(),texture.get_height()))
		sprite.show()
	pair[0].modulate = Color(1,1,1,alpha)
	pair[1].modulate = Color(1,1,1,white)

func _smooth(a: float, b: float, value: float) -> float:
	var t := clampf((value-a)/(b-a),0.0,1.0)
	return t*t*(3.0-2.0*t)
