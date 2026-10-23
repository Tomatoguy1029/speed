## ステージが使う資源のパス。実体は利用するセッションのScopeが保持する。
class_name StageResources
extends Resource
@export var paths := PackedStringArray()
@export var enemy_ids := PackedStringArray()

## ロード中にmaterialを作って描くshader。
@export var shader_paths := PackedStringArray()
