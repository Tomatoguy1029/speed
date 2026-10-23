## ほうおう座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_phoenix(i, dt)

## ほうおう座：機体の周りを大きく旋回しながら飛び、飛んだ跡に炎（残る線）を残す。
func _phoenix(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var d := t.pos[i] - state.enemy_aim
	var ring := float(p.orbit) * (0.75 + 0.25 * sin(t.age[i] * 0.7 + float(t.id[i])))
	var side := Vector2(-d.y, d.x).normalized()
	var target := state.enemy_aim + d.normalized() * ring + side * 260.0
	_steer_to(i, target, t.speed[i], t.accel[i], dt)
	_turn_moving(i, t.turn[i], dt)
	t.fire_t[i] -= dt
	if t.fire_t[i] <= 0.0:
		t.fire_t[i] = float(p.trail_step)
		var back := t.pos[i] - t.vel[i] * float(p.trail_step)
		var seg := t.pos[i] - back
		if seg.length() > 1.0:
			projectiles.fire_wall(back, seg.angle(), seg.length(), float(p.trail_width), 0.0, float(p.trail_time),
				float(p.bullet_dmg), Color("#ff8a3c"))
