## 雑魚の表・行動・出現・補充・再配置（仕様書 11、設計書 6・6.1）。
##
## 敵はノードではなく、敵の表（EnemyTable）の1行として持つ。雑魚の行動は種類ごとの単純なステートマシン
## （例：ダーターの予告 → 突進 → 回復）。隕石とボスも同じ表に入るが、数え方と行動は別に扱う。
## 行動する雑魚は、行動の種類ごとの行番号の一覧（beh_rows）に入り、更新は種類ごとにその一覧だけを回す。
class_name EnemyManager
extends RunSystem

var field: FieldManager
var projectiles: ProjectileManager
var bosses: BossManager

const BEH := {&"chase": EnemyTable.Beh.CHASE, &"dash": EnemyTable.Beh.DASH, &"split": EnemyTable.Beh.SPLIT,
	&"gunner": EnemyTable.Beh.GUNNER, &"missile": EnemyTable.Beh.MISSILE,
	&"battleship": EnemyTable.Beh.BATTLESHIP, &"drift": EnemyTable.Beh.DRIFT}

var table := EnemyTable.new()
var slots: RowSlots
## 行動の種類ごとの行番号の一覧（ボスと隕石は入らない）
var beh_rows: Array[PackedInt32Array] = []
## 撃破済みで、その回の終わりに空きへ戻す行
var _dead_rows := PackedInt32Array()
## 分裂などで、更新の終わりに個体数の上限の範囲で出す敵：[def, level, pos, opts]
var _new: Array = []
var _next_id := 1
var _spawn_acc := 0.0
var _wave_t := 0.0
var _edge_counts := [0, 0, 0, 0]
var _phase_id: StringName = &""

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
	state.enemy_aim = state.ship_pos
	slots = RowSlots.new(table, "")
	beh_rows.resize(EnemyTable.Beh.size())
	for b in EnemyTable.Beh.size():
		beh_rows[b] = PackedInt32Array()
	# 敵を出す関数が、使い回す行の全部の列を書き直すか（デバッグ版だけ）
	assert(Columns.check_add(table, slots.cols, func(): return spawn(def_of(&"drifter"), 1.0, Vector2.ONE),
		_release_row))
	clear_all()

# ── 行の出し入れ ──────────────────────────────────────────────────

## 敵を1体出し、その行番号を返す。opts：elite、size、facing、spin、meteor_index、vel、hit_cd。
## 仕様書 11.2 の補正をかける。
func spawn(def: EnemyDef, level: float, pos: Vector2, opts := {}) -> int:
	var i := slots.take()
	_reset_row(i)
	var t := table
	t.def[i] = def
	t.type[i] = def.id
	var L := maxf(1.0, level)
	t.level[i] = L
	var elite: bool = opts.get("elite", false)
	t.elite[i] = 1 if elite else 0
	var size: float = opts.get("size", def.radius)
	var z := size / def.radius
	var r := size * (1.25 if elite else 1.0)
	# 手描き素材はエリートも同じ基準サイズで運用する。
	if def.id in RenderManager.NATIVE_SPRITES:
		r = def.radius
	if def.id != &"meteor":
		r *= cfg.character_scale
	t.r[i] = r
	t.max_hp[i] = def.hp * z * z * (1.0 + 0.6 * (L - 1.0)) * cfg.enemy_hp_mult * (3.0 if elite else 1.0)
	t.hp[i] = t.max_hp[i]
	t.armor[i] = def.armor * z * (1.0 + 0.35 * (L - 1.0)) * cfg.enemy_armor_mult * (1.3 if elite else 1.0)
	t.contact[i] = def.contact * (1.0 + 0.2 * (L - 1.0))
	t.xp[i] = def.xp * z * (1.0 + 0.5 * (L - 1.0)) * (4.0 if elite else 1.0)
	t.speed[i] = def.speed * (1.0 + 0.04 * (L - 1.0))
	t.pos[i] = pos
	t.vel[i] = opts.get("vel", Vector2.ZERO)
	t.facing[i] = opts.get("facing", 0.0)
	t.spin[i] = opts.get("spin", 0.0)
	t.hit_cd[i] = opts.get("hit_cd", 0.0)
	t.weak_arc[i] = def.weak_arc
	t.color[i] = def.color
	var fire_interval: float = def.params.get("fire_interval", 0.0)
	t.fire_t[i] = fire_interval * (0.5 + state.rng.randf() * 0.5)
	t.beh[i] = BEH.get(def.behavior, EnemyTable.Beh.CHASE)
	var n := t.id[i]
	t.roam_phase[i] = n * 1.61803398875
	t.roam_angle[i] = n * 2.39996322973
	t.roam_radius[i] = (0.45 + 0.5 * sqrt(fmod(n * 0.61803398875, 1.0))) * minf(1.0, cfg.enemy_pursuit_spread / 480.0)
	t.accel[i] = def.accel if def.accel > 0.0 else 2.0
	t.turn[i] = def.turn if def.turn > 0.0 else 4.0
	t.meteor_index[i] = opts.get("meteor_index", -1)
	if t.meteor_index[i] < 0:
		_add_beh(i)
	return i

