## シーンの抽出は制作工程で行う。SpawnSystemは生成結果だけを使う。
@tool
extends RefCounted

static func formation(scene: PackedScene) -> Dictionary:
	if scene == null: return {}
	var node := scene.instantiate()
	var result: Dictionary = node.to_data() if node.has_method("to_data") else {}
	node.free()
	return result

static func clip(source: SpawnClip) -> RuntimeClip:
	var result := RuntimeClip.new()
	for key in ["types", "time", "length", "groups", "interval", "attack_priority"]:
		result.set(key, source.get(key))
	for scene in source.formations:
		var data := formation(scene)
		var layouts := []
		for index in source.allowed_layouts(scene.resource_path, data):
			var layout: Dictionary = data.layouts[index].duplicate(true)
			layout.value = source.formation_value(scene.resource_path, str(layout.get("name", "")))
			layout.erase("name")
			layouts.append(layout)
		if not layouts.is_empty():
			result.prepared.append({"layouts": layouts, "entries": data.entries})
	return result

static func compile(source: StageDef) -> RuntimeStage:
	var result := RuntimeStage.new()
	for property in source.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE == 0: continue
		if property.name in ["script", "resource_path", "resource_name", "resource_local_to_scene", "clips", "phases", "track_names", "scene_path", "backgrounds"]: continue
		var value: Variant = source.get(property.name)
		result.set(property.name, value.duplicate(true) if value is Dictionary or value is Array else value)
	for placement in source.backgrounds:
		result.backgrounds.append(preload("res://tools/content/prepare_background.gd").compile(placement))
	result.zako_curves = []
	for curve in source.zako_curves: result.zako_curves.append(curve.duplicate(true))
	result.phases = []
	for phase: PhaseDef in source.phases:
		var copy := phase.duplicate(true) as PhaseDef
		copy.display_name = ""
		result.phases.append(copy)
	for item in source.clips: result.clips.append(clip(item))
	result.resources = load("res://tools/content/build_stage_resources.gd").build(result)
	# 実行用にも局所上書きを保持し、未知の敵・項目・不正な数値を生成時に止める。
	for id in result.enemy_tuning:
		var path := "res://data/enemies/%s.tres" % String(id)
		var definition := load(path) as EnemyDef if ResourceLoader.exists(path) else null
		if definition == null or not result.enemy_tuning[id] is Dictionary:
			push_error("敵調整の定義が不正: %s" % id)
			return null
		var problem := StageEnemyTuning.error_for(definition, result.enemy_tuning[id])
		if not problem.is_empty():
			push_error("敵調整 %s: %s" % [id, problem])
			return null
	return result if result.resources != null else null

static func names(source: StageDef) -> Dictionary:
	var result := {"phases": {}, "clips": {}}
	for phase: PhaseDef in source.phases: result.phases[String(phase.id)] = phase.display_name
	for index in source.clips.size(): result.clips[index] = source.clips[index].label
	return result

static func build_all(output := "res://.content") -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("dev")))
	for file in DirAccess.get_files_at("res://data/stages"):
		if not file.ends_with(".tres"): continue
		var source := ResourceLoader.load("res://data/stages/" + file, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
		var compiled := compile(source)
		if compiled == null: return ERR_INVALID_DATA
		var error := ResourceSaver.save(compiled, output.path_join("stage_%d.tres" % source.index))
		if error != OK: return error
		var handle := FileAccess.open(output.path_join("dev/stage_%d.json" % source.index), FileAccess.WRITE)
		if handle == null: return FileAccess.get_open_error()
		handle.store_string(JSON.stringify(names(source)))
	return OK
