## 自爆する雑魚。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_bomber(i, dt)

func admit_due(i: int, _dt: float) -> bool:
	return table.pos[i].distance_to(state.ship_pos) <= float(table.def[i].params.trigger)

## 自爆する雑魚：追ってきて、機体が trigger に入るとカウントダウンに入る。カウントダウンの間も止まらず、
## rush 倍の速さで機体へ詰め寄る。2回明滅し終わると爆発する。明滅し終わる前に倒せば爆発しない。
func _bomber(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		_chase(i, dt)
		if t.pos[i].distance_squared_to(state.ship_pos) <= float(p.trigger) * float(p.trigger):
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.blast_delay)
		return
	_steer_to(i, state.ship_pos, t.speed[i] * float(p.rush), t.accel[i] * 2.0, dt)
	_turn_moving(i, t.turn[i] * 2.0, dt)
	t.timer[i] -= dt
	# 2回明滅する。charge はカウントダウンの進み（0〜1）
	var phase := 1.0 - t.timer[i] / maxf(float(p.blast_delay), 0.001)
	t.charge[i] = clampf(phase, 0.0, 1.0)
	t.flash[i] = 0.05 if fmod(phase * 2.0, 1.0) > 0.75 else 0.0
	if t.timer[i] <= 0.0:
		_self_destruct(i)
