## プレイの記録（開発版だけ。設計書 14.3）。F9 で記録の待機を入・切する。
## 待機中に始めたランを、終わる（クリア・やられた・やめた）まで1つのファイルに書く。待機は F9 で切るまで続き、
## 次のランは別のファイルにする。実験場のランは記録しない。
## ファイルは user://recordings/stage<番号>_<日時>.jsonl。1行に1つの記録（JSON）で、メモリにためずに書き出す。
## 集計はしない（記録を読む側が行う）。
extends Node

## まとめた数を書く間隔（ランの時計の秒）
const INTERVAL := 3.0
const DIR := "user://recordings"

var armed := false
var _run: Node = null
var _file: FileAccess = null
var _next_sample := 0.0
var _last_xp_gained := 0.0
var _last_xp_dropped := 0.0
## 間隔のあいだにたまった数
var _kills: Dictionary = {}
var _damage: Dictionary = {}
var _budget_max := 0.0
## 強敵（星3以上）：id → [種類, 出た時刻, 体当たりの回数, 武器のダメージ]
var _strong: Dictionary = {}
## 直前に出たカードと、最後に受けた攻撃
var _offered: Array = []
var _last_hurt: Dictionary = {}
var _label: Label

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
	_label.offset_left = -170.0
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
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F9:
		_set_armed(not armed)

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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var path := "%s/stage%d_%s.jsonl" % [DIR, run.state.stage_index, stamp]
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
	var bands := []
	var phases: Array = run.state.stage.phases
	for k in phases.size():
		var p: PhaseDef = phases[k]
		bands.append({"id": String(p.id), "name": p.display_name, "start": p.start, "target_level": p.target_level})
	_write({"type": "start", "stage": run.state.stage_index, "stage_file": run.state.stage.resource_path.get_file(),
		"start_time": _r(run.state.time), "date": Time.get_datetime_string_from_system(), "interval": INTERVAL, "bands": bands})
	_update_label()

func _process(_delta: float) -> void:
	if _run == null:
		return
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
	var phase: PhaseDef = _run.enemies.current_phase()
	_write({"type": "sample", "t": _r(s.time), "band": String(phase.id),
		"xp_picked": _r(s.xp_gained - _last_xp_gained), "xp_dropped": _r(s.xp_dropped - _last_xp_dropped), "xp_field": _r(field_xp),
		"level": s.level, "hp": _r(s.ship_hp), "hp_max": _r(s.stats.max_hp),
		"enemies": total, "in_view": in_view, "by_star": by_star, "kills": _kills, "damage": _damage, "attack_budget_max": _r(_budget_max)})
	_last_xp_gained = s.xp_gained
	_last_xp_dropped = s.xp_dropped
	_reset_counts()
	_file.flush()

func _reset_counts() -> void:
	_kills = {}
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
			&"kill":
				if e.get("cause", &"") == &"finale":
					continue
				var ty := String(e.get("enemy_type", &""))
				_kills[ty] = int(_kills.get(ty, 0)) + 1
				var id: int = e.get("id", -1)
				if _strong.has(id):
					var rec: Array = _strong[id]
					_write({"type": "strong", "t": time, "enemy": rec[0], "spawned": rec[1], "life": _r(time - rec[1]),
						"rams": rec[2], "weapon_damage": _r(rec[3]), "result": "killed"})
					_strong.erase(id)
			&"hit":
				var id: int = e.get("id", -1)
				if _strong.has(id):
					var rec: Array = _strong[id]
					var cause: StringName = e.get("cause", &"")
					if cause == &"ram":
						rec[2] += 1
					elif cause != &"bump" and cause != &"touch":
						rec[3] += float(e.get("dmg", 0.0))
			&"hurt":
				var key := String(e.get("cause", &""))
				if String(e.get("source", &"")) != "":
					key += "/" + String(e.source)
				_damage[key] = _r(float(_damage.get(key, 0.0)) + float(e.get("amount", 0.0)))
				_last_hurt = {"cause": String(e.get("cause", &"")), "source": String(e.get("source", &""))}
			&"strong_spawn":
				_strong[e.id] = [String(e.enemy_type), time, 0, 0.0]
			&"clip_group":
				_write({"type": "clip_group", "t": time, "clip": e.clip, "key": e.key, "n": e.n})
			&"clip_group_end":
				_write({"type": "clip_group_end", "t": time, "clip": e.clip, "key": e.key})
			&"phase":
				var p: PhaseDef = _run.enemies.current_phase()
				_write({"type": "band", "t": time, "id": String(p.id), "name": p.display_name, "target_level": p.target_level})
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
	if phase != RunState.Phase.ENDED or _run == null:
		return
	var s = _run.state
	_end("clear" if s.cleared else ("death" if s.ship_hp <= 0.0 else "quit"))

## ランの記録を閉じる。
func _end(result: String) -> void:
	if _run == null:
		return
	var s = _run.state
	_sample()
	for id in _strong:
		var rec: Array = _strong[id]
		_write({"type": "strong", "t": _r(s.time), "enemy": rec[0], "spawned": rec[1], "life": _r(s.time - rec[1]),
			"rams": rec[2], "weapon_damage": _r(rec[3]), "result": "alive"})
	_write({"type": "end", "t": _r(s.time), "result": result, "level": s.level, "kills": s.kills,
		"weapons": _plain(s.weapons), "traits": _plain(s.traits), "last_hurt": _last_hurt if result == "death" else {}})
	_file.close()
	_file = null
	for sig in [[_run.frame_events, _on_events], [_run.phase_changed, _on_phase_changed], [_run.build.cards_opened, _on_cards]]:
		if sig[0].is_connected(sig[1]):
			sig[0].disconnect(sig[1])
	for c in _run.tree_exiting.get_connections():
		if c.callable.get_object() == self:
			_run.tree_exiting.disconnect(c.callable)
	_run = null
	_strong = {}
	_offered = []
	_last_hurt = {}
	_update_label()

func _write(record: Dictionary) -> void:
	if _file != null:
		_file.store_line(JSON.stringify(record))

func _update_label() -> void:
	if _label == null:
		return
	_label.visible = armed
	if _run != null:
		var t: float = _run.state.time
		_label.text = "● REC %d:%02d" % [int(t) / 60, int(t) % 60]
	else:
		_label.text = "● REC 待機"

static func _r(v: float) -> float:
	return snappedf(v, 0.01)

static func _plain(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out
