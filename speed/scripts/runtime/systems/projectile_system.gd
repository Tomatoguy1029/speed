## 弾と破片（設計書 4.3）。味方の弾・敵の弾・大型の敵の破片（仕様書 8・11.6）と、敵の攻撃の形（仕様書 11.7）。
##
## 物理的な弾と破片は、惑星と月で止まる。味方の波動・範囲攻撃・ビームはここでは扱わない。
## 敵の攻撃の形（ビーム・遅れて弾ける範囲など）は、予告のあとに当たり判定を持ち、地形では止まらない。
class_name ProjectileSystem
extends RunSystem

func dispose() -> void:
	for attack in _attached_attacks.values():
		attack.dispose()
	_attached_attacks.clear()
	_attack_kinds.clear()
	for slots in [friend_slots, hostile_slots, hazard_slots]:
		if slots != null:
			slots.owner = null
	super()

var field: FieldSystem:
	get: return ctx.field
var combat: CombatSystem:
	get: return ctx.combat
var ship: ShipSystem:
	get: return ctx.ship
var build: LoadoutSystem:
	get: return ctx.loadout

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
## 敵に当たったときに、ダメージの代わりに呼ぶ処理（敵の行・ダメージ・当たった位置。撃った武器が決める。なければ通常のダメージ）
var friend_on_hit: Array[Callable] = []
var _friend_shapes: Dictionary = {}
var friend_slots: RowSlots
var _buf := PackedInt32Array()
var _hits: Array = []

## 敵の弾。項目ごとの列で持つ。1行が1発で、行は前へ詰めない（設計書 6）。
## SHELL はポンプ座の圧縮弾。直進し、届く距離を飛ぶか何かに当たると、その場で大きく破裂する（破裂が当たる）
## SLASH はやまねこ座の斬撃。片側1組の、潰れた弧の3本の爪痕。真ん中の少し先から外側へ横に伸び、外側で本体の方へ反り上がる。
## 形を保ったまま直進する。hostile_r が爪痕の横の大きさ、hostile_turn が伸びる側（進む向きに対して 1 なら左、-1 なら右）
## BOLT はケフェウス座の兵の細長い光弾。直進し、追尾しない
enum HostileKind { BULLET, MISSILE, REFLECTED, SHELL, SLASH, BOLT }
const HOSTILE_CAUSE: Array[StringName] = [&"bullet", &"missile", &"reflected", &"blast", &"slash", &"bolt"]
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
## 石になっている残り時間（ペルセウス座の力。石の間は止まり、触れると砕けて被弾しない）
var hostile_stone := PackedFloat32Array()
## 浮かんで待つ残り時間（その間は動かないが、触れると被弾する）
var hostile_wait := PackedFloat32Array()
## 圧縮弾が破裂する範囲の半径（圧縮弾のほかは 0）
var hostile_burst := PackedFloat32Array()
var hostile_slots: RowSlots
## 実験の攻撃グループ。行の再利用時に必ず上書きする。
var lab_context := 0
var lab_hostile_group: Dictionary = {}
var lab_hazard_group: Dictionary = {}
var director
var _hostile_updating := false
var _hostile_clear_pending := false

