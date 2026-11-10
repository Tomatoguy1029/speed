## 実行前・CLI・exportで共有する生成処理。
@tool
extends RefCounted
const ROOT := "res://.content"
static func _files(directory: String, result: PackedStringArray) -> void:
	for name in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		if path == "res://data/content_catalog.tres": continue
		if path.begins_with("res://data/bosses/ai/") or "_moves/" in path: continue
		if path.get_extension() in ["gd", "tres", "res", "tscn", "gdshader", "gdshaderinc", "png", "svg", "jpg", "jpeg", "webp", "mp3", "wav", "ogg", "glsl", "import"] or path.ends_with(".regions.json"): result.append(path)
	for name in DirAccess.get_directories_at(directory):
		if not name.begins_with("."): _files(directory.path_join(name), result)
static func signature() -> String:
	var files := PackedStringArray()
	for directory in ["res://data", "res://scripts", "res://scenes", "res://addons", "res://tools/content", "res://shaders", "res://assets"]: _files(directory, files)
	files.append("res://tools/art/bake_burst_noise.py")
	files.append("res://tools/art/bake_draco_finale.py")
	files.append("res://tools/art/bake_burst_profiles.py")
	files.append("res://tools/art/bake_pump_shell.py")
	files.append("res://tools/art/bake_landmark_masks.py")
	files.append("res://tools/art/bake_elite_death.py")
	files.append("res://tools/art/elite_contacts.py")
	files.append("res://tools/art/bake_elite_crackle.py")
	for name in ["bake_phoenix_fx", "bake_centaurus_contact_masks", "bake_canis_fx"]: files.append("res://tools/art/"+name+".py")
	files.append_array(preload("res://tools/content/build_canis_fx.gd").input_paths())
	files.append_array(preload("res://tools/content/build_boss_image_fx.gd").input_paths())
	files.append_array(preload("res://tools/content/build_canis_image_fx.gd").input_paths())
	files.append_array(preload("res://tools/content/build_monoceros_image_fx.gd").input_paths())
	files.append_array(preload("res://tools/content/build_canis_roar_fx.gd").input_paths())
	files.append_array(preload("res://tools/content/build_canis_fire_fx.gd").input_paths())
	files.append("res://tools/art/bake_canis_hound_edges.py")
	for name in ["bake_reference_edges","bake_roar_textures"]: files.append("res://tools/art/"+name+".py")
	files.append("res://tools/art/bake_canis_contact_masks.py")
	files.append("res://tools/art/bake_monoceros_contact_masks.py")
	for path in preload("res://tools/content/build_attack_visuals.gd").input_paths():
		if not path in files and FileAccess.file_exists(path): files.append(path)
	return _file_signature(files)

static func _file_signature(files: PackedStringArray) -> String:
	files = files.duplicate()
	files.sort()
	var hashes := PackedStringArray(["engine:" + str(Engine.get_version_info().string), "res://project.godot:" + FileAccess.get_sha256("res://project.godot")])
	for path in files: hashes.append(path + ":" + FileAccess.get_sha256(path))
	return "\n".join(hashes).sha256_text()
static func is_current(output := ROOT) -> bool:
	var stamp := output.path_join("stamp.json")
	if not FileAccess.file_exists(stamp): return false
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(stamp))
	if not saved is Dictionary or saved.get("signature", "") != signature(): return false
	for path in saved.get("outputs", []):
		if not FileAccess.file_exists(path): return false
	return true
const INPUTS := preload("res://addons/content_build/inputs.gd")
const STAGES := preload("res://tools/content/build_stage_bundle.gd")
static var last_build_report: Array[Dictionary] = []
const EDITOR_RESULT_PREFIX := "SPEED_CONTENT_BUILD_RESULT:"

static func editor_arguments() -> PackedStringArray:
	return PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--quit-after","1",
		"--script","res://tools/content/build_all.gd","--","--editor-build-report"])