## ボスの当たり判定の行を出し、その行番号を返す。ボスの行動は BossActor が動かす。
func spawn_boss(type: StringName, pos: Vector2, r: float, max_hp: float, armor: float, contact: float,
		xp: float, speed: float, weak_arc: float, facing: float, color: Color) -> int:
	var i := slots.take()
	_reset_row(i)
	var t := table
	t.type[i] = type
	t.is_boss[i] = 1
	t.pos[i] = pos
	t.r[i] = r
	t.max_hp[i] = max_hp
	t.hp[i] = max_hp
	t.armor[i] = armor
	t.contact[i] = contact
	t.xp[i] = xp
	t.speed[i] = speed
	t.weak_arc[i] = weak_arc
	t.facing[i] = facing
	t.color[i] = color
	return i

## 行 i の全部の列を初期値にし、新しい id を振る。敵を出す関数は、必ずここを通してから値を入れる。
func _reset_row(i: int) -> void:
	var t := table
	t.id[i] = _next_id
	_next_id += 1
	t.def[i] = null
	t.type[i] = &""
	t.beh[i] = EnemyTable.Beh.CHASE
	t.beh_slot[i] = -1
	t.is_boss[i] = 0
	t.meteor_index[i] = -1
	t.dead[i] = 0
	t.level[i] = 1.0
	t.elite[i] = 0
	t.pos[i] = Vector2.ZERO
	t.vel[i] = Vector2.ZERO
	t.facing[i] = 0.0
	t.r[i] = 10.0
	t.hp[i] = 1.0
	t.max_hp[i] = 1.0
	t.armor[i] = 0.0
	t.contact[i] = 0.0
	t.xp[i] = 0.0
	t.weak_arc[i] = 0.0
	t.color[i] = Color.WHITE
	t.hit_cd[i] = 0.0
	t.flash[i] = 0.0
	t.age[i] = 0.0
	t.hull_scattered[i] = 0
	t.speed[i] = 0.0
	t.accel[i] = 2.0
	t.turn[i] = 4.0
	t.roam_phase[i] = 0.0
	t.roam_angle[i] = 0.0
	t.roam_radius[i] = 0.0
	t.mode[i] = EnemyTable.Mode.MOVE
	t.timer[i] = 0.0
	t.fire_t[i] = 0.0
	t.charge[i] = 0.0
	t.bud_t[i] = 0.0
	t.buds[i] = 0
	t.spin[i] = 0.0
	t.knock_t[i] = 0.0
	t.shove_time[i] = 0.0
	t.shove_vel[i] = Vector2.ZERO
	t.shove_dmg[i] = 0.0
	t.shove_hits[i] = {}
	t.shove_from[i] = Vector2.ZERO
	t.shoved[i] = 0
	t.dash_seen[i] = -1
	t.dash_fresh[i] = 0

