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

## Hydra 内の演出契約。判定を変えず、技 ID と取り付け位置を受け取る。
signal presentation_event(event: Dictionary)
signal presentation_advanced(world_dt: float)
@export var presentation_scene: PackedScene
@export_range(0.0, 1.0) var compass_spin_fraction := 0.5
var _presentation: Node
var _defeat_announced := false

const GRID := preload("res://scripts/bosses/hydra_grid.gd")
const SNAKE := preload("res://scripts/bosses/hydra_snake_motion.gd")
const NORMALS := preload("res://scripts/bosses/hydra_normals.gd")
const HEAD_BT := preload("res://scenes/bosses/hydra_head_bt.tres")
var special: RefCounted
var attack_field: Node2D
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
		return immortal_row>=0 and manager.enemies.is_same(immortal_row,immortal_id) and table.dead[immortal_row]==0
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
const TECH_DIR := {&"grid": 0.0, &"swarm": -PI/2.0, &"tornado": PI/2.0, &"debris_shatter": 0.0, &"beam_pincer": PI, &"curve": PI/2.0, &"sequence": 0.0, &"north": -PI / 2.0, &"east": 0.0, &"south": PI / 2.0, &"west": PI}

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
var _awaiting_regrowth := false
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

func _on_bound() -> void:
	# 手動の固定更新中に技の処理を確定し、描画フレームへ持ち越さない。
	timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	draws_self = true
	table.gate[body] = EnemyTable.Gate.NONE
	# 本体と首は、敵（頭）の下、地形の上に描く（RenderManager の描画の層の enemies の下）
	z_index = 5
	if presentation_scene != null:
		_presentation = presentation_scene.instantiate()
		add_child(_presentation)
		if _presentation.has_method("bind_hydra"):
			_presentation.bind_hydra(self)
	attack_field = load("res://scripts/bosses/hydra_attack_field.gd").new()
	add_child(attack_field)
	attack_field.bind(self)
	special=load("res://scripts/bosses/hydra_techniques.gd").new(self)
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
	_sim_dt = dt
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
	_expose_cd = maxf(0.0, _expose_cd - dt)
	# 全滅を先に確定する。同じ更新で期限が来た頭を先に生やさない。
	_chance_step(dt)
	if north_aiming:
		_update_north_targets()
	for k in necks.size():
		_tick_neck(necks[k], k, dt)
	_tech_cd -= dt
	combo_wait=maxf(0.0,combo_wait-dt)
	_spin_t -= dt
	_update_blackboard()
	hsm.update(dt)
	if manager.projectiles.director != null:
		manager.projectiles.lab_context = manager.projectiles.director.token("boss:" + str(table.id[body]))
	if busy and special.positioning:
		if special.position(dt):timeline.play()
	if timeline.is_playing():
		timeline.advance(dt)
		if tech != &"" and not _tech_ok(tech):
			# 先に片方の首を落とされた：技が崩れる
			interrupt_tech()
		if busy and tech in [&"sequence",&"curve",&"tornado",&"debris_shatter",&"beam_pincer",&"swarm",&"grid"]: special.tick(dt)
		elif tech == &"east":
			_shatter_on_beams()
	if table.hp[body] <= 0.0 and separated and not _defeat_announced:
		_defeat_announced = true
		hsm.set_active(false)
		interrupt_tech()
		for neck in necks:
			_release_attack(neck)
			if _alive(neck):manager.enemies.mark_dead(neck.row)
		attack_field.clear_effects()
		_cue(&"defeated")
		manager.on_boss_defeated(body, {"cause": &"ram"})
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
	if busy and tech == &"north" and north_aiming:
		var slot := TAU/float(count)
		var wanted := d.angle()-roundf((d.angle()-t.facing[i])/slot)*slot
		t.facing[i] = rotate_toward(t.facing[i],wanted,def.turn*dt)
	var swimming := dist > float(p.engage) and not busy and exposed_t <= 0.0 and recovery_t <= 0.0
	var want := d / dist * def.speed if swimming else Vector2.ZERO
	t.vel[i] += (want - t.vel[i]) * minf(1.0, def.accel * dt)
	if busy or exposed_t > 0.0 or recovery_t > 0.0:
		t.vel[i] = Vector2.ZERO
	# 構えている間は胴体の向きを保ち、狙いは首先で表す。
	if swimming:
		t.facing[i] += clampf(Geom.angle_diff(d.angle(), t.facing[i]), -def.turn * dt, def.turn * dt)
	var from := t.pos[i]
	t.pos[i] += t.vel[i] * dt
	manager.field.collide_enemy(i, from)
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
		if neck.row >= 0 and _alive(neck):
			_release_attack(neck)
			manager.enemies.mark_dead(neck.row)
			neck.row = -1
		neck.base_angle = TAU * k / float(n)
		neck.burned = false
		if neck.row < 0:
			neck.regrow = 0.0
			_grow(neck)

