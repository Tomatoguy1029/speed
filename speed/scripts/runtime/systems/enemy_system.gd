## 雑魚の表・行動・出現・補充・再配置（仕様書 11、設計書 6・6.1）。
##
## 敵はノードではなく、敵の表（EnemyTable）の1行として持つ。雑魚の行動は種類ごとの単純なステートマシン
## （例：ダーターの予告 → 突進 → 回復）。隕石とボスも同じ表に入るが、数え方と行動は別に扱う。
## 行動する雑魚は、行動の種類ごとの行番号の一覧（beh_rows）に入り、更新は種類ごとにその一覧だけを回す。
class_name EnemySystem
extends RunSystem
signal picaro_spawned(row: int, row_id: int, owner_id: int)

var motion := EnemyMotion.new()
## 位置を動かす前の雑魚の行IDと位置。強敵・ボスの更新後に雑魚側だけ進路を直す。
var _avoid_ids := PackedInt32Array()
var _avoid_from := PackedVector2Array()
var _avoid_obstacles := PackedInt32Array()
var _avoid_cells: Dictionary = {}
const AVOID_CELL := 160.0

func dispose() -> void:
	motion.m = null
	for behavior in behaviors:
		behavior.m = null
	behaviors.clear()
	_row_watchers.clear()
	definitions.clear()
	_stage_bases.clear()
	stage_tuning.clear()
	super()

var field: FieldSystem:
	get: return ctx.field
var projectiles: ProjectileSystem:
	get: return ctx.projectiles
var bosses: BossSystem:
	get: return ctx.bosses
## 実験場が複製した定義。未指定時は本番の定義を読む。
var definitions: Dictionary = {}
var _source_row := -1
## このランだけのステージ差分。共通定義や別のランと辞書を共有しない。
var stage_tuning: Dictionary = {}
var _stage_bases: Dictionary = {}

func set_stage_tuning(values: Dictionary) -> void:
	stage_tuning = values.duplicate(true)

func _stage_definition(type: StringName) -> EnemyDef:
	if not _stage_bases.has(type):
		_stage_bases[type] = definitions[type] if definitions.has(type) else ContentManager.definition(&"enemies", type)
	var base: EnemyDef = _stage_bases[type]
	var values: Dictionary = stage_tuning.get(String(type), {})
	return StageEnemyTuning.resolve(base, values) if not values.is_empty() else base

## 開発用UIからのライブ変更。個体の残HP割合、行動、位置、IDを保つ。
func update_stage_tuning(values: Dictionary) -> void:
	if values == stage_tuning: return
	var affected := stage_tuning.keys()
	for id in values:
		if id not in affected: affected.append(id)
	stage_tuning = values.duplicate(true)
	var t := table
	for id in affected:
		var type := StringName(id)
		var definition := _stage_definition(type)
		definitions[type] = definition
		for i in t.alive.size():
			if not t.alive[i] or t.dead[i] or t.is_boss[i] or t.type[i] != type: continue
			var old: EnemyDef = t.def[i]
			var old_hp := old.base_hp(cfg)
			var scale := sqrt(t.max_hp[i] / maxf(old_hp * cfg.enemy_hp_mult * (3.0 if t.elite[i] else 1.0), 0.001))
			if definition.base_hp(cfg) != old_hp:
				var health := t.hp[i] / maxf(t.max_hp[i], 0.001)
				t.max_hp[i] *= definition.base_hp(cfg) / maxf(old_hp, 0.001)
				t.hp[i] = t.max_hp[i] * health
			if definition.armor != old.armor:
				t.armor[i] = t.armor[i] * definition.armor / old.armor if old.armor > 0.0 else definition.armor * scale * cfg.enemy_armor_mult * (1.3 if t.elite[i] else 1.0)
			if definition.speed != old.speed:
				t.speed[i] = t.speed[i] * definition.speed / old.speed if old.speed > 0.0 else definition.speed
			if definition.accel != old.accel: t.accel[i] = definition.accel if definition.accel > 0.0 else 2.0
			if definition.turn != old.turn: t.turn[i] = definition.turn if definition.turn > 0.0 else 4.0
			if definition.weak_arc != old.weak_arc: t.weak_arc[i] = definition.weak_arc
			var interval := float(definition.params.get("fire_interval", 0.0))
			var previous := float(old.params.get("fire_interval", 0.0))
			if previous > 0.0 and interval != previous: t.fire_t[i] *= interval / previous
			t.def[i] = definition
	state.emit(&"enemy_tuning_changed", {"t": state.time, "world_t": state.world_time, "values": stage_tuning.duplicate(true)})

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
## 行動が予約した生成。更新の終わりにすべて出す：[def, pos, opts]
var _new: Array = []
var _next_id := 1
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
	motion.setup(self)
	state.enemy_aim = state.ship_pos
	slots = RowSlots.new(table, "")
	# 敵を出す関数が、使い回す行の全部の列を書き直すか（デバッグ版だけ）
	assert(Columns.check_add(table, slots.cols, func(): return spawn(def_of(&"drifter"), Vector2.ONE),
		_release_row))
	clear_all()

