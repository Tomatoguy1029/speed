## エスコートウィングの機体と青緑の光跡をまとめて描く。
extends Node2D
const DRONE := preload("res://assets/pixel/drone.png")
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
const KEY := "weapon/dashRangeDrone"
var _bodies: InstanceBatch
var _trail: InstanceBatch
func _ready() -> void:
	_trail = InstanceBatch.new()
	_trail.setup_shader_quad()
	add_child(_trail)
	_bodies = InstanceBatch.new()
	_bodies.setup_texture(DRONE)
	add_child(_bodies)
func step(weapon: WeaponBehavior, cfg: GameConfig, _zoom: float) -> void:
	_bodies.begin()
	_trail.begin()
	var scale_value := cfg.character_scale * SETTINGS.number(KEY,"effect_scale",1.0)
	var pixel := 1.82 * cfg.character_scale * SETTINGS.number(KEY,"pixel_scale",1.0)
	var duration := 0.22 * SETTINGS.number(KEY,"duration_scale",1.0)
	if weapon != null:
		for d in weapon.drones:
			var points: Array = d.trail
			var remaining: float = weapon.level_value("tail_by_level") * scale_value
			for i in range(points.size()-1,0,-1):
				if not points[i].join:continue
				var a: Vector2 = points[i].pos
				var b: Vector2 = points[i-1].pos
				var distance := a.distance_to(b)
				if distance < 0.01:continue
				b = a.move_toward(b,minf(distance,remaining))
				var alpha := clampf(1.0-(0.22-float(points[i].life))/duration,0,1)
				for layer in 3:
					var color: Color = [Color("#5ff6ff"),Color("#3fd0e8"),Color("#f2ffff")][layer]
					color.a = alpha * [0.12,0.6,1.0][layer]
					_trail.add_rect((a+b)*0.5,Vector2(a.distance_to(b)*0.5,[4.0,2.0,1.0][layer]*pixel*0.5),(a-b).angle(),SETTINGS.tinted(KEY,color))
				if i%3==0:
					var chip: Vector2 = b + d.dir.orthogonal()*pixel*(3.0 if i%2 else -3.0)
					_trail.add_upright((chip/pixel).round()*pixel,pixel*0.5,SETTINGS.tinted(KEY,Color(0.37,0.96,1,alpha*0.65)))
				remaining -= distance
				if remaining <= 0.0:break
			_bodies.add((d.pos/pixel).round()*pixel,d.dir.angle()+PI*0.5,DRONE.get_height()*scale_value*0.5,SETTINGS.tinted(KEY,Color.WHITE))
			var exhaust: Vector2 = d.pos-d.dir*(4.0 if weapon.active else 3.5)*pixel
			_trail.add_rect((exhaust/pixel).round()*pixel,Vector2(1.0 if weapon.active else 0.5,0.5)*pixel,d.dir.angle(),SETTINGS.tinted(KEY,Color("#f2ffff") if weapon.active else Color("#3fd0e8")))
	_bodies.end()
	_trail.end()
