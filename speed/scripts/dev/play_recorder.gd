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
const WEAPON_CAUSES := {"contactWave": "W04", "barrier": "W05", "mine": "W07", "sonic": "W08",
	"contactArc": "W17", "towShot": "W21", "bipolar": "W22", "interceptor": "W25",
	"dashRangeDrone": "W26", "afterimage": "W27", "flashSlash": "W28", "endBlast": "W29"}

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

## 0=off, 1=action/damage, 2=decision candidates (default). Applied at recording start.
@export_range(0, 2) var combat_level := 2
@export var combat_events_per_second := 120
@export var combat_max_events := 30000
@export var combat_max_bytes := 33554432
const COMBAT_LINE_BYTES := 16384
var _combat_bytes := 0
var _combat_dropped := 0
var _recording_id := ""
var _io_failed := false
var armed := false
var _run: RunSimulation = null
## 記録中のランのセッション（木から出たら記録を閉じる）
var _session: RunSession = null
## 記録中だけ開く、録画用の処理時間の記録（ゲーム側・表示側・敵の描画の行の数）。性能の区間ごとに書いて空にする
var _view: RunPresentation = null
var _perf_sim := {}
var _perf_view := {}
var _perf_rows := {}
## 性能の区間のあいだに録画が書いた行数と、その時間（マイクロ秒）
var _self_lines := 0
var _self_write_us := 0
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
## 命中はJSONLへ1件ずつ書かず、武器・敵種・敵級・原因ごとにsampleへ集約する。
var _effective: Dictionary = {}
## 個体ID → 出現時刻と初被弾。開始時点で既存の個体は出現時刻を不明とする。
var _enemy_seen: Dictionary = {}
var _enemy_life: Dictionary = {}
var _enemy_contacts: Dictionary = {}
## 受けたダメージ（攻撃の種類/撃った敵ごと）
var _damage: Dictionary = {}
var _budget_max := 0.0
## 強敵（星3以上）：id → [種類, 出た時刻, 体当たりの回数, 武器のダメージ, 武器のダメージの原因ごとの合計]
var _strong: Dictionary = {}
## 直前に出たカードと、最後に受けた攻撃
var _offered: Array = []
var _offer_id := 0
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
	var level_setting := OS.get_environment("SPEED_COMBAT_LOG_LEVEL")
	if level_setting.is_valid_int(): combat_level = clampi(int(level_setting), 0, 2)
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
	_io_failed = false
	_combat_bytes = 0
	_combat_dropped = 0
	_offer_id = 0
	_recording_id = "%s-%d" % [run.bosses.diagnostics.run_id, Time.get_ticks_usec()]
	var directory := _recording_directory()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_open_failed()
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var base := directory.path_join("stage%d_%s" % [run.state.stage_index, stamp])
	var path := base + ".jsonl"
	var suffix := 1
	while FileAccess.file_exists(path):
		path = "%s_%d.jsonl" % [base, suffix]
		suffix += 1
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		_open_failed()
		return
	run.frame_events.connect(_on_events)
	run.phase_changed.connect(_on_phase_changed)
	run.loadout.cards_opened.connect(_on_cards)
	run.loadout.loadout_recorded.connect(_on_loadout)
	run.loadout.choice_recorded.connect(_on_choice)
	run.pickups.xp_recorded.connect(_write)
	run.ship.hurt_recorded.connect(_on_hurt)
	run.ship.recording_hurt_attempt.connect(_on_enemy_contact)
	run.enemies.recording_spawned.connect(_on_enemy_spawned)
	run.enemies.recording_released.connect(_on_enemy_released)
	run.combat.recording_damage.connect(_on_damage_recorded)
	_skip_events = run.state.events.size() if during_run else 0
	session.tree_exiting.connect(_end.bind("quit"))
	_reset_counts()
	_enemy_seen.clear()
	_seed_existing_enemies()
	_on_cards(run.state.cards, false)
	_last_xp_gained = run.state.xp_gained
	_last_xp_dropped = run.state.xp_dropped
	_next_sample = run.state.time + INTERVAL
	var git_state := IDENTITY.git_state()
	_open_profiles()
	_perf_start(Time.get_ticks_usec())
	var names_path := "res://.content/dev/stage_%d.json" % run.state.stage_index
	_record_names = {}
	if FileAccess.file_exists(names_path):
		var names := JSON.new()
		if names.parse(FileAccess.get_file_as_string(names_path)) == OK and names.data is Dictionary:
			_record_names = names.data
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
		"schema_version": 4, "measurement_version": 3, "combat_version": 1,
		"combat_config": {"level": combat_level, "events_per_second": clampi(combat_events_per_second, 1, 1000), "max_events": clampi(combat_max_events, 1, 1000000), "max_bytes": maxi(0, combat_max_bytes), "line_bytes": COMBAT_LINE_BYTES}, "run_start": run_start, "recording_start": recording_start, "missing_prefix": during_run,
		"xp_config": _xp_config(), "perf_interval_real": PERF_INTERVAL_US / 1000000.0,
		"engine_version": Engine.get_version_info().string, "meta_levels": _meta_levels(), "meta_dev_override": not SaveManager.dev_meta_override.is_empty(),
		"git_state": git_state,
		"perf_excludes_ui_pause": true,
		"stage_file_sha256_at_start": FileAccess.get_sha256(run.state.stage.resource_path) if FileAccess.file_exists(run.state.stage.resource_path) else ""})
	if not run.state.cards.is_empty(): _on_cards(run.state.cards, true, true)
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
	run.bosses.diagnostics.recorded.connect(_on_combat)
	run.bosses.diagnostics.configure(0 if _io_failed else combat_level, combat_events_per_second, combat_max_events)
	_flush()
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
	_finish_removed_enemies()
	_write({"type": "sample", "t": _r(s.time), "world_t": s.world_time, "band": String(phase.id),
		"xp_picked": _r(s.xp_gained - _last_xp_gained), "xp_dropped": _r(s.xp_dropped - _last_xp_dropped), "xp_field": _r(field_xp),
		"level": s.level, "hp": _r(s.ship_hp), "hp_max": _r(s.stats.max_hp),
		"enemies": total, "in_view": in_view, "by_star": by_star, "kills": _kills, "kills_by": _kills_by, "dealt": _dealt,
		"effective_damage": _effective.values(), "enemy_life": _enemy_life.values(), "enemy_contacts": _enemy_contacts.values(),
		"damage": _damage, "attack_budget_max": _r(_budget_max)})
	_last_xp_gained = s.xp_gained
	_last_xp_dropped = s.xp_dropped
	_reset_counts()
	_flush()

