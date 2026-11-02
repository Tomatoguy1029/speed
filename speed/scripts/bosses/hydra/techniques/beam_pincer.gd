## 挟撃ビームの互換Runner。値は編集用Resourceを使う。
@tool
extends "res://scripts/data_types/boss_techniques/hydra/beam_pincer.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func beam_pincer()->void:
		var p: Dictionary=a.move_params(a.tech)
		if not state.has("aims"):
			state.aims=[]
			for n in a.participants:state.aims.append((a.neck_tracking_target(n,a.run_state.ship_pos)-n.strike_pos).angle())
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
