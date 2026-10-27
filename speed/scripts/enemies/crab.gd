## かに座：自機へ横腹を向けて横歩きで寄り、届いたら進む方向をハサミで薙ぐ。前後には動かない。
extends EnemyBehavior

func _init() -> void:
	# 攻撃枠を待つ間も、共通の追跡へ戻さず横歩きを続ける。
	admission = false

func on_spawn(i: int, opts: Dictionary) -> void:
	table.buds[i] = 1
	if not opts.has("facing"):
		_steer(i)

## buds は進む向き（体の右が1、左が-1）。薙ぎもこの向きへ出す。
func step(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] != EnemyTable.Mode.MOVE:
		_lab_admit(i, dt)
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_steer(i)
			if _sweep_reaches(i) and t.pos[i].distance_squared_to(state.ship_pos) <= pow(float(p.approach), 2):
				# approach まで近づき、薙ぎも届くなら止まり、攻撃枠が取れたらすぐに構える。
				t.vel[i] = Vector2.ZERO
				if _lab_admit(i, dt):
					_begin_windup(i)
			else:
				t.vel[i] = walk_direction(i) * t.speed[i]
				if projectiles.director != null:
					projectiles.director.cancel_wait(_lab_owner(i), t.id[i])
		EnemyTable.Mode.WINDUP:
			t.vel[i] = Vector2.ZERO
			t.timer[i] = maxf(0.0, t.timer[i] - dt)
			t.charge[i] = clampf(1.0 - t.timer[i] / maxf(0.01, float(p.telegraph)), 0.0, 1.0)
			if t.timer[i] <= 0.0:
				var h := projectiles.fire_zone(sweep_center(i), sweep_radius(i), 0.0, float(p.bullet_dmg),
					ProjectileSystem.HazardStyle.PLAIN, t.color[i].lightened(0.3))
				projectiles.attach_hazard(h, i)
				t.links[i] = PackedInt32Array([h])
				_recover(i)
		EnemyTable.Mode.RECOVER:
			t.vel[i] = Vector2.ZERO
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				_clear_hazards(i)
				t.mode[i] = EnemyTable.Mode.MOVE

## 進む向きから turn_angle 度以上自機がずれたら、その場で横腹を自機へ向け直す。回る量が少ない側を選ぶ。
func _steer(i: int) -> void:
	var t := table
	var to := state.ship_pos - t.pos[i]
	if to.length_squared() < 1.0:
		return
	if absf(walk_direction(i).angle_to(to)) < deg_to_rad(float(t.def[i].params.turn_angle)):
		return
	var right := to.angle() - PI / 2.0
	var left := to.angle() + PI / 2.0
	if absf(Geom.angle_diff(right, t.facing[i])) <= absf(Geom.angle_diff(left, t.facing[i])):
		t.facing[i] = right
		t.buds[i] = 1
	else:
		t.facing[i] = left
		t.buds[i] = -1

## 横歩きの向き。体の向きに直交する。
func walk_direction(i: int) -> Vector2:
	return Vector2.from_angle(table.facing[i] + PI / 2.0) * (-1.0 if table.buds[i] < 0 else 1.0)

func _begin_windup(i: int) -> void:
	table.mode[i] = EnemyTable.Mode.WINDUP
	table.timer[i] = maxf(0.01, float(table.def[i].params.telegraph))
	table.charge[i] = 0.0
	table.vel[i] = Vector2.ZERO

func _recover(i: int) -> void:
	table.mode[i] = EnemyTable.Mode.RECOVER
	table.timer[i] = maxf(0.01, float(table.def[i].params.open_time))
	table.vel[i] = Vector2.ZERO
	table.charge[i] = 0.0

func sweep_center(i: int) -> Vector2:
	return table.pos[i] + walk_direction(i) * (table.r[i] + float(table.def[i].params.reach) * 0.5)

func sweep_radius(i: int) -> float:
	return float(table.def[i].params.reach) * 0.6

func _sweep_reaches(i: int) -> bool:
	return sweep_center(i).distance_squared_to(state.ship_pos) <= pow(sweep_radius(i), 2)

func admit_due(_i: int, _dt: float) -> bool:
	return true

func admit_duration(i: int) -> float:
	var p: Dictionary = table.def[i].params
	return float(p.telegraph) + float(p.open_time) + 0.1

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
