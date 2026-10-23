## かに座：横歩きで前を薙ぎ、届かないときは90度以内で向き直して突進する。
extends EnemyBehavior

const SWEEP := 0
const TURN := 1

func _init() -> void:
	# 攻撃枠を待つ間も、共通の追跡へ戻さず横歩きを続ける。
	admission = false

func on_spawn(i: int, opts: Dictionary) -> void:
	var t := table
	if not opts.has("facing"):
		t.facing[i] = (state.ship_pos - t.pos[i]).angle()
	t.carry[i] = 0.0
	t.target[i] = SWEEP
	t.target_id[i] = 1
	_start_walk(i)

## MOVE: timer は左右の再判断、bud_t は小走り/停止の時間、buds は進行方向（停止は0）。
## carry は横歩きで届かない時間。WINDUP: target は薙ぎ/向き直し、target_id は向き直す回数。
## 向き直しの間は spin が開始角、anchor が狙う位置。DASH の anchor は直前の位置。
func step(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] != EnemyTable.Mode.MOVE:
		_lab_admit(i, dt)
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_walk(i, dt)
			t.fire_t[i] = maxf(0.0, t.fire_t[i] - dt)
			var local := (state.ship_pos - t.pos[i]).rotated(-t.facing[i])
			var offset := t.r[i] + float(p.reach) * 0.5
			var reachable := absf(local.x - offset) <= sweep_radius(i)
			t.carry[i] = 0.0 if reachable else t.carry[i] + dt
			if t.fire_t[i] <= 0.0 and _sweep_reaches(i):
				t.target[i] = SWEEP
				if _lab_admit(i, dt):
					_begin_windup(i, float(p.telegraph))
			elif t.fire_t[i] <= 0.0 and t.carry[i] >= float(p.turn_delay):
				t.target[i] = TURN
				if _lab_admit(i, dt):
					t.anchor[i] = state.ship_pos
					t.spin[i] = t.facing[i]
					t.target_id[i] = 1 if state.rng.randf() < 0.5 else 3
					_begin_windup(i, float(p.turn_time))
			elif projectiles.director != null:
				projectiles.director.cancel_wait(_lab_owner(i), t.id[i])
		EnemyTable.Mode.WINDUP:
			t.vel[i] = Vector2.ZERO
			t.timer[i] = maxf(0.0, t.timer[i] - dt)
			var duration := float(p.turn_time) if t.target[i] == TURN else float(p.telegraph)
			t.charge[i] = clampf(1.0 - t.timer[i] / maxf(0.01, duration), 0.0, 1.0)
			if t.target[i] == TURN:
				_turn_to_target(i)
			if t.timer[i] <= 0.0:
				if t.target[i] == SWEEP:
					var h := projectiles.fire_zone(sweep_center(i), sweep_radius(i), 0.0, float(p.bullet_dmg),
						ProjectileSystem.HazardStyle.PLAIN, t.color[i].lightened(0.3))
					projectiles.attach_hazard(h, i)
					t.links[i] = PackedInt32Array([h])
					_recover(i)
				elif absf(Geom.angle_diff((t.anchor[i] - t.pos[i]).angle(), t.facing[i])) <= 0.01:
					_begin_dash(i)
				else:
					# 背後まで1回で回らない。90度で止め、次の横歩きから判断し直す。
					_recover(i)
		EnemyTable.Mode.DASH:
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				_clear_hazards(i)
				_recover(i)
		EnemyTable.Mode.RECOVER:
			t.vel[i] = Vector2.ZERO
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				_clear_hazards(i)
				t.mode[i] = EnemyTable.Mode.MOVE
				t.fire_t[i] = float(p.fire_interval)
				t.carry[i] = 0.0
				_start_walk(i)

