## Godot側だけが解決する、生成済みの資源キーとパス。
extends Resource
@export var input_sha256 := ""
@export var paths := PackedStringArray()
@export var keys: Dictionary = {}
