## うみへび座（仕様書 12.3）。本体と、段階が進むほど増える首（3〜9本）と、真ん中の不死の首。
## 設計書 6.1 の3層で作る。
##   形態：LimboHSM。首全滅 → 不死首への突進で 3 → 5 → 7 → 9 本へ進む。
##   判断：形態の BTState が持つ Behavior Tree（強めの技を出せるなら、使える技のタイムラインを再生する）
##   攻撃：強めの技は AnimationPlayer のタイムライン（north・east・south・west）。普段の首の攻撃は首ごとの動き
##
## 本体と首はすり抜け、頭だけを攻撃できる。本体の HP バーは残りの段階を示す。
## 頭は敵の表の1行（部位。種類ごとの敵の定義 hydra_<首の種類>）で、位置はこの役者が決める。
## 首の節は FABRIK で本体と頭をつなぎ、この役者が描く。
extends BossActor

const NECK_CHAIN := preload("res://scripts/bosses/hydra_neck.gd")

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
	## 首の骨組みの点列（付け根から頭まで）
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
## 強めの技の方位（羅針盤の針が止まる向き。画面の上が北）
const TECH_DIR := {&"north": -PI / 2.0, &"east": 0.0, &"south": PI / 2.0, &"west": PI}

@onready var hsm: LimboHSM = $LimboHSM
@onready var timeline: AnimationPlayer = $Timeline
@onready var decision: BTState = $LimboHSM/Form1

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
## 世界秒で進む攻めどきと、技別の再使用可能時刻。
var recovery_t := 0.0
var _tech_until: Dictionary = {}
var _cooldown_scale := 1.0
var last_tech: StringName = &""
var last_tech_result: StringName = &""

func _on_bound() -> void:
	# 手動の固定更新中に技の処理を確定し、描画フレームへ持ち越さない。
	timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	draws_self = true
	table.gate[body] = EnemyTable.Gate.GHOST
	# 本体と首は、敵（頭）の下、地形の上に描く（RenderManager の描画の層の enemies の下）
	z_index = 5
	_set_count(3)
	_tech_cd = float(def.params.tech_cd) * 0.6
	hsm.initialize(self)
	hsm.set_active(true)
	queue_redraw()

func _process(_delta: float) -> void:
	if manager == null or not manager.has_boss():
		return
	# 実験場で停止中に本体を移動・拡縮した場合も表示を更新する。
	if position != table.pos[body]:
		position = table.pos[body]
		queue_redraw()
	if get_meta(&"draw_radius", -1.0) != table.r[body]:
		queue_redraw()

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0:
		return
	_time += dt
	_move(dt)
	recovery_t = maxf(0.0, recovery_t - dt)
	for k in necks.size():
		_tick_neck(necks[k], k, dt)
	_tick_immortal(dt)
	_tech_cd -= dt
	_spin_t -= dt
	_update_blackboard()
	hsm.update(dt)
	if manager.projectiles.director != null:
		manager.projectiles.lab_context = manager.projectiles.director.token("boss:" + str(table.id[body]))
	if timeline.is_playing():
		timeline.advance(dt)
		if tech != &"" and not _tech_ok(tech):
			# 先に片方の首を落とされた：技が崩れる
			interrupt_tech()
		elif tech == &"east":
			_shatter_on_beams()
	if table.hp[body] <= 0.0 and not run_state.boss_dead:
		manager.on_boss_defeated(body, {"cause": &"ram"})
	queue_redraw()

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
			neck.cd = float(def.params.attack_cd) * (0.5 + 0.5 * run_state.rng.randf())
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
	neck.segs.clear()
	_follow_neck(neck, 0.0)

func _head_pos(neck: Neck) -> Vector2:
	return table.pos[body] + Vector2.from_angle(neck.angle) * (table.r[body] + neck.length)

func _alive(neck: Neck) -> bool:
	return neck.row >= 0 and manager.enemies.is_same(neck.row, neck.row_id) and table.dead[neck.row] == 0

## 頭の行が再利用される前に、火で落ちたかと本体へのダメージを確定する。
func on_part_defeated(row: int) -> void:
	queue_redraw()
	for neck in necks:
		if neck.row == row and neck.row_id == table.id[row]:
			_on_head_lost(neck)
			return
	if immortal_row == row and immortal_id == table.id[row]:
		_tick_immortal(0.0)

