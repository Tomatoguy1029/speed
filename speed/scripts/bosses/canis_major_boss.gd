## おおいぬ座。選択は共通フロー、追跡・群れの統率・飛びかかり・号令・シリウスの光は個別ロジックで進める。
## 予告・狙い固定・発進・終了はAnimationPlayerで進め、本体は全方向から攻撃できる。
## 近くの猟犬を、ボスの前から機体へ向けて広がるくさび形の隊形へ並べ、走る先を猟犬の行動（hound.gd）へ渡す。
## 遠吠え（大技）は、群れの猟犬と呼び足した猟犬を機体のまわりの輪に並べ、薄い所を残して輪を狭める。
## 第2形態では、技の数値のうち `_p2` を付けた値が同じ名前の値を置き換え、追う速さは speed_p2 を使う。
class_name CanisMajorBoss
extends "res://scripts/bosses/boss_final_strike.gd"

signal presentation_event(event: Dictionary)
signal presentation_advanced(world_dt: float)
@export var presentation_scene: PackedScene
## 隊形の走る先を渡し直す間隔より長く、猟犬が目標を保つ時間
const FOLLOW_HOLD := 0.3
## シリウスの光の色と、口元の位置（本体の半径に対する割合）
const SIRIUS_COLOR := Color("#cfefff")
const MOUTH_REACH := 0.84

var phase := 1
## HPが第2形態の境目を切った。今の技が終わって追跡へ戻ると移る。
var phase_pending := false
## シリウスを強く輝かせる移行の残り時間
var phase_time := 0.0
var mode: StringName = &"idle"
var technique: StringName = &""
var clock := 0.0
var recovery := 0.0
var locked := false
## 技を最後に使った時刻。再使用待ちは選ぶときに今の形態と群れの数で測る。
var used_at: Dictionary = {}
var turn_motion := 0.0
## 飛びかかりの着地点と向き
var aim_point := Vector2.ZERO
var direction := Vector2.RIGHT
## 率いている猟犬の行（ID 順）と、号令で飛び出している猟犬の行
var led: PackedInt32Array = []
var lunging: PackedInt32Array = []
var attack_hit := false
## 遠吠えの囲み。猟犬の行 → [個体ID, 輪の上の角度]。中心は吠え終えた時の機体の位置
var ring: Dictionary = {}
var ring_center := Vector2.ZERO
## 囲みを始めた clock（囲んでいなければ -1）と、その時の遠吠えの性能
var ring_started := -1.0
var ring_rule: Dictionary = {}
var _led_ids: Dictionary = {}
## 率いている猟犬の行 → [個体ID, 加わる前の最大HP, 加わる前の色]。外れたら最大HPと色を戻す。
var _hound_base: Dictionary = {}
var _lead_scan := 0.0
var _pack_spawned := false
var _previous_ship := Vector2.ZERO
var _defeated := false
var _presentation: Node
var entrance_time := 0.0
var entrance_from := Vector2.ZERO
var entrance_target := Vector2.ZERO
var _cooldown := 0.0
var selection_enabled := true
var action_rules: Resource
var flow_runner := preload("res://scripts/bosses/flow/runner.gd").new()
var flow_adapter: RefCounted
var _moves := {}
## 今の形態の技の性能。技のID → 性能
var _rules := {}

func configure_flow(program: Resource) -> void:
	action_rules = program.data.rules
	_moves.clear()
	for move in action_rules.techniques: _moves[move.technique] = move
	_apply_phase()
	flow_runner.configure(program.data.flow)
	flow_runner.selector.random = run_state.rng
	flow_adapter = preload("res://scripts/bosses/flow/single_actor_adapter.gd").new(self)
	selection_enabled = true

