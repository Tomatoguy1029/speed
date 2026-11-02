## 性能の表示（仕様書 20）。開発版だけで、F3 を押すたびに 簡易 → 詳細 → 非表示 と切り替わる。
##
## 初期位置は画面の右上（ボスの HP バーの下）。つかんで動かせ、位置と表示の段階は同じ起動の間は次のランにも引き継ぐ。
## 文字は1秒に4回更新し、その間の平均と最大を出す。処理ごとの時間は詳細表示の間だけ、この表示用の記録に取る。
class_name PerfOverlay
extends PanelContainer


enum Mode { HIDDEN, COMPACT, DETAIL }

const REFRESH := 0.25
const GRAPH_FRAMES := 120
const GRAPH_SIZE := Vector2(260, 56)
## グラフの縦軸の上限（ms）
const GRAPH_MAX_MS := 50.0
const WARN := Color("#ff6b5a")
const OK := Color("#9fe8ff")
const HEAD := "[color=#9fe8ff]%s[/color]"

## 表示の段階と位置。同じ起動の間は次のランにも引き継ぐ（計測用ツールは段階を指定して起動できる）
static var saved_mode := Mode.HIDDEN
static var _saved_pos := Vector2(-1, -1)

## RunSession が木に入れる前に入れる
var bridge: RefCounted
var _cpp_previous := {}
var _cpp_window := {}
var view: RunPresentation
var mode := Mode.HIDDEN
var _label: RichTextLabel
## 詳細表示の右の列（表示側の時間）
var _view_label: RichTextLabel
var _graph: Control
## 直近のフレーム時間（ms）の輪。_frame_head が次に書く位置
var _frames := PackedFloat32Array()
var _frame_head := 0
var _last_us := 0
## このフレームに実行した物理更新の回数と、更新の間の最大
var _steps := 0
var _steps_max := 0
var _steps_sum := 0
var _acc := 0.0
var _frame_sum := 0.0
var _frame_max := 0.0
var _frame_n := 0
var _compiles_prev := -1
## 詳細表示の間だけ開く、この表示用の記録（ゲーム側・表示側・敵の描画の行の数）
var _sim_rec := {}
var _view_rec := {}
var _rows_rec := {}
var _dragging := false
var _drag_offset := Vector2.ZERO
var _placed := false

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.88)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	# 詳細表示は縦に収まるよう、表示側の時間を右の列に分ける
	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 16)
	add_child(columns)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(box)
	_label = _new_label()
	box.add_child(_label)
	_view_label = _new_label()
	columns.add_child(_view_label)
	_graph = Control.new()
	_graph.custom_minimum_size = GRAPH_SIZE
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	box.add_child(_graph)
	_frames.resize(GRAPH_FRAMES)
	get_tree().physics_frame.connect(func(): _steps += 1)
	_set_mode(saved_mode)

func _exit_tree() -> void:
	saved_mode = mode
	if _placed:
		_saved_pos = position

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_perf"):
		get_viewport().set_input_as_handled()
		_set_mode((mode + 1) % Mode.size() as Mode)

func _set_mode(m: Mode) -> void:
	mode = m
	visible = mode != Mode.HIDDEN
	_graph.visible = mode == Mode.DETAIL
	_view_label.visible = false
	_label.custom_minimum_size = Vector2(380.0 if mode == Mode.DETAIL else 0.0, 0.0)
	_cpp_previous = view.metrics_snapshot() if view!=null else bridge.read_metrics().value
	_reset_window()
	_acc = REFRESH
	reset_size()

# ── つかんで動かす ────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_offset = event.global_position - global_position
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		position = _clamped(event.global_position - _drag_offset)
		_saved_pos = position
		accept_event()

