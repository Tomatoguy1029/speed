## 敵の出現と補充（仕様書 4.2・11.3・11.4・11.7）。時間帯・雑魚の曲線・強敵の群れ・地域の上限・再配置を決める。
##
## 「どこに何を出すか」をここで決め、敵の行を作るのは EnemySystem.spawn() に任せる。
class_name SpawnSystem
extends RunSystem

var enemies: EnemySystem:
	get: return ctx.enemies
var field: FieldSystem:
	get: return ctx.field
var projectiles: ProjectileSystem:
	get: return ctx.projectiles
var table: EnemyTable:
	get: return ctx.enemies.table

var _spawn_acc := 0.0
var _wave_t := 0.0
var _edge_counts := [0, 0, 0, 0]
var _phase_id: StringName = &""

func spawn(def: EnemyDef, pos: Vector2, opts := {}) -> int:
	return enemies.spawn(def, pos, opts)

func def_of(type: StringName) -> EnemyDef:
	return enemies.def_of(type)

func is_same(i: int, id: int) -> bool:
	return enemies.is_same(i, id)

func mark_dead(i: int) -> void:
	enemies.mark_dead(i)


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

func target() -> Dictionary:
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
func count_population(in_view: bool) -> int:
	var n := 0
	var lim := state.view_half * cfg.spawn_recycle_scale + Vector2(200, 200)
	var pos := table.pos
	var dead := table.dead
	for rows in enemies.beh_rows:
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
	var t := target()
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

## クリップの番号 → そのクリップから出た群れ（各群れの行番号と id を交互に並べたもの）
var _clip_groups: Dictionary = {}
## クリップの番号 → 次に群れを出せる時刻（実秒）
var _clip_next: Dictionary = {}
## 一度画面に入ったクリップの群れ（群れの最初の敵の id → true）。入ったあとは遠くなったら再配置する
var _clip_arrived: Dictionary = {}

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
	var group := enemies._next_id if value > 0.0 else 0
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
		var clip: RuntimeClip = clips[n]
		var prev: Array = _clip_groups.get(n, [])
		var groups: Array = prev.filter(_group_alive)
		if groups.size() < prev.size():
			# 全滅した群れ（プレイの記録が読む。群れは最初の敵の id で見分ける）
			for g: PackedInt32Array in prev:
				if not groups.has(g):
					_clip_arrived.erase(g[1])
					state.emit(&"clip_group_end", {"clip": n, "key": g[1]})
		_clip_groups[n] = groups
		if state.time < clip.time or state.time >= clip.end_time():
			continue
		if groups.size() >= clip.groups or state.time < float(_clip_next.get(n, -1e9)):
			continue
		var items := []
		for data: Dictionary in clip.prepared:
			if not _formation_capped(data): items.append({"data": data, "weight": 1.0})
		var k := _pick_weighted(items)
		if k < 0:
			continue
		var choices := []
		for li in items[k].data.layouts.size():
			choices.append({"index": li, "weight": items[k].data.layouts[li].weight})
		var c := _pick_weighted(choices)
		if c < 0:
			continue
		var layout_index: int = choices[c].index
		var value: float = items[k].data.layouts[layout_index].value
		var rows := spawn_formation(items[k].data, layout_index, -1, clip.types, value, clip.attack_priority)
		if not rows.is_empty():
			groups.append(rows)
			_clip_next[n] = state.time + clip.interval
			state.emit(&"clip_group", {"clip": n, "key": rows[1], "n": rows.size() / 2})

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
	for rows in enemies.beh_rows:
		for i in rows:
			if dead[i] != 0:
				continue
			# 上限のある種類だけ数える
			if defs[i].max_alive > 0:
				_type_counts[type[i]] = _type_counts.get(type[i], 0) + 1
			var rel := pos[i] - vc
			if absf(rel.x) > lim.x or absf(rel.y) > lim.y:
				# 部位は親と一緒に動き、自分で退場する種類（横断する群れなど）は、離れても再配置しない
				if table.parent[i] < 0 and (table.beh_slot[i] < 0 or enemies.behaviors[table.beh[i]].recycles_far) and not grouped.has(i):
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
	enemies.notify_row_gone(i)
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
