extends Node
# 検証用：本物のゲーム（タイトル→ステージ、HUD 込み）でしし座を救出して発動し、機体をゆるやかな S 字に走らせて
# 画面全体を 30fps の生の RGB で書き出す。一時作業場所の project.godot に autoload として足して使う（本体には入れない）。
# 使い方：Godot --path <一時作業場所/speed> --resolution 1280x720 -- --lion-capture <出力フォルダ> [ステージ] [秒]
# 画面は HDR（リニア）なので、HDR を使わない画面へ sRGB に直して写してから撮る。
const SPEED := 600.0
const WEAVE := 0.45
const WEAVE_RATE := 1.1

var out_dir := ""
var stage := 2
var seconds := 6.0
var session: Node
var shown: SubViewport
var phase := 0
var wait := 0.0
var frame_index := 0
var frames := 0
var t := 0.0
var pos := Vector2.ZERO

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--lion-capture")
	if at < 0 or at + 1 >= args.size():
		set_process(false)
		set_physics_process(false)
		return
	out_dir = args[at + 1]
	if at + 2 < args.size(): stage = int(args[at + 2])
	if at + 3 < args.size(): seconds = float(args[at + 3])
	frames = int(seconds * 30.0)
	DirAccess.make_dir_recursive_absolute(out_dir)
	RunManager.session_created.connect(func(s): session = s)
	wait = 2.0

func _ensure_capture() -> void:
	if shown != null: return
	var size := get_viewport().get_visible_rect().size
	shown = SubViewport.new()
	shown.size = Vector2i(size)
	shown.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(shown)
	var rect := TextureRect.new()
	rect.texture = get_viewport().get_texture()
	# 画面の実際の画素数は論理の大きさと違うことがあるので、枠いっぱいに縮めて写す
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = size
	var conv := ShaderMaterial.new()
	conv.shader = load("res://capture_srgb.gdshader")
	rect.material = conv
	shown.add_child(rect)

func _ui() -> Dictionary:
	if session == null or session.bridge == null: return {}
	var snapshot: Dictionary = session.bridge.latest_frame()
	return snapshot.value.get("ui", {}) if snapshot.ok and snapshot.value is Dictionary else {}

func _physics_process(delta: float) -> void:
	if phase != 3 or session == null or session.bridge == null: return
	# 機体をゆるやかな S 字に走らせる
	t += delta
	var vel := Vector2.from_angle(WEAVE * sin(t * WEAVE_RATE)) * SPEED
	pos += vel * delta
	session.bridge.command("dev_ship_motion", {"position": pos, "velocity": vel})

func _process(delta: float) -> void:
	if wait > 0.0:
		wait -= delta
		return
	match phase:
		0:
			GameManager.start_run(stage)
			phase = 1
		1:
			var ui := _ui()
			if ui.is_empty() or not ui.get("input_enabled", false): return
			var placed: Dictionary = session.bridge.command("dev_hero_place", {"id": "leo"})
			print("[lion] place ", placed.ok)
			phase = 2
			wait = 0.3
		2:
			var hero: Dictionary = _ui().get("hero", {})
			if hero.is_empty(): return
			var links: PackedInt32Array = hero.links
			for i in range(0, links.size(), 2):
				session.bridge.command("dev_hero_pass", {"from": hero.stars[links[i]], "to": hero.stars[links[i + 1]], "dash": i})
			phase = 5
			wait = 1.0
		5:
			# 救出の表示が閉じて操作できるようになってから発動する
			if not _ui().get("input_enabled", false): return
			var activated: Dictionary = session.bridge.command("dev_hero_activate", {})
			print("[lion] activate ", activated.ok, " power ", _ui().get("hero", {}).get("power", ""))
			pos = _ui().ship.ship_pos
			_ensure_capture()
			phase = 3
		3:
			_save.call_deferred()
			if frame_index >= frames:
				print("[lion] frames ", frame_index)
				get_tree().quit()
				phase = 4

func _save() -> void:
	await RenderingServer.frame_post_draw
	if phase != 3 and phase != 4: return
	var img := shown.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var f := FileAccess.open(out_dir.path_join("%04d.raw" % frame_index), FileAccess.WRITE)
	f.store_buffer(img.get_data())
	if frame_index % 30 == 0: img.save_png(out_dir.path_join("f%03d.png" % frame_index))
	frame_index += 1
