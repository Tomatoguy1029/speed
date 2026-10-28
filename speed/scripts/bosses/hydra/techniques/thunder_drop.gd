## 落雷の値と動き。
@tool
extends HydraTechnique

## 予備動作（秒）
@export_range(0,100000,0.01) var normal_charge := 0.6
## 攻撃後の停止（秒）
@export_range(0,100000,0.01) var normal_hold := 0.9
## 技後の待ち（秒）
@export_range(0,100000,0.01) var attack_cd := 3.0
## 雷の範囲
@export_range(0,100000,0.01) var thunder_radius := 150.0
## 雷光の時間
@export_range(0,100000,0.01) var thunder_flash := 0.22
## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0
## 狙いを固定する割合
@export_range(0,100000,0.01) var target_lock_fraction := 0.55
## 雷の先読み距離
@export_range(0,100000,0.01) var thunder_lead := 0.4

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn")

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func tick_neck(a: Node,n,dt: float) -> void:
		var aim: Dictionary = a.move_params(n.mode)
		if a.tracks_during_warn(n.mode) and n.t <= minf(float(aim.get("aim_tracking", 0.0)), float(aim.get("normal_charge", 0.0))): n.target = a.run_state.ship_pos
		var p: Dictionary = a.move_params(n.mode)
		var charge := float(p.normal_charge)
		if not n.locked:
			var points := PackedVector2Array([n.target,n.target+Vector2(0.1,0)])
			if n.emission.is_empty(): n.emission=a.attack_field.add_shape(points,float(p.thunder_radius)*2.0,charge-n.t,float(p.thunder_flash),float(p.beam_dmg),&"lightning",n.row)
			else: n.emission.points=points
			n.glow=n.t/charge
			if n.t>=charge*float(p.target_lock_fraction):
				n.strike_pos=a._head_pos(n)
				n.locked=true
				a._cue(&"target_locked",n.mode,a.head_index(n))
		if n.t>=charge and n.step==0:
			n.step=1
			a._cue(&"attack_started",n.mode,a.head_index(n))
		if n.t>=charge+float(p.thunder_flash)+float(p.normal_hold): a.finish_normal(n)
