## みずがめ座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_aquarius(i, dt)

func admit_due(i: int, dt: float) -> bool:
	return table.fire_t[i] <= dt

## みずがめ座：瓶の口をいつも機体へ向けたまま機体へ近づき、approach の距離まで来たら、
## 先へ行くほど広がる極太ビームを全方位へ beams 本、等間隔で一斉に照射する。
## 1本は機体の方を向く。撃つ向きは予告の始めに決め、telegraph の間は溜めながら通り道に水の流れを流して予告し、
## 撃つと beam_time の間だけ当てる。溜めの間はだんだん遅くなって止まり、瓶の口を機体の方へ向ける。
## ビームの間には安全な隙間が残る。WINDUP が溜め・予告と照射、RECOVER が照射後の休み。
func _aquarius(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	match t.mode[i]:
		EnemyTable.Mode.WINDUP:
			var beam_time := float(p.beam_time)
			if t.timer[i] > beam_time:
				# 溜め：だんだん遅くなって止まり、瓶の口を機体の方へ向ける
				t.vel[i] *= maxf(0.0, 1.0 - 2.5 * dt)
				_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), 2.0, dt)
			else:
				_hold(i, dt)
			var before := t.timer[i]
			t.timer[i] -= dt
			if before > beam_time and t.timer[i] <= beam_time:
				state.emit(&"enemy_laser_fire", {"id": t.id[i]})
			t.charge[i] = clampf(1.0 - (t.timer[i] - beam_time) / float(p.telegraph), 0.0, 1.0)
			if t.timer[i] <= 0.0:
				t.charge[i] = 0.0
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.rest)
		EnemyTable.Mode.RECOVER:
			_hold(i, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE
		_:
			# 機体の方へ、approach の距離の所まで寄る。瓶の口はいつも機体を向く
			var to_ship := state.ship_pos - t.pos[i]
			var dist := to_ship.length()
			var approach := float(p.approach)
			var goal := state.ship_pos - to_ship / maxf(dist, 1.0) * approach
			var speed := t.speed[i] * clampf((dist - approach) / 200.0, 0.0, 1.0)
			_steer_to(i, goal, speed, t.def[i].accel, dt)
			_turn_toward(i, to_ship.angle(), t.turn[i], dt)
			t.fire_t[i] -= dt
			if t.fire_t[i] <= 0.0 and dist <= approach * 1.25:
				t.fire_t[i] = float(p.fire_interval)
				var a := to_ship.angle()
				var n := int(p.beams)
				# 照射の瞬間の衝撃と、照射後に崩れて残る水しぶきの演出（描画が本体の生存を確かめる）
				state.emit(&"aquarius_aim", {"pos": t.pos[i], "angle": a, "count": n, "length": float(p.beam_len),
					"width": float(p.beam_width), "spread": float(p.beam_spread), "delay": float(p.telegraph),
					"active": float(p.beam_time), "color": t.color[i].lightened(0.25), "row": i, "id": t.id[i]})
				for k in n:
					var h := projectiles.fire_flood(t.pos[i], a + k * TAU / n, float(p.beam_len), float(p.beam_width),
						float(p.beam_spread), float(p.telegraph), float(p.beam_time), float(p.bullet_dmg),
						t.color[i].lightened(0.25))
					# 予告中・照射中に倒されたら消える
					projectiles.attach_hazard(h, i)
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.telegraph) + float(p.beam_time)
				state.emit(&"enemy_laser_charge", {"id": t.id[i], "row": i})
