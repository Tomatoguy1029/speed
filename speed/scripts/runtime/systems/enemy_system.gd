## 雑魚の表・行動・出現・補充・再配置（仕様書 11、設計書 6・6.1）。
##
## 敵はノードではなく、敵の表（EnemyTable）の1行として持つ。雑魚の行動は種類ごとの単純なステートマシン
## （例：ダーターの予告 → 突進 → 回復）。隕石とボスも同じ表に入るが、数え方と行動は別に扱う。
## 行動する雑魚は、行動の種類ごとの行番号の一覧（beh_rows）に入り、更新は種類ごとにその一覧だけを回す。
class_name EnemySystem
extends RunSystem

var field: FieldSystem:
	get: return ctx.field
var projectiles: ProjectileSystem:
	get: return ctx.projectiles
var bosses: BossSystem:
	get: return ctx.bosses
## 実験場が複製した定義。未指定時は本番の定義を読む。
var definitions: Dictionary = {}

## 特殊な倒し方（EnemyDef.gate）の名前と種類
const GATE := {&"back": EnemyTable.Gate.BACK, &"membrane": EnemyTable.Gate.MEMBRANE, &"claw": EnemyTable.Gate.CLAW,
	&"guard": EnemyTable.Gate.GUARD, &"solid": EnemyTable.Gate.SOLID,
	&"ghost": EnemyTable.Gate.GHOST, &"immortal": EnemyTable.Gate.IMMORTAL}

## その戦いに出た行動の種類の処理（EnemyTable.beh の値の順）と、名前からの番号
var behaviors: Array[EnemyBehavior] = []
var _behavior_ids: Dictionary = {}
## ほかの種類の行の撃破・解放も知りたい処理
var _row_watchers: Array[EnemyBehavior] = []
## 使った倒し方の共通ルール（EnemyTable.Gate の値 → EnemyGate）
var _gate_rules: Dictionary = {}

var table := EnemyTable.new()
var slots: RowSlots
## 行動の種類ごとの行番号の一覧（behaviors と同じ順。ボスと隕石は入らない）
var beh_rows: Array[PackedInt32Array] = []
## 撃破済みで、その回の終わりに空きへ戻す行
var _dead_rows := PackedInt32Array()
## 分裂などで、更新の終わりに個体数の上限の範囲で出す敵：[def, pos, opts]
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

func setup(context: RunContext) -> void:
	super(context)
	state.enemy_aim = state.ship_pos
	slots = RowSlots.new(table, "")
	# 敵を出す関数が、使い回す行の全部の列を書き直すか（デバッグ版だけ）
	assert(Columns.check_add(table, slots.cols, func(): return spawn(def_of(&"drifter"), Vector2.ONE),
		_release_row))
	clear_all()

# ── 行の出し入れ ──────────────────────────────────────────────────

## 敵を1体出し、その行番号を返す。opts：elite、size、facing、spin、meteor_index、vel、hit_cd。
## 仕様書 11.2 の補正をかける。
func spawn(def: EnemyDef, pos: Vector2, opts := {}) -> int:
	var i := slots.take()
	_reset_row(i)
	var t := table
	t.def[i] = def
	t.type[i] = def.id
	t.attack_group[i] = int(opts.get("attack_group", 0))
	var priority := float(opts.get("attack_priority", state.stage.enemy_attack_priority(def.id) if state.stage != null else 0.0))
	t.attack_priority[i] = priority if is_finite(priority) else 0.0
	if t.attack_group[i] > 0:
		t.attack_value[i] = float(opts.get("attack_value", 1.0))
	else:
		t.attack_value[i] = state.stage.enemy_attack_value(def.id) if state.stage != null else 1.0
	apply_scaling(i, def, opts)
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
	t.beh[i] = _behavior_index(def.behavior)
	t.accel[i] = def.accel if def.accel > 0.0 else 2.0
	t.turn[i] = def.turn if def.turn > 0.0 else 4.0
	t.meteor_index[i] = opts.get("meteor_index", -1)
	if t.meteor_index[i] < 0:
		_add_beh(i)
		behaviors[t.beh[i]].on_spawn(i, opts)
	else:
		for b in behaviors:
			b.rocks_changed()
	# 強敵と大物の出現は、プレイの記録が倒れるまでを追う
	if def.rank >= 3:
		state.emit(&"strong_spawn", {"id": t.id[i], "enemy_type": def.id})
	return i

