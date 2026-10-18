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
## 実験場が複製した定義。未指定時は本番の定義を読む。
var definitions: Dictionary = {}

const BEH := {&"chase": EnemyTable.Beh.CHASE, &"dash": EnemyTable.Beh.DASH, &"split": EnemyTable.Beh.SPLIT,
	&"gunner": EnemyTable.Beh.GUNNER, &"missile": EnemyTable.Beh.MISSILE,
	&"battleship": EnemyTable.Beh.BATTLESHIP, &"drift": EnemyTable.Beh.DRIFT, &"rocket": EnemyTable.Beh.ROCKET,
	&"bomber": EnemyTable.Beh.BOMBER, &"beamer": EnemyTable.Beh.BEAMER, &"pulser": EnemyTable.Beh.PULSER,
	&"pump": EnemyTable.Beh.PUMP, &"sniper": EnemyTable.Beh.SNIPER, &"shield": EnemyTable.Beh.SHIELD,
	&"ruler": EnemyTable.Beh.RULER, &"clock": EnemyTable.Beh.CLOCK, &"lynx": EnemyTable.Beh.LYNX,
	&"crow": EnemyTable.Beh.CROW, &"reticle": EnemyTable.Beh.RETICLE, &"triangle": EnemyTable.Beh.TRIANGLE,
	&"part": EnemyTable.Beh.PART, &"phoenix": EnemyTable.Beh.PHOENIX, &"crab": EnemyTable.Beh.CRAB,
	&"marlin": EnemyTable.Beh.MARLIN, &"aquarius": EnemyTable.Beh.AQUARIUS, &"auriga": EnemyTable.Beh.AURIGA,
	&"corona": EnemyTable.Beh.CORONA, &"cepheus": EnemyTable.Beh.CEPHEUS, &"aquila": EnemyTable.Beh.AQUILA,
	&"soldier": EnemyTable.Beh.SOLDIER}
## ポンプ座の吸い込み口の位置（胴体の中心から前へ、半径に対する割合。pump.png の口に合わせる）
const PUMP_MOUTH := 0.85
## 特殊な倒し方（EnemyDef.gate）の名前と種類
const GATE := {&"mouth": EnemyTable.Gate.MOUTH, &"back": EnemyTable.Gate.BACK, &"shell": EnemyTable.Gate.SHELL,
	&"membrane": EnemyTable.Gate.MEMBRANE, &"claw": EnemyTable.Gate.CLAW,
	&"guard": EnemyTable.Gate.GUARD, &"solid": EnemyTable.Gate.SOLID,
	&"ghost": EnemyTable.Gate.GHOST, &"immortal": EnemyTable.Gate.IMMORTAL}

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
## 画面から遠い敵の判断を間引く回数（LOD 回に1回、まとめた時間で判断する。移動は毎回）と、更新の通し番号
const LOD := 3
var _lod := 0
## 1回の更新の中で何度も読む値（更新の始めに読む）
var _aim := Vector2.ZERO
var _vc := Vector2.ZERO
var _vh := Vector2.ZERO
var _face_move := 0.0

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
	apply_scaling(i, def, level, opts)
	t.pos[i] = pos
	t.vel[i] = opts.get("vel", Vector2.ZERO)
	t.facing[i] = opts.get("facing", 0.0)
	t.spin[i] = opts.get("spin", 0.0)
	t.hit_cd[i] = opts.get("hit_cd", 0.0)
	t.guard[i] = opts.get("guard", 0.0)
	t.knock_t[i] = opts.get("knock", 0.0)
	t.weak_arc[i] = def.weak_arc
	t.gate[i] = GATE.get(def.gate, EnemyTable.Gate.NONE)
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
	if t.beh[i] == EnemyTable.Beh.TRIANGLE:
		_spawn_triangle_stars(i)
	elif t.beh[i] == EnemyTable.Beh.CORONA:
		var star := def_of(&"corona_star")
		for k in int(def.params.stars):
			spawn_part(i, star, pos + Vector2.from_angle(TAU * k / float(def.params.stars)) * float(def.params.ring))
	elif t.beh[i] == EnemyTable.Beh.CROW and not opts.get("flock_member", false):
		_spawn_flock(i, level, opts)
	return i

## からす座の群れの隊列（先頭からの位置。前へ x、右へ y、flock_gap 単位）。からす座の4つの星の並びにそろえる
const CROW_FORMATION := [Vector2(-1.0, -1.1), Vector2(-1.1, 1.0), Vector2(-2.1, 0.2)]

## からす座：先頭の1羽（行 i）の向きを決め、残りを隊列に並べて同じ向き・同じ速さで出す。
## 向きは、画面の中心から aim_spread だけずれた所を通る向き。画面の中心のすぐ近くに置かれた群れは、置いた向きのまま進む。
func _spawn_flock(i: int, level: float, opts: Dictionary) -> void:
	var t := table
	var def := t.def[i]
	var p: Dictionary = def.params
	var vc := state.view_center
	var vh := state.view_half
	var spread := float(p.aim_spread)
	var target := vc + Vector2(state.rng.randf_range(-spread, spread) * vh.x, state.rng.randf_range(-spread, spread) * vh.y)
	if target.distance_to(t.pos[i]) > minf(vh.x, vh.y) * 0.25:
		t.facing[i] = (target - t.pos[i]).angle()
	t.mode[i] = EnemyTable.Mode.DASH
	var u := Vector2.from_angle(t.facing[i])
	var side := Vector2(-u.y, u.x)
	var gap := float(p.flock_gap)
	for k in mini(int(p.flock) - 1, CROW_FORMATION.size()):
		var at: Vector2 = t.pos[i] + (u * CROW_FORMATION[k].x + side * CROW_FORMATION[k].y) * gap
		var j := spawn(def, level, at, {"facing": t.facing[i], "elite": opts.get("elite", false), "flock_member": true})
		t.mode[j] = EnemyTable.Mode.DASH

## 強さと大きさを同じ規則で再計算する。位置・行動・個体IDは保つ。
func apply_scaling(i: int, def: EnemyDef, level: float, opts := {}) -> void:
	var t := table
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
	if opts.get("meteor_index", -1) < 0:
		r *= cfg.character_scale
	t.r[i] = r
	t.max_hp[i] = def.hp * z * z * (1.0 + 0.6 * (L - 1.0)) * cfg.enemy_hp_mult * (3.0 if elite else 1.0)
	t.hp[i] = t.max_hp[i]
	t.armor[i] = def.armor * z * (1.0 + 0.35 * (L - 1.0)) * cfg.enemy_armor_mult * (1.3 if elite else 1.0)
	t.xp[i] = def.xp * z * (1.0 + 0.5 * (L - 1.0)) * (4.0 if elite else 1.0)
	t.speed[i] = def.speed * (1.0 + 0.04 * (L - 1.0))

## 部位を1つ出し、親（行 i）に付ける。
func spawn_part(i: int, def: EnemyDef, pos: Vector2) -> int:
	var j := spawn(def, table.level[i], pos)
	table.parent[j] = i
	table.parent_id[j] = table.id[i]
	var parts := table.parts[i]
	parts.append(j)
	parts.append(table.id[j])
	table.parts[i] = parts
	return j

## 部位のうち、生きているものの数。
func parts_alive(i: int) -> int:
	var parts := table.parts[i]
	var n := 0
	for k in range(0, parts.size(), 2):
		if self.is_same(parts[k], parts[k + 1]) and table.dead[parts[k]] == 0:
			n += 1
	return n

