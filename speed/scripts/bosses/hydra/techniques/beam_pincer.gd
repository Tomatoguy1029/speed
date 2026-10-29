## 挟撃ビームの値と動き。
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
@export_range(0,100000,0.01) var cooldown := 12.0:
	set(value):
		cooldown = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 3.4:
	set(value):
		performance_time = value
		_values_dirty = true
## 挟み込みの終点角度（度）
@export_range(0,100000,0.01) var pincer_close_angle := 0.12:
	set(value):
		pincer_close_angle = value
		_values_dirty = true
## 挟み込みまでの遅れ
@export_range(0,100000,0.01) var pincer_delay := 0.5:
	set(value):
		pincer_delay = value
		_values_dirty = true
## 挟み込みの開始角度（度）
@export_range(0,100000,0.01) var pincer_open_angle := 0.8:
	set(value):
		pincer_open_angle = value
		_values_dirty = true
## 挟み込みの時間
@export_range(0,100000,0.01) var pincer_time := 1.8:
	set(value):
		pincer_time = value
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
	func beam_pincer()->void:
		var p: Dictionary=a.move_params(a.tech)
		if not state.has("aims"):
			state.aims=[]
			for n in a.participants:state.aims.append((a.run_state.ship_pos-n.strike_pos).angle())
		for j in a.participants.size():
			var n=a.participants[j]
			var side:=1.0 if j==0 else -1.0
			n.angle=float(state.aims[j])+side*lerpf(float(p.pincer_open_angle),float(p.pincer_close_angle),clampf((time-float(p.pincer_delay))/float(p.pincer_time),0.0,1.0))
			var points:=PackedVector2Array([n.strike_pos,n.strike_pos+Vector2.from_angle(n.angle)*float(p.beam_len)])
			if n.emission.is_empty():n.emission=a.attack_field.add_shape(points,float(p.beam_width),float(p.pincer_delay),float(p.pincer_time),float(p.beam_dmg),&"beam",n.row)
			else:n.emission.points=points


	## 配置の途中も同じ操舵を使う。到着まで攻撃の時間軸を進めない。

	func perform(dt: float) -> void:
		beam_pincer()

	func kind() -> StringName:
		return &"beam_pincer"