## 強さと大きさを同じ規則で再計算する。位置・行動・個体IDは保つ。
func apply_scaling(i: int, def: EnemyDef, opts := {}) -> void:
	var t := table
	var elite: bool = opts.get("elite", false)
	t.elite[i] = 1 if elite else 0
	var size: float = opts.get("size", def.radius)
	var z := size / def.radius
	var r := size * (1.25 if elite else 1.0)
	# 手描き素材はエリートも同じ基準サイズで運用する。
	if def.id in EnemyDef.NATIVE_SPRITES:
		r = def.radius
	if opts.get("meteor_index", -1) < 0:
		r *= cfg.character_scale
	t.r[i] = r * def.visual_value("scale", 1.0)
	t.max_hp[i] = def.base_hp(cfg) * z * z * cfg.enemy_hp_mult * (3.0 if elite else 1.0)
	t.hp[i] = t.max_hp[i]
	t.armor[i] = def.armor * z * cfg.enemy_armor_mult * (1.3 if elite else 1.0)
	t.xp[i] = def.xp * z * (4.0 if elite else 1.0)
	t.speed[i] = def.speed

## 部位を1つ出し、親（行 i）に付ける。
func spawn_part(i: int, def: EnemyDef, pos: Vector2) -> int:
	var j := spawn(def, pos, {"attack_group": table.attack_group[i], "attack_value": table.attack_value[i], "attack_priority": table.attack_priority[i]})
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
	t.beh[i] = 0
	t.beh_slot[i] = -1
	t.is_boss[i] = 0
	t.meteor_index[i] = -1
	t.attack_group[i] = 0
	t.attack_value[i] = 1
	t.attack_priority[i] = 0
	t.dead[i] = 0
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
	t.stone[i] = 0.0
	t.held[i] = 0
	t.landmark[i] = 0
	t.fire_hit[i] = -1e9
	t.parent[i] = -1
	t.parent_id[i] = -1
	t.parts[i] = PackedInt32Array()

## 分裂などで増える敵。更新の終わりに、個体数の上限の範囲で出す（仕様書 11.3）。
func spawn_later(def: EnemyDef, pos: Vector2, opts := {}) -> void:
	_new.append([def, pos, opts])

## 行 i が、id の敵のまま使用中か（撃破済みでも、空きに戻るまでは true）。
func is_same(i: int, id: int) -> bool:
	return i >= 0 and i < table.alive.size() and table.alive[i] != 0 and table.id[i] == id

## 撃破済みにする。行はその回の終わり（cleanup）に空きへ戻る。
## 行 i の敵に、位置 hit から向き dir の攻撃（cause）が当たったときの扱い（EnemyTable.GateResult）。
## 特殊な倒し方の条件を満たさない攻撃は、体当たりなら貫通するがダメージを与えない（PASS）。
## 弾かれるのは失敗のとき（BOUNCE）だけ。dmg は当たった攻撃のダメージで、殻（やまねこ座）にはこの判定で傷を付ける。
func gate_check(i: int, hit: Vector2, dir: Vector2, cause: StringName, dmg := 0.0) -> int:
	if table.is_boss[i] != 0 or table.beh_slot[i] < 0:
		return gate_rule(i, hit, dir, cause, dmg)
	return behaviors[table.beh[i]].gate(i, hit, dir, cause, dmg)

## 敵の倒し方（EnemyDef.gate。ボスは役者が入れる）の共通ルールで決める扱い。
func gate_rule(i: int, hit: Vector2, dir: Vector2, cause: StringName, dmg: float) -> int:
	var rule := _gate(table.gate[i])
	return rule.check(self, i, hit, dir, cause, dmg) if rule != null else EnemyTable.GateResult.ALLOW

## 倒し方の条件を満たした体当たりのダメージ。
func gate_ram_damage(i: int, dmg: float) -> float:
	var rule := _gate(table.gate[i])
	return rule.ram_damage(self, i, dmg) if rule != null else dmg

## 前面で攻撃を弾く敵か（命中した位置 hit、飛んできた向き dir）。
func blocks_front(i: int, hit: Vector2, dir: Vector2) -> bool:
	return table.beh_slot[i] >= 0 and behaviors[table.beh[i]].blocks_front(i, hit, dir)

## 背面から盾を奪える位置か。
func rear_open(i: int, hit: Vector2) -> bool:
	return table.beh_slot[i] >= 0 and behaviors[table.beh[i]].rear_open(i, hit)

## 接触の間隔（hit_cd）があっても、機体の接触を毎回調べる敵か。
func ignores_hit_cd(i: int) -> bool:
	return table.beh_slot[i] >= 0 and behaviors[table.beh[i]].ignores_hit_cd

func _gate(kind: int) -> EnemyGate:
	if kind == EnemyTable.Gate.NONE:
		return null
	if not _gate_rules.has(kind):
		var name := String(EnemyTable.Gate.keys()[kind]).to_lower()
		_gate_rules[kind] = load("res://scripts/enemies/gates/%s.gd" % name).new()
	return _gate_rules[kind]

