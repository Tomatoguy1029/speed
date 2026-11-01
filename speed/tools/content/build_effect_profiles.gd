## 明示ベイク済みの3種の爆発と圧縮弾を、共通ビルドでも照合する。
@tool
extends RefCounted

static func validate() -> Error:
	var saved := FileAccess.get_file_as_string("res://data/visuals/effect_settings.tres")
	var hashes := {}
	var pattern := RegEx.create_from_string('(?ms)^"([^"]+)": \\{\\n.*?^\\}')
	for capture in pattern.search_all(saved): hashes[capture.get_string(1)] = capture.get_string().sha256_text()
	for entry in [["burst_runtime.tres", 2, "bake_burst_profiles.py"], ["pump_shell_runtime.tres", 1, "bake_pump_shell.py"]]:
		var path := "res://data/visuals/" + String(entry[0])
		var baked := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if baked == null or baked.get_meta("bake_version", 0) != entry[1]: return ERR_INVALID_DATA
		for group in ["inputs", "outputs"]:
			for file: String in baked.get_meta(group, {}):
				if FileAccess.get_sha256(file) != baked.get_meta(group)[file]:
					push_error("表示素材をtools/art/%sでベイクしてください: %s" % [entry[2], file])
					return ERR_INVALID_DATA
		for key: String in baked.get_meta("saved_profiles", {}):
			if hashes.get(key, "") != baked.get_meta("saved_profiles")[key]:
				push_error("保存した表示をtools/art/%sでベイクしてください: %s" % [entry[2], key])
				return ERR_INVALID_DATA
	return OK
