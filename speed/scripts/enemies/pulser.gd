## 波動の敵：止まって光を輪へ集め、完成した輪を発射する。
extends EnemyBehavior

func _init() -> void:
	# 予兆と発射の端数時間を、弾と同じ更新間隔で扱う。
	full_rate = true

## 完成輪は元のスプライトの縁のすぐ外側。接触判定の倍率から独立させる。
static func ring_radius(t: EnemyTable, i: int) -> float:
	return minf(float(t.def[i].params.wave_radius), t.r[i] / t.def[i].visual_value("collision_scale", 1.0) * 1.12)

func wait_for_attack(i: int, dt: float) -> void:
	_keep_distance(i, dt)

func step(i: int, dt: float) -> void:
	if table.mode[i] == EnemyTable.Mode.MOVE:
		_keep_distance(i, dt)
	else:
		_hold(i, dt)
	_pulser(i, dt)

func _pulser(i: int, dt: float) -> void:
	var t: EnemyTable = table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		t.fire_t[i] -= dt
		if t.fire_t[i] <= 0.0:
			t.facing[i] = (state.enemy_aim - t.pos[i]).angle()
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.telegraph)
		return
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		return
	t.timer[i] -= dt
	if t.timer[i] <= 0.0:
		# 予兆中は敵のtimerだけを持つ。死亡・除去した敵の遅延攻撃を弾側へ残さない。
		if t.dead[i] != 0 or t.held[i] != 0 or t.pump_owner[i] >= 0:
			return
		var h: int = projectiles.fire_wave(t.pos[i], t.facing[i], float(p.wave_arc), float(p.wave_radius),
			float(p.wave_speed), float(p.wave_width), 0.0, float(p.bullet_dmg), 0.0, 0.0,
			Color("#ff0c24"), ring_radius(t, i))
		projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.PULSER
		# 同じ更新の味方弾で倒れた場合も、実際に飛び始める直前に取り消す。
		projectiles.attach_hazard(h, i)
		# このあと弾もdtだけ進む。溜めが完了してからの端数だけ波を進める。
		projectiles.hazard_t[h] = -dt - t.timer[i]
		t.mode[i] = EnemyTable.Mode.MOVE
		t.fire_t[i] = float(p.fire_interval)