## 首1本の更新。露出中は生え直しを止める。
func _tick_neck(neck: Neck, k: int, dt: float) -> void:
	var p: Dictionary = def.params
	if neck.row >= 0 and not _alive(neck):
		_on_head_lost(neck)
	if neck.row < 0:
		if not neck.burned and exposed_t <= 0.0:
			neck.regrow -= dt
			if neck.regrow <= 0.0:
				_grow(neck)
		neck.length = maxf(0.0, neck.length - float(p.neck_rest) * dt)
	else:
		neck.head_hp = table.hp[neck.row]
		_attack(neck, k, dt)
		table.pos[neck.row] = _head_pos(neck)
		table.facing[neck.row] = neck.angle
	if neck.row >= 0 or neck.length > 0.0:
		_follow_neck(neck, dt)

## 頭が落ちた：首の残骸を破片にして飛ばし、生え直す時間を決める。
## 1本の線でまとめて落とした本数が多いほど、生え直しが少しだけ遅くなる。火で落ちた頭は次の段階まで生え直さない。
func _on_head_lost(neck: Neck) -> void:
	var p: Dictionary = def.params
	var head := neck.row
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

## 頭の位置・向きは攻撃側が決め、描画用の点列だけを解く。頭を失った首は短く畳む。
func _follow_neck(neck: Neck, dt: float) -> void:
	var rest := float(def.params.neck_rest)
	if neck.row < 0:
		rest = minf(rest, neck.length)
	NECK_CHAIN.update(neck.segs, table.pos[body], _head_pos(neck), table.r[body] + rest,
		neck.base_angle * 2.4, _time, dt, def.params)

# ── 不死の首 ──────────────────────────────────────────────────────

## 普段の頭を全部落とすと不死の首が露出し、貫くと次の段階へ進む。
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
		NECK_CHAIN.update(immortal_segs, table.pos[body], at, table.r[body] + float(p.neck_rest) * 0.8,
			1.2, _time, dt, p)
		_immortal_attack(dt)
	if lost or exposed_t <= 0.0:
		_finish_exposure(lost)

func _finish_exposure(pierced: bool) -> void:
	var row := immortal_row
	immortal_row = -1
	exposed_t = 0.0
	_expose_cd = 3.0
	if row >= 0 and manager.enemies.is_same(row, immortal_id) and table.dead[row] == 0:
		manager.enemies.mark_dead(row)
	if pierced:
		interrupt_tech()
		run_state.emit(&"boss_hit", {"pos": table.pos[body]})
		if count == 9:
			table.hp[body] = 0.0
		else:
			_set_count(count + 2)
			table.hp[body] = table.max_hp[body] * (11.0 - count) / 8.0
			table.flash[body] = 0.3
	else:
		for neck in necks:
			if not neck.burned:
				neck.regrow = minf(neck.regrow, 0.8)

func _expose() -> void:
	interrupt_tech()
	var p: Dictionary = def.params
	exposed_t = float(p.expose_time)
	var j := manager.enemies.spawn_part(body, manager.enemies.def_of(&"hydra_immortal"), table.pos[body])
	var hp := float(p.head_hp) * manager.cfg.enemy_hp_mult
	table.max_hp[j] = hp
	table.hp[j] = hp
	table.gate[j] = EnemyTable.Gate.IMMORTAL
	immortal_row = j
	immortal_id = table.id[j]
	immortal_segs.clear()
	run_state.emit(&"text", {"pos": table.pos[body] + Vector2(0, -table.r[body] - 40.0), "text": "!", "color": Color("#ffe46b"), "size": 48})

# ── 首の攻撃（各首の種類ごと） ──────────────────────────────────────

