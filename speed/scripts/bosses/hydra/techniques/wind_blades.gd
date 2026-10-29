## 風刃の値と動き。
@tool
extends HydraTechnique

## 予備動作（秒）
@export_range(0,100000,0.01) var normal_charge := 0.6:
	set(value):
		normal_charge = value
		_values_dirty = true
## 攻撃後の停止（秒）
@export_range(0,100000,0.01) var normal_hold := 0.9:
	set(value):
		normal_hold = value
		_values_dirty = true
## 技後の待ち（秒）
@export_range(0,100000,0.01) var attack_cd := 3.0:
	set(value):
		attack_cd = value
		_values_dirty = true
## 刃を出す間隔
@export_range(0,100000,0.01) var blade_interval := 0.18:
	set(value):
		blade_interval = value
		_values_dirty = true
## 刃の大きさ
@export_range(0,100000,0.01) var blade_size := 100.0:
	set(value):
		blade_size = value
		_values_dirty = true
## 刃の幅
@export_range(0,100000,0.01) var blade_width := 28.0:
	set(value):
		blade_width = value
		_values_dirty = true
## 刃が残る時間
@export_range(0,100000,0.01) var blade_life := 3.0:
	set(value):
		blade_life = value
		_values_dirty = true
## 刃の速さ
@export_range(0,100000,0.01) var blade_speed := 600.0:
	set(value):
		blade_speed = value
		_values_dirty = true
## 刃の広がり角度（度）
@export_range(0,100000,0.01) var blade_spread := 1.0:
	set(value):
		blade_spread = value
		_values_dirty = true
## bite_dmg
@export_range(0,100000,0.01) var bite_dmg := 16.0:
	set(value):
		bite_dmg = value
		_values_dirty = true

func range_info(p: Dictionary) -> Dictionary:
	return {"origin": "head", "max": float(p.blade_speed) * float(p.blade_life) + float(p.blade_size)}

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func tick_neck(a: Node,n,dt: float) -> void:
		var aim: Dictionary = a.move_params(n.mode)
		if a.tracks_during_warn(n.mode) and n.t <= minf(float(aim.get("aim_tracking", 0.0)), float(aim.get("normal_charge", 0.0))): n.target = a.run_state.ship_pos
		var p: Dictionary = a.move_params(n.mode)
		var charge := float(p.normal_charge)
		if n.t < charge:
			a.aim_neck(n,(n.target-a._head_pos(n)).angle()-float(p.blade_spread)*0.5,dt)
			n.glow=n.t/charge
		elif not n.locked:
			n.strike_pos=a._head_pos(n)
			n.locked=true
			n.sweep=(n.target-n.strike_pos).angle()
		if n.locked and n.step<3 and n.t>=charge+n.step*float(p.blade_interval):
			n.angle=n.sweep+(float(n.step)*0.5-0.5)*float(p.blade_spread)
			var points := PackedVector2Array()
			for i in 13:
				var angle := -PI*0.5+PI*float(i)/12.0
				points.append(n.strike_pos+Vector2(cos(angle)*float(p.blade_size)*0.6,sin(angle)*float(p.blade_size)).rotated(n.angle))
			a.attack_field.add_shape(points,float(p.blade_width),0.0,float(p.blade_life),float(p.bite_dmg),&"wind_blade",n.row,Vector2.from_angle(n.angle)*float(p.blade_speed),true)
			n.step+=1
			a._cue(&"attack_started",n.mode,a.head_index(n))
		if n.t>=charge+2.0*float(p.blade_interval)+float(p.normal_hold): a.finish_normal(n)

	func kind() -> StringName:
		return &"wind_blades"
