## 計測用の試作（tasks/todo.md 0-1・0-2）。製品には含めない。
##
## 敵 1300 体を配列で持ち、demo の追跡（18 秒周期の接近と広域移動）、格子での近傍探索、
## 自機との接触、なぞりの線分の掃引判定を固定更新で回し、1 回の更新にかかる時間を測る。
## 描画は MultiMeshInstance2D でまとめて行う。
##
## 実行時の引数（`--` の後ろ）:
##   --count=1300     敵の数
##   --ticks=120      1 秒あたりの固定更新の回数
##   --seconds=10     計測する秒数（最初の 1 秒は捨てる）
##   --layers         層ごとの SubViewport と HDR の光のにじみを加える（0-2）
##   --shot=<path>    終了直前に画面を PNG で保存する
extends Node2D

const CELL := 128.0
const VIEW := Vector2(1600.0, 900.0)

var count := 1300
var ticks := 120
var seconds := 10.0
var use_layers := false
var shot_path := ""

# 敵の配列（種類ごとの配列を想定した構造の代表として 1 種類で測る）
var px := PackedFloat32Array()
var py := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var radius := PackedFloat32Array()
var age := PackedFloat32Array()
var hp := PackedFloat32Array()

# 格子（セルごとの先頭と、敵ごとの次の要素）
var grid_cols := 0
var grid_rows := 0
var grid_origin := Vector2.ZERO
var cell_head := PackedInt32Array()
var next_in_cell := PackedInt32Array()

var ship := Vector2.ZERO
var aim := Vector2.ZERO
var t := 0.0
var path_from := Vector2.ZERO
var path_to := Vector2.ZERO
var path_hits := 0
var contact_hits := 0

var tick_times: Array[int] = []
var frame_times: Array[float] = []
var gpu_times: Array[float] = []
var elapsed := 0.0

var mm_instance: MultiMeshInstance2D
var mm: MultiMesh

func _ready() -> void:
	_parse_args()
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = 16
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(12345)
	_spawn()
	_build_view()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("[perf] count=%d ticks=%d layers=%s renderer=%s" % [count, ticks, use_layers, RenderingServer.get_current_rendering_method()])

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--count="):
			count = a.get_slice("=", 1).to_int()
		elif a.begins_with("--ticks="):
			ticks = a.get_slice("=", 1).to_int()
		elif a.begins_with("--seconds="):
			seconds = a.get_slice("=", 1).to_float()
		elif a == "--layers":
			use_layers = true
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)

func _spawn() -> void:
	px.resize(count); py.resize(count); vx.resize(count); vy.resize(count)
	radius.resize(count); age.resize(count); hp.resize(count)
	next_in_cell.resize(count)
	for i in count:
		var a := randf() * TAU
		var d := randf_range(200.0, 900.0)
		px[i] = cos(a) * d
		py[i] = sin(a) * d
		vx[i] = 0.0
		vy[i] = 0.0
		radius[i] = 11.0 if i % 3 == 0 else 14.0
		age[i] = randf() * 18.0
		hp[i] = 6.0

func _build_view() -> void:
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(28, 28)
	mm.mesh = quad
	mm.instance_count = count
	mm_instance = MultiMeshInstance2D.new()
	mm_instance.multimesh = mm
	var cam := Camera2D.new()
	cam.zoom = Vector2(0.6, 0.6)
	if use_layers:
		_build_layers(cam)
	else:
		add_child(mm_instance)
		add_child(cam)
		cam.make_current()