## 首の頭を生やす。
func _grow(neck: Neck) -> void:
	_awaiting_regrowth = false
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
	if neck.mode in [&"special_aim",&"special_hold"]: return neck.strike_pos
	if tech == &"north" and neck.mode in [&"tech_lunge", &"tech_hold"]:
		return neck.strike_pos
	if neck.locked and def.params.normal_rules.has(neck.mode): return neck.strike_pos
	if separated:return neck.free_pos
	return _neck_base(neck) + Vector2.from_angle(neck.angle) * neck.length

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
		if def.params.normal_rules.has(neck.mode):
			neck.t += dt
			NORMALS.tick(self,neck,dt)
		elif neck.mode == &"idle":
			neck.cd = maxf(0.0,neck.cd-dt)
			if not busy and recovery_t <= 0.0 and chance_t <= 0.0: neck.bt.execute(dt)
		elif not String(neck.mode).begins_with("special_"): _attack(neck,k,dt)
		table.pos[neck.row] = _head_pos(neck)
		table.facing[neck.row] = neck.angle
	if neck.row >= 0 or neck.length > 0.0:
		_follow_neck(neck, dt)

## 頭が落ちた：首の残骸を破片にして飛ばし、生え直す時間を決める。
## 1本の線でまとめて落とした本数が多いほど、生え直しが少しだけ遅くなる。火で落ちた頭は次の段階まで生え直さない。
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
	manager.projectiles.burst_debris(table.pos[head], 8, 700.0, float(p.debris_dmg) * manager.cfg.atk_scale,
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
	if separated:
		SNAKE.follow(neck,_head_pos(neck),dt,_time,def.params)
		return
	var rest := float(def.params.neck_rest)
	if neck.row < 0:
		rest = minf(rest, neck.length)
	NECK_CHAIN.update(neck.segs, _neck_base(neck), _head_pos(neck), rest,
		neck.base_angle * 2.4, _time, dt, def.params)
	if not separated: NECK_CHAIN.keep_outside(neck.segs,table.pos[body],table.r[body])

# ── 不死の首 ──────────────────────────────────────────────────────

## 普段の頭を全部落とすと不死の首が露出し、貫くと次の段階へ進む。
func _try_expose() -> void:
	if exposed_t > 0.0 or _expose_cd > 0.0 or _awaiting_regrowth or necks.is_empty(): return
	for neck in necks:
		if _alive(neck): return
	_expose()

func _tick_immortal(dt: float) -> void:
	var p: Dictionary = def.params
	if exposed_t <= 0.0:
		_try_expose()
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
	_expose_cd = 0.0
	_awaiting_regrowth = false
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
		# 失敗直後にも通常の猶予を残す。再生が済むまで次の露出の判定を待つ。
		_expose_cd = float(def.params.regrow)
		for neck in necks:
			if not neck.burned:
				neck.regrow = float(def.params.regrow)
				_awaiting_regrowth = true

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
	_cue(&"exposed", &"immortal", -2)
	run_state.emit(&"text", {"pos": table.pos[body] + Vector2(0, -table.r[body] - 40.0), "text": "!", "color": Color("#ffe46b"), "size": 48})


func normal_ready(index: int, attack: StringName) -> bool:
	if index < 0 or index >= necks.size() or not def.params.normal_rules.has(attack): return false
	var n := necks[index]
	var rule: Dictionary = def.params.normal_rules[attack]
	if not _alive(n) or n.kind != rule.kind or n.mode != &"idle" or n.cd > 0.0: return false
	if busy or recovery_t > 0.0 or chance_t > 0.0 or growth_t > 0.0 or separation_pending: return false
	var at := _head_pos(n)
	if not run_state.view_rect().grow(-table.r[n.row]).has_point(at): return false
	var offset := run_state.ship_pos-at
	if offset.length() < rule.min or offset.length() > rule.max: return false
	if not separated and absf(angle_difference(n.base_angle+table.facing[body],(run_state.ship_pos-_neck_base(n)).angle())) > 1.25: return false
	var used := 0.0
	for other in necks:
		if def.params.normal_rules.has(other.mode): used += float(def.params.normal_rules[other.mode].cost)
	return used + float(rule.cost) <= float(def.params.normal_budget)

func start_normal(index: int, attack: StringName) -> bool:
	if not normal_ready(index,attack): return false
	var n := necks[index]
	if not manager.admit("neck:"+str(n.row_id),["dash"],n.row,4.0): return false
	n.mode = attack
	n.t = 0.0
	n.locked = false
	n.step = 0
	n.emission.clear()
	_cue(&"warning_started",attack,index)
	return true

func finish_normal(n: Neck) -> void:
	var at := _head_pos(n)
	_release_attack(n)
	n.angle = (at-_neck_base(n)).angle()
	n.length = at.distance_to(_neck_base(n))
	n.free_pos=at
	n.locked = false
	n.mode = &"idle"
	n.cd = float(def.params.attack_cd)
	_cue(&"finished",&"",head_index(n))

func position_head(index: int, dt: float) -> void:
	var n := necks[index]
	if separated:
		var center: Vector2=table.pos[immortal_row] if immortal_row>=0 else run_state.ship_pos
		var desired: Vector2=center+Vector2.from_angle(n.base_angle+_time*0.12)*float(def.params.guard_radius)
		if not run_state.view_rect().grow(-60.0).has_point(n.free_pos):desired=run_state.view_rect().get_center()+Vector2.from_angle(n.base_angle)*minf(run_state.view_half.x,run_state.view_half.y)*0.65
		SNAKE.steer(n,desired,dt,def.params)
		return
	var facing := n.base_angle+table.facing[body]
	n.angle = lerp_angle(n.angle,facing+sin(_time+n.base_angle)*0.15,minf(1.0,dt*2.0))
	n.length = move_toward(n.length,float(def.params.neck_rest),float(def.params.neck_rest)*dt)

# ── 首の攻撃（各首の種類ごと） ──────────────────────────────────────

## 首の攻撃の更新。普段は機体の方へゆらゆら向き、間隔ごとに種類ごとの2つの攻撃のどちらかを出す。
## 普段の首の攻撃は予告しない（噛みつきの引き・ビームの溜めなど、首の動きと光で見せる）。
func _attack(neck: Neck, _k: int, dt: float) -> void:
	var p: Dictionary = def.params
	var owner := "neck:" + str(neck.row_id)
	if manager.projectiles.director != null:
		manager.projectiles.lab_context = manager.projectiles.director.token(owner)
	var aim := (run_state.ship_pos - _neck_base(neck)).angle()
	if neck.mode == &"idle":
		# 旧追尾首は弱点として残す。追尾弾は発射しない。
		if neck.kind == &"homing" or chance_t > 0.0 or growth_t > 0.0 or recovery_t > 0.0:
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
			_cue(&"warning_started", neck.mode, necks.find(neck))
		return
	neck.t += dt
	match neck.mode:
		&"tech_aim":
			var direction := (neck.target - _neck_base(neck)).angle()
			neck.angle = lerp_angle(neck.angle, direction, minf(1.0, dt * 6.0))
			neck.length = move_toward(neck.length, float(p.neck_rest) * 0.35, float(p.neck_rest) * dt * 2.0)
			neck.glow = minf(1.0, neck.glow + dt * 1.5)
		&"tech_lunge":
			_north_step(neck, minf(1.0, neck.t / _north_duration), dt)
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
			_cue(&"attack_started", neck.mode, necks.find(neck))
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
		_cue(&"attack_started", neck.mode, necks.find(neck))
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
	_cue(&"attack_started", neck.mode, necks.find(neck))
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
			_cue(&"attack_started", neck.mode, necks.find(neck), {"damage_delay": 0.45})
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
		_cue(&"attack_started", neck.mode, necks.find(neck))
	neck.angle += 2.2 / sweep * dt
	neck.glow = 1.0
	if neck.hazard >= 0:
		manager.projectiles.move_hazard(neck.hazard, _head_pos(neck), neck.angle)
	if neck.t >= charge + sweep:
		_release_attack(neck)
		_end(neck)

## 首の攻撃の後片付け（頭が落ちたとき）。
func _release_attack(neck: Neck) -> void:
	if attack_field != null: attack_field.remove_owner(neck.row)
	if neck.hazard >= 0:
		if manager.projectiles.owns_hazard(neck.hazard, neck.row, neck.row_id):
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
	if tech==attack:return true
	if not TECH_DIR.has(attack) or busy or timeline.is_playing() or chance_t>0.0 or growth_t>0.0 or separation_pending or recovery_t>0.0:return false
	if COMBOS.has(attack):
		if combo_wait>0.0:return false
	elif _tech_cd>0.0:return false
	return _time>=float(_tech_until.get(attack,0.0)) and _tech_ok(attack)

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
	if not manager.admit("boss:" + str(table.id[body]), ["dash", "beam", "zone", "aimed"], body, 12.0):
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
	timeline.play(tech)
	timeline.advance(0.0)
	if special.positioning:timeline.pause()
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
	_tech_until[tech] = _time + float(def.params.get(String(tech)+"_cooldown",def.params.combo_cooldown if COMBOS.has(tech) else def.params.tech_cd)) * _cooldown_scale
	recovery_t = float(def.params.tech_recovery)
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
		if manager.enemies.is_same(r.x, r.y) and table.dead[r.x] == 0:
			manager.enemies.mark_dead(r.x)
	_rubble.clear()

## 北：予告中は自機周辺を捕捉し、north_curl のキーで狙いを固定する。
func front_heads() -> Array[Neck]:
	var result: Array[Neck] = []
	if count < 5: return result
	var aim := (run_state.ship_pos-table.pos[body]).angle()
	var ordered := necks.duplicate()
	ordered.sort_custom(func(a,b):return absf(angle_difference(a.base_angle+table.facing[body],aim)) < absf(angle_difference(b.base_angle+table.facing[body],aim)))
	for n in ordered:
		if _alive(n) and absf(angle_difference(n.base_angle+table.facing[body],aim)) < float(def.params.north_half_angle):
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
		ordered[i].target = center+side*float(def.params.north_spread)*(i-1)

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
	neck.hazard = manager.projectiles.fire_wall(previous, delta.angle(), delta.length(), float(def.params.bite_radius) * 2.0,
		0.0, maxf(dt, 0.001) + 0.001, float(def.params.bite_dmg), Color("#ff7a5a"))
	manager.projectiles.attach_hazard(neck.hazard, neck.row)
	if fraction >= 1.0:
		neck.mode = &"tech_hold"

## 世界の更新がキーをまたいでも、最後の区間を判定してから止める。
func north_follow() -> void:
	for neck in necks:
		if neck.mode == &"tech_lunge":
			_north_step(neck, 1.0, _sim_dt)

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
	_cue(&"attack_started")
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
	_cue(&"attack_started")
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
	_cue(&"attack_started", tech, necks.find(neck))

## 判定タイムラインの実行キーから予告の長さを読む。演出専用のタイマーを正にしない。
func _timeline_key_time(name: StringName, method: StringName) -> float:
	var animation := timeline.get_animation(name)
	if animation == null: return 0.0
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD: continue
		for key in animation.track_get_key_count(track):
			if animation.method_track_get_name(track, key) == method:
				return animation.track_get_key_time(track, key)
	return 0.0

func _warning_duration(name: StringName) -> float:
	var method: StringName = {&"sequence": &"special_attack", &"curve": &"special_attack", &"north": &"north_burst", &"east": &"east_sweep", &"west": &"west_sweep"}.get(name, &"")
	return maxf(0.0, _timeline_key_time(name, method) - _timeline_key_time(name, &"tech_compass"))

## -1 は本体、-2 は不死首、0 以上は通常首の配列の添字。戻り値はワールド座標。
func presentation_anchor(index := -1) -> Transform2D:
	if index >= 0 and index < necks.size():
		return Transform2D(necks[index].angle, _head_pos(necks[index]))
	if index == -2 and immortal_row >= 0 and manager.enemies.is_same(immortal_row, immortal_id):
		return Transform2D(0.0, table.pos[immortal_row])
	return Transform2D(table.facing[body], table.pos[body])

## 予告と実際の判定が共有する標的位置。絵の側から射程を推測しない。
func presentation_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if tech != &"north": return targets
	for i in necks.size():
		if participants.has(necks[i]) and _alive(necks[i]):
			targets.append({"neck_index": i, "base": _neck_base(necks[i]), "from": _head_pos(necks[i]),
				"target": necks[i].target, "radius": float(def.params.bite_radius), "locked": not north_aiming})
	return targets

func presentation_state() -> Dictionary:
	return {"technique": tech, "busy": busy, "neck_count": count, "exposed": exposed_t > 0.0,
		"north_aiming": north_aiming, "north_target": north_target, "recovery": recovery_t, "defeated": _defeat_announced, "world_time": _time}

func _cue(cue: StringName, attack: StringName = &"", index := -1, details := {}) -> void:
	if manager == null or not manager.has_boss(): return
	var anchor := presentation_anchor(index)
	var head_id := necks[index].row_id if index >= 0 and index < necks.size() else (immortal_id if index == -2 else table.id[body])
	presentation_event.emit({"cue": cue, "technique": attack if attack != &"" else tech,
		"neck_index": index, "part_id": head_id, "kind": necks[index].kind if index >= 0 and index < necks.size() else (&"immortal" if index == -2 else &"body"),
		"position": anchor.origin, "angle": anchor.get_rotation(), "world_time": _time}.merged(details))

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
	if separated:
		if immortal_neck!=null:
			_draw_neck(c,immortal_neck.segs,110.0,Color("#c9a64a"),0.0)
			_draw_compass(c,52.0)
		return
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
	immortal_row=manager.enemies.spawn_part(body,manager.enemies.def_of(&"hydra_immortal"),immortal_neck.free_pos)
	immortal_id=table.id[immortal_row]
	immortal_neck.row=immortal_row
	immortal_neck.row_id=immortal_id
	immortal_neck.cd=float(def.params.attack_cd)
	var hp: float=float(def.params.immortal_hp)*manager.cfg.enemy_hp_mult
	table.max_hp[immortal_row]=hp
	table.hp[immortal_row]=hp
	table.gate[immortal_row]=EnemyTable.Gate.NONE
	table.max_hp[body]=hp
	table.hp[body]=hp
	table.guard[immortal_row]=separation_t
	_cue(&"separation_started",&"",-2,{"duration":separation_t})

func tick_bearer(dt: float)->void:
	if immortal_row<0 or not manager.enemies.is_same(immortal_row,immortal_id) or table.dead[immortal_row]:
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
		_cue(&"warning_started",&"bite_thrust",-2)
	else:
		n.cd=maxf(0.0,n.cd-dt)
		var away: Vector2=(n.free_pos-run_state.ship_pos).normalized()
		if away==Vector2.ZERO:away=Vector2.LEFT
		var target: Vector2=run_state.ship_pos+away.rotated(sin(_time*0.7)*0.6)*float(def.params.bearer_distance)
		var grid_hold: bool=busy and tech==&"grid" and special.state.has("plan")
		if grid_hold:target=special.state.plan.bearer
		target=target.limit_length(manager.cfg.field_radius-200.0)
		if grid_hold and n.free_pos.distance_to(target)<45.0:
			n.free_pos=n.free_pos.lerp(target,1.0-exp(-4.0*dt))
			n.velocity=Vector2.ZERO
		else:SNAKE.steer(n,target,dt,def.params,float(def.params.bearer_speed)/float(def.params.snake_speed))
	var at:=_head_pos(n)
	table.pos[immortal_row]=at
	table.facing[immortal_row]=n.angle
	table.pos[body]=at
	table.hp[body]=table.hp[immortal_row]
	_follow_neck(n,dt)

func health_row()->int:
	return immortal_row if separated and manager.enemies.is_same(immortal_row,immortal_id) else body

func head_index(n: Neck)->int:
	return -2 if n==immortal_neck else necks.find(n)

func grid_plan()->Dictionary:
	var maximum: float=manager.cfg.draw_length*run_state.stats.capacity*run_state.stats.length_mult*run_state.stats.max_speed/manager.cfg.base_max_speed
	return GRID.build(run_state.view_rect(),run_state.ship_pos,necks.filter(func(n):return _alive(n)).size(),def.params,manager.cfg.ship_radius,maximum)
