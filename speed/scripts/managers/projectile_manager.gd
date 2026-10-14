## 弾と破片（設計書 4.3）。味方の弾・敵の弾・大型の敵の破片（仕様書 8・11.6）と、敵の攻撃の形（仕様書 11.7）。
##
## 物理的な弾と破片は、惑星と月で止まる。味方の波動・範囲攻撃・ビームはここでは扱わない。
## 敵の攻撃の形（ビーム・遅れて弾ける範囲など）は、予告のあとに当たり判定を持ち、地形では止まらない。
class_name ProjectileManager
extends RunSystem

var field: FieldManager
var combat: CombatManager
var ship: ShipManager
var build: BuildManager

## 味方の弾と破片。項目ごとの列で持つ。1行が1つで、行は前へ詰めない（設計書 6）。
## HULL は質量牽引砲（W21）が撃ち出す船体
enum FriendKind { SHOT, DEBRIS, HULL }
## 1 なら使用中の行
var friend_alive := PackedByteArray()
var friend_kind := PackedByteArray()
var friend_cause: Array[StringName] = []
var friend_pos := PackedVector2Array()
var friend_vel := PackedVector2Array()
var friend_r := PackedFloat32Array()
var friend_dmg := PackedFloat64Array()
var friend_life := PackedFloat32Array()
## 敵を貫くか（1 なら貫く）。貫かない場合は friend_pierce_left が、あと何体貫けるか
var friend_pierce := PackedByteArray()
var friend_pierce_left := PackedInt32Array()
## もう当てた敵（id → true）
var friend_hit: Array[Dictionary] = []
var friend_color := PackedColorArray()
var friend_no_crit := PackedByteArray()
var friend_knock := PackedFloat32Array()
## 破片：回転と、実際に通った位置の跡
var friend_angle := PackedFloat32Array()
var friend_spin := PackedFloat32Array()
var friend_trail: Array[PackedVector2Array] = []
## 撃ち出した船体の元の敵の種類（見た目に使う。船体以外は空）
var friend_type: Array[StringName] = []
var friend_slots: RowSlots
var _buf := PackedInt32Array()
var _hits: Array = []

## 敵の弾。項目ごとの列で持つ。1行が1発で、行は前へ詰めない（設計書 6）。
enum HostileKind { BULLET, MISSILE }
const HOSTILE_CAUSE: Array[StringName] = [&"bullet", &"missile"]
## 1 なら使用中の行
var hostile_alive := PackedByteArray()
var hostile_pos := PackedVector2Array()
var hostile_vel := PackedVector2Array()
var hostile_speed := PackedFloat32Array()
var hostile_r := PackedFloat32Array()
var hostile_life := PackedFloat32Array()
var hostile_dmg := PackedFloat64Array()
var hostile_slow := PackedFloat32Array()
## 誘導の曲がる速さ（ミサイル）
var hostile_turn := PackedFloat32Array()
var hostile_kind := PackedByteArray()
## 天体の表面までの余裕の下限。これが移動量より大きい間は天体の判定を省く
var hostile_gap := PackedFloat32Array()
var hostile_slots: RowSlots
var _hostile_updating := false
var _hostile_clear_pending := false

