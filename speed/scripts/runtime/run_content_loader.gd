## 出撃では保存済みの索引と生成物だけを読む。生成器は呼ばない。
extends RefCounted
const ResourceList = preload("res://scripts/data_types/run_resources.gd")

static func read_bundle(index_path: String, expected_input: String) -> Dictionary:
	if expected_input.length()!=64 or not FileAccess.file_exists(index_path): return {}
	var index = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not index is Dictionary or index.get("input_sha256","")!=expected_input or index.get("format",0)!=1: return {}
	var root := index_path.get_base_dir()+"/"
	for key in ["binary","resources"]:
		if not index.get(key,"") is String or not index[key].begins_with(root) or "/../" in index[key] or not FileAccess.file_exists(index[key]): return {}
	var bytes := FileAccess.get_file_as_bytes(index.binary)
	if bytes.size()<88 or bytes.slice(24,56).hex_encode()!=expected_input or bytes.slice(56,88).hex_encode()!=index.get("payload_sha256",""): return {}
	if FileAccess.get_sha256(index.resources)!=index.get("resources_sha256",""): return {}
	var resources = ResourceLoader.load(index.resources,"",ResourceLoader.CACHE_MODE_IGNORE)
	if resources == null or resources.get_script()!=ResourceList or resources.input_sha256!=expected_input: return {}
	if resources.dependencies.is_empty(): return {}
	for path in resources.dependencies:
		if not path is String or not resources.dependencies[path] is String: return {}
		if OS.has_feature("editor") and FileAccess.get_sha256(path)!=resources.dependencies[path]: return {}
	for key in resources.keys:
		if not key is int or key<=0 or not resources.keys[key] is String or not ResourceLoader.exists(resources.keys[key]): return {}
		if not resources.keys[key] in resources.order or not resources.signatures.has(resources.keys[key]): return {}
	for path in resources.paths:
		if not path in resources.order or not resources.signatures.has(path) or not ResourceLoader.exists(path): return {}
	return {"bytes":bytes,"resources":resources,"index":index}
