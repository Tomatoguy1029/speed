## わし座：旋回する巡航と、進路を見せてから踏み切る雷撃。
extends EnemyBehavior

func _init() -> void:
	full_rate = true

func step(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			t.fire_t[i] = maxf(0.0, t.fire_t[i] - dt)
			if t.fire_t[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.aim_time) + float(p.lock_time)
				t.vel[i] = Vector2.ZERO
				return
			cruise(i, dt)
		EnemyTable.Mode.WINDUP:
			t.vel[i] = Vector2.ZERO
			var lock_time := float(p.lock_time)
			if t.timer[i] > lock_time:
				_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), 2.8, dt)
				t.charge[i] = 0.0
			t.timer[i] -= dt
			if t.timer[i] <= lock_time and t.charge[i] == 0.0:
				# この時点で進路を固定。地形に遮られる分も予告と実走行で共通にする。
				var to_ship := state.ship_pos - t.pos[i]
				t.facing[i] = to_ship.angle()
				var stop_gap := t.r[i] + cfg.ship_radius + 12.0
				var advance := minf(float(p.dash_speed) * float(p.dash_time), maxf(0.0, to_ship.length() - stop_gap))
				var end := t.pos[i] + Vector2.from_angle(t.facing[i]) * advance
				var hit = field.first_body_hit(t.pos[i], end, t.r[i])
				t.anchor[i] = t.pos[i].lerp(end, float(hit.t)) if hit != null else end
				t.charge[i] = 0.01
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = float(p.dash_time)
				t.bud_t[i] = 0.0
				t.charge[i] = 0.0
			else:
				t.charge[i] = maxf(t.charge[i], 1.0 - t.timer[i] / lock_time)
		EnemyTable.Mode.DASH:
			pass # before_move が実走行と雷の位置をまとめて決める。
		_:
			t.vel[i] = Vector2.ZERO
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE
				t.fire_t[i] = float(p.fire_interval)

## 予算待ちも同じ大きな円弧で飛び、機体への直線追跡に戻さない。
func cruise(i: int, dt: float) -> void:
	var t := table
	var radial := t.pos[i] - state.enemy_aim
	var outward := radial.normalized() if radial.length_squared() > 0.001 else Vector2.RIGHT
	var side := 1.0 if t.id[i] % 2 == 1 else -1.0
	var target := state.enemy_aim + outward * float(t.def[i].params.keep) + outward.orthogonal() * 200.0 * side
	var course := target - t.pos[i]
	if course.length_squared() > 0.001:
		_turn_toward(i, course.angle(), t.turn[i], dt)
	t.vel[i] = Vector2.from_angle(t.facing[i]) * t.speed[i]

func before_move(i: int, dt: float) -> void:
	var t := table
	if t.mode[i] != EnemyTable.Mode.DASH or dt <= 0.0:
		return
	var p: Dictionary = t.def[i].params
	var dir := Vector2.from_angle(t.facing[i])
	var remaining := maxf(0.0, (t.anchor[i] - t.pos[i]).dot(dir))
	var travel := minf(remaining, float(p.dash_speed) * minf(dt, t.timer[i]))
	t.vel[i] = dir * (travel / dt)
	var step := float(p.drop_step)
	var elapsed := travel / float(p.dash_speed)
	var next_drop := t.bud_t[i]
	while next_drop <= elapsed + 0.00001:
		projectiles.fire_zone(t.pos[i] + dir * float(p.dash_speed) * next_drop,
			float(p.blast_radius), float(p.blast_delay), float(p.bullet_dmg),
			ProjectileSystem.HazardStyle.AQUILA, Color("#e1f7ff"))
		next_drop += step
	t.bud_t[i] = next_drop - elapsed
	t.timer[i] -= dt
	if t.timer[i] <= 0.0 or remaining <= travel + 0.001:
		if step - t.bud_t[i] > step * 0.25:
			projectiles.fire_zone(t.pos[i] + dir * travel,
				float(p.blast_radius), float(p.blast_delay), float(p.bullet_dmg),
				ProjectileSystem.HazardStyle.AQUILA, Color("#e1f7ff"))
		t.mode[i] = EnemyTable.Mode.RECOVER
		t.timer[i] = float(p.recover)

func admit_duration(i: int) -> float:
	var p: Dictionary = table.def[i].params
	return float(p.aim_time) + float(p.lock_time) + float(p.dash_time) + float(p.blast_delay) + ProjectileSystem.ZONE_FLASH
