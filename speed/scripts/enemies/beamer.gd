## ビームの敵：距離を保ち、間隔ごとに止まって砲口に光を集め、ビームを撃つ。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	if table.mode[i] == EnemyTable.Mode.MOVE:
		_keep_distance(i, dt)
	else:
		_hold(i, dt)
	_beamer(i, dt)

## ビームの敵：距離を保ち、間隔ごとに止まって砲口に光を集め、ビームを撃つ。
func _beamer(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		t.fire_t[i] -= dt
		if t.fire_t[i] <= 0.0:
			var a := (state.enemy_aim - t.pos[i]).angle()
			t.facing[i] = a
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.telegraph) + float(p.beam_time)
			var beams := PackedInt32Array()
			if p.get("cross", false):
				# みなみじゅうじ座：十字のレーザー
				beams = projectiles.fire_cross(t.pos[i], a + PI / 4.0, float(p.beam_len), float(p.beam_width),
					float(p.telegraph), float(p.beam_time), float(p.bullet_dmg), t.color[i].lightened(0.3))
			else:
				beams.append(projectiles.fire_beam(t.pos[i] + Vector2.from_angle(a) * t.r[i], a, float(p.beam_len), float(p.beam_width),
					float(p.telegraph), float(p.beam_time), float(p.bullet_dmg), t.color[i].lightened(0.3)))
			# 予告の間、ビームの通り道を予告線で示す。
			for h in beams:
				if h >= 0: projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.GUIDE
		return
	t.timer[i] -= dt
	# charge は砲口に光が集まる進み（0〜1）。撃っている間は 1
	t.charge[i] = clampf(1.0 - (t.timer[i] - float(p.beam_time)) / float(p.telegraph), 0.0, 1.0)
	if t.timer[i] <= 0.0:
		t.mode[i] = EnemyTable.Mode.MOVE
		t.fire_t[i] = float(p.fire_interval)
		t.charge[i] = 0.0
