## プレイの記録（開発版だけ。設計書 14.3）。F9 で記録の待機を入・切し、待機中に F10 で記録のフォルダを開く。
## 待機中に始めたランを、終わる（クリア・やられた・やめた）まで1つのファイルに書く。待機は F9 で切るまで続き、
## 次のランは別のファイルにする。実験場のランは記録しない。
## ファイルは書類フォルダの SPEED/recordings/stage<番号>_<日時>.jsonl。1行に1つの記録（JSON）で、メモリにためずに書き出す。
## 記録を閉じたら、保存したファイル名を画面の隅に少しのあいだ出す。性能は実時間窓で集約し、全フレームは保存しない。
extends Node

## まとめた数を書く間隔（ランの時計の秒）
const INTERVAL := 3.0
const PERF_INTERVAL_US := 3000000
## 保存したファイル名を出しておく時間（実秒）
const SAVED_NOTICE := 5.0

var _real_start_us := 0
var _perf_last_us := 0
var _perf_window_us := 0
var _perf_phase := -1
var _perf_bonus := false
var _perf_frames := 0
var _perf_sum_us := 0
var _perf_max_us := 0
var _perf_over_33 := 0
var _perf_over_50 := 0
var _perf_hitstop := 0
var _perf_drawing := 0
var _perf_tracing := 0

var armed := false
var _run: Node = null
var _file: FileAccess = null
var _next_sample := 0.0
var _last_xp_gained := 0.0
var _last_xp_dropped := 0.0
## 記録中だけ保持する。Pickup 自体をキーにして、インスタンス ID の再利用を避ける。
var _xp_capsules: Dictionary = {}
var _capsule_next_id := 0
var _capsule_counts: Dictionary = {}
## 間隔のあいだにたまった数
var _kills: Dictionary = {}
## 倒した原因ごとの数と、与えたダメージの原因ごとの合計（倒しきった分の余りも含む）
var _kills_by: Dictionary = {}
var _dealt: Dictionary = {}
## 受けたダメージ（攻撃の種類/撃った敵ごと）
var _damage: Dictionary = {}
var _budget_max := 0.0
## 強敵（星3以上）：id → [種類, 出た時刻, 体当たりの回数, 武器のダメージ, 武器のダメージの原因ごとの合計]
var _strong: Dictionary = {}
## 直前に出たカードと、最後に受けた攻撃
var _offered: Array = []
var _last_hurt: Dictionary = {}
var _label: Label
## 保存したファイル名の表示の残り時間と、その文字
var _saved_t := 0.0
var _saved_text := ""

## 記録を置くフォルダ（書類フォルダの SPEED/recordings。書類フォルダが分からなければユーザーデータの中）。
static func folder() -> String:
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs == "":
		return ProjectSettings.globalize_path("user://recordings")
	return docs.path_join("SPEED").path_join("recordings")

func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_label = Label.new()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -360.0
	_label.offset_right = -10.0
	_label.offset_top = -26.0
	_label.offset_bottom = -6.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 0.8))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	layer.add_child(_label)

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F9:
		_set_armed(not armed)
	elif key.keycode == KEY_F10 and armed:
		DirAccess.make_dir_recursive_absolute(folder())
		OS.shell_open(folder())

func _set_armed(on: bool) -> void:
	armed = on
	if on:
		get_tree().node_added.connect(_on_node_added)
	else:
		if get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)
		_end("stopped")
	_update_label()

## ランの管理役（RunManager）が来たら、準備ができてから記録を始める。
func _on_node_added(node: Node) -> void:
	if node is RunManager:
		node.ready.connect(_begin.bind(node), CONNECT_ONE_SHOT)