func _on_bound() -> void:
	draws_self = true
	table.gate[body] = EnemyTable.Gate.NONE
	timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	var library := timeline.get_animation_library("").duplicate(true) as AnimationLibrary
	timeline.remove_animation_library("")
	timeline.add_animation_library("", library)
	configure_flow(load("res://.content/boss_canis_major.tres"))
	_cooldown = float(def.params.initial_wait)
	_previous_ship = run_state.ship_pos
	if presentation_scene != null:
		_presentation = presentation_scene.instantiate()
		add_child(_presentation)
		_presentation.bind_canis_major(self)
	_cue(&"spawned")
	if not run_state.lab_mode: begin_entrance()

func begin_entrance() -> void:
	entrance_target = table.pos[body]
	entrance_from = entrance_target - Vector2(maxf(1000.0, run_state.view_half.x * 2.0), 0.0)
	entrance_time = 0.0
	mode = &"entrance"
	table.pos[body] = entrance_from
	table.facing[body] = 0.0
	_cue(&"entering")

func on_body_damaged() -> void:
	_check_phase()
	_cue(&"hit")

func _check_phase() -> void:
	if phase == 1 and table.hp[body] / table.max_hp[body] <= float(def.params.phase_threshold): phase_pending = true

func handle_body_defeat(_opts: Dictionary) -> bool:
	_stop_combat()
	return false

func _stop_combat() -> void:
	if _defeated: return
	_defeated = true
	if flow_adapter != null: flow_adapter.cancel()
	selection_enabled = false
	timeline.stop()
	_end_ring()
	_release_pack()
	mode = &"defeated"
	table.vel[body] = Vector2.ZERO
	table.charge[body] = 0.0
	_cue(&"defeated")

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0 or not body_alive(): return
	clock += dt
	table.flash[body] = maxf(0.0, table.flash[body] - dt)
	table.hit_cd[body] = maxf(0.0, table.hit_cd[body] - dt)
	turn_motion = 0.0
	if mode == &"entrance":
		entrance_time += dt
		var duration := maxf(0.05, float(def.params.get("entrance_time", 1.4)))
		var progress := clampf(entrance_time / duration, 0.0, 1.0)
		var before := table.pos[body]
		table.pos[body] = entrance_from.lerp(entrance_target, 1.0 - pow(1.0 - progress, 3.0))
		table.vel[body] = (table.pos[body] - before) / dt
		if progress >= 1.0:
			mode = &"idle"
			table.vel[body] = Vector2.ZERO
			_cue(&"entrance_finished")
	elif final_strike_t >= 0.0:
		_final_strike_tick(dt)
	elif mode == &"phase":
		phase_time -= dt
		table.vel[body] = Vector2.ZERO
		_face(run_state.enemy_aim, def.turn, dt)
		if phase_time <= 0.0: mode = &"idle"
	elif mode == &"recovery":
		recovery = maxf(0.0, recovery - dt)
		table.vel[body] = Vector2.ZERO
		if recovery <= 0.0:
			mode = &"idle"
			technique = &""
	elif mode in [&"windup", &"active"]:
		if mode == &"windup":
			table.vel[body] = Vector2.ZERO
			if not locked: _aim(dt)
		if mode == &"active": _active_tick(dt)
		if timeline.is_playing(): timeline.advance(dt)
	else:
		_check_phase()
		if phase_pending:
			_begin_phase_two()
		else:
			_cooldown = maxf(0.0, _cooldown - dt)
			_chase_tick(dt)
			if selection_enabled: flow_runner.tick(dt, {"player": run_state.enemy_aim}, flow_adapter)
	if mode not in [&"entrance", &"defeated"]:
		if not _pack_spawned: _spawn_pack()
		_lead_tick(dt)
		_ring_tick()
	table.charge[body] = clampf(timeline.current_animation_position / maxf(float(rule().get("warn", 1.0)), 0.001), 0.0, 1.0) if mode == &"windup" else 0.0
	_previous_ship = run_state.ship_pos
	presentation_advanced.emit(dt)

func rule() -> Dictionary:
	return _rules.get(technique, {})

## 追う速さ。第2形態では speed_p2 があればそれを使う。
func chase_speed() -> float:
	return float(def.params.get("speed_p2", def.speed)) if phase >= 2 else def.speed

