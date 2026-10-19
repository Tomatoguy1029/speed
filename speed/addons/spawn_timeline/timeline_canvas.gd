## 出現タイムラインのトラック。上から目盛り・時間帯・雑魚の補充の目標の数・クリップ（1本が1つ）を並べる。
## 時間帯の境目と、クリップの開始・長さをドラッグで変える。ラベルはダブルクリックで変える。
## フォーメーションに、クリップの種類の組み合わせにない敵を置いているクリップを赤く出す。
## 大きさはエディタの表示倍率に合わせる。トラックは縦にスクロールし、目盛り・時間帯・雑魚の数は上に留める。
@tool
extends Control

## 操作の説明（パネルの「操作」ボタンで出す）
const HELP := "クリップをドラッグ：開始の時刻　右端をドラッグ：長さ\n" + \
		"クリップを上下にドラッグ：トラックを移す　クリップ・トラック名をダブルクリック：名前　右クリック・⌘C/⌘V/⌘D：コピー・貼り付け・複製\n" + \
		"時間帯の境目をドラッグ：開始の時刻　時間帯をダブルクリック：名前　目盛りをクリック：再生位置\n" + \
		"雑魚の曲線：何もない所をダブルクリックで点を足す　点をドラッグで動かす　点をダブルクリックで時刻と数を入力（例 2:00 30）　↑↓で数を1ずつ（Shift で10ずつ）　Delete で点を消す\n" + \
		"ホイール・2本指の縦スクロール：上下に動かす　Shift＋ホイール・2本指の横スクロール：左右に動かす\n" + \
		"Ctrl（⌘）＋ホイール・ピンチ：拡大縮小\n" + \
		"Delete：選んだクリップを消す　Shift を押しながらドラッグすると 0.1 秒刻み"

## 大きさ（表示倍率 1 のとき）
const BASE := {"gutter": 230.0, "ruler": 30.0, "phase": 50.0, "pop": 48.0, "track": 38.0, "handle": 8.0, "curve": 84.0}

## 表示倍率と、それを掛けた大きさ
var ui := 1.0
var GUTTER := 230.0
var RULER := 30.0
var PHASE_ROW := 50.0
var POP_ROW := 48.0
var TRACK := 38.0
var HANDLE := 8.0
var CURVE_ROW := 84.0
## 選んでいる雑魚の曲線と、その点の番号（-1 ならなし）
var curve_selected := -1
var point_selected := -1
## マウスが近くにある曲線の点（-1 ならなし）
var _hover_curve := -1
var _hover_point := -1

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
	CURVE_ROW = BASE.curve * ui

## 文字の大きさ（表示倍率を掛ける）。
func _fs(n: float) -> int:
	return int(round(n * ui))

## トラックを縦にスクロールしている量（上に留める部分の位置）。
func _scroll_y() -> float:
	var sc := get_parent() as ScrollContainer
	return float(sc.scroll_vertical) if sc != null else 0.0

## 中身の高さ（縦のスクロールに使う）。
func content_height() -> float:
	return _clips_top() + track_count() * TRACK + 12.0 * ui

## クリップ k の置かれたトラック（番号を持たないクリップは、並びの番号のトラック）。
func clip_track(k: int) -> int:
	var t := int(timeline.clips()[k].get("track"))
	return t if t >= 0 else k

## トラック row の名前（ステージの track_names。なければ番号）。
func track_name(row: int) -> String:
	var names = timeline.stage.get("track_names")
	if names != null and row < names.size() and String(names[row]) != "":
		return String(names[row])
	return "トラック %d" % (row + 1)

## トラック row の名前を、左の欄の上で書き換える。
func _start_track_rename(row: int) -> void:
	_open_editor(track_name(row), Rect2(2.0, _clips_top() + row * TRACK, GUTTER - 4.0, TRACK),
		func(text: String) -> void:
			var stage: Resource = timeline.stage
			if stage.get("track_names") == null:
				return
			var before: PackedStringArray = stage.get("track_names")
			var after := before.duplicate()
			while after.size() <= row:
				after.append("")
			after[row] = text
			if after != before:
				stage.set("track_names", after)
				timeline.commit("トラックの名前を変える", [[stage, "track_names", before, after]]))

## トラックの数（クリップのある一番下のトラックの次に、空のトラックを1本足す）。
func track_count() -> int:
	var n := 0
	for k in timeline.clips().size():
		n = maxi(n, clip_track(k) + 1)
	return n + 1

