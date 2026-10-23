## かじき座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_marlin(i, dt)

## かじき座：距離を保ち、光って予告してから、機体の方へ高速で泳ぎ抜ける。泳いでいる間、左右へ扇状にしぶきを撒く。
func _marlin(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_keep_distance(i, dt)
			if _gun_timer(i, dt):
				var a := (state.enemy_aim - t.pos[i]).angle()
				t.facing[i] = a
				t.vel[i] = Vector2.from_angle(a) * float(p.dash_speed)
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = float(p.dash_time)
				t.bud_t[i] = 0.0
		EnemyTable.Mode.DASH:
			t.timer[i] -= dt
			t.bud_t[i] -= dt
			if t.bud_t[i] <= 0.0:
				t.bud_t[i] = float(p.spray_step)
				var n := int(p.spray)
				for side: float in [-1.0, 1.0]:
					for k in n:
						var a := t.facing[i] + side * PI / 2.0 + (float(k) / maxf(n - 1, 1) - 0.5) * float(p.spread)
						projectiles.fire_enemy(i, a, float(p.bullet_speed), &"bullet")
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = 0.8
		_:
			_hold(i, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE
