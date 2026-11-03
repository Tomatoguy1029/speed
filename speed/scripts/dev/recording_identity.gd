## 開始時に一度だけ作る計測用の実行条件。ゲーム状態・乱数・読み込み済み資源を変更しない。
extends RefCounted

static func capture(session: RunSession, snapshot: Dictionary = {}) -> Dictionary:
	if snapshot.is_empty():
		var result: Dictionary = session.bridge.read_recording(true)
		if not result.ok: return {}
		snapshot = result.value
	var out: Dictionary = snapshot.conditions.duplicate(true)
	var levels := {}
	for entry: ContentEntry in ContentManager.catalog.table(&"meta_upgrades").values():
		levels[String(entry.id)] = SaveManager.run_meta_level(entry.id)
	out["meta_levels"] = levels
	out["meta_dev_override"] = not SaveManager.dev_meta_override.is_empty()
	out["physics_ticks_per_second"] = Engine.physics_ticks_per_second
	out["simulation_ticks_per_second"] = 120
	out["rng_seed"] = session.bridge.recording_origin.get("start",{}).get("seed","")
	out["xp_reward_version"] = 2
	out["xp_config"] = snapshot.xp_config.duplicate(true)
	var names_path := "res://.content/dev/stage_%s.json" % str(snapshot.identity.stage_id)
	var names: Variant = JSON.parse_string(FileAccess.get_file_as_string(names_path)) if FileAccess.file_exists(names_path) else {}
	if not names is Dictionary: names = {}
	out["xp_config"]["rank_counts"] = names.get("xp_rank_counts",{})
	out["xp_config"]["rank_counts_available"] = names.has("xp_rank_counts")
	out["stage_metadata"] = names
	out["enemy_tuning"] = snapshot.enemy_tuning.duplicate(true)
	out["run_state"] = snapshot.run_state.duplicate(true)
	var identity: Dictionary = snapshot.identity.duplicate(true)
	var scripts := {}
	var loaded_scripts := {}
	var data := {}
	# ビルド済み依存一覧を使う。旧GDScript戦闘コードやディレクトリ全体は走査しない。
	if session.cpp_resources!=null:
		for path: String in session.cpp_resources.dependencies:
			var hashes: Dictionary = scripts if path.ends_with(".gd") else data
			hashes[path] = session.cpp_resources.dependencies[path]
			if path.ends_with(".gd") and ResourceLoader.has_cached(path):
				var script := load(path) as Script
				if script!=null and script.has_source_code(): loaded_scripts[path] = script.source_code.sha256_text()
		identity["resource_signatures_sha256"] = digest(session.cpp_resources.signatures)
	scripts["res://project.godot"] = FileAccess.get_sha256("res://project.godot")
	identity.merge({"code_files_sha256":scripts,"loaded_script_sources_sha256":loaded_scripts,"data_files_sha256":data,
		"code_sha256":digest({"native":identity.implementation_sha256,"scripts":scripts}),"data_sha256":identity.payload_sha256,
		"config_sha256":digest(out.config),"stats_sha256":digest(out.stats),"xp_reward_config_sha256":digest(out.xp_config),
		"catalog_signature":ContentManager.catalog.source_signature,
		"build_revision":OS.get_environment("SPEED_BUILD_REVISION"),"scope":"run_runtime_bundle",
		"resource_digest_version":3,"source_files_available":not loaded_scripts.is_empty(),"git_state":git_state()})
	out["identity"] = identity
	return out

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
