## 突進型：近づくと構え（WINDUP）、向いた方へ突進し（DASH）、少し休む（RECOVER）。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_dash(i, dt)

func admit_due(i: int, _dt: float) -> bool:
	return table.pos[i].distance_to(state.enemy_aim) <= float(table.def[i].params.range)

func _dash(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var d := state.enemy_aim.distance_to(t.pos[i])
	t.timer[i] -= dt
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_chase(i, dt)
			if d < float(p.range):
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = p.windup
		EnemyTable.Mode.WINDUP:
			t.vel[i] *= 1.0 - 4.0 * dt
			_turn_toward(i, (state.enemy_aim - t.pos[i]).angle(), 6.0, dt)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = p.dash_time
				t.vel[i] = Vector2.from_angle(t.facing[i]) * float(p.dash_speed)
		EnemyTable.Mode.DASH:
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = p.recover
		EnemyTable.Mode.RECOVER:
			t.vel[i] *= 1.0 - 2.0 * dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE
