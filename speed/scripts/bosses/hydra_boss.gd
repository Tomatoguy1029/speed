## 中央の瓦礫を守る多頭ボス。HP閾値で3→5→8本へ増加し、瓦礫破壊で独立蛇へ分離する。
## 行動選択はLimboAI、振り付けはAnimationPlayer、形状・判定は共有点列で扱う。
extends BossActor

## Hydra 内の演出契約。判定を変えず、技 ID と取り付け位置を受け取る。
signal presentation_event(event: Dictionary)
signal presentation_advanced(world_dt: float)
@export var presentation_scene: PackedScene
@export_group("Artwork")
@export var body_texture: Texture2D
@export var neck_texture: Texture2D
@export var compass_texture: Texture2D
@export_group("Presentation")
@export var energy_shader: Shader=preload("res://shaders/hydra_energy.gdshader")
@export var tornado_scene: PackedScene=preload("res://scenes/bosses/hydra_tornado.tscn")
@export_range(0.0, 1.0) var compass_spin_fraction := 0.5
var _presentation: Node
var _defeat_announced := false
var _neck_mesh: ArrayMesh
var _neck_mesh_dirty:=true
var _neck_mesh_origin:=Vector2.INF
var _neck_mesh_radius:=-1.0

const GRID := preload("res://scripts/bosses/hydra_grid.gd")
const SNAKE := preload("res://scripts/bosses/hydra_snake_motion.gd")
const NORMALS := preload("res://scripts/bosses/hydra_normals.gd")
const HEAD_BT := preload("res://scenes/bosses/hydra_head_bt.tres")
var _moves: Dictionary = {}
var _move_gates: Dictionary = {}
var _normal_moves: Dictionary = {}
var special: RefCounted
var attack_field: Node2D
var arena: Node2D
const NECK_CHAIN := preload("res://scripts/bosses/hydra_neck.gd")

## 首1本の状態
class Neck:
	## 首の種類（bite・vortex・debris・beam・thunder）
	var kind: StringName
	## 本体から見た付け根の向きと、今の首の向き・長さ
	var base_angle := 0.0
	var angle := 0.0
	var length := 0.0
	## 頭の行と id（落ちていれば -1）、前の更新の頭の HP
	var row := -1
	var row_id := 0
	var head_hp := 0.0
	## 生え直すまでの時間。火で落ちた頭は待ち時間を延長する。
	var regrow := 0.0
	var burned := false
	## 首の骨組みの点列（付け根から頭まで）
	var segs := PackedVector2Array()
	## 攻撃の段階と残り時間、次の攻撃までの時間、続けた回数、予告の光（0〜1）
	var mode: StringName = &"idle"
	var t := 0.0
	var cd := 0.0
	var emission: Dictionary = {}
	var locked := false
	var bt: BTTask
	var free_pos:=Vector2.ZERO
	var velocity:=Vector2.ZERO
	var motion: Dictionary={}
	var step := 0
	var glow := 0.0
	## 付いて動く攻撃の形（ビーム）の行と、強めの技で首を振る速さ
	var hazard := -1
	var sweep := 0.0
	## 北の集中噛みつき：捕捉点と、狙い固定後のワールド座標での伸長。
	var target := Vector2.ZERO
	var strike_from := Vector2.ZERO
	var strike_pos := Vector2.ZERO

## 首の本数ごとの首の種類（並びは付け根の向きの順）
const NECKS := {
	3: [&"bite", &"vortex", &"debris"],
	5: [&"bite", &"vortex", &"debris", &"beam", &"thunder"],
	8: [&"bite", &"vortex", &"debris", &"beam", &"thunder", &"bite", &"beam", &"vortex"],
}
var growth_t := 0.0
var separation_pending := false
var separated := false
var separation_t:=0.0
var immortal_neck: Neck
var chance_t := 0.0

func _chance_step(dt: float) -> void:
	if separated or separation_pending: return
	if chance_t > 0.0:
		chance_t = maxf(0.0, chance_t - dt)
		if chance_t <= 0.0:
			for neck in necks:
				if not _alive(neck): _grow(neck)
	elif not necks.is_empty() and necks.all(func(n): return not _alive(n)):
		interrupt_tech()
		chance_t = float(def.params.chance_time)
		_cue(&"recovery_started", &"chance", -1, {"duration": chance_t})


func on_body_damaged() -> void:
	if not separated:
		_check_growth()

func handle_body_defeat(_opts: Dictionary) -> bool:
	if separated:
		return immortal_row>=0 and ctx.enemies.is_same(immortal_row,immortal_id) and table.dead[immortal_row]==0
	separation_pending = true
	return true

func _check_growth() -> void:
	if growth_t > 0.0 or separated:
		return
	var ratio := table.hp[body] / table.max_hp[body]
	var thresholds: Array = def.params.growth_thresholds
	var next := 5 if count == 3 and ratio <= float(thresholds[0]) else (8 if count == 5 and ratio <= float(thresholds[1]) else 0)
	if next == 0:
		return
	interrupt_tech()
	_set_count(next)
	growth_t = float(def.params.growth_time)
	table.guard[body] = growth_t
	for neck in necks:
		if _alive(neck): table.guard[neck.row] = growth_t
	_cue(&"growth_started", &"", -1, {"duration": growth_t})

## 強めの技の方位（羅針盤の針が止まる向き。画面の上が北）
const COMBOS: Array[StringName] = [&"tornado",&"debris_shatter",&"beam_pincer"]
var combo_wait := 0.0
const TECH_DIR := {&"grid":0.0,&"swarm":-PI/2.0,&"tornado":PI/2.0,&"debris_shatter":0.0,&"beam_pincer":PI,&"curve":PI/2.0,&"sequence":0.0,&"north":-PI/2.0}

@onready var hsm: LimboHSM = $LimboHSM
@onready var timeline: AnimationPlayer = $Timeline
@onready var decision: BTState = $LimboHSM/Form1

var necks: Array[Neck] = []
var _guard_approach: Array[Neck] = []
## 今の段階の首の本数
var count := 0
## 不死の首：むき出しの残り時間と、頭の行と id
var immortal_row := -1
var immortal_id := 0
## むき出しが終わってから、次にむき出しになれるまでの時間
## 1本の線（突進の番号）ごとに落とした頭の数
var _dash_kills: Dictionary = {}
## 強めの技の最中（普段の首の攻撃を止める）
var busy := false
## 今の強めの技（空なら無し）、次に出せるまでの時間、羅針盤の針が回っている残り時間と止まる向き
var tech: StringName = &""
var _tech_cd := 0.0
var _spin_t := 0.0
var _needle := -PI / 2.0
## 強めの技で吐いた瓦礫（行と id）と、南の技の渦の位置
var _rubble: Array[Vector2i] = []
var _time := 0.0
var _sim_dt := 0.0
var north_target := Vector2.ZERO
var participants: Array[Neck] = []
var north_aiming := false
var _north_duration := 0.001
## 世界秒で進む攻めどきと、技別の再使用可能時刻。
var recovery_t := 0.0
var _tech_until: Dictionary = {}
var _cooldown_scale := 1.0
var last_tech: StringName = &""
var last_tech_result: StringName = &""
## 制限時間の一撃の経過時間（負なら使っていない。ランの時計で数える）、始めた時刻、溜めの長さ、首ごとの光の形
var final_strike_t := -1.0
var _final_start := 0.0
var _final_charge := 1.0
var _final_beams: Dictionary = {}

