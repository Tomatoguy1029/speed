## 出現タイムラインのトラック。上から目盛り・時間帯・雑魚の補充の目標の数・クリップ（1本が1つ）を並べる。
## 時間帯の境目と、クリップの開始・長さをドラッグで変える。ラベルはダブルクリックで変える。
## フォーメーションに、クリップの種類の組み合わせにない敵を置いているクリップを赤く出す。
## 大きさはエディタの表示倍率に合わせる。トラックは縦にスクロールし、目盛り・時間帯・雑魚の数は上に留める。
@tool
extends Control

## 大きさ（表示倍率 1 のとき）
const BASE := {"gutter": 230.0, "ruler": 30.0, "phase": 50.0, "pop": 48.0, "track": 38.0, "handle": 8.0}

## 表示倍率と、それを掛けた大きさ
var ui := 1.0
var GUTTER := 230.0
var RULER := 30.0
var PHASE_ROW := 50.0
var POP_ROW := 48.0
var TRACK := 38.0
var HANDLE := 8.0

var timeline
## 再生位置（秒）
var playhead := 0.0
## 選んでいるクリップの番号（-1 ならなし）
var selected := -1
## 見えている範囲の左端の時刻と、1秒の幅
var view_start := 0.0
var px_per_sec := 2.0
## 拡大縮小・横移動をしたか（していなければ、大きさが変わるたびに全体を表示し直す）
var _user_view := false
## ドラッグ中：種類（"phase"・"time"・"length"・"pan"・"playhead"）、対象、押した所の時刻、前の値
var _drag := {}
var _rename: LineEdit = null

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	if Engine.is_editor_hint():
		ui = EditorInterface.get_editor_scale()
	GUTTER = BASE.gutter * ui
	RULER = BASE.ruler * ui
	PHASE_ROW = BASE.phase * ui
	POP_ROW = BASE.pop * ui
	TRACK = BASE.track * ui
	HANDLE = BASE.handle * ui
	tooltip_text = "クリップをドラッグ：開始の時刻　右端をドラッグ：長さ\n" + \
		"時間帯の境目をドラッグ：開始の時刻　時間帯・クリップのラベルをダブルクリック：名前　目盛りをクリック：再生位置\n" + \
		"ホイール・2本指の縦スクロール：上下に動かす　Shift＋ホイール・2本指の横スクロール：左右に動かす\n" + \
		"Ctrl（⌘）＋ホイール・ピンチ：拡大縮小\n" + \
		"Delete：選んだクリップを消す　Shift を押しながらドラッグすると 0.1 秒刻み"

## 文字の大きさ（表示倍率を掛ける）。
func _fs(n: float) -> int:
	return int(round(n * ui))

## トラックを縦にスクロールしている量（上に留める部分の位置）。
func _scroll_y() -> float:
	var sc := get_parent() as ScrollContainer
	return float(sc.scroll_vertical) if sc != null else 0.0

## 中身の高さ（縦のスクロールに使う）。
func content_height() -> float:
	return _tracks_top() + timeline.clips().size() * TRACK + 12.0 * ui

## m:ss の形の時刻。
static func clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _user_view:
		fit()

## ステージの長さ全体が収まるように表示する。
func fit() -> void:
	_user_view = false
	view_start = 0.0
	px_per_sec = _min_px()
	queue_redraw()

## 一番縮めたときの1秒の幅（ステージの長さ全体が収まる幅）。
func _min_px() -> float:
	return maxf(0.05, (size.x - GUTTER - 16.0)) / maxf(60.0, _end_time())

## 拡大縮小する。factor が 1 より大きければ拡大。at_x の位置の時刻を動かさない。
func zoom(factor: float, at_x := -1.0) -> void:
	if at_x < 0.0:
		at_x = GUTTER + (size.x - GUTTER) / 2.0
	var at := _t(at_x)
	px_per_sec = clampf(px_per_sec * factor, _min_px(), 40.0)
	view_start = at - (at_x - GUTTER) / px_per_sec
	_user_view = true
	_clamp_view()

## 横に動かす（秒）。
func pan(seconds: float) -> void:
	view_start += seconds
	_user_view = true
	_clamp_view()

func _clamp_view() -> void:
	var shown := (size.x - GUTTER) / px_per_sec
	view_start = clampf(view_start, 0.0, maxf(0.0, _end_time() - shown + 8.0 / px_per_sec))
	queue_redraw()

func _x(t: float) -> float:
	return GUTTER + (t - view_start) * px_per_sec

func _t(x: float) -> float:
	return view_start + (x - GUTTER) / px_per_sec

func _tracks_top() -> float:
	return RULER + PHASE_ROW + POP_ROW

