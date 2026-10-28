## 格子ビームの値と動き。
@tool
extends HydraTechnique

## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0:
	set(value):
		beam_dmg = value
		_values_dirty = true
## 光の太さ
@export_range(0,100000,0.01) var beam_width := 40.0:
	set(value):
		beam_width = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 30.0:
	set(value):
		cooldown = value
		_values_dirty = true
## 格子攻撃の時間
@export_range(0,100000,0.01) var grid_time := 3.5:
	set(value):
		grid_time = value
		_values_dirty = true
## 予備動作（秒）
@export_range(0,100000,0.01) var normal_charge := 0.6:
	set(value):
		normal_charge = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 5.2:
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
	func grid()->void:
		var p: Dictionary=a.move_params(a.tech)
		for i in a.participants.size():
			var n=a.participants[i]
			if not a._alive(n) or not n.emission.is_empty():continue
			var points:=PackedVector2Array([n.strike_pos,state.plan.beams[i][1]])
			n.angle=(points[1]-points[0]).angle()
			n.emission=a.attack_field.add_shape(points,float(p.beam_width),float(p.normal_charge),float(p.grid_time),float(p.beam_dmg),&"beam",n.row)
			n.mode=&"special_hold"
			a._cue(&"attack_started",a.tech,a.necks.find(n))

	func perform(dt: float) -> void:
		grid()

	func kind() -> StringName:
		return &"grid"