# ── 行の出し入れ ──────────────────────────────────────────────────

## 敵を1体出し、その行番号を返す。opts：elite、size、facing、spin、meteor_index、vel、hit_cd。
## 仕様書 11.2 の補正をかける。行を作る境界であり、出現可否と固有数は呼び出し元が決める。
## 通常補充の上限は SpawnSystem、召喚・分裂・構成員の数は各行動が管理する。
func spawn(def: EnemyDef, pos: Vector2, opts := {}) -> int:
	def=_inherit_picaro(def)
	if stage_tuning.has(String(def.id)) and not def.params.get("picaro",false): def = def_of(def.id)
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
		var previous_source:=_source_row
		_source_row=i
		behaviors[t.beh[i]].on_spawn(i, opts)
		_source_row=previous_source
	else:
		for b in behaviors:
			b.rocks_changed()
	# 強敵と大物の出現は、プレイの記録が倒れるまでを追う
	if def.rank >= 3:
		state.emit(&"strong_spawn", {"id": t.id[i], "enemy_type": def.id})
	if def.params.get("picaro", false):
		picaro_spawned.emit(i, t.id[i], int(def.params.get("picaro_owner", 0)))
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
	t.r[i] = r * def.visual_value("scale", 1.0) * def.visual_value("collision_scale", 1.0)
	t.max_hp[i] = def.base_hp(cfg) * z * z * cfg.enemy_hp_mult * (3.0 if elite else 1.0)
	t.hp[i] = t.max_hp[i]
	t.armor[i] = def.armor * z * cfg.enemy_armor_mult * (1.3 if elite else 1.0)
	t.xp[i] = def.xp * z * (4.0 if elite else 1.0)
	t.speed[i] = def.speed

## 部位を1つ出し、親（行 i）に付ける。
func spawn_part(i: int, def: EnemyDef, pos: Vector2) -> int:
	if table.def[i] != null and table.def[i].params.get("picaro",false):
		def = def.duplicate(true)
		def.params.picaro = true
		def.params.source_type = def.id
	var j := spawn(def, pos, {"attack_group": table.attack_group[i], "attack_value": table.attack_value[i], "attack_priority": table.attack_priority[i]})
	table.held[j] = table.held[i]
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
	t.pump_owner[i] = -1
	t.pump_owner_id[i] = -1
	t.landmark[i] = 0
	t.fire_hit[i] = -1e9
	t.parent[i] = -1
	t.parent_id[i] = -1
	t.parts[i] = PackedInt32Array()

## 行動に必要な分裂などを予約する。即時生成と同じく通常補充の上限を適用せず、更新の終わりに出す。
## 数・間隔は予約する行動が制限する。撃破時の生成は親の行の寿命から独立し、clear_all() で破棄する。
func spawn_later(def: EnemyDef, pos: Vector2, opts := {}) -> void:
	_new.append([_inherit_picaro(def), pos, opts])

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

## ほかの種類の行を抱える処理に、行 i が撃破・解放・再配置されたことを知らせる。
func notify_row_gone(i: int) -> void:
	for w in _row_watchers:
		w.on_row_gone(i)

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
	if stage_tuning.has(String(type)):
		if not definitions.has(type) or definitions[type] == _stage_bases.get(type):
			definitions[type] = _stage_definition(type)
		return definitions[type]
	return (definitions[type] if definitions.has(type) else ContentManager.definition(&"enemies", type)) as EnemyDef

