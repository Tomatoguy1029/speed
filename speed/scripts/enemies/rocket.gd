## ミサイル：出た向きのまま一直線に飛ぶ。機体に近づくと爆発し、飛ぶ時間が過ぎると消える。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_rocket(i, dt)

func admit_due(_i: int, _dt: float) -> bool:
	return true

## ミサイル：出た向きのまま一直線に飛ぶ。機体に近づくと爆発し、飛ぶ時間が過ぎると消える。
func _rocket(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		var a := (state.enemy_aim - t.pos[i]).angle()
		t.facing[i] = a
		t.vel[i] = Vector2.from_angle(a) * t.speed[i]
		t.mode[i] = EnemyTable.Mode.DASH
		t.timer[i] = float(p.life)
		return
	t.timer[i] -= dt
	if t.pos[i].distance_squared_to(state.ship_pos) <= float(p.fuse) * float(p.fuse):
		_self_destruct(i)
	elif t.timer[i] <= 0.0:
		mark_dead(i)
