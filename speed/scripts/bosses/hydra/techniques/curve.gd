## 曲線ビームの値と動き。
@tool
extends HydraTechnique

## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0:
	set(value):
		beam_dmg = value
		_values_dirty = true
## beam_len
@export_range(0,100000,0.01) var beam_len := 1400.0:
	set(value):
		beam_len = value
		_values_dirty = true
## 光の太さ
@export_range(0,100000,0.01) var beam_width := 40.0:
	set(value):
		beam_width = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 14.0:
	set(value):
		cooldown = value
		_values_dirty = true
## 曲線攻撃までの遅れ
@export_range(0,100000,0.01) var curve_delay := 0.8:
	set(value):
		curve_delay = value
		_values_dirty = true
## 曲線攻撃の軌跡差（度）
@export_range(0,100000,0.01) var curve_lag := 1.1:
	set(value):
		curve_lag = value
		_values_dirty = true
## 曲線攻撃の時間
@export_range(0,100000,0.01) var curve_time := 2.6:
	set(value):
		curve_time = value
		_values_dirty = true
## 曲線攻撃の回転速度（度/秒）
@export_range(0,100000,0.01) var curve_turn := 0.45:
	set(value):
		curve_turn = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 3.4:
	set(value):
		performance_time = value
		_values_dirty = true
## 技後の全体待ち（秒）
@export_range(0,100000,0.01) var tech_recovery := 1.5:
	set(value):
		tech_recovery = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warning_time := 0.8:
	set(value):
		warning_time = value
		_values_dirty = true

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func curve(dt: float)->void:
		var p: Dictionary=a.move_params(a.tech)
		a.table.facing[a.body]+=float(p.curve_turn)*dt
		for n in a.participants:
			if not a._alive(n):continue
			n.angle=n.base_angle+a.table.facing[a.body]
			n.strike_pos=a._neck_base(n)+Vector2.from_angle(n.angle)*float(p.neck_rest)
			var points:=PackedVector2Array([n.strike_pos])
			var at: Vector2=n.strike_pos
			for j in range(1,25):
				var f:=float(j)/24.0
				at+=Vector2.from_angle(n.angle-f*float(p.curve_lag))*float(p.beam_len)/24.0
				points.append(at)
			if n.emission.is_empty():
				n.emission=a.attack_field.add_shape(points,float(p.beam_width),float(p.curve_delay),float(p.curve_time),float(p.beam_dmg),&"beam",n.row)
			else:n.emission.points=points
			if time>=float(p.curve_time):
				n.emission.life=0.0
				n.mode=&"special_hold"

	func perform(dt: float) -> void:
		curve(dt)

	func kind() -> StringName:
		return &"curve"
