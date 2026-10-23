## プレイの記録（開発版だけ。設計書 14.3）。F9 で記録を入・切し、プレイ中ならその場で開始する。
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
const IDENTITY := preload("res://scripts/dev/recording_identity.gd")

var _real_start_us := 0
var _perf_last_us := 0
var _perf_window_us := 0
var _record_names: Dictionary = {}
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
var _run: RunSimulation = null
## 記録中のランのセッション（木から出たら記録を閉じる）
var _session: RunSession = null
var _file: FileAccess = null
var _next_sample := 0.0
var _last_xp_gained := 0.0
var _last_xp_dropped := 0.0
## 大きい結晶の段（"1"〜"3"）ごとの、落ちた数と経験値の累計
var _big_crystals: Dictionary = {}
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
## F9 の直前から表示待ちだった出来事は、観測区間へ混ぜない。
var _skip_events := 0

## 記録を置くフォルダ（書類フォルダの SPEED/recordings。書類フォルダが分からなければユーザーデータの中）。
static func folder() -> String:
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs == "":
		return ProjectSettings.globalize_path("user://recordings")
	return docs.path_join("SPEED").path_join("recordings")

func _recording_directory() -> String:
	return folder()

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
	if on == armed:
		return
	armed = on
	if on:
		get_tree().node_added.connect(_on_node_added)
		for run in get_tree().get_nodes_in_group("recordable_runs"):
			if run.sim.state == null:
				_on_node_added(run)
				continue
			if run.is_node_ready() and not run.is_queued_for_deletion() and run.sim.state != null:
				_begin(run, true)
				if _run != null:
					break
	else:
		if get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)
		_end("stopped")
	_update_label()

## ランのセッションが来たら、準備ができてから記録を始める。
func _on_node_added(node: Node) -> void:
	if node is RunSession:
		var callback := _begin.bind(node)
		if not node.started.is_connected(callback): node.started.connect(callback, CONNECT_ONE_SHOT)

