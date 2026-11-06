extends Node
# 検証用：本物のゲーム（HUD 込み）で英雄を救出して発動し、決まった操作を流して画面を 30fps の生の RGB で書き出す。
# 一時作業場所の project.godot に autoload として足して使う（本体には入れない）。
# 使い方：Godot --path <一時作業場所/speed> --resolution 1280x720 -- --hero-capture <出力フォルダ> <gemini|hercules> [ステージ] [秒]
# 出力フォルダに - を渡すと画面を保存せず、0.5秒ごとに fps・処理時間・描画命令数を表示する（重さの計測用）。
# ふたご座：並走のあと、斜めに曲がる線を2回描いて突進する（影は反転した経路を走る）。ヘルクレス座：まわりに敵を置いてゆっくり進む。
const CRUISE := 240.0

var out_dir := ""
var hero_id := "gemini"
var stage := 3
var seconds := 7.0
var session: Node
var shown: SubViewport
var phase := 0
var wait := 0.0
var frame_index := 0
var frames := 0
var t := 0.0
var pos := Vector2.ZERO
var heading := Vector2.RIGHT
var draws := [1.7, 4.2]
var drawn := 0
var weapons: Array = ["W01", "W04", "W29"]
## 武器選択や獲得演出で操作できない間の秒と、次に押すまでの秒
var blocked := 0.0
var poke := 0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--hero-capture")
	if at < 0 or at + 2 >= args.size():
		set_process(false)
		set_physics_process(false)
		return
	out_dir = args[at + 1]
	hero_id = args[at + 2]
	if at + 3 < args.size(): stage = int(args[at + 3])
	if at + 4 < args.size(): seconds = float(args[at + 4])
	# ふたご座で持たせる武器（コンマ区切り）
	if at + 5 < args.size(): weapons = Array(args[at + 5].split(","))
	frames = int(seconds * 30.0)
	if out_dir != "-": DirAccess.make_dir_recursive_absolute(out_dir)
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
	var ui := _ui()
	if ui.is_empty() or not ui.get("input_enabled", false) or int(ui.get("phase", 0)) != 0: return
	t += delta
	if ui.draw.tracing or ui.draw.drawing or ui.ship.get("ship_glide", false):
		pos = ui.ship.ship_pos
		heading = Vector2(ui.ship.ship_heading)
		return
	# ゆるやかに曲がりながら巡航する
	heading = heading.rotated(0.35 * sin(t * 1.3) * delta)
	pos += heading * CRUISE * delta
	session.bridge.command("dev_ship_motion", {"position": pos, "velocity": heading * CRUISE})

func _spawn_around(center: Vector2, forward: Vector2) -> void:
	var side := forward.orthogonal()
	for i in 10:
		var at := center + forward * randf_range(200.0, 650.0) + side * randf_range(-320.0, 320.0)
		session.bridge.command("dev_spawn", {"definition_id": "drifter", "position": at})

## 一本の線を、押す・伸ばす・離すまで同じコマの中で描く（ゲームの入力が途中で混ざらないように）
func _draw_line(bend: float) -> void:
	var ui := _ui()
	var start: Vector2 = ui.ship.ship_pos
	var forward := Vector2(ui.ship.ship_heading).normalized()
	var side := forward.orthogonal()
	var core = session.bridge._core
	var clock := Time.get_ticks_msec()
	core.handle_draw({"press": true, "pen": start}, clock, 1.0)
	for i in range(1, 13):
		var k := i / 12.0
		var p := start + forward * 520.0 * k + side * bend * 260.0 * k * k
		core.handle_draw({"has_cursor": true, "pen": p}, clock + i, 1.0)
	core.handle_draw({"has_cursor": true, "touch": true, "pen_release": true, "pen": start + forward * 520.0 + side * bend * 260.0}, clock + 20, 1.0)
	var after: Dictionary = core.draw_snapshot()
	print("[hero] draw frame=", frame_index, " tracing=", after.get("tracing"), " drawing=", after.get("drawing"), " gauge=", after.get("gauge"))

## 武器選択の画面なら 1 を押す。獲得演出などで操作できないときは、3秒待ってから1秒おきに画面をクリックする。
## 操作できない間は true を返す（そのあいだは撮らず、操作も流さない）
func _clear_screens(delta: float) -> bool:
	var ui := _ui()
	if ui.is_empty(): return false
	poke -= delta
	if int(ui.get("phase", 0)) == 1:
		if poke <= 0.0:
			poke = 0.5
			for pressed in [true, false]:
				var key := InputEventKey.new()
				key.keycode = KEY_1
				key.physical_keycode = KEY_1
				key.pressed = pressed
				Input.parse_input_event(key)
		return true
	if ui.get("input_enabled", false):
		blocked = 0.0
		return false
	blocked += delta
	if blocked > 3.0 and poke <= 0.0:
		poke = 1.0
		var center := get_viewport().get_visible_rect().size * 0.5
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = center
			click.global_position = center
			click.pressed = pressed
			Input.parse_input_event(click)
	return true

func _process(delta: float) -> void:
	if phase >= 1 and phase != 4 and _clear_screens(delta): return
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
			session.bridge.command("dev_hero_place", {"id": hero_id})
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
			if not _ui().get("input_enabled", false): return
			var ui := _ui()
			pos = ui.ship.ship_pos
			heading = Vector2(ui.ship.ship_heading).normalized() if Vector2(ui.ship.ship_heading).length_squared() > 0.0 else Vector2.RIGHT
			_spawn_around(pos, heading)
			# 武器の複製を見られるように、弾を撃つ武器を持たせる
			if hero_id == "gemini":
				for id in weapons: session.bridge.command("dev_grant_equipment", {"id": id, "kind": "trait" if String(id).begins_with("T") else "weapon", "levels": 3})
			var activated: Dictionary = session.bridge.command("dev_hero_activate", {})
			print("[hero] activate ", activated.ok, " power ", _ui().get("hero", {}).get("power", ""))
			if out_dir != "-": _ensure_capture()
			t = 0.0
			phase = 3
		3:
			if hero_id == "gemini" and drawn < draws.size() and t >= draws[drawn]:
				var ui := _ui()
				if not ui.draw.tracing and not ui.draw.drawing:
					_spawn_around(ui.ship.ship_pos, Vector2(ui.ship.ship_heading).normalized())
					_draw_line(1.0 if drawn == 0 else -0.8)
					drawn += 1
			if hero_id == "hercules" and frame_index % 60 == 30:
				_spawn_around(pos, heading)
			if out_dir != "-": _save.call_deferred()
			else:
				frame_index += 1
				if frame_index % 30 == 0:
					print("[perf] t=%.1f fps=%d process_ms=%.2f draw_calls=%d objects=%d tracing=%s holes=%d run_up_hits=%d" % [t, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), _ui().get("draw", {}).get("tracing", false), Array(_ui().get("vortex", {}).get("visuals", [])).filter(func(v): return int(v.kind) == 0).size(), Array(_ui().get("run_up", {}).get("hits", [])).size()])
			if frame_index >= frames:
				print("[hero] frames ", frame_index)
				get_tree().quit()
				phase = 4

func _save() -> void:
	await RenderingServer.frame_post_draw
	if phase != 3 and phase != 4: return
	var img := shown.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var f := FileAccess.open(out_dir.path_join("%04d.raw" % frame_index), FileAccess.WRITE)
	f.store_buffer(img.get_data())
	if frame_index % 15 == 0: img.save_png(out_dir.path_join("f%03d.png" % frame_index))
	frame_index += 1