## 敵の攻撃の形。項目ごとの列で持つ。1行が1つ（設計書 6）。
##   BEAM：pos から angle の向きへ長さ len・幅 width の線。予告（delay）のあと active の間当たる
##   ZONE：pos を中心に半径 len の円。予告（delay）のあと一瞬弾ける
##   WAVE：pos から広がる輪・扇。angle の向きを中心に左右 arc の角度、速さ speed で半径 len まで広がる。
##         幅 width。gap_w が 0 より大きければ、gap の向きの左右 gap_w の角度に切れ目がある
##   WALL：pos から angle の向きへ長さ len・幅 width の残る線。予告のあと active の間、触れると被弾する
enum HazardKind { BEAM, ZONE, WAVE, WALL }
## 見た目の種類（描画が読む）
enum HazardStyle { PLAIN, RETICLE, LIGHTNING, BLAST }
const HAZARD_CAUSE: Array[StringName] = [&"beam", &"blast", &"wave", &"wall"]
## 弾けた範囲を見せる時間
const ZONE_FLASH := 0.25
var hazard_alive := PackedByteArray()
var hazard_kind := PackedByteArray()
var hazard_style := PackedByteArray()
var hazard_pos := PackedVector2Array()
var hazard_angle := PackedFloat32Array()
var hazard_len := PackedFloat32Array()
var hazard_width := PackedFloat32Array()
## 出てからの時間、予告の時間、当たる時間（世界秒）
var hazard_t := PackedFloat32Array()
var hazard_delay := PackedFloat32Array()
var hazard_active := PackedFloat32Array()
var hazard_dmg := PackedFloat64Array()
## 1 なら、もう機体に当たった（1つの攻撃は1回だけ当たる）
var hazard_hit := PackedByteArray()
var hazard_color := PackedColorArray()
## 遅れて弾ける範囲が、敵に与えるダメージ（0 なら敵には当たらない。誘爆に使う）
var hazard_edmg := PackedFloat64Array()
## 広がる波の速さ、扇の左右の角度、切れ目の向きと左右の角度
var hazard_speed := PackedFloat32Array()
var hazard_arc := PackedFloat32Array()
var hazard_gap := PackedFloat32Array()
var hazard_gap_w := PackedFloat32Array()
var hazard_slots: RowSlots

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
	friend_slots = RowSlots.new(self, "friend_")
	hostile_slots = RowSlots.new(self, "hostile_")
	# 追加の関数が、使い回す行の全部の列を書き直すか（デバッグ版だけ）
	assert(Columns.check_add(self, friend_slots.cols,
		func(): return _add_friend(FriendKind.SHOT, &"shot", Vector2.ONE, Vector2.ONE, 1.0, 1.0, 1.0, true, 1,
			Color.RED, true, 1.0, 1.0, 1.0, 5),
		friend_slots.release))
	friend_slots.clear()
	assert(Columns.check_add(self, hostile_slots.cols,
		func(): return _add_hostile(Vector2.ONE, Vector2.ONE, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, HostileKind.MISSILE),
		hostile_slots.release))
	hostile_slots.clear()
	hazard_slots = RowSlots.new(self, "hazard_")
	assert(Columns.check_add(self, hazard_slots.cols,
		func(): return _add_hazard(HazardKind.ZONE, HazardStyle.BLAST, Vector2.ONE, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, Color.RED,
			1.0, 1.0, 1.0, 1.0),
		hazard_slots.release))
	hazard_slots.clear()

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	_update_friendly(world_dt)
	if state.phase != RunState.Phase.PLAY:
		return
	_update_hostile(world_dt)
	_update_hazards(world_dt)

# ── 味方の弾と破片 ───────────────────────────────────────────────

## 味方の弾を撃つ。opts：speed、r、life、pierce_left、color、cause。
func fire_shot(from: Vector2, angle: float, dmg: float, opts := {}) -> void:
	var speed: float = opts.get("speed", 1300.0)
	_add_friend(FriendKind.SHOT, StringName(opts.get("cause", &"shot")), from, Vector2.from_angle(angle) * speed,
		opts.get("r", 5.0), dmg, opts.get("life", 0.9), false, opts.get("pierce_left", 0),
		opts.get("color", Color("#ffe46b")), false, 250.0, 0.0, 0.0, -1)

## 撃破された大型の敵（行 i）から、攻撃する破片を飛ばす（仕様書 11.6）。
func scatter_hull(i: int, dir: Vector2, speed: float, dmg: float, knock := -1.0) -> bool:
	var t := combat.enemies.table
	var r := t.r[i]
	if r < cfg.hull_debris_min_radius or t.meteor_index[i] >= 0 or t.is_boss[i] != 0 or t.hull_scattered[i] != 0:
		return false
	t.hull_scattered[i] = 1
	var pos := t.pos[i]
	var count := mini(cfg.hull_debris_max_pieces, maxi(6, ceili(r / 12.0)))
	var directed := dir.length() > 0.01
	var base := dir.angle() if directed else t.facing[i]
	var spread := deg_to_rad(cfg.hull_debris_spread) if directed else TAU
	for k in count:
		var a := base + ((float(k) / (count - 1) - 0.5) if directed else float(k) / count) * spread
		var u := Vector2.from_angle(a)
		var v := speed * (0.85 + (k % 3) * 0.12)
		_add_friend(FriendKind.DEBRIS, &"hullDebris", pos + u * r * 0.3, u * v,
			clampf(r * 0.17, 10.0, 20.0), dmg, cfg.hull_debris_life, true, 0, t.color[i], true,
			cfg.hull_debris_knock if knock < 0.0 else knock, state.rng.randf() * TAU,
			10.0 * (1.0 if k % 2 == 0 else -1.0), t.id[i])
	state.emit(&"hull_scatter", {"pos": pos, "count": count})
	return true