## ボスとその部位の位置は役者が決める。外力だけを除き、自力移動や被弾表現を保つ。
func knockback_scale(i: int) -> float:
	if table.is_boss[i] != 0:
		return 0.0
	var parent := table.parent[i]
	if self.is_same(parent,table.parent_id[i]) and table.is_boss[parent] != 0:
		return 0.0
	return table.def[i].knockback_scale(cfg) if table.def[i] != null else 1.0

func mark_dead(i: int) -> void:
	if table.dead[i] != 0:
		return
	table.dead[i] = 1
	for w in _row_watchers:
		w.on_row_gone(i)
	_dead_rows.append(i)

## 使用中の行の数（隕石・ボス・空きに戻る前の撃破済みを含む）。
func count() -> int:
	return slots.live

## ボスと障害物のほかの敵を、撃破にせずに消す（ボーナスステージの出入り）。
func clear_regular() -> void:
	var t := table
	for i in t.alive.size():
		if t.alive[i] != 0 and t.is_boss[i] == 0 and t.meteor_index[i] < 0:
			var parent:=t.parent[i]
			if self.is_same(parent,t.parent_id[i]) and t.is_boss[parent]!=0 and t.dead[parent]==0:
				continue
			mark_dead(i)

## 全部の敵を消す（計測・確認用のツールが使う）。
func clear_all() -> void:
	for b in behaviors:
		b.clear()
	slots.clear()
	for rows in beh_rows:
		rows.clear()
	_dead_rows.clear()
	_new.clear()

func _add_beh(i: int) -> void:
	var b := table.beh[i]
	table.beh_slot[i] = beh_rows[b].size()
	beh_rows[b].append(i)

## 行 i を空きに戻す。行動の種類ごとの一覧からは、最後の行と入れ替えて外す。
func _release_row(i: int) -> void:
	for w in _row_watchers:
		w.on_row_gone(i)
	var s := table.beh_slot[i]
	if s >= 0:
		behaviors[table.beh[i]].on_release(i)
		var rows := beh_rows[table.beh[i]]
		var last := rows[rows.size() - 1]
		rows[s] = last
		table.beh_slot[last] = s
		rows.resize(rows.size() - 1)
		table.beh_slot[i] = -1
	slots.release(i)

## 機体の移動と通常の戦闘が終わったあと。種類ごとの処理（投げた敵の当たりなど）を呼ぶ。
func after_combat() -> void:
	for b in behaviors:
		b.after_combat()

## 回収の更新のとき。ドロップを拾う種類の処理を呼ぶ。
func gather_pickups(pk: PickupSystem, dt: float) -> void:
	for b in behaviors:
		b.gather_pickups(pk, dt)

## 行動の種類の処理（その戦いにまだ出ていなければ null）。
func behavior(name: StringName) -> EnemyBehavior:
	var k: int = _behavior_ids.get(name, -1)
	return behaviors[k] if k >= 0 else null

## 行動の種類の番号。初めて出た種類は res://scripts/enemies/<名前>.gd を読んで作る。ファイルがなければ追跡と同じ動き。
func _behavior_index(name: StringName) -> int:
	var k: int = _behavior_ids.get(name, -1)
	if k >= 0:
		return k
	var path := "res://scripts/enemies/%s.gd" % name
	if not ResourceLoader.exists(path):
		return _behavior_index(&"chase")
	var b: EnemyBehavior = load(path).new()
	k = behaviors.size()
	b.setup(self, name, k)
	behaviors.append(b)
	beh_rows.append(PackedInt32Array())
	_behavior_ids[name] = k
	if b.watches_rows:
		_row_watchers.append(b)
	return k

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
	for k in clampi(count_n, 1, 10000):
		var def := choices[state.rng.randi_range(0, choices.size() - 1)]
		var pos := Vector2(state.rng.randf_range(view.position.x, view.end.x),
			state.rng.randf_range(view.position.y, view.end.y))
		var opts := {"facing": (state.ship_pos - pos).angle()}
		if def.size_var:
			opts.size = def.radius * state.rng.randf_range(0.85, 1.45)
		var i := spawn(def, pos, opts)
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
	for k in behaviors.size():
		var rows := beh_rows[k]
		if rows.is_empty():
			continue
		if behaviors[k].custom_loop:
			behaviors[k].tick_rows(rows, world_dt)
		else:
			_tick_behavior(k, world_dt)
	for b in behaviors:
		b.after_tick(world_dt)
	_flush_new()

