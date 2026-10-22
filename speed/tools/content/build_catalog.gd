## 索引の生成は制作工程で行い、実行時は結果だけを読む。
@tool
extends RefCounted
const CATEGORIES := {"enemies": "enemy", "phases": "phase", "stages": "stage", "bosses": "boss", "weapons": "weapon", "traits": "trait", "meta_upgrades": "meta", "legendary_modules": "legendary", "heroes": "hero"}
static func build(output := "res://data/content_catalog.tres") -> Error:
	var catalog := ContentCatalog.new()
	var hashes := PackedStringArray([FileAccess.get_sha256("res://tools/content/build_catalog.gd")])
	for category in CATEGORIES:
		for file in DirAccess.get_files_at("res://data/" + category):
			if not file.ends_with(".tres"): continue
			var path := "res://data/%s/%s" % [category, file]
			hashes.append(path + ":" + FileAccess.get_sha256(path))
			var definition: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			var entry := ContentEntry.new()
			entry.category = category
			entry.path = path
			entry.text_prefix = CATEGORIES[category]
			if category == "stages": entry.index = definition.index
			else: entry.id = definition.id
			for key in ["code_id", "order", "costs", "stat", "per_level", "comet_only"]:
				if key in definition: entry.set(key, definition.get(key))
			for key in ["icon", "preview"]:
				var property: String = key + "_texture"
				if property in definition and definition.get(property) != null:
					entry.set(key + "_path", definition.get(property).resource_path)
			if "params" in definition:
				for key in ["color", "branches_by_level"]:
					if definition.params.has(key): entry.params[key] = definition.params[key]
			catalog.entries.append(entry)
	catalog.source_signature = "\n".join(hashes).sha256_text()
	if FileAccess.file_exists(output):
		var previous := load(output) as ContentCatalog
		if previous != null and previous.source_signature == catalog.source_signature: return OK
	return ResourceSaver.save(catalog, output)