## 負荷計測用。通常の出現上限を超え、画面内にランダムな通常敵を追加する。
# ── 更新 ──────────────────────────────────────────────────────────

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	# 開発版の計測：避け合いの準備・行動の種類ごと・更新後の処理を enemies.<名前> に足す
	var perf := ctx.perf
	var t0 := Time.get_ticks_usec()
	_capture_avoidance_starts()
	perf.since(&"enemies.avoid_capture", t0)
	motion._update_aim(world_dt)
	_lod += 1
	_aim = state.enemy_aim
	_vc = state.view_center
	_vh = state.view_half
	_face_move = cfg.enemy_face_move
	for k in behaviors.size():
		var rows := beh_rows[k]
		if rows.is_empty():
			continue
		t0 = Time.get_ticks_usec()
		if behaviors[k].custom_loop:
			behaviors[k].tick_rows(rows, world_dt)
		else:
			_tick_behavior(k, world_dt)
		if perf.active:
			perf.since(StringName("enemies." + String(behaviors[k].name)), t0)
	t0 = Time.get_ticks_usec()
	for b in behaviors:
		b.after_tick(world_dt)
	_flush_new()
	perf.since(&"enemies.after_tick", t0)

func _can_avoid_strong(i: int) -> bool:
	var t := table
	return t.alive[i] != 0 and t.dead[i] == 0 and t.def[i] != null and t.def[i].rank <= 2 \
		and t.is_boss[i] == 0 and t.meteor_index[i] < 0 and t.parent[i] < 0 \
		and t.mode[i] == EnemyTable.Mode.MOVE and t.held[i] == 0 and t.stone[i] <= 0.0 \
		and t.shove_time[i] <= 0.0 and t.knock_t[i] <= 0.0 and t.pump_owner[i] < 0

func _capture_avoidance_starts() -> void:
	var t := table
	var count := t.alive.size()
	_avoid_ids.resize(count)
	_avoid_from.resize(count)
	for i in count:
		_avoid_ids[i] = t.id[i] if _can_avoid_strong(i) else -1
		if _avoid_ids[i] >= 0:
			_avoid_from[i] = t.pos[i]

func _avoid_clearance(point: Vector2, i: int, candidates: Array) -> float:
	var gap := INF
	for j: int in candidates:
		gap = minf(gap, point.distance_to(table.pos[j]) - table.r[i] - table.r[j] - 2.0)
	return gap

