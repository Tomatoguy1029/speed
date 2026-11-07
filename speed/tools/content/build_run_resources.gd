## 参照の探索と署名は生成時に行い、出撃へはパスだけの一覧を渡す。
@tool
extends RefCounted
const VIEW := "res://scenes/run/run.tscn"
const PROFILE_PATHS := ["res://data/visuals/burst_runtime.tres","res://data/visuals/pump_shell_runtime.tres",
	"res://data/visuals/elite_runtime.tres","res://assets/effects/build/burst_noise.tres",
	"res://assets/effects/elite_death/masks.tres","res://assets/effects/landmark/masks.tres","res://assets/effects/landmark/elite_contacts.tres","res://data/visuals/landmark_aura_material.tres","res://data/visuals/biter_parts.tres"]

## 一度の共通生成の間だけ共有する。次のF5やライブ編集へ古い署名を持ち越さない。
static var _batch_active := false
static var _batch_hashes := {}
static var _batch_dependencies := {}
static var _batch_signatures := {}
static var _batch_tables := {}
static var _batch_held: Array[Resource] = []
static func begin_batch() -> void:
	end_batch()
	_batch_active = true
static func end_batch() -> void:
	_batch_active = false
	_batch_hashes.clear()
	_batch_dependencies.clear()
	_batch_signatures.clear()
	_batch_tables.clear()
	_batch_held.clear()

## load()の保持はResourceの参照が切れると失われるので、定義を読み直さないよう一括生成の間だけ握る。
static func hold_definitions() -> void:
	if not _batch_active: return
	var catalog := load("res://data/content_catalog.tres") as ContentCatalog
	_batch_held.append(catalog)
	for category: StringName in [&"enemies",&"bosses",&"heroes",&"weapons",&"traits"]:
		for entry: ContentEntry in catalog.table(category).values(): _batch_held.append(load(entry.path))
	for name in DirAccess.get_files_at("res://scenes/attacks"):
		if name.ends_with(".tscn"): _batch_held.append(load("res://scenes/attacks/"+name))

## 一括生成の間だけ、同じ入力から作る固定表を使い回す。
static func batch_tables(key: String, make: Callable) -> Dictionary:
	if not _batch_active: return make.call()
	if not _batch_tables.has(key): _batch_tables[key] = make.call()
	return _batch_tables[key]

static func _constant_paths(value: Variant, paths: PackedStringArray) -> void:
	if value is Resource:
		var path: String = value.resource_path.split("::")[0]
		if path.begins_with("res://") and not path in paths: paths.append(path)
	elif value is Dictionary:
		for child in value.values(): _constant_paths(child,paths)
	elif value is Array:
		for child in value: _constant_paths(child,paths)

static func _dependencies(path: String) -> PackedStringArray:
	if _batch_active and _batch_dependencies.has(path): return _batch_dependencies[path]
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
	if _batch_active: _batch_dependencies[path] = paths
	return paths

static var _file_memo := {}
static var _file_memo_path := ""
static var _file_memo_dirty := false
## 実験場の作り直しでは、更新時刻が同じファイルの計算結果を使い回す。
static func use_file_memo(path: String) -> void:
	_file_memo_path = path
	if _file_memo.is_empty() and FileAccess.file_exists(path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if saved is Dictionary: _file_memo = saved

static func save_file_memo() -> void:
	if _file_memo_dirty:
		var file := FileAccess.open(_file_memo_path,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(_file_memo))
	_file_memo_dirty = false
	_file_memo_path = ""

static func _visit(path: String, hashes: Dictionary, pending: Dictionary) -> bool:
	if hashes.has(path): return true
	if not path.begins_with("res://") or path.contains("..") or not FileAccess.file_exists(path): return false
	if pending.has(path): return true
	pending[path] = true
	var stamp := float(FileAccess.get_modified_time(path))
	var known: Array = _file_memo.get(path,[]) if _file_memo_path!="" else []
	var fresh: bool = not known.is_empty() and float(known[0])==stamp
	if fresh: hashes[path] = known[1]
	else: hashes[path] = _batch_hashes[path] if _batch_active and _batch_hashes.has(path) else FileAccess.get_sha256(path)
	if _batch_active: _batch_hashes[path] = hashes[path]
	if hashes[path].is_empty(): return false
	var dependencies: Array = known[2] if fresh else Array(_dependencies(path)) if ResourceLoader.exists(path) else []
	if _file_memo_path!="" and not fresh:
		_file_memo[path] = [stamp,hashes[path],dependencies]
		_file_memo_dirty = true
	for target in dependencies:
		if not _visit(target,hashes,pending): return false
	for companion in [path+".import",path.get_basename()+".regions.json"]:
		if FileAccess.file_exists(companion) and not _visit(companion,hashes,pending): return false
	pending.erase(path)
	return true

static func _folder(directory: String, hashes: Dictionary) -> bool:
	for name in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		if not preload("res://addons/content_build/inputs.gd").affects_stage(path): continue
		if name.ends_with(".regions.json") or name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):
			if not _visit(path,hashes,{}): return false
	for name in DirAccess.get_directories_at(directory):
		if not name.begins_with(".") and not _folder(directory.path_join(name),hashes): return false
	return true

static func _runtime_resource(path: String) -> bool:
	# 領域の編集元とimport設定は署名だけに使い、出撃では読み込まない。
	return not path.ends_with(".regions.json") and not path.ends_with(".import") and ResourceLoader.exists(path)

static func _ordered(path: String, seen: Dictionary, paths: PackedStringArray) -> void:
	if seen.has(path) or not _runtime_resource(path): return
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
		"res://assets/effects/elite_death/masks.tres","res://assets/effects/landmark/masks.tres","res://data/visuals/landmark_aura_material.tres",
		"res://assets/effects/landmark/elite_contacts.tres","res://data/visuals/elite_runtime.tres",
		"res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]:
		var dependencies := {}
		if not _visit(path,dependencies,{}): return {}
		for key in dependencies:
			hashes[key] = dependencies[key]
			if _runtime_resource(key): startup_paths[key] = true
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
			if _runtime_resource(key): startup_paths[key] = true
	var paths := PackedStringArray(startup_paths.keys())
	paths.sort()
	var order := PackedStringArray()
	var seen := {}
	for path in paths: _ordered(path,seen,order)
	var startup_order := order.duplicate()
	for path: String in keys.values(): _ordered(path,seen,order)
	var signatures := {}
	for path in order:
		if _batch_active and _batch_signatures.has(path):
			signatures[path] = _batch_signatures[path]
			continue
		var closure := {}
		if not _visit(path,closure,{}): return {}
		var names := closure.keys()
		names.sort()
		var lines := PackedStringArray()
		for name: String in names: lines.append(name+":"+str(closure[name]))
		signatures[path] = "\n".join(lines).sha256_text()
		if _batch_active: _batch_signatures[path] = signatures[path]
	return {"paths":startup_order,"hashes":hashes,"keys":keys,"equipment":equipment,"order":order,"signatures":signatures}