## タイムラインの終わりの時刻（10:00 か、最後の時間帯の開始・クリップの終わりに少し足した遅い方）。
func _end_time() -> float:
	var t := 600.0
	if timeline == null:
		return t
	var ps: Array = timeline.phases()
	if not ps.is_empty():
		t = maxf(t, float(ps[ps.size() - 1].get("start")) + 60.0)
	for c in timeline.clips():
		t = maxf(t, _clip_end(c) + 30.0)
	return t

static func _clip_end(c: Resource) -> float:
	return float(c.get("time")) + maxf(0.0, float(c.get("length")))

## 種類が合わないクリップの番号の一覧。
func mismatches() -> Array:
	var out := []
	var cs: Array = timeline.clips()
	for k in cs.size():
		if not timeline.clip_mismatch(cs[k]).is_empty():
			out.append(k)
	return out

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.11, 0.14))
	if timeline == null or timeline.stage == null:
		draw_string(font, Vector2(16, 30) * ui, "ステージ（data/stages/*.tres）をインスペクターで開いてください", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15))
		return
	var end := _end_time()
	var off := _scroll_y()
	# クリップ：開始から長さの間の棒。中に種類・同時の群れの数・出す間隔を書く
	var cs: Array = timeline.clips()
	var bad := mismatches()
	for k in cs.size():
		var c: Resource = cs[k]
		var y := _tracks_top() + k * TRACK
		draw_rect(Rect2(0, y, size.x, TRACK), Color(1, 1, 1, 0.04 if k % 2 == 0 else 0.0))
		var label := str(c.get("label")) if str(c.get("label")) != "" else "（名前なし）"
		draw_string(font, Vector2(8 * ui, y + TRACK * 0.66), label, HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 12 * ui, _fs(15), Color(1, 1, 0.8) if k == selected else Color.WHITE)
		var x0 := _x(float(c.get("time")))
		var x1 := _x(_clip_end(c))
		var base := Color(0.35, 0.55, 0.95) if k != selected else Color(0.5, 0.75, 1.0)
		var r := Rect2(x0, y + 4 * ui, maxf(3.0, x1 - x0), TRACK - 8 * ui)
		draw_rect(r, Color(base, 0.55))
		if k in bad:
			draw_rect(r, Color(1, 0.3, 0.3), false, 2.0 * ui)
		var names := []
		for type_id in c.get("types"):
			names.append(String(type_id))
		var text := "%s　×%d　%ds" % ["・".join(names) if not names.is_empty() else "種類なし", int(c.get("groups")), int(c.get("interval"))]
		draw_string(font, r.position + Vector2(6 * ui, r.size.y * 0.7), text, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, r.size.x - 10 * ui), _fs(14))
		draw_rect(Rect2(x1 - 3 * ui, r.position.y, 3 * ui, r.size.y), Color.WHITE)
	# 終わりより先は暗くする
	if _x(end) < size.x:
		draw_rect(Rect2(_x(end), 0, size.x - _x(end), size.y), Color(0, 0, 0, 0.45))
	# ここから上に留める部分（目盛り・時間帯・雑魚の数）
	draw_rect(Rect2(0, off, size.x, _tracks_top()), Color(0.1, 0.11, 0.14))
	draw_rect(Rect2(0, off, size.x, RULER), Color(0.16, 0.17, 0.21))
	# 目盛り：ラベルの間隔が十分空く、切りのいい間隔
	var step := 300.0
	for st: float in [1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0]:
		if st * px_per_sec >= 80.0 * ui:
			step = st
			break
	var minor := step / 5.0 if step / 5.0 * px_per_sec >= 10.0 * ui else step
	var t := floorf(view_start / minor) * minor
	while _x(t) < size.x and t <= end + 0.001:
		var x := _x(t)
		if x >= GUTTER:
			var major := fmod(t + 0.0001, step) < 0.001
			draw_line(Vector2(x, off + RULER - (12.0 if major else 5.0) * ui), Vector2(x, size.y), Color(1, 1, 1, 0.12 if major else 0.04))
			if major:
				draw_string(font, Vector2(x + 4 * ui, off + RULER * 0.66), clock(t), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(14))
		t += minor
	var ps: Array = timeline.phases()
	var top := off + RULER
	var max_pop := 1.0
	for p in ps:
		max_pop = maxf(max_pop, maxf(float(p.get("pop_from")), float(p.get("pop_to"))))
	for k in ps.size():
		var p: Resource = ps[k]
		var s := float(p.get("start"))
		var e := float(ps[k + 1].get("start")) if k + 1 < ps.size() else end
		var col := Color.from_hsv(fmod(k * 0.13, 1.0), 0.35, 0.45)
		var r := Rect2(_x(s), top + 3 * ui, (e - s) * px_per_sec, PHASE_ROW - 6 * ui)
		draw_rect(r, col)
		draw_line(Vector2(r.position.x, top), Vector2(r.position.x, size.y), Color(1, 1, 1, 0.35), 2.0 * ui)
		var name_ := str(p.get("display_name")) if str(p.get("display_name")) != "" else str(p.get("id"))
		draw_string(font, r.position + Vector2(6 * ui, r.size.y * 0.62), name_, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, r.size.x - 8 * ui), _fs(15))
		# 雑魚の補充の目標の数
		var y0 := off + RULER + PHASE_ROW + POP_ROW - 6.0 * ui
		var h := POP_ROW - 12.0 * ui
		draw_line(Vector2(_x(s), y0 - h * float(p.get("pop_from")) / max_pop), Vector2(_x(e), y0 - h * float(p.get("pop_to")) / max_pop), Color(0.5, 0.9, 0.6), 2.0 * ui)
	draw_rect(Rect2(0, off, GUTTER, _tracks_top()), Color(0.1, 0.11, 0.14))
	draw_rect(Rect2(0, off, GUTTER, RULER), Color(0.16, 0.17, 0.21))
	draw_string(font, Vector2(8 * ui, off + RULER + PHASE_ROW * 0.6), "時間帯", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15))
	draw_string(font, Vector2(8 * ui, off + RULER + PHASE_ROW + POP_ROW * 0.6), "雑魚の数（最大 %d）" % int(max_pop), HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 12 * ui, _fs(14))
	draw_line(Vector2(0, off + _tracks_top()), Vector2(size.x, off + _tracks_top()), Color(1, 1, 1, 0.25))
	# 再生位置
	var px := _x(playhead)
	draw_line(Vector2(px, off), Vector2(px, size.y), Color(1, 0.8, 0.2), 2.0 * ui)
	draw_line(Vector2(GUTTER, 0), Vector2(GUTTER, size.y), Color(1, 1, 1, 0.2))