## エディターが保持した古いC++拡張・Resourceを、生成に使わない。
static func build_for_editor() -> Error:
	last_build_report = []
	var output := []
	var exit_code := OS.execute(OS.get_executable_path(),editor_arguments(),output,true)
	var result_error: Error = FAILED
	for chunk: String in output:
		for line: String in chunk.split("\n"):
			if line.begins_with(EDITOR_RESULT_PREFIX):
				var result: Variant = JSON.parse_string(line.trim_prefix(EDITOR_RESULT_PREFIX))
				if result is Dictionary and (result.get("error") is float or result.get("error") is int) and result.get("report") is Array:
					result_error = int(result.error)
					last_build_report.assign(result.report)
			elif not line.is_empty() and not line.begins_with("Godot Engine "):
				print(line)
	return FAILED if exit_code!=0 and result_error==OK else result_error

static func _select(files: PackedStringArray, prefixes: Array) -> PackedStringArray:
	var chosen := PackedStringArray(["res://project.godot"])
	for path in files:
		if not INPUTS.affects_output(path): continue
		for prefix: String in prefixes:
			if path.begins_with(prefix):
				if not path in chosen: chosen.append(path)
				break
	return chosen

static func _result(error: Error, paths: PackedStringArray) -> Dictionary:
	return {"error":error,"outputs":paths}

static func _visual_outputs(output: String) -> PackedStringArray:
	var paths := PackedStringArray([output.path_join("visual_index.tres"),output.path_join("meteor_pieces.res")])
	for name in DirAccess.get_files_at("res://data/visuals/looks"):
		if name.ends_with(".tres"):
			paths.append(output.path_join("look_"+name.get_basename()+".res"))
			paths.append(output.path_join("dev/armor_"+name.get_basename()+".res"))
	return paths

static func stage_inputs(files: PackedStringArray, source: StageDef, output: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for path in files:
		if not INPUTS.affects_stage(path): continue
		if path.begins_with("res://data/stages/") and path != source.resource_path: continue
		if path.begins_with("res://data/codex/"): continue
		if path.begins_with("res://data/bosses/"):
			if path != "res://data/bosses/%s.tres" % source.boss_id and not (source.boss_id == &"draco" and path == "res://data/bosses/hydra.tres"): continue
		paths.append(path)
	if not source.resource_path.is_empty() and not source.resource_path in paths: paths.append(source.resource_path)
	if not source.boss_id.is_empty(): paths.append(output.path_join("boss_%s.tres" % source.boss_id))
	if source.boss_id == &"draco": paths.append(output.path_join("boss_hydra.tres"))
	# 前回の実行資源が参照した外部ファイルも追跡する。生成物の欠落も入力変更になる。
	var index_path := output.path_join("run/stage_%d.json" % source.index)
	var index = JSON.parse_string(FileAccess.get_file_as_string(index_path)) if FileAccess.file_exists(index_path) else null
	if index is Dictionary and FileAccess.file_exists(index.resources):
		var resources := ResourceLoader.load(index.resources,"",ResourceLoader.CACHE_MODE_IGNORE) as Resource
		if resources != null:
			for path: String in resources.dependencies:
				if INPUTS.affects_stage(path) and not path in paths: paths.append(path)
	return paths

## 全体の編集版だけを更新し、変わっていない戦闘バイナリと資源表はそのまま使う。
static func _refresh_source_signature(path: String, input_signature: String) -> Error:
	var index = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not index is Dictionary: return ERR_FILE_CORRUPT
	if index.get("source_sha256") == input_signature: return OK
	index.source_sha256 = input_signature
	var file := FileAccess.open(path+".pending",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(index))
	file.close()
	return DirAccess.rename_absolute(path+".pending",path)

static func _source_files() -> PackedStringArray:
	var files := PackedStringArray()
	for directory in ["res://data","res://scripts","res://scenes","res://addons","res://tools/content","res://shaders","res://assets"]: _files(directory,files)
	for name in ["bake_burst_noise","bake_burst_profiles","bake_pump_shell","bake_landmark_masks","bake_elite_death","elite_contacts","bake_elite_crackle","bake_phoenix_fx","bake_centaurus_contact_masks","bake_canis_fx","bake_canis_contact_masks","bake_monoceros_contact_masks","bake_reference_edges","bake_roar_textures"]: files.append("res://tools/art/"+name+".py")
	return files

static func _all_inputs(files: PackedStringArray) -> PackedStringArray:
	var all_inputs := files.duplicate()
	var boss_inputs := PackedStringArray()
	preload("res://addons/content_build/incremental.gd").files("res://data/bosses",boss_inputs)
	for path in boss_inputs:
		if not path in all_inputs: all_inputs.append(path)
	return all_inputs

static func _unchanged(output: String, input_fingerprint: String) -> bool:
	var stamp_path := output.path_join("stamp.json")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(stamp_path)) if FileAccess.file_exists(stamp_path) else null
	return saved is Dictionary and saved.get("input_fingerprint","") == input_fingerprint and not saved.get("outputs",[]).is_empty() and saved.outputs.all(func(path): return FileAccess.file_exists(path)) and FileAccess.file_exists(output.path_join("dev/build_cache.json"))

