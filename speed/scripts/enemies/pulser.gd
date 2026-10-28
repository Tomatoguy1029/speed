## 波動の敵：距離を保ち、間隔ごとに止まって、1枚の輪か扇を出す。
extends EnemyBehavior

func wait_for_attack(i: int, dt: float) -> void:
	_keep_distance(i, dt)

func step(i: int, dt: float) -> void:
	if table.mode[i] == EnemyTable.Mode.MOVE:
		_keep_distance(i, dt)
	else:
		_hold(i, dt)
	_pulser(i, dt)

## 波動の敵：距離を保ち、間隔ごとに止まって、1枚の輪か扇を出す。
func _pulser(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		t.fire_t[i] -= dt
		if t.fire_t[i] <= 0.0:
			var a := (state.enemy_aim - t.pos[i]).angle()
			t.facing[i] = a
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.telegraph)
			if int(p.get("layers", 1)) > 1:
				# いるか座：何層もの輪。層ごとに切れ目がずれる
				projectiles.fire_rings(t.pos[i], int(p.layers), float(p.layer_interval), float(p.wave_radius),
					float(p.wave_speed), float(p.wave_width), float(p.telegraph), float(p.bullet_dmg),
					a + state.rng.randf_range(-1.0, 1.0), float(p.gap_width), float(p.gap_step) * (1.0 if t.id[i] % 2 == 1 else -1.0),
					t.color[i])
			else:
				projectiles.fire_wave(t.pos[i], a, float(p.wave_arc), float(p.wave_radius), float(p.wave_speed),
					float(p.wave_width), float(p.telegraph), float(p.bullet_dmg), 0.0, 0.0, t.color[i])
		return
	t.timer[i] -= dt
	if t.timer[i] <= 0.0:
		t.mode[i] = EnemyTable.Mode.MOVE
		t.fire_t[i] = float(p.fire_interval)
