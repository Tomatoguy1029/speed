## うみへび座（仕様書 12.3）。本体と、体力が減るほど増える首（3〜9本）と、真ん中の不死の首。
## 設計書 6.1 の3層で作る。
##   形態：LimboHSM（形態1つ。首の本数は体力で増える）
##   判断：形態の BTState が持つ Behavior Tree（強めの技を出せるなら、使える技のタイムラインを再生する）
##   攻撃：強めの技は AnimationPlayer のタイムライン（north・east・south・west）。普段の首の攻撃は首ごとの動き
##
## 本体と首は、体当たりも武器もすり抜ける。ダメージが通るのは頭だけで、頭に与えたダメージの一部が本体の体力を削る。
## 頭は敵の表の1行（部位。種類ごとの敵の定義 hydra_<首の種類>）で、位置はこの役者が決める。
## 首の節（瓦礫の塊）は頭を追いかけて動き、この役者が描く。
extends BossActor

## 首1本の状態
class Neck:
	## 首の種類（bite・vortex・debris・beam・homing）
	var kind: StringName
	## 本体から見た付け根の向きと、今の首の向き・長さ
	var base_angle := 0.0
	var angle := 0.0
	var length := 0.0
	## 頭の行と id（落ちていれば -1）、前の更新の頭の HP
	var row := -1
	var row_id := 0
	var head_hp := 0.0
	## 生え直すまでの時間。burned なら次の段階まで生え直さない（火で落ちた頭）
	var regrow := 0.0
	var burned := false
	## 首の節の位置（頭を追う）
	var segs := PackedVector2Array()
	## 攻撃の段階と残り時間、次の攻撃までの時間、続けた回数、予告の光（0〜1）
	var mode: StringName = &"idle"
	var t := 0.0
	var cd := 0.0
	var step := 0
	var glow := 0.0
	## 付いて動く攻撃の形（ビーム）の行と、強めの技で首を振る速さ
	var hazard := -1
	var sweep := 0.0

## 首の本数ごとの首の種類（並びは付け根の向きの順）
const NECKS := {
	3: [&"bite", &"vortex", &"debris"],
	5: [&"bite", &"vortex", &"debris", &"beam", &"bite"],
	7: [&"bite", &"vortex", &"debris", &"beam", &"bite", &"homing", &"beam"],
	9: [&"bite", &"vortex", &"debris", &"beam", &"bite", &"homing", &"beam", &"vortex", &"debris"],
}
const SEGS := 9
## 強めの技の方位（羅針盤の針が止まる向き。画面の上が北）
const TECH_DIR := {&"north": -PI / 2.0, &"east": 0.0, &"south": PI / 2.0, &"west": PI}

@onready var hsm: LimboHSM = $LimboHSM
@onready var timeline: AnimationPlayer = $Timeline

var necks: Array[Neck] = []
## 今の段階の首の本数
var count := 0
## 不死の首：むき出しの残り時間と、頭の行と id
var exposed_t := 0.0
var immortal_row := -1
var immortal_id := 0
var immortal_segs := PackedVector2Array()
## むき出しが終わってから、次にむき出しになれるまでの時間
var _expose_cd := 0.0
## 1本の線（突進の番号）ごとに落とした頭の数
var _dash_kills: Dictionary = {}
var _shock_t := 0.0
## 強めの技の最中（普段の首の攻撃を止める）
var busy := false
## 今の強めの技（空なら無し）、次に出せるまでの時間、羅針盤の針が回っている残り時間と止まる向き
var tech: StringName = &""
var _tech_cd := 0.0
var _spin_t := 0.0
var _needle := -PI / 2.0
## 強めの技で吐いた瓦礫（行と id）と、南の技の渦の位置
var _rubble: Array[Vector2i] = []
var _vortex_at := Vector2.ZERO
var _time := 0.0

func _on_bound() -> void:
	draws_self = true
	table.gate[body] = EnemyTable.Gate.GHOST
	# 本体と首は、敵（頭）の下、地形の上に描く（RenderManager の描画の層の enemies の下）
	z_index = 5
	_set_count(3)
	_tech_cd = float(def.params.tech_cd) * 0.6
	hsm.initialize(self)
	hsm.set_active(true)

func _process(_delta: float) -> void:
	if manager != null and manager.has_boss():
		position = table.pos[body]
	queue_redraw()

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0:
		return
	_time += dt
	_move(dt)
	var frac := table.hp[body] / maxf(table.max_hp[body], 1.0)
	var want := 3 if frac > 0.75 else (5 if frac > 0.5 else (7 if frac > 0.25 else 9))
	if want > count:
		_set_count(want)
	for k in necks.size():
		_tick_neck(necks[k], k, dt)
	_tick_immortal(dt)
	_tech_cd -= dt
	_spin_t -= dt
	hsm.update(dt)
	if timeline.is_playing():
		timeline.advance(dt)
		if tech != &"" and not _tech_ok(tech):
			# 先に片方の首を落とされた：技が崩れる
			timeline.stop()
			tech_end()
		elif tech == &"east":
			_shatter_on_beams()
	if table.hp[body] <= 0.0 and not run_state.boss_dead:
		manager.on_boss_defeated(body, {"cause": &"ram"})

## 本体：基本はその場で構える。機体が一定より離れると、機体の方へ泳いで近づく。
func _move(dt: float) -> void:
	var t := table
	var i := body
	var p: Dictionary = def.params
	var d := run_state.ship_pos - t.pos[i]
	var dist := maxf(d.length(), 1.0)
	var want := d / dist * def.speed if dist > float(p.engage) else Vector2.ZERO
	t.vel[i] += (want - t.vel[i]) * minf(1.0, def.accel * dt)
	t.facing[i] += clampf(Geom.angle_diff(d.angle(), t.facing[i]), -def.turn * dt, def.turn * dt)
	var from := t.pos[i]
	t.pos[i] += t.vel[i] * dt
	manager.field.collide_enemy(i, from)
	if t.flash[i] > 0.0:
		t.flash[i] -= dt

## 首の本数を n にする（段階が変わった）。火で落ちた頭も含めて、全部の首が生え直す。
func _set_count(n: int) -> void:
	count = n
	var kinds: Array = NECKS[n]
	for k in kinds.size():
		var neck: Neck
		if k < necks.size():
			neck = necks[k]
		else:
			neck = Neck.new()
			neck.kind = kinds[k]
			neck.cd = float(def.params.attack_cd) * (0.5 + 0.5 * randf())
			necks.append(neck)
		neck.base_angle = TAU * k / float(n)
		neck.burned = false
		if neck.row < 0:
			neck.regrow = 0.0
			_grow(neck)

## 首の頭を生やす。
func _grow(neck: Neck) -> void:
	var p: Dictionary = def.params
	neck.length = float(p.neck_rest) * 0.3
	neck.angle = neck.base_angle + table.facing[body]
	var head_def := manager.enemies.def_of(StringName("hydra_" + String(neck.kind)))
	var j := manager.enemies.spawn_part(body, head_def, _head_pos(neck))
	var hp := float(p.head_hp) * manager.cfg.enemy_hp_mult
	table.max_hp[j] = hp
	table.hp[j] = hp
	neck.row = j
	neck.row_id = table.id[j]
	neck.head_hp = hp
	neck.mode = &"idle"
	neck.glow = 0.0
	if neck.segs.is_empty():
		neck.segs.resize(SEGS)
		for s in SEGS:
			neck.segs[s] = table.pos[body]

func _head_pos(neck: Neck) -> Vector2:
	return table.pos[body] + Vector2.from_angle(neck.angle) * (table.r[body] + neck.length)

func _alive(neck: Neck) -> bool:
	return neck.row >= 0 and manager.enemies.is_same(neck.row, neck.row_id) and table.dead[neck.row] == 0

## 頭の行が再利用される前に、火で落ちたかと本体へのダメージを確定する。
func on_part_defeated(row: int) -> void:
	for neck in necks:
		if neck.row == row and neck.row_id == table.id[row]:
			_on_head_lost(neck)
			return
	if immortal_row == row and immortal_id == table.id[row]:
		_tick_immortal(0.0)

## 首1本の更新：頭へのダメージを本体へ移し、頭が落ちたら生え直しを待つ。頭の位置を決め、節が追う。
func _tick_neck(neck: Neck, k: int, dt: float) -> void:
	var p: Dictionary = def.params
	if neck.row >= 0 and not _alive(neck):
		_on_head_lost(neck)
	if neck.row < 0:
		if not neck.burned:
			neck.regrow -= dt
			if neck.regrow <= 0.0:
				_grow(neck)
		neck.length = maxf(0.0, neck.length - float(p.neck_rest) * dt)
	else:
		var hp := table.hp[neck.row]
		if hp < neck.head_hp:
			table.hp[body] -= (neck.head_hp - hp) * float(p.head_share)
			table.flash[body] = 0.08
		neck.head_hp = hp
		_attack(neck, k, dt)
		table.pos[neck.row] = _head_pos(neck)
		table.facing[neck.row] = neck.angle
	_follow(neck.segs, table.pos[body], _head_pos(neck), dt)

## 頭が落ちた：残りの HP ぶんを本体へ移し、首の残骸を破片にして飛ばす。生え直しの時間を決める。
## 1本の線でまとめて落とした本数が多いほど、生え直しが少しだけ遅くなる。火で落ちた頭は次の段階まで生え直さない。
func _on_head_lost(neck: Neck) -> void:
	var p: Dictionary = def.params
	var head := neck.row
	table.hp[body] -= maxf(0.0, neck.head_hp) * float(p.head_share)
	neck.burned = run_state.world_time - table.fire_hit[head] < 0.5
	var n := 1
	if run_state.tracing:
		n = int(_dash_kills.get(run_state.dash_id, 0)) + 1
		_dash_kills[run_state.dash_id] = n
	neck.regrow = float(p.regrow) * (1.0 + float(p.regrow_combo) * (n - 1))
	manager.projectiles.burst_debris(table.pos[head], 8, 700.0, float(p.debris_dmg) * manager.cfg.atk_scale,
		Color("#a89a86"), table.id[head])
	_release_attack(neck)
	neck.row = -1
	neck.mode = &"idle"

## 節を、付け根から頭までの曲線に向かって遅れて動かす。
func _follow(segs: PackedVector2Array, base: Vector2, head: Vector2, dt: float) -> void:
	var side := (head - base).orthogonal().normalized() * sin(_time * 1.3 + base.x * 0.01) * 30.0
	var k := minf(1.0, dt * 14.0)
	for s in segs.size():
		var f := float(s + 1) / float(segs.size())
		var target := base.lerp(head, f) + side * sin(f * PI)
		segs[s] = segs[s].lerp(target, k)

# ── 不死の首 ──────────────────────────────────────────────────────

## 普段の頭が全部落ちると、真ん中の不死の首がむき出しになる。むき出しの間に頭を貫くと本体に大きなダメージ。
func _tick_immortal(dt: float) -> void:
	var p: Dictionary = def.params
	if exposed_t <= 0.0:
		_expose_cd -= dt
		if _expose_cd > 0.0:
			return
		for neck in necks:
			if neck.row >= 0:
				return
		_expose()
		return
	exposed_t -= dt
	var lost := not (manager.enemies.is_same(immortal_row, immortal_id) and table.dead[immortal_row] == 0)
	if not lost:
		var a := (run_state.ship_pos - table.pos[body]).angle()
		var at := table.pos[body] + Vector2.from_angle(a) * (table.r[body] + float(p.neck_rest) * 0.8)
		table.pos[immortal_row] = at
		_follow(immortal_segs, table.pos[body], at, dt)
		_immortal_attack(dt)
	if lost or exposed_t <= 0.0:
		if lost:
			table.hp[body] -= table.max_hp[body] * float(p.immortal_dmg)
			table.flash[body] = 0.3
			run_state.emit(&"boss_hit", {"pos": table.pos[body]})
		else:
			manager.enemies.mark_dead(immortal_row)
		exposed_t = 0.0
		_expose_cd = 3.0
		immortal_row = -1
		# 焼いた首は段階が変わるまで戻らない。焼いていない首だけ生え直す。
		for neck in necks:
			if not neck.burned:
				neck.regrow = minf(neck.regrow, 0.8)

func _expose() -> void:
	var p: Dictionary = def.params
	exposed_t = float(p.expose_time)
	var j := manager.enemies.spawn_part(body, manager.enemies.def_of(&"hydra_immortal"), table.pos[body])
	var hp := float(p.head_hp) * manager.cfg.enemy_hp_mult
	table.max_hp[j] = hp
	table.hp[j] = hp
	table.gate[j] = EnemyTable.Gate.IMMORTAL
	immortal_row = j
	immortal_id = table.id[j]
	immortal_segs.resize(SEGS)
	for s in SEGS:
		immortal_segs[s] = table.pos[body]
	run_state.emit(&"text", {"pos": table.pos[body] + Vector2(0, -table.r[body] - 40.0), "text": "!", "color": Color("#ffe46b"), "size": 48})

# ── 首の攻撃（各首の種類ごと） ──────────────────────────────────────

## 首の攻撃の更新。普段は機体の方へゆらゆら向き、間隔ごとに種類ごとの2つの攻撃のどちらかを出す。
## 普段の首の攻撃は予告しない（噛みつきの引き・ビームの溜めなど、首の動きと光で見せる）。
func _attack(neck: Neck, _k: int, dt: float) -> void:
	var p: Dictionary = def.params
	var aim := (run_state.ship_pos - table.pos[body]).angle()
	if neck.mode == &"idle":
		var sway := sin(_time * 0.9 + neck.base_angle * 3.0) * 0.35
		var home := neck.base_angle + table.facing[body] + sway
		neck.angle = lerp_angle(neck.angle, lerp_angle(home, aim, 0.35), minf(1.0, dt * 2.0))
		neck.length = move_toward(neck.length, float(p.neck_rest), float(p.neck_rest) * dt * 2.0)
		neck.glow = maxf(0.0, neck.glow - dt * 3.0)
		neck.cd -= dt
		if neck.cd <= 0.0 and not busy and table.pos[body].distance_to(run_state.ship_pos) < float(p.engage) * 1.3:
			neck.cd = float(p.attack_cd) * (0.8 + 0.4 * randf())
			neck.step = 0
			neck.mode = StringName(String(neck.kind) + ("_a" if randf() < 0.5 else "_b"))
			neck.t = 0.0
		return
	neck.t += dt
	match neck.mode:
		&"tech_curl":
			neck.length = move_toward(neck.length, float(p.neck_rest) * 0.35, float(p.neck_rest) * dt * 2.0)
			neck.glow = minf(1.0, neck.glow + dt * 1.5)
		&"tech_burst":
			var reach := float(p.bite_reach)
			neck.length = move_toward(neck.length, reach, reach * dt * 6.0)
			neck.glow = 1.0
			if neck.step == 0 and neck.length >= reach - 1.0:
				neck.step = 1
				manager.projectiles.fire_zone(_head_pos(neck), float(p.bite_radius), 0.0, float(p.bite_dmg),
					ProjectileManager.HazardStyle.PLAIN, Color("#ff7a5a"))
		&"tech_charge":
			neck.length = move_toward(neck.length, float(p.neck_rest) * 1.25, float(p.neck_rest) * dt)
			neck.angle = lerp_angle(neck.angle, neck.sweep, minf(1.0, dt * 4.0))
			neck.glow = minf(1.0, neck.glow + dt)
		&"tech_beam":
			neck.angle += neck.sweep * dt
			neck.glow = 1.0
			if neck.hazard >= 0:
				manager.projectiles.move_hazard(neck.hazard, _head_pos(neck), neck.angle)
		&"tech_hold":
			pass
		&"bite_a", &"bite_b":
			_bite(neck, aim, dt)
		&"vortex_a", &"vortex_b":
			_vortex(neck, aim, dt)
		&"debris_a", &"debris_b":
			_debris(neck, aim, dt)
		&"beam_a", &"beam_b":
			_beam(neck, aim, dt)
		&"homing_a", &"homing_b":
			_homing(neck, aim, dt)
		_:
			neck.mode = &"idle"

func _end(neck: Neck) -> void:
	neck.mode = &"idle"
	neck.t = 0.0
	neck.step = 0
	neck.glow = 0.0

## 噛みつく首。a：首を後ろに引いてから、前へ大きく伸びて噛みつく。噛みついた直後は伸びきって止まる。
## b：短く3回、続けて噛みつきながら前へ出てくる。
func _bite(neck: Neck, aim: float, dt: float) -> void:
	var p: Dictionary = def.params
	var rest := float(p.neck_rest)
	var reach := float(p.bite_reach)
	var multi := neck.mode == &"bite_b"
	var pull_t := 0.3 if multi else 0.6
	var lunge_t := 0.1 if multi else 0.14
	var hold_t := 0.25 if multi else 0.9
	var phase_t := pull_t + lunge_t + hold_t
	var local := neck.t - neck.step * phase_t
	if local < pull_t:
		# 引く
		neck.angle = lerp_angle(neck.angle, aim, minf(1.0, dt * 6.0))
		neck.length = move_toward(neck.length, rest * 0.55, rest * dt * 2.5)
		neck.glow = local / pull_t
	elif local < pull_t + lunge_t:
		var target := rest + (reach - rest) * ((neck.step + 1) / 3.0 if multi else 1.0)
		neck.length = move_toward(neck.length, target, (target - rest * 0.5) * dt / lunge_t * 1.2)
		neck.glow = 1.0
		if local + dt >= pull_t + lunge_t:
			manager.projectiles.fire_zone(_head_pos(neck), float(p.bite_radius), 0.0, float(p.bite_dmg),
				ProjectileManager.HazardStyle.PLAIN, Color("#ff7a5a"))
	elif local < phase_t:
		neck.glow = 0.0
	else:
		neck.step += 1
		if not multi or neck.step >= 3:
			_end(neck)

## 渦の首。a：渦を巻く息を吐き、ボスの周りに渦を1つ置く。b：息を長く吐きながら首を振り、渦を3つ並べて置く。
func _vortex(neck: Neck, aim: float, dt: float) -> void:
	var p: Dictionary = def.params
	var multi := neck.mode == &"vortex_b"
	neck.angle = lerp_angle(neck.angle, aim + (sin(neck.t * 2.0) * 0.9 if multi else 0.0), minf(1.0, dt * 3.0))
	neck.glow = minf(1.0, neck.t / 0.5)
	var times := [0.5, 1.0, 1.5] if multi else [0.5]
	if neck.step < times.size() and neck.t >= times[neck.step]:
		neck.step += 1
		var at := _head_pos(neck) + Vector2.from_angle(neck.angle) * float(p.vortex_radius) * 0.8
		manager.field.add_well(at, float(p.vortex_life), float(p.vortex_radius), float(p.vortex_pull))
	if neck.t >= times[times.size() - 1] + 0.4:
		_end(neck)

## 瓦礫の首。a：鉄の瓦礫を吐き出し、ほかの首の周りに漂わせる（当たると弾かれる。少しすると消える）。
## b：瓦礫を固めて塊にし、投げつける。
func _debris(neck: Neck, aim: float, dt: float) -> void:
	var p: Dictionary = def.params
	neck.angle = lerp_angle(neck.angle, aim, minf(1.0, dt * 3.0))
	neck.glow = minf(1.0, neck.t / 0.6)
	if neck.t < 0.6:
		return
	if neck.mode == &"debris_a":
		spit_rubble(neck, int(p.rubble_count))
	else:
		manager.projectiles.fire_lump(neck.row, aim, float(p.lump_speed), float(p.lump_r), float(p.lump_dmg))
	_end(neck)

## 瓦礫を n 個吐き出し、ほかの首の頭の周りに漂わせる。
func spit_rubble(neck: Neck, n: int) -> void:
	var rubble := manager.enemies.def_of(&"hydra_rubble")
	var heads: Array[Vector2] = []
	for other in necks:
		if other != neck and _alive(other):
			heads.append(_head_pos(other))
	if heads.is_empty():
		heads.append(table.pos[body])
	for k in n:
		var around: Vector2 = heads[k % heads.size()]
		var at := around + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 160.0)
		var j := manager.enemies.spawn(rubble, 1.0, _head_pos(neck), {"spin": randf_range(-2.0, 2.0)})
		table.vel[j] = (at - table.pos[j]) * 1.2

## ビームの首。a：首を高く持ち上げて光を溜め、首を振りながら太いビームで本体の周りを薙ぐ。
## b：細いビームを、機体の方へ3回続けて撃つ。
func _beam(neck: Neck, aim: float, dt: float) -> void:
	var p: Dictionary = def.params
	if neck.mode == &"beam_b":
		neck.angle = lerp_angle(neck.angle, aim, minf(1.0, dt * 4.0))
		neck.glow = 0.6
		var times := [0.2, 0.8, 1.4]
		if neck.step < 3 and neck.t >= times[neck.step]:
			neck.step += 1
			var from := _head_pos(neck)
			manager.projectiles.fire_beam(from, (run_state.ship_pos - from).angle(), float(p.beam_len), 14.0, 0.45, 0.25,
				float(p.beam_dmg) * 0.7)
		if neck.t >= 2.2:
			_end(neck)
		return
	var charge := 1.0
	var sweep := 1.6
	if neck.t < charge:
		# 首を高く持ち上げて光を溜める
		neck.length = move_toward(neck.length, float(p.neck_rest) * 1.25, float(p.neck_rest) * dt)
		neck.angle = lerp_angle(neck.angle, aim - 1.1, minf(1.0, dt * 3.0))
		neck.glow = neck.t / charge
		return
	if neck.hazard < 0:
		neck.step = 0
		neck.hazard = manager.projectiles.fire_beam(_head_pos(neck), neck.angle, float(p.beam_len), 40.0, 0.0, sweep,
			float(p.beam_dmg))
		manager.projectiles.attach_hazard(neck.hazard, neck.row)
	neck.angle += 2.2 / sweep * dt
	neck.glow = 1.0
	if neck.hazard >= 0:
		manager.projectiles.move_hazard(neck.hazard, _head_pos(neck), neck.angle)
	if neck.t >= charge + sweep:
		_release_attack(neck)
		_end(neck)