## 敵の攻撃の形。項目ごとの列で持つ。1行が1つ（設計書 6）。
##   BEAM：pos から angle の向きへ長さ len・幅 width の線。予告（delay）のあと active の間当たる。
##         arc が 0 より大きければ、先へ行くほど左右に arc の角度で広がる（みずがめ座の極太ビーム）
##   ZONE：pos を中心に半径 len の円。予告（delay）のあと一瞬弾ける
##   WAVE：pos から広がる輪・扇。angle の向きを中心に左右 arc の角度、速さ speed で半径 len まで広がる。
##         幅 width。gap_w が 0 より大きければ、gap の向きの左右 gap_w の角度に切れ目がある
##   WALL：pos から angle の向きへ長さ len・幅 width の残る線。予告のあと active の間、触れると被弾する
enum HazardKind { BEAM, ZONE, WAVE, WALL }
## 見た目の種類（描画が読む）
## RAY は残る線をビームとして描く（じょうぎ座）。BITE は噛みつき（噛みつく雑魚）。RIPPLE は数層の弧の波動（いるか座）。
## FLOOD は広がるビームで、予告の間も照射する範囲全体を見せる（みずがめ座）。TRAIL は付いている敵の見た目が描く
## 残る線（みなみのさんかく座の赤いレーザーの軌跡）
enum HazardStyle { PLAIN, RETICLE, LIGHTNING, BLAST, RAY, BITE, RIPPLE, FLOOD, TRAIL }
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
## 付いている敵の行と id（付いていなければ -1）。敵が倒れると、その攻撃の形も消える
var hazard_owner := PackedInt32Array()
var hazard_owner_id := PackedInt32Array()
## 遅れて弾ける範囲・広がる波が、敵に与えるダメージ（0 なら敵には当たらない。誘爆・いるか座の波動に使う）
var hazard_edmg := PackedFloat64Array()
## 1 なら、当たっている間の残る線が機体の移動を止める壁になる（じょうぎ座のビーム）
var hazard_block := PackedByteArray()
## 広がる波の速さ、扇の左右の角度（広がるビームでは広がる角度）、切れ目の向きと左右の角度
var hazard_speed := PackedFloat32Array()
var hazard_arc := PackedFloat32Array()
var hazard_gap := PackedFloat32Array()
var hazard_gap_w := PackedFloat32Array()
var hazard_slots: RowSlots
## 使った敵の弾の種類・攻撃の形の処理（種類の番号の位置。使っていない種類は null）
var _hostile_shapes: Array[HostileShape] = []
var _hazard_shapes: Array[HazardShape] = []

## 機体の移動を使う攻撃。装備管理は発動だけを行い、攻撃自身が寿命と命中を持つ。
var _attached_attacks: Dictionary = {}

## 使った攻撃の生成器だけを保持する。外から登録した種類も同じ入口で使える。
var _attack_kinds: Dictionary = {}

func register_attack(kind: StringName, attack: AttackKind) -> void:
	_attack_kinds[kind] = attack

func emit_attack(kind: StringName, args: Array) -> Variant:
	if not _attack_kinds.has(kind):
		register_attack(kind, load("res://scripts/attacks/%s.gd" % kind).new())
	return _attack_kinds[kind].emit(self, args)

func attached_attack(kind: StringName) -> RunSystem:
	if not _attached_attacks.has(kind):
		var attack: RunSystem = load("res://scripts/attacks/%s.gd" % kind).new()
		attack.setup(ctx)
		_attached_attacks[kind] = attack
	return _attached_attacks[kind]

func tick_attached(real_dt: float) -> void:
	for attack in _attached_attacks.values():
		attack.tick(real_dt, real_dt)
		if state.phase != RunState.Phase.PLAY:
			return

func trail_attached(p0: Vector2, p1: Vector2) -> void:
	for attack in _attached_attacks.values():
		attack.on_trail(p0, p1)
		if state.phase != RunState.Phase.PLAY:
			return

func setup(context: RunContext) -> void:
	super(context)
	_hostile_shapes.resize(HostileKind.size())
	_hazard_shapes.resize(HazardKind.size())
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
	combat.enemies.after_combat()
	if state.phase != RunState.Phase.PLAY:
		return
	_update_hostile(world_dt)
	_update_hazards(world_dt)

# ── 味方の弾と破片 ───────────────────────────────────────────────

## 味方の弾を撃つ。opts：speed、r、life、pierce_left、color、cause、on_hit（friend_on_hit）。
func fire_shot(from: Vector2, angle: float, dmg: float, opts := {}) -> void:
	emit_attack(&"friend_shot", [from, angle, dmg, opts])

## 位置 pos から、攻撃する破片を count 個、全方向へ飛ばす（うみへび座の首の残骸など）。source_id の敵には当たらない。
func burst_debris(pos: Vector2, count: int, speed: float, dmg: float, color: Color, source_id: int) -> void:
	emit_attack(&"burst_debris", [pos, count, speed, dmg, color, source_id])

## 撃破された大型の敵（行 i）から、攻撃する破片を飛ばす（仕様書 11.6）。
func scatter_hull(i: int, dir: Vector2, speed: float, dmg: float, knock := -1.0) -> bool:
	return emit_attack(&"scatter_hull", [i, dir, speed, dmg, knock])

## 牽引した船体を撃ち出す（質量牽引砲 W21）。敵を貫き、クリティカルにならない。source_id の敵には当たらない。
func fire_hull(pos: Vector2, vel: Vector2, r: float, dmg: float, life: float, knock: float, type: StringName,
		angle: float, source_id: int) -> void:
	emit_attack(&"friend_hull", [pos, vel, r, dmg, life, knock, type, angle, source_id])

## 体当たりされた回る丸鋸を飛ばす。敵を貫いて巻き込み、クリティカルにならない。
func fire_saw(pos: Vector2, vel: Vector2, r: float, dmg: float, life: float) -> void:
	emit_attack(&"saw", [pos, vel, r, dmg, life])

## 敵の死体（行 i）を1つ飛ばす（吹き飛ばし衝角で小型の敵を倒したとき）。
func fling_corpse(i: int, vel: Vector2, dmg: float) -> void:
	emit_attack(&"fling_corpse", [i, vel, dmg])

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
	friend_on_hit[i] = Callable()
	return i

## 使用中の味方の弾・破片の数。
func friend_count() -> int:
	return friend_slots.live

## 行の解放時に、発射元を保持する命中処理も外す。
func release_friend(i: int) -> void:
	friend_on_hit[i] = Callable()
	friend_slots.release(i)

func _friend_shape(kind: int) -> FriendShape:
	if not _friend_shapes.has(kind):
		_friend_shapes[kind] = load("res://scripts/attacks/friend_%s.gd" % String(FriendKind.keys()[kind]).to_lower()).new()
	return _friend_shapes[kind]

func _update_friendly(dt: float) -> void:
	var et := combat.enemies.table
	var i := 0
	# 命中で増えた破片が後ろの行に入った場合は、この更新で一緒に進める
	while i < friend_alive.size():
		if friend_alive[i] == 0:
			i += 1
			continue
		var shape := _friend_shape(friend_kind[i])
		var from := friend_pos[i]
		var vel := friend_vel[i]
		var r := friend_r[i]
		var pos := from + vel * dt
		var life := friend_life[i] - dt
		shape.advance(self, i, pos, dt)
		var body_hit = field.first_body_hit(from, pos, r)
		var to: Vector2 = pos if body_hit == null else body_hit.point
		var pad := Vector2(r + combat.enemy_query_padding, r + combat.enemy_query_padding)
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
			var impact := from.lerp(to, h[0])
			if shape.reflect(self, i, row, impact):
				pos = impact
				life = 0.0
				body_hit = null
				break
			hit[et.id[row]] = true
			if friend_on_hit[i].is_valid():
				friend_on_hit[i].call(row, friend_dmg[i], impact)
			else:
				combat.damage_enemy(row, friend_dmg[i], {"cause": friend_cause[i], "no_crit": friend_no_crit[i] != 0,
					"dir": vel / sp if sp > 0.0 else Vector2.ZERO, "knock": friend_knock[i], "impact": impact})
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
			shape.on_end(self, i)
			release_friend(i)
		i += 1

# ── 敵の弾 ────────────────────────────────────────────────────────

## 敵（行 i）が弾を撃つ（射撃型・ミサイル艇・戦艦・ボス）。kind は &"bullet" か &"missile"。
func fire_enemy(i: int, angle: float, speed: float, kind: StringName, params := {}) -> void:
	emit_attack(&"enemy", [i, angle, speed, kind, params])

## 敵（行 i）の周りに弾を輪のように n 発浮かべ、wait 世界秒のあと全部を外へ放つ（うみへび座のホーミング弾の首）。
func fire_ring_hold(i: int, n: int, radius: float, wait: float, speed: float, dmg: float) -> void:
	emit_attack(&"ring_hold", [i, n, radius, wait, speed, dmg])

## 塊を投げる（うみへび座の瓦礫の首）。大きさ r、ダメージ dmg。
func fire_lump(i: int, angle: float, speed: float, r: float, dmg: float) -> void:
	emit_attack(&"lump", [i, angle, speed, r, dmg])

## ポンプ座の圧縮弾を撃つ。距離 range を飛ぶか何かに当たると、半径 burst で破裂して dmg を与える。
func fire_shell(i: int, angle: float, speed: float, r: float, range: float, burst: float, dmg: float) -> void:
	emit_attack(&"shell", [i, angle, speed, r, range, burst, dmg])

## ケフェウス座の兵の細長い光弾を、from から向き angle へ撃つ。直進し、追尾しない。
func fire_bolt(from: Vector2, angle: float, speed: float, dmg: float) -> void:
	emit_attack(&"bolt", [from, angle, speed, dmg])

## やまねこ座の斬撃を飛ばす。from（真ん中の先端）から向き angle へ形を保って直進し、距離 range を飛ぶと消える。
## size は爪痕の横の大きさ、side は伸びる側（進む向きに対して 1 なら左、-1 なら右）。
func fire_slash(from: Vector2, angle: float, speed: float, size: float, range: float, dmg: float, side: float) -> void:
	emit_attack(&"slash", [from, angle, speed, size, range, dmg, side])

## 敵の弾を1行加え、その行番号を返す。空いた行を使い回すので、hostile_ の全部の列をここで書き直す。
func _add_hostile(pos: Vector2, vel: Vector2, speed: float, r: float, life: float, dmg: float, slow: float,
		turn: float, kind: HostileKind) -> int:
	var i := hostile_slots.take()
	if director != null:
		lab_hostile_group[i] = lab_context
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
	hostile_stone[i] = 0.0
	hostile_wait[i] = 0.0
	hostile_burst[i] = 0.0
	return i

## 画面の中の敵の弾を、seconds 世界秒のあいだ石にする（ペルセウス座の力）。
func stone_hostile(view: Rect2, seconds: float) -> void:
	for i in hostile_alive.size():
		if hostile_alive[i] != 0 and view.has_point(hostile_pos[i]):
			hostile_stone[i] = seconds

## 使用中の敵の弾の数。
func hostile_count() -> int:
	return hostile_slots.live

func _update_hostile(dt: float) -> void:
	var R := cfg.ship_radius
	var body_move := field.body_speed_max * dt
	var ship_pos := state.ship_pos
	var aim := state.enemy_aim
	var vc := state.view_center
	var keep := state.view_half + Vector2(400, 400)
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
		if hostile_stone[i] > 0.0:
			hostile_stone[i] -= dt
			var reach_s := hostile_r[i] + R
			if ship_pos.distance_squared_to(from) <= reach_s * reach_s:
				hostile_slots.release(i)
			i += 1
			continue
		var vel := hostile_vel[i]
		if hostile_wait[i] > 0.0:
			hostile_wait[i] -= dt
			vel = Vector2.ZERO
		var speed := hostile_speed[i]
		var shape := _hostile_shape(hostile_kind[i])
		var steered := shape.steer(self, i, vel, aim, dt)
		if steered != vel:
			vel = steered
			hostile_vel[i] = vel
		var to := from + vel * dt
		life -= dt
		# 画面の外で、画面から離れていく弾（追いかけない弾）は、もう当たらないので消す
		var rel := to - vc
		if shape.leaves_view and (absf(rel.x) > keep.x or absf(rel.y) > keep.y) and rel.dot(vel) > 0.0:
			life = 0.0
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
		var stop = shape.contact(self, i, from, to, body_hit, ship_pos, R, step)
		if stop != null:
			life = 0.0
			to = stop
		if body_hit != null or life <= 0.0:
			# 飛びきるか何かに当たった位置で消える（圧縮弾はそこで破裂する）
			shape.on_end(self, i, to if body_hit == null else from + (to - from) * float(body_hit.t), life <= 0.0)
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
func _hostile_shape(kind: int) -> HostileShape:
	if _hostile_shapes[kind] == null:
		_hostile_shapes[kind] = load("res://scripts/attacks/%s.gd" % String(HostileKind.keys()[kind]).to_lower()).new()
	return _hostile_shapes[kind]