## 別プロセスを起動せず、全編集元と出力の照合だけを行う。
static func is_unchanged(output := ROOT) -> bool:
	return _unchanged(output,_file_signature(_all_inputs(_source_files())))

static func build_all(force := false, output := ROOT) -> Error:
	var resources = preload("res://tools/content/build_run_resources.gd")
	resources.begin_batch()
	var error := _build_units(force,output)
	resources.end_batch()
	return error

static func _build_units(force: bool, output: String) -> Error:
	last_build_report = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("dev")))
	var cache := preload("res://addons/content_build/incremental.gd").new()
	cache.open(output.path_join("dev/build_cache.json"))
	last_build_report = cache.report
	var files := _source_files()
	# 全編集元を内容で照合し、変更も出力欠落もなければResourceの読込前に返す。
	var all_inputs := _all_inputs(files)
	var input_fingerprint := _file_signature(all_inputs)
	if not force and _unchanged(output,input_fingerprint):
		last_build_report.append({"unit":"all","rebuilt":false})
		return OK
	# 変更がないときは技のResourceを読み込まず、依存の内容だけを照合する。
	for id in ["hydra","monoceros","draco","centaurus","canis_major"]:
		var inputs := _select(files,["res://scripts/data_types/","res://tools/content/build_boss_program.gd"])
		inputs.append_array(PackedStringArray(["res://data/bosses/ai/"+id+"_action_rules.tres","res://data/bosses/ai/"+id+"_flow.tres"]))
		var error: Error = cache.run("boss_"+id,inputs,func():
			var path := output.path_join("boss_"+id+".tres")
			var result: Dictionary = preload("res://tools/content/build_boss_program.gd").build_boss(id,path)
			return _result(result.error,PackedStringArray([path])),force)
		if error != OK: return error
	var units := [
		["visuals",["res://data/visuals/","res://data/enemies/","res://assets/","res://shaders/","res://scripts/data_types/","res://tools/content/build_visuals.gd","res://tools/content/visual_transforms.gd","res://tools/content/build_effect_profiles.gd","res://tools/art/"],func(): return _result(load("res://tools/content/build_visuals.gd").build(output),_visual_outputs(output))],
		["attacks",["res://data/bosses/","res://data/enemies/","res://data/visuals/","res://scenes/attacks/","res://scripts/render/attacks/","res://scripts/data_types/","res://assets/","res://shaders/","res://tools/content/build_attack_visuals.gd","res://tools/content/build_stage_resources.gd"],func(): return _result(load("res://tools/content/build_attack_visuals.gd").build(output),PackedStringArray([output.path_join("attack_visuals.res")]))],
		["aura",["res://tools/content/build_hero_aura.gd","res://scripts/data_types/hero_aura_assets.gd","res://shaders/hero_aura.gdshader"],func(): return _result(load("res://tools/content/build_hero_aura.gd").build(output),PackedStringArray([output.path_join("hero_aura.res")]))],
		["codex",["res://data/codex/","res://scripts/data_types/codex_animation.gd","res://tools/content/build_codex_thumbnails.gd"],func():
			var paths := PackedStringArray()
			for name in DirAccess.get_files_at("res://data/codex"):
				if name.ends_with(".res"): paths.append(output.path_join("codex_thumbnail_"+name))
			return _result(load("res://tools/content/build_codex_thumbnails.gd").build(output),paths)],
		["catalog",["res://data/","res://scripts/data_types/","res://scripts/render/","res://scenes/attacks/","res://assets/","res://shaders/","res://tools/content/build_catalog.gd","res://tools/content/build_stage_resources.gd"],func():
			var path := "res://data/content_catalog.tres" if output == ROOT else output.path_join("catalog.tres")
			return _result(load("res://tools/content/build_catalog.gd").build(path),PackedStringArray([path]))],
		["audio",["res://assets/audio/","res://tools/content/build_audio.gd","res://scripts/data_types/audio_bank.gd","res://scripts/data_types/sound_entry.gd","res://scripts/data_types/sound_table.gd","res://scripts/data_types/sound_slots.gd"],func(): return _result(load("res://tools/content/build_audio.gd").build(output.path_join("audio.res")),PackedStringArray([output.path_join("audio.res")]))],
		["probe",["res://data/config.tres","res://data/enemies/splitling.tres","res://data/weapons/W01_forward.tres","res://scripts/data_types/","res://tools/content/build_native_data.gd"],func(): return _result(load("res://tools/content/build_native_data.gd").build_probe(output.path_join("dev/native_probe.json")),PackedStringArray([output.path_join("dev/native_probe.json")]))]]
	for unit: Array in units:
		var inputs := _select(files,unit[1])
		if unit[0] == "attacks": inputs.append_array(preload("res://tools/content/build_attack_visuals.gd").input_paths())
		var error: Error = cache.run(unit[0],inputs,unit[2],force)
		if error != OK: return error
	preload("res://tools/content/build_run_resources.gd").hold_definitions()
	var input_signature := signature()
	for name in DirAccess.get_files_at("res://data/stages"):
		if not name.ends_with(".tres"): continue
		var source := ResourceLoader.load("res://data/stages/"+name,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
		if source == null: return ERR_INVALID_DATA
		var error: Error = cache.run("stage_%d" % source.index,stage_inputs(files,source,output),func(): return STAGES.build_stage(source,output,input_signature,not force),force)
		if error != OK: return error
		cache.entries["stage_%d" % source.index].fingerprint = cache.digest(stage_inputs(files,source,output))
		error = _refresh_source_signature(output.path_join("run/stage_%d.json" % source.index),input_signature)
		if error != OK: return error
	var active := {}
	for row: Dictionary in cache.report: active[row.unit] = true
	for key in cache.entries.keys():
		if not active.has(key): cache.entries.erase(key)
	var error: Error = cache.save(output.path_join("dev/build_cache.json"))
	if error != OK: return error
	var outputs: PackedStringArray = cache.outputs()
	var stamp := FileAccess.open(output.path_join("stamp.json"),FileAccess.WRITE)
	if stamp == null: return FileAccess.get_open_error()
	stamp.store_string(JSON.stringify({"signature":input_signature,"outputs":outputs,"input_fingerprint":input_fingerprint if _file_signature(all_inputs)==input_fingerprint else ""}))
	stamp.close()
	return OK

## 開発用C++入口。通常入口の切替までは明示して呼ぶ。
static func build_cpp_stage(source: StageDef, config: GameConfig, output := ROOT, definitions := {}) -> Error:
	var stage := preload("res://tools/content/build_runtime_stage.gd").compile(source,output,config)
	if stage == null: return ERR_INVALID_DATA
	return preload("res://tools/content/build_run_content.gd").build(stage,config,output.path_join("run"),signature(),definitions)