func _begin(run: Node) -> void:
	if run.state.lab_mode:
		return
	_end("quit")
	_run = run
	DirAccess.make_dir_recursive_absolute(folder())
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var path := folder().path_join("stage%d_%s.jsonl" % [run.state.stage_index, stamp])
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		_run = null
		return
	run.frame_events.connect(_on_events)
	run.phase_changed.connect(_on_phase_changed)
	run.build.cards_opened.connect(_on_cards)
	run.tree_exiting.connect(_end.bind("quit"))
	_reset_counts()
	_last_xp_gained = run.state.xp_gained
	_last_xp_dropped = run.state.xp_dropped
	_next_sample = run.state.time + INTERVAL
	_perf_start(Time.get_ticks_usec())
	var bands := []
	var phases: Array = run.state.stage.phases
	for k in phases.size():
		var p: PhaseDef = phases[k]
		bands.append({"id": String(p.id), "name": p.display_name, "start": p.start})
	_write({"type": "start", "stage": run.state.stage_index, "stage_file": run.state.stage.resource_path.get_file(),
		"start_time": _r(run.state.time), "date": Time.get_datetime_string_from_system(), "interval": INTERVAL, "bands": bands,
		"schema_version": 3, "capsule_config": _capsule_config(), "perf_interval_real": PERF_INTERVAL_US / 1000000.0,
		"engine_version": Engine.get_version_info().string,
		"stage_file_sha256_at_start": FileAccess.get_sha256(run.state.stage.resource_path) if FileAccess.file_exists(run.state.stage.resource_path) else ""})
	_start_capsules()
	_update_label()

## 既存の記録行はそのままにし、カプセルの生成・取得・消失と累計を加える。
## t はラン秒、level は XP 加算前。spawned が null なら生成時刻は不明。
func _start_capsules() -> void:
	_xp_capsules = {}
	_capsule_next_id = 0
	_capsule_counts = {}
	_run.pickups.xp_capsule_event.connect(_on_xp_capsule)
	_sync_capsules()

func _capsule_config() -> Dictionary:
	var out := {}
	for key in ["capsule_xp_frac", "drift_capsule_xp_frac", "drift_capsule_count", "drift_capsule_interval", "pickup_life", "drop_base", "drop_power_exp", "drop_max", "xp_base", "xp_growth", "xp_curve"]:
		out[key] = _run.cfg.get(key)
	return out

func _observe_capsule(c: Pickup, spawned: bool) -> void:
	if _xp_capsules.has(c):
		return
	_capsule_next_id += 1
	var source := "unknown"
	match c.src:
		&"drop": source = "enemy_drop"
		&"field": source = "drift"
	var rec := {"id": _capsule_next_id, "source": source, "source_raw": String(c.src),
		"xp": c.value, "spawned": _run.state.time if spawned else null}
	_xp_capsules[c] = rec
	var action := "spawn" if spawned else "observed"
	_count_capsule(action, source, c.value)
	var event := rec.duplicate()
	event.merge({"type": "xp_capsule_" + action, "t": _run.state.time, "level": _run.state.level})
	_write(event)

func _on_xp_capsule(c: Pickup, action: StringName, cause: StringName) -> void:
	if _run == null:
		return
	if action == &"spawn":
		_observe_capsule(c, true)
		return
	if not _xp_capsules.has(c):
		_observe_capsule(c, false)
	var event: Dictionary = _xp_capsules[c].duplicate()
	event.merge({"type": "xp_capsule_" + String(action), "t": _run.state.time,
		"level": _run.state.level, "cause": String(cause)})
	_write(event)
	_count_capsule(String(action), event.source, c.value)
	_xp_capsules.erase(c)

func _count_capsule(action: String, source: String, xp: float) -> void:
	if not _capsule_counts.has(source):
		_capsule_counts[source] = {}
	var counts: Dictionary = _capsule_counts[source]
	counts[action] = int(counts.get(action, 0)) + 1
	counts[action + "_xp"] = float(counts.get(action + "_xp", 0.0)) + xp

## 通知のない追加・除去は生成や期限切れと推測しない。
func _sync_capsules() -> void:
	var active := {}
	for c: Pickup in _run.pickups.capsules:
		if c.kind != Pickup.Kind.CACHE or c.taken:
			continue
		active[c] = true
		if not _xp_capsules.has(c):
			_observe_capsule(c, false)
	for c: Pickup in _xp_capsules.keys():
		if not active.has(c):
			_on_xp_capsule(c, &"lost", &"unknown")

## 累計（source 別）。observed は生成未確認。remaining は未回収であり、lost と分ける。
func _capsule_summary() -> Dictionary:
	var out := _capsule_counts.duplicate(true)
	for source in out:
		out[source]["remaining"] = 0
		out[source]["remaining_xp"] = 0.0
	for rec: Dictionary in _xp_capsules.values():
		out[rec.source]["remaining"] += 1
		out[rec.source]["remaining_xp"] += rec.xp
	return out