## 牽引した船体を撃ち出す（質量牽引砲 W21）。敵を貫き、クリティカルにならない。source_id の敵には当たらない。
func fire_hull(pos: Vector2, vel: Vector2, r: float, dmg: float, life: float, knock: float, type: StringName,
		angle: float, source_id: int) -> void:
	_add_friend(FriendKind.HULL, &"towShot", pos, vel, r, dmg, life, true, 0, Color("#ffbe65"), true, knock,
		angle, 0.0, source_id, type)

## 敵の死体（行 i）を1つ飛ばす（吹き飛ばし衝角で小型の敵を倒したとき）。
func fling_corpse(i: int, vel: Vector2, dmg: float) -> void:
	var t := combat.enemies.table
	_add_friend(FriendKind.DEBRIS, &"corpse", t.pos[i], vel, maxf(10.0, t.r[i] * 0.6), dmg, 0.9, true, 0,
		t.color[i], true, 250.0, state.rng.randf() * TAU, 10.0, t.id[i])

## 味方の弾・破片を1行加え、その行番号を返す。hit_id は最初から当てたことにする敵（-1 なら無し）。
## 空いた行を使い回すので、friend_ の全部の列をここで書き直す。
func _add_friend(kind: FriendKind, cause: StringName, pos: Vector2, vel: Vector2, r: float, dmg: float,
		life: float, pierce: bool, pierce_left: int, color: Color, no_crit: bool, knock: float,
		angle: float, spin: float, hit_id: int, type := &"") -> int:
	var i := friend_slots.take()
	friend_kind[i] = kind
	friend_cause[i] = cause
	friend_pos[i] = pos
	friend_vel[i] = vel
	friend_r[i] = r
	friend_dmg[i] = dmg
	friend_life[i] = life
	friend_pierce[i] = 1 if pierce else 0
	friend_pierce_left[i] = pierce_left
	friend_hit[i] = {hit_id: true} if hit_id != -1 else {}
	friend_color[i] = color
	friend_no_crit[i] = 1 if no_crit else 0
	friend_knock[i] = knock
	friend_angle[i] = angle
	friend_spin[i] = spin
	friend_trail[i] = PackedVector2Array()
	friend_type[i] = type
	return i

## 使用中の味方の弾・破片の数。
func friend_count() -> int:
	return friend_slots.live

func _update_friendly(dt: float) -> void:
	var trail_points := cfg.corpse_trail_points
	var et := combat.enemies.table
	var i := 0
	# 命中で増えた破片が後ろの行に入った場合は、この更新で一緒に進める
	while i < friend_alive.size():
		if friend_alive[i] == 0:
			i += 1
			continue
		var kind := friend_kind[i]
		var from := friend_pos[i]
		var vel := friend_vel[i]
		var r := friend_r[i]
		var pos := from + vel * dt
		var life := friend_life[i] - dt
		friend_angle[i] += friend_spin[i] * dt
		var trail := friend_trail[i]
		if kind == FriendKind.DEBRIS:
			trail.append(pos)
			if trail.size() > trail_points:
				trail.remove_at(0)
			friend_trail[i] = trail
		var body_hit = field.first_body_hit(from, pos, r)
		var to: Vector2 = pos if body_hit == null else body_hit.point
		var pad := Vector2(r + cfg.max_enemy_radius, r + cfg.max_enemy_radius)
		combat.grid.query(from.min(to) - pad, from.max(to) + pad, _buf)
		var hit: Dictionary = friend_hit[i]
		_hits.clear()
		for row in _buf:
			if hit.has(et.id[row]):
				continue
			var t := Geom.seg_circle_t(from, to, et.pos[row], r + et.r[row])
			if t >= 0.0:
				_hits.append([t, row])
		if _hits.size() > 1:
			_hits.sort_custom(func(a, b): return a[0] < b[0])
		var sp := vel.length()
		var pierce := friend_pierce[i] != 0
		for h in _hits:
			var row: int = h[1]
			if life <= 0.0 or et.dead[row] != 0:
				continue
			hit[et.id[row]] = true
			combat.damage_enemy(row, friend_dmg[i], {"cause": friend_cause[i], "no_crit": friend_no_crit[i] != 0,
				"dir": vel / sp if sp > 0.0 else Vector2.ZERO, "knock": friend_knock[i]})
			if state.phase != RunState.Phase.PLAY:
				# 残りの行は進めずにそのまま残す
				friend_pos[i] = pos
				friend_life[i] = life
				return
			if not pierce:
				if friend_pierce_left[i] > 0:
					friend_pierce_left[i] -= 1
				else:
					life = 0.0
		if body_hit != null:
			pos = body_hit.point
			life = 0.0
			state.emit(&"ring", {"pos": pos, "radius": 22.0, "color": Color("#ffd19a"), "life": 0.18})
		friend_pos[i] = pos
		friend_life[i] = life
		if life <= 0.0:
			if kind == FriendKind.DEBRIS and trail.size() > 1:
				state.emit(&"debris_trail", {"points": trail, "color": friend_color[i]})
			friend_slots.release(i)
		i += 1

