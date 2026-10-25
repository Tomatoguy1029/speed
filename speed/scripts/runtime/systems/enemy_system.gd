## 雑魚の表・行動・出現・補充・再配置（仕様書 11、設計書 6・6.1）。
##
## 敵はノードではなく、敵の表（EnemyTable）の1行として持つ。雑魚の行動は種類ごとの単純なステートマシン
## （例：ダーターの予告 → 突進 → 回復）。隕石とボスも同じ表に入るが、数え方と行動は別に扱う。
## 行動する雑魚は、行動の種類ごとの行番号の一覧（beh_rows）に入り、更新は種類ごとにその一覧だけを回す。
class_name EnemySystem
extends RunSystem

var motion := EnemyMotion.new()

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
## 分裂などで、更新の終わりに個体数の上限の範囲で出す敵：[def, pos, opts]
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
## 仕様書 11.2 の補正をかける。
func spawn(def: EnemyDef, pos: Vector2, opts := {}) -> int:
	if stage_tuning.has(String(def.id)): def = def_of(def.id)
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
		def.id = StringName("picaro_"+String(def.id))
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
				motion._chase(i, bdt)
				pos[i] += vel[i] * dt
				if motion._near_body(i, pos[i], r[i] + vel[i].length() * dt, now, body_move):
					field.collide_enemy(i, from)
				continue
			behavior.step(i, bdt)
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
		behaviors[t.beh[i]].on_death(i, atk)
	if dp.has("chain_power"):
		projectiles.fire_zone(t.pos[i], float(dp.blast_radius), float(dp.blast_delay), float(dp.blast_dmg),
			ProjectileSystem.HazardStyle.BLAST, t.color[i], atk * float(dp.chain_power))
	projectiles.lab_context = prior_context

## 分裂体は個体数の上限を超えて出し、ほかの増殖は上限の範囲で出す（仕様書 11.3）。
func _flush_new() -> void:
	if _new.is_empty():
		return
	var limit := ceili(ctx.spawn.target().pop * (1.0 + cfg.enemy_split_overflow))
	var population := ctx.spawn.count_population(false)
	for n in _new:
		var def: EnemyDef = n[0]
		if population >= limit and def.id != &"splitling":
			continue
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