func _process(delta: float) -> void:
	if _saved_t > 0.0:
		_saved_t -= delta
		_update_label()
	if _run == null:
		return
	_perf_tick(Time.get_ticks_usec())
	var d = _run.projectiles.director
	if d != null:
		_budget_max = maxf(_budget_max, d.used_cost())
	if _run.state.time >= _next_sample:
		_sample()
		_next_sample = _run.state.time + INTERVAL
	_update_label()

## 間隔ごとのまとめ。
func _sample() -> void:
	_sync_capsules()
	var s = _run.state
	var t = _run.enemies.table
	var by_star := {}
	var in_view := 0
	var total := 0
	var view: Rect2 = s.view_rect()
	for i in t.alive.size():
		if not t.alive[i] or t.dead[i] != 0 or t.def[i] == null:
			continue
		total += 1
		var star := str(t.def[i].rank)
		by_star[star] = int(by_star.get(star, 0)) + 1
		if view.has_point(t.pos[i]):
			in_view += 1
	var field_xp := 0.0
	var pk = _run.pickups
	for g in pk.gem_alive.size():
		if pk.gem_alive[g] != 0:
			field_xp += pk.gem_value[g]
	var phase: PhaseDef = _run.enemies.current_phase()
	_write({"type": "sample", "t": _r(s.time), "band": String(phase.id),
		"xp_picked": _r(s.xp_gained - _last_xp_gained), "xp_dropped": _r(s.xp_dropped - _last_xp_dropped), "xp_field": _r(field_xp),
		"xp_capsules": _capsule_summary(), "level": s.level, "hp": _r(s.ship_hp), "hp_max": _r(s.stats.max_hp),
		"enemies": total, "in_view": in_view, "by_star": by_star, "kills": _kills, "kills_by": _kills_by, "dealt": _dealt, "damage": _damage, "attack_budget_max": _r(_budget_max)})
	_last_xp_gained = s.xp_gained
	_last_xp_dropped = s.xp_dropped
	_reset_counts()
	_file.flush()

func _reset_counts() -> void:
	_kills = {}
	_kills_by = {}
	_dealt = {}
	_damage = {}
	_budget_max = 0.0

func _on_cards(cards: Array) -> void:
	_offered = []
	for c in cards:
		_offered.append("%s:%s:%d" % [c.kind, c.id, int(c.get("level", 0))])

func _on_events(events: Array[Dictionary]) -> void:
	if _run == null:
		return
	var time: float = _r(_run.state.time)
	var pick: Dictionary = {}
	for e in events:
		match e.type:
			&"bonus":
				_write({"type": "bonus", "t": time, "enter": bool(e.enter), "remaining": _run.state.bonus_t})
			&"kill":
				if e.get("cause", &"") == &"finale":
					continue
				var ty := String(e.get("enemy_type", &""))
				_kills[ty] = int(_kills.get(ty, 0)) + 1
				var by := String(e.get("cause", &""))
				_kills_by[by] = int(_kills_by.get(by, 0)) + 1
				var id: int = e.get("id", -1)
				if _strong.has(id):
					var rec: Array = _strong[id]
					_write({"type": "strong", "t": time, "enemy": rec[0], "spawned": rec[1], "life": _r(time - rec[1]),
						"rams": rec[2], "weapon_damage": _r(rec[3]), "by_cause": rec[4], "killed_by": by, "result": "killed"})
					_strong.erase(id)
			&"hit":
				var cause: StringName = e.get("cause", &"")
				var dmg := float(e.get("dmg", 0.0))
				_dealt[String(cause)] = _r(float(_dealt.get(String(cause), 0.0)) + dmg)
				var id: int = e.get("id", -1)
				if _strong.has(id):
					var rec: Array = _strong[id]
					if cause == &"ram":
						rec[2] += 1
					elif cause != &"bump" and cause != &"touch":
						rec[3] += dmg
						rec[4][String(cause)] = _r(float(rec[4].get(String(cause), 0.0)) + dmg)
			&"hurt":
				var key := String(e.get("cause", &""))
				if String(e.get("source", &"")) != "":
					key += "/" + String(e.source)
				_damage[key] = _r(float(_damage.get(key, 0.0)) + float(e.get("amount", 0.0)))
				_last_hurt = {"cause": String(e.get("cause", &"")), "source": String(e.get("source", &""))}
			&"strong_spawn":
				_strong[e.id] = [String(e.enemy_type), time, 0, 0.0, {}]
			&"clip_group":
				_write({"type": "clip_group", "t": time, "clip": e.clip, "key": e.key, "n": e.n})
			&"clip_group_end":
				_write({"type": "clip_group_end", "t": time, "clip": e.clip, "key": e.key})
			&"phase":
				var p: PhaseDef = _run.enemies.current_phase()
				_write({"type": "band", "t": time, "id": String(p.id), "name": p.display_name})
			&"levelup":
				_write({"type": "levelup", "t": time, "level": e.level})
			&"upgrade":
				var c: Dictionary = e.card
				pick = {"type": "pick", "t": time, "level": _run.state.level, "offered": _offered,
					"chosen": "%s:%s:%d" % [c.kind, c.id, int(c.get("level", 0))], "bonus": 0}
			&"level_bonus":
				if not pick.is_empty():
					pick.bonus += 1
	if not pick.is_empty():
		_write(pick)

