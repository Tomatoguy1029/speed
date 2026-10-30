## 実験用 JSON の保存・差分・再現基準。読み込みからコードやシーンを実行しない。
extends RefCounted
const ARMOR_PAINT := preload("res://tools/content/visual_transforms.gd")
const VERSION := 1
const ROOT := "user://enemy_lab"
const COMMANDS := ["boss_appearance", "armor_paint", "spawn", "boss", "move", "delete", "clear", "command", "input", "invincible", "ship", "parameter", "director", "schedule", "loadout", "config", "hero", "guard", "individual", "boss_parameter", "phase_set", "meta", "time", "edit_range", "level", "route", "pin", "field"]

static func plain(value):
	if value is Vector2:
		return [value.x, value.y]
	if value is Color:
		return value.to_html()
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = plain(value[key])
		return result
	if value is Array or value is PackedVector2Array:
		var result := []
		for item in value:
			result.append(plain(item))
		return result
	if value is StringName:
		return String(value)
	return value

static func baseline() -> Dictionary:
	var hashes: Dictionary = ContentManager.source_hashes.duplicate()
	_hash_sources("res://scripts", hashes)
	_hash_sources("res://gyms/enemy_lab", hashes)
	return {"engine": Engine.get_version_info().string, "files": hashes}

static func record(session, route: PackedVector2Array, pattern: Dictionary, results: Array, candidates: Array = []) -> Dictionary:
	return plain({"version": VERSION, "kind": "record", "baseline": session.baseline.duplicate(true), "spec": session.spec,
		"history": session.history, "branches": session.branches, "branch_name": session.current_branch, "branch_serial": session.branch_serial, "tick": session.tick, "end": session.furthest,
		"route": route, "pattern": pattern, "results": results, "candidates": candidates})

static func preset(session, route: PackedVector2Array, pattern: Dictionary) -> Dictionary:
	var spec: Dictionary = session.spec.duplicate(true)
	spec["overrides"] = differences(session)
	spec["boss_overrides"] = boss_differences(session)
	spec["config"] = {}
	for property in session.run.cfg.get_property_list():
		var key: String = property.name
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and typeof(session.run.cfg.get(key)) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL] and session.run.cfg.get(key) != ContentManager.base.get(key):
			spec.config[key] = session.run.cfg.get(key)
	spec["weapons"] = {}
	for id in session.run.state.weapons: spec.weapons[String(id)] = session.run.state.weapons[id]
	spec["traits"] = {}
	for id in session.run.state.traits: spec.traits[String(id)] = session.run.state.traits[id]
	spec["hero"] = String(session.run.state.hero_power)
	spec["level"] = session.run.state.level
	spec["meta"] = session.run.state.meta_override.duplicate(true)
	spec["director"] = session.run.projectiles.director.settings.duplicate(true)
	spec.director["enabled"] = session.run.projectiles.director.enabled
	spec["ship_pos"] = plain(session.run.state.ship_pos)
	spec["gauge"] = session.run.state.gauge
	spec["time"] = session.run.state.time
	spec["schedule"] = session.schedule.duplicate(true)
	var phase_ids := []
	for phase in session.run.state.stage.phases:
		if ContentManager.phases.has(phase.id): phase_ids.append(String(phase.id))
	var commands := [{"tick": 0, "kind": "phase_set", "args": {"ids": phase_ids}}]
	var t := session.run.enemies.table as EnemyTable
	for i in t.alive.size():
		if not t.alive[i] or t.dead[i] or t.parent[i] >= 0:
			continue
		commands.append({"tick": 0, "kind": "boss" if t.is_boss[i] else "spawn",
			"args": {"type": String(t.type[i]), "pos": plain(t.pos[i]), "angle": t.facing[i], "elite": t.elite[i] != 0}})
	return plain({"version": VERSION, "kind": "preset", "baseline": session.baseline.duplicate(true), "spec": spec,
		"history": commands, "branches": [], "tick": 0, "end": 0, "route": route, "pattern": pattern, "results": []})

static func differences(session) -> Dictionary:
	var changes := {}
	for id in session.run.enemies.definitions:
		var current: EnemyDef = session.run.enemies.definitions[id]
		var base: EnemyDef = ContentManager.enemies.get(id)
		if base == null:
			continue
		var values := {}
		for property in current.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and String(property.name) not in ["script", "resource_name", "resource_local_to_scene"]:
				if current.get(property.name) != base.get(property.name):
					values[property.name] = plain(current.get(property.name))
		if not values.is_empty():
			changes[String(id)] = values
	return changes