func _on_bound() -> void:
	# 手動の固定更新中に技の処理を確定し、描画フレームへ持ち越さない。
	timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	draws_self = true
	table.gate[body] = EnemyTable.Gate.NONE
	table.armor[body] = 0.0
	# 本体と首は、敵（頭）の下、地形の上に描く（RunPresentation の描画の層の enemies の下）
	z_index = 5
	arena = preload("res://scripts/bosses/hydra_arena.gd").new()
	add_child(arena)
	arena.bind(self)
	if presentation_scene != null:
		_presentation = presentation_scene.instantiate()
		add_child(_presentation)
		if _presentation.has_method("bind_hydra"):
			_presentation.bind_hydra(self)
	attack_field = load("res://scripts/bosses/hydra_attack_field.gd").new()
	add_child(attack_field)
	attack_field.bind(self)
	special=load("res://scripts/bosses/hydra_techniques.gd").new(self)
	_collect_moves(HEAD_BT.root_task)
	_collect_moves(decision.behavior_tree.root_task)
	_set_count(3)
	_tech_cd = float(def.params.tech_cd) * 0.6
	hsm.initialize(self)
	hsm.set_active(true)
	queue_redraw()

func _process(delta: float) -> void:
	if ctx == null or not has_body():
		return
	# 実験場で停止中に本体を移動・拡縮した場合も表示を更新する。
	if position != table.pos[body]:
		position = table.pos[body]
		queue_redraw()
	if get_meta(&"draw_radius", -1.0) != table.r[body]:
		queue_redraw()
	# 制限時間の一撃が当たったら、敗北の停止の間に光を消し、爆発と GAME OVER を見せる。
	if final_strike_t >= 0.0 and run_state.phase != RunState.Phase.PLAY:
		attack_field.modulate.a = move_toward(attack_field.modulate.a, 0.0, delta / maxf(0.01, ctx.cfg.death_freeze_time))

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0:
		return
	_time += dt
	_sim_dt = dt
	if final_strike_t >= 0.0:
		_final_strike_tick(dt)
		presentation_advanced.emit(dt)
		queue_redraw()
		return
	if growth_t > 0.0:
		growth_t = maxf(0.0, growth_t - dt)
		table.guard[body] = growth_t
		for neck in necks:
			if _alive(neck):
				table.guard[neck.row] = growth_t
				neck.length = move_toward(neck.length, float(def.params.neck_rest), float(def.params.neck_rest) * dt)
				table.pos[neck.row] = _head_pos(neck)
				_follow_neck(neck, dt)
		if growth_t <= 0.0: _check_growth()
		presentation_advanced.emit(dt)
		queue_redraw()
		return
	_check_growth()
	if growth_t > 0.0: return
	if separation_pending:begin_separation()
	if separation_t>0.0:
		separation_t=maxf(0.0,separation_t-dt)
		table.guard[body]=separation_t
		if immortal_row>=0:table.guard[immortal_row]=separation_t
		for n in necks:
			if _alive(n):table.guard[n.row]=separation_t
		presentation_advanced.emit(dt)
		queue_redraw()
		return
	if separated:tick_bearer(dt)
	else:_move(dt)
	recovery_t = maxf(0.0, recovery_t - dt)
	# 全滅を先に確定する。同じ更新で期限が来た頭を先に生やさない。
	_chance_step(dt)
	if north_aiming:
		_update_north_targets()
	_update_guard_approach()
	for k in necks.size():
		_tick_neck(necks[k], k, dt)
	_tech_cd -= dt
	combo_wait=maxf(0.0,combo_wait-dt)
	_spin_t -= dt
	_update_blackboard()
	hsm.update(dt)
	if ctx.projectiles.director != null:
		ctx.projectiles.lab_context = ctx.projectiles.director.token("boss:" + str(table.id[body]))
	if busy and special.positioning:
		if special.position(dt):timeline.play()
	if timeline.is_playing():
		timeline.advance(dt)
		if tech != &"" and not _tech_ok(tech):
			# 先に片方の首を落とされた：技が崩れる
			interrupt_tech()
		if busy and tech in [&"sequence",&"curve",&"tornado",&"debris_shatter",&"beam_pincer",&"swarm",&"grid"]: special.tick(dt)
	# 攻撃の位置が確定してから、頭と胴の姿勢を固定更新につき一度だけ進める。
	for n in necks:
		if _alive(n):
			table.pos[n.row]=_head_pos(n)
			table.facing[n.row]=n.angle
		if n.row>=0 or n.length>0.0:_follow_neck(n,dt)
	if separated and immortal_neck!=null:_follow_neck(immortal_neck,dt)

	if table.hp[body] <= 0.0 and separated and not _defeat_announced:
		_defeat_announced = true
		hsm.set_active(false)
		interrupt_tech()
		for neck in necks:
			_release_attack(neck)
			if _alive(neck):ctx.enemies.mark_dead(neck.row)
		attack_field.clear_effects()
		arena.release()
		_cue(&"defeated")
		ctx.bosses.on_boss_defeated(body, {"cause": &"ram"})
	attack_field.tick(dt)
	presentation_advanced.emit(dt)
	queue_redraw()

## 本体：基本はその場で構える。機体が一定より離れると、機体の方へ泳いで近づく。
func _move(dt: float) -> void:
	var t := table
	var i := body
	var p: Dictionary = def.params
	var d := run_state.ship_pos - t.pos[i]
	var dist := maxf(d.length(), 1.0)
	if busy and ((tech==&"north" and north_aiming) or tech==&"sequence"):
		var middle:=Vector2.ZERO
		for n in participants:middle+=Vector2.from_angle(n.base_angle)
		var wanted: float=d.angle()-middle.angle()
		t.facing[i] = rotate_toward(t.facing[i],wanted,def.turn*dt)
	var swimming := (dist > float(p.engage) or not run_state.view_rect().grow(-table.r[i]).has_point(t.pos[i])) and not busy and recovery_t <= 0.0
	var want := d / dist * def.speed if swimming else Vector2.ZERO
	t.vel[i] += (want - t.vel[i]) * minf(1.0, def.accel * dt)
	if busy or recovery_t > 0.0:
		t.vel[i] = Vector2.ZERO
	# 構えている間は胴体の向きを保ち、狙いは首先で表す。
	if swimming:
		t.facing[i] += clampf(Geom.angle_diff(d.angle(), t.facing[i]), -def.turn * dt, def.turn * dt)
	var from := t.pos[i]
	t.pos[i] += t.vel[i] * dt
	ctx.field.collide_enemy(i, from)
	t.pos[i] = arena.clamp_point(t.pos[i],t.r[i]+float(p.neck_rest)+80.0)
	if t.flash[i] > 0.0:
		t.flash[i] -= dt

## 首の本数を n にする（段階が変わった）。火で落ちた頭も含めて、全部の首が生え直す。
func _set_count(n: int) -> void:
	_cue(&"phase_changed", &"", -1, {"next_count": n})
	n = 8 if n >= 8 else (5 if n >= 5 else 3)
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
		neck.kind = kinds[k]
		if neck.row >= 0:
			_release_attack(neck)
			if _alive(neck):ctx.enemies.mark_dead(neck.row)
			neck.row = -1
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
	var head_def := ctx.enemies.def_of(StringName("hydra_" + String(neck.kind)))
	var j := ctx.enemies.spawn_part(body, head_def, _head_pos(neck))
	var hp := float(p.head_hp) * ctx.cfg.enemy_hp_mult
	table.max_hp[j] = hp
	table.hp[j] = hp
	neck.row = j
	neck.row_id = table.id[j]
	neck.head_hp = hp
	var bb := Blackboard.new()
	bb.set_var(&"head_index",necks.find(neck))
	neck.bt = HEAD_BT.root_task.clone()
	neck.bt.initialize(self,bb,self)
	neck.mode = &"idle"
	neck.glow = 0.0
	neck.segs.clear()
	_follow_neck(neck, 0.0)