func _on_phase_changed(phase: int) -> void:
	if _run == null:
		return
	_write({"type": "run_phase", "t": _r(_run.state.time), "phase": RunState.Phase.keys()[phase]})
	if phase != RunState.Phase.ENDED:
		return
	var s = _run.state
	_end("clear" if s.cleared else ("death" if s.ship_hp <= 0.0 else "quit"))

## ランの記録を閉じる。
func _end(result: String) -> void:
	if _run == null:
		return
	var s = _run.state
	_flush_performance(_perf_last_us)
	_sample()
	for id in _strong:
		var rec: Array = _strong[id]
		_write({"type": "strong", "t": _r(s.time), "enemy": rec[0], "spawned": rec[1], "life": _r(s.time - rec[1]),
			"rams": rec[2], "weapon_damage": _r(rec[3]), "by_cause": rec[4], "result": "alive"})
	_write({"type": "end", "t": _r(s.time), "result": result, "level": s.level, "kills": s.kills,
		"weapons": _plain(s.weapons), "traits": _plain(s.traits), "last_hurt": _last_hurt if result == "death" else {},
		"xp_capsules": _capsule_summary(), "xp_capsules_remaining": _xp_capsules.values()})
	_saved_text = "保存：" + _file.get_path().get_file()
	_saved_t = SAVED_NOTICE
	_file.close()
	_file = null
	for sig in [[_run.frame_events, _on_events], [_run.phase_changed, _on_phase_changed], [_run.build.cards_opened, _on_cards],
		[_run.pickups.xp_capsule_event, _on_xp_capsule]]:
		if sig[0].is_connected(sig[1]):
			sig[0].disconnect(sig[1])
	for c in _run.tree_exiting.get_connections():
		if c.callable.get_object() == self:
			_run.tree_exiting.disconnect(c.callable)
	_run = null
	_xp_capsules = {}
	_capsule_counts = {}
	_strong = {}
	_offered = []
	_last_hurt = {}
	_update_label()

func _write(record: Dictionary) -> void:
	if _file != null:
		if _real_start_us > 0:
			if not record.has("real_t"):
				record.real_t = (Time.get_ticks_usec() - _real_start_us) / 1000000.0
		_file.store_line(JSON.stringify(record))

func _update_label() -> void:
	if _label == null:
		return
	_label.visible = armed or _saved_t > 0.0
	var text := "● REC 待機"
	if _saved_t > 0.0 and _run == null:
		text = _saved_text
	elif _run != null:
		var t := int(_run.state.time)
		text = "● REC %d:%02d" % [t / 60, t % 60]
	# 文字が変わったときだけ書き換える（毎フレーム書き換えると、文字の組み直しが毎回走る）
	if _label.text != text:
		_label.text = text

static func _r(v: float) -> float:
	return snappedf(v, 0.01)

