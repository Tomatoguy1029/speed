## 画面と資源の検索に使う、小さな定義の索引。画像はパスだけを保存する。
class_name ContentEntry
extends Resource
@export var id: StringName
@export var index := 0
@export var category: StringName
@export var path := ""
@export var text_prefix := ""
@export var code_id: StringName
@export var order := 0
@export var icon_path := ""
@export var preview_path := ""
@export var params: Dictionary = {}
@export var costs := PackedInt32Array()
@export var stat: StringName
@export var per_level := 0.0
@export var comet_only := false
var preview_texture: Texture2D:
	get: return load(preview_path) if not preview_path.is_empty() else null
var icon_texture: Texture2D:
	get: return load(icon_path) if not icon_path.is_empty() else null
func get_display_name() -> String:
	return tr("%s.%s.name" % [text_prefix, str(index) if category == &"stages" else String(id)])
func get_description() -> String:
	return tr("%s.%s.desc" % [text_prefix, String(id)])