## 行動の種類 b の敵を進める。押し出し・石化・遠い敵の間引きを済ませてから、種類の処理を1行ずつ呼ぶ。
func _tick_behavior(b: int, dt: float) -> void:
	var rows: PackedInt32Array = beh_rows[b]
	var behavior := behaviors[b]
	var managed := behavior.admission
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
	var held := t.held
	var vc := state.view_center
	var lim := state.view_half * 1.25 + Vector2(300, 300)
	for i in rows:
		if dead[i] != 0 or held[i] != 0:
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
			var needs_admission := managed and t.def[i].rank >= 3
			if managed and not needs_admission:
				projectiles.lab_context = 0
			if needs_admission and not _lab_admit(i, bdt):
				_chase(i, bdt)
				pos[i] += vel[i] * dt
				if _near_body(i, pos[i], r[i] + vel[i].length() * dt, now, body_move):
					field.collide_enemy(i, from)
				continue
			behavior.step(i, bdt)
			if dead[i] != 0:
				continue
			pos[i] += vel[i] * dt
		if _near_body(i, pos[i], r[i] + vel[i].length() * dt, now, body_move):
			field.collide_enemy(i, from)

	projectiles.lab_context = 0

## 行 i の敵が、位置 p から margin 以内に天体があるか（FieldSystem.near_body と同じ条件）。
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
func _chase(i: int, _dt: float) -> void:
	var t := table
	var d := state.ship_pos - t.pos[i]
	var dist := d.length()
	if dist < 0.001:
		t.vel[i] = Vector2.ZERO
		return
	var u := d / dist
	t.vel[i] = u * t.speed[i]
	t.facing[i] = u.angle()

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

## 予告や攻撃の間、その場で止まる。
func _hold(i: int, dt: float) -> void:
	table.vel[i] *= maxf(0.0, 1.0 - 8.0 * dt)

## 自分の周りで爆発して消える（倒されたことにはならない）。
func _self_destruct(i: int) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	projectiles.fire_zone(t.pos[i], float(p.blast_radius), 0.0, float(p.blast_dmg),
		ProjectileSystem.HazardStyle.BLAST, t.color[i])
	mark_dead(i)

# ── 強敵（仕様書 11.7・敵一覧） ──────────────────────────────────

## 大きく旋回しながら一定の速さで走る（ぎょしゃ座・わし座）。向きは turn の速さでしか変わらない。
func _drive(i: int, dt: float) -> void:
	var t := table
	_turn_toward(i, (state.enemy_aim - t.pos[i]).angle(), t.turn[i], dt)
	t.vel[i] = Vector2.from_angle(t.facing[i]) * t.speed[i]

## 撃破されたときの処理。誘爆する雑魚は少し遅れて爆発し、種類ごとの撃破の処理（分裂・解放など）を呼ぶ。atk は機体の攻撃力。
func on_enemy_death(i: int, atk: float) -> void:
	var t := table
	var dp: Dictionary = t.def[i].params if t.def[i] != null else {}
	var prior_context := projectiles.lab_context
	if projectiles.director != null:
		projectiles.lab_context = projectiles.director.passive(str(t.id[i]), i, t.id[i])
	if t.beh_slot[i] >= 0:
		behaviors[t.beh[i]].on_death(i, atk)
	if dp.has("chain_power"):
		projectiles.fire_zone(t.pos[i], float(dp.blast_radius), float(dp.blast_delay), float(dp.blast_dmg),
			ProjectileSystem.HazardStyle.BLAST, t.color[i], atk * float(dp.chain_power))
	projectiles.lab_context = prior_context

## 分裂などで増えた敵を、個体数の上限の範囲で出す（仕様書 11.3）。
func _flush_new() -> void:
	if _new.is_empty():
		return
	var limit := ceili(_target().pop * (1.0 + cfg.enemy_split_overflow))
	var population := _count_population(false)
	for n in _new:
		if population >= limit:
			break
		spawn(n[0], n[1], n[2])
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
	return phases[_phase_index()]

## 今の時間帯の番号。時間帯は開始の時刻だけを持ち、次の時間帯の開始まで続く。
func _phase_index() -> int:
	var phases: Array = state.stage.phases
	var n := 0
	for k in range(1, phases.size()):
		if (phases[k] as PhaseDef).start > state.time:
			break
		n = k
	return n

## 時間帯 n の終わりの時刻（次の時間帯の開始。最後の時間帯はボスの出現時刻）。
func _phase_end(n: int) -> float:
	var phases: Array = state.stage.phases
	if n + 1 < phases.size():
		return (phases[n + 1] as PhaseDef).start
	return state.stage.boss_start(cfg)