## 技の性能を今の形態の値にそろえる。技の途中では変えない。
func _apply_phase() -> void:
	_rules.clear()
	for id in _moves:
		var base: Dictionary = _moves[id].parameters
		var values := {}
		for key: String in base:
			if not key.ends_with("_p2"): values[key] = base[key]
		if phase >= 2:
			for key: String in base:
				if key.ends_with("_p2"): values[key.trim_suffix("_p2")] = base[key]
		_rules[id] = values

## 止まってシリウスを強く輝かせ、第2形態の値へ切り替える。群れは隊形を保つ。
func _begin_phase_two() -> void:
	phase_pending = false
	phase = 2
	_apply_phase()
	mode = &"phase"
	phase_time = float(def.params.phase_time)
	table.vel[body] = Vector2.ZERO
	_cue(&"phase_changed")

## 技の再使用待ち。率いている猟犬が alone_hounds より少ないと cd_alone を使う（群れが減ると自分で攻める）。
func cooldown_of(attack: StringName) -> float:
	var r: Dictionary = _rules.get(attack, {})
	if r.has("cd_alone") and led.size() < int(r.get("alone_hounds", 0)): return float(r.cd_alone)
	return float(r.get("cd", 0.0))

# ── 共通フローへの入口 ─────────────────────────────────────────

func technique_ready(attack: StringName, gate: Dictionary) -> bool:
	if not can_select(attack, int(gate.get("min_phase", 1)), float(gate.get("min", 0.0)), float(gate.get("max", INF))): return false
	return preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, (run_state.enemy_aim - table.pos[body]).rotated(-table.facing[body]))

func selection_blocked() -> bool:
	return not body_alive() or not selection_enabled or mode in [&"entrance", &"phase", &"final", &"defeated"]

func can_begin_sequence() -> bool:
	return mode == &"idle" and _cooldown <= 0.0

func attack_failed() -> bool:
	return not body_alive()

## 条件評価では攻撃枠を消費しない。号令は率いている猟犬が足りるときだけ選べる。
func can_select(attack: StringName, min_phase: int, min_range: float, max_range: float) -> bool:
	if mode != &"idle" or phase_pending or _cooldown > 0.0 or phase < min_phase: return false
	if used_at.has(attack) and clock < float(used_at[attack]) + cooldown_of(attack): return false
	if attack == &"command" and led.size() < int(_rules[attack].min_hounds): return false
	var distance := run_state.enemy_aim.distance_to(table.pos[body])
	return distance >= min_range and distance <= max_range

func start_attack(attack: StringName) -> bool:
	if mode != &"idle" or not _rules.has(attack): return false
	var r: Dictionary = _rules[attack]
	var length := _attack_length(attack, r)
	if not ctx.bosses.admit("boss:" + str(body_id), ["aimed"], body, length): return false
	technique = attack
	used_at[attack] = clock
	_begin_windup(r, length)
	return true

func attack_playing() -> bool:
	return mode in [&"windup", &"active", &"recovery"]

func cancel_attack() -> void:
	timeline.stop()
	locked = false
	recovery = 0.0
	technique = &""
	lunging.clear()
	if mode in [&"windup", &"active", &"recovery"]: mode = &"idle"

# ── 技 ────────────────────────────────────────────────────

func _attack_length(attack: StringName, r: Dictionary) -> float:
	if attack == &"command": return float(r.warn) + float(r.lunge_time) + 0.05
	if attack == &"sirius": return float(r.warn) + float(r.beam_time) + 0.05
	if attack == &"howl": return float(r.warn) + 0.05
	return float(r.warn) + float(r.active) + 0.05