## 0-2：敵を層の SubViewport に描き、HDR で光のにじみをかけて合成する。
func _build_layers(cam: Camera2D) -> void:
	var root_vp := get_viewport()
	root_vp.use_hdr_2d = true
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.size = get_viewport_rect().size
	var sub := SubViewport.new()
	sub.use_hdr_2d = true
	sub.transparent_bg = true
	sub.size = Vector2i(get_viewport_rect().size)
	holder.add_child(sub)
	sub.add_child(mm_instance)
	sub.add_child(cam)
	var layer := CanvasLayer.new()
	layer.add_child(holder)
	add_child(layer)
	cam.make_current()
	mm_instance.modulate = Color(2.5, 2.5, 3.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _physics_process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	_tick(delta)
	var used := Time.get_ticks_usec() - start
	if elapsed > 1.0:
		tick_times.append(used)

func _process(delta: float) -> void:
	elapsed += delta
	_write_view()
	if elapsed > 1.0:
		frame_times.append(delta * 1000.0)
		gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	if elapsed >= seconds + 1.0:
		_report()
		set_process(false)
		set_physics_process(false)
		if shot_path != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()

func _tick(dt: float) -> void:
	t += dt
	# 自機：円を描いて動き、2 秒ごとに長さ 1000 の線をなぞる
	ship = Vector2(cos(t * 0.5), sin(t * 0.5)) * 400.0
	_update_aim(dt)
	_update_enemies(dt)
	_build_grid()
	_contact_ship()
	if fmod(t, 2.0) < dt:
		path_from = ship
		path_to = ship + Vector2(cos(t), sin(t)) * 1000.0
		path_hits += _sweep(path_from, path_to, 16.0 + 45.0)

func _update_aim(dt: float) -> void:
	var d := ship - aim
	var dist := d.length()
	if dist > 300.0:
		aim = ship - d / dist * 300.0
		d = ship - aim
		dist = 300.0
	if dist < 0.000001:
		return
	var step := minf(dist * (1.0 - exp(-dt / 0.5)), 450.0 * dt)
	aim += d / dist * step

func _update_enemies(dt: float) -> void:
	var half := VIEW * 0.5
	var k := minf(1.0, 2.5 * dt)
	for i in count:
		var a := age[i] + dt
		age[i] = a
		var cycle := fmod(a + i * 1.61803398875, 18.0)
		var roam := clampf(minf((cycle - 4.5) / 2.0, (18.0 - cycle) / 2.0), 0.0, 1.0)
		var ang := i * 2.39996322973 + a * 0.12
		var ux := cos(ang)
		var uy := sin(ang)
		var rad := 0.45 + 0.5 * sqrt(fmod(i * 0.61803398875, 1.0))
		var edge := rad / maxf(absf(ux), absf(uy))
		var tx := aim.x + (ship.x + ux * edge * half.x - aim.x) * roam
		var ty := aim.y + (ship.y + uy * edge * half.y - aim.y) * roam
		var dx := tx - px[i]
		var dy := ty - py[i]
		var dd := sqrt(dx * dx + dy * dy)
		if dd < 0.001:
			dd = 1.0
		vx[i] += (dx / dd * 130.0 - vx[i]) * k
		vy[i] += (dy / dd * 130.0 - vy[i]) * k
		px[i] += vx[i] * dt
		py[i] += vy[i] * dt

func _build_grid() -> void:
	var span := Vector2(4000.0, 4000.0)
	grid_origin = ship - span * 0.5
	grid_cols = int(span.x / CELL)
	grid_rows = int(span.y / CELL)
	var n := grid_cols * grid_rows
	if cell_head.size() != n:
		cell_head.resize(n)
	cell_head.fill(-1)
	for i in count:
		var cx := int((px[i] - grid_origin.x) / CELL)
		var cy := int((py[i] - grid_origin.y) / CELL)
		if cx < 0 or cy < 0 or cx >= grid_cols or cy >= grid_rows:
			next_in_cell[i] = -1
			continue
		var c := cy * grid_cols + cx
		next_in_cell[i] = cell_head[c]
		cell_head[c] = i

func _contact_ship() -> void:
	var cx := int((ship.x - grid_origin.x) / CELL)
	var cy := int((ship.y - grid_origin.y) / CELL)
	for gy in range(cy - 1, cy + 2):
		for gx in range(cx - 1, cx + 2):
			if gx < 0 or gy < 0 or gx >= grid_cols or gy >= grid_rows:
				continue
			var i := cell_head[gy * grid_cols + gx]
			while i != -1:
				var dx := px[i] - ship.x
				var dy := py[i] - ship.y
				var rr := radius[i] + 16.0
				if dx * dx + dy * dy < rr * rr:
					contact_hits += 1
				i = next_in_cell[i]

## 線分 a→b から width 以内の敵を数える（なぞりの帯の判定）。
func _sweep(a: Vector2, b: Vector2, width: float) -> int:
	var hits := 0
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(width + 30.0, width + 30.0)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(width + 30.0, width + 30.0)
	var x0 := clampi(int((lo.x - grid_origin.x) / CELL), 0, grid_cols - 1)
	var x1 := clampi(int((hi.x - grid_origin.x) / CELL), 0, grid_cols - 1)
	var y0 := clampi(int((lo.y - grid_origin.y) / CELL), 0, grid_rows - 1)
	var y1 := clampi(int((hi.y - grid_origin.y) / CELL), 0, grid_rows - 1)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var i := cell_head[gy * grid_cols + gx]
			while i != -1:
				var p := Vector2(px[i], py[i])
				var s := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
				var q := a + ab * s
				var rr := width + radius[i]
				if p.distance_squared_to(q) < rr * rr:
					hits += 1
				i = next_in_cell[i]
	return hits

func _write_view() -> void:
	var col := Color(0.5, 0.82, 1.0)
	for i in count:
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(px[i], py[i])))
		mm.set_instance_color(i, col)

func _report() -> void:
	tick_times.sort()
	var n := tick_times.size()
	var sum := 0
	for v in tick_times:
		sum += v
	var avg_ms := float(sum) / maxf(n, 1) / 1000.0
	var p95_ms := float(tick_times[int(n * 0.95)]) / 1000.0 if n > 0 else 0.0
	var ft := 0.0
	for v in frame_times:
		ft += v
	var gt := 0.0
	for v in gpu_times:
		gt += v
	var frames := maxf(frame_times.size(), 1)
	print("[perf] ticks_measured=%d tick_avg_ms=%.3f tick_p95_ms=%.3f per_second_ms=%.1f" % [n, avg_ms, p95_ms, avg_ms * ticks])
	print("[perf] frame_avg_ms=%.2f fps=%.1f gpu_avg_ms=%.3f path_hits=%d contact_hits=%d" % [ft / frames, 1000.0 / (ft / frames), gt / frames, path_hits, contact_hits])
