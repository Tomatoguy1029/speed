## 瓦礫砕きの値と動き。
@tool
extends HydraTechnique

## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0
## beam_len
@export_range(0,100000,0.01) var beam_len := 1400.0
## 光の太さ
@export_range(0,100000,0.01) var beam_width := 40.0
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 12.0
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 3.4
## rubble_count
@export_range(0,100000,1) var rubble_count := 6
## shard_dmg
@export_range(0,100000,0.01) var shard_dmg := 10.0
## shard_speed
@export_range(0,100000,0.01) var shard_speed := 420.0
## 破片の広がり角度（度）
@export_range(0,100000,0.01) var shatter_arc := 1.8
## 破片を広げる時間
@export_range(0,100000,0.01) var shatter_deploy := 0.7
## 破片が残る時間
@export_range(0,100000,0.01) var shatter_time := 1.8
## 技後の全体待ち（秒）
@export_range(0,100000,0.01) var tech_recovery := 1.5
## 予告（秒）
@export_range(0,100000,0.01) var warning_time := 0.8

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn")

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func debris_shatter()->void:
		var p: Dictionary=a.move_params(a.tech)
		var debris=a.participants[0]
		var beam=a.participants[1]
		if not state.has("deployed"):
			state.deployed=true
			state.aim=(a.run_state.ship_pos-beam.strike_pos).angle()
			for j in int(p.rubble_count):
				var offset: float=(float(j)/maxf(1.0,float(p.rubble_count)-1.0)-0.5)*1.4
				var at: Vector2=beam.strike_pos+Vector2.from_angle(float(state.aim)+offset)*420.0
				var row: int=a.ctx.enemies.spawn(a.ctx.enemies.def_of(&"hydra_rubble"),debris.strike_pos)
				a._rubble.append(Vector2i(row,a.table.id[row]))
				a.table.vel[row]=Vector2.ZERO
				state[row]={"from":debris.strike_pos,"to":at}
		if time<float(p.shatter_deploy):
			for ref in a._rubble:
				a.table.pos[ref.x]=Vector2(state[ref.x].from).lerp(state[ref.x].to,clampf(time/float(p.shatter_deploy),0.0,1.0))
		if time>=float(p.shatter_deploy) and time<float(p.shatter_deploy)+float(p.shatter_time):
			beam.angle=float(state.aim)-float(p.shatter_arc)*0.5+float(p.shatter_arc)*clampf((time-float(p.shatter_deploy))/float(p.shatter_time),0.0,1.0)
			var points:=PackedVector2Array([beam.strike_pos,beam.strike_pos+Vector2.from_angle(beam.angle)*float(p.beam_len)])
			if beam.emission.is_empty():beam.emission=a.attack_field.add_shape(points,float(p.beam_width),0.0,float(p.shatter_time),float(p.beam_dmg),&"beam",beam.row)
			else:beam.emission.points=points
			for ref in a._rubble.duplicate():
				if not a.ctx.enemies.is_same(ref.x,ref.y) or a.table.dead[ref.x]:
					a._rubble.erase(ref)
					continue
				if Geometry2D.get_closest_point_to_segment(a.table.pos[ref.x],points[0],points[1]).distance_to(a.table.pos[ref.x])<=a.table.r[ref.x]+float(p.beam_width)*0.5:
					a._burst_rubble(ref.x,(a.table.pos[ref.x]-beam.strike_pos).normalized())
					a._rubble.erase(ref)
					a._cue(&"rubble_shattered",a.tech,a.necks.find(beam))

	func perform(dt: float) -> void:
		debris_shatter()