func _target() -> Dictionary:
	var n := _phase_index()
	var p: PhaseDef = state.stage.phases[n]
	var k := clampf((state.time - p.start) / maxf(0.001, _phase_end(n) - p.start), 0.0, 1.0)
	var effects := state.stage.surge_effects(cfg, state.time)
	var steps: int = effects.steps
	if state.bonus_t > 0.0:
		# ボーナスステージ：雑魚と硬めの敵だけを多く保つ
		return {"phase": p, "steps": steps, "surge": effects, "pop": cfg.bonus_pop * cfg.density_mult}
	var scale := cfg.density_mult * (1.0 + float(effects.pop))
	var curves: Array = state.stage.zako_curves
	if not curves.is_empty():
		# 雑魚の種類ごとの目標の数の曲線（合計が目標の数）。曲線の値がそのまま実際の数で、敵の密度倍率は掛けない
		var surge := 1.0 + float(effects.pop)
		var per := {}
		var total := 0.0
		for c: SpawnCurve in curves:
			var v := maxf(0.0, c.value_at(state.time)) * surge
			per[c.type] = float(per.get(c.type, 0.0)) + v
			total += v
		return {"phase": p, "steps": steps, "surge": effects, "pop": total, "per_type": per}
	return {"phase": p, "steps": steps, "surge": effects, "pop": lerpf(p.pop_from, p.pop_to, k) * scale}

## 強化帯の強まりの段（仕様書 4.2）。右端に達したあとは、その段を保つ。
func surge_steps() -> int:
	return int(state.stage.surge_effects(cfg, state.time).steps)

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
	var alive_n := _survey(t.pop)
	# 領域ごとの上限で数えない敵がたまり続けないように、実際の数は目標の数 × spawn_total_cap で止める
	var raw_n: int = _survey_raw
	var raw_limit: float = t.pop * cfg.spawn_total_cap if cfg.spawn_total_cap > 0.0 else INF
	var deficit := maxf(0.0, t.pop - alive_n)
	var rate := maxf(phase.rate * cfg.density_mult, deficit / cfg.spawn_refill_time)
	var cap := maxf(8.0, 8.0 * cfg.density_mult)
	_spawn_acc = minf(_spawn_acc + rate * world_dt, cap)
	var attempts := 0
	while _spawn_acc >= 1.0 and alive_n < t.pop and raw_n < raw_limit and attempts < cap:
		attempts += 1
		_spawn_acc -= 1.0
		if _spawn_one(t):
			alive_n += 1
			raw_n += 1
	if phase.wave_interval > 0.0:
		_wave_t += world_dt
		if _wave_t >= phase.wave_interval:
			_wave_t = 0.0
			if alive_n < t.pop and raw_n < raw_limit:
				_spawn_wave(t, minf(t.pop - alive_n, raw_limit - raw_n))
	_tick_clips()
	_sync_attack_budget(phase)

## 本番のランは、時間帯の予算と個体value（明示overrideだけ群れ共有）で攻撃を管理する。
## 実験場では、実験場の設定に任せる。
func _sync_attack_budget(phase: PhaseDef) -> void:
	var d = projectiles.director
	if d == null or state.lab_mode:
		return
	d.formation_mode = true
	d.enabled = true
	d.settings.budget = maxi(0, phase.attack_budget)
	d.settings.jitter = 0.0

# ── 強敵の群れ（敵の組み合わせのシーン） ────────────────────────────

## 組み合わせのシーンのパス → ゲーム中に使う形（EnemyFormation.to_data）
var _formation_cache: Dictionary = {}
## クリップの番号 → そのクリップから出た群れ（各群れの行番号と id を交互に並べたもの）
var _clip_groups: Dictionary = {}
## クリップの番号 → 次に群れを出せる時刻（実秒）
var _clip_next: Dictionary = {}
## 一度画面に入ったクリップの群れ（群れの最初の敵の id → true）。入ったあとは遠くなったら再配置する
var _clip_arrived: Dictionary = {}

## 組み合わせのシーンを、ゲーム中に使う形にする（シーンごとに1回だけ）。
func formation_data(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}
	if not _formation_cache.has(scene.resource_path):
		var node := scene.instantiate()
		_formation_cache[scene.resource_path] = node.to_data() if node.has_method("to_data") else {}
		node.free()
	return _formation_cache[scene.resource_path]

## 重み（weight）で1つ選んだ番号。空なら -1。
func _pick_weighted(items: Array) -> int:
	var total := 0.0
	for it in items:
		total += float(it.weight)
	if items.is_empty() or total <= 0.0:
		return -1
	var roll := state.rng.randf() * total
	for k in items.size():
		roll -= float(items[k].weight)
		if roll < 0.0:
			return k
	return items.size() - 1