## 首の攻撃の更新。普段は機体の方へゆらゆら向き、間隔ごとに種類ごとの2つの攻撃のどちらかを出す。
## 普段の首の攻撃は予告しない（噛みつきの引き・ビームの溜めなど、首の動きと光で見せる）。
func _attack(neck: Neck, _k: int, dt: float) -> void:
	var p: Dictionary = def.params
	var owner := "neck:" + str(neck.row_id)
	if manager.projectiles.director != null:
		manager.projectiles.lab_context = manager.projectiles.director.token(owner)
	var aim := (run_state.ship_pos - table.pos[body]).angle()
	if neck.mode == &"idle":
		# 旧追尾首は弱点として残す。追尾弾は発射しない。
		if neck.kind == &"homing" or exposed_t > 0.0 or recovery_t > 0.0:
			return
		var sway := sin(_time * 0.9 + neck.base_angle * 3.0) * 0.35
		var home := neck.base_angle + table.facing[body] + sway
		neck.angle = lerp_angle(neck.angle, lerp_angle(home, aim, 0.35), minf(1.0, dt * 2.0))
		neck.length = move_toward(neck.length, float(p.neck_rest), float(p.neck_rest) * dt * 2.0)
		neck.glow = maxf(0.0, neck.glow - dt * 3.0)
		neck.cd -= dt
		if neck.cd <= 0.0 and not busy and table.pos[body].distance_to(run_state.ship_pos) < float(p.engage) * 1.3:
			var cats: Array = {&"bite": ["dash"], &"vortex": ["wave"], &"debris": ["aimed"], &"beam": ["beam"], &"homing": ["homing"]}.get(neck.kind, ["aimed"])
			if not manager.admit(owner, cats, neck.row, 5.0):
				return
			neck.cd = float(p.attack_cd) * (0.8 + 0.4 * run_state.rng.randf())
			neck.step = 0
			neck.mode = StringName(String(neck.kind) + ("_a" if run_state.rng.randf() < 0.5 else "_b"))
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
		var at := around + Vector2.from_angle(run_state.rng.randf() * TAU) * run_state.rng.randf_range(70.0, 160.0)
		var j := manager.enemies.spawn(rubble, _head_pos(neck), {"spin": run_state.rng.randf_range(-2.0, 2.0)})
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

func _update_blackboard() -> void:
	var bb := decision.get_bt_instance().get_blackboard()
	var offset := run_state.ship_pos - table.pos[body]
	bb.set_var(&"player_distance", offset.length())
	bb.set_var(&"player_angle", angle_difference(table.facing[body], offset.angle()))
	var counts: Dictionary = {}
	for neck in necks:
		if _alive(neck): counts[neck.kind] = int(counts.get(neck.kind, 0)) + 1
	bb.set_var(&"live_heads", counts)
	bb.set_var(&"neck_count", count)
	bb.set_var(&"exposed", exposed_t > 0.0)
	bb.set_var(&"recovering", recovery_t > 0.0)

## 条件評価は読み取りだけ。攻撃枠は選択後に取得する。
func attack_ready(attack: StringName) -> bool:
	return tech == attack or (TECH_DIR.has(attack) and _tech_cd <= 0.0 and not busy and not timeline.is_playing() \
		and exposed_t <= 0.0 and recovery_t <= 0.0 and _time >= float(_tech_until.get(attack, 0.0)) and _tech_ok(attack))

func try_start_tech(attack: StringName, cooldown_scale: float) -> bool:
	if busy or not attack_ready(attack):
		return false
	if not manager.admit("boss:" + str(table.id[body]), ["dash", "beam", "zone", "aimed"], body, 12.0):
		return false
	tech = attack
	_cooldown_scale = cooldown_scale
	last_tech_result = &""
	busy = true
	for neck in necks:
		_release_attack(neck)
		_end(neck)
	timeline.play(tech)
	timeline.advance(0.0)
	return true

func attack_playing() -> bool:
	return busy

## BT の中断と部位喪失で共通の後片付けを行う。
func interrupt_tech(attack: StringName = &"") -> void:
	if attack != &"" and tech != &"" and tech != attack:
		return
	if manager.projectiles.director != null:
		manager.projectiles.director.cancel_attack("boss:" + str(table.id[body]), table.id[body])
	if not busy:
		return
	timeline.stop()
	last_tech_result = &"interrupted"
	tech_end()

## 技に必要な首：北は噛みつく首、東は瓦礫の首とビームの首、南は渦の首と瓦礫の首、西はビームの首2本。
func _tech_ok(name: StringName) -> bool:
	match name:
		&"north":
			return _count(&"bite") >= 1
		&"east":
			return _count(&"debris") >= 1 and _count(&"beam") >= 1
		&"south":
			return false # 渦の壁と隙間の回避難度を決めてから接続する。
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
	if not busy:
		return
	last_tech = tech
	if last_tech_result == &"":
		last_tech_result = &"finished"
	_tech_until[tech] = _time + float(def.params.tech_cd) * _cooldown_scale
	recovery_t = float(def.params.tech_recovery)
	for neck in necks:
		if String(neck.mode).begins_with("tech_"):
			_release_attack(neck)
			_end(neck)
	busy = false
	tech = &""
	_tech_cd = 0.0
	for r in _rubble:
		if manager.enemies.is_same(r.x, r.y) and table.dead[r.x] == 0:
			manager.enemies.mark_dead(r.x)
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

