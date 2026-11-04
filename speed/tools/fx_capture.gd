## 独立コピー上で、正規ランの状態と表示から連続コマを保存する。
extends Node

const TICK := 1.0 / 120.0
const SIZE := Vector2i(1280,720)
var session: RunSession
var viewport: SubViewport
var render: RunPresentation
var values := {}
var checkpoints: Array[int] = []
var observations: Array = []
var intent := Intent.new()

func _ready() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_name()=="headless":
		_fail("撮影には描画付きの起動が必要です")
		return
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().simplify_path()
	if not _isolated(root):
		_fail("独立コピーと保存先の隔離を確認できません")
		return
	var spec_path := root.path_join(".fx-user/capture-spec.json")
	var spec = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	if not spec is Dictionary or not _valid_spec(spec):
		_fail("撮影条件を読み取れません: " + spec_path)
		return
	if not _valid_identity(root,spec.build_identity):
		_fail("撮影用ライブラリとビルド情報が一致しません")
		return
	var index_path: String = spec.index
	var index = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not index is Dictionary or not index.get("input_sha256","") is String:
		_fail("生成済みランの索引がありません")
		return
	var output := root.path_join(".fx-user/captures").path_join(spec.id)
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		_fail("撮影先を作れません")
		return
	if not DirAccess.get_files_at(output).is_empty():
		_fail("撮影先に既存ファイルがあります: " + output)
		return
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	session = RunManager.create_session(viewport,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,
		"seed":int(spec.seed),"hud":false,"cpp_start":{"lab_mode":true},"cpp_profile":ProfileManager.for_cpp(true,{})},true)
	session.remove_from_group("recordable_runs")
	session.auto_step = false
	while is_instance_valid(session) and session.bridge==null and session.cpp_error==OK:
		await get_tree().process_frame
	if not is_instance_valid(session) or session.bridge==null:
		_fail("本番ランの開始に失敗しました")
		return
	var recording: Dictionary = session.bridge.read_recording(true)
	if not recording.ok or recording.value.get("identity",{}).get("implementation_sha256","")!=spec.build_identity.source_sha256:
		_fail("ロード済みC++と撮影用ソースのハッシュが一致しません")
		return
	session.bridge.unsubscribe("audio")
	session.bridge.unsubscribe("laser_audio")
	var router := session.cpp_input_source.get_object() as InputRouter
	if router!=null:
		router.set_process_input(false)
		router.set_process_unhandled_input(false)
	render = session.view.get_node("RunPresentation") as RunPresentation
	render.set_process(false)
	render.view_override = {"center":Vector2(float(spec.camera.center[0]),float(spec.camera.center[1])),"zoom":float(spec.camera.zoom),"shake":bool(spec.camera.get("shake",false))}
	var setup: Dictionary = session.bridge.command("dev_set_scenario",{"kind":"lab","params":{"lab_mode":true,"auto_spawn":false,"auto_boss":false,"invincible":true,"empty":true}})
	if not setup.ok:
		_fail("撮影場面の初期化に失敗しました")
		return
	var images: Array = []
	var commands: Array = spec.commands
	var next_command := 0
	for frame in int(spec.frames):
		var tick := frame * 2
		while next_command<commands.size() and int(commands[next_command].tick)==tick:
			if not _action(commands[next_command]): return
			next_command += 1
		if not _present(spec.camera,frame,images): return
		await RenderingServer.frame_post_draw
		if not _save_frame(output,frame,images): return
		if frame+1==int(spec.frames): break
		for offset in 2:
			if offset==1:
				while next_command<commands.size() and int(commands[next_command].tick)==tick+1:
					if not _action(commands[next_command]): return
					next_command += 1
			if not _sync_camera(spec.camera): return
			var result: Dictionary = session.bridge.step(TICK,session.bridge.pack_intent(intent),{"logical_size":Vector2(SIZE)})
			if not result.ok:
				_fail("戦闘の固定更新に失敗しました: " + str(result))
				return
	var metadata := {"id":spec.id,"fps":60,"tick_rate":120,"size":[SIZE.x,SIZE.y],"seed":int(spec.seed),
		"index":index_path,"index_input_sha256":index.input_sha256,"camera":spec.camera,"build_identity":spec.build_identity,
		"library_sha256":FileAccess.get_sha256("res://extensions/run/bin/libspeed_runtime.macos.template_release.arm64.dylib"),
		"dependencies_sha256":FileAccess.get_sha256(root.path_join("cpp/dependencies.json")),"engine":Engine.get_version_info(),
		"frames":images,"observations":observations}
	var file := FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
	if file==null:
		_fail("撮影条件を保存できません")
		return
	file.store_string(JSON.stringify(metadata,"\t"))
	for checkpoint in checkpoints: session.bridge.release_checkpoint(checkpoint)
	print("撮影完了: ",output)
	get_tree().quit(0)

func _present(camera: Dictionary, frame: int, images: Array) -> bool:
	if not _sync_camera(camera): return false
	var state: Dictionary = session.bridge.read_frame()
	if not state.ok:
		_fail("撮影時刻を読めません")
		return false
	var center: Vector2 = render.view_override.center
	render._present_cpp(0.0 if frame==0 else 1.0/60.0)
	images.append({"file":"%06d.png" % frame,"tick":frame*2,"seconds":frame/60.0,"world_time":state.value.ui.world_time,"camera_center":[center.x,center.y]})
	return true