## 通常の行動とボスの姿勢を確定した後、移動中の雑魚だけを身体の外へ導く。
## 位置補正は1世界更新の通常速度を超えず、ボス・強敵・攻撃中の行は動かさない。
func avoid_strong(world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	var t := table
	var pos := t.pos
	var radius_rows := t.r
	var ids := t.id
	var speeds := t.speed
	_avoid_obstacles.clear()
	_avoid_cells.clear()
	var normal_radius := 0.0
	var normal_step := 0.0
	# 開発版の計測：強敵を集める全行の走査（scan）と、雑魚ごとの補正（rows）
	var perf := ctx.perf
	var t0 := Time.get_ticks_usec()
	for j in t.alive.size():
		if t.alive[j] == 0 or t.dead[j] != 0 or t.held[j] != 0 or t.meteor_index[j] >= 0:
			continue
		if t.is_boss[j] != 0 or (t.def[j] != null and t.def[j].rank >= 3):
			# 吸い込める間は、雑魚がPumpの口へ入ることを優先する。
			if t.type[j] == &"pump" and t.mode[j] == EnemyTable.Mode.MOVE and t.stone[j] <= 0.0 \
					and t.shove_time[j] <= 0.0 and t.knock_t[j] <= 0.0 \
					and t.buds[j] < int(t.def[j].params.store_max):
				continue
			_avoid_obstacles.append(j)
		elif j < _avoid_ids.size() and _avoid_ids[j] == t.id[j] and _can_avoid_strong(j):
			normal_radius = maxf(normal_radius, radius_rows[j])
			normal_step = maxf(normal_step, speeds[j] * world_dt)
	perf.since(&"enemy_avoidance.scan", t0)
	if _avoid_obstacles.is_empty() or normal_radius <= 0.0:
		return
	t0 = Time.get_ticks_usec()
	# 強敵の占有円が届くセルだけ登録する。各雑魚は自分のセルだけを見る。
	for j in _avoid_obstacles:
		var extent := radius_rows[j] + normal_radius + normal_step + 2.0
		var lo := Vector2i(floori((pos[j].x - extent) / AVOID_CELL), floori((pos[j].y - extent) / AVOID_CELL))
		var hi := Vector2i(floori((pos[j].x + extent) / AVOID_CELL), floori((pos[j].y + extent) / AVOID_CELL))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var key := Vector2i(cx, cy)
				if not _avoid_cells.has(key):
					_avoid_cells[key] = [j]
				else:
					_avoid_cells[key].append(j)
	for i in mini(_avoid_ids.size(), t.alive.size()):
		if _avoid_ids[i] != ids[i] or not _can_avoid_strong(i):
			continue
		var from := _avoid_from[i]
		var key := Vector2i(floori(from.x / AVOID_CELL), floori(from.y / AVOID_CELL))
		if not _avoid_cells.has(key):
			continue
		var intended := pos[i] - from
		var limit := speeds[i] * world_dt
		if limit <= 0.0 or intended.length() > limit + 0.01:
			continue # 専用行動による瞬間移動・高速移動は書き換えない。
		var inside := Vector2.ZERO
		var most_inside := -1.0
		var fallback := Vector2.ZERO
		var near_row := -1
		var near_depth := 0.0
		for j: int in _avoid_cells[key]:
			if j == i:
				continue
			var radius := radius_rows[i] + radius_rows[j] + 2.0
			var offset := from - pos[j]
			var distance_sq := offset.length_squared()
			var reach := radius + limit
			if distance_sq > reach * reach:
				continue
			if distance_sq < radius * radius:
				var distance := sqrt(distance_sq)
				var normal := offset / distance if distance > 0.001 else Vector2.from_angle(float((ids[i] * 17 + ids[j] * 31) % 360) * PI / 180.0)
				var depth := radius - distance
				inside += normal * depth
				if depth > most_inside:
					most_inside = depth
					fallback = normal
				continue
			var next_distance := (from + intended).distance_to(pos[j])
			if next_distance < radius and radius - next_distance > near_depth:
				near_depth = radius - next_distance
				near_row = j
		var corrected := intended
		if most_inside > 0.0:
			var outward := inside.normalized() if inside.length_squared() > 0.000001 else fallback
			# 連続するボス部位の中心線では左右の法線が互いを塞ぐ。
			# 複数円からの最小距離が最も増える、横方向も含む進路を選ぶ。
			var tangent := outward.orthogonal()
			var side := 1.0 if ids[i] % 2 == 0 else -1.0
			var best := _avoid_clearance(from + outward * limit, i, _avoid_cells[key])
			for direction in [tangent * side, tangent * -side, -outward]:
				var score := _avoid_clearance(from + direction * limit, i, _avoid_cells[key])
				if score > best + 0.0001:
					best = score
					outward = direction
			corrected = outward * limit
		elif near_row >= 0:
			var radial := (from - pos[near_row]).normalized()
			corrected -= radial * minf(0.0, corrected.dot(radial))
			if corrected.length_squared() < 0.000001:
				var side := 1.0 if (ids[i] + ids[near_row]) % 2 == 0 else -1.0
				corrected = radial.orthogonal() * side * intended.length()
			else:
				corrected = corrected.normalized() * intended.length()
		if not corrected.is_equal_approx(intended):
			# 一つ目の円の接線が隣の部位へ入る場合、もう一方の接線を試す。
			# 外から身体へ入る進路しかなければその更新だけ止まる。
			if most_inside <= 0.0 and _avoid_clearance(from + corrected, i, _avoid_cells[key]) < 0.0:
				var side := corrected.orthogonal().normalized() * intended.length()
				var opposite := -side
				if _avoid_clearance(from + side, i, _avoid_cells[key]) >= 0.0:
					corrected = side
				elif _avoid_clearance(from + opposite, i, _avoid_cells[key]) >= 0.0:
					corrected = opposite
				else:
					corrected = Vector2.ZERO
			pos[i] = from + corrected
			t.vel[i] = corrected / world_dt
			if field.body_gap(pos[i], radius_rows[i]) < 0.0:
				field.collide_enemy(i, from)
	perf.since(&"enemy_avoidance.rows", t0)

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
		if not behavior.full_rate and (absf(rel.x) > lim.x or absf(rel.y) > lim.y):
			if (t.id[i] + _lod) % LOD != 0 and shove_time[i] <= 0.0 and knock_t[i] <= 0.0:
				pos[i] = from + vel[i] * dt
				continue
			bdt = dt * LOD
		if shove_time[i] > 0.0 or knock_t[i] > 0.0:
			motion._update_pushed(i, dt)
		else:
			var needs_admission := managed and t.def[i].rank >= 3
			if managed and not needs_admission:
				projectiles.lab_context = 0
			if needs_admission and not _lab_admit(i, bdt):
				if t.type[i] == &"aquila":
					behavior.call(&"cruise", i, bdt)
				else:
					motion._chase(i, bdt)
				pos[i] += vel[i] * dt
				if motion._near_body(i, pos[i], r[i] + vel[i].length() * dt, now, body_move):
					field.collide_enemy(i, from)
				continue
			var previous_source:=_source_row
			_source_row=i
			var prior_visual := projectiles.visual_context
			projectiles.visual_context = table.def[i].attack_visual
			behavior.step(i, bdt)
			projectiles.visual_context = prior_visual
			_source_row=previous_source
			if dead[i] != 0:
				continue
			behavior.before_move(i, dt)
			if dead[i] != 0:
				continue
			pos[i] += vel[i] * dt
		if motion._near_body(i, pos[i], r[i] + vel[i].length() * dt, now, body_move):
			field.collide_enemy(i, from)

	projectiles.lab_context = 0

## 撃破されたときの処理。誘爆する雑魚は少し遅れて爆発し、種類ごとの撃破の処理（分裂・解放など）を呼ぶ。atk は機体の攻撃力。
func on_enemy_death(i: int, atk: float) -> void:
	var t := table
	var dp: Dictionary = t.def[i].params if t.def[i] != null else {}
	var prior_context := projectiles.lab_context
	if projectiles.director != null:
		projectiles.lab_context = projectiles.director.passive(str(t.id[i]), i, t.id[i])
	if t.beh_slot[i] >= 0:
		var previous_source:=_source_row
		_source_row=i
		behaviors[t.beh[i]].on_death(i, atk)
		_source_row=previous_source
	if dp.has("chain_power"):
		projectiles.fire_zone(t.pos[i], float(dp.blast_radius), float(dp.blast_delay), float(dp.blast_dmg),
			ProjectileSystem.HazardStyle.BLAST, t.color[i], atk * float(dp.chain_power))
	projectiles.lab_context = prior_context

## 行動が確定した生成を実行する（仕様書 11.3）。敵IDによらず即時生成と同じ方針を使う。
func _flush_new() -> void:
	for n in _new:
		spawn(n[0], n[1], n[2])
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

func row_behavior(row: int) -> EnemyBehavior:
	return behaviors[table.beh[row]] if table.def[row] != null else null

func contact_override(row: int, dir: Vector2, from: Vector2, ship_speed: float) -> bool:
	var behavior := row_behavior(row)
	return behavior != null and behavior.on_contact(row, dir, from, ship_speed)

func extra_drops(pickups: PickupSystem, row: int) -> void:
	var behavior := row_behavior(row)
	if behavior != null:
		behavior.extra_drops(pickups, row)

## 元の行動が出す部位・兵・分裂体も、同じボスが所有するコズミック版へ引き継ぐ。
func _inherit_picaro(definition: EnemyDef) -> EnemyDef:
	if _source_row<0 or _source_row>=table.def.size() or table.def[_source_row]==null: return definition
	var source: EnemyDef=table.def[_source_row]
	if not source.params.get("picaro",false): return definition
	var owner: int=int(source.params.get("picaro_owner",0))
	if definition.params.get("picaro",false) and int(definition.params.get("picaro_owner",0))==owner: return definition
	var copy:=definition.duplicate(true) as EnemyDef
	copy.params.picaro=true
	copy.params.source_type=definition.id
	copy.params.picaro_owner=owner
	return copy
