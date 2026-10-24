## ぼうえんきょう座（狙撃）。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_telescope(i, dt)

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	admission = false

func admit_due(_i: int, _dt: float) -> bool:
	return true

func admit_active(i: int, d, owner: String) -> bool:
	return (table.mode[i] == EnemyTable.Mode.WINDUP or table.mode[i] == EnemyTable.Mode.RECOVER) and d.token(owner) > 0

func admit_duration(i: int) -> float:
	var p: Dictionary = table.def[i].params
	return maxf(0.0, 1.0 - table.charge[i]) * float(p.lock_fill) + float(p.laser_charge) + float(p.laser_delay) + float(p.laser_time) + 0.1

func on_death(i: int, _atk: float) -> void:
	_tele_rays.erase(table.id[i])

func clear() -> void:
	_tele_rays.clear()
	_sight_rocks.clear()
	_sight_step = -1

## 隕石が増えたので、遮る岩の一覧を次の更新で作り直す。
func rocks_changed() -> void:
	_sight_step = -1

## ぼうえんきょう座のサーチライトの光線の数と、光線ごとの届く長さ（敵の id → 長さの並び。帯の右端から左端の順）
var _sight_rocks := PackedInt32Array()

var _sight_step := -1

const TELE_RAYS := 48

## 岩を必要とする光線と支援判定で共用する。通常敵を各個体の近傍探索へ混ぜない。
func _ensure_sight_rocks() -> void:
	if _sight_step == m._lod:
		return
	_sight_step = m._lod
	_sight_rocks.clear()
	for row in table.alive.size():
		if table.alive[row] != 0 and table.dead[row] == 0 and table.meteor_index[row] >= 0:
			_sight_rocks.append(row)

var _tele_rays: Dictionary = {}

## ぼうえんきょう座：距離を保ちながら、レンズの向き（facing）へサーチライトの帯を伸ばす。見失っている間は、機体のいる方へ
## search_turn の速さで向き直りながら、その周りを左右へ search_sway の幅で振って探す。
## 機体が光の中にいる間は機体の方へ track_turn の速さで追い、狙い（charge）が lock_fill で溜まる。帯の外では狙いが戻る。
## 光は隕石・惑星・月で遮られ、その陰では見つからない。狙いの途中でも陰に入れば、狙いはすぐ外れる。
## 帯は狙いが溜まるほど細くなる。溜まりきると laser_charge の間レーザーを溜め（WINDUP。機体を追い続け、岩陰に入られたら取り消す）、
## 溜め終わりの向きへ太いレーザーを撃つ（laser_delay ののち laser_time の間当たる。光と同じく隕石などで止まる）。
## 撃ったあと cooldown の間は休む（RECOVER）。
func _telescope(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var d := t.pos[i] - _aim
	var dist := maxf(d.length(), 1.0)
	var u := d / dist
	var side := 1.0 if t.id[i] % 2 == 1 else -1.0
	_steer_to(i, _aim + u * float(p.keep) + Vector2(-u.y, u.x) * 150.0 * side, t.speed[i], t.accel[i], dt)
	if t.mode[i] == EnemyTable.Mode.RECOVER:
		t.timer[i] -= dt
		_search_telescope(i, dt)
		_tele_rays.erase(t.id[i])
		if t.timer[i] <= 0.0:
			t.mode[i] = EnemyTable.Mode.MOVE
		return
	if not telescope_in_range(i):
		_cancel_telescope(i)
		_search_telescope(i, dt)
		return
	_cast_telescope(i, true)
	var seen := telescope_sight(i, state.ship_pos)
	if seen != 1:
		_cancel_telescope(i)
		_search_telescope(i, dt)
		return
	# 照準が見え始める前に、射程・遮蔽物と予算を確認する。
	if not _lab_admit(i, dt):
		t.mode[i] = EnemyTable.Mode.MOVE
		t.charge[i] = 0.0
		_tele_rays.erase(t.id[i])
		_search_telescope(i, dt)
		return
	_cast_telescope(i)
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), float(p.track_turn), dt)
		t.timer[i] -= dt
		if t.timer[i] <= 0.0:
			var lens := telescope_lens(i)
			var reach := telescope_reach(i, t.facing[i])
			var beam := projectiles.fire_beam(lens, t.facing[i], reach, float(p.laser_width), float(p.laser_delay), float(p.laser_time),
				float(p.bullet_dmg), Color(1.0, 0.3, 0.25))
			if beam >= 0:
				projectiles.hazard_style[beam] = ProjectileSystem.HazardStyle.TELESCOPE
			state.emit(&"telescope_fire", {"pos": lens, "angle": t.facing[i], "length": reach, "width": float(p.laser_width)})
			t.charge[i] = 0.0
			t.mode[i] = EnemyTable.Mode.RECOVER
			t.timer[i] = float(p.cooldown)
		return
	_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), float(p.track_turn), dt)
	t.charge[i] = minf(1.0, t.charge[i] + dt / float(p.lock_fill))
	if t.charge[i] >= 1.0:
		t.mode[i] = EnemyTable.Mode.WINDUP
		t.timer[i] = float(p.laser_charge)
		state.emit(&"telescope_charge", {"pos": telescope_lens(i)})

## 照準と未発射の予約を解除する。既に飛んでいる攻撃はdirector側が保持する。
func _cancel_telescope(i: int) -> void:
	if projectiles.director != null:
		projectiles.director.cancel_attack(_lab_owner(i), table.id[i])
	table.mode[i] = EnemyTable.Mode.MOVE
	table.charge[i] = 0.0
	_tele_rays.erase(table.id[i])

func telescope_in_range(i: int) -> bool:
	var distance := telescope_lens(i).distance_to(state.ship_pos)
	return distance >= 1.0 and distance <= float(table.def[i].params.band_len)

