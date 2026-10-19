## 出現タイムラインのトラック。上から目盛り・時間帯・雑魚の補充の目標の数・クリップ（1本が1つ）を並べる。
## 時間帯の境目と、クリップの時刻・いる時間・回数・間隔をドラッグで変える。ラベルはダブルクリックで変える。
## 攻撃の組み合わせの表で禁止した組み合わせが同じ時間に重なるところを赤く出す。
@tool
extends Control

const GUTTER := 170.0
const RULER := 22.0
const PHASE_ROW := 44.0
const POP_ROW := 40.0
const TRACK := 26.0
const HANDLE := 6.0

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
## ドラッグ中：種類（"phase"・"time"・"stay"・"count"・"interval"・"pan"・"playhead"）、対象、押した所の時刻、前の値
var _drag := {}
var _rename: LineEdit = null

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	tooltip_text = "クリップをドラッグ：時刻　右端：いる時間　Shift＋右端：回数　2つ目の目盛り：間隔\n" + \
		"時間帯の境目をドラッグ：開始の時刻　目盛りをクリック：再生位置　ラベルをダブルクリック：名前\n" + \
		"ホイール・2本指の横スクロール：横に動かす　Ctrl（⌘）＋ホイール・ピンチ：拡大縮小\n" + \
		"Delete：選んだクリップを消す　Shift を押しながらドラッグすると 0.1 秒刻み"

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

## クリップの最後の群れが出る時刻。
static func _last_spawn(c: Resource) -> float:
	return float(c.get("time")) + maxf(0.0, float(c.get("interval"))) * maxi(0, int(c.get("count")) - 1)

static func _clip_end(c: Resource) -> float:
	return _last_spawn(c) + maxf(0.0, float(c.get("stay")))

## 禁止した組み合わせの重なり：[{"a": クリップの番号, "b": 番号, "from": 時刻, "to": 時刻}]
func conflicts() -> Array:
	var out := []
	var rules: Resource = timeline.rules()
	if rules == null:
		return out
	var cs: Array = timeline.clips()
	for a in cs.size():
		for b in range(a, cs.size()):
			var ta: Array = timeline.formation_types(cs[a])
			var tb: Array = timeline.formation_types(cs[b])
			var g := -1.0
			for x in ta:
				for y in tb:
					g = maxf(g, float(rules.call("gap", x, y)))
			if g < 0.0:
				continue
			for sa: float in _spawns(cs[a]):
				for sb: float in _spawns(cs[b]):
					if a == b and sa >= sb:
						continue
					var ea := sa + float(cs[a].get("stay"))
					var eb := sb + float(cs[b].get("stay"))
					if sa < eb + g and sb < ea + g:
						out.append({"a": a, "b": b, "from": maxf(sa, sb), "to": maxf(minf(ea, eb), maxf(sa, sb) + 1.0)})
	return out