# ── 敵の弾 ────────────────────────────────────────────────────────

## 敵（行 i）が弾を撃つ（射撃型・ミサイル艇・戦艦・ボス）。kind は &"bullet" か &"missile"。
func fire_enemy(i: int, angle: float, speed: float, kind: StringName, params := {}) -> void:
	var t := combat.enemies.table
	var p: Dictionary = params if not params.is_empty() else t.def[i].params
	var missile := kind == &"missile"
	var u := Vector2.from_angle(angle)
	var pos := t.pos[i]
	_add_hostile(pos + u * t.r[i], u * speed, speed, 9.0 if missile else 7.0, 4.5 if missile else 4.0,
		float(p.get("bullet_dmg", 7.0)) * (1.0 + 0.25 * (t.level[i] - 1.0)), p.get("slow", 0.0),
		p.get("missile_turn", 0.0), HostileKind.MISSILE if missile else HostileKind.BULLET)
	state.emit(&"shoot", {"pos": pos, "kind": kind})

## 敵の弾を1行加え、その行番号を返す。空いた行を使い回すので、hostile_ の全部の列をここで書き直す。
func _add_hostile(pos: Vector2, vel: Vector2, speed: float, r: float, life: float, dmg: float, slow: float,
		turn: float, kind: HostileKind) -> int:
	var i := hostile_slots.take()
	hostile_pos[i] = pos
	hostile_vel[i] = vel
	hostile_speed[i] = speed
	hostile_r[i] = r
	hostile_life[i] = life
	hostile_dmg[i] = dmg
	hostile_slow[i] = slow
	hostile_turn[i] = turn
	hostile_kind[i] = kind
	hostile_gap[i] = 0.0
	return i

## 使用中の敵の弾の数。
func hostile_count() -> int:
	return hostile_slots.live

func _update_hostile(dt: float) -> void:
	var R := cfg.ship_radius
	var body_move := field.body_speed_max * dt
	var ship_pos := state.ship_pos
	var aim := state.enemy_aim
	_hostile_updating = true
	var i := 0
	while i < hostile_alive.size():
		if hostile_alive[i] == 0:
			i += 1
			continue
		var life := hostile_life[i]
		if life <= 0.0:
			# バリアで消された弾
			hostile_slots.release(i)
			i += 1
			continue
		var from := hostile_pos[i]
		var vel := hostile_vel[i]
		var speed := hostile_speed[i]
		var kind := hostile_kind[i]
		if kind == HostileKind.MISSILE:
			var turn := hostile_turn[i] * dt
			var want := (aim - from).angle()
			var cur := vel.angle()
			vel = Vector2.from_angle(cur + clampf(Geom.angle_diff(want, cur), -turn, turn)) * speed
			hostile_vel[i] = vel
		var to := from + vel * dt
		life -= dt
		var r := hostile_r[i]
		# 敵の弾は等速。天体の表面までの余裕が、この更新の弾と天体の移動量より大きい間は判定を省く。
		var step := speed * dt
		var gap := hostile_gap[i] - body_move
		var body_hit = null
		if gap <= step:
			gap = field.body_gap(from, r)
			if gap <= step:
				body_hit = field.first_body_hit(from, to, r)
		# 線分上の点は終点から step 以内にあるので、終点との距離で遠くの弾を除外する。
		# 高速な弾も線分全体を確認する。
		var rr := r + R
		var reach := rr + step
		if ship_pos.distance_squared_to(to) <= reach * reach:
			var t := Geom.seg_circle_t(from, to, ship_pos, rr)
			if t >= 0.0 and (body_hit == null or t < body_hit.t):
				ship.damage(hostile_dmg[i], hostile_slow[i], HOSTILE_CAUSE[kind])
				life = 0.0
		if body_hit != null or life <= 0.0:
			hostile_slots.release(i)
		else:
			hostile_pos[i] = to
			hostile_life[i] = life
			hostile_gap[i] = gap - step
		i += 1
	_hostile_updating = false
	if _hostile_clear_pending:
		_hostile_clear_pending = false
		hostile_slots.clear()