func _clamped(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return p.clamp(Vector2.ZERO, (vp - size).max(Vector2.ZERO))

# ── 計測と表示 ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_us) / 1000.0 if _last_us > 0 else delta * 1000.0
	_last_us = now
	var steps := _steps
	_steps = 0
	if mode == Mode.HIDDEN:
		return
	_frames[_frame_head] = frame_ms
	_frame_head = (_frame_head + 1) % GRAPH_FRAMES
	_frame_sum += frame_ms
	_frame_max = maxf(_frame_max, frame_ms)
	_frame_n += 1
	_steps_sum += steps
	_steps_max = maxi(_steps_max, steps)
	if not _placed and size.x > 0.0:
		# 初期位置：同じ起動で動かした位置があればそこ、なければ右上（ボスの HP バーの下）
		var vp := get_viewport_rect().size
		position = _saved_pos if _saved_pos.x >= 0.0 else Vector2(vp.x - size.x - 16.0, 80.0)
		_placed = true
	position = _clamped(position)
	if mode == Mode.DETAIL:
		_graph.queue_redraw()
	_acc += delta
	if _acc < REFRESH:
		return
	_acc = 0.0
	if bridge!=null:
		var current: Dictionary = view.metrics_snapshot() if view!=null else bridge.read_metrics().value
		_cpp_window = preload("res://scripts/runtime/run_metrics.gd").window(current,_cpp_previous,_frame_n,int(_frame_sum*1000.0))
		_cpp_previous = current
	_label.text = _text()
	_reset_window()

func _reset_window() -> void:
	_frame_sum = 0.0
	_frame_max = 0.0
	_frame_n = 0
	_steps_sum = 0
	_steps_max = 0

func _text() -> String:
	return _cpp_text()

func _new_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 13)
	return label

func _ms(v: float, warn: float) -> String:
	if v >= warn:
		return "[color=#%s]%.1fms[/color]" % [WARN.to_html(false), v]
	return "%.1fms" % v

func _mb(bytes: float) -> String:
	return "%.1fMB" % (bytes / 1048576.0)

func _draw_graph() -> void:
	var s := _graph.size
	_graph.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.35))
	for ref in [16.7, 33.3]:
		var y: float = s.y - ref / GRAPH_MAX_MS * s.y
		_graph.draw_line(Vector2(0, y), Vector2(s.x, y), Color(1, 1, 1, 0.25), 1.0)
	# 線1本で描き、25ms を超えたフレームだけ赤い棒を重ねる
	var w := s.x / (GRAPH_FRAMES - 1)
	var pts := PackedVector2Array()
	pts.resize(GRAPH_FRAMES)
	for k in GRAPH_FRAMES:
		var v := _frames[(_frame_head + k) % GRAPH_FRAMES]
		var y := s.y - minf(v / GRAPH_MAX_MS, 1.0) * s.y
		pts[k] = Vector2(k * w, y)
		if v > 25.0:
			_graph.draw_line(Vector2(k * w, s.y), Vector2(k * w, y), WARN, 2.0)
	_graph.draw_polyline(pts, OK, 1.0)

func _cpp_text() -> String:
	var lines: Array[String] = []
	var avg := _frame_sum/maxi(1,_frame_n)
	lines.append("FPS [b]%.0f[/b]   フレーム %.1fms（最大 %s）" % [1000.0/maxf(avg,0.001),avg,_ms(_frame_max,25.0)])
	var result: Dictionary = bridge.read_metrics()
	if not result.ok: return "C++の性能を取得できません"
	var current: Dictionary = result.value
	var pools: Dictionary = current.attack_pools
	lines.append("敵 %d  敵弾 %d  味方弾 %d  範囲 %d" % [current.enemies,pools.get("1",0),pools.get("0",0),pools.get("2",0)])
	if mode==Mode.DETAIL:
		lines.append(HEAD % "処理時間（ms/フレーム）")
		var names := {"sim":"ゲーム更新","output_build":"C++の出力構築","bridge_copy":"窓口の受け渡し","view_update":"表示の更新","view_draw":"描画命令の構築","resource_wait":"資源待ち","engine_gpu_wait":"描画エンジン・GPU・待ち（未分離）"}
		for key in names:
			var sample: Variant = _cpp_window.get("timings",{}).get(key)
			lines.append("%s：%s" % [names[key],"未取得" if sample==null else "%.3f" % sample.ms_per_frame])
		lines.append("Packed配列の論理量：%.0f bytes/frame" % _cpp_window.get("packed_bytes_per_frame",0.0))
		lines.append("GPU単独時間：未取得")
		lines.append("固定更新 累計%d回  通知 累計%d件" % [current.fixed_steps,current.events_emitted])
	return "\n".join(lines)