func _reset_counts() -> void:
	_kills = {}
	_kills_by = {}
	_dealt = {}
	_effective = {}
	_enemy_life = {}
	_enemy_contacts = {}
	_damage = {}
	_budget_max = 0.0

func _on_enemy_contact(contact: Dictionary) -> void:
	var cause := String(contact.cause)
	var source := String(contact.source)
	var reason := String(contact.reason)
	var key := "%s/%s/%s" % [cause, source, reason]
	if not _enemy_contacts.has(key):
		_enemy_contacts[key] = {"cause": cause, "source": source, "reason": reason, "count": 0}
	_enemy_contacts[key].count += 1

func _enemy_class(boss: bool, meteor: bool, rank: int) -> String:
	if boss: return "boss"
	if meteor: return "meteor"
	return "strong" if rank >= 3 else "regular"

func _life_row(enemy_type: String, enemy_class: String, elite: bool) -> Dictionary:
	var key := "%s/%s/%s" % [enemy_class, enemy_type, elite]
	if not _enemy_life.has(key):
		_enemy_life[key] = {"enemy": enemy_type, "class": enemy_class, "elite": elite, "spawned": 0, "killed": 0,
			"removed": 0, "alive_at_end": 0, "unknown_spawn": 0, "life_world_sum": 0.0,
			"life_world_count": 0, "first_hit_to_kill_world_sum": 0.0, "first_hit_to_kill_count": 0,
			"max_hp_at_spawn_sum": 0.0, "max_hp_at_spawn_count": 0}
	return _enemy_life[key]

