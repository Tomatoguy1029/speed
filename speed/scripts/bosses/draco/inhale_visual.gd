## 技に合わせた予告とエフェクト。
extends "res://scripts/bosses/draco/technique_visual.gd"

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	super()
	if actor.technique == technique_id and actor._runner != null and not actor._runner.spent:
		var mouth := actor.to_local(actor.mouth_pos())
		for j in 24:
			var k := fmod(actor.elapsed*0.7+j/24.0,1.0)
			var angle := j*2.399963
			var at := mouth+Vector2.from_angle(angle)*float(actor.rule().pull_range)*(1.0-k)
			draw_line(at,at+(mouth-at).normalized()*25.0,Color(0.6,0.5,1.0,k*0.6),3.0)