## 組み合わせ data から配置と出現位置を1つずつ選び（layout・entry に番号を渡せば、その配置・出現位置）、群れを出す。配置の中心と正面を出現位置の点と向きにそろえ、
## 機体の向きに合わせて回して置く。出現位置の距離は、今の映る広さ（止まっているときとの比）だけ伸ばす。
## types を渡せば、その種類の敵だけを出す（クリップの種類の組み合わせ）。出した敵の行番号と id を交互に並べて返す。
## priorityが数値なら0を含めて群れ全員へ渡す。nullならステージの種類別優先度を使う。
func spawn_formation(data: Dictionary, layout := -1, entry_index := -1, types: Array = [], value := -1.0, priority: Variant = null) -> PackedInt32Array:
	var rows := PackedInt32Array()
	var group := _next_id if value > 0.0 else 0
	var li := layout if layout >= 0 and layout < data.get("layouts", []).size() else _pick_weighted(data.get("layouts", []))
	var ei := entry_index if entry_index >= 0 and entry_index < data.get("entries", []).size() else _pick_weighted(data.get("entries", []))
	if li < 0 or ei < 0:
		return rows
	var entry: Dictionary = data.entries[ei]
	var heading := state.ship_vel.normalized() if state.ship_vel.length() > 40.0 else state.ship_heading
	if heading == Vector2.ZERO:
		heading = Vector2.UP
	# 作るときの機体は上（y の負）向き。今の向きとの差だけ回す
	var turn := heading.angle() + PI / 2.0
	var stretch := maxf(1.0, minf(state.view_half.x, state.view_half.y) * 2.0 / maxf(cfg.base_view, 1.0))
	var entry_xf := Transform2D(float(entry.rot), Vector2(entry.pos) * stretch)
	for m: Dictionary in data.layouts[li].markers:
		if not types.is_empty() and not types.has(StringName(m.type)):
			continue
		var def := def_of(StringName(m.type))
		if def == null:
			continue
		var local := entry_xf * Transform2D(float(m.rot), Vector2(m.pos))
		var pos := state.ship_pos + local.origin.rotated(turn)
		# 置き場所の正面は y の負の向き
		var facing := turn + local.get_rotation() - PI / 2.0
		var opts := {"facing": facing, "attack_group": group, "attack_value": value}
		if priority != null:
			opts.attack_priority = priority
		var i := spawn(def, pos, opts)
		rows.append(i)
		rows.append(table.id[i])
	return rows

## 群れのうち、生きている敵がいるか。
func _group_alive(rows: PackedInt32Array) -> bool:
	for k in range(0, rows.size(), 2):
		if self.is_same(rows[k], rows[k + 1]) and table.dead[rows[k]] == 0:
			return true
	return false

## 組み合わせの敵のうち、同時に出る数の上限（max_alive）に達している種類があるか。
func _formation_capped(data: Dictionary) -> bool:
	for l: Dictionary in data.get("layouts", []):
		for m: Dictionary in l.markers:
			var def := def_of(StringName(m.type))
			if def != null and def.max_alive > 0 and _type_counts.get(def.id, 0) >= def.max_alive:
				return true
	return false

## ステージのクリップから強敵の群れを出す。クリップは開始から長さの間だけ働き、そのクリップから出た群れが同時の群れの数より
## 少なく、前の群れから出す間隔が経っていれば、フォーメーションを1つ選び、クリップの使う並びから配置を重みで1つ選んで、クリップの種類の敵だけを出す。
## 種類ごとの上限（max_alive）に達するフォーメーションは選ばない。
func _tick_clips() -> void:
	var clips: Array = state.stage.clips if state.stage != null else []
	for n in clips.size():
		var clip: SpawnClip = clips[n]
		var prev: Array = _clip_groups.get(n, [])
		var groups: Array = prev.filter(_group_alive)
		if groups.size() < prev.size():
			# 全滅した群れ（プレイの記録が読む。群れは最初の敵の id で見分ける）
			for g: PackedInt32Array in prev:
				if not groups.has(g):
					_clip_arrived.erase(g[1])
					state.emit(&"clip_group_end", {"clip": clip.label, "key": g[1]})
		_clip_groups[n] = groups
		if state.time < clip.time or state.time >= clip.end_time():
			continue
		if groups.size() >= clip.groups or state.time < float(_clip_next.get(n, -1e9)):
			continue
		var items := []
		for scene: PackedScene in clip.formations:
			var data := formation_data(scene)
			if data.is_empty() or _formation_capped(data):
				continue
			var allowed := clip.allowed_layouts(scene.resource_path, data)
			if not allowed.is_empty():
				items.append({"data": data, "layouts": allowed, "scene_path": scene.resource_path, "weight": 1.0})
		var k := _pick_weighted(items)
		if k < 0:
			continue
		var choices := []
		for li: int in items[k].layouts:
			choices.append({"index": li, "weight": items[k].data.layouts[li].weight})
		var c := _pick_weighted(choices)
		if c < 0:
			continue
		var layout_index: int = choices[c].index
		var value := clip.formation_value(items[k].scene_path, str(items[k].data.layouts[layout_index].get("name", "")))
		var rows := spawn_formation(items[k].data, layout_index, -1, clip.types, value, clip.attack_priority)
		if not rows.is_empty():
			groups.append(rows)
			_clip_next[n] = state.time + clip.interval
			state.emit(&"clip_group", {"clip": clip.label, "key": rows[1], "n": rows.size() / 2})