func _hazard_shape(kind: int) -> HazardShape:
	if _hazard_shapes[kind] == null:
		_hazard_shapes[kind] = load("res://scripts/attacks/%s.gd" % String(HazardKind.keys()[kind]).to_lower()).new()
	return _hazard_shapes[kind]

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

## 範囲攻撃 i を出した敵の種類（敵に付いていて、その敵がまだいるときだけ。分からなければ空）。
func _hazard_source(i: int) -> StringName:
	var owner := hazard_owner[i]
	if owner >= 0 and combat.enemies.is_same(owner, hazard_owner_id[i]):
		return combat.enemies.table.type[owner]
	return &""

## ビームを出す。from から angle の向きへ長さ length・幅 width。delay の予告のあと active の間当たる。
func fire_beam(from: Vector2, angle: float, length: float, width: float, delay: float, active: float, dmg: float,
		color := Color("#ff5a6e")) -> int:
	return emit_attack(&"beam", [from, angle, length, width, delay, active, dmg, color])

## 先へ行くほど広がるビームを出す。from で幅 width、そこから左右に spread の角度で広がる。
## 予告（delay）の間は照射する範囲全体を見せ、そのあと active の間だけ当たる。
func fire_flood(from: Vector2, angle: float, length: float, width: float, spread: float, delay: float, active: float,
		dmg: float, color := Color("#8fd0ff")) -> int:
	return emit_attack(&"flood", [from, angle, length, width, spread, delay, active, dmg, color])

## 広がるビーム（行 h）の、根元から along の距離での幅の半分。
func flood_half(h: int, along: float) -> float:
	return hazard_width[h] * 0.5 + maxf(along, 0.0) * tan(hazard_arc[h])

## 十字のビームを出す（4方向の fire_beam）。出した4本の行番号を返す。
func fire_cross(center: Vector2, angle: float, length: float, width: float, delay: float, active: float, dmg: float,
		color := Color("#ffe0a0")) -> PackedInt32Array:
	return emit_attack(&"cross", [center, angle, length, width, delay, active, dmg, color])

## 遅れて弾ける範囲を出す。center を中心に半径 radius。delay の予告のあと一瞬弾ける。style は見た目。
## edmg が 0 より大きければ、弾けたときに範囲の敵にもダメージを与える（誘爆）。
func fire_zone(center: Vector2, radius: float, delay: float, dmg: float, style := HazardStyle.BLAST,
		color := Color("#ffb36b"), edmg := 0.0) -> int:
	return emit_attack(&"zone", [center, radius, delay, dmg, style, color, edmg])

## 広がる輪・扇を出す。arc は扇の左右の角度（PI で全周）。gap_w が 0 より大きければ、gap の向きに切れ目を空ける。
## delay の予告のあと、速さ speed で半径 radius まで広がる。
func fire_wave(center: Vector2, angle: float, arc: float, radius: float, speed: float, width: float, delay: float,
		dmg: float, gap := 0.0, gap_w := 0.0, color := Color("#9ad8ff")) -> int:
	return emit_attack(&"wave", [center, angle, arc, radius, speed, width, delay, dmg, gap, gap_w, color])

## 何層もの輪を出す。層ごとに interval ずつ遅れて広がり、切れ目の向きが gap_step ずつずれる。
func fire_rings(center: Vector2, layers: int, interval: float, radius: float, speed: float, width: float, delay: float,
		dmg: float, gap: float, gap_w: float, gap_step: float, color := Color("#9ad8ff")) -> void:
	emit_attack(&"rings", [center, layers, interval, radius, speed, width, delay, dmg, gap, gap_w, gap_step, color])

## 残る線を出す。from から angle の向きへ長さ length・幅 width。delay のあと active の間、触れると被弾する。
func fire_wall(from: Vector2, angle: float, length: float, width: float, delay: float, active: float, dmg: float,
		color := Color("#ffd27a")) -> int:
	return emit_attack(&"wall", [from, angle, length, width, delay, active, dmg, color])

## 攻撃の形（行 h）を敵（行 e）に付ける。敵が倒れると消え、位置と向きは敵が move_hazard で動かす。
func attach_hazard(h: int, e: int) -> void:
	hazard_owner[h] = e
	hazard_owner_id[h] = combat.enemies.table.id[e]