func _on_enemy_spawned(row: int) -> void:
	var t := _run.enemies.table
	var enemy_type := String(t.type[row])
	var enemy_class := _enemy_class(t.is_boss[row] != 0, t.meteor_index[row] >= 0,
		t.def[row].rank if t.def[row] != null else 0)
	var elite := t.elite[row] != 0
	_enemy_seen[t.id[row]] = {"enemy": enemy_type, "class": enemy_class, "elite": elite, "t": _run.state.time,
		"world_t": _run.state.world_time, "observed_spawn": true, "first_hit_world_t": -1.0, "released": false}
	var life := _life_row(enemy_type, enemy_class, elite)
	life.spawned += 1
	life.max_hp_at_spawn_sum += t.max_hp[row]
	life.max_hp_at_spawn_count += 1

func _seed_existing_enemies() -> void:
	var t := _run.enemies.table
	for row in t.alive.size():
		if t.alive[row] == 0 or t.dead[row] != 0: continue
		var enemy_type := String(t.type[row])
		_enemy_seen[t.id[row]] = {"enemy": enemy_type,
			"class": _enemy_class(t.is_boss[row] != 0, t.meteor_index[row] >= 0,
				t.def[row].rank if t.def[row] != null else 0),
			"elite": t.elite[row] != 0, "t": _run.state.time, "world_t": _run.state.world_time,
			"observed_spawn": false, "first_hit_world_t": -1.0, "released": false}

func _on_enemy_released(row: int) -> void:
	var id: int = _run.enemies.table.id[row]
	if _enemy_seen.has(id): _enemy_seen[id].released = true

func _finish_enemy(id: int, result: String, event_world_t := -1.0) -> void:
	if not _enemy_seen.has(id): return
	var seen: Dictionary = _enemy_seen[id]
	var row := _life_row(seen.enemy, seen["class"], bool(seen.elite))
	var world_t := event_world_t if event_world_t >= 0.0 else _run.state.world_time
	match result:
		"killed": row.killed += 1
		"removed": row.removed += 1
		"alive": row.alive_at_end += 1
	if not seen.observed_spawn:
		row.unknown_spawn += 1
	elif result == "killed":
		row.life_world_sum += maxf(0.0, world_t - float(seen.world_t))
		row.life_world_count += 1
		if float(seen.first_hit_world_t) >= 0.0:
			row.first_hit_to_kill_world_sum += maxf(0.0, world_t - float(seen.first_hit_world_t))
			row.first_hit_to_kill_count += 1
	_enemy_seen.erase(id)

func _finish_removed_enemies() -> void:
	for id in _enemy_seen.keys():
		if _enemy_seen[id].released: _finish_enemy(id, "removed")

func _on_damage_recorded(hit: Dictionary) -> void:
	var cause := String(hit.cause)
	var weapon_id := String(hit.weapon_id)
	if weapon_id == "": weapon_id = WEAPON_CAUSES.get(cause, "")
	var enemy_type := String(hit.enemy_type)
	var enemy_class := _enemy_class(bool(hit.boss), bool(hit.meteor), int(hit.rank))
	var elite := bool(hit.elite)
	var key := "%s/%s/%s/%s/%s" % [weapon_id, enemy_class, enemy_type, elite, cause]
	if not _effective.has(key):
		_effective[key] = {"weapon_id": weapon_id, "enemy": enemy_type, "class": enemy_class, "elite": elite,
			"cause": cause, "hits": 0, "resolved": 0.0, "applied": 0.0, "overkill": 0.0, "discarded": 0.0}
	var item: Dictionary = _effective[key]
	item.hits += 1
	item.resolved += float(hit.resolved)
	item.applied += float(hit.applied)
	item.overkill += float(hit.overkill)
	item.discarded += maxf(0.0, float(hit.resolved) - float(hit.applied) - float(hit.overkill))
	var id: int = hit.id
	if float(hit.applied) > 0.0 and _enemy_seen.has(id) and float(_enemy_seen[id].first_hit_world_t) < 0.0:
		_enemy_seen[id].first_hit_world_t = _run.state.world_time