## 撮影中はC++と表示の双方へ、同じ比較用カメラを各固定更新前に渡す。
func _sync_camera(camera: Dictionary) -> bool:
	var center := Vector2(float(camera.center[0]),float(camera.center[1]))
	if camera.get("mode","fixed")=="boss_ship_midpoint":
		var state: Dictionary = session.bridge.read_frame()
		if not state.ok:
			_fail("追従カメラの機体を読めません")
			return false
		var bodies: Dictionary = session.bridge.command("dev_boss_body_state")
		var actor := int(values.get(str(camera.get("boss_ref","")),-1))
		var found := false
		if bodies.ok:
			for body: Dictionary in bodies.value:
				if int(body.actor)==actor:
					center = (body.position+state.value.ui.ship.ship_pos)*0.5
					found = true
					break
		if not found:
			_fail("追従カメラのボスを読めません")
			return false
	var updated: Dictionary = session.bridge.command("dev_edit",{"kind":"camera","payload":{"center":center,"size":Vector2(SIZE),"zoom":float(camera.zoom),"bars":0.0}})
	if not updated.ok:
		_fail("本番の比較用カメラを設定できません")
		return false
	render.view_override.center = center
	return true

func _save_frame(output: String, frame: int, images: Array) -> bool:
	if viewport.get_texture().get_image().save_png(output.path_join(images[frame].file))!=OK:
		_fail("コマを保存できません: %d" % frame)
		return false
	return true

## 特殊な入力はVector2と命令結果の参照だけを変換し、戦闘は本番命令へ渡す。
func _decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size()==1 and value.has("vector2"):
			return Vector2(float(value.vector2[0]),float(value.vector2[1]))
		if value.size()==1 and value.has("integer"): return int(value.integer)
		if value.size()==1 and value.has("ref"): return values.get(str(value.ref))
		var result := {}
		for key in value: result[key] = _decode(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_decode(item))
		return result
	return value

func _action(action: Dictionary) -> bool:
	var kind := str(action.get("kind",""))
	var result := {}
	match kind:
		"command": result = session.bridge.command(str(action.get("name","")),_decode(action.get("payload",{})))
		"checkpoint": result = session.bridge.checkpoint()
		"restore": result = session.bridge.restore(int(values.get(str(action.get("ref","")),-1)))
		"release": result = session.bridge.release_checkpoint(int(values.get(str(action.get("ref","")),-1)))
		"input":
			for key in action.get("fields",{}):
				if key not in ["has_cursor","cursor","stick","stick_active","pen","press","alt_press","hero_press","pen_release","touch"]:
					_fail("不明な入力: " + str(key))
					return false
				intent.set(key,_decode(action.fields[key]))
			return true
		_:
			_fail("不明な撮影操作: " + kind)
			return false
	if not result.get("ok",false):
		_fail("撮影操作に失敗しました: " + str(action) + " / " + str(result))
		return false
	if action.has("save"):
		values[str(action.save)] = result.get("value")
		if kind=="checkpoint": checkpoints.append(int(result.value))
	if action.get("observe",false): observations.append({"tick":int(action.tick),"name":action.get("name",kind),"value":var_to_str(result.get("value"))})
	if kind=="release": checkpoints.erase(int(values.get(str(action.get("ref","")),-1)))
	return true

func _valid_spec(spec: Dictionary) -> bool:
	if not spec.get("id") is String or not spec.id.is_valid_filename() or spec.id in [".",".."]: return false
	if not spec.get("index") is String or not spec.index.begins_with("res://.content/"): return false
	if not spec.get("seed") is int and not spec.get("seed") is float: return false
	if not spec.get("frames") is int and not spec.get("frames") is float: return false
	if int(spec.frames)<1 or not spec.get("camera") is Dictionary or not spec.camera.get("center") is Array or spec.camera.center.size()!=2 or float(spec.camera.get("zoom",0))<=0.0: return false
	if spec.camera.get("mode","fixed") not in ["fixed","boss_ship_midpoint"]: return false
	if spec.camera.get("mode","fixed")=="boss_ship_midpoint" and not spec.camera.get("boss_ref") is String: return false
	if not spec.get("commands") is Array or not spec.get("build_identity") is Dictionary or spec.build_identity.is_empty(): return false
	var previous := -1
	for item in spec.commands:
		if not item is Dictionary or not item.has("tick"): return false
		var tick := int(item.tick)
		if tick<previous or tick<0 or tick>=(int(spec.frames)-1)*2+1: return false
		previous = tick
	return true

func _isolated(root: String) -> bool:
	if root.get_base_dir()!="/private/tmp" or not root.get_file().begins_with("speed-fx-capture."): return false
	var isolated := root.path_join(".fx-user")
	if not DirAccess.dir_exists_absolute(isolated): return false
	if SaveManager.SAVE_PATH!=isolated.path_join("save.json") or SaveManager.SETTINGS_PATH!=isolated.path_join("settings.cfg"): return false
	var launcher := FileAccess.get_file_as_string("res://addons/stage_launcher/launch_request.gd")
	var recorder := FileAccess.get_file_as_string("res://scripts/dev/play_recorder.gd")
	return launcher.contains('const PATH := "'+isolated.path_join("stage_launch.cfg")+'"') and recorder.contains('"'+isolated.path_join("recordings")+'"')

func _valid_identity(root: String, identity: Dictionary) -> bool:
	for key in ["source_sha256","dependencies_sha256","library_sha256"]:
		if not identity.get(key) is String or identity[key].length()!=64: return false
	if not identity.get("base_commit") is String or identity.base_commit.is_empty(): return false
	return identity.dependencies_sha256==FileAccess.get_sha256(root.path_join("cpp/dependencies.json")) and identity.library_sha256==FileAccess.get_sha256("res://extensions/run/bin/libspeed_runtime.macos.template_release.arm64.dylib")

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
