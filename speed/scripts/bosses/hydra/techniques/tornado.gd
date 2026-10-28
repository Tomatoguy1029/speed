## 瓦礫竜巻の値と動き。
@tool
extends HydraTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 12.0
## lump_dmg
@export_range(0,100000,0.01) var lump_dmg := 16.0
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 3.4
## 技後の全体待ち（秒）
@export_range(0,100000,0.01) var tech_recovery := 1.5
## 竜巻の予備動作
@export_range(0,100000,0.01) var tornado_charge := 1.2
## 竜巻が残る時間
@export_range(0,100000,0.01) var tornado_life := 1.8
## 竜巻の速さ
@export_range(0,100000,0.01) var tornado_speed := 680.0
## 竜巻の幅
@export_range(0,100000,0.01) var tornado_width := 210.0
## 予告（秒）
@export_range(0,100000,0.01) var warning_time := 0.8

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func tornado()->void:
		var p: Dictionary=a.move_params(a.tech)
		var wind=a.participants[0]
		var debris=a.participants[1]
		if not state.has("vortex"):
			var direction: Vector2=(a.run_state.ship_pos-wind.strike_pos).normalized()
			if direction==Vector2.ZERO:direction=Vector2.from_angle(wind.angle)
			state.center=wind.strike_pos+direction*120.0
			state.direction=direction
			wind.angle=direction.angle()
			debris.angle=(Vector2(state.center)-debris.strike_pos).angle()
			var points:=PackedVector2Array([state.center,state.center+Vector2(0.1,0)])
			state.vortex=a.attack_field.add_shape(points,float(p.tornado_width)*0.8,0.0,float(p.tornado_charge),0.0,&"tornado_charge",wind.row)
			state.rows=[]
			state.from=debris.strike_pos
			for j in 3:
				var row: int=a.ctx.enemies.spawn(a.ctx.enemies.def_of(&"hydra_rubble"),debris.strike_pos)
				a._rubble.append(Vector2i(row,a.table.id[row]))
				state.rows.append(row)
				a.table.color[row].a=0.0
				a.table.r[row]=26.0+float(j)*6.0
			a._cue(&"gather_started",a.tech,a.necks.find(wind))
		if not state.has("launched"):
			state.vortex.fill=clampf((time-float(p.tornado_charge)*5.0/12.0)/(float(p.tornado_charge)*7.0/12.0),0.0,1.0)
			state.vortex.feed=[]
			var from: Vector2=state.from
			var center: Vector2=state.center
			var side: Vector2=(center-from).normalized().orthogonal()
			for j in state.rows.size():
				var row: int=state.rows[j]
				var progress:=clampf((time-float(p.tornado_charge)*(0.25+float(j)*0.12)/1.2)/(float(p.tornado_charge)*0.65/1.2),0.0,1.0)
				var at:=from.lerp(center,progress)+side*sin(progress*PI)*(60.0+float(j)*35.0)
				a.table.pos[row]=at
				a.table.r[row]=(26.0+float(j)*6.0)*(1.0-progress*0.7)
				state.vortex.feed.append(Vector3(at.x,at.y,a.table.r[row]))
		if time>=float(p.tornado_charge) and not state.has("launched"):
			state.launched=true
			state.vortex.life=0.0
			for row in state.rows:a.ctx.enemies.mark_dead(row)
			var direction: Vector2=state.direction
			var points:=PackedVector2Array([state.center-direction*45.0,state.center+direction*45.0])
			a.attack_field.add_shape(points,float(p.tornado_width),0.0,float(p.tornado_life),float(p.lump_dmg),&"tornado",wind.row,direction*float(p.tornado_speed),true)
			a._cue(&"attack_started",a.tech,a.necks.find(wind))

	func perform(dt: float) -> void:
		tornado()