## 根元は胴体表面のローカル座標で固定し、首の狙い角から分離する。
func _neck_base(neck: Neck) -> Vector2:
	if separated:return neck.free_pos-Vector2.from_angle(neck.angle)*float(def.params.neck_rest)
	return table.pos[body] + Vector2.from_angle(neck.base_angle + table.facing[body]) * table.r[body]

func _head_pos(neck: Neck) -> Vector2:
	var at := _unbounded_head_pos(neck)
	var radius: float=table.r[neck.row] if _alive(neck) else 40.0
	if arena==null:return at
	# 高速の伸長も天体の手前で止め、反対側へ抜けてから押し出すことを防ぐ。
	if _alive(neck):
		var hit=ctx.field.first_body_hit(table.pos[neck.row],at,radius)
		if hit!=null and hit.body!=null:
			var normal: Vector2=(hit.point-hit.body.pos).normalized()
			at=hit.body.pos+normal*(hit.body.r+radius+0.1)
	return arena.safe_point(at,radius)

func _unbounded_head_pos(neck: Neck) -> Vector2:
	if neck.mode in [&"special_aim",&"special_hold"]: return neck.strike_pos
	if tech == &"north" and neck.mode in [&"tech_lunge", &"tech_hold"]:
		return neck.strike_pos
	if neck.locked and _normal_moves.has(neck.mode): return neck.strike_pos
	if separated:return neck.free_pos
	return _neck_base(neck) + Vector2.from_angle(neck.angle) * neck.length

func _alive(neck: Neck) -> bool:
	return neck.row >= 0 and ctx.enemies.is_same(neck.row, neck.row_id) and table.dead[neck.row] == 0

## 頭の行が再利用される前に、火で落ちたかと本体へのダメージを確定する。
func on_part_defeated(row: int) -> void:
	queue_redraw()
	for neck in necks:
		if neck.row == row and neck.row_id == table.id[row]:
			_on_head_lost(neck)
			return
	if immortal_row == row and immortal_id == table.id[row]:
		if table.hp[row] <= 0.0:
			_cue(&"hit", &"immortal", -2, {"target": &"hydra", "damage": table.max_hp[row]})
		if separated:table.hp[body]=0.0

## 首1本の更新。露出中は生え直しを止める。
func _tick_neck(neck: Neck, k: int, dt: float) -> void:
	var p: Dictionary = def.params
	if neck.row >= 0 and not _alive(neck):
		_on_head_lost(neck)
	if neck.row < 0:
		if not separated and chance_t <= 0.0 and growth_t <= 0.0 and not busy and recovery_t <= 0.0:
			neck.regrow -= dt
			if neck.regrow <= 0.0:
				_grow(neck)
		neck.length = maxf(0.0, neck.length - float(p.neck_rest) * dt)
	else:
		if table.hp[neck.row] < neck.head_hp:
			neck.motion.hit=0.35
			_cue(&"hit", neck.mode, k, {"target": &"hydra", "damage": neck.head_hp - maxf(0.0, table.hp[neck.row])})
		neck.head_hp = table.hp[neck.row]
		if _normal_moves.has(neck.mode):
			neck.t += dt
			NORMALS.tick(self,neck,dt)
		elif neck.mode == &"idle":
			neck.cd = maxf(0.0,neck.cd-dt)
			if not busy and recovery_t <= 0.0 and chance_t <= 0.0: neck.bt.execute(dt)
		elif not String(neck.mode).begins_with("special_"): _attack(neck,k,dt)
		table.pos[neck.row] = _head_pos(neck)
		table.facing[neck.row] = neck.angle

## 頭が落ちた：首の残骸を破片にして飛ばし、生え直す時間を決める。
## 同じ線で倒した本数と、火の命中に応じて再生待ち時間を延長する。
func _on_head_lost(neck: Neck) -> void:
	var p: Dictionary = def.params
	var head := neck.row
	if table.hp[head] < neck.head_hp:
		_cue(&"hit", neck.mode, necks.find(neck), {"target": &"hydra", "damage": neck.head_hp - maxf(0.0, table.hp[head])})
	_cue(&"head_destroyed", neck.mode, necks.find(neck))
	neck.burned = run_state.world_time - table.fire_hit[head] < 0.5
	var n := 1
	if run_state.tracing:
		n = int(_dash_kills.get(run_state.dash_id, 0)) + 1
		_dash_kills[run_state.dash_id] = n
	ctx.projectiles.burst_debris(table.pos[head], 8, 700.0, float(p.debris_dmg) * ctx.cfg.atk_scale,
		Color("#a89a86"), table.id[head])
	_release_attack(neck)
	neck.row = -1
	neck.mode = &"idle"
	_extend_regrow_grace(1.0 + float(p.regrow_combo) * (n - 1))
	if neck.burned:
		neck.regrow = maxf(neck.regrow, float(p.regrow) * float(p.fire_regrow_scale))

## 次の首へ向かう時間を残り首数で確保し、倒すたびに全ての倒れた首へ猶予を与える。
func _extend_regrow_grace(combo_scale: float) -> void:
	var remaining := 0
	for neck in necks:
		if _alive(neck): remaining += 1
	var grace := (float(def.params.regrow) + float(def.params.regrow_per_head) * remaining) * combo_scale
	for neck in necks:
		if neck.row < 0:
			neck.regrow = maxf(neck.regrow, grace)

## 頭の位置・向きは攻撃側が決め、描画用の点列だけを解く。頭を失った首は短く畳む。
func _follow_neck(neck: Neck, dt: float) -> void:
	_neck_mesh_dirty=true
	if separated:
		SNAKE.follow(neck,_head_pos(neck),dt,_time,def.params)
		var points:=neck.segs
		for i in points.size():points[i]=arena.safe_point(points[i],24.0)
		neck.segs=points
		return
	var rest := float(def.params.neck_rest)
	if neck.row < 0:
		rest = minf(rest, neck.length)
	NECK_CHAIN.update(neck.segs, _neck_base(neck), _head_pos(neck), rest,
		neck.base_angle * 2.4, _time, dt, def.params)
	if not separated: NECK_CHAIN.keep_outside(neck.segs,table.pos[body],table.r[body])

## BT の技ノードが参照する Resource を役者ごとに読み込む。BossDef の既存編集は保持する。
func _collect_moves(task: BTTask, gates: Array = []) -> void:
	var branch := gates.duplicate()
	if task is BTSequence:
		for child_index in task.get_child_count():
			var child := task.get_child(child_index)
			if child.has_method("allows"): branch.append(child)
	if task.has_method("get_hydra_settings"):
		var settings: HydraTechnique = task.get_hydra_settings()
		if settings != null:
			_moves[settings.technique] = settings.duplicate(true)
			_move_gates[settings.technique] = branch
			if settings.head_kind != &"": _normal_moves[settings.technique] = true
	for child_index in task.get_child_count(): _collect_moves(task.get_child(child_index), branch)

func move_settings(attack: StringName) -> HydraTechnique:
	return _moves.get(attack)

## 移行済みの技別値は Settings が正。Params は本体・移動・共通予算の値を供給する。
func move_params(attack: StringName) -> Dictionary:
	var settings := move_settings(attack)
	return def.params.merged(settings.parameters, true) if settings != null else def.params

func _position_ready(attack: StringName, index := -1) -> bool:
	for condition in _move_gates.get(attack, []):
		if not condition.allows(self, index): return false
	return true

func _normal_cost(attack: StringName) -> float:
	var settings := move_settings(attack)
	return float(settings.parameters.cost) if settings != null else INF