func _begin_windup(r: Dictionary, length: float) -> void:
	mode = &"windup"
	locked = false
	attack_hit = false
	table.vel[body] = Vector2.ZERO
	aim_point = run_state.enemy_aim
	var anim := timeline.get_animation(&"attack")
	anim.length = length
	while anim.track_get_key_count(0) > 0: anim.track_remove_key(0, 0)
	if technique in [&"pounce", &"sirius"]:
		anim.track_insert_key(0, maxf(0.01, float(r.warn) - float(r.lock)), {"method": &"lock_aim", "args": []})
	anim.track_insert_key(0, float(r.warn), {"method": &"launch", "args": []})
	anim.track_insert_key(0, length, {"method": &"end_attack", "args": []})
	timeline.play(&"attack")
	timeline.advance(0.0)
	_cue(&"telegraph")

## 構えの間は共通の遅延照準を追い、飛びかかりの着地点を決める。
func _aim(dt: float) -> void:
	aim_point = run_state.enemy_aim
	_face(aim_point, def.turn, dt)

## 飛びかかりは着地点を、シリウスの光は向きを固定する。
func lock_aim() -> void:
	if mode != &"windup": return
	locked = true
	if technique == &"sirius":
		direction = Vector2.from_angle(table.facing[body])
	else:
		var to := aim_point - table.pos[body]
		direction = to.normalized() if to.length_squared() > 1.0 else Vector2.from_angle(table.facing[body])
		aim_point += direction * float(rule().overshoot)
	_cue(&"aim_locked")

## 口元。シリウスの光はここから出る。
func mouth() -> Vector2:
	return table.pos[body] + Vector2.from_angle(table.facing[body]) * table.r[body] * MOUTH_REACH

## 飛びかかりは固定した着地点へ跳ぶ。号令は率いている猟犬を一斉に機体の方へ、最初から全速で飛び出させる。
func launch() -> void:
	if mode != &"windup": return
	mode = &"active"
	attack_hit = false
	if technique == &"pounce":
		if not locked: lock_aim()
		_cue(&"pounce")
		return
	if technique == &"sirius":
		_fire_sirius()
		return
	if technique == &"howl":
		_form_ring(rule())
		return
	var r := rule()
	var hounds = _hounds()
	_cue(&"command")
	if hounds == null: return
	lunging = PackedInt32Array(Array(led).filter(func(i): return not ring.has(i)))
	var until := run_state.world_time + float(r.lunge_time)
	for i in lunging:
		var speed_scale := float(r.lunge_speed) / maxf(table.speed[i], 1.0)
		var toward := (run_state.ship_pos - table.pos[i]).normalized()
		hounds.follow(i, table.pos[i] + toward * float(r.lunge_speed) * (float(r.lunge_time) + 0.2), until, speed_scale)
		# 加速を待たず、最初から全速で飛び出す。
		table.vel[i] = toward * float(r.lunge_speed)

## 固定した向きへ光を出す。光は猟犬などの敵をすり抜け、惑星・月で止まる。ボスが倒れると消える。
func _fire_sirius() -> void:
	if not locked: lock_aim()
	var r := rule()
	var from := mouth()
	var length := float(r.beam_length)
	var hit = ctx.field.first_body_hit(from, from + direction * length, float(r.beam_width) * 0.5)
	if hit != null: length *= float(hit.t)
	var beam := ctx.projectiles.fire_beam(from, direction.angle(), length, float(r.beam_width), 0.0, float(r.beam_time),
		float(r.damage) * ctx.cfg.atk_scale, SIRIUS_COLOR)
	if beam >= 0:
		ctx.projectiles.hazard_style[beam] = ProjectileSystem.HazardStyle.TELESCOPE
		ctx.projectiles.attach_hazard(beam, body)
	_cue(&"sirius")

func _active_tick(dt: float) -> void:
	var r := rule()
	if technique == &"pounce":
		# 着地の時刻までに、残りの距離を等速で詰める。
		var from := table.pos[body]
		var left := float(r.warn) + float(r.active) - timeline.current_animation_position
		_move_body((aim_point - from) * clampf(dt / maxf(left, dt), 0.0, 1.0), dt)
		table.facing[body] = direction.angle()
		if not attack_hit and _ship_touches(from, table.pos[body], table.r[body]):
			_hit_ship(float(r.damage))
		return
	if technique in [&"sirius", &"howl"]:
		table.vel[body] = Vector2.ZERO
		return
	# 号令：飛び出した猟犬に触れたら1回だけ当たる。
	if attack_hit: return
	for i in lunging:
		if not _alive_hound(i): continue
		if _ship_touches(table.pos[i], table.pos[i], table.r[i]):
			_hit_ship(float(r.damage))
			return