## ボスの当たり判定の行を出し、その行番号を返す。ボスの行動は BossActor が動かす。
func spawn_boss(type: StringName, pos: Vector2, r: float, max_hp: float, armor: float,
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
	t.gate[i] = EnemyTable.Gate.NONE
	t.xp[i] = 0.0
	t.weak_arc[i] = 0.0
	t.color[i] = Color.WHITE
	t.hit_cd[i] = 0.0
	t.guard[i] = 0.0
	t.flash[i] = 0.0
	t.age[i] = 0.0
	t.hull_scattered[i] = 0
	t.speed[i] = 0.0
	t.accel[i] = 2.0
	t.turn[i] = 4.0
	t.body_gap[i] = -1.0
	t.body_gap_pos[i] = Vector2.ZERO
	t.body_gap_time[i] = 0.0
	t.roam_phase[i] = 0.0
	t.roam_angle[i] = 0.0
	t.roam_radius[i] = 0.0
	t.mode[i] = EnemyTable.Mode.MOVE
	t.timer[i] = 0.0
	t.fire_t[i] = 0.0
	t.charge[i] = 0.0
	t.bud_t[i] = 0.0
	t.buds[i] = 0
	t.carry[i] = 0.0
	t.target[i] = -1
	t.target_id[i] = -1
	t.anchor[i] = Vector2.ZERO
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
	t.links[i] = PackedInt32Array()
	t.shell_dmg[i] = 0.0
	t.shell_open[i] = 0.0
	t.shell_rest[i] = 0.0
	t.stone[i] = 0.0
	t.landmark[i] = 0
	t.fire_hit[i] = -1e9
	t.parent[i] = -1
	t.parent_id[i] = -1
	t.parts[i] = PackedInt32Array()

## 分裂などで増える敵。更新の終わりに、個体数の上限の範囲で出す（仕様書 11.3）。
func spawn_later(def: EnemyDef, level: float, pos: Vector2, opts := {}) -> void:
	_new.append([def, level, pos, opts])

## 行 i が、id の敵のまま使用中か（撃破済みでも、空きに戻るまでは true）。
func is_same(i: int, id: int) -> bool:
	return i >= 0 and i < table.alive.size() and table.alive[i] != 0 and table.id[i] == id

## 撃破済みにする。行はその回の終わり（cleanup）に空きへ戻る。
## 行 i の敵に、位置 hit から向き dir の攻撃（cause）が当たったときの扱い（EnemyTable.GateResult）。
## 特殊な倒し方の条件を満たさない攻撃は、体当たりなら貫通するがダメージを与えない（PASS）。
## 弾かれるのは失敗のとき（BOUNCE）だけ。dmg は当たった攻撃のダメージで、殻（やまねこ座）にはこの判定で傷を付ける。
func gate_check(i: int, _hit: Vector2, dir: Vector2, cause: StringName, dmg := 0.0) -> int:
	var t := table
	if t.beh[i] == EnemyTable.Beh.SHIELD:
		if shield_blocks(i, _hit, dir):
			return EnemyTable.GateResult.BOUNCE if cause == &"ram" else EnemyTable.GateResult.PASS
		return EnemyTable.GateResult.ALLOW
	match t.gate[i]:
		EnemyTable.Gate.MOUTH:
			# 口が開いている（吸い込んでいる）間だけ倒せる
			return EnemyTable.GateResult.ALLOW if t.mode[i] == EnemyTable.Mode.WINDUP else EnemyTable.GateResult.PASS
		EnemyTable.Gate.BACK, EnemyTable.Gate.CLAW:
			# 攻撃が背面から来たときだけ倒せる。前から当たった体当たりは弾かれる（失敗）
			# かに座は、挟んだ直後（ハサミが開いたまま）なら正面からでも倒せる
			if t.gate[i] == EnemyTable.Gate.CLAW and t.mode[i] == EnemyTable.Mode.RECOVER:
				return EnemyTable.GateResult.ALLOW
			var arc: float = t.def[i].params.get("front_arc", 1.6)
			var from_back := dir != Vector2.ZERO and absf(Geom.angle_diff(dir.angle(), t.facing[i])) < PI - arc
			if from_back:
				return EnemyTable.GateResult.ALLOW
			return EnemyTable.GateResult.BOUNCE if cause == &"ram" else EnemyTable.GateResult.PASS
		EnemyTable.Gate.MEMBRANE:
			# 膜が消えている（頂点の星が欠けている）間だけ、中の核を倒せる
			return EnemyTable.GateResult.ALLOW if t.mode[i] == EnemyTable.Mode.RECOVER else EnemyTable.GateResult.PASS
		EnemyTable.Gate.GHOST:
			# うみへび座の本体：体当たりも武器もすり抜ける（ダメージなし、弾かれない）
			return EnemyTable.GateResult.PASS
		EnemyTable.Gate.IMMORTAL:
			# うみへび座の不死の首：貫いたときだけ。火では焼けない
			return EnemyTable.GateResult.ALLOW if cause == &"ram" else EnemyTable.GateResult.PASS
		EnemyTable.Gate.SOLID:
			# 回る丸鋸：攻撃では壊れない（体当たりで飛ばす扱いは CombatManager）
			return EnemyTable.GateResult.PASS
		EnemyTable.Gate.GUARD:
			# 体当たりは弾かれる（失敗）。武器や波動では壊せる
			return EnemyTable.GateResult.BOUNCE if cause == &"ram" else EnemyTable.GateResult.ALLOW
		EnemyTable.Gate.SHELL:
			# 殻が割れている間に当たると倒れる
			if t.shell_open[i] > 0.0:
				t.hp[i] = minf(t.hp[i], 0.001)
				return EnemyTable.GateResult.ALLOW
			# 体当たりなら1回、ほかの攻撃は傷が殻の耐久に届くと割れる
			var p: Dictionary = t.def[i].params
			t.shell_rest[i] = 0.0
			t.shell_dmg[i] += INF if cause == &"ram" else dmg
			t.flash[i] = 0.08
			if t.shell_dmg[i] >= float(p.shell_hp):
				t.shell_open[i] = float(p.shell_time)
				t.shell_dmg[i] = 0.0
				state.emit(&"block_impact", {"pos": t.pos[i], "normal": -dir, "enemy_pos": t.pos[i], "r": t.r[i]})
			return EnemyTable.GateResult.PASS
	return EnemyTable.GateResult.ALLOW

## たて座の前面。命中した位置を使い、位置のない攻撃は飛んできた向きから判定する。
func shield_blocks(i: int, hit: Vector2, dir: Vector2) -> bool:
	var d := hit - table.pos[i]
	if d.length_squared() < 0.01:
		d = -dir
	return d.length_squared() > 0.0 and absf(Geom.angle_diff(d.angle(), table.facing[i])) <= float(table.def[i].params.front_arc)

## 盾を奪える背面。側面の通常攻撃と、背後からの高速体当たりを分ける。
func shield_rear(i: int, hit: Vector2) -> bool:
	return absf(Geom.angle_diff((hit - table.pos[i]).angle(), table.facing[i] + PI)) <= table.weak_arc[i]

func mark_dead(i: int) -> void:
	if table.dead[i] != 0:
		return
	table.dead[i] = 1
	_dead_rows.append(i)

## 使用中の行の数（隕石・ボス・空きに戻る前の撃破済みを含む）。
func count() -> int:
	return slots.live

## ボスと障害物のほかの敵を、撃破にせずに消す（ボーナスステージの出入り）。
func clear_regular() -> void:
	var t := table
	for i in t.alive.size():
		if t.alive[i] != 0 and t.is_boss[i] == 0 and t.meteor_index[i] < 0:
			mark_dead(i)

## 全部の敵を消す（計測・確認用のツールが使う）。
func clear_all() -> void:
	slots.clear()
	_tele_rays.clear()
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
	return definitions.get(type, ConfigManager.enemies.get(type)) as EnemyDef

## 負荷計測用。通常の出現上限を超え、画面内にランダムな通常敵を追加する。
func debug_spawn_random(count_n: int) -> void:
	if not OS.is_debug_build():
		return
	var choices: Array[EnemyDef] = []
	for def: EnemyDef in ConfigManager.sorted(ConfigManager.enemies):
		if def.id != &"meteor" and def.behavior != &"part" and def.behavior != &"obstacle":
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
	_lod += 1
	_aim = state.enemy_aim
	_vc = state.view_center
	_vh = state.view_half
	_face_move = cfg.enemy_face_move
	_tick_chase(world_dt)
	for b in [EnemyTable.Beh.DASH, EnemyTable.Beh.SPLIT, EnemyTable.Beh.GUNNER, EnemyTable.Beh.MISSILE,
			EnemyTable.Beh.BATTLESHIP, EnemyTable.Beh.DRIFT, EnemyTable.Beh.ROCKET, EnemyTable.Beh.BOMBER,
			EnemyTable.Beh.BEAMER, EnemyTable.Beh.PULSER, EnemyTable.Beh.PUMP, EnemyTable.Beh.SNIPER,
			EnemyTable.Beh.SHIELD, EnemyTable.Beh.RULER, EnemyTable.Beh.CLOCK, EnemyTable.Beh.LYNX,
			EnemyTable.Beh.CROW, EnemyTable.Beh.RETICLE, EnemyTable.Beh.TRIANGLE, EnemyTable.Beh.PART,
			EnemyTable.Beh.PHOENIX, EnemyTable.Beh.CRAB, EnemyTable.Beh.MARLIN, EnemyTable.Beh.AQUARIUS,
			EnemyTable.Beh.AURIGA, EnemyTable.Beh.CORONA, EnemyTable.Beh.CEPHEUS, EnemyTable.Beh.AQUILA,
			EnemyTable.Beh.SOLDIER]:
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
	var face_move := cfg.enemy_face_move
	var pos := t.pos
	var vel := t.vel
	var facing := t.facing
	var age := t.age
	var hit_cd := t.hit_cd
	var guard := t.guard
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
	var now := state.world_time
	var body_move := field.body_speed_max
	var stone := t.stone
	var lod_lim := vh * 1.25 + Vector2(300, 300)
	for i in beh_rows[EnemyTable.Beh.CHASE]:
		if dead[i] != 0:
			continue
		if stone[i] > 0.0:
			stone[i] -= dt
			vel[i] = Vector2.ZERO
			continue
		var a := age[i] + dt
		age[i] = a
		if hit_cd[i] > 0.0:
			hit_cd[i] -= dt
		if guard[i] > 0.0:
			guard[i] -= dt
		if flash[i] > 0.0:
			flash[i] -= dt
		var from := pos[i]
		var cdt := dt
		var rel := from - vc
		if absf(rel.x) > lod_lim.x or absf(rel.y) > lod_lim.y:
			if (t.id[i] + _lod) % LOD != 0 and shove_time[i] <= 0.0 and knock_t[i] <= 0.0:
				pos[i] = from + vel[i] * dt
				continue
			cdt = dt * LOD
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
			var k := minf(1.0, accel[i] * cdt)
			var v := vel[i]
			v += (d * (speed[i] / dist) - v) * k
			vel[i] = v
			# 向き：進む向きと機体への向きを混ぜ、毎秒 turn までしか回さない
			var w := face_move * minf(1.0, v.length() / maxf(speed[i], 1.0))
			var face := v.normalized() * w + (aim - from).normalized() * (1.0 - w)
			if face.length_squared() > 0.0025:
				var f := facing[i]
				var turn_max := turn[i] * cdt
				facing[i] = f + clampf(wrapf(face.angle() - f, -PI, PI), -turn_max, turn_max)
			pos[i] = from + v * dt
		if _near_body(i, pos[i], r[i] + vel[i].length() * dt, now, body_move):
			field.collide_enemy(i, from)

## 追跡以外の行動の種類 b の雑魚を進める。
func _tick_behavior(b: int, dt: float) -> void:
	var t := table
	var now := state.world_time
	var body_move := field.body_speed_max
	var pos := t.pos
	var vel := t.vel
	var age := t.age
	var hit_cd := t.hit_cd
	var guard := t.guard
	var flash := t.flash
	var dead := t.dead
	var shove_time := t.shove_time
	var knock_t := t.knock_t
	var r := t.r
	var stone := t.stone
	var vc := state.view_center
	var lim := state.view_half * 1.25 + Vector2(300, 300)
	for i in beh_rows[b]:
		if dead[i] != 0:
			continue
		if stone[i] > 0.0:
			# 石になっている間は動かない
			stone[i] -= dt
			vel[i] = Vector2.ZERO
			continue
		age[i] += dt
		if hit_cd[i] > 0.0:
			hit_cd[i] -= dt
		if guard[i] > 0.0:
			guard[i] -= dt
		if flash[i] > 0.0:
			flash[i] -= dt
		var from := pos[i]
		# 画面から遠い敵は、LOD 回に1回だけ、まとめた時間で判断する。間の回は今の速度で進むだけ
		var bdt := dt
		var rel := from - vc
		if absf(rel.x) > lim.x or absf(rel.y) > lim.y:
			if (t.id[i] + _lod) % LOD != 0 and shove_time[i] <= 0.0 and knock_t[i] <= 0.0:
				pos[i] = from + vel[i] * dt
				continue
			bdt = dt * LOD
		if shove_time[i] > 0.0 or knock_t[i] > 0.0:
			_update_pushed(i, dt)
		else:
			if not _lab_admit(i, bdt):
				_chase(i, bdt)
				pos[i] += vel[i] * dt
				if _near_body(i, pos[i], r[i] + vel[i].length() * dt, now, body_move):
					field.collide_enemy(i, from)
				continue
			match b:
				EnemyTable.Beh.DASH:
					_dash(i, bdt)
				EnemyTable.Beh.SPLIT:
					_chase(i, bdt)
					_split(i, bdt)
				EnemyTable.Beh.GUNNER:
					_keep_distance(i, bdt)
					if _gun_timer(i, bdt):
						projectiles.fire_enemy(i, (state.enemy_aim - pos[i]).angle(), t.def[i].params.bullet_speed, &"bullet")
				EnemyTable.Beh.MISSILE:
					_keep_distance(i, bdt)
					if _gun_timer(i, bdt):
						projectiles.fire_enemy(i, t.facing[i], t.def[i].params.missile_speed, &"missile")
				EnemyTable.Beh.BATTLESHIP:
					_chase(i, bdt)
					if _gun_timer(i, bdt):
						fire_volley(i)
				EnemyTable.Beh.DRIFT:
					t.facing[i] += t.spin[i] * bdt
					# 時間で消える漂流物（うみへび座の瓦礫など）。吐き出された勢いは少しずつ落ちる
					if t.def[i].params.has("life"):
						vel[i] *= maxf(0.0, 1.0 - 1.5 * bdt)
						if t.age[i] > float(t.def[i].params.life):
							mark_dead(i)
				EnemyTable.Beh.ROCKET:
					_rocket(i, bdt)
				EnemyTable.Beh.BOMBER:
					_bomber(i, bdt)
				EnemyTable.Beh.BEAMER:
					if t.mode[i] == EnemyTable.Mode.MOVE:
						_keep_distance(i, bdt)
					else:
						_hold(i, bdt)
					_beamer(i, bdt)
				EnemyTable.Beh.PULSER:
					if t.mode[i] == EnemyTable.Mode.MOVE:
						_keep_distance(i, bdt)
					else:
						_hold(i, bdt)
					_pulser(i, bdt)
				EnemyTable.Beh.PUMP:
					_pump(i, bdt)
				EnemyTable.Beh.SNIPER:
					_telescope(i, bdt)
				EnemyTable.Beh.SHIELD:
					t.fire_t[i] = maxf(0.0, t.fire_t[i] - bdt)
					_steer_to(i, state.enemy_aim, t.speed[i], t.accel[i], bdt)
					_turn_toward(i, (state.ship_pos - pos[i]).angle(), t.turn[i], bdt)
				EnemyTable.Beh.RULER:
					_ruler(i, bdt)
				EnemyTable.Beh.CLOCK:
					_chase(i, bdt)
					_clock(i, bdt)
				EnemyTable.Beh.LYNX:
					_lynx(i, bdt)
				EnemyTable.Beh.CROW:
					_crow(i, bdt)
				EnemyTable.Beh.RETICLE:
					_reticle(i, bdt)
				EnemyTable.Beh.TRIANGLE:
					_keep_distance(i, bdt)
					_triangle(i, bdt)
					if t.mode[i] != EnemyTable.Mode.RECOVER and _gun_timer(i, bdt):
						fire_volley(i)
				EnemyTable.Beh.PART:
					# 位置は親が決める。親が倒れたら一緒に消える
					if not self.is_same(t.parent[i], t.parent_id[i]) or t.dead[t.parent[i]] != 0:
						mark_dead(i)
					vel[i] = Vector2.ZERO
				EnemyTable.Beh.PHOENIX:
					_phoenix(i, bdt)
				EnemyTable.Beh.CRAB:
					_crab(i, bdt)
				EnemyTable.Beh.MARLIN:
					_marlin(i, bdt)
				EnemyTable.Beh.AQUARIUS:
					_aquarius(i, bdt)
				EnemyTable.Beh.AURIGA:
					_drive(i, bdt)
					_auriga(i, bdt)
				EnemyTable.Beh.CORONA:
					_chase(i, bdt)
					_corona(i, bdt)
				EnemyTable.Beh.CEPHEUS:
					_cepheus(i, bdt)
				EnemyTable.Beh.SOLDIER:
					_soldier(i, bdt)
				EnemyTable.Beh.AQUILA:
					_drive(i, bdt)
					_aquila(i, bdt)
			if dead[i] != 0:
				continue
			pos[i] += vel[i] * dt
		if _near_body(i, pos[i], r[i] + vel[i].length() * dt, now, body_move):
			field.collide_enemy(i, from)

	projectiles.lab_context = 0

## 行 i の敵が、位置 p から margin 以内に天体があるか（FieldManager.near_body と同じ条件）。
## 前回確かめたときの天体の表面までの距離から、その後に動いた距離と月が動けた距離を引き、
## まだ margin より遠ければ確かめずに false を返す。瞬間移動も、前回の位置からの距離に入る。
func _near_body(i: int, p: Vector2, margin: float, now: float, body_speed: float) -> bool:
	var t := table
	var gap := t.body_gap[i]
	if gap >= 0.0:
		var travelled := p.distance_to(t.body_gap_pos[i]) + (now - t.body_gap_time[i]) * body_speed
		if gap - travelled > margin:
			return false
	gap = field.body_gap(p, 4.0)
	t.body_gap[i] = maxf(gap, 0.0)
	t.body_gap_pos[i] = p
	t.body_gap_time[i] = now
	return gap < margin

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
		projectiles.fire_enemy(i, base + (float(k) / maxi(1, n - 1) - 0.5) * spread, p.bullet_speed, &"bullet")

func _steer_to(i: int, target: Vector2, speed: float, accel: float, dt: float) -> void:
	var d := target - table.pos[i]
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var k := minf(1.0, accel * dt)
	table.vel[i] += (d / dist * speed - table.vel[i]) * k

func _turn_toward(i: int, target: float, rate: float, dt: float) -> void:
	table.facing[i] += clampf(Geom.angle_diff(target, table.facing[i]), -rate * dt, rate * dt)

## 移動中の向き：進む向きと機体への向きを config.enemy_face_move の割合で混ぜた向きへ回す。
func _turn_moving(i: int, rate: float, dt: float) -> void:
	var t := table
	var v := t.vel[i]
	var spd := maxf(t.speed[i], 1.0)
	var w := cfg.enemy_face_move * minf(1.0, v.length() / spd)
	var face := v.normalized() * w + (state.enemy_aim - t.pos[i]).normalized() * (1.0 - w)
	if face.length_squared() > 0.0025:
		_turn_toward(i, face.angle(), rate, dt)

## 追跡：18秒の周期で「接近」と「広域移動」を切り替える（仕様書 11.5）。
func _chase(i: int, dt: float) -> void:
	var t := table
	var aim := _aim
	var a := t.age[i]
	var cycle_len := cfg.enemy_approach_cycle
	var blend := cfg.enemy_approach_blend
	var cycle := fmod(a + t.roam_phase[i], cycle_len)
	var roam := clampf(minf((cycle - cfg.enemy_approach_time) / blend, (cycle_len - cycle) / blend), 0.0, 1.0)
	var target := aim
	if roam > 0.0:
		var ang := t.roam_angle[i] + a * cfg.enemy_roam_turn
		var ux := cos(ang)
		var uy := sin(ang)
		var edge := t.roam_radius[i] / maxf(absf(ux), absf(uy))
		target = aim + (Vector2(_vc.x + ux * edge * _vh.x, _vc.y + uy * edge * _vh.y) - aim) * roam
	_move_to(i, target, t.speed[i], t.accel[i], t.turn[i], dt)

## 狙った位置へ速さ speed で向かい（加速 accel）、進む向きと機体への向きを混ぜた向きへ毎秒 turn まで回る。
## 追跡と距離を保つ動きの共通部分（よく呼ぶので、関数をまとめて呼び出しを減らす）。
func _move_to(i: int, target: Vector2, speed: float, accel: float, turn: float, dt: float) -> void:
	var t := table
	var from := t.pos[i]
	var d := target - from
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var v := t.vel[i]
	v += (d * (speed / dist) - v) * minf(1.0, accel * dt)
	t.vel[i] = v
	var w := _face_move * minf(1.0, v.length() / maxf(t.speed[i], 1.0))
	var face := v.normalized() * w + (_aim - from).normalized() * (1.0 - w)
	if face.length_squared() > 0.0025:
		var f := t.facing[i]
		var turn_max := turn * dt
		t.facing[i] = f + clampf(wrapf(face.angle() - f, -PI, PI), -turn_max, turn_max)

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
	var a := bud_angle(i)
	t.buds[i] += 1
	spawn_later(def_of(&"splitling"), t.level[i], t.pos[i] + Vector2.from_angle(a) * t.r[i] * 1.2,
		{"facing": a, "vel": Vector2.from_angle(a) * 160.0, "hit_cd": 0.2})
	state.emit(&"bud", {"pos": t.pos[i] + Vector2.from_angle(a) * t.r[i], "color": t.color[i]})

## 分裂する雑魚が次の分裂体を生む向き（育っていく芽の位置。描画も同じ向きを使う）。
func bud_angle(i: int) -> float:
	return table.roam_angle[i] + float(table.buds[i]) * 2.399963

## 射撃型・ミサイル艇：機体の周りの keep の距離を保ち、回り込む。
func _keep_distance(i: int, dt: float) -> void:
	var t := table
	var aim := _aim
	var d := t.pos[i] - aim
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var u := d / dist
	var side := 1.0 if t.id[i] % 2 == 1 else -1.0
	var def := t.def[i]
	var keep: float = def.params.keep
	var target := aim + u * keep + Vector2(-u.y, u.x) * 200.0 * side
	if t.charge[i] > 0.0:
		# 撃つ前の予告の間は機体の方を向く
		_steer_to(i, target, t.speed[i], def.accel, dt)
		_turn_toward(i, (aim - t.pos[i]).angle(), 3.0, dt)
	else:
		_move_to(i, target, t.speed[i], def.accel, 3.0, dt)

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

# ── 雑魚と硬めの敵の攻撃（仕様書 11.7） ─────────────────────────────

## 敵のレベルで増えた攻撃のダメージ。
func _attack_dmg(i: int, base: float) -> float:
	return base * (1.0 + 0.25 * (table.level[i] - 1.0))

## 予告や攻撃の間、その場で止まる。
func _hold(i: int, dt: float) -> void:
	table.vel[i] *= maxf(0.0, 1.0 - 8.0 * dt)

## 自分の周りで爆発して消える（倒されたことにはならない）。
func _self_destruct(i: int) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	projectiles.fire_zone(t.pos[i], float(p.blast_radius), 0.0, _attack_dmg(i, float(p.blast_dmg)),
		ProjectileManager.HazardStyle.BLAST, t.color[i])
	mark_dead(i)

## ミサイル：出た向きのまま一直線に飛ぶ。機体に近づくと爆発し、飛ぶ時間が過ぎると消える。
func _rocket(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		var a := (state.enemy_aim - t.pos[i]).angle()
		t.facing[i] = a
		t.vel[i] = Vector2.from_angle(a) * t.speed[i]
		t.mode[i] = EnemyTable.Mode.DASH
		t.timer[i] = float(p.life)
		return
	t.timer[i] -= dt
	if t.pos[i].distance_squared_to(state.ship_pos) <= float(p.fuse) * float(p.fuse):
		_self_destruct(i)
	elif t.timer[i] <= 0.0:
		mark_dead(i)

## 自爆する雑魚：追ってきて、機体が trigger に入るとカウントダウンに入る。カウントダウンの間も止まらず、
## rush 倍の速さで機体へ詰め寄る。2回明滅し終わると爆発する。明滅し終わる前に倒せば爆発しない。
func _bomber(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		_chase(i, dt)
		if t.pos[i].distance_squared_to(state.ship_pos) <= float(p.trigger) * float(p.trigger):
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.blast_delay)
		return
	_steer_to(i, state.ship_pos, t.speed[i] * float(p.rush), t.accel[i] * 2.0, dt)
	_turn_moving(i, t.turn[i] * 2.0, dt)
	t.timer[i] -= dt
	# 2回明滅する。charge はカウントダウンの進み（0〜1）
	var phase := 1.0 - t.timer[i] / maxf(float(p.blast_delay), 0.001)
	t.charge[i] = clampf(phase, 0.0, 1.0)
	t.flash[i] = 0.05 if fmod(phase * 2.0, 1.0) > 0.75 else 0.0
	if t.timer[i] <= 0.0:
		_self_destruct(i)

## ビームの敵：距離を保ち、間隔ごとに止まって砲口に光を集め、ビームを撃つ。
func _beamer(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		t.fire_t[i] -= dt
		if t.fire_t[i] <= 0.0:
			var a := (state.enemy_aim - t.pos[i]).angle()
			t.facing[i] = a
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.telegraph) + float(p.beam_time)
			if p.get("cross", false):
				# みなみじゅうじ座：十字のレーザー
				projectiles.fire_cross(t.pos[i], a + PI / 4.0, float(p.beam_len), float(p.beam_width),
					float(p.telegraph), float(p.beam_time), _attack_dmg(i, float(p.bullet_dmg)), t.color[i].lightened(0.3))
			else:
				projectiles.fire_beam(t.pos[i] + Vector2.from_angle(a) * t.r[i], a, float(p.beam_len), float(p.beam_width),
					float(p.telegraph), float(p.beam_time), _attack_dmg(i, float(p.bullet_dmg)), t.color[i].lightened(0.3))
		return
	t.timer[i] -= dt
	# charge は砲口に光が集まる進み（0〜1）。撃っている間は 1
	t.charge[i] = clampf(1.0 - (t.timer[i] - float(p.beam_time)) / float(p.telegraph), 0.0, 1.0)
	if t.timer[i] <= 0.0:
		t.mode[i] = EnemyTable.Mode.MOVE
		t.fire_t[i] = float(p.fire_interval)
		t.charge[i] = 0.0

## 波動の敵：距離を保ち、間隔ごとに止まって、1枚の輪か扇を出す。
func _pulser(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.mode[i] == EnemyTable.Mode.MOVE:
		t.fire_t[i] -= dt
		if t.fire_t[i] <= 0.0:
			var a := (state.enemy_aim - t.pos[i]).angle()
			t.facing[i] = a
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.telegraph)
			if int(p.get("layers", 1)) > 1:
				# いるか座：何層もの輪。層ごとに切れ目がずれる
				projectiles.fire_rings(t.pos[i], int(p.layers), float(p.layer_interval), float(p.wave_radius),
					float(p.wave_speed), float(p.wave_width), float(p.telegraph), _attack_dmg(i, float(p.bullet_dmg)),
					a + state.rng.randf_range(-1.0, 1.0), float(p.gap_width), float(p.gap_step) * (1.0 if t.id[i] % 2 == 1 else -1.0),
					t.color[i])
			else:
				projectiles.fire_wave(t.pos[i], a, float(p.wave_arc), float(p.wave_radius), float(p.wave_speed),
					float(p.wave_width), float(p.telegraph), _attack_dmg(i, float(p.bullet_dmg)), 0.0, 0.0, t.color[i])
		return
	t.timer[i] -= dt
	if t.timer[i] <= 0.0:
		t.mode[i] = EnemyTable.Mode.MOVE
		t.fire_t[i] = float(p.fire_interval)

# ── 強敵（仕様書 11.7・敵一覧） ──────────────────────────────────

## 機体が高速か（なぞり中・勢いの間・速い移動）。引き寄せる力は、高速の機体には効かない。
func _ship_fast() -> bool:
	return state.tracing or state.glide or state.ship_vel.length() >= state.stats.max_speed * cfg.ram_speed_ratio

## ポンプ座：機体を追いながら周りの敵を吸い込んで圧縮する（buds が吸い込んだ数）。数に応じて胴体が膨らむ。
## 満タンになると吸い込みを止めて構え（WINDUP）、向きを固定して圧縮弾を一発撃つ。撃ったあとはしぼむ（RECOVER）。
func _pump(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var store_max := int(p.store_max)
	var full := float(t.buds[i]) / float(store_max)
	# 胴体は吸い込んだ数に応じて膨らみ、撃ったあとはしぼむ
	var base_r := t.def[i].radius * (1.25 if t.elite[i] != 0 else 1.0) * cfg.character_scale
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
					float(p.burst_radius), _attack_dmg(i, float(p.bullet_dmg)))
				t.buds[i] = 0
				t.charge[i] = 0.0
				t.vel[i] -= Vector2.from_angle(t.facing[i]) * float(p.shell_speed) * 0.3
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.recover)
		_:
			_hold(i, dt)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE

## ポンプ座が周りの敵を吸い寄せ、口に届いた敵を一定の間隔で吸い込む。吸い込める敵は、上限を持たない雑魚と硬めの敵。
## 吸い寄せられている敵は自分の動きをやめ（knock_t）、自転しながら口へまっすぐ進む。口に近いほど速く、速く回る。
## 吸い込んだ敵は撃破にせずに消し、自転しながら小さくなって口へ飛び込む見た目を描画へ知らせる。
func _pump_suck(i: int, p: Dictionary, dt: float) -> void:
	var t := table
	var reach := float(p.pull_radius)
	var pull := float(p.pull)
	var spin := float(p.pull_spin)
	var mouth := t.pos[i] + Vector2.from_angle(t.facing[i]) * t.r[i] * PUMP_MOUTH
	var bite := t.r[i] + float(p.swallow_reach)
	t.bud_t[i] -= dt
	var rows := PackedInt32Array()
	projectiles.combat.nearby(t.pos[i], reach, rows)
	for j in rows:
		if j == i or t.dead[j] != 0 or t.is_boss[j] != 0 or t.meteor_index[j] >= 0 or t.parent[j] >= 0 \
				or t.landmark[j] != 0:
			continue
		if t.def[j] == null or t.def[j].max_alive > 0 or t.beh[j] == EnemyTable.Beh.PUMP:
			continue
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

## ぼうえんきょう座のサーチライトの光線の数と、光線ごとの届く長さ（敵の id → 長さの並び。帯の右端から左端の順）
const TELE_RAYS := 48
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
		_cast_telescope(i)
		if t.timer[i] <= 0.0:
			t.mode[i] = EnemyTable.Mode.MOVE
		return
	_cast_telescope(i)
	var seen := telescope_sight(i, state.ship_pos)
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		if seen == 2:
			# 溜めの間に岩陰へ逃げられた：取り消して探し直す
			t.mode[i] = EnemyTable.Mode.MOVE
			t.charge[i] = 0.0
			return
		_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), float(p.track_turn), dt)
		t.timer[i] -= dt
		if t.timer[i] <= 0.0:
			var lens := telescope_lens(i)
			var reach := telescope_reach(i, t.facing[i])
			projectiles.fire_beam(lens, t.facing[i], reach, float(p.laser_width), float(p.laser_delay), float(p.laser_time),
				_attack_dmg(i, float(p.bullet_dmg)), Color(1.0, 0.3, 0.25))
			state.emit(&"telescope_fire", {"pos": lens, "angle": t.facing[i], "length": reach, "width": float(p.laser_width)})
			t.charge[i] = 0.0
			t.mode[i] = EnemyTable.Mode.RECOVER
			t.timer[i] = float(p.cooldown)
		return
	if seen == 1:
		_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), float(p.track_turn), dt)
		t.charge[i] = minf(1.0, t.charge[i] + dt / float(p.lock_fill))
	elif seen == 2:
		# 岩陰に隠れた：狙いを外し、探し直す
		t.charge[i] = 0.0
		_search_telescope(i, dt)
	else:
		_search_telescope(i, dt)
		t.charge[i] = maxf(0.0, t.charge[i] - dt * float(p.lock_decay))
	if t.charge[i] >= 1.0:
		t.mode[i] = EnemyTable.Mode.WINDUP
		t.timer[i] = float(p.laser_charge)
		state.emit(&"telescope_charge", {"pos": telescope_lens(i)})

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
func _cast_telescope(i: int) -> void:
	var t := table
	var length := float(t.def[i].params.band_len)
	var lens := telescope_lens(i)
	var half := telescope_half(i)
	# 遮るもの：帯の届く範囲の隕石・鉄のがれきと、惑星・月
	var blockers: Array = []
	var rows := PackedInt32Array()
	projectiles.combat.nearby(lens, length, rows)
	for j in rows:
		if t.meteor_index[j] >= 0 and t.dead[j] == 0:
			blockers.append([t.pos[j], t.r[j]])
	for b in field.bodies:
		if b.pos.distance_to(lens) < length + b.r:
			blockers.append([b.pos, b.r])
	var rays := PackedFloat32Array()
	rays.resize(TELE_RAYS)
	for n in TELE_RAYS:
		var v := Vector2.from_angle(t.facing[i] - half + 2.0 * half * n / float(TELE_RAYS - 1))
		var reach := length
		for blk in blockers:
			var c: Vector2 = blk[0] - lens
			var r: float = blk[1]
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