## 分裂などで増える敵。更新の終わりに、個体数の上限の範囲で出す（仕様書 11.3）。
func spawn_later(def: EnemyDef, level: float, pos: Vector2, opts := {}) -> void:
	_new.append([def, level, pos, opts])

## 行 i が、id の敵のまま使用中か（撃破済みでも、空きに戻るまでは true）。
func is_same(i: int, id: int) -> bool:
	return i >= 0 and i < table.alive.size() and table.alive[i] != 0 and table.id[i] == id

## 撃破済みにする。行はその回の終わり（cleanup）に空きへ戻る。
func mark_dead(i: int) -> void:
	if table.dead[i] != 0:
		return
	table.dead[i] = 1
	_dead_rows.append(i)

## 使用中の行の数（隕石・ボス・空きに戻る前の撃破済みを含む）。
func count() -> int:
	return slots.live

## 全部の敵を消す（計測・確認用のツールが使う）。
func clear_all() -> void:
	slots.clear()
	for b in EnemyTable.Beh.size():
		beh_rows[b].clear()
	_dead_rows.clear()
	_new.clear()

func _add_beh(i: int) -> void:
	var b := table.beh[i]
	table.beh_slot[i] = beh_rows[b].size()
	beh_rows[b].append(i)

## 行 i を空きに戻す。行動の種類ごとの一覧からは、最後の行と入れ替えて外す。
func _release_row(i: int) -> void:
	var s := table.beh_slot[i]
	if s >= 0:
		var rows := beh_rows[table.beh[i]]
		var last := rows[rows.size() - 1]
		rows[s] = last
		table.beh_slot[last] = s
		rows.resize(rows.size() - 1)
		table.beh_slot[i] = -1
	slots.release(i)

func def_of(type: StringName) -> EnemyDef:
	return ConfigManager.enemies.get(type) as EnemyDef

## 負荷計測用。通常の出現上限を超え、画面内にランダムな通常敵を追加する。
func debug_spawn_random(count_n: int) -> void:
	if not OS.is_debug_build():
		return
	var choices: Array[EnemyDef] = []
	for def: EnemyDef in ConfigManager.sorted(ConfigManager.enemies):
		if def.id != &"meteor":
			choices.append(def)
	if choices.is_empty():
		return
	var view := state.view_rect()
	var level: float = _target().level
	for k in clampi(count_n, 1, 10000):
		var def := choices[state.rng.randi_range(0, choices.size() - 1)]
		var pos := Vector2(state.rng.randf_range(view.position.x, view.end.x),
			state.rng.randf_range(view.position.y, view.end.y))
		var opts := {"facing": (state.ship_pos - pos).angle()}
		if def.size_var:
			opts.size = def.radius * state.rng.randf_range(0.85, 1.45)
		var i := spawn(def, level + field.danger_at(pos.length()) * cfg.danger_level, pos, opts)
		var r := table.r[i]
		var p := field.push_out(pos, r + 4.0)
		if p.length() > cfg.field_radius - r:
			p = p.normalized() * (cfg.field_radius - r)
		table.pos[i] = p

# ── 更新 ──────────────────────────────────────────────────────────

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	_update_aim(world_dt)
	_tick_chase(world_dt)
	for b in [EnemyTable.Beh.DASH, EnemyTable.Beh.SPLIT, EnemyTable.Beh.GUNNER, EnemyTable.Beh.MISSILE, EnemyTable.Beh.BATTLESHIP, EnemyTable.Beh.DRIFT]:
		_tick_behavior(b, world_dt)
	_flush_new()