func _begin(session: RunSession, during_run := false) -> void:
	if not is_instance_valid(session):
		return
	var run := session.sim
	if not armed or run == _run or session.is_queued_for_deletion() or run.state == null or run.state.lab_mode or run.state.phase == RunState.Phase.ENDED:
		return
	_end("quit")
	_run = run
	_session = session
	var directory := _recording_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var base := directory.path_join("stage%d_%s" % [run.state.stage_index, stamp])
	var path := base + ".jsonl"
	var suffix := 1
	while FileAccess.file_exists(path):
		path = "%s_%d.jsonl" % [base, suffix]
		suffix += 1
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		_run = null
		_session = null
		return
	run.frame_events.connect(_on_events)
	run.phase_changed.connect(_on_phase_changed)
	run.loadout.cards_opened.connect(_on_cards)
	run.loadout.loadout_recorded.connect(_on_loadout)
	run.pickups.xp_recorded.connect(_write)
	run.ship.hurt_recorded.connect(_on_hurt)
	_skip_events = run.state.events.size() if during_run else 0
	session.tree_exiting.connect(_end.bind("quit"))
	_reset_counts()
	_on_cards(run.state.cards)
	_last_xp_gained = run.state.xp_gained
	_last_xp_dropped = run.state.xp_dropped
	_next_sample = run.state.time + INTERVAL
	_perf_start(Time.get_ticks_usec())
	var names_path := "res://.content/dev/stage_%d.json" % run.state.stage_index
	_record_names = JSON.parse_string(FileAccess.get_file_as_string(names_path)) if FileAccess.file_exists(names_path) else {}
	var bands := []
	var phases: Array = run.state.stage.phases
	for k in phases.size():
		var p: PhaseDef = phases[k]
		bands.append({"id": String(p.id), "name": _record_names.get("phases", {}).get(String(p.id), p.display_name), "start": p.start})
	var recording_start: Dictionary = run.recording_snapshot()
	recording_start["trigger"] = "during_run" if during_run else "armed_before_run"
	var run_start := run.recording_origin.duplicate(true)
	if not session.recording_initial.is_empty():
		run_start["conditions"] = session.recording_initial
	recording_start["conditions"] = {"config": IDENTITY.plain(run.cfg), "profile": IDENTITY.plain(run.ctx.profile),
		"stats": IDENTITY.stats(run.state.stats), "hitstop_enabled": run.state.hitstop_enabled, "invincible": run.ship.invincible,
		"rng_seed": str(run.state.rng.seed), "rng_state": str(run.state.rng.state)}
	if "stage_tuning" in run.enemies:
		recording_start.conditions["enemy_tuning"] = IDENTITY.plain(run.enemies.get("stage_tuning"))
	_write({"type": "start", "stage": run.state.stage_index, "stage_file": run.state.stage.resource_path.get_file(),
		"start_time": _r(run.state.time), "date": Time.get_datetime_string_from_system(), "interval": INTERVAL, "bands": bands,
		"schema_version": 4, "measurement_version": 1, "run_start": run_start, "recording_start": recording_start, "missing_prefix": during_run,
		"xp_config": _xp_config(), "perf_interval_real": PERF_INTERVAL_US / 1000000.0,
		"engine_version": Engine.get_version_info().string, "meta_levels": _meta_levels(), "meta_dev_override": not SaveManager.dev_meta_override.is_empty(),
		"stage_file_sha256_at_start": FileAccess.get_sha256(run.state.stage.resource_path) if FileAccess.file_exists(run.state.stage.resource_path) else ""})
	# 途中録画に存在する結晶は、生成時刻・出所を推定せず、ID と現値だけ引き継ぐ。
	if during_run:
		var gems := []
		var pk := run.pickups
		for i in pk.gem_alive.size():
			if pk.gem_alive[i] != 0: gems.append([pk.gem_seq[i], pk.gem_value[i]])
		var carried := []
		var table := run.enemies.table
		for i in table.alive.size():
			if table.alive[i] != 0 and table.dead[i] == 0 and table.carry[i] > 0.0:
				carried.append([table.id[i], table.carry[i]])
		_write({"type": "xp_existing", "t": run.state.time, "world_t": run.state.world_time, "gems": gems, "carried": carried, "origin": "unobserved"})
	_big_crystals = {}
	_run.pickups.big_crystal_dropped.connect(_on_big_crystal)
	_file.flush()
	_update_label()

## ランで使う機体の強化の段（ID → 段）。開発版の上書きを含む。
func _meta_levels() -> Dictionary:
	var out := {}
	for def: MetaUpgradeDef in ContentManager.meta_upgrades.values():
		out[String(def.id)] = SaveManager.run_meta_level(def.id)
	return out

func _xp_config() -> Dictionary:
	var out := {}
	for key in ["drop_base", "drop_power_exp", "drop_max", "big_crystal_xp", "big_crystal_weights_start", "big_crystal_weights_end",
			"big_crystal_shift_time", "xp_base", "xp_growth", "xp_curve"]:
		var v = _run.cfg.get(key)
		out[key] = Array(v) if v is PackedFloat32Array else v
	return out

