## 配布用コピーだけに、実行時生成するCanvas shaderの事前変換対象を保存する。
extends SceneTree
const OUTPUT := "res://shader_bake_targets.tres"
var _excluded := PackedStringArray()
var _paths := PackedStringArray()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_fail("export preset名を1つ指定してください")
		return
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		_fail("export presetを読み込めません")
		return
	var found := false
	for section in presets.get_sections():
		if presets.get_value(section, "name", "") != args[0]: continue
		_excluded = String(presets.get_value(section, "exclude_filter", "")).split(",", false)
		found = true
		break
	if not found or not _collect("res://"):
		_fail("presetまたはCanvas shaderの読み込みに失敗しました")
		return
	# headlessではGPU素材を作らず、描画付きexportが読む静的資源を保存する。
	_paths.sort()
	var lines := PackedStringArray(['[gd_resource type="Resource" format=3]', ""])
	var references := PackedStringArray()
	for i in _paths.size():
		lines.append('[ext_resource type="Shader" path=%s id="shader_%d"]' % [JSON.stringify(_paths[i]), i])
	for i in _paths.size():
		lines.append('\n[sub_resource type="ShaderMaterial" id="material_%d"]\nshader = ExtResource("shader_%d")' % [i, i])
		references.append('SubResource("material_%d")' % i)
	# CanvasItemMaterialと同じコードで、標準mix・add・unshadedの変種も含める。
	for mode in ["blend_mix", "blend_add", "blend_mix, unshaded"]:
		var i := references.size()
		var code := "shader_type canvas_item;\nrender_mode %s;\n" % mode
		lines.append('\n[sub_resource type="Shader" id="builtin_%d"]\ncode = %s' % [i, JSON.stringify(code)])
		lines.append('\n[sub_resource type="ShaderMaterial" id="material_%d"]\nshader = SubResource("builtin_%d")' % [i, i])
		references.append('SubResource("material_%d")' % i)
	lines.append('\n[resource]\nmetadata/materials = Array[ShaderMaterial]([%s])\n' % ", ".join(references))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		_fail("ベイク対象を保存できません: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string("\n".join(lines))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		_fail("ベイク対象を書き込めません: %s" % error_string(error))
		return
	print("[shader_bake_targets] %d materials: %s" % [references.size(), OUTPUT])
	quit()

func _collect(directory: String) -> bool:
	var dir := DirAccess.open(directory)
	if dir == null: return false
	for name in dir.get_files():
		var path := directory.path_join(name)
		if not name.ends_with(".gdshader") or _is_excluded(path): continue
		var shader := load(path) as Shader
		if shader == null: return false
		if shader.get_mode() == Shader.MODE_CANVAS_ITEM: _paths.append(path)
	for name in dir.get_directories():
		if name.begins_with("."): continue
		var path := directory.path_join(name)
		if not _is_excluded(path + "/") and not _collect(path): return false
	return true

func _is_excluded(path: String) -> bool:
	for pattern in _excluded:
		if path.trim_prefix("res://").match(pattern.strip_edges()): return true
	return false

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