## ホーミング弾の首。a：ホーミング弾を4発吐き出す。b：自分の周りに弾を輪のように浮かべ、少しして全部を外へ放つ。
func _homing(neck: Neck, aim: float, dt: float) -> void:
	var p: Dictionary = def.params
	neck.angle = lerp_angle(neck.angle, aim, minf(1.0, dt * 3.0))
	neck.glow = minf(1.0, neck.t / 0.5)
	if neck.t < 0.5:
		return
	if neck.mode == &"homing_a":
		for k in 4:
			manager.projectiles.fire_enemy(neck.row, aim + (k - 1.5) * 0.35, float(p.missile_speed), &"missile",
				{"bullet_dmg": float(p.missile_dmg), "missile_turn": 2.2})
	else:
		manager.projectiles.fire_ring_hold(neck.row, 12, 70.0, 0.9, float(p.ring_speed), float(p.missile_dmg))
	_end(neck)

## 首の攻撃の後片付け（頭が落ちたとき）。
func _release_attack(neck: Neck) -> void:
	if neck.hazard >= 0:
		manager.projectiles.release_hazard(neck.hazard)
		neck.hazard = -1
	neck.glow = 0.0

## むき出しの不死の首：周りへ短い衝撃を出して暴れる。
func _immortal_attack(dt: float) -> void:
	var p: Dictionary = def.params
	_shock_t -= dt
	if _shock_t <= 0.0:
		_shock_t = 0.9
		manager.projectiles.fire_wave(table.pos[immortal_row], 0.0, PI, float(p.shock_radius), 700.0, 24.0, 0.0,
			float(p.bite_dmg) * 0.6, 0.0, 0.0, Color("#ffd27a"))

# ── 強めの技（判断の層とタイムラインから呼ばれる） ────────────────────────

## 強めの技を出せるか（判断の層の AttackReady）。
func attack_ready(attack: StringName) -> bool:
	return attack == &"technique" and _tech_cd <= 0.0 and not timeline.is_playing() and exposed_t <= 0.0 \
		and table.pos[body].distance_to(run_state.ship_pos) < float(def.params.engage) * 1.3 and not _available().is_empty()

## 使える技から1つ選んで、そのタイムラインを再生する（判断の層の PlayAttack）。
func start_attack(_attack: StringName) -> void:
	var list := _available()
	tech = list[randi() % list.size()]
	busy = true
	for neck in necks:
		_release_attack(neck)
		_end(neck)
	timeline.play(tech)
	timeline.advance(0.0)

func attack_playing() -> bool:
	return timeline.is_playing()

## 技に必要な首がそろっている技の一覧。
func _available() -> Array[StringName]:
	var out: Array[StringName] = []
	for name: StringName in TECH_DIR:
		if _tech_ok(name):
			out.append(name)
	return out

## 技に必要な首：北は噛みつく首、東は瓦礫の首とビームの首、南は渦の首と瓦礫の首、西はビームの首2本。
func _tech_ok(name: StringName) -> bool:
	match name:
		&"north":
			return _count(&"bite") >= 1
		&"east":
			return _count(&"debris") >= 1 and _count(&"beam") >= 1
		&"south":
			return _count(&"vortex") >= 1 and _count(&"debris") >= 1
		&"west":
			return _count(&"beam") >= 2
	return false

func _count(kind: StringName) -> int:
	var n := 0
	for neck in necks:
		if neck.kind == kind and _alive(neck):
			n += 1
	return n

func _first(kind: StringName) -> Neck:
	for neck in necks:
		if neck.kind == kind and _alive(neck):
			return neck
	return null

## 羅針盤の針がくるくる回り出し、技の方位を指して止まる。
func tech_compass(name: StringName) -> void:
	_spin_t = 1.2
	_needle = TECH_DIR.get(name, -PI / 2.0)

## 技の終わり（崩れたときも）。首を普段に戻す。
func tech_end() -> void:
	for neck in necks:
		if String(neck.mode).begins_with("tech_"):
			_release_attack(neck)
			_end(neck)
	busy = false
	tech = &""
	_tech_cd = float(def.params.tech_cd)
	_rubble.clear()