## 追跡（いちばん多い雑魚）は、関数を呼ばずにここで計算する（仕様書 11.5）。
func _tick_chase(dt: float) -> void:
	var t := table
	var aim := state.enemy_aim
	var vc := state.view_center
	var vh := state.view_half
	var cycle_len := cfg.enemy_approach_cycle
	var appr := cfg.enemy_approach_time
	var blend := cfg.enemy_approach_blend
	var roam_turn := cfg.enemy_roam_turn
	var pos := t.pos
	var vel := t.vel
	var facing := t.facing
	var age := t.age
	var hit_cd := t.hit_cd
	var flash := t.flash
	var dead := t.dead
	var shove_time := t.shove_time
	var knock_t := t.knock_t
	var roam_phase := t.roam_phase
	var roam_angle := t.roam_angle
	var roam_radius := t.roam_radius
	var speed := t.speed
	var accel := t.accel
	var turn := t.turn
	var r := t.r
	for i in beh_rows[EnemyTable.Beh.CHASE]:
		if dead[i] != 0:
			continue
		var a := age[i] + dt
		age[i] = a
		if hit_cd[i] > 0.0:
			hit_cd[i] -= dt
		if flash[i] > 0.0:
			flash[i] -= dt
		var from := pos[i]
		if shove_time[i] > 0.0 or knock_t[i] > 0.0:
			_update_pushed(i, dt)
		else:
			var cycle := fmod(a + roam_phase[i], cycle_len)
			var roam := clampf(minf((cycle - appr) / blend, (cycle_len - cycle) / blend), 0.0, 1.0)
			var target := aim
			if roam > 0.0:
				var ang := roam_angle[i] + a * roam_turn
				var ux := cos(ang)
				var uy := sin(ang)
				var edge := roam_radius[i] / maxf(absf(ux), absf(uy))
				target = aim + (Vector2(vc.x + ux * edge * vh.x, vc.y + uy * edge * vh.y) - aim) * roam
			var d := target - from
			var dist := d.length()
			if dist < 0.001:
				dist = 1.0
			var k := minf(1.0, accel[i] * dt)
			var v := vel[i]
			v += (d * (speed[i] / dist) - v) * k
			vel[i] = v
			var f := facing[i]
			var turn_max := turn[i] * dt
			facing[i] = f + clampf(wrapf((aim - from).angle() - f, -PI, PI), -turn_max, turn_max)
			pos[i] = from + v * dt
		if field.near_body(pos[i], r[i] + vel[i].length() * dt):
			field.collide_enemy(i, from)

## 追跡以外の行動の種類 b の雑魚を進める。
func _tick_behavior(b: int, dt: float) -> void:
	var t := table
	for i in beh_rows[b]:
		if t.dead[i] != 0:
			continue
		t.age[i] += dt
		if t.hit_cd[i] > 0.0:
			t.hit_cd[i] -= dt
		if t.flash[i] > 0.0:
			t.flash[i] -= dt
		var from := t.pos[i]
		if t.shove_time[i] > 0.0 or t.knock_t[i] > 0.0:
			_update_pushed(i, dt)
		else:
			match b:
				EnemyTable.Beh.DASH:
					_dash(i, dt)
				EnemyTable.Beh.SPLIT:
					_chase(i, dt)
					_split(i, dt)
				EnemyTable.Beh.GUNNER:
					_keep_distance(i, dt)
					if _gun_timer(i, dt):
						projectiles.fire_enemy(i, (state.enemy_aim - t.pos[i]).angle(), t.def[i].params.bullet_speed, &"bullet")
				EnemyTable.Beh.MISSILE:
					_keep_distance(i, dt)
					if _gun_timer(i, dt):
						projectiles.fire_enemy(i, t.facing[i], t.def[i].params.missile_speed, &"missile")
				EnemyTable.Beh.BATTLESHIP:
					_chase(i, dt)
					if _gun_timer(i, dt):
						fire_volley(i)
				EnemyTable.Beh.DRIFT:
					t.facing[i] += t.spin[i] * dt
			t.pos[i] += t.vel[i] * dt
		if field.near_body(t.pos[i], t.r[i] + t.vel[i].length() * dt):
			field.collide_enemy(i, from)