## 位置 p にあるもの：{"kind", "index"}。
func _hit(p: Vector2) -> Dictionary:
	var hy := p.y - _scroll_y()
	if hy < RULER:
		return {"kind": "playhead"}
	var ps: Array = timeline.phases()
	if hy < _tracks_top() and hy >= RULER + PHASE_ROW:
		return {}
	if hy < RULER + PHASE_ROW:
		for k in range(1, ps.size()):
			if absf(p.x - _x(float(ps[k].get("start")))) <= HANDLE:
				return {"kind": "phase", "index": k}
		var at := _t(p.x)
		for k in range(ps.size() - 1, -1, -1):
			if at >= float(ps[k].get("start")):
				return {"kind": "phase_body", "index": k}
		return {}
	var k := int(floor((p.y - _tracks_top()) / TRACK))
	var cs: Array = timeline.clips()
	if p.y < _tracks_top() or k < 0 or k >= cs.size():
		return {}
	var c: Resource = cs[k]
	if p.x < GUTTER:
		return {"kind": "label", "index": k}
	if absf(p.x - _x(_clip_end(c))) <= HANDLE:
		return {"kind": "length", "index": k}
	if p.x >= _x(float(c.get("time"))) - HANDLE and p.x <= _x(_clip_end(c)):
		return {"kind": "time", "index": k}
	return {}

