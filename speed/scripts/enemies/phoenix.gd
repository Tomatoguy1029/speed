## ほうおう座：離脱し、着地点を予告して飛び込み、炎を弾けさせて停止する。
extends EnemyBehavior

func _init() -> void:
	# 枠を待つ間も位置を保つ。離脱中の画面外への移動は、この行動が管理する。
	admission = false
	recycles_far = false

func step(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.vel[i] = Vector2.ZERO
	if t.mode[i] != EnemyTable.Mode.RECOVER and not _lab_admit(i, dt):
		return
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			if t.timer[i] <= 0.0:
				var away := (t.pos[i] - state.enemy_aim).normalized()
				if away == Vector2.ZERO:
					away = Vector2.from_angle(t.facing[i])
				t.anchor[i] = t.pos[i] + away * float(p.retreat_distance)
				t.timer[i] = maxf(0.01, float(p.retreat_time))
			_advance_to(i, t.anchor[i], dt)
			if t.timer[i] <= 0.0:
				# ここから着地まで同じ位置を見せる。先読み・追尾は行わない。
				t.anchor[i] = state.enemy_aim
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = maxf(0.01, float(p.telegraph))
				t.facing[i] = (t.anchor[i] - t.pos[i]).angle()
		EnemyTable.Mode.WINDUP:
			t.timer[i] = maxf(0.0, t.timer[i] - dt)
			t.charge[i] = 1.0 - t.timer[i] / maxf(0.01, float(p.telegraph))
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = maxf(0.01, float(p.dive_time))
				t.charge[i] = 0.0
		EnemyTable.Mode.DASH:
			_advance_to(i, t.anchor[i], dt)
			if t.timer[i] <= 0.0:
				var flame := projectiles.fire_zone(t.anchor[i], impact_radius(i), 0.0, float(p.impact_dmg),
					ProjectileSystem.HazardStyle.PHOENIX, t.color[i])
				# ZONEの命中は発動の1回だけ。炎の余韻を見せる時間を別に取る。
				projectiles.hazard_active[flame] = maxf(0.05, float(p.impact_time))
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = maxf(0.01, float(p.recover_time))
		EnemyTable.Mode.RECOVER:
			t.timer[i] = maxf(0.0, t.timer[i] - dt)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE

## 自前で位置を進め、画面外のまとめ更新でも移動量と段階の時間をそろえる。
func _advance_to(i: int, target: Vector2, dt: float) -> void:
	var t := table
	var delta := target - t.pos[i]
	if not delta.is_zero_approx():
		t.facing[i] = delta.angle()
	t.pos[i] = t.pos[i].lerp(target, clampf(dt / maxf(0.001, t.timer[i]), 0.0, 1.0))
	t.timer[i] = maxf(0.0, t.timer[i] - dt)

func impact_radius(i: int) -> float:
	return maxf(table.r[i] * 1.1, float(table.def[i].params.impact_radius))

func admit_active(i: int, director, owner: String) -> bool:
	# 石化・吹き飛ばしなどで期限が過ぎた場合は、再び枠を取ってから続ける。
	return director.token(owner) > 0 and (table.mode[i] != EnemyTable.Mode.MOVE or table.timer[i] > 0.0)

func admit_due(_i: int, _dt: float) -> bool:
	return true

func admit_duration(i: int) -> float:
	var p: Dictionary = table.def[i].params
	return maxf(0.01, float(p.retreat_time)) + maxf(0.01, float(p.telegraph)) \
		+ maxf(0.01, float(p.dive_time)) + maxf(0.05, float(p.impact_time)) + 0.1

func on_death(i: int, _atk: float) -> void:
	_cancel(i)

func on_release(i: int) -> void:
	_cancel(i)

func clear() -> void:
	for i in rows():
		_cancel(i)

func _cancel(i: int) -> void:
	table.charge[i] = 0.0
	if projectiles.director != null:
		projectiles.director.cancel_attack(_lab_owner(i), table.id[i])