func normal_ready(index: int, attack: StringName) -> bool:
	if index < 0 or index >= necks.size() or not _normal_moves.has(attack): return false
	var n := necks[index]
	var settings := move_settings(attack)
	if not _alive(n) or n.kind != settings.head_kind or n.mode != &"idle" or n.cd > 0.0: return false
	if busy or recovery_t > 0.0 or chance_t > 0.0 or growth_t > 0.0 or separation_pending: return false
	var at := _head_pos(n)
	if not run_state.view_rect().grow(-table.r[n.row]).has_point(at): return false
	if not _position_ready(attack, index): return false
	var used := 0.0
	for other in necks:
		if _normal_moves.has(other.mode): used += _normal_cost(other.mode)*maxf(0.0,table.attack_value[other.row])
	return used + _normal_cost(attack)*maxf(0.0,table.attack_value[n.row]) <= float(def.params.normal_budget)

func start_normal(index: int, attack: StringName) -> bool:
	if not normal_ready(index,attack): return false
	var n := necks[index]
	var director=ctx.projectiles.director
	# 通常ランの雑魚枠と、首同士のnormal_budgetを独立させる。
	if director!=null and not director.formation_mode:
		var cats: Array={&"bite":["dash"],&"vortex":["wave"],&"debris":["aimed"],&"beam":["beam"],&"thunder":["zone"]}[n.kind]
		var cost: float=_normal_cost(attack)*maxf(0.0,table.attack_value[n.row])
		if not director.request("neck:"+str(n.row_id),cats,n.row,n.row_id,4.0,table.attack_priority[n.row],cost):return false
	n.mode = attack
	n.t = 0.0
	n.locked = false
	n.step = 0
	n.emission.clear()
	n.target = run_state.ship_pos
	if attack==&"thunder_drop":n.target+=run_state.ship_vel*float(move_params(attack).thunder_lead)
	_cue(&"warning_started",attack,index)
	return true

func finish_normal(n: Neck) -> void:
	var cooldown := float(move_params(n.mode).attack_cd)
	var at := _head_pos(n)
	_release_attack(n)
	n.angle = (at-_neck_base(n)).angle()
	n.length = at.distance_to(_neck_base(n))
	n.free_pos=at
	n.locked = false
	n.mode = &"idle"
	n.cd = cooldown
	_cue(&"finished",&"",head_index(n))

func position_head(index: int, dt: float) -> void:
	var n := necks[index]
	if separated:
		var desired:=_guard_patrol(n,index)
		var entering:=false
		# 次の攻撃予算に入る蛇だけ画面内へ向かい、残りは護衛位置へ散る。
		if _guard_approach.has(n):
			var view: Rect2=run_state.view_rect().grow(-table.r[n.row]-24.0).intersection(arena.bounds.grow(-float(def.params.neck_rest)-table.r[n.row]-24.0))
			if not view.has_area():
				view=run_state.view_rect().grow(-table.r[n.row]-24.0).intersection(arena.bounds.grow(-table.r[n.row]-24.0))
				entering=true
			var heading:=Vector2.from_angle(n.base_angle)
			desired=view.get_center()+heading*view.size*0.4
		var spacing: float=float(def.params.neck_rest)*0.6+table.r[n.row]*2.0
		for other in necks:
			if other==n or not _alive(other):continue
			var offset:=n.free_pos-table.pos[other.row]
			var distance:=offset.length()
			if distance>=spacing:continue
			var direction:=offset/distance if distance>1.0 else Vector2.from_angle(n.base_angle)
			desired+=direction*(spacing-distance)*1.5
		steer_snake(n,desired,dt,1.0,entering)
		return
	var facing := n.base_angle+table.facing[body]
	n.motion.aim_wait=maxf(0.0,float(n.motion.get("aim_wait",0.0))-dt)
	if not n.motion.has("aim_target") or n.motion.aim_wait<=0.0:
		n.motion.aim_target=run_state.ship_pos
		n.motion.aim_wait=float(def.params.aim_refresh)
	var offset: Vector2=n.motion.aim_target-_neck_base(n)
	var forward:=Vector2.from_angle(facing)
	# 根元の背後を横切った自機を追って、左右の限界へ交互に首を振らない。
	var local:=atan2(offset.dot(forward.orthogonal()),maxf(float(def.params.aim_deadzone),offset.dot(forward)))
	var defend: float=facing+clampf(local,-0.8,0.8)
	aim_neck(n,defend+sin(_time+n.base_angle)*0.06,dt)
	n.length = move_toward(n.length,float(def.params.neck_rest),float(def.params.neck_rest)*dt)

## 護衛範囲を壁の内側へ収め、内外の持ち場をそれぞれ異なる周期で泳ぐ。
func _guard_patrol(n: Neck,index: int)->Vector2:
	var center: Vector2=table.pos[immortal_row]
	var away:=(center-run_state.ship_pos).normalized()
	var reach:=float(def.params.guard_radius)*3.0
	center-=away*float(def.params.guard_radius)*0.4
	var margin: float=float(def.params.neck_rest)+table.r[n.row]+24.0
	var region:=Rect2(center-Vector2.ONE*reach,Vector2.ONE*reach*2.0).intersection(arena.bounds.grow(-margin))
	if not region.has_area():region=arena.bounds.grow(-margin)
	var phase:=_time*(0.23+index*0.017)+n.base_angle*2.0
	var angle:=n.base_angle+sin(phase)*0.35
	var ring:=0.55+0.35*(index%2)+sin(phase*0.7+index)*0.06
	return region.get_center()+Vector2.from_angle(angle)*region.size*0.5*ring

## 通常攻撃の予算と待ち順から、画面内へ入る護衛だけを先に選ぶ。
func _update_guard_approach()->void:
	_guard_approach.clear()
	if not separated or busy or recovery_t>0.0:return
	var budget:=float(def.params.normal_budget)
	var pending: Array[Neck]=[]
	for n in necks:
		if not _alive(n):continue
		if _normal_moves.has(n.mode):
			budget-=_normal_cost(n.mode)*maxf(0.0,table.attack_value[n.row])
		elif n.mode==&"idle" and n.cd<=0.0:
			if not n.motion.has("guard_ready_since"):n.motion.guard_ready_since=_time
			pending.append(n)
		else:n.motion.erase("guard_ready_since")
	pending.sort_custom(func(a,b):
		if a.motion.guard_ready_since!=b.motion.guard_ready_since:return a.motion.guard_ready_since<b.motion.guard_ready_since
		return a.free_pos.distance_squared_to(run_state.ship_pos)<b.free_pos.distance_squared_to(run_state.ship_pos))
	for n in pending:
		var cost:=INF
		for settings: HydraTechnique in _moves.values():
			if settings.head_kind==n.kind:cost=minf(cost,float(settings.parameters.cost)*maxf(0.0,table.attack_value[n.row]))
		if cost>budget:continue
		budget-=cost
		_guard_approach.append(n)

func aim_neck(n: Neck, desired: float, dt: float) -> void:
	if dt<=0.0:return
	var offset:=angle_difference(n.angle,desired)
	var accel:=float(def.params.aim_accel)
	var speed:=minf(float(def.params.aim_turn),sqrt(2.0*accel*absf(offset)))
	var velocity:=move_toward(float(n.motion.get("aim_velocity",0.0)),signf(offset)*speed,accel*dt)
	var step:=velocity*dt
	if signf(step)==signf(offset) and absf(step)>absf(offset):step=offset
	n.angle+=step
	n.motion.aim_velocity=step/dt

# ── 首の攻撃（各首の種類ごと） ──────────────────────────────────────