static func save_json(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(plain(data), "\t", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(temporary, path)

static func safe_name(value: String) -> String:
	return value.validate_filename().replace("..", "_").replace("/", "_").left(80) if not value.strip_edges().is_empty() else "experiment"

static func read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16000000:
		return {"error": TranslationServer.translate("lab.message_87b29ea1a5")}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {"error": TranslationServer.translate("lab.message_d2cbd5f4c9")}
	var data: Dictionary = json.data
	var problem := validate(data)
	if not problem.is_empty():
		return {"error": problem}
	data["stale"] = data.get("baseline", {}) != baseline()
	return data

static func validate(data: Dictionary) -> String:
	if int(data.get("version", 0)) != VERSION or data.get("kind") not in ["record", "preset"]:
		return TranslationServer.translate("lab.message_5aa5077c96")
	if not data.get("spec") is Dictionary or not data.get("history") is Array or not data.get("branches", []) is Array:
		return TranslationServer.translate("lab.message_03af38d54f")
	var format_error := TranslationServer.translate("lab.message_03af38d54f")
	for key in ["tick", "end", "branch_serial"]:
		if data.has(key) and (not _number_ok(data[key]) or float(data[key]) < 0): return format_error
	if int(data.get("tick", 0)) > int(data.get("end", 0)): return format_error
	if data.has("branch_name") and not data.branch_name is String: return format_error
	if not data.get("results", []) is Array: return format_error
	for comparison in data.get("results", []):
		if not comparison is Dictionary or not comparison.get("route", []) is Array or not comparison.get("result", {}) is Dictionary: return format_error
		for point in comparison.get("route", []):
			if not _vector_ok(point): return format_error
		var result: Dictionary = comparison.get("result", {})
		if result.has("end") and not _vector_ok(result.end): return format_error
		if result.get("status") == "replayed":
			for key in ["kills", "damage", "gauge"]:
				if not _number_ok(result.get(key)): return format_error
	var previous_tick := -1
	for command in data.history:
		if not command is Dictionary or not _number_ok(command.get("tick")): return format_error
		if int(command.tick) < previous_tick or int(command.tick) > int(data.get("end", 0)): return format_error
		previous_tick = int(command.tick)
	for branch in data.get("branches", []):
		if not branch is Dictionary or not branch.get("name") is String or not _number_ok(branch.get("end")): return format_error
	if data.history.size() > 100000 or data.branches.size() > 128 or int(data.get("end", 0)) > 216000:
		return TranslationServer.translate("lab.message_5411903cfb")
	var spec: Dictionary = data.spec
	for key in ["seed", "stage", "time", "gauge", "level"]:
		if spec.has(key) and not _number_ok(spec[key]): return TranslationServer.translate("lab.message_6d6845a8d1")
	if not data.get("pattern", {}) is Dictionary: return TranslationServer.translate("lab.error_b356dea242")
	var pattern_error := _pattern_problem(data.get("pattern", {}))
	if not pattern_error.is_empty(): return pattern_error
	if not data.get("candidates", []) is Array or data.get("candidates", []).size() > 128: return TranslationServer.translate("lab.error_46cc43be42")
	for candidate in data.get("candidates", []):
		if not candidate is Dictionary or not candidate.get("route", []) is Array: return TranslationServer.translate("lab.error_f5899d482e")
		for point in candidate.get("route", []):
			if not _vector_ok(point): return TranslationServer.translate("lab.error_51df4a5681")
		if not candidate.get("commands", []) is Array: return TranslationServer.translate("lab.error_34dfb05e18")
		for command in candidate.get("commands", []):
			if not command is Dictionary: return TranslationServer.translate("lab.error_f2c0bc8a77")
			var item: Dictionary = command.duplicate(true)
			item["tick"] = 0
			var error := _validate_command(item)
			if not error.is_empty(): return error

	for key in ["empty", "auto_spawn", "auto_boss", "invincible"]:
		if spec.has(key) and not spec[key] is bool: return TranslationServer.translate("lab.message_03af38d54f")
	for key in spec:
		if key not in ["seed", "empty", "stage", "auto_spawn", "auto_boss", "invincible", "config", "overrides", "boss_overrides", "meta", "ship_pos", "time", "gauge", "weapons", "traits", "level", "hero", "schedule", "director", "field"]:
			return TranslationServer.translate("lab.message_516be31176") + String(key)
	if int(spec.get("stage", 1)) < 1 or int(spec.get("stage", 1)) > ContentManager.stage_count():
		return TranslationServer.translate("lab.message_da5e2e784c")
	for key in ["config", "overrides", "boss_overrides", "meta", "weapons", "traits", "director", "field"]:
		if spec.has(key) and not spec[key] is Dictionary: return TranslationServer.translate("lab.message_5023536a4b") + key
	for pair in [["overrides", false], ["boss_overrides", true]]:
		var error := _definition_problem(spec.get(pair[0], {}), pair[1])
		if not error.is_empty(): return error
	for id in spec.get("meta", {}):
		if not ContentManager.meta_upgrades.has(StringName(id)) or not _number_ok(spec.meta[id]) or float(spec.meta[id]) < 0 or float(spec.meta[id]) > 100: return TranslationServer.translate("lab.message_dcb428f285")
	if not spec.get("hero", "") is String or (not String(spec.get("hero", "")).is_empty() and not ContentManager.heroes.has(StringName(spec.hero))): return TranslationServer.translate("lab.message_dcb428f285")
	var director_error := _director_problem(spec.get("director", {}))
	if not director_error.is_empty(): return director_error
	var schedule_error := _schedule_problem(spec.get("schedule", []))
	if not schedule_error.is_empty(): return schedule_error
	if not _vector_ok(spec.get("ship_pos", [0, 0])): return TranslationServer.translate("lab.message_c6f64ef280")
	for pair in [["weapons", ContentManager.weapons], ["traits", ContentManager.traits]]:
		for id in spec.get(pair[0], {}):
			if not pair[1].has(StringName(id)) or not _number_ok(spec[pair[0]][id]) or float(spec[pair[0]][id]) > 100: return TranslationServer.translate("lab.message_dcb428f285")
	if not data.get("route", []) is Array or data.get("route", []).size() > 10000: return TranslationServer.translate("lab.message_97502315d3")
	for point in data.get("route", []):
		if not _vector_ok(point): return TranslationServer.translate("lab.message_275c3dbb23")
	if not data.get("pattern", {}) is Dictionary: return TranslationServer.translate("lab.message_1ea25ab8b0")
	for key in spec.get("config", {}):
		var found := false
		for property in ContentManager.base.get_property_list():
			if property.name == key and int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and typeof(spec.config[key]) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
				found = true
		if not found:
			return TranslationServer.translate("lab.message_3b1b000e8b") + String(key)
	for id in spec.get("overrides", {}):
		if not ContentManager.enemies.has(StringName(id)):
			return TranslationServer.translate("lab.message_3fc0d7300b") + String(id)
		for key in spec.overrides[id]:
			if key not in ["hp", "toughness", "armor", "speed", "radius", "accel", "turn", "xp", "weak_arc", "params", "visual_settings", "armor_colors"]:
				return TranslationServer.translate("lab.message_8cfee97b22") + String(key)
	for command in data.history:
		var problem := _validate_command(command)
		if not problem.is_empty():
			return problem
	for branch in data.get("branches", []):
		if not branch is Dictionary or not branch.get("history") is Array:
			return TranslationServer.translate("lab.message_8c395a3b3b")
		for command in branch.history:
			var problem := _validate_command(command)
			if not problem.is_empty():
				return problem
	return ""

static func _validate_command(command) -> String:
	if not command is Dictionary or command.get("kind") not in COMMANDS or not command.get("args") is Dictionary:
		return TranslationServer.translate("lab.message_2fa6cacf94")
	if int(command.get("tick", -1)) < 0 or int(command.tick) > 216000:
		return TranslationServer.translate("lab.message_884b1ef739")
	if command.kind in ["boss_appearance", "spawn", "boss", "parameter", "boss_parameter", "meta", "time", "edit_range", "level"]:
		if not command.args.get("type", "") is String and not command.args.get("type", "") is StringName: return TranslationServer.translate("lab.message_03af38d54f")
		var id := StringName(command.args.get("type", ""))
		if not ContentManager.enemies.has(id) and not ContentManager.bosses.has(id):
			return TranslationServer.translate("lab.message_3fc0d7300b") + String(id)
	var args: Dictionary = command.args
	if args.has("pos") and not _vector_ok(args.pos): return TranslationServer.translate("lab.message_2a897624ac")
	for key in ["cursor", "pen"]:
		if args.has(key) and not _vector_ok(args[key]): return TranslationServer.translate("lab.message_c547a6d3c5")
	if command.kind in ["parameter", "boss_parameter", "meta", "time", "edit_range", "level"]:
		if not _number_ok(args.get("value")) and not args.get("value") is bool: return TranslationServer.translate("lab.message_6b1292dfc2")
	for key in ["count", "level", "angle", "gauge", "id", "size"]:
		if args.has(key) and not _number_ok(args[key]) and not (command.kind in ["loadout", "hero"] and key == "id"): return TranslationServer.translate("lab.message_6d6845a8d1")
	if command.kind in ["config", "parameter", "boss_parameter", "edit_range"] and not args.get("key", "") is String: return TranslationServer.translate("lab.message_dcb428f285")
	if command.kind == "loadout" and not args.get("reset", false):
		if not args.get("id", "") is String or args.get("kind", "weapon") not in ["weapon", "trait"]: return TranslationServer.translate("lab.message_dcb428f285")
		var registry: Dictionary = ContentManager.weapons if args.get("kind", "weapon") == "weapon" else ContentManager.traits
		if not registry.has(StringName(args.get("id", ""))): return TranslationServer.translate("lab.message_dcb428f285")
	if command.kind == "boss_appearance":
		if not ContentManager.bosses.has(StringName(args.get("type", ""))) or not BossDef.valid_part_appearance(args.get("parts")):
			return TranslationServer.translate("lab.message_7241f95e31")
	if command.kind == "armor_paint":
		if not ContentManager.enemies.has(StringName(args.get("type", ""))) or not ARMOR_PAINT.valid_palettes(args.get("colors")):
			return TranslationServer.translate("lab.message_7241f95e31")
	if command.kind == "hero":
		if not args.get("id", "") is String or (not String(args.get("id", "")).is_empty() and not ContentManager.heroes.has(StringName(args.id))): return TranslationServer.translate("lab.message_dcb428f285")
	if command.kind == "director":
		var error := _director_problem(args)
		if not error.is_empty(): return error
	if command.kind == "phase_set":
		if not args.get("ids", []) is Array: return TranslationServer.translate("lab.error_b03790ec83")
		for id in args.get("ids", []):
			if not ContentManager.phases.has(StringName(id)): return TranslationServer.translate("lab.error_1ba7e23ea5")
	if command.kind == "schedule":
		var error := _schedule_problem(args.get("entries", []))
		if not error.is_empty(): return error
	if command.kind == "command" and command.args.get("name", "") not in ["draw_button", "debug_time", "debug_grant", "debug_reset_loadout", "debug_gauge_full", "debug_heal", "debug_invincible"]:
		return TranslationServer.translate("lab.message_e4cadb1cab")
	return ""

static func boss_differences(session) -> Dictionary:
	var changes := {}
	for id in session.run.bosses.definitions:
		var def: BossDef = session.run.bosses.definitions[id]
		var base: BossDef = ContentManager.bosses[id]
		var values := {}
		for key in ["params", "speed", "radius", "accel", "turn", "weak_arc", "xp", "part_appearance"]:
			if def.get(key) != base.get(key): values[key] = plain(def.get(key))
		if not values.is_empty(): changes[String(id)] = values
	return changes

static func _vector_ok(value) -> bool:
	return value is Array and value.size() == 2 and _number_ok(value[0]) and _number_ok(value[1])

static func _number_ok(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= 1e12

static func _schedule_problem(entries) -> String:
	if not entries is Array or entries.size() > 256: return TranslationServer.translate("lab.message_3313855ba5")
	for entry in entries:
		if not entry is Dictionary: return TranslationServer.translate("lab.message_e33e75d642")
		if not ContentManager.enemies.has(StringName(entry.get("type", ""))) and not ContentManager.bosses.has(StringName(entry.get("type", ""))): return TranslationServer.translate("lab.message_f9993c711a")
		if not _vector_ok(entry.get("pos", [0, 0])): return TranslationServer.translate("lab.message_bb508ec943")
		for key in ["start", "end", "interval", "count", "level"]:
			if entry.has(key) and not _number_ok(entry[key]): return TranslationServer.translate("lab.message_b58910d240")
		if float(entry.get("interval", 1)) <= 0: return TranslationServer.translate("lab.message_94331992ec")
	return ""

static func _definition_problem(values, boss := false) -> String:
	if not values is Dictionary: return TranslationServer.translate("lab.message_1f862285cc")
	for id in values:
		var registry: Dictionary = ContentManager.bosses if boss else ContentManager.enemies
		if not registry.has(StringName(id)) or not values[id] is Dictionary: return TranslationServer.translate("lab.message_3c66a49d71")
		var original: Resource = registry[StringName(id)]
		for key in values[id]:
			var value = values[id][key]
			if key == "part_appearance" and boss:
				if not BossDef.valid_part_appearance(value): return TranslationServer.translate("lab.message_7241f95e31")
			elif key == "armor_colors" and not boss:
				if not ARMOR_PAINT.valid_palettes(value): return TranslationServer.translate("lab.message_7241f95e31")
			elif key == "visual_settings" and not boss:
				if not value is Dictionary: return TranslationServer.translate("lab.message_2dac0fe5e5")
				for field in value:
					if not EnemyDef.VISUAL_LIMITS.has(field) or not _number_ok(value[field]): return TranslationServer.translate("lab.message_7241f95e31")
					var limits: Vector2 = EnemyDef.VISUAL_LIMITS[field]
					if float(value[field]) < limits.x or float(value[field]) > limits.y: return TranslationServer.translate("lab.message_7241f95e31")
			elif key == "params":
				if not value is Dictionary: return TranslationServer.translate("lab.message_2dac0fe5e5")
				for param in value:
					if not original.params.has(param) or (not _number_ok(value[param]) and not value[param] is bool): return TranslationServer.translate("lab.message_7241f95e31")
			elif key not in ["hp", "toughness", "armor", "speed", "radius", "accel", "turn", "xp", "weak_arc"] or not _number_ok(value):
				return TranslationServer.translate("lab.message_00769fb623")
			elif (float(value) < 0 and key != "toughness") or (key in ["hp", "radius"] and float(value) <= 0):
				return TranslationServer.translate("lab.message_7d67422141")
	return ""

static func _hash_sources(folder: String, into: Dictionary) -> void:
	var dir := DirAccess.open(folder)
	if dir == null: return
	for file in dir.get_files():
		if file.ends_with(".gd") or file.ends_with(".tscn"): into[folder.path_join(file)] = FileAccess.get_sha256(folder.path_join(file))
	for child in dir.get_directories(): _hash_sources(folder.path_join(child), into)

static func _director_problem(value: Dictionary) -> String:
	if value.has("budget") and (not _number_ok(value.budget) or float(value.budget) < 0): return TranslationServer.translate("lab.error_ea2fd16cf8")
	for key in ["slots", "weights", "gaps"]:
		if not value.get(key, {}) is Dictionary: return TranslationServer.translate("lab.error_76545bdd1e")
		for category in value.get(key, {}):
			if category not in ["aimed", "homing", "dash", "beam", "zone", "wave", "residue"] or not _number_ok(value[key][category]) or float(value[key][category]) < 0: return TranslationServer.translate("lab.error_141fdea6d8")
	return ""

static func _pattern_problem(value: Dictionary) -> String:
	if value.is_empty(): return ""
	if not value.get("route", []) is Array or value.get("route", []).size() > 10000 or not value.get("regions", []) is Array or value.get("regions", []).size() > 10000: return TranslationServer.translate("lab.error_d1d25618ab")
	for point in value.get("route", []):
		if not _vector_ok(point): return TranslationServer.translate("lab.error_59317e2e86")
	for key in ["margin", "rotation", "scale_min", "scale_max", "min_fodder", "window", "attempts", "draw_seconds", "exit_clearance", "min_spacing"]:
		if value.has(key) and not _number_ok(value[key]): return TranslationServer.translate("lab.error_8a4eb2caa3")
	for region in value.get("regions", []):
		if not region is Dictionary or not _vector_ok(region.get("pos", [0, 0])): return TranslationServer.translate("lab.error_956b200251")
		if not ContentManager.enemies.has(StringName(region.get("type", ""))) and not ContentManager.bosses.has(StringName(region.get("type", ""))): return TranslationServer.translate("lab.error_1c4f35b1cc")
		for key in ["jitter", "level", "angle", "min_count", "max_count"]:
			if region.has(key) and not _number_ok(region[key]): return TranslationServer.translate("lab.error_28ac733ef0")
	return ""

static func adoption_baseline() -> Dictionary:
	var result: Dictionary = baseline().files
	for path in result.keys():
		if String(path).begins_with("res://data/stages/"): result.erase(path)
	return result
