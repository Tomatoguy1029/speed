## かに座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_crab(i, dt)

## かに座：近づいてきて、機体が届く距離に入るとハサミを開き（構え）、前方を挟む。
## 挟んだ直後はハサミが開いたままで（mode が RECOVER）、正面からでも倒せる。
func _crab(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_steer_to(i, state.enemy_aim, t.speed[i], t.accel[i], dt)
			_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i], dt)
			t.fire_t[i] -= dt
			var reach := float(p.reach) + t.r[i]
			if t.fire_t[i] <= 0.0 and t.pos[i].distance_squared_to(state.ship_pos) < reach * reach * 1.6:
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.telegraph)
		EnemyTable.Mode.WINDUP:
			_hold(i, dt)
			_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i] * 0.5, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				var at := t.pos[i] + Vector2.from_angle(t.facing[i]) * (t.r[i] + float(p.reach) * 0.5)
				projectiles.fire_zone(at, float(p.reach) * 0.6, 0.0, float(p.bullet_dmg),
					ProjectileSystem.HazardStyle.PLAIN, t.color[i].lightened(0.3))
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.open_time)
		_:
			_hold(i, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE
				t.fire_t[i] = float(p.fire_interval)