## 首の攻撃の更新。普段は機体の方へゆらゆら向き、間隔ごとに種類ごとの2つの攻撃のどちらかを出す。
## 普段の首の攻撃は予告しない（噛みつきの引き・ビームの溜めなど、首の動きと光で見せる）。
func _attack(neck: Neck, _k: int, dt: float) -> void:
	neck.t+=dt
	match neck.mode:
		&"tech_aim":
			var direction: float=(neck.target-_neck_base(neck)).angle()
			neck.angle=lerp_angle(neck.angle,direction,minf(1.0,dt*6.0))
			neck.length=move_toward(neck.length,float(def.params.neck_rest)*0.35,float(def.params.neck_rest)*dt*2.0)
			neck.glow=minf(1.0,neck.glow+dt*1.5)
		&"tech_lunge":_north_step(neck,minf(1.0,neck.t/_north_duration),dt)

func _end(neck: Neck, interrupted := false) -> void:
	# 伸びた頭をその場に残し、攻めどきが終わってから通常の長さへ戻す。
	if tech == &"north" and neck.mode in [&"tech_lunge", &"tech_hold"]:
		var offset := neck.strike_pos - _neck_base(neck)
		neck.angle = offset.angle()
		neck.length = offset.length()
	if neck.mode != &"idle" and not String(neck.mode).begins_with("tech_"):
		_cue(&"interrupted" if interrupted else &"finished", neck.mode, necks.find(neck))
	if String(neck.mode).begins_with("special_"):
		var delta := neck.strike_pos-_neck_base(neck)
		neck.angle=delta.angle()
		neck.length=delta.length()
		neck.free_pos=neck.strike_pos
		neck.locked=false
	neck.mode = &"idle"
	neck.t = 0.0
	neck.step = 0
	neck.glow = 0.0

## 首の攻撃の後片付け（頭が落ちたとき）。
func _release_attack(neck: Neck) -> void:
	if ctx.projectiles.director!=null and not _alive(neck):ctx.projectiles.director.cancel_attack("neck:"+str(neck.row_id),neck.row_id)
	if attack_field != null: attack_field.remove_owner(neck.row)
	if neck.hazard >= 0:
		if ctx.projectiles.owns_hazard(neck.hazard, neck.row, neck.row_id):
			ctx.projectiles.release_hazard(neck.hazard)
		neck.hazard = -1
	neck.glow = 0.0

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
	bb.set_var(&"exposed", false)
	bb.set_var(&"recovering", recovery_t > 0.0)

## 条件評価は読み取りだけ。攻撃枠は選択後に取得する。
func attack_ready(attack: StringName) -> bool:
	if tech==attack:return true
	if not TECH_DIR.has(attack) or busy or timeline.is_playing() or chance_t>0.0 or growth_t>0.0 or separation_pending or recovery_t>0.0:return false
	if COMBOS.has(attack):
		if combo_wait>0.0:return false
	elif _tech_cd>0.0:return false
	return _time>=float(_tech_until.get(attack,0.0)) and _tech_ok(attack) and _position_ready(attack)

func combo_heads(kinds: Array) -> Array[Neck]:
	var result: Array[Neck]=[]
	for kind in kinds:
		var found: Neck
		for n in necks:
			if _alive(n) and n.kind==kind and n.mode==&"idle" and not result.has(n):
				found=n
				break
		if found==null:return []
		result.append(found)
	return result

func try_start_tech(attack: StringName, cooldown_scale: float) -> bool:
	if busy or not attack_ready(attack):
		return false
	if not timeline.has_animation(attack):return false
	var director=ctx.projectiles.director
	if director!=null and not director.formation_mode and not director.request("boss:"+str(table.id[body]),["dash","beam","zone","aimed"],body,table.id[body],12.0,1.5,float(move_params(attack).major_cost)):
		return false
	if attack in [&"north",&"sequence"]: participants = front_heads()
	elif attack in [&"curve",&"swarm",&"grid"]: participants.assign(necks.filter(func(n):return _alive(n)))
	elif COMBOS.has(attack):
		participants=combo_heads({&"tornado": [&"vortex",&"debris"],&"debris_shatter": [&"debris",&"beam"],&"beam_pincer": [&"beam",&"beam"]}[attack])
		combo_wait=float(def.params.combo_cooldown)
	tech = attack
	_cooldown_scale = cooldown_scale
	last_tech_result = &""
	busy = true
	for neck in necks:
		_release_attack(neck)
		_end(neck, true)
	_configure_tech_timeline(attack)
	timeline.play("configured/"+String(tech))
	timeline.advance(0.0)
	if special.positioning:timeline.pause()
	return true

func attack_playing() -> bool:
	return busy

## BT の中断と部位喪失で共通の後片付けを行う。
func interrupt_tech(attack: StringName = &"") -> void:
	if attack != &"" and tech != &"" and tech != attack:
		return
	if ctx.projectiles.director != null:
		ctx.projectiles.director.cancel_attack("boss:" + str(table.id[body]), table.id[body])
	if not busy:
		return
	timeline.stop()
	last_tech_result = &"interrupted"
	tech_end()

## 制限時間の一撃（仕様書 4.1）。全ての首・蛇が機体へ向いて光を溜め、溜め終わりに戦闘エリアを光で埋める。
## 当たりの判定は RunSimulation が溜めの終わりに行う。溜めの間はボスを無敵にし、ほかの攻撃と判断を止める。
func begin_final_strike(charge: float) -> void:
	if final_strike_t >= 0.0:
		return
	final_strike_t = 0.0
	_final_start = run_state.time
	_final_charge = maxf(0.1, charge)
	hsm.set_active(false)
	interrupt_tech()
	growth_t = 0.0
	separation_t = 0.0
	for n in _final_necks():
		_end(n, true)
		_release_attack(n)
	attack_field.clear_effects()
	_final_beams.clear()
	_cue(&"final_strike_started")

func _final_necks() -> Array[Neck]:
	var result: Array[Neck] = []
	for n in necks:
		if _alive(n): result.append(n)
	if separated and immortal_neck != null and immortal_row >= 0 and table.dead[immortal_row] == 0:
		result.append(immortal_neck)
	return result

func _final_strike_tick(dt: float) -> void:
	final_strike_t = run_state.time - _final_start
	var k := clampf(final_strike_t / _final_charge, 0.0, 1.0)
	var widen := clampf((final_strike_t - (_final_charge - float(def.params.final_widen_time))) / float(def.params.final_widen_time), 0.0, 1.0)
	var width := lerpf(float(def.params.final_warn_width), float(def.params.final_beam_width), widen * widen)
	var reach := Vector2(def.params.arena_size).length() * 1.5
	var ship := run_state.ship_pos
	table.guard[body] = 1.0
	for n in _final_necks():
		table.guard[n.row] = 1.0
		if separated:
			n.velocity = Vector2.ZERO
			n.angle = lerp_angle(n.angle, (ship - n.free_pos).angle(), minf(1.0, dt * 6.0))
		else:
			aim_neck(n, (ship - _neck_base(n)).angle(), dt)
			n.length = move_toward(n.length, float(def.params.neck_rest), float(def.params.neck_rest) * dt)
		n.glow = k
		table.pos[n.row] = _head_pos(n)
		table.facing[n.row] = n.angle
		_follow_neck(n, dt)
		var head: Vector2 = table.pos[n.row]
		var points := PackedVector2Array([head, head + (ship - head).normalized() * reach])
		if not _final_beams.has(n.row_id):
			_final_beams[n.row_id] = attack_field.add_shape(points, width, maxf(0.0, _final_charge - float(def.params.final_widen_time) - final_strike_t),
				_final_charge + 10.0, 0.0, &"beam", n.row, Vector2.ZERO, true)
		var beam: Dictionary = _final_beams[n.row_id]
		beam.points = points
		beam.width = width
	attack_field.tick(dt)