## じょうぎ座：1体の定規として現れ、split_delay たつと二つに分かれる（buds が左右の印 1・-1。0 は分かれる前）。
## 2体は、機体の方へ向かう縦か横の軸（facing）をそろえ、機体を左右から挟む位置へ展開する（DASH）。
## 照射の向きを予告し（WINDUP、charge が予告の進み）、それぞれ長いビームを出し続ける（RECOVER）。ビームは発射元に
## つながり、機体の移動を止める壁になる。照射が終わると、また機体を挟む位置へ展開し直す。倒した個体のビームは消える。
func _ruler(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.buds[i] == 0:
		_keep_distance(i, dt)
		if t.age[i] >= float(p.split_delay):
			_split_ruler(i)
		return
	var d := Vector2.from_angle(t.facing[i])
	t.timer[i] -= dt
	match t.mode[i]:
		EnemyTable.Mode.DASH:
			var n := Vector2(-d.y, d.x)
			var goal := state.ship_pos + n * float(t.buds[i]) * float(p.half_gap) - d * float(p.emit_back)
			_steer_to(i, goal, float(p.deploy_speed), 6.0, dt)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.telegraph)
		EnemyTable.Mode.WINDUP:
			_hold(i, dt)
			t.charge[i] = 1.0 - maxf(0.0, t.timer[i]) / float(p.telegraph)
			if t.timer[i] <= 0.0:
				var h := projectiles.fire_wall(t.pos[i] + d * t.r[i], t.facing[i], float(p.beam_len), float(p.beam_width), 0.0,
					float(p.beam_time), _attack_dmg(i, float(p.bullet_dmg)), t.color[i])
				projectiles.hazard_style[h] = ProjectileManager.HazardStyle.RAY
				projectiles.hazard_block[h] = 1
				projectiles.attach_hazard(h, i)
				t.links[i] = PackedInt32Array([h])
				t.charge[i] = 0.0
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.beam_time)
		EnemyTable.Mode.RECOVER:
			_hold(i, dt)
			for h in t.links[i]:
				if projectiles.owns_hazard(h, i, t.id[i]):
					projectiles.move_hazard(h, t.pos[i] + d * t.r[i], t.facing[i])
			if t.timer[i] <= 0.0:
				for h in t.links[i]:
					if projectiles.owns_hazard(h, i, t.id[i]):
						projectiles.release_hazard(h)
				t.links[i] = PackedInt32Array()
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = float(p.deploy_time)

