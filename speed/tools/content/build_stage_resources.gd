## 編集元から利用する種類と依存資源を解決する。外観の差し替えもここで反映する。
@tool
extends RefCounted
static func _add(paths: Dictionary, path: String) -> void:
	if paths.has(path) or not ResourceLoader.exists(path): return
	paths[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		var parts := dependency.split("::")
		_add(paths, parts[-1])
	if path.ends_with(".gd") and FileAccess.file_exists(path):
		var pattern := RegEx.new()
		pattern.compile('res://[^"\\n]+')
		for match in pattern.search_all(FileAccess.get_file_as_string(path)): _add(paths, match.get_string())
static func _script(paths: Dictionary, path: String) -> String:
	_add(paths, path)
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
static func _attack(paths: Dictionary, kind: String) -> void:
	_script(paths, "res://scripts/attacks/%s.gd" % kind)
	_script(paths, "res://scripts/render/attacks/%s.gd" % kind)
	if kind in ["zone", "beam"]:
		for file in DirAccess.get_files_at("res://scripts/render/attacks"):
			if file.begins_with(kind + "_") and file.ends_with(".gd") and file != "beam_flood.gd":
				_script(paths, "res://scripts/render/attacks/" + file)
	if kind in ["enemy", "ring_hold", "lump"]:
		_script(paths, "res://scripts/attacks/bullet.gd")
		_script(paths, "res://scripts/render/attacks/bullet.gd")
	if kind == "enemy":
		_script(paths, "res://scripts/attacks/missile.gd")
		_script(paths, "res://scripts/render/attacks/missile.gd")
	if kind in ["cross", "flood"]: _script(paths, "res://scripts/render/attacks/beam.gd")
	if kind == "flood":
		_script(paths, "res://scripts/render/attacks/beam_flood.gd")
		_script(paths, "res://scripts/render/attacks/flood.gd")
		_add(paths, "res://shaders/water_flood.gdshader")
	if kind == "rings": _script(paths, "res://scripts/render/attacks/wave.gd")
static func build(stage: RuntimeStage) -> StageResources:
	var result := StageResources.new()
	var paths := {}
	for placement: BackgroundPlacement in stage.backgrounds:
		if placement.texture != null: _add(paths, placement.texture.resource_path)
	var catalog := load("res://data/content_catalog.tres") as ContentCatalog
	var ids := {}
	for id in stage.enemies: ids[String(id)] = true
	for curve in stage.zako_curves: ids[String(curve.type)] = true
	for phase: PhaseDef in stage.phases:
		for id in phase.mix: ids[String(id)] = true
		if phase.wave_type != &"": ids[String(phase.wave_type)] = true
	for clip: RuntimeClip in stage.clips:
		for formation in clip.prepared:
			for layout in formation.layouts:
				for marker in layout.markers:
					if clip.types.is_empty() or StringName(marker.type) in clip.types: ids[String(marker.type)] = true
	var cfg := load("res://data/config.tres") as GameConfig
	for kind in ["meteor", "iron", "saw"]:
		if cfg.get(kind + "_count") > 0: ids[kind] = true
	var pending := ids.keys()
	var known := catalog.table(&"enemies")
	var attack_pattern := RegEx.new()
	attack_pattern.compile('projectiles\\.fire_([A-Za-z_]+)')
	var shared := FileAccess.get_file_as_string("res://scripts/enemies/enemy_behavior.gd")
	for match in attack_pattern.search_all(shared): _attack(paths, match.get_string(1))
	for entry in catalog.table(&"heroes").values(): _add(paths, entry.path)
	while not pending.is_empty():
		var id: String = pending.pop_back()
		var entry := catalog.find(&"enemies", StringName(id))
		if entry == null: continue
		_add(paths, entry.path)
		var definition := load(entry.path) as EnemyDef
		var behavior := "res://scripts/enemies/%s.gd" % definition.behavior
		var text := _script(paths, behavior)
		_script(paths, "res://scripts/render/enemies/%s.gd" % definition.behavior)
		_script(paths, "res://scripts/render/enemies/%s.gd" % id)
		for match in attack_pattern.search_all(text): _attack(paths, match.get_string(1))
		# 派生体と増援に使うIDは、行動のリテラルと定義の値から解決する。
		var values := var_to_str(definition.params)
		for candidate in known:
			var token := '"' + String(candidate) + '"'
			if not ids.has(String(candidate)) and (text.contains(token) or values.contains(token)):
				ids[String(candidate)] = true
				pending.append(String(candidate))
		var skin := stage.enemy_sprite_path(StringName(id)).get_file().get_basename()
		var look := "res://data/visuals/looks/%s.tres" % skin
		if not ResourceLoader.exists(look): look = "res://data/visuals/looks/%s.tres" % id
		_add(paths, look)
		_add(paths, stage.enemy_sprite_path(StringName(id)))
	for entry: ContentEntry in catalog.table(&"weapons").values():
		if entry.comet_only:
			for path in entry.resources: _add(paths, path)
	var legendary := catalog.find(&"legendary_modules", stage.legendary_module_id)
	if legendary != null: _add(paths, legendary.path)
	var boss := catalog.find(&"bosses", stage.boss_id)
	if boss != null:
		_add(paths, boss.path)
		var definition := load(boss.path) as BossDef
		_add(paths, definition.scene_path)
	for common in ["res://.content/audio.res", "res://scenes/run/run.tscn", "res://scripts/render/render_pipeline.gd", "res://scripts/render/gpu_sparks.gd", "res://scripts/render/ship_visual.gd", "res://scripts/render/body_visual.gd", "res://scripts/render/meteor_visual.gd", "res://assets/pixel/planet.png", "res://assets/pixel/moon.png", "res://shaders/pixel_sprite.gdshader", "res://shaders/xp_crystal.gdshader"]: _script(paths, common) if common.ends_with(".gd") else _add(paths, common)
	result.paths = PackedStringArray(paths.keys())
	result.paths.sort()
	for path in result.paths:
		if path.ends_with(".gdshader"): result.shader_paths.append(path)
	result.enemy_ids = PackedStringArray(ids.keys())
	result.enemy_ids.sort()
	return result