func _on_cards(cards: Array, observed := true, snapshot := false) -> void:
	_offered = []
	for c in cards:
		_offered.append("%s:%s:%d" % [c.kind, c.id, int(c.get("level", 0))])
	if observed and not _offered.is_empty() and _run != null:
		_offer_id += 1
		_write({"type": "offer", "t": _r(_run.state.time), "world_t": _run.state.world_time,
			"offer_id": _offer_id, "source": "initial_choice" if _run.state.start_pick else "comet_swap" if _run.state.swap_pick != &"" else "card",
			"offered": _offered.duplicate(), "rerolls_left": _run.state.rerolls_left, "snapshot": snapshot})

func _on_choice(card: Dictionary, source: StringName) -> void:
	_write({"type": "choice", "t": _r(_run.state.time), "world_t": _run.state.world_time,
		"level": _run.state.level, "source": String(source), "offer_id": _offer_id if _offer_id > 0 else null,
		"offered": _offered.duplicate(), "chosen": "%s:%s:%d" % [card.kind, card.id, int(card.get("level", 0))]})

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
			&"enemy_tuning_changed", &"enemy_tuning_saved":
				# t は通知を処理した時計。適用・保存そのものの時計は別に保ち、通知待ちを区別する。
				var record := {"type": String(e.type), "t": time, "world_t": _run.state.world_time,
					"event_t": e.get("t", null), "event_world_t": e.get("world_t", null), "values": e.get("values", null)}
				if e.type == &"enemy_tuning_saved": record["path"] = e.get("path", null)
				_write(record)
			&"bonus":
				_write({"type": "bonus", "t": time, "enter": bool(e.enter), "remaining": _run.state.bonus_t})
			&"barrier_hit":
				_on_enemy_contact({"cause": "hostile_projectile", "source": "", "reason": "barrier"})
			&"kill":
				var id: int = e.get("id", -1)
				_finish_enemy(id, "killed", float(e.get("world_t", -1.0)))
				if e.get("cause", &"") == &"finale":
					continue
				var ty := String(e.get("enemy_type", &""))
				_kills[ty] = int(_kills.get(ty, 0)) + 1
				var by := String(e.get("cause", &""))
				_kills_by[by] = int(_kills_by.get(by, 0)) + 1
				if _strong.has(id):
					var rec: Array = _strong[id]
					_write({"type": "strong", "t": time, "enemy": rec[0], "spawned": rec[1], "life": _r(time - rec[1]),
						"rams": rec[2], "weapon_damage": _r(rec[3]), "by_cause": rec[4], "killed_by": by, "result": "killed"})
					_strong.erase(id)
			&"boss_defeated":
				_finish_enemy(int(e.get("id", -1)), "killed", float(e.get("world_t", -1.0)))
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
				pick = {"type": "pick", "t": time, "level": _run.state.level, "offered": _offered.duplicate(),
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
	for actor in _run.bosses.actors: actor.finish_combat_observations("observation_end", "recording_end")
	_run.projectiles.clear_combat_observations()
	_flush_performance(_perf_last_us)
	for id in _enemy_seen.keys():
		_finish_enemy(id, "removed" if _enemy_seen[id].released else "alive")
	_sample()
	for id in _strong:
		var rec: Array = _strong[id]
		_write({"type": "strong", "t": _r(s.time), "enemy": rec[0], "spawned": rec[1], "life": _r(s.time - rec[1]),
			"rams": rec[2], "weapon_damage": _r(rec[3]), "by_cause": rec[4], "result": "alive"})
	_write({"type": "end", "t": _r(s.time), "result": result, "level": s.level, "kills": s.kills,
		"weapons": _plain(s.weapons), "traits": _plain(s.traits), "last_hurt": _last_hurt if result == "death" else {},
		"big_crystals": _big_crystals, "combat_summary": {"emitted": _run.bosses.diagnostics.emitted, "rate_or_count_dropped": _run.bosses.diagnostics.dropped,
			"size_dropped": _combat_dropped, "bytes": _combat_bytes, "transport_complete": _run.bosses.diagnostics.dropped == 0 and _combat_dropped == 0}})
	_flush()
	_saved_text = "記録に失敗しました" if _io_failed else "保存：" + _file.get_path().get_file()
	_saved_t = SAVED_NOTICE
	if _file != null: _file.close()
	_file = null
	_run.bosses.diagnostics.level = 0
	_run.projectiles.clear_combat_observations()
	if _run.bosses.diagnostics.recorded.is_connected(_on_combat): _run.bosses.diagnostics.recorded.disconnect(_on_combat)
	for sig in [[_run.frame_events, _on_events], [_run.phase_changed, _on_phase_changed], [_run.loadout.cards_opened, _on_cards],
		[_run.pickups.big_crystal_dropped, _on_big_crystal], [_run.pickups.xp_recorded, _write], [_run.loadout.loadout_recorded, _on_loadout],
		[_run.loadout.choice_recorded, _on_choice],
		[_run.ship.hurt_recorded, _on_hurt], [_run.ship.recording_hurt_attempt, _on_enemy_contact],
		[_run.enemies.recording_spawned, _on_enemy_spawned],
		[_run.enemies.recording_released, _on_enemy_released], [_run.combat.recording_damage, _on_damage_recorded]]:
		if sig[0].is_connected(sig[1]):
			sig[0].disconnect(sig[1])
	for c in _session.tree_exiting.get_connections() if is_instance_valid(_session) else []:
		if c.callable.get_object() == self:
			_session.tree_exiting.disconnect(c.callable)
	_close_profiles()
	_run = null
	_session = null
	_big_crystals = {}
	_strong = {}
	_enemy_seen = {}
	_offered = []
	_last_hurt = {}
	_skip_events = 0
	_update_label()

func _write(record: Dictionary) -> void:
	if _file != null and not _io_failed:
		var t0 := Time.get_ticks_usec()
		_write_line(record)
		# 録画そのものの重さ（書いた行数と、行を作って書く時間）
		_self_lines += 1
		_self_write_us += Time.get_ticks_usec() - t0

func _write_line(record: Dictionary) -> void:
	# 既存の区間行と出来事を同じ時計精度で並べる。
	if record.has("t"): record.t = _r(float(record.t))
	if _real_start_us > 0:
		if not record.has("real_t"):
			record.real_t = (Time.get_ticks_usec() - _real_start_us) / 1000000.0
	if _run != null:
		record["run_id"] = _run.bosses.diagnostics.run_id
		record["recording_id"] = _recording_id
	if not _store_line(JSON.stringify(record)): _fail_io()

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
	_perf_phase = _performance_phase()
	_perf_bonus = _run.state.bonus_t > 0.0
	_clear_performance()

func _clear_performance() -> void:
	_self_lines = 0
	_self_write_us = 0
	_perf_sim.clear()
	_perf_view.clear()
	_perf_rows.clear()
	_perf_frames = 0
	_perf_sum_us = 0
	_perf_max_us = 0
	_perf_over_33 = 0
	_perf_over_50 = 0
	_perf_hitstop = 0
	_perf_drawing = 0
	_perf_tracing = 0

## 報酬・メニューの表示は PLAY のまま世界を止めるため、性能集計では停止として扱う。
func _performance_phase() -> int:
	var phase: int = _run.state.phase
	if phase == RunState.Phase.PLAY and (_run.ui_reward_active or _run.ui_overlay_active):
		return RunState.Phase.PAUSED
	return phase

func _perf_tick(now_us: int) -> void:
	if _perf_last_us == 0:
		_perf_start(now_us)
		return
	var s = _run.state
	var phase := _performance_phase()
	var bonus: bool = s.bonus_t > 0.0
	if phase != _perf_phase or bonus != _perf_bonus:
		if phase == RunState.Phase.PLAY and phase == _perf_phase:
			# ボーナスへの出入りも遊んでいる同じ1フレーム。切替時の重さを落とさない。
			_add_performance_frame(now_us - _perf_last_us)
			_flush_performance(now_us)
		else:
			_flush_performance(_perf_last_us)
		# 停止・カード選択の間に描いた分を、次の区間へ混ぜない
		_clear_performance()
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
			"corona_members": (_run.enemies.behavior(&"corona").vortex.members.size() if _run.enemies.behavior(&"corona") != null else 0)},
		"profile": _profile_record()})
	if _file != null:
		_flush()
	_clear_performance()
	_perf_window_us = now_us