func end_attack() -> void:
	if mode not in [&"windup", &"active"]: return
	timeline.stop()
	locked = false
	lunging.clear()
	table.vel[body] = Vector2.ZERO
	mode = &"recovery"
	recovery = float(rule().recover)
	_cue(&"recovery_started")

func _ship_touches(from: Vector2, to: Vector2, radius: float) -> bool:
	var reach := radius + ctx.cfg.ship_radius
	var ship := run_state.ship_pos
	return Geometry2D.get_closest_point_to_segment(ship, from, to).distance_to(ship) <= reach \
		or Geometry2D.get_closest_point_to_segment(to, _previous_ship, ship).distance_to(to) <= reach

func _hit_ship(damage: float) -> void:
	attack_hit = true
	ctx.ship.damage(damage * ctx.cfg.atk_scale, 0.0, technique, &"canis_major")

# ── 追跡と群れ ────────────────────────────────────────────

## 群れの先頭で、共通の遅延照準を追う。
func _chase_tick(dt: float) -> void:
	var aim := run_state.enemy_aim
	_face(aim, def.turn, dt)
	var to := aim - table.pos[body]
	if to.length() > table.r[body]:
		_move_body(Vector2.from_angle(table.facing[body]) * chase_speed() * dt, dt)
	else:
		table.vel[body] = Vector2.ZERO

## 猟犬の行動（hound.gd）。猟犬がまだ出ていなければ null。
func _hounds():
	return ctx.enemies.behavior(&"hound")

func _alive_hound(i: int) -> bool:
	return table.alive[i] != 0 and table.dead[i] == 0 and _led_ids.get(i, -1) == table.id[i]

## 自分の群れを連れて出る。群れの番号はボスごとに分け、通常の猟犬の群れと混ぜない。
func _spawn_pack() -> void:
	_pack_spawned = true
	var hound := ctx.enemies.def_of(&"hound")
	if hound == null: return
	var count := int(def.params.pack_size)
	var back := -Vector2.from_angle(table.facing[body])
	for k in count:
		var at := table.pos[body] + back.rotated((float(k) / maxf(count - 1, 1) - 0.5) * 2.2) * (table.r[body] + 70.0)
		ctx.enemies.spawn(hound, at, {"hound_pack": -body_id, "facing": table.facing[body]})
	_lead_scan = 0.0

## 近くの猟犬を数え直し、ボスの前から機体へ向けて広がるくさび形の隊形の位置を渡す。
func _lead_tick(dt: float) -> void:
	var hounds = _hounds()
	if hounds == null: return
	_lead_scan -= dt
	if _lead_scan <= 0.0:
		_lead_scan = float(def.params.lead_scan)
		_scan_pack(hounds)
	var until := run_state.world_time + FOLLOW_HOLD
	var forward := Vector2.from_angle(table.facing[body])
	var side := forward.orthogonal()
	var origin := table.pos[body] + forward * (table.r[body] + 20.0)
	var width := float(def.params.slot_side)
	var catch_up := float(def.params.lead_catch_up)
	# 列の数（1列目2体、2列目3体……）。くさびの先端が機体を越えないよう、列の間隔を縮める。
	var rows := 0
	while (rows + 1) * (rows + 4) / 2 <= led.size(): rows += 1
	rows = maxi(rows + 1, 1)
	var room := maxf(0.0, origin.distance_to(run_state.enemy_aim) - 40.0)
	var spacing := minf(float(def.params.slot_back), room / rows)
	var row := 1
	var column := 0
	for i in led:
		if not _alive_hound(i): continue
		if not lunging.has(i) and not ring.has(i):
			var goal := origin + forward * spacing * row + side * (column - row * 0.5) * width
			hounds.follow(i, goal, until, catch_up)
		column += 1
		if column > row:
			row += 1
			column = 0

