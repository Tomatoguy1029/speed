@tool
extends Resource
@export var adapter: StringName = &""
@export_file("*.tscn") var trial_scene := ""
@export var techniques: Array[Resource] = []
@export var conditions: Dictionary = {}
@export var forbidden: Array = []
@export var combos: Dictionary = {}
@export var costs: Dictionary = {}
@export var layout: Dictionary = {}