var _type_counts: Dictionary = {}
## 曲線のある雑魚の種類ごとの、再配置の範囲の中の数
var _zako_counts: Dictionary = {}
var _far_rows := PackedInt32Array()
## 領域（0〜3：左・右・上・下、4：中心付近）ごとの、数える範囲の敵の数と、種類ごとの数
var _region_n := PackedInt32Array([0, 0, 0, 0, 0])
var _region_types: Array[Dictionary] = [{}, {}, {}, {}, {}]
## 直前の走査での、再配置の範囲の中の敵の実際の数（領域ごとの上限で切る前）
var _survey_raw := 0

## 1回の走査で、外周の辺ごとの数・同時に出る数の上限がある種類の数・再配置の範囲の中の数を数え、遠くの敵を再配置する。
## 戻り値は、目標の数 pop と比べる、再配置の範囲の中の敵の数。上下左右と中心付近の領域ごとに、
## pop × config.spawn_region_cap までしか数えない（一か所に固まった敵だけで目標に届かないように）。
func _survey(pop: float) -> float:
	_edge_counts.fill(0)
	_type_counts.clear()
	_zako_counts.clear()
	_region_n.fill(0)
	for d in _region_types:
		d.clear()
	var vc := state.view_center
	var vh := state.view_half
	var lim := vh * cfg.spawn_recycle_scale + Vector2(200, 200)
	var center_x := vh.x * 0.45
	var center_y := vh.y * 0.45
	var pos := table.pos
	var dead := table.dead
	var type := table.type
	var defs := table.def
	_far_rows.clear()
	# クリップから出た群れは、隊列のまま近づけるため、画面に入るまでは遠くにいても再配置しない。
	# 一度画面に入った群れは、ほかの敵と同じく遠くなったら近くへ移す
	var grouped := {}
	var view := state.view_rect()
	for groups: Array in _clip_groups.values():
		for rows: PackedInt32Array in groups:
			if _clip_arrived.has(rows[1]):
				continue
			var seen := false
			for k in range(0, rows.size(), 2):
				if self.is_same(rows[k], rows[k + 1]) and view.has_point(pos[rows[k]]):
					seen = true
					break
			if seen:
				_clip_arrived[rows[1]] = true
				continue
			for k in range(0, rows.size(), 2):
				grouped[rows[k]] = true
	for rows in beh_rows:
		for i in rows:
			if dead[i] != 0:
				continue
			# 上限のある種類だけ数える
			if defs[i].max_alive > 0:
				_type_counts[type[i]] = _type_counts.get(type[i], 0) + 1
			var rel := pos[i] - vc
			if absf(rel.x) > lim.x or absf(rel.y) > lim.y:
				# 部位は親と一緒に動き、自分で退場する種類（横断する群れなど）は、離れても再配置しない
				if table.parent[i] < 0 and (table.beh_slot[i] < 0 or behaviors[table.beh[i]].recycles_far) and not grouped.has(i):
					_far_rows.append(i)
				continue
			var ax := absf(rel.x)
			var ay := absf(rel.y)
			var region := 4
			if ax >= center_x or ay >= center_y:
				# 正規化した距離の比較を交差乗算にし、個体ごとの除算を省く。
				region = (0 if rel.x < 0.0 else 1) if ax * vh.y > ay * vh.x else (2 if rel.y < 0.0 else 3)
				_edge_counts[region] += 1
			_region_n[region] += 1
			var rt: Dictionary = _region_types[region]
			rt[type[i]] = int(rt.get(type[i], 0)) + 1
	# 領域ごとに上限で切って数える（種類ごとの数も同じ割合で減らす）
	var limit := pop * cfg.spawn_region_cap if pop > 0.0 and cfg.spawn_region_cap > 0.0 else INF
	var alive_n := 0.0
	_survey_raw = 0
	for region in 5:
		var n := _region_n[region]
		_survey_raw += n
		if n == 0:
			continue
		var keep := minf(1.0, limit / n)
		alive_n += n * keep
		var rt: Dictionary = _region_types[region]
		for ty in rt:
			_zako_counts[ty] = float(_zako_counts.get(ty, 0.0)) + rt[ty] * keep
	for i in _far_rows:
		if _recycle(i):
			alive_n += 1.0
			_survey_raw += 1
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
	var type := _pick_short_type(t.per_type) if t.has("per_type") else _pick_type(phase, float(t.surge.ranged))
	if type == &"":
		return false
	var def := def_of(type)
	if def == null:
		return false
	if def.max_alive > 0 and _type_counts.get(type, 0) >= def.max_alive:
		return false
	var elite: bool = def.max_alive == 0 and state.rng.randf() < 0.01 + float(t.surge.elite)
	var opts := {"elite": elite, "facing": (state.ship_pos - p).angle()}
	if def.size_var:
		opts.size = def.radius * (0.85 + state.rng.randf() * 0.45)
	spawn(def, p, opts)
	if def.max_alive > 0:
		_type_counts[type] = _type_counts.get(type, 0) + 1
	_zako_counts[type] = float(_zako_counts.get(type, 0.0)) + 1.0
	return true

