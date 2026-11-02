## 参照の探索と署名は生成時に行い、出撃へはパスだけの一覧を渡す。
@tool
extends RefCounted
const VIEW := "res://scenes/run/run.tscn"
const PROFILE_PATHS := ["res://data/visuals/burst_runtime.tres","res://data/visuals/pump_shell_runtime.tres",
	"res://data/visuals/elite_runtime.tres","res://assets/effects/build/burst_noise.tres",
	"res://assets/effects/landmark/masks.tres","res://data/visuals/biter_parts.tres"]

static func _constant_paths(value: Variant, paths: PackedStringArray) -> void:
	if value is Resource:
		var path: String = value.resource_path.split("::")[0]
		if path.begins_with("res://") and not path in paths: paths.append(path)
	elif value is Dictionary:
		for child in value.values(): _constant_paths(child,paths)
	elif value is Array:
		for child in value: _constant_paths(child,paths)

static func _dependencies(path: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for dependency in ResourceLoader.get_dependencies(path):
		var target: String = dependency.split("::")[-1]
		if target.begins_with("uid://"):
			var id := ResourceUID.text_to_id(target)
			if ResourceUID.has_id(id): target = ResourceUID.get_id_path(id)
		if not target in paths: paths.append(target)
	if path.ends_with(".gd"):
		var script := load(path) as Script
		if script!=null: _constant_paths(script.get_script_constant_map(),paths)
	return paths

static func _visit(path: String, hashes: Dictionary, pending: Dictionary) -> bool:
	if hashes.has(path): return true
	if not path.begins_with("res://") or path.contains("..") or not FileAccess.file_exists(path): return false
	if pending.has(path): return true
	pending[path] = true
	hashes[path] = FileAccess.get_sha256(path)
	if hashes[path].is_empty(): return false
	if ResourceLoader.exists(path):
		for target in _dependencies(path):
			if not _visit(target,hashes,pending): return false
	for companion in [path+".import",path.get_basename()+".regions.json"]:
		if FileAccess.file_exists(companion) and not _visit(companion,hashes,pending): return false
	pending.erase(path)
	return true

static func _folder(directory: String, hashes: Dictionary) -> bool:
	for name in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		if name.ends_with(".regions.json") or name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):
			if not _visit(path,hashes,{}): return false
	for name in DirAccess.get_directories_at(directory):
		if not name.begins_with(".") and not _folder(directory.path_join(name),hashes): return false
	return true

static func _ordered(path: String, seen: Dictionary, paths: PackedStringArray) -> void:
	if seen.has(path) or not ResourceLoader.exists(path): return
	seen[path] = true
	for target in _dependencies(path): _ordered(target,seen,paths)
	paths.append(path)

static func collect(startup: PackedStringArray, visuals: Array, catalog: ContentCatalog, previous_keys := {}) -> Dictionary:
	var hashes := {}
	var startup_paths := {}
	for path in startup:
		if not _visit(path,hashes,{}): return {}
		startup_paths[path] = true
	# 画面の静的preloadも、この生成済みの依存一覧へ展開する。
	for path in [VIEW,"res://scripts/render/run_frame_view.gd","res://assets/pixel/xp_crystal_facets.tres",
		"res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]:
		var dependencies := {}
		if not _visit(path,dependencies,{}): return {}
		for key in dependencies:
			hashes[key] = dependencies[key]
			if ResourceLoader.exists(key): startup_paths[key] = true
	var keys: Dictionary = previous_keys.duplicate()
	var by_path := {}
	for id: int in keys: by_path[keys[id]] = id
	for visual: Dictionary in visuals:
		if not visual.path.is_empty():
			keys[visual.id] = visual.path
			by_path[visual.path] = visual.id
	var next_key := 1
	for id: int in keys: next_key = maxi(next_key,id+1)
	var equipment := {}
	for category in [&"weapons",&"traits"]:
		for entry: ContentEntry in catalog.table(category).values():
			var assets := PackedInt32Array()
			for path in entry.resources:
				if not _visit(path,hashes,{}): return {}
				if not by_path.has(path):
					by_path[path] = next_key
					keys[next_key] = path
					next_key += 1
				assets.append(by_path[path])
			equipment[("weapon:" if category==&"weapons" else "trait:")+String(entry.id)] = assets
	# 全固定外観を追跡し、表示が戦闘へ効く画像・領域・importも署名に含める。
	for name in DirAccess.get_files_at("res://data/visuals/looks"):
		if name.ends_with(".tres") and not _visit("res://data/visuals/looks/"+name,hashes,{}): return {}
	for path in ["res://assets/pixel/saw.png","res://assets/pixel/monoceros/horn/horn.tres"]:
		if not _visit(path,hashes,{}): return {}
	for profile_path in PROFILE_PATHS:
		if not _visit(profile_path,hashes,{}): return {}
		var profile := load(profile_path) as Resource
		if profile==null: return {}
		for group in ["inputs","outputs"]:
			for path: String in profile.get_meta(group,{}):
				if not _visit(path,hashes,{}): return {}
	if not _folder("res://tools/content",hashes) or not _folder("res://shaders",hashes): return {}
	for path in ["res://tools/art/bake_burst_noise.py","res://tools/art/bake_burst_profiles.py","res://tools/art/bake_pump_shell.py",
		"res://tools/art/bake_landmark_masks.py","res://tools/art/bake_elite_crackle.py","res://scripts/ui/speed_indicator.gd"]:
		if not _visit(path,hashes,{}): return {}
	# 元のstage.pathsも、複合資源より先に画像を取得できる形へ展開する。
	for path in startup:
		var dependencies := {}
		if not _visit(path,dependencies,{}): return {}
		for key in dependencies:
			if ResourceLoader.exists(key): startup_paths[key] = true
	var paths := PackedStringArray(startup_paths.keys())
	paths.sort()
	var order := PackedStringArray()
	var seen := {}
	for path in paths: _ordered(path,seen,order)
	var startup_order := order.duplicate()
	for path: String in keys.values(): _ordered(path,seen,order)
	var signatures := {}
	for path in order:
		var closure := {}
		if not _visit(path,closure,{}): return {}
		var names := closure.keys()
		names.sort()
		var lines := PackedStringArray()
		for name: String in names: lines.append(name+":"+str(closure[name]))
		signatures[path] = "\n".join(lines).sha256_text()
	return {"paths":startup_order,"hashes":hashes,"keys":keys,"equipment":equipment,"order":order,"signatures":signatures}