## 押し出されている・吹き飛ばされている間の動き（行動の種類によらない）。
func _update_pushed(i: int, dt: float) -> void:
	var t := table
	if t.shove_time[i] > 0.0:
		t.shove_from[i] = t.pos[i]
		t.shoved[i] = 1
		t.shove_time[i] -= dt
		t.vel[i] = t.shove_vel[i]
		t.shove_vel[i] *= exp(-dt * 0.8)
	else:
		t.knock_t[i] -= dt
		t.vel[i] *= exp(-dt * 2.0)
	t.pos[i] += t.vel[i] * dt

## 敵の狙い：機体の遅れた位置（仕様書 7.5）。
func _update_aim(dt: float) -> void:
	var d := state.ship_pos - state.enemy_aim
	var dist := d.length()
	var max_lag := maxf(300.0, state.view_half.length() * 0.55)
	if dist > max_lag:
		state.enemy_aim = state.ship_pos - d / dist * max_lag
		d = state.ship_pos - state.enemy_aim
		dist = max_lag
	if dist < 1e-6:
		return
	var step := minf(dist * (1.0 - exp(-dt / cfg.enemy_aim_lag)), cfg.enemy_aim_speed * dt)
	state.enemy_aim += d / dist * step

## 扇状に弾をばらまく（戦艦）。
func fire_volley(i: int) -> void:
	var p: Dictionary = table.def[i].params
	var base := (state.enemy_aim - table.pos[i]).angle()
	var n: int = p.volley
	var spread: float = p.spread
	for k in n:
		projectiles.fire_enemy(i, base + (float(k) / (n - 1) - 0.5) * spread, p.bullet_speed, &"bullet")

func _steer_to(i: int, target: Vector2, speed: float, accel: float, dt: float) -> void:
	var d := target - table.pos[i]
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var k := minf(1.0, accel * dt)
	table.vel[i] += (d / dist * speed - table.vel[i]) * k

func _turn_toward(i: int, target: float, rate: float, dt: float) -> void:
	table.facing[i] += clampf(Geom.angle_diff(target, table.facing[i]), -rate * dt, rate * dt)

## 追跡：18秒の周期で「接近」と「広域移動」を切り替える（仕様書 11.5）。
func _chase(i: int, dt: float) -> void:
	var t := table
	var aim := state.enemy_aim
	var cycle := fmod(t.age[i] + t.roam_phase[i], cfg.enemy_approach_cycle)
	var roam := clampf(minf((cycle - cfg.enemy_approach_time) / cfg.enemy_approach_blend,
		(cfg.enemy_approach_cycle - cycle) / cfg.enemy_approach_blend), 0.0, 1.0)
	var target := aim
	if roam > 0.0:
		var ang := t.roam_angle[i] + t.age[i] * cfg.enemy_roam_turn
		var u := Vector2(cos(ang), sin(ang))
		var edge := t.roam_radius[i] / maxf(absf(u.x), absf(u.y))
		var roam_target := state.view_center + Vector2(u.x * edge * state.view_half.x, u.y * edge * state.view_half.y)
		target = aim + (roam_target - aim) * roam
	_steer_to(i, target, t.speed[i], t.accel[i], dt)
	_turn_toward(i, (aim - t.pos[i]).angle(), t.turn[i], dt)

