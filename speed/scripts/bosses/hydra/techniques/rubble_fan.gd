## 瓦礫の散弾の値と動き。
@tool
extends HydraTechnique

## 予備動作（秒）
@export_range(0,100000,0.01) var normal_charge := 0.6
## 攻撃後の停止（秒）
@export_range(0,100000,0.01) var normal_hold := 0.9
## 技後の待ち（秒）
@export_range(0,100000,0.01) var attack_cd := 3.0
## rubble_count
@export_range(0,100000,1) var rubble_count := 6
## 瓦礫の広がり角度（度）
@export_range(0,100000,0.01) var rubble_spread := 1.3
## 小さい瓦礫の半径
@export_range(0,100000,0.01) var rubble_small_radius := 16.0
## lump_speed
@export_range(0,100000,0.01) var lump_speed := 520.0
## lump_dmg
@export_range(0,100000,0.01) var lump_dmg := 16.0

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
		if n.t < charge:
			a.aim_neck(n,(n.target-a._head_pos(n)).angle(),dt)
			n.glow=n.t/charge
		elif not n.locked:
			n.strike_pos=a._head_pos(n)
			n.locked=true
			if n.mode==&"rubble_lump":
				launch_rubble(a,n,n.angle,float(p.lump_r))
			else:
				for i in int(p.rubble_count):
					var angle: float = n.angle+float(p.rubble_spread)*(float(i)/maxf(1.0,float(p.rubble_count)-1.0)-0.5)
					launch_rubble(a,n,angle,float(p.rubble_small_radius))
			a._cue(&"attack_started",n.mode,a.head_index(n))
		if n.t>=charge+float(p.normal_hold): a.finish_normal(n)

	func launch_rubble(a: Node,n,angle: float,radius: float) -> void:
		var row: int = a.ctx.enemies.spawn(a.ctx.enemies.def_of(&"hydra_rubble"),a._head_pos(n))
		a.table.r[row]=radius
		a.table.vel[row]=Vector2.from_angle(angle)*float(a.move_params(n.mode).lump_speed)
		var at: Vector2 = a.table.pos[row]
		var e: Dictionary = a.attack_field.add_shape(PackedVector2Array([at,at+Vector2(0.1,0)]),radius*2.0,0.0,float(a.ctx.enemies.def_of(&"hydra_rubble").params.life),float(a.move_params(n.mode).lump_dmg),&"rubble",n.row,Vector2.ZERO,true)
		e.follow_row=row
		e.follow_id=a.table.id[row]
