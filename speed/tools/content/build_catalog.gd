## 索引の生成は制作工程で行い、実行時は結果だけを読む。
@tool
extends RefCounted
const CATEGORIES := {"enemies": "enemy", "phases": "phase", "stages": "stage", "bosses": "boss", "weapons": "weapon", "traits": "trait", "meta_upgrades": "meta", "legendary_modules": "legendary", "heroes": "hero"}
static func build(output := "res://data/content_catalog.tres") -> Error:
	var catalog := ContentCatalog.new()
	for category in CATEGORIES:
		for file in DirAccess.get_files_at("res://data/" + category):
			if not file.ends_with(".tres"): continue
			var path := "res://data/%s/%s" % [category, file]
			var definition: Resource = load(path)
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
	return ResourceSaver.save(catalog, output)