func _dash(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var d := state.enemy_aim.distance_to(t.pos[i])
	t.timer[i] -= dt
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_chase(i, dt)
			if d < float(p.range):
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = p.windup
		EnemyTable.Mode.WINDUP:
			t.vel[i] *= 1.0 - 4.0 * dt
			_turn_toward(i, (state.enemy_aim - t.pos[i]).angle(), 6.0, dt)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = p.dash_time
				t.vel[i] = Vector2.from_angle(t.facing[i]) * float(p.dash_speed)
		EnemyTable.Mode.DASH:
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = p.recover
		EnemyTable.Mode.RECOVER:
			t.vel[i] *= 1.0 - 2.0 * dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE

func _split(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.bud_t[i] += dt
	if t.bud_t[i] < float(p.bud_interval):
		return
	t.bud_t[i] = 0.0
	if t.buds[i] >= int(p.max_buds):
		return
	t.buds[i] += 1
	var a := state.rng.randf() * TAU
	spawn_later(def_of(&"splitling"), t.level[i], t.pos[i] + Vector2.from_angle(a) * t.r[i] * 1.5, {"facing": a})

## 射撃型・ミサイル艇：機体の周りの keep の距離を保ち、回り込む。
func _keep_distance(i: int, dt: float) -> void:
	var t := table
	var aim := state.enemy_aim
	var d := t.pos[i] - aim
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var u := d / dist
	var side := 1.0 if t.id[i] % 2 == 1 else -1.0
	var keep: float = t.def[i].params.keep
	var target := aim + u * keep + Vector2(-u.y, u.x) * 200.0 * side
	_steer_to(i, target, t.speed[i], t.def[i].accel, dt)
	_turn_toward(i, (aim - t.pos[i]).angle(), 3.0, dt)

## 発射までの時間を進める。予告の間は charge が 0〜1 で増える。撃つときに true。
func _gun_timer(i: int, dt: float) -> bool:
	var t := table
	var p: Dictionary = t.def[i].params
	t.fire_t[i] -= dt
	var tele: float = p.telegraph
	t.charge[i] = 1.0 - maxf(0.0, t.fire_t[i]) / tele if t.fire_t[i] < tele else 0.0
	if t.fire_t[i] <= 0.0:
		t.fire_t[i] = p.fire_interval
		return true
	return false

## 撃破されたときの処理（分裂型は2体に分かれる）。
func on_enemy_death(i: int) -> void:
	var t := table
	if t.type[i] != &"splitter":
		return
	var p: Dictionary = t.def[i].params
	var n := maxi(1, int(p.get("death_split", 2)))
	var facing := t.facing[i]
	for k in n:
		var a := facing + PI / 2.0 + TAU * float(k) / float(n) if n > 2 else facing + (1.0 if k == 1 else -1.0) * PI / 2.0
		spawn_later(def_of(&"splitling"), t.level[i], t.pos[i] + Vector2.from_angle(a) * t.r[i],
			{"facing": a, "vel": Vector2.from_angle(a) * float(p.get("split_speed", 200.0)), "hit_cd": 0.35})

## 分裂などで増えた敵を、個体数の上限の範囲で出す（仕様書 11.3）。
func _flush_new() -> void:
	if _new.is_empty():
		return
	var limit := ceili(_target().pop * (1.0 + cfg.enemy_split_overflow))
	var population := _count_population(false)
	for n in _new:
		if population >= limit:
			break
		spawn(n[0], n[1], n[2], n[3])
		population += 1
	_new.clear()

## 撃破済みの行を空きに戻す。
func cleanup() -> void:
	if _dead_rows.is_empty():
		return
	for i in _dead_rows:
		if table.alive[i] != 0 and table.dead[i] != 0:
			_release_row(i)
	_dead_rows.clear()

# ── 出現と補充（仕様書 4.2・11.3・11.4） ─────────────────────────────

func current_phase() -> PhaseDef:
	var phases: Array = state.stage.phases
	for p: PhaseDef in phases:
		if state.time < p.end:
			return p
	return phases[phases.size() - 1]

func _target() -> Dictionary:
	var p := current_phase()
	var k := clampf((state.time - p.start) / maxf(0.001, p.end - p.start), 0.0, 1.0)
	return {"phase": p, "pop": lerpf(p.pop_from, p.pop_to, k) * cfg.density_mult, "level": lerpf(p.level_from, p.level_to, k)}

## 通常の敵の数。in_view が true なら、再配置の範囲の中だけを数える。
func _count_population(in_view: bool) -> int:
	var n := 0
	var lim := state.view_half * cfg.spawn_recycle_scale + Vector2(200, 200)
	var pos := table.pos
	var dead := table.dead
	for rows in beh_rows:
		for i in rows:
			if dead[i] != 0:
				continue
			if in_view:
				var d := (pos[i] - state.view_center).abs()
				if d.x > lim.x or d.y > lim.y:
					continue
			n += 1
	return n

## 補充と再配置。更新の終わりに呼ぶ。
func spawner_tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	var t := _target()
	var phase: PhaseDef = t.phase
	if phase.id != _phase_id:
		_phase_id = phase.id
		state.emit(&"phase", {"id": phase.id})
	var alive_n := _survey()
	var deficit := maxf(0.0, t.pop - alive_n)
	var rate := maxf(phase.rate * cfg.density_mult, deficit / cfg.spawn_refill_time)
	var cap := maxf(8.0, 8.0 * cfg.density_mult)
	_spawn_acc = minf(_spawn_acc + rate * world_dt, cap)
	var attempts := 0
	while _spawn_acc >= 1.0 and alive_n < t.pop and attempts < cap:
		attempts += 1
		_spawn_acc -= 1.0
		if _spawn_one(t):
			alive_n += 1
	if phase.wave_interval > 0.0:
		_wave_t += world_dt
		if _wave_t >= phase.wave_interval:
			_wave_t = 0.0
			if alive_n < t.pop:
				_spawn_wave(t, t.pop - alive_n)

var _type_counts: Dictionary = {}
var _far_rows := PackedInt32Array()

## 1回の走査で、外周の辺ごとの数・出現上限のある種類の数・再配置の範囲の中の数を数え、遠くの敵を再配置する。
## 戻り値は再配置の範囲の中の通常の敵の数。
func _survey() -> int:
	_edge_counts.fill(0)
	_type_counts.clear()
	var battleships := 0
	var titans := 0
	var vc := state.view_center
	var vh := state.view_half
	var lim := vh * cfg.spawn_recycle_scale + Vector2(200, 200)
	var alive_n := 0
	var center_x := vh.x * 0.45
	var center_y := vh.y * 0.45
	var pos := table.pos
	var dead := table.dead
	var type := table.type
	_far_rows.clear()
	for rows in beh_rows:
		for i in rows:
			if dead[i] != 0:
				continue
			# 種類別上限を使う2種類だけ集計。全種類の辞書更新は不要。
			var ty := type[i]
			if ty == &"battleship":
				battleships += 1
			elif ty == &"titan":
				titans += 1
			var rel := pos[i] - vc
			if absf(rel.x) > lim.x or absf(rel.y) > lim.y:
				_far_rows.append(i)
				continue
			alive_n += 1
			var ax := absf(rel.x)
			var ay := absf(rel.y)
			if ax < center_x and ay < center_y:
				continue
			# 正規化した距離の比較を交差乗算にし、個体ごとの除算を省く。
			var side := (0 if rel.x < 0.0 else 1) if ax * vh.y > ay * vh.x else (2 if rel.y < 0.0 else 3)
			_edge_counts[side] += 1
	_type_counts[&"battleship"] = battleships
	_type_counts[&"titan"] = titans
	for i in _far_rows:
		if _recycle(i):
			alive_n += 1
	return alive_n

## 画面の四辺の外の出現位置。外周の敵が少ない辺を優先する。
func spawn_point(extra := 0.0) -> Variant:
	var view_c := state.view_center
	var half := state.view_half
	for k in 24:
		var weights := []
		var total := 0.0
		for edge in 4:
			var w: float = (half.y if edge < 2 else half.x) / (_edge_counts[edge] + 8)
			weights.append(w)
			total += w
		var roll := state.rng.randf() * total
		var side := 0
		while side < 3 and roll >= weights[side]:
			roll -= weights[side]
			side += 1
		var margin := cfg.spawn_margin + extra + state.rng.randf() * 80.0
		var along := state.rng.randf() * 2.0 - 1.0
		var p := view_c
		if side < 2:
			p += Vector2((-1.0 if side == 0 else 1.0) * (half.x + margin), along * half.y)
		else:
			p += Vector2(along * half.x, (-1.0 if side == 2 else 1.0) * (half.y + margin))
		var r := p.length()
		if r < cfg.field_radius + 200.0 and r > cfg.planet_radius + 150.0:
			_edge_counts[side] += 1
			return p
	return null

func _spawn_one(t: Dictionary) -> bool:
	var p = spawn_point()
	if p == null:
		return false
	var phase: PhaseDef = t.phase
	var danger := field.danger_at(p.length())
	var type := _pick_type(phase, danger)
	if type == &"battleship" and _type_counts.get(type, 0) >= cfg.battleship_max:
		return false
	if type == &"titan" and _type_counts.get(type, 0) >= cfg.titan_max:
		return false
	var def := def_of(type)
	if def == null:
		return false
	var late := phase.id == &"tension" or phase.id == &"escape"
	var elite := type != &"battleship" and state.rng.randf() < 0.01 + 0.06 * danger + (0.02 if late else 0.0)
	var level: float = t.level + danger * cfg.danger_level
	var opts := {"elite": elite, "facing": (state.ship_pos - p).angle()}
	if def.size_var:
		opts.size = def.radius * (0.85 + state.rng.randf() * 0.45)
	spawn(def, level, p, opts)
	_type_counts[type] = _type_counts.get(type, 0) + 1
	return true

func _pick_type(phase: PhaseDef, danger: float) -> StringName:
	var items: Array = []
	var total := 0.0
	for k in phase.mix:
		items.append([StringName(k), float(phase.mix[k])])
	if danger > 0.25:
		var ramp := clampf(state.time / 150.0, 0.15, 1.0)
		items.append([&"armored", 2.0 * danger])
		items.append([&"gunner", danger * ramp])
		items.append([&"missile", 0.7 * danger * ramp])
	for it in items:
		total += it[1]
	var roll := state.rng.randf() * total
	for it in items:
		if roll < it[1]:
			return it[0]
		roll -= it[1]
	return items[items.size() - 1][0]

## 無双期の群れ：環状に囲むか、一方向から流れ込む。
func _spawn_wave(t: Dictionary, remaining: float) -> void:
	var n := mini(roundi(30 * cfg.density_mult), ceili(remaining))
	var def := def_of(&"swarm")
	var half := state.view_half
	if state.rng.randf() < 0.5:
		for k in n:
			var a := (k + state.rng.randf()) / n * TAU
			var u := Vector2(cos(a), sin(a))
			var d := minf((half.x + cfg.spawn_margin) / maxf(0.0001, absf(u.x)), (half.y + cfg.spawn_margin) / maxf(0.0001, absf(u.y))) + state.rng.randf() * 90.0
			spawn(def, t.level, state.view_center + u * d, {"facing": a + PI})
	else:
		var a := state.rng.randf() * TAU
		var u := Vector2(cos(a), sin(a))
		for k in n:
			var d := minf(half.x / maxf(0.0001, absf(u.x)), half.y / maxf(0.0001, absf(u.y))) + cfg.spawn_margin + k * 12.0
			var off := (state.rng.randf() - 0.5) * 120.0
			spawn(def, t.level, state.ship_pos + u * d + Vector2(-u.y, u.x) * off, {"facing": a + PI})
	state.emit(&"wave")

## 遠くへ離れた敵を、画面外の出現位置へ移す。HP などは保ち、撃破・経験値・ドロップは発生しない。
func _recycle(i: int) -> bool:
	var p = spawn_point()
	if p == null:
		return false
	var t := table
	t.pos[i] = p
	var to_ship: Vector2 = (state.ship_pos - p).normalized()
	t.vel[i] = to_ship * t.speed[i]
	t.facing[i] = to_ship.angle()
	t.mode[i] = EnemyTable.Mode.MOVE
	t.timer[i] = 0.0
	t.charge[i] = 0.0
	t.fire_t[i] = t.def[i].params.get("fire_interval", 0.0)
	return true
