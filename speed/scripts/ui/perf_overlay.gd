## 性能の表示（仕様書 20）。開発版だけで、F3 を押すたびに 簡易 → 詳細 → 非表示 と切り替わる。
##
## 初期位置は画面の右上（ボスの HP バーの下）。つかんで動かせ、位置と表示の段階は同じ起動の間は次のランにも引き継ぐ。
## 文字は1秒に4回更新し、その間の平均と最大を出す。Manager ごとの時間は詳細表示の間だけ計測する。
class_name PerfOverlay
extends PanelContainer

@export var run_path: NodePath

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

var run: RunManager
var mode := Mode.HIDDEN
var _label: RichTextLabel
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
## RunManager の計測をこの表示が有効にしたか
var _owns_profiling := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _placed := false

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	run = get_node(run_path) as RunManager
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.88)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", 13)
	box.add_child(_label)
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
	if _owns_profiling and run != null:
		run.profiling = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_perf"):
		get_viewport().set_input_as_handled()
		_set_mode((mode + 1) % Mode.size() as Mode)

func _set_mode(m: Mode) -> void:
	mode = m
	visible = mode != Mode.HIDDEN
	_graph.visible = mode == Mode.DETAIL
	_label.custom_minimum_size = Vector2(380.0 if mode == Mode.DETAIL else 0.0, 0.0)
	if mode == Mode.DETAIL and not run.profiling:
		run.profiling = true
		run.profile.clear()
		_owns_profiling = true
	elif mode != Mode.DETAIL and _owns_profiling:
		run.profiling = false
		_owns_profiling = false
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
	_label.text = _text()
	_reset_window()

func _reset_window() -> void:
	_frame_sum = 0.0
	_frame_max = 0.0
	_frame_n = 0
	_steps_sum = 0
	_steps_max = 0

func _text() -> String:
	var lines: Array[String] = []
	var avg := _frame_sum / maxi(1, _frame_n)
	var fps := 1000.0 / maxf(avg, 0.001)
	lines.append("FPS [b]%.0f[/b]   フレーム %.1fms（最大 %s）" % [fps, avg, _ms(_frame_max, 25.0)])
	var steps_avg := float(_steps_sum) / maxi(1, _frame_n)
	var steps_text := "%d" % _steps_max
	if _steps_max > 2:
		steps_text = "[color=#%s]%d[/color]" % [WARN.to_html(false), _steps_max]
	lines.append("物理更新 %.1f回/フレーム（最大 %s）" % [steps_avg, steps_text])
	var en := run.enemies
	var pr := run.projectiles
	var pk := run.pickups
	lines.append("敵 %d  敵弾 %d  味方弾 %d" % [en.count(), pr.hostile_count(), pr.friend_count()])
	lines.append("結晶 %d  部品 %d" % [pk.gem_slots.live, pk.coin_slots.live])
	if mode == Mode.DETAIL:
		lines.append(HEAD % "処理時間")
		# 描画時間の計測（viewport_set_measure_render_time）は描画の完了を待ってフレームを引き延ばすので使わない。
		# ゲーム処理の時間をフレーム時間から引いた残りを、描画と待ちの目安にする。
		var total: Array = run.profile.get(&"play_total", [0, 0, 0])
		var game_ms: float = total[0] / 1000.0 / maxi(1, _frame_n)
		lines.append("ゲーム処理 %.2fms/フレーム  それ以外（描画・待ち）%.2fms" % [game_ms, maxf(0.0, avg - game_ms)])
		lines.append("ゲーム更新 1回 平均 %.2fms 最大 %.2fms" % [total[0] / 1000.0 / maxi(1, total[1]), total[2] / 1000.0])
		lines.append_array(_manager_lines())
		lines.append(HEAD % "描画")
		lines.append("描画命令 %d  オブジェクト %d  頂点・図形 %d" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		var compiles := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
		var added := compiles - _compiles_prev if _compiles_prev >= 0 else 0
		_compiles_prev = compiles
		var added_text := "[color=#%s]+%d[/color]" % [WARN.to_html(false), added] if added > 0 else "+0"
		lines.append("シェーダーのコンパイル 累計 %d（直近 %s）" % [compiles, added_text])
		lines.append(HEAD % "メモリ")
		lines.append("RAM %s  VRAM %s" % [_mb(Performance.get_monitor(Performance.MEMORY_STATIC)),
			_mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))])
		lines.append("オブジェクト %d  ノード %d  つながっていないノード %d" % [
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
		lines.append(HEAD % "表の行（使用中 / 空きを含む行数）")
		lines.append("敵 %d/%d  敵弾 %d/%d  味方弾 %d/%d" % [en.count(), en.slots.capacity(),
			pr.hostile_count(), pr.hostile_slots.capacity(), pr.friend_count(), pr.friend_slots.capacity()])
		lines.append("結晶 %d/%d  部品 %d/%d" % [pk.gem_slots.live, pk.gem_slots.capacity(),
			pk.coin_slots.live, pk.coin_slots.capacity()])
		lines.append(HEAD % ("フレーム時間（直近 %d フレーム、線は 16.7ms と 33.3ms）" % GRAPH_FRAMES))
	return "\n".join(lines)

## 世界側の各処理の、1回あたりの平均と最大（多い順に8件）。読んだら次の区間のために空にする。
func _manager_lines() -> Array[String]:
	var out: Array[String] = []
	if not run.profiling:
		return out
	var rows: Array = []
	for key in run.profile:
		var rec: Array = run.profile[key]
		if key != &"play_total" and rec[1] > 0:
			rows.append([String(key), rec[0] / 1000.0 / rec[1], rec[2] / 1000.0])
	run.profile.clear()
	rows.sort_custom(func(a, b): return a[1] > b[1])
	out.append("処理ごと（世界側の更新1回あたり 平均 / 最大）")
	for r in rows.slice(0, 8):
		out.append("  %-12s %.3f / %.3fms" % [r[0], r[1], r[2]])
	return out

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