## 大きい結晶が落ちた。t はラン秒、level は落ちたときのレベル。
func _on_big_crystal(tier: int, xp: float, enemy: StringName) -> void:
	if _run == null:
		return
	_write({"type": "big_crystal", "t": _r(_run.state.time), "level": _run.state.level, "tier": tier, "xp": xp, "enemy": String(enemy)})
	var key := str(tier)
	var counts: Dictionary = _big_crystals.get(key, {"count": 0, "xp": 0.0})
	counts.count += 1
	counts.xp += xp
	_big_crystals[key] = counts

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
	var phase: PhaseDef = _run.spawn.current_phase()
	_write({"type": "sample", "t": _r(s.time), "band": String(phase.id),
		"xp_picked": _r(s.xp_gained - _last_xp_gained), "xp_dropped": _r(s.xp_dropped - _last_xp_dropped), "xp_field": _r(field_xp),
		"level": s.level, "hp": _r(s.ship_hp), "hp_max": _r(s.stats.max_hp),
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

func _on_loadout(change: Dictionary) -> void:
	if int(change.current) > 0:
		var category := &"weapons" if change.kind == "weapon" else &"traits"
		var def := ContentManager.definition(category, StringName(change.id))
		change["definition_sha256"] = IDENTITY.digest(IDENTITY.plain(def))
	_write(change)

func _on_hurt(hit: Dictionary) -> void:
	_write({"type": "hurt", "t": hit.t, "world_t": hit.world_t, "amount": hit.amount,
		"cause": String(hit.cause), "source": String(hit.source), "hp_after": hit.hp_after})
	var key := String(hit.cause)
	if String(hit.source) != "": key += "/" + String(hit.source)
	_damage[key] = _r(float(_damage.get(key, 0.0)) + float(hit.amount))
	_last_hurt = {"cause": String(hit.cause), "source": String(hit.source)}

func _on_events(events: Array[Dictionary]) -> void:
	if _run == null:
		return
	var time: float = _r(_run.state.time)
	var pick: Dictionary = {}
	for e in events:
		if _skip_events > 0:
			_skip_events -= 1
			continue
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
			&"strong_spawn":
				_strong[e.id] = [String(e.enemy_type), time, 0, 0.0, {}]
			&"clip_group":
				_write({"type": "clip_group", "t": time, "clip": _record_names.get("clips", {}).get(str(e.clip), str(e.clip)), "key": e.key, "n": e.n})
			&"clip_group_end":
				_write({"type": "clip_group_end", "t": time, "clip": _record_names.get("clips", {}).get(str(e.clip), str(e.clip)), "key": e.key})
			&"phase":
				var p: PhaseDef = _run.spawn.current_phase()
				_write({"type": "band", "t": time, "id": String(p.id), "name": _record_names.get("phases", {}).get(String(p.id), p.display_name)})
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
	# 表示用の待ち行列は消費せず、終了直前の未通知分だけ記録する。
	_on_events(_run.state.events)
	var s = _run.state
	_flush_performance(_perf_last_us)
	_sample()
	for id in _strong:
		var rec: Array = _strong[id]
		_write({"type": "strong", "t": _r(s.time), "enemy": rec[0], "spawned": rec[1], "life": _r(s.time - rec[1]),
			"rams": rec[2], "weapon_damage": _r(rec[3]), "by_cause": rec[4], "result": "alive"})
	_write({"type": "end", "t": _r(s.time), "result": result, "level": s.level, "kills": s.kills,
		"weapons": _plain(s.weapons), "traits": _plain(s.traits), "last_hurt": _last_hurt if result == "death" else {},
		"big_crystals": _big_crystals})
	_saved_text = "保存：" + _file.get_path().get_file()
	_saved_t = SAVED_NOTICE
	_file.close()
	_file = null
	for sig in [[_run.frame_events, _on_events], [_run.phase_changed, _on_phase_changed], [_run.loadout.cards_opened, _on_cards],
		[_run.pickups.big_crystal_dropped, _on_big_crystal], [_run.pickups.xp_recorded, _write], [_run.loadout.loadout_recorded, _on_loadout],
		[_run.ship.hurt_recorded, _on_hurt]]:
		if sig[0].is_connected(sig[1]):
			sig[0].disconnect(sig[1])
	for c in _session.tree_exiting.get_connections():
		if c.callable.get_object() == self:
			_session.tree_exiting.disconnect(c.callable)
	_run = null
	_session = null
	_big_crystals = {}
	_strong = {}
	_offered = []
	_last_hurt = {}
	_skip_events = 0
	_update_label()

func _write(record: Dictionary) -> void:
	if _file != null:
		# 既存の区間行と出来事を同じ時計精度で並べる。
		if record.has("t"): record.t = _r(float(record.t))
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
			"corona_members": (_run.enemies.behavior(&"corona").vortex.members.size() if _run.enemies.behavior(&"corona") != null else 0)}})
	if _file != null:
		_file.flush()
	_clear_performance()
	_perf_window_us = now_us