static func _spawns(c: Resource) -> Array:
	var out := []
	for k in maxi(1, int(c.get("count"))):
		out.append(float(c.get("time")) + k * maxf(0.0, float(c.get("interval"))))
	return out

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.11, 0.14))
	if timeline == null or timeline.stage == null:
		draw_string(font, Vector2(16, 30), "ステージ（data/stages/*.tres）をインスペクターで開いてください")
		return
	var end := _end_time()
	# 終わりより先は暗くする
	if _x(end) < size.x:
		draw_rect(Rect2(_x(end), 0, size.x - _x(end), size.y), Color(0, 0, 0, 0.45))
	# 目盛り：ラベルの間隔が 70px 以上になる、切りのいい間隔
	draw_rect(Rect2(0, 0, size.x, RULER), Color(0.16, 0.17, 0.21))
	var step := 300.0
	for s: float in [1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0]:
		if s * px_per_sec >= 70.0:
			step = s
			break
	var minor := step / 5.0 if step / 5.0 * px_per_sec >= 8.0 else step
	var t := floorf(view_start / minor) * minor
	while _x(t) < size.x and t <= end + 0.001:
		var x := _x(t)
		if x >= GUTTER:
			var major := is_zero_approx(fmod(t + 0.0001, step)) or fmod(t + 0.0001, step) < 0.001
			draw_line(Vector2(x, RULER - (10.0 if major else 4.0)), Vector2(x, size.y), Color(1, 1, 1, 0.12 if major else 0.04))
			if major:
				draw_string(font, Vector2(x + 3, 15), clock(t) if step >= 1.0 else "%.1f" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		t += minor
	# 時間帯
	var ps: Array = timeline.phases()
	var top := RULER
	var max_pop := 1.0
	for p in ps:
		max_pop = maxf(max_pop, maxf(float(p.get("pop_from")), float(p.get("pop_to"))))
	for k in ps.size():
		var p: Resource = ps[k]
		var s := float(p.get("start"))
		var e := float(ps[k + 1].get("start")) if k + 1 < ps.size() else end
		var col := Color.from_hsv(fmod(k * 0.13, 1.0), 0.35, 0.45)
		var r := Rect2(_x(s), top + 2, (e - s) * px_per_sec, PHASE_ROW - 4)
		draw_rect(r, col)
		draw_line(Vector2(r.position.x, top), Vector2(r.position.x, size.y), Color(1, 1, 1, 0.35), 2.0)
		var name_ := str(p.get("display_name")) if str(p.get("display_name")) != "" else str(p.get("id"))
		draw_string(font, r.position + Vector2(4, 15), name_, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, r.size.x - 6), 13)
		var forms: Dictionary = p.get("formations") if p.get("formations") != null else {}
		var names := []
		for scene in forms:
			names.append("%s×%s" % [scene.resource_path.get_file().get_basename(), str(forms[scene])])
		if not names.is_empty():
			draw_string(font, r.position + Vector2(4, 32), "強敵 " + ", ".join(names), HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, r.size.x - 6), 11, Color(1, 0.85, 0.6))
		# 雑魚の補充の目標の数
		var y0 := RULER + PHASE_ROW + POP_ROW - 4.0
		var h := POP_ROW - 8.0
		draw_line(Vector2(_x(s), y0 - h * float(p.get("pop_from")) / max_pop), Vector2(_x(e), y0 - h * float(p.get("pop_to")) / max_pop), Color(0.5, 0.9, 0.6), 2.0)
	draw_string(font, Vector2(6, RULER + 16), "時間帯", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(font, Vector2(6, RULER + PHASE_ROW + 16), "雑魚の数（最大 %d）" % int(max_pop), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	# クリップ
	var cs: Array = timeline.clips()
	var bad := conflicts()
	for k in cs.size():
		var c: Resource = cs[k]
		var y := _tracks_top() + k * TRACK
		draw_rect(Rect2(0, y, size.x, TRACK), Color(1, 1, 1, 0.03 if k % 2 == 0 else 0.0))
		var label := str(c.get("label")) if str(c.get("label")) != "" else "（名前なし）"
		draw_string(font, Vector2(6, y + 17), label, HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 10, 13, Color(1, 1, 0.8) if k == selected else Color.WHITE)
		var x0 := _x(float(c.get("time")))
		var x1 := _x(_clip_end(c))
		var base := Color(0.35, 0.55, 0.95) if k != selected else Color(0.5, 0.75, 1.0)
		draw_rect(Rect2(x0, y + 4, maxf(2.0, x1 - x0), TRACK - 8), Color(base, 0.35))
		for st in _spawns(c):
			var sx := _x(st)
			draw_rect(Rect2(sx, y + 4, maxf(2.0, float(c.get("stay")) * px_per_sec), TRACK - 8), Color(base, 0.45))
			draw_line(Vector2(sx, y + 2), Vector2(sx, y + TRACK - 2), Color.WHITE, 2.0)
		draw_rect(Rect2(x1 - 3, y + 4, 3, TRACK - 8), Color.WHITE)
	for b in bad:
		for idx: int in [b.a, b.b]:
			var y := _tracks_top() + idx * TRACK
			draw_rect(Rect2(_x(b.from), y + 2, maxf(3.0, (b.to - b.from) * px_per_sec), TRACK - 4), Color(1, 0.2, 0.2, 0.45))
	# 再生位置
	var px := _x(playhead)
	draw_line(Vector2(px, 0), Vector2(px, size.y), Color(1, 0.8, 0.2), 2.0)
	draw_rect(Rect2(0, 0, GUTTER, RULER), Color(0.16, 0.17, 0.21))
	draw_line(Vector2(GUTTER, 0), Vector2(GUTTER, size.y), Color(1, 1, 1, 0.2))

## 位置 p にあるもの：{"kind", "index"}。
func _hit(p: Vector2) -> Dictionary:
	if p.y < RULER:
		return {"kind": "playhead"}
	var ps: Array = timeline.phases()
	if p.y < RULER + PHASE_ROW:
		for k in range(1, ps.size()):
			if absf(p.x - _x(float(ps[k].get("start")))) <= HANDLE:
				return {"kind": "phase", "index": k}
		return {}
	var k := int(floor((p.y - _tracks_top()) / TRACK))
	var cs: Array = timeline.clips()
	if p.y < _tracks_top() or k < 0 or k >= cs.size():
		return {}
	var c: Resource = cs[k]
	if p.x < GUTTER:
		return {"kind": "label", "index": k}
	var sp := _spawns(c)
	if absf(p.x - _x(_clip_end(c))) <= HANDLE:
		return {"kind": "count" if Input.is_key_pressed(KEY_SHIFT) else "stay", "index": k}
	if sp.size() >= 2 and absf(p.x - _x(sp[1])) <= HANDLE:
		return {"kind": "interval", "index": k}
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
		else:
			pan((pg.delta.x + pg.delta.y) * 12.0 / px_per_sec)
		accept_event()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom(mg.factor, mg.position.x)
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var wheel := mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
		if mb.pressed and wheel:
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
		"stay":
			_drag.target = timeline.clips()[h.index]
			_drag.props = ["stay"]
		"count":
			_drag.target = timeline.clips()[h.index]
			_drag.props = ["count", "interval"]
		"interval":
			_drag.target = timeline.clips()[h.index]
			_drag.props = ["interval"]
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
		"stay":
			_drag.target.set("stay", maxf(1.0, snappedf(t - _last_spawn(_drag.target), snap)))
		"interval":
			var first := float(_drag.target.get("time"))
			_drag.target.set("interval", maxf(1.0, snappedf(t - first, snap)))
		"count":
			var c: Resource = _drag.target
			var gap := float(c.get("interval"))
			if gap <= 0.0:
				gap = maxf(1.0, float(c.get("stay")))
				c.set("interval", gap)
			var last := t - float(c.get("stay"))
			c.set("count", maxi(1, int(round((last - float(c.get("time"))) / gap)) + 1))
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

func _start_rename(k: int) -> void:
	var c: Resource = timeline.clips()[k]
	if _rename != null:
		_rename.queue_free()
	_rename = LineEdit.new()
	_rename.text = str(c.get("label"))
	_rename.position = Vector2(2, _tracks_top() + k * TRACK)
	_rename.size = Vector2(GUTTER - 4, TRACK)
	add_child(_rename)
	_rename.grab_focus()
	_rename.select_all()
	var done := func() -> void:
		if _rename == null:
			return
		var before := str(c.get("label"))
		var after := _rename.text
		_rename.queue_free()
		_rename = null
		if after != before:
			c.set("label", after)
			timeline.commit("クリップの名前を変える", [[c, "label", before, after]])
	_rename.text_submitted.connect(func(_text: String) -> void: done.call())
	_rename.focus_exited.connect(done)
