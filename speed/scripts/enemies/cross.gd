## みなみじゅうじ座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_cross(i, dt)

func admit_due(i: int, dt: float) -> bool:
	return table.fire_t[i] <= dt

## みなみじゅうじ座：動き回り、機体と縦か横にそろう位置（十字の線が機体に当たる位置）へ回り込む。そろったら止まり、
## 予告してから十字のレーザーを撃つ（線はいつも縦と横）。撃ったあとは少し休む。
func _cross(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var d := state.ship_pos - t.pos[i]
	match t.mode[i]:
		EnemyTable.Mode.WINDUP:
			_hold(i, dt)
			t.timer[i] -= dt
			t.charge[i] = 1.0 - maxf(0.0, t.timer[i]) / float(p.telegraph)
			if t.timer[i] <= 0.0:
				t.charge[i] = 0.0
				state.emit(&"enemy_laser_fire", {"id": t.id[i]})
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.beam_time) + float(p.rest)
		EnemyTable.Mode.RECOVER:
			_hold(i, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE
				t.fire_t[i] = float(p.fire_interval)
		_:
			# 縦か横の近い方の軸で、機体から stand_off だけ離れた所へ回り込む
			var off := float(p.stand_off)
			var goal := Vector2(state.ship_pos.x, state.ship_pos.y - signf(d.y if d.y != 0.0 else 1.0) * off) \
				if absf(d.x) < absf(d.y) else Vector2(state.ship_pos.x - signf(d.x if d.x != 0.0 else 1.0) * off, state.ship_pos.y)
			_steer_to(i, goal, t.speed[i], t.accel[i], dt)
			t.facing[i] += dt * 1.5
			t.fire_t[i] -= dt
			var aligned := minf(absf(d.x), absf(d.y)) <= float(p.align_tol)
			if aligned and t.fire_t[i] <= 0.0 and d.length() <= float(p.beam_len) * 0.8:
				# 本体に付け、予告中・照射中に倒されたらレーザーも消す
				for h in projectiles.fire_cross(t.pos[i], 0.0, float(p.beam_len), float(p.beam_width), float(p.telegraph),
						float(p.beam_time), float(p.bullet_dmg), t.color[i].lightened(0.3)):
					projectiles.attach_hazard(h, i)
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.telegraph)
				state.emit(&"enemy_laser_charge", {"id": t.id[i], "row": i})
				t.facing[i] = 0.0
