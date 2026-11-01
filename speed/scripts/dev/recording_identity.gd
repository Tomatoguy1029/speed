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
	var reward_config := xp_config(run)
	return {"config": config, "profile": plain(run.ctx.profile), "stats": stats(run.state.stats), "meta_levels": meta_levels,
		"xp_reward_version": PickupSystem.XP_REWARD_VERSION, "xp_config": reward_config,
		"enemy_tuning": plain(run.enemies.get("stage_tuning")) if "stage_tuning" in run.enemies else {},
		"meta_dev_override": not SaveManager.dev_meta_override.is_empty(), "physics_ticks_per_second": Engine.physics_ticks_per_second,
		"rng_seed": str(run.state.rng.seed), "rng_state": str(run.state.rng.state),
		"hitstop_enabled": run.state.hitstop_enabled, "invincible": run.ship.invincible,
		"identity": {"code_files_sha256": scripts, "loaded_script_sources_sha256": loaded_scripts,
			"data_files_sha256": data, "code_sha256": digest(scripts), "data_sha256": digest(data),
			"loaded_data_sha256": loaded_data, "enemy_definitions_sha256": digest(plain(run.enemies.definitions)),
			"config_sha256": digest(config), "xp_reward_config_sha256": digest(reward_config), "runtime_stage_sha256": digest(plain(run.state.stage)),
			"catalog_signature": ContentManager.catalog.source_signature,
			"build_revision": OS.get_environment("SPEED_BUILD_REVISION"),
			"scope": "run_initialization", "resource_digest_version": 2, "source_files_available": source_files_available}}

## 解決済み報酬と回収時倍率を読み取る。定義の解決・乱数消費・ゲーム状態の更新を行わない。
static func xp_config(run: RunSimulation) -> Dictionary:
	var cfg := run.cfg
	var ranks := {}
	for stars in range(11):
		ranks[str(stars)] = Array(EnemyDef.default_xp_reward_counts(stars))
	return {"xp_reward_version": PickupSystem.XP_REWARD_VERSION,
		"xp_crystal_values": {"low": cfg.xp_crystal_values[0], "mid": cfg.xp_crystal_values[1], "high": cfg.xp_crystal_values[2]},
		"rank_counts": ranks, "enemy_rewards": run.enemies.xp_reward_snapshot(),
		"strong_gold_chance": cfg.strong_gold_chance, "cap": {"mode": "oldest_high_absorber", "limit": cfg.gem_max},
		"xp_base": cfg.xp_base, "xp_growth": cfg.xp_growth, "xp_curve": cfg.xp_curve,
		"ship_multiplier": run.state.stats.xp_mult, "run_multiplier": run.state.stats.xp_gain_mult,
		"collection_multiplier": run.loadout.crystal_multiplier(), "multiplier_application": "collection_once"}

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

## 録画開始時のディスク上のGodotプロジェクトだけを識別する。Gitが使えなければ未知にする。
static func git_state() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://")
	var revision_out := []
	var revision_status := OS.execute("git", PackedStringArray(["-C", root, "rev-parse", "HEAD"]), revision_out)
	if revision_status != 0 or revision_out.is_empty():
		return {"revision": "", "dirty": null, "scope": "project_disk_at_recording_start"}
	var status_out := []
	var status_code := OS.execute("git", PackedStringArray(["-c", "core.optionalLocks=false", "-C", root,
		"status", "--porcelain=v1", "--untracked-files=all", "--", "."]), status_out)
	var dirty: Variant = null
	if status_code == 0:
		dirty = not String(status_out[0]).strip_edges().is_empty() if not status_out.is_empty() else false
	return {"revision": String(revision_out[0]).strip_edges(),
		"dirty": dirty,
		"scope": "project_disk_at_recording_start"}

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
