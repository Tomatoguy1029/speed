@tool
extends RefCounted
const PROGRAM := preload("res://scripts/data_types/boss_runtime_program.gd")
const VERSION := 1

static func canonical(value: Variant) -> Variant:
	if value is Resource:
		var fields := {}
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["resource_name", "resource_local_to_scene", "script"]:
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
	program.signature = signature
	program.data = source.duplicate(true)
	program.data.erase("layout")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error := ResourceSaver.save(program, output)
	return {"error": error, "program": program if error == OK else null, "generated": error == OK}