## 雑魚の目標の数の曲線から種類を選ぶ。目標の数に足りない分が大きい種類ほど選ばれやすい。足りない種類がなければ空。
func _pick_short_type(per_type: Dictionary) -> StringName:
	var items := []
	for type in per_type:
		var short := float(per_type[type]) - float(_zako_counts.get(type, 0))
		if short > 0.0:
			items.append({"type": type, "weight": short})
	var k := _pick_weighted(items)
	return StringName(items[k].type) if k >= 0 else &""

## 時間帯の出現の重みから種類を選ぶ。積み上げた強化の増分に応じて、撃つ敵を出やすくする。
func _pick_type(phase: PhaseDef, ranged_bonus: float) -> StringName:
	var items: Array = []
	var total := 0.0
	for k in phase.mix:
		var w := float(phase.mix[k])
		var def := def_of(StringName(k))
		if def != null and def.max_alive > 0 and state.bonus_t > 0.0:
			continue
		if def != null and def.ranged:
			w *= 1.0 + ranged_bonus
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
			spawn(def, state.view_center + u * d, {"facing": a + PI})
	else:
		var a := state.rng.randf() * TAU
		var u := Vector2(cos(a), sin(a))
		for k in n:
			var d := minf(half.x / maxf(0.0001, absf(u.x)), half.y / maxf(0.0001, absf(u.y))) + cfg.spawn_margin + k * 12.0
			var off := (state.rng.randf() - 0.5) * 120.0
			spawn(def, state.ship_pos + u * d + Vector2(-u.y, u.x) * off, {"facing": a + PI})
	state.emit(&"wave")

## 遠くへ離れた敵を、画面外の出現位置へ移す。HP などは保ち、撃破・経験値・ドロップは発生しない。
func _recycle(i: int) -> bool:
	if table.held[i] != 0:
		return false
	var p = spawn_point()
	if p == null:
		return false
	for w in _row_watchers:
		w.on_row_gone(i)
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

func _lab_owner(i: int) -> String:
	var d = projectiles.director
	return "formation:%d" % table.attack_group[i] if d != null and d.formation_mode and table.attack_group[i] > 0 else str(table.id[i])

## 予告へ入る前に取る、強敵と大物の攻撃の許可（攻撃の管理。仕様書 11.7）。許可がなければ、攻撃せずに追う。
func _lab_admit(i: int, dt: float) -> bool:
	var d = projectiles.director
	projectiles.lab_context = 0
	var def := table.def[i]
	if def == null:
		return true
	# 雑魚と硬めの敵は数だけで抑え、攻撃は管理しない
	var cats: Array = d.categories(def.behavior) if d != null and def.rank >= 3 else []
	if cats.is_empty():
		return true
	var owner := _lab_owner(i)
	var behavior := behaviors[table.beh[i]]
	if not behavior.admit_active(i, d, owner) and behavior.admit_due(i, dt):
		var duration := behavior.admit_duration(i)
		var cost: float = table.attack_value[i] if d.formation_mode else def.attack_weight
		var priority := table.attack_priority[i]
		if not cats.is_empty() and not d.request(owner, cats, i, table.id[i], duration, priority, cost):
			table.charge[i] = 0
			return false
	if not cats.is_empty():
		projectiles.lab_context = d.token(owner)
	return true
