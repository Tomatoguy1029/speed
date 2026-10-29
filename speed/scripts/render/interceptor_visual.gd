## ストライクウィングの機体・装甲・砲口をまとめて描く。
extends Node2D
const DRONE := preload("res://assets/pixel/drone.png")
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
const KEY := "weapon/interceptor"
var _bodies: InstanceBatch
var _parts: InstanceBatch
func _ready() -> void:
	_bodies = InstanceBatch.new()
	_bodies.setup_texture(DRONE)
	add_child(_bodies)
	_parts = InstanceBatch.new()
	_parts.setup_shader_quad()
	add_child(_parts)
func step(weapon, cfg: GameConfig) -> void:
	_bodies.begin()
	_parts.begin()
	var scale_value := cfg.character_scale * SETTINGS.number(KEY,"effect_scale",1.0)
	var pixel := 1.82 * cfg.character_scale * SETTINGS.number(KEY,"pixel_scale",1.0)
	if weapon != null:
		for d in weapon.drones:
			var angle: float = d.angle + PI * 0.5
			_bodies.add((d.pos/pixel).round()*pixel,angle,DRONE.get_height()*scale_value*0.5,SETTINGS.tinted(KEY,Color.WHITE))
			for x in [-5.0,4.0]:
				_part(d.pos,Vector2(x+0.5,0),Vector2(0.5,2),angle,pixel,Color("#3e9eaa"))
			for x in [-2.0,1.0]:
				_part(d.pos,Vector2(x+0.5,-5),Vector2(0.5,1),angle,pixel,Color("#8fffe2"))
			if d.flash > 0.0:
				var pos: Vector2 = d.pos + Vector2.from_angle(d.angle)*6.0*pixel
				var first: bool = d.flash > 0.03
				_parts.add_rect((pos/pixel).round()*pixel,Vector2.ONE*pixel*(1.5 if first else 1.0),0,SETTINGS.tinted(KEY,Color.WHITE if first else Color("#ffc77c")))
	_bodies.end()
	_parts.end()
func _part(center: Vector2, offset: Vector2, half: Vector2, angle: float, pixel: float, color: Color) -> void:
	_parts.add_rect(center+(offset*pixel).rotated(angle),half*pixel,angle,SETTINGS.tinted(KEY,color))
