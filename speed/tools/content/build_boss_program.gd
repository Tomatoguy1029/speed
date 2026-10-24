@tool
extends RefCounted
const PROGRAM := preload("res://scripts/data_types/boss_runtime_program.gd")
const VERSION := 2
static var generation_count := 0

static func validate(source: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var rules: Resource = source.get("rules")
	var flow: Resource = source.get("flow")
	if rules != null:
		var ids := {}
		for move in rules.techniques:
			var id := String(move.technique)
			if id.is_empty() or ids.has(id): errors.append("技IDの重複・欠損: " + id)
			ids[id] = true
		for id in rules.conditions:
			var gate: Dictionary = rules.conditions[id]
			var minimum := float(gate.get("min", 0.0))
			var maximum := float(gate.get("max", INF))
			var angle := float(gate.get("angle", 0.0))
			var half := float(gate.get("half_angle", 180.0))
			if not is_finite(minimum) or is_nan(maximum) or not is_finite(angle) or not is_finite(half) or minimum < 0.0 or minimum > maximum or half < 0.0 or half > 180.0: errors.append("距離・角度条件が不正: " + id)
		for id in rules.costs:
			var cost := float(rules.costs[id])
			if not is_finite(cost) or cost < 0.0: errors.append("消費が不正: " + id)
		for id in rules.combos: _validate_combo(rules.combos[id], ids, errors, String(id), 0)
	if flow != null:
		if flow.maximum_stamina <= 0.0 or flow.partial_rest < 0.0 or flow.empty_rest < 0.0: errors.append("最大スタミナ・休息時間が不正")
		if flow.sections.is_empty(): errors.append("区間がありません")
		for i in flow.sections.size():
			var section: Dictionary = flow.sections[i]
			if int(section.get("next", 0)) < 0 or int(section.get("next", 0)) >= flow.sections.size(): errors.append("次区間が存在しません: " + str(i))
			if section.get("request", "normal") not in ["normal", "major", "rest", "any"]: errors.append("要求種別が不正: " + str(i))
			if float(section.get("cap", flow.maximum_stamina)) <= 0.0: errors.append("消費上限が不正: " + str(i))
	return errors

static func _validate_combo(node: Dictionary, ids: Dictionary, errors: PackedStringArray, id: String, depth: int) -> void:
	if depth > 24:
		errors.append("コンボの階層が深すぎます: " + id)
		return
	match node.get("type", ""):
		"action":
			if not ids.has(String(node.get("id", ""))) or String(node.get("id", "")) == id: errors.append("コンボ内の技参照が不正: " + id)
		"wait":
			if float(node.get("seconds", -1)) < 0.0: errors.append("待機時間が不正: " + id)
		"sequence", "parallel", "branch":
			var children: Array = node.get("children", [])
			if children.is_empty() or (node.type == "branch" and children.size() != 2): errors.append("コンボの接続が不正: " + id)
			for child in children: _validate_combo(child, ids, errors, id, depth + 1)
		_: errors.append("コンボの種類が不正: " + id)

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
	var errors := validate(source)
	if not errors.is_empty(): return {"error": ERR_INVALID_DATA, "errors": errors, "program": null, "generated": false}
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
	var temporary := output + ".pending.tres"
	var error := ResourceSaver.save(program, temporary)
	if error == OK: error = DirAccess.rename_absolute(temporary, output)
	if error != OK and FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	if error == OK: generation_count += 1
	return {"error": error, "program": program if error == OK else null, "generated": error == OK}