func _scan_pack(hounds) -> void:
	var t := table
	var at := t.pos[body]
	var reach := float(def.params.lead_radius)
	var found: Array = []
	for i in hounds.rows():
		if t.alive[i] == 0 or t.dead[i] != 0: continue
		var distance := t.pos[i].distance_squared_to(at)
		if distance <= reach * reach or _led_ids.get(i, -1) == t.id[i]: found.append([distance, i])
	found.sort()
	_led_ids.clear()
	var rows: Array = []
	for entry in found.slice(0, int(def.params.lead_max)):
		rows.append(entry[1])
		_led_ids[entry[1]] = t.id[entry[1]]
	rows.sort_custom(func(a: int, b: int): return t.id[a] < t.id[b])
	led = PackedInt32Array(rows)
	_toughen_pack()

## 体当たりの基準の強さ。満タンの突進（T04）を持っていれば、その倍率も掛ける。クリティカルは含めない。
func ram_power() -> float:
	var burst := 1.0
	var full_charge = ctx.loadout.trait_behaviors.get(&"T04")
	if full_charge != null: burst = maxf(1.0, full_charge.val("mult"))
	return ctx.cfg.base_attack * run_state.stats.attack_mult * ctx.cfg.atk_scale * burst

## 率いている猟犬の最大HPを、体当たりの基準の強さで led_hits 回目に倒れる値まで上げ（元より下げない）、色を led_color にする。
## 群れから外れた猟犬は元の最大HPと色へ戻す。どちらも今のHPは割合を保つ。
func _toughen_pack() -> void:
	var t := table
	var power := ram_power()
	var hits := maxf(1.0, float(def.params.led_hits))
	var target := power * (hits - 1.0) + power * 0.5
	for i in _hound_base.keys():
		var entry: Array = _hound_base[i]
		if _led_ids.get(i, -1) == entry[0]: continue
		if t.alive[i] != 0 and t.id[i] == entry[0]:
			_set_max_hp(i, float(entry[1]))
			t.color[i] = entry[2]
		_hound_base.erase(i)
	var color: Color = def.params.get("led_color", Color.WHITE)
	for i in led:
		if not _hound_base.has(i): _hound_base[i] = [t.id[i], t.max_hp[i], t.color[i]]
		_set_max_hp(i, maxf(float(_hound_base[i][1]), target))
		t.color[i] = color

func _set_max_hp(i: int, value: float) -> void:
	var t := table
	var health := t.hp[i] / maxf(t.max_hp[i], 0.001)
	t.max_hp[i] = value
	t.hp[i] = value * health

# ── 遠吠え ────────────────────────────────────────────────

## 機体のまわりの輪に猟犬を並べる。輪の位置は ring_count に薄い所の分を足して等分し、
## gaps か所で gap_slots 個ずつ空ける。群れの猟犬を近い位置から先に使い、足りない分を summon_max まで輪の外へ呼ぶ。
func _form_ring(r: Dictionary) -> void:
	var hounds = _hounds()
	var hound := ctx.enemies.def_of(&"hound")
	_end_ring()
	_cue(&"howl")
	ring_rule = r
	ring_center = run_state.ship_pos
	ring_started = clock
	var gaps := maxi(0, int(r.gaps))
	var gap_slots := maxi(0, int(r.gap_slots))
	var total := int(r.ring_count) + gaps * gap_slots
	if total <= 0: return
	var rng: RandomNumberGenerator = run_state.rng
	var offset := rng.randf() * TAU
	var empty := {}
	for g in gaps:
		var start := int(float(g) * total / gaps)
		for k in gap_slots: empty[(start + k) % total] = true
	var angles: Array[float] = []
	for slot in total:
		if not empty.has(slot): angles.append(offset + TAU * slot / total)
	var pool: Array = []
	if hounds != null:
		for i in led:
			if _alive_hound(i) and not lunging.has(i): pool.append(i)
	var summoned := 0
	for angle in angles:
		var best := -1
		var best_gap := INF
		for i: int in pool:
			var gap := absf(Geom.angle_diff((table.pos[i] - ring_center).angle(), angle))
			if gap < best_gap:
				best_gap = gap
				best = i
		if best >= 0:
			pool.erase(best)
			ring[best] = [table.id[best], angle]
		elif hound != null and summoned < int(r.summon_max):
			var at := ring_center + Vector2.from_angle(angle) * (float(r.ring_radius) + float(r.spawn_out))
			var row := ctx.enemies.spawn(hound, at, {"hound_pack": -body_id, "facing": angle + PI})
			if row >= 0:
				ring[row] = [table.id[row], angle]
				summoned += 1