## 北：全方向の噛みつき。首を全部引っ込めて体を丸め、全部の首が一斉に外へ伸びて噛みつき、伸びきって止まる。
func north_curl() -> void:
	for neck in necks:
		if _alive(neck):
			neck.mode = &"tech_curl"

func north_burst() -> void:
	for neck in necks:
		if _alive(neck):
			neck.mode = &"tech_burst"
			neck.step = 0
			neck.angle = neck.base_angle + table.facing[body]

## 北の追い撃ち：ホーミング弾の首がいれば、伸びきったところからホーミング弾を吐く。
func north_follow() -> void:
	var p: Dictionary = def.params
	for neck in necks:
		if neck.kind == &"homing" and _alive(neck):
			var aim := (run_state.ship_pos - _head_pos(neck)).angle()
			for k in 3:
				manager.projectiles.fire_enemy(neck.row, aim + (k - 1) * 0.4, float(p.missile_speed), &"missile",
					{"bullet_dmg": float(p.missile_dmg), "missile_turn": 2.2})
	for neck in necks:
		if neck.mode == &"tech_burst":
			neck.mode = &"tech_hold"

## 東：砕ける瓦礫。瓦礫の首が本体の周りに瓦礫を漂わせたあと、ビームの首が薙ぎ払う。
## ビームに当たった瓦礫は砕けて、破片（敵の弾）が四方へ飛び散る。
func east_debris() -> void:
	var neck := _first(&"debris")
	if neck == null:
		return
	var rubble := manager.enemies.def_of(&"hydra_rubble")
	for k in 10:
		var at := table.pos[body] + Vector2.from_angle(TAU * k / 10.0 + randf() * 0.3) * randf_range(300.0, 480.0)
		var j := manager.enemies.spawn(rubble, 1.0, _head_pos(neck), {"spin": randf_range(-2.0, 2.0)})
		table.vel[j] = (at - table.pos[j]) * 1.2
		_rubble.append(Vector2i(j, table.id[j]))

func east_charge() -> void:
	var aim := (run_state.ship_pos - table.pos[body]).angle()
	for neck in necks:
		if neck.kind == &"beam" and _alive(neck):
			neck.mode = &"tech_charge"
			neck.sweep = aim - 1.1

func east_sweep() -> void:
	for neck in necks:
		if neck.kind == &"beam" and _alive(neck):
			_start_sweep(neck, 2.2 / 1.8, 1.9)

## ビームに当たった瓦礫を砕く。
func _shatter_on_beams() -> void:
	var p: Dictionary = def.params
	for neck in necks:
		if neck.mode != &"tech_beam" or neck.hazard < 0:
			continue
		var a := _head_pos(neck)
		var b := a + Vector2.from_angle(neck.angle) * float(p.beam_len)
		for k in range(_rubble.size() - 1, -1, -1):
			var j := _rubble[k].x
			if not manager.enemies.is_same(j, _rubble[k].y) or table.dead[j] != 0:
				_rubble.remove_at(k)
				continue
			if Geometry2D.get_closest_point_to_segment(table.pos[j], a, b).distance_to(table.pos[j]) < table.r[j] + 20.0:
				_burst_rubble(j, (table.pos[j] - a).normalized())
				_rubble.remove_at(k)

## 瓦礫を砕き、破片を飛ばす。from が 0 でなければ、その向きを中心に飛ばす。
func _burst_rubble(j: int, from: Vector2) -> void:
	var p: Dictionary = def.params
	var base := from.angle() if from != Vector2.ZERO else randf() * TAU
	for k in 6:
		manager.projectiles.fire_enemy(j, base + (k - 2.5) * (0.45 if from != Vector2.ZERO else TAU / 6.0),
			float(p.shard_speed), &"bullet", {"bullet_dmg": float(p.shard_dmg)})
	manager.enemies.mark_dead(j)

## 南：瓦礫の渦。渦の首が機体の方に大きな渦を置いたあと、瓦礫の首が瓦礫を吐く。
## 瓦礫は渦に吸い込まれて回り、渦が消えるときに外へ飛び散る。
func south_vortex() -> void:
	var p: Dictionary = def.params
	var neck := _first(&"vortex")
	if neck == null:
		return
	var d := run_state.ship_pos - table.pos[body]
	_vortex_at = table.pos[body] + d.normalized() * minf(d.length(), 520.0)
	manager.field.add_well(_vortex_at, 3.4, float(p.vortex_radius) * 1.3, float(p.vortex_pull) * 1.3)
	neck.glow = 1.0