## トラック row で、時刻 [from, to) にほかのクリップ（except を除く）があるか。
func track_busy(row: int, from: float, to: float, except := -1) -> bool:
	var cs: Array = timeline.clips()
	for k in cs.size():
		if k == except or clip_track(k) != row:
			continue
		var s0 := float(cs[k].get("time"))
		if from < _clip_end(cs[k]) and s0 < to:
			return true
	return false

## 時刻 [from, to) が空いているトラック（prefer から下へ探す。なければ新しいトラック）。
func free_track(prefer: int, from: float, to: float) -> int:
	var row := maxi(0, prefer)
	while row < track_count() - 1 and track_busy(row, from, to):
		row += 1
	return row

## 雑魚の曲線の行の上端と、クリップの行の上端。
func _curves_top() -> float:
	return _tracks_top()

func _clips_top() -> float:
	return _curves_top() + timeline.curves().size() * CURVE_ROW

## 曲線ごとの、1秒ごとの値（点が変わったときだけ計算し直す）：曲線 → {"key", "values"}
var _curve_cache: Dictionary = {}

## 曲線 c の、0 秒から終わりまで1秒ごとの値。
func _curve_values(c: Resource, end: float) -> PackedFloat32Array:
	var pts: PackedVector2Array = c.get("points")
	var key := hash([pts, int(end)])
	var cached: Dictionary = _curve_cache.get(c, {})
	if cached.get("key", 0) == key:
		return cached.values
	var values := PackedFloat32Array()
	values.resize(int(end) + 2)
	for n in values.size():
		values[n] = _sample(pts, float(n))
	_curve_cache[c] = {"key": key, "values": values}
	return values

## 点の並び pts を、行き過ぎないなめらかな曲線（単調な3次補間）でつないだときの、時刻 t の値。
## ゲームの雑魚の目標の数の曲線（data_types/spawn_curve.gd の sample）と同じつなぎ方。この道具は Godot 本体だけに
## 依存するので（設計書 4.1）、ゲームのスクリプトを呼ばずに、ここでも同じ計算をする。
static func _sample(pts: PackedVector2Array, t: float) -> float:
	var n := pts.size()
	if n == 0:
		return 0.0
	if n == 1 or t <= pts[0].x:
		return pts[0].y
	if t >= pts[n - 1].x:
		return pts[n - 1].y
	var k := 0
	while k < n - 2 and t > pts[k + 1].x:
		k += 1
	var h := maxf(pts[k + 1].x - pts[k].x, 0.0001)
	var s := (t - pts[k].x) / h
	var m0 := _slope(pts, k)
	var m1 := _slope(pts, k + 1)
	var s2 := s * s
	var s3 := s2 * s
	return (2.0 * s3 - 3.0 * s2 + 1.0) * pts[k].y + (s3 - 2.0 * s2 + s) * h * m0 \
		+ (-2.0 * s3 + 3.0 * s2) * pts[k + 1].y + (s3 - s2) * h * m1

static func _slope(pts: PackedVector2Array, k: int) -> float:
	var n := pts.size()
	var left := (pts[k].y - pts[k - 1].y) / maxf(pts[k].x - pts[k - 1].x, 0.0001) if k > 0 else 0.0
	var right := (pts[k + 1].y - pts[k].y) / maxf(pts[k + 1].x - pts[k].x, 0.0001) if k < n - 1 else 0.0
	if k == 0:
		return right
	if k == n - 1:
		return left
	if left * right <= 0.0:
		return 0.0
	return 2.0 * left * right / (left + right)

## 1秒ごとの値 values の、時刻 t の値（間はまっすぐつなぐ）。
static func _value_at(values: PackedFloat32Array, t: float) -> float:
	if values.is_empty():
		return 0.0
	var i := clampi(int(t), 0, values.size() - 1)
	var j := mini(i + 1, values.size() - 1)
	return lerpf(values[i], values[j], clampf(t - float(i), 0.0, 1.0))

## 曲線の行の縦の目盛りの最大（点の最大より少し上。ドラッグ中は変えない）。
func _curve_max(c: Resource) -> float:
	if _drag.get("kind", "") == "point" and _drag.get("curve") == c:
		return float(_drag.vmax)
	var m := 10.0
	for p: Vector2 in c.get("points"):
		m = maxf(m, p.y)
	return ceilf(m * 1.25 / 5.0) * 5.0

