extends RefCounted
var target := Vector2.ZERO
var fired := false
func begin(a: BossActor) -> void:
	target = a.run_state.enemy_aim
	a.telegraph_points = PackedVector2Array([target])
func tick(a: BossActor, _dt: float) -> void:
	if fired: return
	fired = true
	a.ctx.projectiles.fire_zone(target,float(a.rule().radius),0.0,float(a.rule().damage)*a.ctx.cfg.atk_scale)
	a.ctx.projectiles.fire_wave(target,0.0,PI,float(a.rule().radius)*1.5,250.0,12.0,0.0,float(a.rule().damage)*0.5*a.ctx.cfg.atk_scale)
	a.attack_points = PackedVector2Array([a.table.pos[a.body],target])
func end(a: BossActor, _cancelled: bool) -> void:
	a.telegraph_points.clear()
	a.attack_points.clear()