## 技に必要な首：北は噛みつく首、東は瓦礫の首とビームの首、南は渦の首と瓦礫の首、西はビームの首2本。
func _tech_ok(name: StringName) -> bool:
	match name:
		&"grid":
			return separated and (participants.any(func(n):return _alive(n)) if busy else not grid_plan().is_empty())
		&"swarm":
			return separated and (participants.any(func(n):return _alive(n)) if busy else necks.filter(func(n):return _alive(n)).size()>=2)
		&"tornado",&"debris_shatter",&"beam_pincer":
			if busy:return participants.size()==2 and participants.all(func(n):return _alive(n))
			return combo_heads({&"tornado": [&"vortex",&"debris"],&"debris_shatter": [&"debris",&"beam"],&"beam_pincer": [&"beam",&"beam"]}[name]).size()==2
		&"curve":
			return not separated and count>=5 and (participants.any(func(n):return _alive(n)) if busy else necks.filter(func(n):return _alive(n)).size()>=3)
		&"sequence":
			return not separated and count>=5 and (participants.size()==3 and participants.all(func(n):return _alive(n)) if busy else front_heads().size()==3)
		&"north":
			return not separated and count >= 5 and (participants.all(func(n):return _alive(n)) and participants.size()==3 if busy else front_heads().size()==3)
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
	if name in [&"sequence",&"curve",&"swarm",&"grid"] or COMBOS.has(name): special.prepare()
	if name == &"north":
		north_aiming = true
		_update_north_targets()
		for neck in necks:
			if participants.has(neck): neck.mode = &"tech_aim"
	_spin_t = _warning_duration(name) * compass_spin_fraction
	_cue(&"warning_started", name, -1, {"duration": _warning_duration(name)})
	_needle = TECH_DIR.get(name, -PI / 2.0)

## 技の終わり（崩れたときも）。首を普段に戻す。
func special_attack() -> void:
	special.playing=true
	_cue(&"attack_started")

func tech_end() -> void:
	if not busy:
		return
	north_aiming = false
	last_tech = tech
	if last_tech_result == &"":
		last_tech_result = &"finished"
	_tech_until[tech] = _time + float(move_params(tech).cooldown) * _cooldown_scale
	recovery_t = float(move_params(tech).tech_recovery)
	_cue(&"finished" if last_tech_result == &"finished" else &"interrupted")
	_cue(&"recovery_started", tech, -1, {"duration": recovery_t})
	for neck in necks:
		if String(neck.mode).begins_with("tech_") or String(neck.mode).begins_with("special_"):
			_release_attack(neck)
			_end(neck)
	busy = false
	tech = &""
	_tech_cd = float(def.params.tech_cd)
	special.playing=false
	special.positioning=false
	for r in _rubble:
		if ctx.enemies.is_same(r.x, r.y) and table.dead[r.x] == 0:
			ctx.enemies.mark_dead(r.x)
	_rubble.clear()

## 北：予告中は自機周辺を捕捉し、north_curl のキーで狙いを固定する。
func front_heads() -> Array[Neck]:
	var result: Array[Neck] = []
	if count < 5: return result
	var aim := (run_state.ship_pos-table.pos[body]).angle()
	var ordered := necks.duplicate()
	ordered.sort_custom(func(a,b):return absf(angle_difference(a.base_angle+table.facing[body],aim)) < absf(angle_difference(b.base_angle+table.facing[body],aim)))
	for n in ordered:
		if _alive(n) and absf(angle_difference(n.base_angle+table.facing[body],aim)) < float(def.params.north_half_angle)+PI/float(count):
			result.append(n)
		if result.size()==3: break
	return result

func _update_north_targets() -> void:
	north_target = run_state.ship_pos
	var direction := (north_target-table.pos[body]).normalized()
	var side := direction.orthogonal()
	var center := table.pos[body]+direction*maxf(north_target.distance_to(table.pos[body]),table.r[body]+float(def.params.neck_rest))
	var ordered := participants.duplicate()
	ordered.sort_custom(func(a,b):return _neck_base(a).dot(side) < _neck_base(b).dot(side))
	for i in ordered.size():
		ordered[i].target = center+side*float(move_params(&"north").north_spread)*(i-1)

func north_curl() -> void:
	_update_north_targets()
	north_aiming = false
	_cue(&"target_locked", &"north", -1, {"target_position": north_target})

func north_burst() -> void:
	north_aiming = false
	_north_duration = maxf(0.001, _timeline_key_time(&"north", &"north_follow") - _timeline_key_time(&"north", &"north_burst"))
	_cue(&"attack_started")
	for neck in participants:
		if _alive(neck):
			neck.strike_from = _head_pos(neck)
			neck.strike_pos = neck.strike_from
			neck.mode = &"tech_lunge"
			neck.t = 0.0
			neck.angle = (neck.target - neck.strike_from).angle()
			_cue(&"attack_started", &"north", necks.find(neck), {"target_position": neck.target})

## 先端の移動区間にも判定を出し、粗い固定更新で標的位置を飛び越えない。
func _north_step(neck: Neck, fraction: float, dt: float) -> void:
	var previous := neck.strike_pos
	neck.strike_pos = neck.strike_from.lerp(neck.target, fraction)
	_release_attack(neck)
	neck.glow = 1.0
	var delta := neck.strike_pos - previous
	neck.hazard = ctx.projectiles.fire_wall(previous, delta.angle(), delta.length(), float(move_params(&"north").bite_radius) * 2.0,
		0.0, maxf(dt, 0.001) + 0.001, float(move_params(&"north").bite_dmg), Color("#ff7a5a"))
	ctx.projectiles.attach_hazard(neck.hazard, neck.row)
	if fraction >= 1.0:
		neck.mode = &"tech_hold"

## 世界の更新がキーをまたいでも、最後の区間を判定してから止める。
func north_follow() -> void:
	for neck in necks:
		if neck.mode == &"tech_lunge":
			_north_step(neck, 1.0, _sim_dt)

## 瓦礫を砕き、破片を飛ばす。from が 0 でなければ、その向きを中心に飛ばす。
func _burst_rubble(j: int, from: Vector2) -> void:
	var p: Dictionary = move_params(tech)
	var base := from.angle() if from != Vector2.ZERO else run_state.rng.randf() * TAU
	for k in 6:
		ctx.projectiles.fire_enemy(j, base + (k - 2.5) * (0.45 if from != Vector2.ZERO else TAU / 6.0),
			float(p.shard_speed), &"bullet", {"bullet_dmg": float(p.shard_dmg)})
	ctx.enemies.mark_dead(j)

## 技別 Settings から内部イベントを構成する。共有外部ライブラリを変更しない。
func _configure_tech_timeline(attack: StringName) -> void:
	var p := move_params(attack)
	var animation := Animation.new()
	var track := animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(track, NodePath("."))
	animation.track_insert_key(track, 0.0, {"method": &"tech_compass", "args": [attack]})
	var warning := maxf(0.001, float(p.warning_time))
	if attack == &"north":
		animation.track_insert_key(track, clampf(float(p.north_lock_time), 0.0, warning), {"method": &"north_curl", "args": []})
		animation.track_insert_key(track, warning, {"method": &"north_burst", "args": []})
		animation.track_insert_key(track, warning+float(p.north_flight), {"method": &"north_follow", "args": []})
	else:
		animation.track_insert_key(track, warning, {"method": &"special_attack", "args": []})
	var end := warning+maxf(float(p.performance_time), float(p.get("north_flight", 0.0)))
	animation.track_insert_key(track, end, {"method": &"tech_end", "args": []})
	animation.length = end+0.2
	var library := AnimationLibrary.new()
	library.add_animation(attack, animation)
	# The actor owns this library; replacement leaves the template resource untouched.
	if timeline.has_animation_library(&"configured"): timeline.remove_animation_library(&"configured")
	timeline.add_animation_library(&"configured", library)