## 曲線の行 k で、目標の数 v の y と、y の目標の数。
func _curve_y(k: int, v: float, vmax: float) -> float:
	var top := _curves_top() + k * CURVE_ROW
	return top + CURVE_ROW - 6.0 * ui - (CURVE_ROW - 14.0 * ui) * v / vmax

func _curve_v(k: int, y: float, vmax: float) -> float:
	var top := _curves_top() + k * CURVE_ROW
	return maxf(0.0, (top + CURVE_ROW - 6.0 * ui - y) / (CURVE_ROW - 14.0 * ui) * vmax)

## 数を、整数ならそのまま、そうでなければ小数1桁で。
static func _num(v: float) -> String:
	return "%d" % int(v) if is_equal_approx(v, roundf(v)) else "%.1f" % v

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
	# トラック：1行に複数のクリップ。クリップは開始から長さの間の棒で、中に名前・種類・同時の群れの数・出す間隔を書く
	var cs: Array = timeline.clips()
	var bad := mismatches()
	for row in track_count():
		var y := _clips_top() + row * TRACK
		draw_rect(Rect2(0, y, size.x, TRACK), Color(1, 1, 1, 0.04 if row % 2 == 0 else 0.0))
		var title := track_name(row) if row < track_count() - 1 else "（新しいトラック）"
		draw_string(font, Vector2(8 * ui, y + TRACK * 0.66), title, HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 12 * ui, _fs(14), Color(1, 1, 1, 0.75 if row < track_count() - 1 else 0.35))
	for k in cs.size():
		var c: Resource = cs[k]
		var y := _clips_top() + clip_track(k) * TRACK
		var x0 := _x(float(c.get("time")))
		var x1 := _x(_clip_end(c))
		var base := Color(0.35, 0.55, 0.95) if k != selected else Color(0.5, 0.75, 1.0)
		var r := Rect2(x0, y + 4 * ui, maxf(3.0, x1 - x0), TRACK - 8 * ui)
		draw_rect(r, Color(base, 0.7))
		if k == selected:
			draw_rect(r, Color(1, 1, 0.8), false, 2.0 * ui)
		if k in bad:
			draw_rect(r, Color(1, 0.3, 0.3), false, 2.0 * ui)
		var names := []
		for type_id in c.get("types"):
			names.append(timeline.enemy_name(type_id))
		var label := str(c.get("label")) if str(c.get("label")) != "" else "（名前なし）"
		var text := "%s　%s ×%d %ds" % [label, "・".join(names) if not names.is_empty() else "種類なし", int(c.get("groups")), int(c.get("interval"))]
		draw_string(font, r.position + Vector2(6 * ui, r.size.y * 0.7), text, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, r.size.x - 10 * ui), _fs(14))
		draw_rect(Rect2(x1 - 3 * ui, r.position.y, 3 * ui, r.size.y), Color.WHITE)
	# 雑魚の目標の数の曲線：種類ごとの行に、曲線と点を描く
	var curves: Array = timeline.curves()
	for k in curves.size():
		var c: Resource = curves[k]
		var top := _curves_top() + k * CURVE_ROW
		draw_rect(Rect2(0, top, size.x, CURVE_ROW), Color(0.3, 0.9, 0.5, 0.06 if k == curve_selected else 0.03))
		draw_line(Vector2(0, top + CURVE_ROW), Vector2(size.x, top + CURVE_ROW), Color(1, 1, 1, 0.08))
		var vmax := _curve_max(c)
		# 縦の目盛り：切りのいい間隔で横線と数を描く
		var grid_step := 1.0
		for gs: float in [1.0, 2.0, 5.0, 10.0, 20.0, 25.0, 50.0, 100.0, 200.0, 250.0, 500.0, 1000.0]:
			grid_step = gs
			if vmax / gs <= 4.0:
				break
		var gv := 0.0
		while gv <= vmax + 0.001:
			var gy := _curve_y(k, gv, vmax)
			draw_line(Vector2(GUTTER, gy), Vector2(size.x, gy), Color(1, 1, 1, 0.07 if gv > 0.0 else 0.15))
			draw_string(font, Vector2(GUTTER + 4 * ui, gy - 2 * ui), "%d" % int(gv), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(11), Color(1, 1, 1, 0.45))
			gv += grid_step
		var values := _curve_values(c, end)
		var pts := PackedVector2Array()
		var x := GUTTER
		while x <= minf(size.x, _x(end)):
			pts.append(Vector2(x, _curve_y(k, _value_at(values, _t(x)), vmax)))
			x += 3.0 * ui
		if pts.size() > 1:
			draw_polyline(pts, Color(0.5, 0.95, 0.6), 2.0 * ui, true)
		var ps_: PackedVector2Array = c.get("points")
		for n in ps_.size():
			var q := Vector2(_x(ps_[n].x), _curve_y(k, ps_[n].y, vmax))
			var on := k == curve_selected and n == point_selected
			draw_circle(q, (6.0 if on else 4.5) * ui, Color(1, 0.9, 0.4) if on else Color(0.85, 1.0, 0.9))
			# 選んでいる点・マウスが近い点・動かしている点は、時刻と数を出す
			if on or (k == _hover_curve and n == _hover_point):
				var text := "%s　%s体" % [clock(ps_[n].x), _num(ps_[n].y)]
				var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13)).x
				var tp := q + Vector2(8 * ui, -8 * ui)
				if tp.x + tw > size.x:
					tp.x = q.x - tw - 8 * ui
				tp.y = clampf(tp.y, top + 14 * ui, top + CURVE_ROW - 4 * ui)
				draw_rect(Rect2(tp + Vector2(-3 * ui, -13 * ui), Vector2(tw + 6 * ui, 17 * ui)), Color(0, 0, 0, 0.75))
				draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), Color(1, 0.95, 0.6))
		draw_string(font, Vector2(8 * ui, top + 20 * ui), timeline.enemy_name(c.get("type")), HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 12 * ui, _fs(15),
			Color(1, 1, 0.8) if k == curve_selected else Color(0.7, 1.0, 0.8))
		draw_string(font, Vector2(8 * ui, top + 40 * ui), "最大 %d 体" % int(vmax), HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 12 * ui, _fs(12), Color(1, 1, 1, 0.6))
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
		# 雑魚の補充の目標の数（曲線がなければ時間帯の値）
		if curves.is_empty():
			var y0 := off + RULER + PHASE_ROW + POP_ROW - 6.0 * ui
			var h := POP_ROW - 12.0 * ui
			draw_line(Vector2(_x(s), y0 - h * float(p.get("pop_from")) / max_pop), Vector2(_x(e), y0 - h * float(p.get("pop_to")) / max_pop), Color(0.5, 0.9, 0.6), 2.0 * ui)
	if not curves.is_empty():
		# 曲線の合計
		var sums := []
		var xs := []
		var x := GUTTER
		max_pop = 1.0
		var all_values := []
		for c in curves:
			all_values.append(_curve_values(c, end))
		while x <= minf(size.x, _x(end)):
			var total := 0.0
			for values: PackedFloat32Array in all_values:
				total += _value_at(values, _t(x))
			sums.append(total)
			xs.append(x)
			max_pop = maxf(max_pop, total)
			x += 4.0 * ui
		var y0 := off + RULER + PHASE_ROW + POP_ROW - 6.0 * ui
		var h := POP_ROW - 12.0 * ui
		var line := PackedVector2Array()
		for n in xs.size():
			line.append(Vector2(xs[n], y0 - h * float(sums[n]) / max_pop))
		if line.size() > 1:
			draw_polyline(line, Color(0.5, 0.9, 0.6), 2.0 * ui, true)
	draw_rect(Rect2(0, off, GUTTER, _tracks_top()), Color(0.1, 0.11, 0.14))
	draw_rect(Rect2(0, off, GUTTER, RULER), Color(0.16, 0.17, 0.21))
	draw_string(font, Vector2(8 * ui, off + RULER + PHASE_ROW * 0.6), "時間帯", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15))
	draw_string(font, Vector2(8 * ui, off + RULER + PHASE_ROW + POP_ROW * 0.6), ("雑魚の合計（最大 %d）" if not curves.is_empty() else "雑魚の数（最大 %d）") % int(max_pop), HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 12 * ui, _fs(14))
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
	if p.y < _clips_top():
		var ck := int(floor((p.y - _curves_top()) / CURVE_ROW))
		var curves: Array = timeline.curves()
		if ck < 0 or ck >= curves.size():
			return {}
		if p.x < GUTTER:
			return {"kind": "curve_label", "curve": ck}
		var c: Resource = curves[ck]
		var vmax := _curve_max(c)
		var pts: PackedVector2Array = c.get("points")
		for n in pts.size():
			if Vector2(_x(pts[n].x), _curve_y(ck, pts[n].y, vmax)).distance_to(p) <= 9.0 * ui:
				return {"kind": "point", "curve": ck, "point": n}
		return {"kind": "curve_body", "curve": ck}
	var row := int(floor((p.y - _clips_top()) / TRACK))
	if row < 0 or row >= track_count():
		return {}
	if p.x < GUTTER:
		return {"kind": "track_label", "row": row} if row < track_count() - 1 else {}
	var cs: Array = timeline.clips()
	# 選んでいるクリップを先に調べる（重なっていても選んだものをつかめるように）
	var order := range(cs.size())
	if selected >= 0 and selected < cs.size():
		order.erase(selected)
		order.push_front(selected)
	for k in order:
		if clip_track(k) != row:
			continue
		var c: Resource = cs[k]
		if absf(p.x - _x(_clip_end(c))) <= HANDLE:
			return {"kind": "length", "index": k}
		if p.x >= _x(float(c.get("time"))) - HANDLE and p.x <= _x(_clip_end(c)):
			return {"kind": "time", "index": k}
	return {"kind": "track", "row": row}
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
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var h := _hit(mb.position)
			if h.get("kind", "") in ["time", "length"]:
				selected = h.index
				queue_redraw()
			_clip_menu(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = {"kind": "pan", "x": mb.position.x, "start": view_start} if mb.pressed else {}
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			grab_focus()
			var h := _hit(mb.position)
			if h.is_empty():
				return
			if h.kind == "time" and mb.double_click:
				selected = h.index
				_start_rename(h.index)
				return
			if h.kind == "track":
				selected = -1
				queue_redraw()
				return
			if h.kind == "track_label":
				if mb.double_click:
					_start_track_rename(h.row)
				return
			if h.kind == "phase_body":
				if mb.double_click:
					_start_phase_rename(h.index)
				return
			if h.kind in ["curve_label", "curve_body", "point"]:
				curve_selected = h.curve
				point_selected = h.get("point", -1)
				if h.kind == "curve_body" and mb.double_click:
					_add_point(h.curve, mb.position)
				elif h.kind == "point" and mb.double_click:
					_start_point_edit(h.curve, h.point)
				elif h.kind == "point":
					_begin_point_drag(h.curve, h.point)
				queue_redraw()
				return
			if h.has("index") and h.kind != "phase":
				selected = h.index
				EditorInterface.inspect_object(timeline.clips()[selected], "", true)
			_begin_drag(h, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not _drag.is_empty():
			_end_drag()
	elif event is InputEventMouseMotion and not _drag.is_empty():
		_move_drag((event as InputEventMouseMotion).position, (event as InputEventMouseMotion).shift_pressed)
	elif event is InputEventMouseMotion:
		var h := _hit((event as InputEventMouseMotion).position)
		var hc: int = h.get("curve", -1) if h.get("kind", "") == "point" else -1
		var hp: int = h.get("point", -1) if h.get("kind", "") == "point" else -1
		if hc != _hover_curve or hp != _hover_point:
			_hover_curve = hc
			_hover_point = hp
			queue_redraw()
	elif event is InputEventKey and event.pressed and point_selected >= 0 and (event as InputEventKey).keycode in [KEY_UP, KEY_DOWN]:
		# 選んでいる点の数を、上下の矢印キーで 1 ずつ（Shift で 10 ずつ）変える
		var ke := event as InputEventKey
		_nudge_point((1.0 if ke.keycode == KEY_UP else -1.0) * (10.0 if ke.shift_pressed else 1.0))
		accept_event()
	elif event is InputEventKey and event.pressed and ((event as InputEventKey).ctrl_pressed or (event as InputEventKey).meta_pressed) \
			and (event as InputEventKey).keycode in [KEY_C, KEY_V, KEY_D]:
		match (event as InputEventKey).keycode:
			KEY_C:
				copy_clip()
			KEY_V:
				paste_clip()
			KEY_D:
				duplicate_clip()
		accept_event()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode in [KEY_DELETE, KEY_BACKSPACE]:
		if point_selected >= 0:
			_remove_point()
		else:
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
			_drag.props = ["time", "track"]
			_drag.row0 = clip_track(h.index)
		"length":
			_drag.target = timeline.clips()[h.index]
			_drag.props = ["length"]
	if _drag.has("target"):
		_drag.before = {}
		for prop in _drag.props:
			_drag.before[prop] = _drag.target.get(prop)

## 曲線 k の、位置 at に点を足す。
func _add_point(k: int, at: Vector2) -> void:
	var c: Resource = timeline.curves()[k]
	var before: PackedVector2Array = c.get("points")
	var after := before.duplicate()
	var pt := Vector2(maxf(0.0, snappedf(_t(at.x), 1.0)), snappedf(_curve_v(k, at.y, _curve_max(c)), 1.0))
	var n := 0
	while n < after.size() and after[n].x < pt.x:
		n += 1
	after.insert(n, pt)
	c.set("points", after)
	point_selected = n
	timeline.commit("雑魚の曲線に点を足す", [[c, "points", before, after]])

## 点の時刻と数を文字で入れる（「m:ss 体数」または「秒 体数」）。
func _start_point_edit(k: int, n: int) -> void:
	var c: Resource = timeline.curves()[k]
	var pts: PackedVector2Array = c.get("points")
	var vmax := _curve_max(c)
	var q := Vector2(_x(pts[n].x), _curve_y(k, pts[n].y, vmax))
	_open_editor("%s %s" % [clock(pts[n].x), _num(pts[n].y)], Rect2(q + Vector2(8 * ui, -14 * ui), Vector2(170 * ui, 30 * ui)),
		func(text: String) -> void:
			var parts := text.strip_edges().replace("　", " ").split(" ", false)
			if parts.size() < 2:
				return
			var tt := String(parts[0])
			var secs := float(tt.get_slice(":", 0)) * 60.0 + float(tt.get_slice(":", 1)) if tt.contains(":") else float(tt)
			var before: PackedVector2Array = c.get("points")
			var after := before.duplicate()
			var lo := after[n - 1].x + 0.1 if n > 0 else 0.0
			var hi := after[n + 1].x - 0.1 if n + 1 < after.size() else 1e9
			after[n] = Vector2(clampf(secs, lo, hi), maxf(0.0, float(parts[1])))
			if after != before:
				c.set("points", after)
				timeline.commit("雑魚の曲線の点を変える", [[c, "points", before, after]]))

## 選んでいる点の数を delta だけ変える（0 より下にはしない）。
func _nudge_point(delta: float) -> void:
	var curves: Array = timeline.curves()
	if curve_selected < 0 or curve_selected >= curves.size():
		return
	var c: Resource = curves[curve_selected]
	var before: PackedVector2Array = c.get("points")
	if point_selected < 0 or point_selected >= before.size():
		return
	var after := before.duplicate()
	after[point_selected].y = maxf(0.0, after[point_selected].y + delta)
	if after != before:
		c.set("points", after)
		timeline.commit("雑魚の曲線の点を変える", [[c, "points", before, after]])

func _remove_point() -> void:
	var curves: Array = timeline.curves()
	if curve_selected < 0 or curve_selected >= curves.size():
		return
	var c: Resource = curves[curve_selected]
	var before: PackedVector2Array = c.get("points")
	if point_selected < 0 or point_selected >= before.size():
		return
	var after := before.duplicate()
	after.remove_at(point_selected)
	c.set("points", after)
	point_selected = -1
	timeline.commit("雑魚の曲線の点を消す", [[c, "points", before, after]])

func _begin_point_drag(k: int, n: int) -> void:
	var c: Resource = timeline.curves()[k]
	_drag = {"kind": "point", "curve": c, "k": k, "n": n, "vmax": _curve_max(c), "target": c, "props": ["points"],
		"before": {"points": (c.get("points") as PackedVector2Array).duplicate()}}

func _move_drag(p: Vector2, fine: bool) -> void:
	var t := _t(p.x)
	var snap := 0.1 if fine else 1.0
	match _drag.kind:
		"point":
			var pts: PackedVector2Array = (_drag.curve.get("points") as PackedVector2Array).duplicate()
			var n: int = _drag.n
			var lo := pts[n - 1].x + 0.1 if n > 0 else 0.0
			var hi := pts[n + 1].x - 0.1 if n + 1 < pts.size() else 1e9
			pts[n] = Vector2(clampf(snappedf(t, snap), lo, hi), snappedf(_curve_v(_drag.k, p.y, _drag.vmax), 0.1 if fine else 1.0))
			_drag.curve.set("points", pts)
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
			var row := clampi(int(floor((p.y - _clips_top()) / TRACK)), 0, track_count() - 1)
			_drag.target.set("track", row)
		"length":
			_drag.target.set("length", maxf(1.0, snappedf(t - float(_drag.target.get("time")), snap)))
	timeline.refresh()

func _end_drag() -> void:
	# クリップを落とした先で、ほかのクリップと重なるなら元の位置に戻す
	if _drag.get("kind", "") in ["time", "length"]:
		var k: int = _drag.index
		var c: Resource = _drag.target
		if track_busy(clip_track(k), float(c.get("time")), _clip_end(c), k):
			for prop in _drag.props:
				c.set(prop, _drag.before[prop])
			if _drag.kind == "time" and int(_drag.before.get("track", -1)) < 0:
				c.set("track", -1)
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

## コピーしたクリップ（貼り付けるたびに複製する）
var _clipboard: Resource = null

func copy_clip() -> void:
	var cs: Array = timeline.clips()
	if selected >= 0 and selected < cs.size():
		_clipboard = cs[selected].duplicate(true)

## コピーしたクリップを、再生位置の時刻に置く（重なるなら空いているトラックへ）。
func paste_clip() -> void:
	if _clipboard == null:
		return
	var row := clip_track(selected) if selected >= 0 and selected < timeline.clips().size() else 0
	_insert_clip(_clipboard.duplicate(true), maxf(0.0, snappedf(playhead, 1.0)), row, "クリップを貼り付ける")

## 選んでいるクリップを、そのすぐ後ろに複製する（重なるなら空いているトラックへ）。
func duplicate_clip() -> void:
	var cs: Array = timeline.clips()
	if selected < 0 or selected >= cs.size():
		return
	_insert_clip(cs[selected].duplicate(true), _clip_end(cs[selected]), clip_track(selected), "クリップを複製する")

func _insert_clip(c: Resource, time: float, prefer_row: int, label: String) -> void:
	var stage: Resource = timeline.stage
	# 番号を持たないクリップは、今の行を番号にしてから足す（並びが変わっても行が動かないように）
	var cs: Array = timeline.clips()
	var fixes := []
	for k in cs.size():
		if int(cs[k].get("track")) < 0:
			fixes.append([cs[k], "track", -1, k])
	for f in fixes:
		f[0].set("track", f[3])
	c.set("time", time)
	c.set("track", free_track(prefer_row, time, time + float(c.get("length"))))
	var before: Array = cs
	var after: Array = before.duplicate()
	after.append(c)
	stage.set("clips", after)
	selected = after.size() - 1
	timeline.commit(label, fixes + [[stage, "clips", before, after]])

## 右クリックのメニュー：コピー・貼り付け・複製・消す。
func _clip_menu(at: Vector2) -> void:
	var menu := PopupMenu.new()
	var has: bool = selected >= 0 and selected < timeline.clips().size()
	menu.add_item("コピー（⌘C）", 0)
	menu.set_item_disabled(0, not has)
	menu.add_item("貼り付け（⌘V）", 1)
	menu.set_item_disabled(1, _clipboard == null)
	menu.add_item("複製（⌘D）", 2)
	menu.set_item_disabled(2, not has)
	menu.add_item("消す（Delete）", 3)
	menu.set_item_disabled(3, not has)
	menu.id_pressed.connect(func(id: int) -> void:
		match id:
			0: copy_clip()
			1: paste_clip()
			2: duplicate_clip()
			3: timeline._remove_clip()
		menu.queue_free())
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(Vector2i(get_screen_position() + at), Vector2i.ZERO))

func _start_rename(k: int) -> void:
	var c: Resource = timeline.clips()[k]
	var x0 := maxf(GUTTER, _x(float(c.get("time"))))
	_open_editor(str(c.get("label")), Rect2(x0, _clips_top() + clip_track(k) * TRACK, maxf(200.0 * ui, _x(_clip_end(c)) - x0), TRACK),
		func(text: String) -> void:
			var before := str(c.get("label"))
			if text != before:
				c.set("label", text)
				timeline.commit("クリップの名前を変える", [[c, "label", before, text]]))
