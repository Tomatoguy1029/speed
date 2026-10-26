## 高速回遊から急停止して光り、その瞬間の機体の位置へ直線突進する。
extends EnemyBehavior

func _init() -> void:
	full_rate = true
	admission = false

func on_spawn(i: int, opts: Dictionary) -> void:
	if not opts.has("facing") and table.vel[i].length_squared() > 0.001:
		table.facing[i] = table.vel[i].angle()

func step(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] != EnemyTable.Mode.MOVE:
		_lab_admit(i, dt)
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			t.fire_t[i] = maxf(float(p.telegraph), t.fire_t[i] - dt)
			if t.fire_t[i] <= float(p.telegraph) and _lab_admit(i, dt):
				# 停止した瞬間の現在位置を固定する。共通の遅延照準と移動予測は使わない。
				t.anchor[i] = state.ship_pos
				t.facing[i] = (t.anchor[i] - t.pos[i]).angle()
				t.vel[i] = Vector2.ZERO
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = maxf(0.0, t.fire_t[i])
				t.charge[i] = 0.01
			else:
				_cruise(i, dt)
		EnemyTable.Mode.WINDUP:
			t.vel[i] = Vector2.ZERO
			t.timer[i] -= dt
			t.charge[i] = clampf(1.0 - t.timer[i] / maxf(float(p.telegraph), 0.001), 0.01, 1.0)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = float(p.dash_time)
				t.fire_t[i] = float(p.fire_interval)
				t.charge[i] = 0.0
		EnemyTable.Mode.DASH:
			if t.timer[i] <= 0.0:
				t.vel[i] = Vector2.ZERO
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.recover)
		_:
			_hold(i, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.vel[i] = Vector2.ZERO
				t.mode[i] = EnemyTable.Mode.MOVE

## 回遊は目標点へ鼻先を旋回してから前進する。速度だけを横へ補間しない。
func _cruise(i: int, dt: float) -> void:
	var t := table
	var to_ship := t.pos[i] - state.enemy_aim
	var outward := to_ship.normalized() if to_ship.length_squared() > 0.001 else Vector2.RIGHT
	var side := 1.0 if t.id[i] % 2 == 1 else -1.0
	var target := state.enemy_aim + outward * float(t.def[i].params.keep) + outward.orthogonal() * 200.0 * side
	var course := target - t.pos[i]
	if course.length_squared() > 0.001:
		_turn_toward(i, course.angle(), t.turn[i], dt)
	var speed := move_toward(t.vel[i].length(), t.speed[i], t.speed[i] * t.accel[i] * dt)
	t.vel[i] = Vector2.from_angle(t.facing[i]) * speed

## 天体に接したときの共通衝突処理が速度を接線へ変えた後も、鼻先を進行方向へ揃える。
func after_tick(_dt: float) -> void:
	var t := table
	for i in rows():
		if t.dead[i] == 0 and t.mode[i] == EnemyTable.Mode.MOVE and t.shove_time[i] <= 0.0 and t.knock_t[i] <= 0.0 and t.vel[i].length_squared() > 0.001:
			t.facing[i] = t.vel[i].angle()

## 通常の移動・地形衝突の前に、実際に進む区間を掃引する。
func before_move(i: int, dt: float) -> void:
	var t := table
	if t.mode[i] != EnemyTable.Mode.DASH or dt <= 0.0:
		return
	var p: Dictionary = t.def[i].params
	var travel := minf(dt, maxf(0.0, t.timer[i]))
	if travel <= 0.0:
		t.vel[i] = Vector2.ZERO
		return
	var from := t.pos[i]
	var dir := Vector2.from_angle(t.facing[i])
	var to := from + dir * float(p.dash_speed) * travel
	# 惑星・月・固定外周は共通の地形判定を使い、衝突より先まで破壊しない。
	var terrain_hit = field.first_body_hit(from, to, t.r[i])
	if terrain_hit != null:
		to = from.lerp(to, float(terrain_hit.t))
	# 敵更新の後に再構築される戦闘格子は使わず、現在の表の位置を調べる。
	# 撃破は共通入口に集め、同じ対象の再命中や複数のカジキでも報酬を重ねない。
	for j in t.alive.size():
		if j == i or not t.alive[j] or t.dead[j] or t.is_boss[j] or t.guard[j] > 0.0:
			continue
		var parent := t.parent[j]
		if m.is_same(parent, t.parent_id[j]) and t.is_boss[parent]:
			continue
		var hit := Geom.seg_circle_t(from, to, t.pos[j], t.r[i] + t.r[j])
		if hit < 0.0: continue
		var impact := from.lerp(to, hit)
		if m.gate_check(j, impact, dir, &"marlin", t.hp[j]) == EnemyTable.GateResult.ALLOW:
			projectiles.combat.kill_enemy(j, {"cause": &"marlin", "dir": dir})
		if t.dead[i] or state.phase != RunState.Phase.PLAY: return
	t.vel[i] = (to - from) / dt
	t.timer[i] = maxf(0.0, t.timer[i] - dt)
