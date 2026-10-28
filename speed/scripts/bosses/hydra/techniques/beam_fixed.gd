## 固定ビームの値と動き。
@tool
extends HydraTechnique

## 予備動作（秒）
@export_range(0,100000,0.01) var normal_charge := 0.6
## 攻撃後の停止（秒）
@export_range(0,100000,0.01) var normal_hold := 0.9
## 技後の待ち（秒）
@export_range(0,100000,0.01) var attack_cd := 3.0
## 光を出す時間（秒）
@export_range(0,100000,0.01) var beam_time := 1.0
## beam_len
@export_range(0,100000,0.01) var beam_len := 1400.0
## 光の太さ
@export_range(0,100000,0.01) var beam_width := 40.0
## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0

func range_info(p: Dictionary) -> Dictionary:
	return {"origin": "head", "max": float(p.beam_len) + float(p.beam_width) * 0.5}

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func tick_neck(a: Node,n,dt: float) -> void:
		var aim: Dictionary = a.move_params(n.mode)
		if a.tracks_during_warn(n.mode) and n.t <= minf(float(aim.get("aim_tracking", 0.0)), float(aim.get("normal_charge", 0.0))): n.target = a.run_state.ship_pos
		var p: Dictionary = a.move_params(n.mode)
		var charge := float(p.normal_charge)
		if n.t < charge:
			a.aim_neck(n,(n.target-a._head_pos(n)).angle(),dt)
			n.glow=n.t/charge
			var at: Vector2 = a._head_pos(n)
			var points := PackedVector2Array([at,at+Vector2.from_angle(n.angle)*float(p.beam_len)])
			if n.emission.is_empty():
				n.emission=a.attack_field.add_shape(points,float(p.beam_width),charge-n.t,float(p.beam_time),float(p.beam_dmg),&"beam",n.row)
			else: n.emission.points=points
		elif not n.locked:
			n.strike_pos=a._head_pos(n)
			n.locked=true
			a._cue(&"attack_started",n.mode,a.head_index(n))
		if n.t>=charge+float(p.beam_time)+float(p.normal_hold): a.finish_normal(n)
