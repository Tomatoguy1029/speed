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
	files.append("res://tools/art/bake_burst_profiles.py")
	files.append("res://tools/art/bake_pump_shell.py")
	files.append("res://tools/art/bake_landmark_masks.py")
	files.append("res://tools/art/elite_contacts.py")
	files.append("res://tools/art/bake_elite_crackle.py")
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
static var last_build_report: Array[Dictionary] = []

static func _select(files: PackedStringArray, prefixes: Array) -> PackedStringArray:
	var chosen := PackedStringArray(["res://project.godot", "res://addons/content_build/builder.gd", "res://addons/content_build/incremental.gd"])
	for path in files:
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

static func _bundle_outputs(path: String) -> PackedStringArray:
	var index = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return PackedStringArray([path,index.binary,index.resources]) if index is Dictionary else PackedStringArray()

## 一つのステージの配置・記録名・診断入力・戦闘データを同じ入力から作る。
static func _build_stage(source: StageDef, output: String, input_signature: String, reuse_prepared: bool) -> Dictionary:
	var config := load("res://data/config.tres") as GameConfig
	var stage := preload("res://tools/content/build_runtime_stage.gd").compile(source,output,config)
	if stage == null: return _result(ERR_INVALID_DATA, PackedStringArray())
	var paths := PackedStringArray([output.path_join("stage_%d.tres" % source.index),output.path_join("dev/stage_%d.json" % source.index),output.path_join("dev/native_spawn_%d.bin" % source.index)])
	var error := ResourceSaver.save(stage,paths[0])
	if error != OK: return _result(error,paths)
	# 保存済み配置の数値精度を通常の生成経路とそろえる。
	stage = ResourceLoader.load(paths[0],"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RuntimeStage
	if stage == null: return _result(ERR_FILE_CORRUPT,paths)
	var names := FileAccess.open(paths[1],FileAccess.WRITE)
	if names == null: return _result(FileAccess.get_open_error(),paths)
	names.store_string(JSON.stringify(preload("res://tools/content/build_runtime_stage.gd").names(source)))
	names.close()
	var timeline := preload("res://tools/content/build_native_data.gd").compile_spawn_timeline(stage,config)
	if timeline.is_empty(): return _result(ERR_INVALID_DATA,paths)
	var file := FileAccess.open(paths[2],FileAccess.WRITE)
	if file == null: return _result(FileAccess.get_open_error(),paths)
	file.store_var(timeline)
	file.close()
	error = preload("res://tools/content/build_run_content.gd").build(stage,config,output.path_join("run"),input_signature,{},[],{},null,{},PackedStringArray(),reuse_prepared)
	paths.append_array(_bundle_outputs(output.path_join("run/stage_%d.json" % source.index)))
	return _result(error,paths)

static func _build_intro(output: String, reuse_prepared: bool) -> Dictionary:
	var intro: Dictionary = load("res://scripts/runtime/intro_sequence.gd").practice_package(load("res://data/config.tres"),load("res://data/visuals/intro_presentation.tres"))
	var error := preload("res://tools/content/build_run_content.gd").build(intro.stage,intro.config,output.path_join("run/intro"),"導入練習".sha256_text(),intro.definitions,[],{},null,{},PackedStringArray(),reuse_prepared)
	return _result(error,_bundle_outputs(output.path_join("run/intro/stage_1.json")))

static func stage_inputs(files: PackedStringArray, source: StageDef, output: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for path in files:
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
				if not path in paths: paths.append(path)
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
	var files := PackedStringArray()
	for directory in ["res://data","res://scripts","res://scenes","res://addons","res://tools/content","res://shaders","res://assets"]: _files(directory,files)
	for name in ["bake_burst_noise","bake_burst_profiles","bake_pump_shell","bake_landmark_masks","elite_contacts","bake_elite_crackle"]: files.append("res://tools/art/"+name+".py")
	# 全編集元を内容で照合し、変更も出力欠落もなければResourceの読込前に返す。
	var all_inputs := files.duplicate()
	var boss_inputs := PackedStringArray()
	cache.files("res://data/bosses",boss_inputs)
	for path in boss_inputs:
		if not path in all_inputs: all_inputs.append(path)
	var input_fingerprint := _file_signature(all_inputs)
	var stamp_path := output.path_join("stamp.json")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(stamp_path)) if FileAccess.file_exists(stamp_path) else null
	if not force and saved is Dictionary and saved.get("input_fingerprint","") == input_fingerprint and not saved.get("outputs",[]).is_empty() and saved.outputs.all(func(path): return FileAccess.file_exists(path)) and FileAccess.file_exists(output.path_join("dev/build_cache.json")):
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
		["audio",["res://assets/audio/","res://tools/content/build_audio.gd","res://scripts/data_types/audio_bank.gd"],func(): return _result(load("res://tools/content/build_audio.gd").build(output.path_join("audio.res")),PackedStringArray([output.path_join("audio.res")]))],
		["probe",["res://data/config.tres","res://data/enemies/drifter.tres","res://data/weapons/W01_forward.tres","res://scripts/data_types/","res://tools/content/build_native_data.gd"],func(): return _result(load("res://tools/content/build_native_data.gd").build_probe(output.path_join("dev/native_probe.json")),PackedStringArray([output.path_join("dev/native_probe.json")]))]]
	for unit: Array in units:
		var inputs := _select(files,unit[1])
		if unit[0] == "attacks": inputs.append_array(preload("res://tools/content/build_attack_visuals.gd").input_paths())
		var error: Error = cache.run(unit[0],inputs,unit[2],force)
		if error != OK: return error
	var input_signature := signature()
	for name in DirAccess.get_files_at("res://data/stages"):
		if not name.ends_with(".tres"): continue
		var source := ResourceLoader.load("res://data/stages/"+name,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
		if source == null: return ERR_INVALID_DATA
		var error: Error = cache.run("stage_%d" % source.index,stage_inputs(files,source,output),func(): return _build_stage(source,output,input_signature,not force),force)
		if error != OK: return error
		cache.entries["stage_%d" % source.index].fingerprint = cache.digest(stage_inputs(files,source,output))
		error = _refresh_source_signature(output.path_join("run/stage_%d.json" % source.index),input_signature)
		if error != OK: return error
	var intro_inputs := _select(files,["res://data/","res://assets/","res://shaders/","res://scripts/","res://scenes/","res://tools/content/"])
	for i in range(intro_inputs.size()-1,-1,-1):
		if intro_inputs[i].begins_with("res://data/stages/") or intro_inputs[i].begins_with("res://data/bosses/") or intro_inputs[i].begins_with("res://data/codex/"): intro_inputs.remove_at(i)
	var error: Error = cache.run("intro",intro_inputs,func(): return _build_intro(output,not force),force)
	if error != OK: return error
	var active := {}
	for row: Dictionary in cache.report: active[row.unit] = true
	for key in cache.entries.keys():
		if not active.has(key): cache.entries.erase(key)
	error = cache.save(output.path_join("dev/build_cache.json"))
	if error != OK: return error
	var outputs: PackedStringArray = cache.outputs()
	var stamp := FileAccess.open(output.path_join("stamp.json"),FileAccess.WRITE)
	if stamp == null: return FileAccess.get_open_error()
	stamp.store_string(JSON.stringify({"signature":input_signature,"outputs":outputs,"input_fingerprint":_file_signature(all_inputs)}))
	stamp.close()
	last_build_report.assign(cache.report)
	return OK

## 開発用C++入口。通常入口の切替までは明示して呼ぶ。
static func build_cpp_stage(source: StageDef, config: GameConfig, output := ROOT, definitions := {}) -> Error:
	var stage := preload("res://tools/content/build_runtime_stage.gd").compile(source,output,config)
	if stage == null: return ERR_INVALID_DATA
	return preload("res://tools/content/build_run_content.gd").build(stage,config,output.path_join("run"),signature(),definitions)
