## 開始時に一度だけ作る計測用の実行条件。ゲーム状態・乱数・読み込み済み資源を変更しない。
extends RefCounted

static func capture(run: RunSimulation) -> Dictionary:
	var scripts := {}
	var loaded_scripts := {}
	_scan("res://scripts", ["gd"], scripts, loaded_scripts)
	_scan("res://addons", ["gd"], scripts, loaded_scripts)
	var source_files_available := not scripts.is_empty()
	scripts["res://project.godot"] = FileAccess.get_sha256("res://project.godot")
	var data := {}
	var unused := {}
	_scan("res://data", ["tres"], data, unused)
	var config: Dictionary = plain(run.cfg)
	var loaded_data := {}
	for file in data:
		if ResourceLoader.has_cached(file): loaded_data[file] = digest(plain(load(file)))
	var meta_levels := {}
	for entry: ContentEntry in ContentManager.catalog.table(&"meta_upgrades").values():
		meta_levels[String(entry.id)] = SaveManager.run_meta_level(entry.id)
	return {"config": config, "profile": plain(run.ctx.profile), "stats": stats(run.state.stats), "meta_levels": meta_levels,
		"enemy_tuning": plain(run.enemies.get("stage_tuning")) if "stage_tuning" in run.enemies else {},
		"meta_dev_override": not SaveManager.dev_meta_override.is_empty(), "physics_ticks_per_second": Engine.physics_ticks_per_second,
		"rng_seed": str(run.state.rng.seed), "rng_state": str(run.state.rng.state),
		"hitstop_enabled": run.state.hitstop_enabled, "invincible": run.ship.invincible,
		"identity": {"code_files_sha256": scripts, "loaded_script_sources_sha256": loaded_scripts,
			"data_files_sha256": data, "code_sha256": digest(scripts), "data_sha256": digest(data),
			"loaded_data_sha256": loaded_data, "enemy_definitions_sha256": digest(plain(run.enemies.definitions)),
			"config_sha256": digest(config), "runtime_stage_sha256": digest(plain(run.state.stage)),
			"catalog_signature": ContentManager.catalog.source_signature,
			"build_revision": OS.get_environment("SPEED_BUILD_REVISION"),
			"scope": "run_initialization", "resource_digest_version": 2, "source_files_available": source_files_available}}

static func _scan(path: String, extensions: Array, files: Dictionary, loaded: Dictionary) -> void:
	for name in DirAccess.get_files_at(path):
		if not extensions.has(name.get_extension()): continue
		var file := path.path_join(name)
		files[file] = FileAccess.get_sha256(file)
		if name.ends_with(".gd") and ResourceLoader.has_cached(file):
			var script := load(file) as Script
			if script != null and script.has_source_code():
				loaded[file] = script.source_code.sha256_text()
	for name in DirAccess.get_directories_at(path):
		_scan(path.path_join(name), extensions, files, loaded)

static func digest(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func stats(value: ShipStats) -> Dictionary:
	var out := {}
	for prop in value.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[String(prop.name)] = value.get(prop.name)
	return out

static func plain(value: Variant) -> Variant:
	# 画像の生バイトをJSONの数列へ展開しない。内容のSHA-256で識別する。
	if value is PackedByteArray:
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(value)
		return {"bytes": value.size(), "sha256": hash.finish().hex_encode()}
	if value is Resource:
		var out := {}
		for prop in value.get_property_list():
			if prop.usage & PROPERTY_USAGE_STORAGE and prop.name not in ["script", "resource_name", "resource_local_to_scene"]:
				out[String(prop.name)] = plain(value.get(prop.name))
		return out
	if value is Dictionary:
		var out := {}
		for key in value: out[str(key)] = plain(value[key])
		return out
	if value is Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedStringArray or value is PackedVector2Array:
		var out := []
		for item in value: out.append(plain(item))
		return out
	return value
