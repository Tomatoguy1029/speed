## ケフェウス座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_cepheus(i, dt)

## 王が倒れた：召喚と兵の攻撃が止まり、残った兵は撃ち合って崩れる。
func on_death(i: int, _atk: float) -> void:
	var t := table
	var soldiers = m.behavior(&"soldier")
	if soldiers == null:
		return
	for j in soldiers.rows():
		if t.dead[j] == 0 and t.target[j] == i and t.target_id[j] == t.id[i] and t.mode[j] != EnemyTable.Mode.RECOVER:
			soldiers._start_mutiny(j, float(t.def[i].params.mutiny_time) + state.rng.randf() * 0.6)

## ケフェウス座の隊列の兵の数（段階ごと）。3体は横一列、5体は扇形、7体は千鳥の二重隊列（前列4体・後列3体）
const CEPHEUS_TIERS := [3, 5, 7]
## 兵の射撃予告が画面内で見える時間。
const VOLLEY_WARNING := 0.4

## ケフェウス座：距離を保ち、専用の兵を召喚して隊列を組ませる王（buds が今の段階 1〜3。0 は召喚前）。
## reinforce_interval ごとに増援して段階を上げ（3→5→7体）、そのときだけ隊列を組み直す（WINDUP：射撃を休み、新しい兵の出現位置を
## 予告してから召喚し、全員が配置に着くと射撃を再開する）。組み直したあとは、兵の位置と撃つ向きを固定する。
## 倒された兵の穴は、次の増援まで残す。射撃は王が号令する（MOVE：fire_interval ごとに一斉射撃。7体は前列と後列が交互に撃つ）。
func _cepheus(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	# 機体から keep の距離を保つ。向き（facing）は隊列の向きなので、動いても変えない
	var away := (t.pos[i] - _aim).normalized()
	_steer_to(i, _aim + away * float(p.keep), t.speed[i], t.accel[i], dt)
	if t.buds[i] == 0:
		_cepheus_reform(i)
		return
	t.fire_t[i] -= dt
	match t.mode[i]:
		EnemyTable.Mode.WINDUP:
			t.timer[i] -= dt
			t.charge[i] = 1.0 - clampf(t.timer[i] / float(p.summon_time), 0.0, 1.0)
			if t.timer[i] > 0.0:
				return
			var size: int = CEPHEUS_TIERS[t.buds[i] - 1]
			if t.timer[i] > -dt * 1.5:
				# 予告した位置に兵を召喚する
				var taken := {}
				for j in _soldiers_of(i):
					taken[t.buds[j]] = true
				for k in size:
					if not taken.has(k):
						var j := spawn(def_of(&"cepheus_soldier"), cepheus_slot(i, k)[0], {"facing": cepheus_slot(i, k)[1], "attack_group": t.attack_group[i], "attack_value": t.attack_value[i], "attack_priority": t.attack_priority[i]})
						t.target[j] = i
						t.target_id[j] = t.id[i]
						t.buds[j] = k
						t.mode[j] = EnemyTable.Mode.MOVE
				state.emit(&"cepheus_summon", {"pos": t.pos[i], "color": t.color[i]})
			for j in _soldiers_of(i):
				if t.mode[j] != EnemyTable.Mode.MOVE:
					return
			# 全員が配置に着いた：射撃を再開する
			t.mode[i] = EnemyTable.Mode.MOVE
			t.charge[i] = 0.0
			t.timer[i] = float(p.fire_interval)
			t.fire_t[i] = float(p.reinforce_interval)
		_:
			t.timer[i] -= dt
			_cepheus_warn_volley(i, dt)
			if t.timer[i] <= 0.0:
				_cepheus_volley(i)
				t.timer[i] = float(p.fire_interval) * (0.5 if t.buds[i] == 3 else 1.0)
				for j in _soldiers_of(i):
					t.charge[j] = 0.0
			if t.fire_t[i] <= 0.0:
				_cepheus_reform(i)

## ケフェウス座（行 i）の兵の行の一覧（倒れた兵は含めない）。
func _soldiers_of(i: int) -> PackedInt32Array:
	var t := table
	var out := PackedInt32Array()
	for j in m.behavior(&"soldier").rows() if m.behavior(&"soldier") != null else PackedInt32Array():
		if t.dead[j] == 0 and t.target[j] == i and t.target_id[j] == t.id[i] and t.mode[j] != EnemyTable.Mode.RECOVER:
			out.append(j)
	return out

## 増援：段階を1つ上げ（7体で止まる）、隊列の基準と向きを今の機体の方へ決め直す。残っている兵は新しい位置へ動き、
## 足りない位置は出現位置を予告してから召喚する。
func _cepheus_reform(i: int) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.buds[i] = mini(t.buds[i] + 1, CEPHEUS_TIERS.size())
	t.anchor[i] = t.pos[i]
	t.facing[i] = (state.ship_pos - t.pos[i]).angle()
	var size: int = CEPHEUS_TIERS[t.buds[i] - 1]
	var soldiers := _soldiers_of(i)
	var k := 0
	for j in soldiers:
		if k >= size:
			break
		t.buds[j] = k
		t.mode[j] = EnemyTable.Mode.DASH
		t.charge[j] = 0.0
		k += 1
	for n in range(k, size):
		state.emit(&"summon_mark", {"pos": cepheus_slot(i, n)[0], "king": t.pos[i], "life": float(p.summon_time), "color": t.color[i]})
	t.mode[i] = EnemyTable.Mode.WINDUP
	t.timer[i] = float(p.summon_time)
	t.bud_t[i] = 0.0

## ケフェウス座（行 i）の隊列の k 番目の位置と、そこで撃つ向き。[位置, 向き]
func cepheus_slot(i: int, k: int) -> Array:
	var t := table
	var p: Dictionary = t.def[i].params
	var a := t.facing[i]
	var u := Vector2.from_angle(a)
	var n := Vector2(-u.y, u.x)
	var base := t.anchor[i]
	var spacing := float(p.spacing)
	match CEPHEUS_TIERS[maxi(t.buds[i], 1) - 1]:
		3:
			return [base + u * float(p.row_near) + n * float(k - 1) * spacing, a]
		5:
			var ang := a + float(k - 2) * float(p.fan_step)
			return [base + Vector2.from_angle(ang) * float(p.fan_radius), ang]
		_:
			if k < 4:
				return [base + u * float(p.row_far) + n * (float(k) - 1.5) * spacing, a]
			return [base + u * float(p.row_near) + n * float(k - 5) * spacing, a]

## 画面内で予告を続けた兵だけ、次の号令に備える。カメラ移動・ズームも現在の表示矩形に従う。
func _cepheus_warn_volley(i: int, dt: float) -> void:
	var t := table
	var view := state.view_rect()
	var back := int(t.bud_t[i]) % 2 == 1
	for j in _soldiers_of(i):
		if t.mode[j] != EnemyTable.Mode.MOVE or not view.has_point(t.pos[j]) or t.timer[i] > VOLLEY_WARNING \
				or (t.buds[i] == 3 and (t.buds[j] >= 4) != back):
			t.charge[j] = 0.0
			continue
		# 遠距離LODのまとめ更新でも、1回の処理で予告なしに満了させない。
		t.charge[j] = minf(1.0, t.charge[j] + minf(dt, 0.05) / VOLLEY_WARNING)

## 王の号令で予告済みの兵が撃つ。7体の隊列は前列（0〜3番）と後列（4〜6番）が交互に撃つ（bud_t が号令の回数）。
func _cepheus_volley(i: int) -> void:
	var t := table
	var view := state.view_rect()
	var staggered := t.buds[i] == 3
	var back := int(t.bud_t[i]) % 2 == 1
	t.bud_t[i] += 1.0
	for j in _soldiers_of(i):
		if t.mode[j] != EnemyTable.Mode.MOVE or t.charge[j] < 1.0 or not view.has_point(t.pos[j]):
			continue
		if staggered and (t.buds[j] >= 4) != back:
			continue
		var sp: Dictionary = t.def[j].params
		projectiles.fire_bolt(t.pos[j] + Vector2.from_angle(t.facing[j]) * t.r[j], t.facing[j], float(sp.bolt_speed),
			float(sp.bullet_dmg))