## 行 h の攻撃の形が、敵（行 e、id）に付いたまま残っているか。
func owns_hazard(h: int, e: int, id: int) -> bool:
	return h < hazard_alive.size() and hazard_alive[h] != 0 and hazard_owner[h] == e and hazard_owner_id[h] == id

## 機体（半径 radius）が from から to へ動くとき、移動を止める壁（hazard_block の残る線）に最初にぶつかる位置。
## ぶつからなければ空の辞書。ぶつかれば t（移動の割合。壁の手前で止まる位置）と normal（壁から機体の側への向き）。
func block_hit(from: Vector2, to: Vector2, radius: float) -> Dictionary:
	var best := {}
	var best_t := INF
	for h in hazard_alive.size():
		if hazard_alive[h] == 0 or hazard_block[h] == 0 or hazard_kind[h] != HazardKind.WALL:
			continue
		if hazard_t[h] < hazard_delay[h] or hazard_t[h] > hazard_delay[h] + hazard_active[h]:
			continue
		var a := hazard_pos[h]
		var u := Vector2.from_angle(hazard_angle[h])
		var m := hazard_width[h] * 0.5 + radius
		var d0 := u.cross(from - a)
		var d1 := u.cross(to - a)
		if absf(d1) >= m and signf(d0) == signf(d1):
			continue
		var t := 0.0
		if absf(d0) > m and absf(d0 - d1) > 1e-6:
			t = (d0 - signf(d0) * m) / (d0 - d1)
		var along := u.dot(from.lerp(to, t) - a)
		if along < -m or along > hazard_len[h] + m or t >= best_t:
			continue
		best_t = t
		var n := Vector2(-u.y, u.x) * (1.0 if d0 >= 0.0 else -1.0)
		best = {"t": t, "normal": n, "pos": from.lerp(to, t)}
	return best

## 付いている攻撃の形（行 h）を動かす。length が 0 以上なら長さも変える。
func move_hazard(h: int, pos: Vector2, angle: float, length := -1.0) -> void:
	hazard_pos[h] = pos
	hazard_angle[h] = angle
	if length >= 0.0:
		hazard_len[h] = length

## 攻撃の形（行 h）を消す。
func release_hazard(h: int) -> void:
	if h < hazard_alive.size() and hazard_alive[h] != 0:
		hazard_slots.release(h)

## 攻撃の形を1行加え、その行番号を返す。空いた行を使い回すので、hazard_ の全部の列をここで書き直す。
func _add_hazard(kind: HazardKind, style: HazardStyle, pos: Vector2, angle: float, length: float, width: float,
		delay: float, active: float, dmg: float, color: Color, speed := 0.0, arc := 0.0, gap := 0.0, gap_w := 0.0) -> int:
	var i := hazard_slots.take()
	if director != null:
		lab_hazard_group[i] = lab_context
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
	hazard_block[i] = 0
	hazard_owner[i] = -1
	hazard_owner_id[i] = 0
	hazard_speed[i] = speed
	hazard_arc[i] = arc
	hazard_gap[i] = gap
	hazard_gap_w[i] = gap_w
	return i

## 広がる波（行 i）の、今の半径。
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
		var owner := hazard_owner[i]
		if t >= delay + hazard_active[i] or (owner >= 0 and (not combat.enemies.is_same(owner, hazard_owner_id[i])
				or combat.enemies.table.dead[owner] != 0)):
			hazard_slots.release(i)
			continue
		var shape := _hazard_shape(hazard_kind[i])
		if t >= delay and not shape.act(self, i, dt):
			return
		if t < delay or hazard_hit[i] != 0:
			continue
		if not shape.before_touch(self, i):
			return
		if not shape.touches(self, i, ship_pos, R):
			continue
		if shape.hits_once:
			hazard_hit[i] = 1
		ship.damage(hazard_dmg[i], 0.0, HAZARD_CAUSE[hazard_kind[i]], _hazard_source(i))
		if state.phase != RunState.Phase.PLAY:
			return
