extends RefCounted
const ARROW = preload("res://scripts/attacks/cosmic_arrow.gd")
const ARROW_VISUAL = preload("res://scripts/render/attacks/cosmic_arrow.gd")
var shots := 0
var impacts: Array = []
func begin(a: BossActor) -> void:
	a.picaro.attacking = true
	var choices: Array = a.rule().get("wall_candidates",[&"sniper",&"lynx"])
	for j in int(a.rule().count):
		var position: Vector2 = a.table.pos[a.body].lerp(a.aim,0.45)+Vector2(0,(j-1)*180.0)
		a.picaro.spawn_picaro(StringName(choices[j%choices.size()]),position)
func tick(a: BossActor, dt: float) -> void:
	if shots<int(a.rule().arrows) and a.elapsed>=shots*float(a.rule().interval):
		var from: Vector2 = a.table.pos[a.body]+Vector2(70,-20)
		a.ctx.projectiles.emit_attack(&"cosmic_arrow",[from,-PI*0.5,900.0,12.0,maxf(1000.0,a.run_state.view_half.y*2.5),0.0,true])
		impacts.append({"wait":float(a.rule().flight),"warn":float(a.rule().impact_warn),"pos":Vector2.INF,"age":0.0})
		shots+=1
	for impact: Dictionary in impacts.duplicate():
		impact.age = float(impact.age)+dt
		if impact.pos == Vector2.INF and float(impact.age)>=float(impact.wait): impact.pos=a.run_state.enemy_aim
		if impact.pos != Vector2.INF and float(impact.age)>=float(impact.wait)+float(impact.warn):
			a.ctx.projectiles.fire_zone(impact.pos,float(a.rule().radius),0.0,float(a.rule().damage)*a.ctx.cfg.atk_scale,ProjectileSystem.HazardStyle.BLAST,Color("#b7a3ff"))
			a.presentation_event.emit({"cue":&"arrow_impact","pos":impact.pos,"radius":a.rule().radius})
			impacts.erase(impact)
func end(a: BossActor, _cancelled: bool) -> void:
	impacts.clear()
	a.picaro.pause(_cancelled)