func south_debris() -> void:
	var neck := _first(&"debris")
	if neck == null:
		return
	var rubble := manager.enemies.def_of(&"hydra_rubble")
	for k in 8:
		var j := manager.enemies.spawn(rubble, 1.0, _head_pos(neck), {"spin": randf_range(-3.0, 3.0)})
		var to := _vortex_at + Vector2.from_angle(randf() * TAU) * 120.0
		table.vel[j] = (to - table.pos[j]) * 0.9
		_rubble.append(Vector2i(j, table.id[j]))

func south_burst() -> void:
	for r in _rubble:
		if manager.enemies.is_same(r.x, r.y) and table.dead[r.x] == 0:
			_burst_rubble(r.x, (table.pos[r.x] - _vortex_at).normalized())
	_rubble.clear()

## 西：はさみ薙ぎ。2本のビームの首が、左右から同時に薙ぎ払い、間を閉じるように振る。
func west_charge() -> void:
	var aim := (run_state.ship_pos - table.pos[body]).angle()
	var side := -1.0
	for neck in necks:
		if neck.kind == &"beam" and _alive(neck):
			neck.mode = &"tech_charge"
			neck.sweep = aim + side * 1.4
			side = -side

func west_sweep() -> void:
	var aim := (run_state.ship_pos - table.pos[body]).angle()
	for neck in necks:
		if neck.mode == &"tech_charge":
			var rate := -signf(Geom.angle_diff(neck.angle, aim)) * 1.3 / 1.6
			_start_sweep(neck, rate, 1.7)

## 首を振りながら太いビームを出す。
func _start_sweep(neck: Neck, rate: float, time: float) -> void:
	var p: Dictionary = def.params
	neck.mode = &"tech_beam"
	neck.sweep = rate
	neck.hazard = manager.projectiles.fire_beam(_head_pos(neck), neck.angle, float(p.beam_len), 40.0, 0.0, time,
		float(p.beam_dmg))
	manager.projectiles.attach_hazard(neck.hazard, neck.row)

# ── 見た目 ────────────────────────────────────────────────────────

func _draw() -> void:
	if manager == null or not manager.has_boss():
		return
	var t := table
	var r := t.r[body]
	for neck in necks:
		_draw_neck(neck.segs, r, Color("#8f8170"), neck.glow if neck.row >= 0 else 0.0)
	if exposed_t > 0.0:
		_draw_neck(immortal_segs, r, Color("#c9a64a"), 0.6 + 0.4 * sin(_time * 10.0))
	draw_circle(Vector2.ZERO, r, Color("#5b4f45") if t.flash[body] <= 0.0 else Color("#fff4e0"))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color("#2e2722"), 4.0)
	_draw_compass(r * 0.75)

func _draw_neck(segs: PackedVector2Array, body_r: float, col: Color, glow: float) -> void:
	for s in segs.size():
		var at := to_local(segs[s])
		var size := body_r * (0.32 - 0.14 * float(s) / segs.size())
		draw_circle(at, size, col.darkened(0.15 * (s % 2)))
	if glow > 0.0 and not segs.is_empty():
		draw_circle(to_local(segs[segs.size() - 1]), body_r * 0.5, Color(1.0, 0.85, 0.5, 0.45 * glow))

## 本体に埋め込まれた羅針盤。強めの技の前だけ針が回る（強めの技で使う）。
func _draw_compass(R: float) -> void:
	draw_circle(Vector2.ZERO, R, Color("#e8dcc0"))
	draw_arc(Vector2.ZERO, R, 0, TAU, 48, Color("#3a2f25"), 3.0)
	var font := ThemeDB.fallback_font
	var marks := ["N", "E", "S", "W"]
	for k in 4:
		var u := Vector2.from_angle(-PI / 2.0 + k * PI / 2.0)
		draw_string(font, u * R * 0.72 + Vector2(-9, 9), marks[k], HORIZONTAL_ALIGNMENT_CENTER, 18, 22, Color("#3a2f25"))
	var needle := Vector2.from_angle(compass_angle()) * R * 0.6
	draw_line(-needle * 0.4, needle, Color("#b8322a"), 5.0)
	draw_circle(Vector2.ZERO, 5.0, Color("#3a2f25"))

## 羅針盤の針の向き。強めの技の前だけくるくる回り、技の方位を指して止まる。普段は北を指す。
func compass_angle() -> float:
	if _spin_t > 0.0:
		return _time * 14.0
	return _needle if tech != &"" else -PI / 2.0
