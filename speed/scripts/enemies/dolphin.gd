## いるか座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_dolphin(i, dt)

func admit_due(i: int, dt: float) -> bool:
	return table.fire_t[i] <= dt

## いるか座：距離を保ち、間隔ごとに構えて（WINDUP。機体の方へ向き直りながら、撃つ向きを予告する）、機体の方へ大きな扇の波動を撃つ。
## 波動は数層の弧でできたひとまとまりの一発で、当たるのは先頭の1枚だけ。機体にもほかの敵にも当たる（敵に敵を倒させる）。
func _dolphin(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	match t.mode[i]:
		EnemyTable.Mode.WINDUP:
			_hold(i, dt)
			_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), float(p.aim_turn), dt)
			t.timer[i] -= dt
			t.charge[i] = 1.0 - maxf(0.0, t.timer[i]) / float(p.telegraph)
			if t.timer[i] <= 0.0:
				var h := projectiles.fire_wave(t.pos[i] + Vector2.from_angle(t.facing[i]) * t.r[i], t.facing[i], float(p.wave_arc),
					float(p.wave_radius), float(p.wave_speed), float(p.wave_width), 0.0, float(p.bullet_dmg), 0.0, 0.0, Color(1.0, 0.3, 0.25))
				projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.RIPPLE
				projectiles.hazard_edmg[h] = float(p.enemy_dmg)
				t.charge[i] = 0.0
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = 0.6
		EnemyTable.Mode.RECOVER:
			_hold(i, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE
				t.fire_t[i] = float(p.fire_interval)
		_:
			_keep_distance(i, dt)
			t.fire_t[i] -= dt
			if t.fire_t[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.telegraph)
