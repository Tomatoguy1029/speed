## 曲線ビームの互換Runner。値は編集用Resourceを使う。
@tool
extends "res://scripts/data_types/boss_techniques/hydra/curve.gd"

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