## 機体の周り radius に入った敵の弾を1つ消す（バリアシステム）。消したら true。
func block_one(center: Vector2, radius: float) -> bool:
	for i in hostile_alive.size():
		if hostile_alive[i] != 0 and hostile_life[i] > 0.0 and hostile_pos[i].distance_to(center) <= radius + hostile_r[i]:
			hostile_life[i] = 0.0
			state.emit(&"ring", {"pos": hostile_pos[i], "radius": 32.0, "color": Color("#76aaff"), "life": 0.25})
			return true
	return false

## ボスの撃破などで、敵の弾と攻撃の形をすべて消す。
func clear_hostile() -> void:
	hazard_slots.clear()
	if _hostile_updating:
		_hostile_clear_pending = true
		return
	hostile_slots.clear()

# ── 敵の攻撃の形（仕様書 11.7） ──────────────────────────────────

## ビームを出す。from から angle の向きへ長さ length・幅 width。delay の予告のあと active の間当たる。
func fire_beam(from: Vector2, angle: float, length: float, width: float, delay: float, active: float, dmg: float,
		color := Color("#ff5a6e")) -> int:
	return _add_hazard(HazardKind.BEAM, HazardStyle.PLAIN, from, angle, length, width, delay, active, dmg, color)

## 十字のビームを出す（4方向の fire_beam）。
func fire_cross(center: Vector2, angle: float, length: float, width: float, delay: float, active: float, dmg: float,
		color := Color("#ffe0a0")) -> void:
	for k in 4:
		fire_beam(center, angle + k * PI / 2.0, length, width, delay, active, dmg, color)

## 遅れて弾ける範囲を出す。center を中心に半径 radius。delay の予告のあと一瞬弾ける。style は見た目。
## edmg が 0 より大きければ、弾けたときに範囲の敵にもダメージを与える（誘爆）。
func fire_zone(center: Vector2, radius: float, delay: float, dmg: float, style := HazardStyle.BLAST,
		color := Color("#ffb36b"), edmg := 0.0) -> int:
	var i := _add_hazard(HazardKind.ZONE, style, center, 0.0, radius, 0.0, delay, ZONE_FLASH, dmg, color)
	hazard_edmg[i] = edmg
	return i

## 広がる輪・扇を出す。arc は扇の左右の角度（PI で全周）。gap_w が 0 より大きければ、gap の向きに切れ目を空ける。
## delay の予告のあと、速さ speed で半径 radius まで広がる。
func fire_wave(center: Vector2, angle: float, arc: float, radius: float, speed: float, width: float, delay: float,
		dmg: float, gap := 0.0, gap_w := 0.0, color := Color("#9ad8ff")) -> int:
	return _add_hazard(HazardKind.WAVE, HazardStyle.PLAIN, center, angle, radius, width, delay, radius / maxf(speed, 1.0),
		dmg, color, speed, arc, gap, gap_w)

## 何層もの輪を出す。層ごとに interval ずつ遅れて広がり、切れ目の向きが gap_step ずつずれる。
func fire_rings(center: Vector2, layers: int, interval: float, radius: float, speed: float, width: float, delay: float,
		dmg: float, gap: float, gap_w: float, gap_step: float, color := Color("#9ad8ff")) -> void:
	for k in layers:
		fire_wave(center, 0.0, PI, radius, speed, width, delay + k * interval, dmg, gap + k * gap_step, gap_w, color)

## 残る線を出す。from から angle の向きへ長さ length・幅 width。delay のあと active の間、触れると被弾する。
func fire_wall(from: Vector2, angle: float, length: float, width: float, delay: float, active: float, dmg: float,
		color := Color("#ffd27a")) -> int:
	return _add_hazard(HazardKind.WALL, HazardStyle.PLAIN, from, angle, length, width, delay, active, dmg, color)

