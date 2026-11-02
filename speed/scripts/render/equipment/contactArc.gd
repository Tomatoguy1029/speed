extends WeaponVisual

var _frame: Array = []
var _zoom := 1.0
var _probe: Sprite2D
func setup_frame(parent: Node2D, ship_parent: Node2D, texture: Texture2D, factor: float) -> void:
	node = Node2D.new()
	parent.add_child(node)
	node.draw.connect(func():
		var lightning = preload("res://scripts/render/pixel_lightning.gd")
		for value: Dictionary in _frame:
			var alpha: float = lightning.intensity(value.age,value.life)
			var shape: int = int(value.age/lightning.SHAPE_INTERVAL)
			for i in range(0,value.segments.size(),2):
				lightning.draw(node,value.segments[i],value.segments[i+1],2.0*EFFECT_SETTINGS.number("weapon/contactArc","pixel_scale",1.0)/maxf(_zoom,0.01),int(value.id)*7919+i*313+shape*101,alpha,EFFECT_SETTINGS.tinted("weapon/contactArc",Color("#ffcf3a")),Color("#fff8d6")))
	_probe = Sprite2D.new()
	_probe.texture = texture
	_probe.offset = Vector2(0,texture.get_height()*0.5-30.0) if texture!=null else Vector2.ZERO
	_probe.scale = Vector2.ONE*factor
	ship_parent.add_child(_probe)
func frame_tick(data: Dictionary, ship: Dictionary, zoom: float, visible: bool) -> void:
	_frame = data.visuals.duplicate(true)
	for value: Dictionary in _frame: value.life = data.visual_life
	_zoom = zoom
	node.queue_redraw()
	_probe.position = ship.ship_pos
	_probe.rotation = ship.ship_heading.angle()+PI/2.0
	_probe.visible = visible
	_probe.modulate = Color("#ff6b5a") if ship.ship_hurt>0.0 else Color.WHITE
func dispose() -> void:
	if is_instance_valid(_probe): _probe.queue_free()
	super()