func _open_profiles() -> void:
	_perf_sim = _run.perf.open(&"recorder")
	_view = _session.view.get_node_or_null("RunPresentation") as RunPresentation if _session.view != null else null
	if _view != null:
		_perf_view = _view.perf.open(&"recorder")
		_perf_rows = _view.perf_rows.open(&"recorder")

func _close_profiles() -> void:
	if _run != null:
		_run.perf.close(&"recorder")
	if is_instance_valid(_view):
		_view.perf.close(&"recorder")
		_view.perf_rows.close(&"recorder")
	_view = null
	_perf_sim = {}
	_perf_view = {}
	_perf_rows = {}

## 区間の処理時間。sim・view は 項目 → [合計ms, 回数, 1回の最大ms]、enemy_rows は敵の描画1回あたりの行の数の平均、
## recorder は録画が書いた行数と、行を作って書いた時間の合計。
func _profile_record() -> Dictionary:
	var rows := {}
	for key in _perf_rows:
		var rec: Array = _perf_rows[key]
		rows[String(key)] = snappedf(float(rec[0]) / maxi(1, rec[1]), 0.1)
	return {"sim": _pack_times(_perf_sim), "view": _pack_times(_perf_view), "enemy_rows": rows,
		"recorder": {"lines": _self_lines, "write_ms": snappedf(_self_write_us / 1000.0, 0.001)}}