## 北の伸びきった首を止め、攻めどきを見せる。
func north_follow() -> void:
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
		var at := table.pos[body] + Vector2.from_angle(TAU * k / 10.0 + run_state.rng.randf() * 0.3) * run_state.rng.randf_range(300.0, 480.0)
		var j := manager.enemies.spawn(rubble, _head_pos(neck), {"spin": run_state.rng.randf_range(-2.0, 2.0)})
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
	var base := from.angle() if from != Vector2.ZERO else run_state.rng.randf() * TAU
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
		var j := manager.enemies.spawn(rubble, _head_pos(neck), {"spin": run_state.rng.randf_range(-3.0, 3.0)})
		var to := _vortex_at + Vector2.from_angle(run_state.rng.randf() * TAU) * 120.0
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
	draw_on(self)
	if manager != null and manager.has_boss():
		# 描画キャッシュはメタデータに置き、実験場の戦闘状態の比較から分ける。
		set_meta(&"draw_radius", table.r[body])

## 実験キャンバスも同じ本体・首・羅針盤を描く。
func draw_on(c: CanvasItem) -> void:
	if manager == null or not manager.has_boss():
		return
	var t := table
	var r := t.r[body]
	for neck in necks:
		if neck.row >= 0 or neck.length > 0.0:
			_draw_neck(c, neck.segs, r, Color("#8f8170"), neck.glow if neck.row >= 0 else 0.0)
	if exposed_t > 0.0:
		_draw_neck(c, immortal_segs, r, Color("#c9a64a"), 0.6 + 0.4 * sin(_time * 10.0))
	c.draw_circle(Vector2.ZERO, r, Color("#5b4f45") if t.flash[body] <= 0.0 else Color("#fff4e0"))
	c.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color("#2e2722"), 4.0)
	_draw_compass(c, r * 0.75)

func _draw_neck(c: CanvasItem, segs: PackedVector2Array, body_r: float, col: Color, glow: float) -> void:
	var origin := table.pos[body]
	var point_count := segs.size()
	var dark := col.darkened(0.15)
	var previous := Vector2.ZERO
	for s in point_count:
		var at := segs[s] - origin
		var size := body_r * (0.32 - 0.14 * float(s) / point_count)
		if s > 0:
			c.draw_line(previous, at, col, size * 2.0)
		c.draw_circle(at, size, col if s % 2 == 0 else dark)
		previous = at
	if glow > 0.0 and not segs.is_empty():
		c.draw_circle(previous, body_r * 0.5, Color(1.0, 0.85, 0.5, 0.45 * glow))

## 本体に埋め込まれた羅針盤。強めの技の前だけ針が回る（強めの技で使う）。
func _draw_compass(c: CanvasItem, R: float) -> void:
	c.draw_circle(Vector2.ZERO, R, Color("#e8dcc0"))
	c.draw_arc(Vector2.ZERO, R, 0, TAU, 48, Color("#3a2f25"), 3.0)
	var font := ThemeDB.fallback_font
	var marks := ["N", "E", "S", "W"]
	for k in 4:
		var u := Vector2.from_angle(-PI / 2.0 + k * PI / 2.0)
		c.draw_string(font, u * R * 0.72 + Vector2(-9, 9), marks[k], HORIZONTAL_ALIGNMENT_CENTER, 18, 22, Color("#3a2f25"))
	var needle := Vector2.from_angle(compass_angle()) * R * 0.6
	c.draw_line(-needle * 0.4, needle, Color("#b8322a"), 5.0)
	c.draw_circle(Vector2.ZERO, 5.0, Color("#3a2f25"))

## 羅針盤の針の向き。強めの技の前だけくるくる回り、技の方位を指して止まる。普段は北を指す。
func compass_angle() -> float:
	if _spin_t > 0.0:
		return _time * 14.0
	return _needle if tech != &"" else -PI / 2.0