## 猟犬を gather_time かけて半径 ring_radius の輪へ並べ、そこから close_time かけて ring_close まで狭める。
## 狭め終えると囲みを解き、群れの猟犬は隊形へ、呼んだ猟犬は通常の追跡へ戻る。
func _ring_tick() -> void:
	if ring_started < 0.0: return
	var r := ring_rule
	var hounds = _hounds()
	if clock - ring_started >= float(r.gather_time) + float(r.close_time) or hounds == null:
		_end_ring()
		return
	var radius := ring_radius()
	var until := run_state.world_time + FOLLOW_HOLD
	for i: int in ring.keys():
		var entry: Array = ring[i]
		if table.alive[i] == 0 or table.dead[i] != 0 or table.id[i] != entry[0]:
			ring.erase(i)
			continue
		hounds.follow(i, ring_center + Vector2.from_angle(float(entry[1])) * radius, until, float(r.catch_up))

## 今の囲みの半径。囲んでいなければ -1。
func ring_radius() -> float:
	if ring_started < 0.0: return -1.0
	var progress := clampf((clock - ring_started - float(ring_rule.gather_time)) / maxf(float(ring_rule.close_time), 0.001), 0.0, 1.0)
	return lerpf(float(ring_rule.ring_radius), float(ring_rule.ring_close), progress)

func _end_ring() -> void:
	ring.clear()
	ring_started = -1.0

## 撃破で群れを解き、猟犬を通常の群れの追跡へ戻す。
func _release_pack() -> void:
	var hounds = _hounds()
	if hounds != null:
		for i in led: hounds.follows.erase(i)
	led.clear()
	lunging.clear()
	_led_ids.clear()
	_toughen_pack()

func _face(point: Vector2, rate: float, dt: float) -> void:
	var prior := table.facing[body]
	table.facing[body] = rotate_toward(prior, (point - table.pos[body]).angle(), rate * dt)
	turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)

func _move_body(step: Vector2, dt: float) -> void:
	var from := table.pos[body]
	table.pos[body] += step
	table.vel[body] = step / maxf(dt, 0.001)
	ctx.field.collide_enemy(body, from)

## 実験場だけが描く攻撃範囲。飛びかかりの構えでは着地点、跳んでいる間は本体の円。
func lab_ranges(_with_idle := false) -> Array[Dictionary]:
	if technique != &"pounce" or mode not in [&"windup", &"active"]: return []
	var center := aim_point if mode == &"windup" else table.pos[body]
	return [{"center": center, "radius": table.r[body], "active": mode == &"active"}]

func _cue(cue: StringName) -> void:
	presentation_event.emit({"cue": cue, "technique": technique, "phase": phase, "mode": mode,
		"position": table.pos[body], "angle": table.facing[body], "world_time": clock})

func begin_final_strike(charge: float) -> void:
	if flow_adapter != null: flow_adapter.cancel()
	selection_enabled = false
	lunging.clear()
	mode = &"final"
	super(charge)
	_cue(&"final_strike")

func _exit_tree() -> void:
	if flow_adapter != null: flow_adapter.cancel()
	if ctx != null and ctx.enemies != null: _release_pack()
