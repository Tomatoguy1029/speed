## 格子ビームの互換Runner。値は編集用Resourceを使う。
@tool
extends "res://scripts/data_types/boss_techniques/hydra/grid.gd"

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