## 描画も攻撃可能な射程と、取得済みの枠に従う。
func telescope_aiming(i: int) -> bool:
	if not telescope_in_range(i) or (table.charge[i] <= 0.0 and table.mode[i] != EnemyTable.Mode.WINDUP):
		return false
	var d = projectiles.director
	return d == null or not d.enabled or d.token(_lab_owner(i)) > 0

## ぼうえんきょう座が機体を探す：機体のいる方を中心に、左右へ振りながら向きを変える。
func _search_telescope(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var sway := sin(t.age[i] * TAU / float(p.search_period) + float(t.id[i])) * float(p.search_sway)
	_turn_toward(i, (state.ship_pos - t.pos[i]).angle() + sway, float(p.search_turn), dt)

## ぼうえんきょう座の帯の左右の角度（狙いが溜まるほど細い）。
func telescope_half(i: int) -> float:
	var p: Dictionary = table.def[i].params
	return lerpf(float(p.band_width), float(p.band_narrow), table.charge[i])

## ぼうえんきょう座のサーチライトの光が出る位置（レンズ）。
func telescope_lens(i: int) -> Vector2:
	return table.pos[i] + Vector2.from_angle(table.facing[i]) * table.r[i] * 0.9

## ぼうえんきょう座（行 i）の光線を投げ、光線ごとの届く長さを隕石・惑星・月で切って覚える。
func _cast_telescope(i: int, target_only := false) -> void:
	var t := table
	var length := float(t.def[i].params.band_len)
	var lens := telescope_lens(i)
	var half := telescope_half(i)
	# 遮るもの：帯の届く範囲の隕石・鉄のがれきと、惑星・月
	var blockers := PackedVector3Array()
	_ensure_sight_rocks()
	for j in _sight_rocks:
		if t.alive[j] == 0 or t.dead[j] != 0 or t.meteor_index[j] < 0:
			continue
		var offset := t.pos[j] - lens
		var radius := t.r[j]
		if offset.length_squared() <= (length + radius) * (length + radius):
			blockers.append(Vector3(offset.x, offset.y, radius))
	for b in field.bodies:
		if b.pos.distance_to(lens) < length + b.r:
			var offset: Vector2 = b.pos - lens
			blockers.append(Vector3(offset.x, offset.y, b.r))
	# 円が光の扇と交わる可能性を先に調べる。光線数と円の交差判定は保つ。
	var forward := Vector2.from_angle(t.facing[i])
	var side_scale := cos(half)
	var along_scale := sin(half)
	var candidates := PackedVector3Array()
	for blocker in blockers:
		var offset := Vector2(blocker.x, blocker.y)
		var along := offset.dot(forward)
		if along < -blocker.z or absf(offset.cross(forward)) * side_scale - along * along_scale > blocker.z:
			continue
		candidates.append(blocker)
	var rays := PackedFloat32Array()
	rays.resize(TELE_RAYS)
	# 予約前は、機体への判定が補間する2本だけを計算する。許可後の見た目は48本を保つ。
	var first := 0
	var last := TELE_RAYS
	if target_only:
		rays.fill(length)
		var offset := Geom.angle_diff((state.ship_pos - lens).angle(), t.facing[i])
		var fraction := clampf((offset + half) / (2.0 * half), 0.0, 1.0) * (TELE_RAYS - 1)
		first = mini(int(fraction), TELE_RAYS - 2)
		last = first + 2
	for n in range(first, last):
		var v := Vector2.from_angle(t.facing[i] - half + 2.0 * half * n / float(TELE_RAYS - 1))
		var reach := length
		for blk in candidates:
			var c := Vector2(blk.x, blk.y)
			var r := blk.z
			var along := c.dot(v)
			if along < -r:
				continue
			var d2 := c.length_squared() - along * along
			if d2 > r * r:
				continue
			reach = minf(reach, maxf(0.0, along - sqrt(r * r - d2)))
		rays[n] = reach
	_tele_rays[t.id[i]] = rays

## ぼうえんきょう座（行 i）の光線ごとの届く長さ（まだ投げていなければ空）。
func telescope_rays(i: int) -> PackedFloat32Array:
	return _tele_rays.get(table.id[i], PackedFloat32Array())

## 位置 at が、ぼうえんきょう座（行 i）の光の中か：0 は帯の外、1 は光の中、2 は帯の中だが隕石などの陰。
## 描く光と同じ光線の長さで判定する。休んでいる間は見えない。
func telescope_sight(i: int, at: Vector2) -> int:
	var t := table
	if t.mode[i] == EnemyTable.Mode.RECOVER:
		return 0
	var lens := telescope_lens(i)
	var d := at - lens
	var dist := d.length()
	if dist > float(t.def[i].params.band_len) or dist < 1.0:
		return 0
	var half := telescope_half(i)
	var off := Geom.angle_diff(d.angle(), t.facing[i])
	if absf(off) > half + atan(cfg.ship_radius / dist):
		return 0
	return 1 if dist <= telescope_reach(i, d.angle()) else 2

## ぼうえんきょう座（行 i）の光が、向き angle にどこまで届くか（帯の中の光線の長さを補間する）。
func telescope_reach(i: int, angle: float) -> float:
	var rays := telescope_rays(i)
	var length := float(table.def[i].params.band_len)
	if rays.is_empty():
		return length
	var half := telescope_half(i)
	var off := Geom.angle_diff(angle, table.facing[i])
	var f := clampf((off + half) / (2.0 * half), 0.0, 1.0) * (TELE_RAYS - 1)
	var n := mini(int(f), TELE_RAYS - 2)
	return lerpf(rays[n], rays[n + 1], f - n)