func _gui_input(event: InputEvent) -> void:
	if timeline == null or timeline.stage == null:
		return
	if event is InputEventPanGesture:
		# トラックパッドの2本指スクロール。Ctrl（⌘）を押していれば拡大縮小
		var pg := event as InputEventPanGesture
		if pg.ctrl_pressed or pg.meta_pressed:
			zoom(exp(-pg.delta.y * 0.08), pg.position.x)
			accept_event()
		elif absf(pg.delta.x) > absf(pg.delta.y):
			pan(pg.delta.x * 12.0 / px_per_sec)
			accept_event()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom(mg.factor, mg.position.x)
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var wheel := mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
		var sideways := mb.shift_pressed or mb.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
		if mb.pressed and wheel and (mb.ctrl_pressed or mb.meta_pressed or sideways):
			var dir := 1.0 if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else -1.0
			if mb.ctrl_pressed or mb.meta_pressed:
				zoom(1.0 + 0.15 * dir, mb.position.x)
			else:
				pan(-dir * 40.0 / px_per_sec)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = {"kind": "pan", "x": mb.position.x, "start": view_start} if mb.pressed else {}
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			grab_focus()
			var h := _hit(mb.position)
			if h.is_empty():
				return
			if h.kind == "label" and mb.double_click:
				_start_rename(h.index)
				return
			if h.kind == "phase_body":
				if mb.double_click:
					_start_phase_rename(h.index)
				return
			if h.has("index") and h.kind != "phase":
				selected = h.index
				EditorInterface.inspect_object(timeline.clips()[selected], "", true)
			_begin_drag(h, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not _drag.is_empty():
			_end_drag()
	elif event is InputEventMouseMotion and not _drag.is_empty():
		_move_drag((event as InputEventMouseMotion).position, (event as InputEventMouseMotion).shift_pressed)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_DELETE:
		timeline._remove_clip()
		accept_event()

func _begin_drag(h: Dictionary, p: Vector2) -> void:
	_drag = h.duplicate()
	_drag.t0 = _t(p.x)
	match h.kind:
		"playhead":
			playhead = maxf(0.0, _t(p.x))
			timeline.refresh()
		"phase":
			_drag.target = timeline.phases()[h.index]
			_drag.props = ["start"]
		"time":
			_drag.target = timeline.clips()[h.index]
			_drag.props = ["time"]
		"length":
			_drag.target = timeline.clips()[h.index]
			_drag.props = ["length"]
	if _drag.has("target"):
		_drag.before = {}
		for prop in _drag.props:
			_drag.before[prop] = _drag.target.get(prop)

func _move_drag(p: Vector2, fine: bool) -> void:
	var t := _t(p.x)
	var snap := 0.1 if fine else 1.0
	match _drag.kind:
		"pan":
			view_start = _drag.start - (p.x - _drag.x) / px_per_sec
			_user_view = true
			_clamp_view()
		"playhead":
			playhead = maxf(0.0, t)
		"phase":
			var ps: Array = timeline.phases()
			var k: int = _drag.index
			var lo := float(ps[k - 1].get("start")) + 1.0
			var hi := float(ps[k + 1].get("start")) - 1.0 if k + 1 < ps.size() else 1e9
			_drag.target.set("start", clampf(snappedf(t, snap), lo, hi))
		"time":
			_drag.target.set("time", maxf(0.0, snappedf(float(_drag.before.time) + t - _drag.t0, snap)))
		"length":
			_drag.target.set("length", maxf(1.0, snappedf(t - float(_drag.target.get("time")), snap)))
	timeline.refresh()

func _end_drag() -> void:
	if _drag.has("target"):
		var changes := []
		for prop in _drag.props:
			if _drag.target.get(prop) != _drag.before[prop]:
				changes.append([_drag.target, prop, _drag.before[prop], _drag.target.get(prop)])
		if not changes.is_empty():
			timeline.commit("出現タイムラインを編集", changes)
	_drag = {}

## 時間帯 k の名前（display_name）を、その区間の上で書き換える。
func _start_phase_rename(k: int) -> void:
	var p: Resource = timeline.phases()[k]
	var ps: Array = timeline.phases()
	var x0 := maxf(GUTTER, _x(float(p.get("start"))))
	var x1 := _x(float(ps[k + 1].get("start"))) if k + 1 < ps.size() else size.x
	_open_editor(str(p.get("display_name")), Rect2(x0, _scroll_y() + RULER, maxf(160.0 * ui, x1 - x0), PHASE_ROW),
		func(text: String) -> void:
			var before := str(p.get("display_name"))
			if text != before:
				p.set("display_name", text)
				timeline.commit("時間帯の名前を変える", [[p, "display_name", before, text]]))

## 文字の入力欄を rect に出し、確定したら done(文字) を呼ぶ。
func _open_editor(text: String, rect: Rect2, done: Callable) -> void:
	if _rename != null:
		_rename.queue_free()
	_rename = LineEdit.new()
	_rename.text = text
	_rename.position = rect.position
	_rename.size = rect.size
	_rename.add_theme_font_size_override("font_size", _fs(15))
	add_child(_rename)
	_rename.grab_focus()
	_rename.select_all()
	var finish := func() -> void:
		if _rename == null:
			return
		var value := _rename.text
		_rename.queue_free()
		_rename = null
		done.call(value)
	_rename.text_submitted.connect(func(_text: String) -> void: finish.call())
	_rename.focus_exited.connect(finish)

func _start_rename(k: int) -> void:
	var c: Resource = timeline.clips()[k]
	_open_editor(str(c.get("label")), Rect2(2.0, _tracks_top() + k * TRACK, GUTTER - 4.0, TRACK),
		func(text: String) -> void:
			var before := str(c.get("label"))
			if text != before:
				c.set("label", text)
				timeline.commit("クリップの名前を変える", [[c, "label", before, text]]))
