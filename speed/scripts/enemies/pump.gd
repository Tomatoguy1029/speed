## ポンプ座。
extends EnemyBehavior

## 吸い込み口の位置（胴体の中心から前へ、半径に対する割合。pump.png の口に合わせる）
const MOUTH := 0.85

func _init() -> void:
	watches_rows = true

## 所有は対象の列に持つ。飲み込み後の在庫（buds）とは独立させる。
func _pulling(i: int) -> bool:
	var t := table
	return t.dead[i] == 0 and t.beh[i] == index and t.mode[i] == EnemyTable.Mode.MOVE \
		and t.buds[i] < int(t.def[i].params.store_max) and t.stone[i] <= 0.0 \
		and t.held[i] == 0 and t.knock_t[i] <= 0.0 and t.shove_time[i] <= 0.0

func _owns(j: int) -> bool:
	var t := table
	var owner := t.pump_owner[j]
	return m.is_same(owner, t.pump_owner_id[j]) and _pulling(owner) \
		and t.pos[owner].distance_squared_to(t.pos[j]) <= pow(float(t.def[owner].params.pull_radius), 2.0)

func _release(j: int) -> void:
	table.pump_owner[j] = -1
	table.pump_owner_id[j] = -1

func on_row_gone(i: int) -> void:
	var t := table
	_release(i)
	for j in t.alive.size():
		if t.alive[j] != 0 and t.pump_owner[j] == i:
			_release(j)

func after_tick(_dt: float) -> void:
	var t := table
	for j in t.alive.size():
		if t.alive[j] != 0 and t.pump_owner[j] >= 0 and (t.dead[j] != 0 or not _owns(j)):
			_release(j)

func step(i: int, dt: float) -> void:
	_pump(i, dt)

func admit_due(i: int, _dt: float) -> bool:
	return table.buds[i] >= int(table.def[i].params.store_max)

## 撃破で、圧縮していた敵を一気に解放する。飛び散る敵と破裂は機体の側の攻撃で、蓄積が多いほど強い。
func on_death(i: int, atk: float) -> void:
	var t := table
	var dp: Dictionary = t.def[i].params
	var full := float(t.buds[i]) / float(dp.store_max)
	projectiles.burst_debris(t.pos[i], int(dp.release_base) + int(float(dp.release_per) * float(t.buds[i])),
		float(dp.release_speed), atk * float(dp.release_dmg), t.color[i].lightened(0.3), t.id[i])
	projectiles.combat.explode(t.pos[i], float(dp.release_radius) * (1.0 + full), atk * float(dp.release_dmg),
		{"cause": &"pump_burst", "no_crit": true, "color": t.color[i].lightened(0.4), "life": 0.35, "knock": 500.0 + 400.0 * full})

## ポンプ座：機体を追いながら周りの敵を吸い込んで圧縮する（buds が吸い込んだ数）。数に応じて胴体が膨らむ。
## 満タンになると吸い込みを止めて構え（WINDUP）、向きを固定して圧縮弾を一発撃つ。撃ったあとはしぼむ（RECOVER）。
func _pump(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var store_max := int(p.store_max)
	var full := float(t.buds[i]) / float(store_max)
	# 胴体は吸い込んだ数に応じて膨らみ、撃ったあとはしぼむ
	var base_r := t.def[i].radius * (1.25 if t.elite[i] != 0 else 1.0) * cfg.character_scale * t.def[i].visual_value("scale", 1.0) * t.def[i].visual_value("collision_scale", 1.0)
	t.r[i] += (base_r * (1.0 + float(p.grow) * full) - t.r[i]) * minf(1.0, 6.0 * dt)
	t.timer[i] -= dt
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_steer_to(i, state.enemy_aim, t.speed[i], t.accel[i], dt)
			_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i], dt)
			_pump_suck(i, p, dt)
			if t.buds[i] >= store_max:
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.telegraph)
		EnemyTable.Mode.WINDUP:
			_hold(i, dt)
			t.charge[i] = 1.0 - maxf(0.0, t.timer[i]) / float(p.telegraph)
			# 撃つ直前の lock_time は向きを固定する
			if t.timer[i] > float(p.lock_time):
				_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i] * 2.0, dt)
			if t.timer[i] <= 0.0:
				projectiles.fire_shell(i, t.facing[i], float(p.shell_speed), float(p.shell_r), float(p.shell_range),
					float(p.burst_radius), float(p.bullet_dmg))
				t.buds[i] = 0
				t.charge[i] = 0.0
				t.vel[i] -= Vector2.from_angle(t.facing[i]) * float(p.shell_speed) * 0.3
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.recover)
		_:
			_hold(i, dt)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE

## ポンプ座が周りの雑魚（星1・2）を吸い寄せ、口に届いた敵を一定の間隔で吸い込む。
## 吸い寄せられている敵は自分の動きをやめ（knock_t）、自転しながら口へまっすぐ進む。口に近いほど速く、速く回る。
## 吸い込んだ敵は撃破にせずに消し、自転しながら小さくなって口へ飛び込む見た目を描画へ知らせる。
func _pump_suck(i: int, p: Dictionary, dt: float) -> void:
	var t := table
	if not _pulling(i): return
	var reach := float(p.pull_radius)
	var pull := float(p.pull)
	var spin := float(p.pull_spin)
	var mouth := t.pos[i] + Vector2.from_angle(t.facing[i]) * t.r[i] * MOUTH
	var bite := t.r[i] + float(p.swallow_reach)
	t.bud_t[i] -= dt
	var rows := PackedInt32Array()
	projectiles.combat.nearby(t.pos[i], reach, rows)
	for j in rows:
		if t.buds[i] >= int(p.store_max): break
		if j == i or t.dead[j] != 0 or t.is_boss[j] != 0 or t.meteor_index[j] >= 0 or t.parent[j] >= 0 \
				or t.landmark[j] != 0:
			continue
		if t.def[j] == null or t.def[j].rank < 1 or t.def[j].rank > 2 or t.beh[j] == index:
			continue
		if t.pos[i].distance_squared_to(t.pos[j]) > reach * reach:
			continue
		if _owns(j) and (t.pump_owner[j] != i or t.pump_owner_id[j] != t.id[i]):
			continue
		t.pump_owner[j] = i
		t.pump_owner_id[j] = t.id[i]
		var d := mouth - t.pos[j]
		var dist := d.length()
		if dist < bite and t.bud_t[i] <= 0.0 and t.buds[i] < int(p.store_max):
			t.buds[i] += 1
			t.bud_t[i] = float(p.swallow_interval)
			state.emit(&"swallow", {"enemy_type": t.type[j], "pos": t.pos[j], "r": t.r[j], "facing": t.facing[j],
				"color": t.color[j], "row": i, "id": t.id[i], "spin": spin * 2.0})
			mark_dead(j)
			continue
		var near := 1.0 - clampf(dist / reach, 0.0, 1.0)
		t.knock_t[j] = maxf(t.knock_t[j], dt * 2.0)
		t.vel[j] = d / maxf(dist, 1.0) * pull * (0.3 + 0.7 * near)
		t.facing[j] += spin * (0.4 + 0.6 * near) * dt