## 判定タイムラインの実行キーから予告の長さを読む。演出専用のタイマーを正にしない。
func _timeline_key_time(name: StringName, method: StringName) -> float:
	var key := StringName("configured/"+String(name))
	var animation := timeline.get_animation(key if timeline.has_animation(key) else name)
	if animation == null: return 0.0
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD: continue
		for method_key in animation.track_get_key_count(track):
			if animation.method_track_get_name(track, method_key) == method:
				return animation.track_get_key_time(track, method_key)
	return 0.0

func _warning_duration(name: StringName) -> float:
	var method: StringName=&"north_burst" if name==&"north" else &"special_attack"
	return maxf(0.0, _timeline_key_time(name, method) - _timeline_key_time(name, &"tech_compass"))

## -1 は本体、-2 は不死首、0 以上は通常首の配列の添字。戻り値はワールド座標。
func presentation_anchor(index := -1) -> Transform2D:
	if index >= 0 and index < necks.size():
		return Transform2D(necks[index].angle, _head_pos(necks[index]))
	if index == -2 and immortal_row >= 0 and ctx.enemies.is_same(immortal_row, immortal_id):
		return Transform2D(0.0, table.pos[immortal_row])
	return Transform2D(table.facing[body], table.pos[body])

## 予告と実際の判定が共有する標的位置。絵の側から射程を推測しない。
func presentation_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if tech != &"north": return targets
	for i in necks.size():
		if participants.has(necks[i]) and _alive(necks[i]):
			targets.append({"neck_index": i, "base": _neck_base(necks[i]), "from": _head_pos(necks[i]),
				"target": necks[i].target, "radius": float(move_params(&"north").bite_radius), "locked": not north_aiming})
	return targets

func presentation_state() -> Dictionary:
	return {"technique": tech, "busy": busy, "neck_count": count, "exposed": false,
		"north_aiming": north_aiming, "north_target": north_target, "recovery": recovery_t, "defeated": _defeat_announced, "world_time": _time}

func _cue(cue: StringName, attack: StringName = &"", index := -1, details := {}) -> void:
	if ctx == null or not has_body(): return
	var anchor := presentation_anchor(index)
	var head_id := necks[index].row_id if index >= 0 and index < necks.size() else (immortal_id if index == -2 else table.id[body])
	presentation_event.emit({"cue": cue, "technique": attack if attack != &"" else tech,
		"neck_index": index, "part_id": head_id, "kind": necks[index].kind if index >= 0 and index < necks.size() else (&"immortal" if index == -2 else &"body"),
		"position": anchor.origin, "angle": anchor.get_rotation(), "world_time": _time}.merged(details))

# ── 見た目 ────────────────────────────────────────────────────────

func _draw() -> void:
	draw_on(self)
	if ctx != null and has_body():
		# 描画キャッシュはメタデータに置き、実験場の戦闘状態の比較から分ける。
		set_meta(&"draw_radius", table.r[body])

## 実験キャンバスも同じ本体・首・羅針盤を描く。
func draw_on(c: CanvasItem) -> void:
	if ctx == null or not has_body():
		return
	var t := table
	var r := t.r[body]
	if neck_texture==null:
		_draw_neck_mesh(c,r)
	else:
		for neck in necks:
			if neck.row >= 0 or neck.length > 0.0:
				_draw_neck(c, neck.segs, r, Color("#8f8170"), neck.glow if neck.row >= 0 else 0.0)
	if separated:
		if immortal_neck!=null:
			if neck_texture!=null:_draw_neck(c,immortal_neck.segs,110.0,Color("#c9a64a"),0.0)
			_draw_compass(c,52.0)
		return
	if body_texture!=null:c.draw_texture_rect(body_texture,Rect2(Vector2.ONE*-r,Vector2.ONE*r*2.0),false)
	else:c.draw_circle(Vector2.ZERO, r, Color("#5b4f45") if t.flash[body] <= 0.0 else Color("#fff4e0"))
	c.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color("#2e2722"), 4.0)
	_draw_compass(c, r * 0.75)

## 仮の首の節・継ぎ目・ハイライトを一枚へまとめ、色と重なり順を保つ。
func _draw_neck_mesh(c: CanvasItem,radius: float)->void:
	if _neck_mesh_dirty or _neck_mesh_origin!=table.pos[body] or _neck_mesh_radius!=radius:
		var vertices:=PackedVector2Array()
		var colors:=PackedColorArray()
		var indices:=PackedInt32Array()
		for neck in necks:
			if neck.row>=0 or neck.length>0.0:_append_neck_mesh(neck.segs,radius,Color("#8f8170"),vertices,colors,indices)
		if separated and immortal_neck!=null:_append_neck_mesh(immortal_neck.segs,110.0,Color("#c9a64a"),vertices,colors,indices)
		_neck_mesh=null
		if not vertices.is_empty():
			var arrays:=[]
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices
			arrays[Mesh.ARRAY_COLOR]=colors
			arrays[Mesh.ARRAY_INDEX]=indices
			_neck_mesh=ArrayMesh.new()
			_neck_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		_neck_mesh_dirty=false
		_neck_mesh_origin=table.pos[body]
		_neck_mesh_radius=radius
	if _neck_mesh!=null:c.draw_mesh(_neck_mesh,null)
	for neck in necks:
		if neck.row>=0 and neck.glow>0.0 and not neck.segs.is_empty():
			c.draw_circle(neck.segs[-1]-table.pos[body],radius*0.5,Color(1.0,0.85,0.5,0.45*neck.glow))

func _append_neck_mesh(segs: PackedVector2Array,radius: float,col: Color,vertices: PackedVector2Array,colors: PackedColorArray,indices: PackedInt32Array)->void:
	var previous:=Vector2.ZERO
	var dark:=col.darkened(0.15)
	for i in segs.size():
		var at:=segs[i]-table.pos[body]
		var size:=radius*(0.32-0.14*float(i)/segs.size())
		if i>0:_append_neck_line(previous,at,size*2.0,col,vertices,colors,indices)
		var polygon:=PackedVector2Array()
		for corner in 8:polygon.append((at+Vector2.from_angle(float(corner)*TAU/8.0)*size).snapped(Vector2(3,3)))
		_append_neck_polygon(polygon,col if i%2==0 else dark,vertices,colors,indices)
		_append_neck_line(at+Vector2(-size*0.5,-size*0.4),at+Vector2(size*0.4,-size*0.4),3.0,col.lightened(0.2),vertices,colors,indices)
		previous=at

func _append_neck_line(a: Vector2,b: Vector2,width: float,col: Color,vertices: PackedVector2Array,colors: PackedColorArray,indices: PackedInt32Array)->void:
	var side:=(b-a).normalized().orthogonal()*width*0.5
	_append_neck_polygon(PackedVector2Array([a+side,b+side,b-side,a-side]),col,vertices,colors,indices)

func _append_neck_polygon(points: PackedVector2Array,col: Color,vertices: PackedVector2Array,colors: PackedColorArray,indices: PackedInt32Array)->void:
	var start:=vertices.size()
	vertices.append_array(points)
	for i in points.size():colors.append(col)
	for i in range(1,points.size()-1):indices.append_array(PackedInt32Array([start,start+i,start+i+1]))

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
		if neck_texture!=null:
			var facing: float=(at-previous).angle() if s>0 else 0.0
			c.draw_set_transform(at,facing)
			c.draw_texture_rect(neck_texture,Rect2(Vector2.ONE*-size,Vector2.ONE*size*2.0),false)
			c.draw_set_transform(Vector2.ZERO)
		else:
			var polygon:=PackedVector2Array()
			for corner in 8:polygon.append((at+Vector2.from_angle(float(corner)*TAU/8.0)*size).snapped(Vector2(3,3)))
			c.draw_colored_polygon(polygon,col if s%2==0 else dark)
			c.draw_line(at+Vector2(-size*0.5,-size*0.4),at+Vector2(size*0.4,-size*0.4),col.lightened(0.2),3.0)
		previous = at
	if glow > 0.0 and not segs.is_empty():
		c.draw_circle(previous, body_r * 0.5, Color(1.0, 0.85, 0.5, 0.45 * glow))

