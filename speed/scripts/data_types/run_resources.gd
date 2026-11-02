## Godot側だけが解決する、生成済みの資源キーとパス。
extends Resource
@export var input_sha256 := ""
@export var paths := PackedStringArray()
@export var keys: Dictionary = {}
@export var visuals: Array[Dictionary] = []

@export var dependencies: Dictionary = {}
@export var equipment: Dictionary = {}
@export var order := PackedStringArray()
@export var signatures: Dictionary = {}

@export var background_color := Color.BLACK
@export var backgrounds: Array[BackgroundPlacement] = []
@export var fire_uses: Dictionary = {}