static func _plain(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out

## 記録中の描画フレーム間隔を定数個のカウンタへ集約する。停止・カード選択とボーナスの境界で窓を分ける。
func _perf_start(now_us: int) -> void:
	_real_start_us = now_us
	_perf_last_us = now_us
	_perf_window_us = now_us
	_perf_phase = _run.state.phase
	_perf_bonus = _run.state.bonus_t > 0.0
	_clear_performance()

func _clear_performance() -> void:
	_perf_frames = 0
	_perf_sum_us = 0
	_perf_max_us = 0
	_perf_over_33 = 0
	_perf_over_50 = 0
	_perf_hitstop = 0
	_perf_drawing = 0
	_perf_tracing = 0

func _perf_tick(now_us: int) -> void:
	if _perf_last_us == 0:
		_perf_start(now_us)
		return
	var s = _run.state
	var phase: int = s.phase
	var bonus: bool = s.bonus_t > 0.0
	if phase != _perf_phase or bonus != _perf_bonus:
		if phase == RunState.Phase.PLAY and phase == _perf_phase:
			# ボーナスへの出入りも遊んでいる同じ1フレーム。切替時の重さを落とさない。
			_add_performance_frame(now_us - _perf_last_us)
			_flush_performance(now_us)
		else:
			_flush_performance(_perf_last_us)
		_perf_phase = phase
		_perf_bonus = bonus
		_perf_window_us = now_us
		_perf_last_us = now_us
		return
	var dt := now_us - _perf_last_us
	_perf_last_us = now_us
	if phase != RunState.Phase.PLAY or dt <= 0:
		return
	_add_performance_frame(dt)
	if now_us - _perf_window_us >= PERF_INTERVAL_US:
		_flush_performance(now_us)

func _add_performance_frame(dt: int) -> void:
	if dt <= 0: return
	var s = _run.state
	_perf_frames += 1
	_perf_sum_us += dt
	_perf_max_us = maxi(_perf_max_us, dt)
	if dt > 33333: _perf_over_33 += 1
	if dt > 50000: _perf_over_50 += 1
	if s.hitstop > 0.0: _perf_hitstop += 1
	if s.drawing: _perf_drawing += 1
	if s.tracing: _perf_tracing += 1

func _flush_performance(now_us: int) -> void:
	if _perf_frames == 0 or _perf_sum_us <= 0:
		return
	var s = _run.state
	var pk = _run.pickups
	var pr = _run.projectiles
	_write({"type": "performance", "t": _r(s.time), "window_end_real": (now_us - _real_start_us) / 1000000.0,
		"window_start_real": (_perf_window_us - _real_start_us) / 1000000.0,
		"duration_real": _perf_sum_us / 1000000.0, "world_t": s.world_time, "bonus": _perf_bonus,
		"frames": _perf_frames, "fps": _perf_frames * 1000000.0 / _perf_sum_us,
		"frame_ms_mean": _perf_sum_us / 1000.0 / _perf_frames, "frame_ms_max": _perf_max_us / 1000.0,
		"frames_over_33ms": _perf_over_33, "frames_over_50ms": _perf_over_50,
		"frames_with_hitstop": _perf_hitstop, "hitstop_frame_ratio": float(_perf_hitstop) / _perf_frames, "frames_drawing": _perf_drawing, "frames_tracing": _perf_tracing,
		"bonus_at_write": s.bonus_t > 0.0, "objects_at_write": {"enemies": _run.enemies.count(), "enemy_capacity": _run.enemies.slots.capacity(),
			"friendly": pr.friend_count(), "friendly_capacity": pr.friend_slots.capacity(),
			"hostile": pr.hostile_count(), "hostile_capacity": pr.hostile_slots.capacity(),
			"hazards": pr.hazard_count(), "hazard_capacity": pr.hazard_slots.capacity(),
			"gems": pk.gem_slots.live, "gem_capacity": pk.gem_slots.capacity(),
			"coins": pk.coin_slots.live, "coin_capacity": pk.coin_slots.capacity(), "capsules": pk.capsules.size(),
			"corona_members": _run.enemies.corona.members.size()}})
	if _file != null:
		_file.flush()
	_clear_performance()
	_perf_window_us = now_us