## 本体に埋め込まれた羅針盤。強めの技の前だけ針が回る（強めの技で使う）。
func _draw_compass(c: CanvasItem, R: float) -> void:
	if compass_texture!=null:
		c.draw_texture_rect(compass_texture,Rect2(Vector2.ONE*-R,Vector2.ONE*R*2.0),false)
		return
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


## 瓦礫破壊を勝利と分け、全快した独立蛇へ所有権を引き継ぐ。
func begin_separation()->void:
	if separated:return
	interrupt_tech()
	attack_field.clear_effects()
	_set_count(count)
	for n in necks:n.free_pos=_head_pos(n)
	separated=true
	separation_pending=false
	chance_t=0.0
	separation_t=float(def.params.separation_time)
	table.gate[body]=EnemyTable.Gate.GHOST
	immortal_neck=Neck.new()
	immortal_neck.kind=&"immortal"
	immortal_neck.free_pos=table.pos[body]
	immortal_neck.angle=(table.pos[body]-run_state.ship_pos).angle()
	immortal_row=ctx.enemies.spawn_part(body,ctx.enemies.def_of(&"hydra_immortal"),immortal_neck.free_pos)
	immortal_id=table.id[immortal_row]
	immortal_neck.row=immortal_row
	immortal_neck.row_id=immortal_id
	immortal_neck.cd=float(def.params.attack_cd)
	var hp: float=float(def.params.immortal_hp)*ctx.cfg.enemy_hp_mult
	table.max_hp[immortal_row]=hp
	table.hp[immortal_row]=hp
	table.gate[immortal_row]=EnemyTable.Gate.NONE
	table.armor[immortal_row]=0.0
	table.max_hp[body]=hp
	table.hp[body]=hp
	table.guard[immortal_row]=separation_t
	_cue(&"separation_started",&"",-2,{"duration":separation_t})

func tick_bearer(dt: float)->void:
	if immortal_row<0 or not ctx.enemies.is_same(immortal_row,immortal_id) or table.dead[immortal_row]:
		table.hp[body]=0.0
		return
	var n:=immortal_neck
	if n.head_hp>table.hp[immortal_row]:
		n.motion.hit=0.35
		_cue(&"hit",&"immortal",-2,{"target":&"hydra","damage":n.head_hp-table.hp[immortal_row]})
	n.head_hp=table.hp[immortal_row]
	var alone:=necks.all(func(head):return not _alive(head))
	if alone and n.mode!=&"idle":
		n.t+=dt
		NORMALS.tick(self,n,dt)
	elif alone and n.cd<=0.0:
		n.mode=&"bite_thrust"
		n.t=0.0
		n.locked=false
		n.step=0
		n.target=run_state.ship_pos
		_cue(&"warning_started",&"bite_thrust",-2)
	else:
		n.cd=maxf(0.0,n.cd-dt)
		var away: Vector2=(n.free_pos-run_state.ship_pos).normalized()
		if away==Vector2.ZERO:away=Vector2.LEFT
		var target: Vector2=run_state.ship_pos+away.rotated(sin(_time*0.7)*0.6)*float(def.params.bearer_distance)
		var grid_hold: bool=busy and tech==&"grid" and special.state.has("plan")
		if grid_hold:target=special.state.plan.bearer
		target=arena.clamp_point(target,table.r[n.row]+12.0 if grid_hold else float(def.params.neck_rest)+60.0)
		if grid_hold and n.free_pos.distance_to(target)<45.0:
			n.free_pos=n.free_pos.lerp(target,1.0-exp(-4.0*dt))
			n.velocity=Vector2.ZERO
		else:steer_snake(n,target,dt,float(def.params.bearer_speed)/float(def.params.snake_speed),grid_hold)
	var at:=_head_pos(n)
	table.pos[immortal_row]=at
	table.facing[immortal_row]=n.angle
	table.pos[body]=at
	table.hp[body]=table.hp[immortal_row]

func health_row()->int:
	return immortal_row if separated and ctx.enemies.is_same(immortal_row,immortal_id) else body

func head_index(n: Neck)->int:
	return -2 if n==immortal_neck else necks.find(n)

func grid_plan()->Dictionary:
	if not separated or immortal_row<0:return {}
	var maximum: float=ctx.cfg.draw_length*run_state.stats.capacity*run_state.stats.length_mult*run_state.stats.max_speed/ctx.cfg.base_max_speed
	var plan: Dictionary=GRID.build(run_state.view_rect().intersection(arena.bounds),run_state.ship_pos,necks.filter(func(n):return _alive(n)).size(),def.params,ctx.cfg.ship_radius,maximum)
	if plan.is_empty():return plan
	var head_radius:=0.0
	for n in necks:
		if _alive(n):head_radius=maxf(head_radius,table.r[n.row])
	# 天体の中の配置へ泳ぎ続ける大技を選ばず、通常戦闘と別の技を続ける。
	for obstacle in ctx.field.bodies:
		if Vector2(plan.bearer).distance_to(obstacle.pos)<obstacle.r+table.r[immortal_row]:return {}
		for beam in plan.beams:
			if Vector2(beam[0]).distance_to(obstacle.pos)<obstacle.r+head_radius:return {}
		for i in range(1,plan.path.size()):
			if Geom.seg_circle_t(plan.path[i-1],plan.path[i],obstacle.pos,obstacle.r+ctx.cfg.ship_radius)>=0.0:return {}
	return plan

## 通常移動は胴の長さぶん手前で回り込み、陣形への移動は指定された内側の配置へ進む。
func steer_snake(n: Neck, target: Vector2, dt: float, speed_scale:=1.0, formation:=false) -> void:
	var radius: float=table.r[n.row]
	var margin:=radius+12.0 if formation else float(def.params.neck_rest)+radius+24.0
	var from: Vector2=arena.safe_point(n.free_pos,radius+1.0)
	n.free_pos=from
	var destination: Vector2=arena.safe_point(target,margin)
	# 障害物へ直進して停止する代わりに、その手前から表面に沿って回り込む。
	for obstacle in ctx.field.bodies:
		var clearance: float=obstacle.r+radius+60.0
		if from.distance_to(obstacle.pos)<clearance+120.0 and Geom.seg_circle_t(from,destination,obstacle.pos,clearance)>=0.0:
			var outward: Vector2=(from-obstacle.pos).normalized()
			if outward.is_zero_approx():outward=Vector2.RIGHT
			var turn:=signf(outward.cross(destination-obstacle.pos))
			if turn==0.0:turn=1.0
			destination=arena.safe_point(obstacle.pos+outward.rotated(turn*0.6)*clearance,radius+1.0)
			break
	SNAKE.steer(n,destination,dt,def.params,speed_scale)
	table.pos[n.row]=n.free_pos
	table.vel[n.row]=n.velocity
	ctx.field.collide_enemy(n.row,from)
	n.free_pos=arena.safe_point(table.pos[n.row],radius+1.0)
	n.velocity=table.vel[n.row]
	var inside: Vector2=arena.clamp_point(n.free_pos,radius)
	if inside!=n.free_pos:
		var inward: Vector2=(inside-n.free_pos).normalized()
		n.velocity-=inward*minf(0.0,n.velocity.dot(inward))
		n.free_pos=inside