func _walk(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.bud_t[i] -= dt
	t.timer[i] -= dt
	if t.bud_t[i] <= 0.0:
		if t.buds[i] == 0:
			_start_walk(i)
		else:
			t.buds[i] = 0
			t.bud_t[i] = state.rng.randf_range(float(p.pause_min), maxf(float(p.pause_min), float(p.pause_max)))
	elif t.buds[i] != 0 and t.timer[i] <= 0.0:
		# 進行方向を途中で見直す。ときどき短く逆へ走ってから、次の判断で戻る。
		var toward := _walk_direction(i)
		t.buds[i] = -toward if toward == t.buds[i] and state.rng.randf() < float(p.reverse_chance) else toward
		t.timer[i] = _rethink_time(p)
	var side := Vector2.from_angle(t.facing[i] + PI / 2.0)
	var gap := (state.ship_pos - t.pos[i]).dot(side)
	# 自機の横位置を越えて振動しない。前後への速度は残さない。
	var speed := minf(t.speed[i], absf(gap) / maxf(dt, 0.001))
	t.vel[i] = side * float(t.buds[i]) * (speed if absf(gap) > float(p.walk_deadzone) else 0.0)

func _start_walk(i: int) -> void:
	var p: Dictionary = table.def[i].params
	table.buds[i] = _walk_direction(i)
	table.bud_t[i] = state.rng.randf_range(float(p.walk_min), maxf(float(p.walk_min), float(p.walk_max)))
	table.timer[i] = _rethink_time(p)

func _walk_direction(i: int) -> int:
	var side := Vector2.from_angle(table.facing[i] + PI / 2.0)
	return 1 if (state.ship_pos - table.pos[i]).dot(side) >= 0.0 else -1

func _rethink_time(p: Dictionary) -> float:
	return maxf(0.01, float(p.rethink_time)) * state.rng.randf_range(0.65, 1.35)

func _begin_windup(i: int, duration: float) -> void:
	table.mode[i] = EnemyTable.Mode.WINDUP
	table.timer[i] = maxf(0.01, duration)
	table.charge[i] = 0.0
	table.vel[i] = Vector2.ZERO

func _turn_to_target(i: int) -> void:
	var t := table
	var delta := clampf(Geom.angle_diff((t.anchor[i] - t.pos[i]).angle(), t.spin[i]), -PI / 2.0, PI / 2.0)
	var steps := maxi(1, t.target_id[i])
	var progress := t.charge[i] * steps
	var segment := minf(floorf(progress), steps - 1)
	# 各段の後半は止まり、狙いを絞る間を作る。一度で回る場合も同じ補間を使う。
	var k := clampf((progress - segment) / 0.7, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	t.facing[i] = t.spin[i] + delta * (segment + k) / steps

func _begin_dash(i: int) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.mode[i] = EnemyTable.Mode.DASH
	t.timer[i] = maxf(0.01, float(p.dash_time))
	t.charge[i] = 0.0
	t.vel[i] = Vector2.from_angle(t.facing[i]) * float(p.dash_speed)
	t.anchor[i] = t.pos[i]
	var h := projectiles.fire_wall(t.pos[i], t.facing[i], 0.0, t.r[i] * 2.0, 0.0,
		t.timer[i] + 0.1, float(p.bullet_dmg), t.color[i])
	projectiles.attach_hazard(h, i)
	# 接触線そのものは見せず、本体側の突進の残像で表す。
	projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.TRAIL
	t.links[i] = PackedInt32Array([h])

## 共通の位置更新後、突進の実移動区間にだけ判定を置く。通り過ぎた線は残さない。
func after_tick(_dt: float) -> void:
	var t := table
	for i in rows():
		if t.dead[i] != 0 or t.mode[i] != EnemyTable.Mode.DASH:
			continue
		if t.stone[i] > 0.0 or t.knock_t[i] > 0.0 or t.shove_time[i] > 0.0 or t.held[i] != 0:
			_clear_hazards(i)
			_recover(i)
			continue
		var delta := t.pos[i] - t.anchor[i]
		for h in t.links[i]:
			if projectiles.owns_hazard(h, i, t.id[i]):
				projectiles.move_hazard(h, t.anchor[i], delta.angle(), delta.length())
		t.anchor[i] = t.pos[i]

func _recover(i: int) -> void:
	table.mode[i] = EnemyTable.Mode.RECOVER
	table.timer[i] = maxf(0.01, float(table.def[i].params.open_time))
	table.vel[i] = Vector2.ZERO
	table.charge[i] = 0.0

func sweep_center(i: int) -> Vector2:
	return table.pos[i] + Vector2.from_angle(table.facing[i]) * (table.r[i] + float(table.def[i].params.reach) * 0.5)

func sweep_radius(i: int) -> float:
	return float(table.def[i].params.reach) * 0.6

func _sweep_reaches(i: int) -> bool:
	return sweep_center(i).distance_squared_to(state.ship_pos) <= pow(sweep_radius(i), 2)

## 停止中の小さな傾きは表示だけに使い、横移動の軸と当たり判定の向きは変えない。
func body_tilt(i: int) -> float:
	if table.mode[i] != EnemyTable.Mode.MOVE or table.buds[i] != 0:
		return 0.0
	return clampf(Geom.angle_diff((state.ship_pos - table.pos[i]).angle(), table.facing[i]), -0.16, 0.16)

func admit_due(_i: int, _dt: float) -> bool:
	return true

func admit_duration(i: int) -> float:
	var p: Dictionary = table.def[i].params
	return (float(p.turn_time) + float(p.dash_time) if table.target[i] == TURN else float(p.telegraph)) \
		+ float(p.open_time) + 0.1

func on_death(i: int, _atk: float) -> void:
	_clear_hazards(i)
	if projectiles.director != null:
		projectiles.director.cancel_attack(_lab_owner(i), table.id[i])

func on_release(i: int) -> void:
	_clear_hazards(i)

func _clear_hazards(i: int) -> void:
	for h in table.links[i]:
		if projectiles.owns_hazard(h, i, table.id[i]):
			projectiles.release_hazard(h)
	table.links[i] = PackedInt32Array()