## じょうぎ座（行 i）が二つに分かれる。機体への向きの縦横の大きい方を照射の軸にし、もう1体を同じ位置に出して展開を始める。
func _split_ruler(i: int) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var rel := state.ship_pos - t.pos[i]
	var d := Vector2(signf(rel.x), 0.0) if absf(rel.x) > absf(rel.y) else Vector2(0.0, signf(rel.y))
	if d == Vector2.ZERO:
		d = Vector2.DOWN
	var halves := [i, spawn(t.def[i], t.level[i], t.pos[i], {"facing": d.angle(), "elite": t.elite[i] != 0})]
	for k in 2:
		var j: int = halves[k]
		t.buds[j] = 1 if k == 0 else -1
		t.facing[j] = d.angle()
		t.mode[j] = EnemyTable.Mode.DASH
		t.timer[j] = float(p.deploy_time)
		t.vel[j] = Vector2(-d.y, d.x) * float(t.buds[j]) * float(p.deploy_speed) * 0.6
	state.emit(&"ruler_split", {"pos": t.pos[i], "angle": d.angle(), "color": t.color[i]})

## とけい座：長針と短針が刃として回り続ける。針は付いて動く残る線で、速さが違う。
func _clock(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var links := t.links[i]
	# 針が消されていたら（ボスの撃破など）作り直す
	if not links.is_empty() and not (projectiles.owns_hazard(links[0], i, t.id[i]) and projectiles.owns_hazard(links[1], i, t.id[i])):
		links = PackedInt32Array()
	if links.is_empty():
		var dmg := _attack_dmg(i, float(p.bullet_dmg))
		for k in 2:
			var length := float(p.hand_long) if k == 0 else float(p.hand_short)
			var h := projectiles.fire_wall(t.pos[i], 0.0, length, float(p.hand_width), float(p.telegraph), 1e9, dmg, t.color[i])
			projectiles.attach_hazard(h, i)
			links.append(h)
		t.links[i] = links
	t.spin[i] += dt
	var a0 := t.spin[i] * float(p.long_speed)
	var a1 := t.spin[i] * float(p.short_speed) + PI
	projectiles.move_hazard(links[0], t.pos[i], a0)
	projectiles.move_hazard(links[1], t.pos[i], a1)

## やまねこ座：距離を保ち、間隔ごとに前足を構えて（charge が構えの進み）、片側1組の斬撃を左右交互に飛ばし続ける
## （buds が撃った数）。斬撃は真ん中の少し先から外側へ伸び、外側で本体の方へ反り上がる。撃ったときの機体の向きへ
## 形を保って直進し、追尾しない。内側の端を左右交互によけて真ん中を抜けさせ、外側からの回り込みを難しくする。
func _lynx(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	# 遠くから撃つが、どこから撃っているか見えるように、本体は画面の中に収まる位置を保つ
	var d := t.pos[i] - _aim
	var u := d / maxf(d.length(), 1.0)
	var room := _vh - Vector2.ONE * (t.r[i] + 40.0)
	var goal := (_aim + u * float(p.keep)).clamp(_vc - room, _vc + room)
	_steer_to(i, goal, t.speed[i], t.accel[i], dt)
	_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i], dt)
	if _gun_timer(i, dt):
		var side := lynx_side(i)
		t.buds[i] += 1
		var a := (state.ship_pos - t.pos[i]).angle()
		projectiles.fire_slash(t.pos[i] + Vector2.from_angle(a) * t.r[i], a, float(p.slash_speed), float(p.slash_size),
			float(p.slash_range), _attack_dmg(i, float(p.bullet_dmg)), side)