## 攻撃の形を1行加え、その行番号を返す。空いた行を使い回すので、hazard_ の全部の列をここで書き直す。
func _add_hazard(kind: HazardKind, style: HazardStyle, pos: Vector2, angle: float, length: float, width: float,
		delay: float, active: float, dmg: float, color: Color, speed := 0.0, arc := 0.0, gap := 0.0, gap_w := 0.0) -> int:
	var i := hazard_slots.take()
	hazard_kind[i] = kind
	hazard_style[i] = style
	hazard_pos[i] = pos
	hazard_angle[i] = angle
	hazard_len[i] = length
	hazard_width[i] = width
	hazard_t[i] = 0.0
	hazard_delay[i] = delay
	hazard_active[i] = active
	hazard_dmg[i] = dmg
	hazard_hit[i] = 0
	hazard_color[i] = color
	hazard_edmg[i] = 0.0
	hazard_speed[i] = speed
	hazard_arc[i] = arc
	hazard_gap[i] = gap
	hazard_gap_w[i] = gap_w
	return i

## 広がる波の、今の半径。
func wave_radius(i: int) -> float:
	return minf(hazard_len[i], maxf(0.0, hazard_t[i] - hazard_delay[i]) * hazard_speed[i])

## 使用中の攻撃の形の数。
func hazard_count() -> int:
	return hazard_slots.live

func _update_hazards(dt: float) -> void:
	var R := cfg.ship_radius
	var ship_pos := state.ship_pos
	for i in hazard_alive.size():
		if hazard_alive[i] == 0:
			continue
		var t := hazard_t[i] + dt
		hazard_t[i] = t
		var delay := hazard_delay[i]
		if t >= delay + hazard_active[i]:
			hazard_slots.release(i)
			continue
		if t < delay or hazard_hit[i] != 0:
			continue
		var kind := hazard_kind[i]
		var hit := false
		match kind:
			HazardKind.BEAM:
				var a := hazard_pos[i]
				var b := a + Vector2.from_angle(hazard_angle[i]) * hazard_len[i]
				var reach := hazard_width[i] * 0.5 + R
				hit = Geometry2D.get_closest_point_to_segment(ship_pos, a, b).distance_squared_to(ship_pos) <= reach * reach
			HazardKind.ZONE:
				# 弾けた瞬間だけ当たる（弾けたら hit を 1 にして、以後は見た目だけ）
				hazard_hit[i] = 1
				var reach := hazard_len[i] + R
				hit = hazard_pos[i].distance_squared_to(ship_pos) <= reach * reach
				if hazard_edmg[i] > 0.0:
					combat.explode(hazard_pos[i], hazard_len[i], hazard_edmg[i],
						{"cause": &"chain", "no_crit": true, "color": hazard_color[i], "life": 0.3})
					if state.phase != RunState.Phase.PLAY:
						return
			HazardKind.WAVE:
				var d := ship_pos - hazard_pos[i]
				var dist := d.length()
				var band := hazard_width[i] * 0.5 + R
				if absf(dist - wave_radius(i)) <= band:
					var a := d.angle()
					hit = absf(Geom.angle_diff(a, hazard_angle[i])) <= hazard_arc[i]
					if hit and hazard_gap_w[i] > 0.0:
						hit = absf(Geom.angle_diff(a, hazard_gap[i])) > hazard_gap_w[i]
			HazardKind.WALL:
				# 残る線は、触れている間ずっと危ない（被弾後の無敵の間は当たらない）
				var a := hazard_pos[i]
				var b := a + Vector2.from_angle(hazard_angle[i]) * hazard_len[i]
				var reach := hazard_width[i] * 0.5 + R
				if Geometry2D.get_closest_point_to_segment(ship_pos, a, b).distance_squared_to(ship_pos) <= reach * reach:
					ship.damage(hazard_dmg[i], 0.0, HAZARD_CAUSE[kind])
					if state.phase != RunState.Phase.PLAY:
						return
				continue
		if hit:
			hazard_hit[i] = 1
			ship.damage(hazard_dmg[i], 0.0, HAZARD_CAUSE[kind])
			if state.phase != RunState.Phase.PLAY:
				return