static func _pack_times(records: Dictionary) -> Dictionary:
	var out := {}
	for key in records:
		var rec: Array = records[key]
		out[String(key)] = [snappedf(rec[0] / 1000.0, 0.001), rec[1], snappedf(rec[2] / 1000.0, 0.001)]
	return out

func _on_combat(record: Dictionary) -> void:
	if _io_failed or _run == null: return
	# The source never includes resources, credentials, user input, or scene paths.
	var bytes := JSON.stringify(record).to_utf8_buffer().size() + 256
	if bytes > COMBAT_LINE_BYTES or _combat_bytes + bytes > maxi(0, combat_max_bytes):
		_combat_dropped += 1
		return
	_combat_bytes += bytes
	_write(record)

func _open_failed() -> void:
	_run = null
	_session = null
	_saved_text = "記録ファイルを開けませんでした"
	_saved_t = SAVED_NOTICE
	push_warning(_saved_text)
	_update_label()

## Seams also allow deterministic short-write / flush-failure tests without a real full disk.
func _store_line(line: String) -> bool:
	return _file.store_line(line) and _file.get_error() == OK

func _flush_file() -> bool:
	_file.flush()
	return _file.get_error() == OK

func _flush() -> void:
	if _file != null and not _io_failed and not _flush_file(): _fail_io()

func _fail_io() -> void:
	if _io_failed: return
	_io_failed = true
	if _run != null: _run.bosses.diagnostics.level = 0
	push_warning("プレイ記録の書き込みに失敗しました。記録を終了します。")
	call_deferred("_end", "io_error")

func _exit_tree() -> void:
	_end("quit")