## やまねこ座が次に斬撃を伸ばす側（1 か -1。構えの見た目にも使う）。
func lynx_side(i: int) -> float:
	return 1.0 if table.buds[i] % 2 == 0 else -1.0

## からす座：群れで隊列を組み、機体を追わずに一直線に戦場を横断する（向きは出たときに _spawn_flock が決める）。
## 経験値の回収は PickupManager が1羽ずつ行う（carry が運んでいる量）。
## 画面の外で exit_margin より離れ、さらに離れていくと、運んでいる経験値ごと退場する（撃破にはならない）。
func _crow(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var rel := t.pos[i] - _vc
	t.vel[i] = Vector2.from_angle(t.facing[i]) * t.speed[i]
	var margin := float(p.exit_margin)
	if (absf(rel.x) > _vh.x + margin or absf(rel.y) > _vh.y + margin) and rel.dot(t.vel[i]) > 0.0:
		mark_dead(i)

## レチクル座：ぼうえんきょう座に付き従う支援機。いちばん近いぼうえんきょう座のそばへ動き、そばにいる間（follow_reach 以内）、
## ぼうえんきょう座と機体の間で視線を遮っている小隕石（半径 small_r 以下）を探す。見つけたら照準を出して予告し（WINDUP、
## 狙う岩は target）、aim_time ののち本体からビームを撃って壊す。機体への直接攻撃や、支援と関係のない岩は撃たない。
## 支援先がいなくなると退却し（DASH）、画面の外で exit_margin より離れると消える（撃破にはならない）。
func _reticle(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var tel := _nearest_telescope(t.pos[i])
	if tel < 0:
		t.mode[i] = EnemyTable.Mode.DASH
		t.target[i] = -1
		var away := (t.pos[i] - state.ship_pos).normalized()
		_steer_to(i, t.pos[i] + away * 400.0, float(p.retreat_speed), t.accel[i], dt)
		_turn_toward(i, away.angle(), t.turn[i], dt)
		var rel := t.pos[i] - _vc
		var margin := float(p.exit_margin)
		if (absf(rel.x) > _vh.x + margin or absf(rel.y) > _vh.y + margin) and rel.dot(t.vel[i]) > 0.0:
			mark_dead(i)
		return
	if t.mode[i] == EnemyTable.Mode.DASH:
		t.mode[i] = EnemyTable.Mode.MOVE
	# ぼうえんきょう座の横に付き従う
	var tf := Vector2.from_angle(t.facing[tel])
	var side := 1.0 if t.id[i] % 2 == 1 else -1.0
	var goal := t.pos[tel] + Vector2(-tf.y, tf.x) * side * float(p.follow_gap) - tf * 30.0
	_steer_to(i, goal, t.speed[i], t.accel[i], dt)
	var near := t.pos[i].distance_to(t.pos[tel]) <= float(p.follow_reach)
	t.fire_t[i] -= dt
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		var rock := t.target[i]
		if not near or not self.is_same(rock, t.target_id[i]) or t.dead[rock] != 0:
			t.mode[i] = EnemyTable.Mode.MOVE
			t.target[i] = -1
			t.charge[i] = 0.0
			return
		_turn_toward(i, (t.pos[rock] - t.pos[i]).angle(), t.turn[i] * 3.0, dt)
		t.timer[i] -= dt
		t.charge[i] = 1.0 - maxf(0.0, t.timer[i]) / float(p.aim_time)
		if t.timer[i] <= 0.0:
			var from := t.pos[i] + Vector2.from_angle(t.facing[i]) * t.r[i]
			state.emit(&"beam", {"from": from, "to": t.pos[rock], "width": 10.0, "life": 0.25, "color": t.color[i].lightened(0.3)})
			state.emit(&"rock_break", {"pos": t.pos[rock], "r": t.r[rock], "meteor_index": t.meteor_index[rock],
				"facing": t.facing[rock], "dir": (t.pos[rock] - from).normalized(), "color": Color("#a08a78")})
			mark_dead(rock)
			t.mode[i] = EnemyTable.Mode.MOVE
			t.target[i] = -1
			t.charge[i] = 0.0
			t.fire_t[i] = float(p.break_interval)
		return
	_turn_toward(i, (t.pos[tel] - t.pos[i]).angle() if not near else t.facing[tel], t.turn[i], dt)
	if near and t.fire_t[i] <= 0.0:
		var rock := _blocking_rock(tel, float(p.small_r))
		if rock >= 0:
			t.target[i] = rock
			t.target_id[i] = t.id[rock]
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.aim_time)

## 位置 at にいちばん近い、生きているぼうえんきょう座の行（いなければ -1）。
func _nearest_telescope(at: Vector2) -> int:
	var t := table
	var best := -1
	var best_d := INF
	for j in beh_rows[EnemyTable.Beh.SNIPER]:
		if t.dead[j] != 0:
			continue
		var d := at.distance_squared_to(t.pos[j])
		if d < best_d:
			best_d = d
			best = j
	return best

## ぼうえんきょう座（行 tel）のレンズと機体の間で、視線を遮っている小隕石（半径 small_r 以下）のうち、レンズにいちばん近いもの。
## 機体がサーチライトの届く距離の外にいるときは探さない。
func _blocking_rock(tel: int, small_r: float) -> int:
	var t := table
	var lens := telescope_lens(tel)
	var ship := state.ship_pos
	var length := lens.distance_to(ship)
	if length > float(t.def[tel].params.band_len):
		return -1
	var rows := PackedInt32Array()
	projectiles.combat.nearby((lens + ship) * 0.5, length * 0.5 + small_r, rows)
	var best := -1
	var best_d := INF
	for j in rows:
		if t.meteor_index[j] < 0 or t.dead[j] != 0 or t.r[j] > small_r:
			continue
		var c := t.pos[j]
		if Geometry2D.get_closest_point_to_segment(c, lens, ship).distance_to(c) > t.r[j] + cfg.ship_radius:
			continue
		var d := lens.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = j
	return best

## みなみのさんかく座：核の周りに3つの星を出す。
func _spawn_triangle_stars(i: int) -> void:
	var star := def_of(&"triangle_star")
	for k in 3:
		spawn_part(i, star, table.pos[i] + Vector2.from_angle(TAU * k / 3.0) * float(table.def[i].params.span))

## みなみのさんかく座：3つの星を核の周りでゆっくり回し、星の間に光の膜（触れると被弾する線）を張る。
## 星が1つでも欠けると膜が消え（mode が RECOVER）、中の核を倒せる。
func _triangle(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.facing[i] += float(p.spin) * dt
	var parts := t.parts[i]
	var verts := PackedVector2Array()
	for k in range(0, parts.size(), 2):
		var j := parts[k]
		var a := t.facing[i] + TAU * (k / 2) / 3.0
		var at := t.pos[i] + Vector2.from_angle(a) * float(p.span)
		if self.is_same(j, parts[k + 1]) and t.dead[j] == 0:
			t.pos[j] = at
		verts.append(at)
	var links := t.links[i]
	if t.mode[i] != EnemyTable.Mode.RECOVER and parts_alive(i) < 3:
		t.mode[i] = EnemyTable.Mode.RECOVER
		for h in links:
			projectiles.release_hazard(h)
		t.links[i] = PackedInt32Array()
		t.charge[i] = 0.0
		state.emit(&"membrane_break", {"points": verts, "color": t.color[i]})
		return
	if t.mode[i] == EnemyTable.Mode.RECOVER or verts.size() < 3:
		return
	if links.is_empty():
		for k in 3:
			var h := projectiles.fire_wall(verts[k], 0.0, 0.0, float(p.wall_width), float(p.telegraph), 1e9,
				_attack_dmg(i, float(p.bullet_dmg)), t.color[i])
			projectiles.attach_hazard(h, i)
			links.append(h)
		t.links[i] = links
	for k in 3:
		var a := verts[k]
		var b := verts[(k + 1) % 3]
		projectiles.move_hazard(links[k], a, (b - a).angle(), a.distance_to(b))

## ほうおう座：機体の周りを大きく旋回しながら飛び、飛んだ跡に炎（残る線）を残す。
func _phoenix(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var d := t.pos[i] - state.enemy_aim
	var ring := float(p.orbit) * (0.75 + 0.25 * sin(t.age[i] * 0.7 + float(t.id[i])))
	var side := Vector2(-d.y, d.x).normalized()
	var target := state.enemy_aim + d.normalized() * ring + side * 260.0
	_steer_to(i, target, t.speed[i], t.accel[i], dt)
	_turn_moving(i, t.turn[i], dt)
	t.fire_t[i] -= dt
	if t.fire_t[i] <= 0.0:
		t.fire_t[i] = float(p.trail_step)
		var back := t.pos[i] - t.vel[i] * float(p.trail_step)
		var seg := t.pos[i] - back
		if seg.length() > 1.0:
			projectiles.fire_wall(back, seg.angle(), seg.length(), float(p.trail_width), 0.0, float(p.trail_time),
				_attack_dmg(i, float(p.bullet_dmg)), Color("#ff8a3c"))

## かに座：近づいてきて、機体が届く距離に入るとハサミを開き（構え）、前方を挟む。
## 挟んだ直後はハサミが開いたままで（mode が RECOVER）、正面からでも倒せる。
func _crab(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_steer_to(i, state.enemy_aim, t.speed[i], t.accel[i], dt)
			_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i], dt)
			t.fire_t[i] -= dt
			var reach := float(p.reach) + t.r[i]
			if t.fire_t[i] <= 0.0 and t.pos[i].distance_squared_to(state.ship_pos) < reach * reach * 1.6:
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.telegraph)
		EnemyTable.Mode.WINDUP:
			_hold(i, dt)
			_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i] * 0.5, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				var at := t.pos[i] + Vector2.from_angle(t.facing[i]) * (t.r[i] + float(p.reach) * 0.5)
				projectiles.fire_zone(at, float(p.reach) * 0.6, 0.0, _attack_dmg(i, float(p.bullet_dmg)),
					ProjectileManager.HazardStyle.PLAIN, t.color[i].lightened(0.3))
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.open_time)
		_:
			_hold(i, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE
				t.fire_t[i] = float(p.fire_interval)

## かじき座：距離を保ち、光って予告してから、機体の方へ高速で泳ぎ抜ける。泳いでいる間、左右へ扇状にしぶきを撒く。
func _marlin(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_keep_distance(i, dt)
			if _gun_timer(i, dt):
				var a := (state.enemy_aim - t.pos[i]).angle()
				t.facing[i] = a
				t.vel[i] = Vector2.from_angle(a) * float(p.dash_speed)
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = float(p.dash_time)
				t.bud_t[i] = 0.0
		EnemyTable.Mode.DASH:
			t.timer[i] -= dt
			t.bud_t[i] -= dt
			if t.bud_t[i] <= 0.0:
				t.bud_t[i] = float(p.spray_step)
				var n := int(p.spray)
				for side: float in [-1.0, 1.0]:
					for k in n:
						var a := t.facing[i] + side * PI / 2.0 + (float(k) / maxf(n - 1, 1) - 0.5) * float(p.spread)
						projectiles.fire_enemy(i, a, float(p.bullet_speed), &"bullet")
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = 0.8
		_:
			_hold(i, dt)
			t.timer[i] -= dt
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE

## みずがめ座：遠くに留まり、水瓶を傾けて（予告）から、機体の方へ太い水流を流し続ける。
## 水流は、中の敵と遅い機体を流れの向きへ押し流す（ダメージはない）。mode が DASH の間が水流。
func _aquarius(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			_keep_distance(i, dt)
			if _gun_timer(i, dt):
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = float(p.pour_time)
		_:
			_hold(i, dt)
			_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), float(p.pour_turn), dt)
			t.timer[i] -= dt
			_pour(i, dt)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.MOVE

## みずがめ座の水流で、帯の中の敵と遅い機体を押し流す。
func _pour(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var u := Vector2.from_angle(t.facing[i])
	var from := t.pos[i] + u * t.r[i]
	var length := float(p.stream_len)
	var half := float(p.stream_width) * 0.5
	var push := u * float(p.push) * dt
	var rel := state.ship_pos - from
	var along := rel.dot(u)
	if along > 0.0 and along < length and absf(rel.cross(u)) < half and not _ship_fast():
		state.ship_vel += push
	var rows := PackedInt32Array()
	var seen := {}
	var step := half * 1.6
	var d := 0.0
	while d < length:
		rows.clear()
		projectiles.combat.nearby(from + u * d, half, rows)
		for j in rows:
			if j != i and not seen.has(j) and t.is_boss[j] == 0 and t.meteor_index[j] < 0 and t.dead[j] == 0 \
					and t.parent[j] < 0:
				seen[j] = true
				t.vel[j] += push
		d += step

## 大きく旋回しながら一定の速さで走る（ぎょしゃ座・わし座）。向きは turn の速さでしか変わらない。
func _drive(i: int, dt: float) -> void:
	var t := table
	_turn_toward(i, (state.enemy_aim - t.pos[i]).angle(), t.turn[i], dt)
	t.vel[i] = Vector2.from_angle(t.facing[i]) * t.speed[i]

## ぎょしゃ座：王の戦車。走った跡に、左右の車輪の跡が燃えて残る。
func _auriga(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.fire_t[i] -= dt
	if t.fire_t[i] > 0.0:
		return
	t.fire_t[i] = float(p.trail_step)
	var seg := t.vel[i] * float(p.trail_step)
	var side := Vector2.from_angle(t.facing[i] + PI / 2.0) * float(p.wheel_gap)
	for s: float in [-1.0, 1.0]:
		var from := t.pos[i] - seg + side * s
		projectiles.fire_wall(from, seg.angle(), seg.length(), float(p.trail_width), 0.0, float(p.trail_time),
			_attack_dmg(i, float(p.bullet_dmg)), Color("#ff8a3c"))

## みなみのかんむり座：周りを小さな星が輪になって回る。周期的に輪を外へ広げて押し出し、少しすると戻る。
## 輪が広がっている間（mode が DASH）、輪の星に触れた機体は外へ押し出される。
func _corona(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.facing[i] += float(p.spin) * dt
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			t.fire_t[i] -= dt
			t.timer[i] = maxf(0.0, t.timer[i] - dt / float(p.expand_time))
			if t.fire_t[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.DASH
				t.fire_t[i] = float(p.fire_interval)
		_:
			t.timer[i] += dt / float(p.expand_time)
			if t.timer[i] >= 1.0 + float(p.hold_time) / float(p.expand_time):
				t.mode[i] = EnemyTable.Mode.MOVE
	var ring := float(p.ring) * (1.0 + (float(p.expand) - 1.0) * smoothstep(0.0, 1.0, minf(t.timer[i], 1.0)))
	var parts := t.parts[i]
	var n := parts.size() / 2
	for k in n:
		var j := parts[k * 2]
		if not self.is_same(j, parts[k * 2 + 1]) or t.dead[j] != 0:
			continue
		t.pos[j] = t.pos[i] + Vector2.from_angle(t.facing[i] + TAU * k / float(n)) * ring
		if t.mode[i] == EnemyTable.Mode.DASH:
			var d := state.ship_pos - t.pos[j]
			var reach := t.r[j] + cfg.ship_radius
			if d.length_squared() < reach * reach:
				var out := (state.ship_pos - t.pos[i]).normalized()
				state.ship_vel += out * float(p.push) * dt

## ケフェウス座の隊列の兵の数（段階ごと）。3体は横一列、5体は扇形、7体は千鳥の二重隊列（前列4体・後列3体）
const CEPHEUS_TIERS := [3, 5, 7]

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
						var j := spawn(def_of(&"cepheus_soldier"), t.level[i], cepheus_slot(i, k)[0], {"facing": cepheus_slot(i, k)[1]})
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
			if t.timer[i] <= 0.0:
				_cepheus_volley(i)
				t.timer[i] = float(p.fire_interval) * (0.5 if t.buds[i] == 3 else 1.0)
			if t.fire_t[i] <= 0.0:
				_cepheus_reform(i)

## ケフェウス座（行 i）の兵の行の一覧（倒れた兵は含めない）。
func _soldiers_of(i: int) -> PackedInt32Array:
	var t := table
	var out := PackedInt32Array()
	for j in beh_rows[EnemyTable.Beh.SOLDIER]:
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

## 王の号令で兵が撃つ。7体の隊列は前列（0〜3番）と後列（4〜6番）が交互に撃つ（bud_t が号令の回数）。
func _cepheus_volley(i: int) -> void:
	var t := table
	var staggered := t.buds[i] == 3
	var back := int(t.bud_t[i]) % 2 == 1
	t.bud_t[i] += 1.0
	for j in _soldiers_of(i):
		if t.mode[j] != EnemyTable.Mode.MOVE:
			continue
		if staggered and (t.buds[j] >= 4) != back:
			continue
		var sp: Dictionary = t.def[j].params
		projectiles.fire_bolt(t.pos[j] + Vector2.from_angle(t.facing[j]) * t.r[j], t.facing[j], float(sp.bolt_speed),
			_attack_dmg(j, float(sp.bullet_dmg)))

## ケフェウス座の兵：王が決めた隊列の位置へ動き（DASH）、着いたら止まって撃つ向きを向く（MOVE。撃つのは王の号令）。
## 王が倒れると（RECOVER）、機体への攻撃をやめ、近くの兵へ向き直って撃ち合い、mutiny の時間が過ぎると崩れて倒れる。
## 王がいないまま置かれた兵は、すぐに崩れる。
func _soldier(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var king := t.target[i]
	if t.mode[i] == EnemyTable.Mode.RECOVER:
		_hold(i, dt)
		t.timer[i] -= dt
		t.fire_t[i] -= dt
		var foe := _nearest_soldier(i)
		if foe >= 0:
			_turn_toward(i, (t.pos[foe] - t.pos[i]).angle(), t.turn[i], dt)
			if t.fire_t[i] <= 0.0:
				t.fire_t[i] = float(p.mutiny_shot)
				state.emit(&"beam", {"from": t.pos[i], "to": t.pos[foe], "width": 4.0, "life": 0.12, "color": t.color[i].lightened(0.3)})
				projectiles.combat.damage_enemy(foe, t.max_hp[foe] * 0.35, {"cause": &"collapse", "no_crit": true})
		if t.timer[i] <= 0.0 and t.dead[i] == 0:
			projectiles.combat.kill_enemy(i, {"cause": &"collapse"})
		return
	if not self.is_same(king, t.target_id[i]) or t.dead[king] != 0:
		_start_mutiny(i, 0.4)
		return
	var slot := cepheus_slot(king, t.buds[i])
	if t.mode[i] == EnemyTable.Mode.DASH:
		var goal: Vector2 = slot[0]
		_steer_to(i, goal, t.speed[i], t.accel[i], dt)
		_turn_toward(i, (goal - t.pos[i]).angle(), t.turn[i], dt)
		if t.pos[i].distance_to(goal) < 8.0:
			t.pos[i] = goal
			t.vel[i] = Vector2.ZERO
			t.facing[i] = slot[1]
			t.mode[i] = EnemyTable.Mode.MOVE
		return
	t.vel[i] = Vector2.ZERO
	t.pos[i] = slot[0]
	_turn_toward(i, slot[1], t.turn[i], dt)

## 兵（行 i）の崩壊を始める。seconds ののちに崩れて倒れる。
func _start_mutiny(i: int, seconds: float) -> void:
	var t := table
	t.mode[i] = EnemyTable.Mode.RECOVER
	t.timer[i] = seconds
	t.fire_t[i] = state.rng.randf() * float(t.def[i].params.mutiny_shot)

## 兵（行 i）にいちばん近い、ほかの兵（いなければ -1）。
func _nearest_soldier(i: int) -> int:
	var t := table
	var best := -1
	var best_d := INF
	for j in beh_rows[EnemyTable.Beh.SOLDIER]:
		if j == i or t.dead[j] != 0:
			continue
		var d := t.pos[i].distance_squared_to(t.pos[j])
		if d < best_d:
			best_d = d
			best = j
	return best

## わし座：雷を運ぶ鷲。大きく旋回しながら飛び、通り道に沿って雷を落とす。
func _aquila(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.fire_t[i] -= dt
	if t.fire_t[i] > 0.0:
		return
	t.fire_t[i] = float(p.drop_step)
	projectiles.fire_zone(t.pos[i], float(p.blast_radius), float(p.blast_delay), _attack_dmg(i, float(p.bullet_dmg)),
		ProjectileManager.HazardStyle.LIGHTNING, Color("#ffe46b"))

## 撃破されたときの処理。分裂する雑魚は分かれ、誘爆する雑魚は少し遅れて爆発する。atk は機体の攻撃力。
## ポンプ座は、圧縮していた敵を一気に解放する。飛び散る敵と破裂は機体の側の攻撃で、蓄積が多いほど強い。
func on_enemy_death(i: int, atk: float) -> void:
	var t := table
	var dp: Dictionary = t.def[i].params if t.def[i] != null else {}
	var prior_context := projectiles.lab_context
	if projectiles.director != null:
		projectiles.lab_context = projectiles.director.passive(str(t.id[i]), i, t.id[i])
	if t.beh[i] == EnemyTable.Beh.SNIPER:
		_tele_rays.erase(t.id[i])
	if t.beh[i] == EnemyTable.Beh.CEPHEUS:
		# 王が倒れた：召喚と兵の攻撃が止まり、残った兵は撃ち合って崩れる
		for j in beh_rows[EnemyTable.Beh.SOLDIER]:
			if t.dead[j] == 0 and t.target[j] == i and t.target_id[j] == t.id[i] and t.mode[j] != EnemyTable.Mode.RECOVER:
				_start_mutiny(j, float(dp.mutiny_time) + state.rng.randf() * 0.6)
	if t.beh[i] == EnemyTable.Beh.PUMP:
		var full := float(t.buds[i]) / float(dp.store_max)
		projectiles.burst_debris(t.pos[i], int(dp.release_base) + int(float(dp.release_per) * float(t.buds[i])),
			float(dp.release_speed), atk * float(dp.release_dmg), t.color[i].lightened(0.3), t.id[i])
		projectiles.combat.explode(t.pos[i], float(dp.release_radius) * (1.0 + full), atk * float(dp.release_dmg),
			{"cause": &"pump_burst", "no_crit": true, "color": t.color[i].lightened(0.4), "life": 0.35, "knock": 500.0 + 400.0 * full})
	if dp.has("chain_power"):
		projectiles.fire_zone(t.pos[i], float(dp.blast_radius), float(dp.blast_delay), _attack_dmg(i, float(dp.blast_dmg)),
			ProjectileManager.HazardStyle.BLAST, t.color[i], atk * float(dp.chain_power))
	projectiles.lab_context = prior_context
	if t.type[i] != &"splitter":
		return
	var p: Dictionary = t.def[i].params
	if int(p.get("death_split", 0)) <= 0:
		return
	var n := maxi(1, int(p.get("death_split", 2)) + state.rng.randi_range(0, int(p.get("split_extra", 0))))
	var facing := t.facing[i]
	for k in n:
		var a := facing + PI / 2.0 + TAU * float(k) / float(n) if n > 2 else facing + (1.0 if k == 1 else -1.0) * PI / 2.0
		spawn_later(def_of(&"splitling"), t.level[i], t.pos[i] + Vector2.from_angle(a) * t.r[i],
			{"facing": a, "vel": Vector2.from_angle(a) * float(p.get("split_speed", 200.0)), "hit_cd": 0.35,
			"guard": float(p.get("split_guard", 0.0)), "knock": float(p.get("split_guard", 0.0))})

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
			if bosses != null and table.parent[i] >= 0:
				bosses.part_defeated(i)
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
	var steps := surge_steps()
	if state.bonus_t > 0.0:
		# ボーナスステージ：雑魚と硬めの敵だけを多く保つ
		return {"phase": p, "steps": steps, "pop": cfg.bonus_pop * cfg.density_mult,
			"level": lerpf(p.level_from, p.level_to, k) + cfg.surge_level * steps}
	return {"phase": p, "steps": steps,
		"pop": lerpf(p.pop_from, p.pop_to, k) * cfg.density_mult * (1.0 + cfg.surge_pop * steps),
		"level": lerpf(p.level_from, p.level_to, k) + cfg.surge_level * steps}

## 今の時間帯の敵のレベル（ほかの Manager が敵を出すときに使う）。
func spawn_level() -> float:
	return _target().level

## 10:00 以降の強まりの段（仕様書 4.2）。始まる前は0、始まると1から一定時間ごとに増える。
func surge_steps() -> int:
	if state.time < cfg.surge_start:
		return 0
	return 1 + int((state.time - cfg.surge_start) / maxf(1.0, cfg.surge_interval))

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

## 1回の走査で、外周の辺ごとの数・同時に出る数の上限がある種類の数・再配置の範囲の中の数を数え、遠くの敵を再配置する。
## 戻り値は再配置の範囲の中の通常の敵の数。
func _survey() -> int:
	_edge_counts.fill(0)
	_type_counts.clear()
	var vc := state.view_center
	var vh := state.view_half
	var lim := vh * cfg.spawn_recycle_scale + Vector2(200, 200)
	var alive_n := 0
	var center_x := vh.x * 0.45
	var center_y := vh.y * 0.45
	var pos := table.pos
	var dead := table.dead
	var type := table.type
	var defs := table.def
	_far_rows.clear()
	for rows in beh_rows:
		for i in rows:
			if dead[i] != 0:
				continue
			# 上限のある種類だけ数える
			if defs[i].max_alive > 0:
				_type_counts[type[i]] = _type_counts.get(type[i], 0) + 1
			var rel := pos[i] - vc
			if absf(rel.x) > lim.x or absf(rel.y) > lim.y:
				# 部位は親と一緒に動き、からす座は横断して自分で退場するので、離れても再配置しない
				if table.parent[i] < 0 and table.beh[i] != EnemyTable.Beh.CROW:
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
	var type := _pick_type(phase, t.steps)
	var def := def_of(type)
	if def == null:
		return false
	if def.max_alive > 0 and _type_counts.get(type, 0) >= def.max_alive:
		return false
	var elite: bool = def.max_alive == 0 and state.rng.randf() < 0.01 + 0.06 * danger + cfg.surge_elite * t.steps
	var level: float = t.level + danger * cfg.danger_level
	var opts := {"elite": elite, "facing": (state.ship_pos - p).angle()}
	if def.size_var:
		opts.size = def.radius * (0.85 + state.rng.randf() * 0.45)
	spawn(def, level, p, opts)
	if def.max_alive > 0:
		_type_counts[type] = _type_counts.get(type, 0) + 1
	return true

## 時間帯の出現の重みから種類を選ぶ。10:00 以降の強まりの段 steps に応じて、撃つ敵を出やすくする。
func _pick_type(phase: PhaseDef, steps: int) -> StringName:
	var items: Array = []
	var total := 0.0
	for k in phase.mix:
		var w := float(phase.mix[k])
		var def := def_of(StringName(k))
		if def != null and def.max_alive > 0 and state.bonus_t > 0.0:
			continue
		if def != null and def.ranged:
			w *= 1.0 + cfg.surge_ranged * steps
		items.append([StringName(k), w])
	if items.is_empty():
		return phase.mix.keys()[0]
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
	var def := def_of(t.phase.wave_type)
	if def == null:
		return
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

## 制限は実験または明示した採用設定だけで有効。予告へ入る前に取得する。
func _lab_admit(i: int, dt: float) -> bool:
	var d = projectiles.director
	projectiles.lab_context = 0
	if d == null:
		return true
	var def := table.def[i]
	if def == null:
		return true
	var cats: Array = d.categories(def.behavior)
	if cats.is_empty():
		return true
	var owner := str(table.id[i])
	var p := def.params
	var active := table.mode[i] != EnemyTable.Mode.MOVE or not table.links[i].is_empty()
	var due := table.fire_t[i] <= float(p.get("telegraph", 0)) + dt
	if def.behavior == &"dash":
		due = table.pos[i].distance_to(state.enemy_aim) <= float(p.range)
	elif def.behavior == &"bomber":
		due = table.pos[i].distance_to(state.ship_pos) <= float(p.trigger)
	elif def.behavior == &"pump":
		due = table.buds[i] >= int(p.store_max)
	elif def.behavior == &"sniper":
		due = table.charge[i] >= 0.8
		active = table.mode[i] == EnemyTable.Mode.WINDUP or table.mode[i] == EnemyTable.Mode.RECOVER
	elif def.behavior in [&"clock", &"triangle", &"rocket", &"corona"]:
		due = true
	if not active and due:
		var duration := float(p.get("telegraph", p.get("windup", 0))) + float(p.get("dash_time", p.get("beam_time", p.get("blast_delay", 0.2)))) + 0.1
		if not d.request(owner, cats, i, table.id[i], duration, 1.0 if state.view_rect().has_point(table.pos[i]) else 0.0):
			table.charge[i] = 0
			return false
	projectiles.lab_context = d.token(owner)
	return true
