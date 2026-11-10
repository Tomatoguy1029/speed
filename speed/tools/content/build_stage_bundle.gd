## ステージと導入の生成内容。入口と報告から分けて依存を追跡する。
@tool
extends RefCounted

static func _result(error: Error, paths: PackedStringArray) -> Dictionary:
	return {"error":error,"outputs":paths}

static func _bundle_outputs(path: String) -> PackedStringArray:
	var index = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return PackedStringArray([path,index.binary,index.resources]) if index is Dictionary else PackedStringArray()

## 一つのステージの配置・記録名・診断入力・戦闘データを同じ入力から作る。
static func build_stage(source: StageDef, output: String, input_signature: String, reuse_prepared: bool) -> Dictionary:
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
