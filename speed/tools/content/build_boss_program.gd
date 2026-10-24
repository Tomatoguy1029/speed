@tool
extends RefCounted
const PROGRAM := preload("res://scripts/data_types/boss_runtime_program.gd")
const VERSION := 2
static var generation_count := 0

static func snapshot(value: Variant) -> Variant:
	if value is Script: return value
	if value is Resource:
		var copy: Resource = value.duplicate(true)
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["script", "resource_name", "resource_local_to_scene"]:
				copy.set(property.name, {} if property.name == "layout" else snapshot(value.get(property.name)))
		return copy
	if value is Dictionary:
		var copy := {}
		for key in value:
			if key != "layout": copy[key] = snapshot(value[key])
		return copy
	if value is Array:
		var copy: Array = value.duplicate()
		for i in value.size(): copy[i] = snapshot(value[i])
		return copy
	return value

static func build_hydra(output := "res://.content/boss_hydra.tres") -> Dictionary:
	var rules = ResourceLoader.load("res://data/bosses/ai/hydra_action_rules.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var flow = ResourceLoader.load("res://data/bosses/ai/hydra_flow.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if rules == null or flow == null: return {"error": ERR_FILE_NOT_FOUND, "generated": false}
	return compile({"rules": rules, "flow": flow}, output)

static func canonical(value: Variant) -> Variant:
	if value is Resource:
		var fields := {}
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["resource_name", "resource_local_to_scene", "script", "layout"]:
				fields[property.name] = canonical(value.get(property.name))
		return fields
	if value is Dictionary:
		var fields := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			if key != "layout": fields[key] = canonical(value[key])
		return fields
	if value is Array:
		var items := []
		for item in value: items.append(canonical(item))
		return items
	return value

static func compile(source: Dictionary, output: String) -> Dictionary:
	var signature := var_to_str(canonical(source)).sha256_text()
	if FileAccess.file_exists(output):
		var previous = ResourceLoader.load(output, "", ResourceLoader.CACHE_MODE_IGNORE)
		if previous != null and previous.get_script() == PROGRAM and previous.version == VERSION and previous.signature == signature:
			return {"error": OK, "program": previous, "generated": false}
	var program := PROGRAM.new()
	program.version = VERSION
	program.signature = signature
	program.data = snapshot(source)
	program.data.erase("layout")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error := ResourceSaver.save(program, output)
	if error == OK: generation_count += 1
	return {"error": error, "program": program if error == OK else null, "generated": error == OK}
