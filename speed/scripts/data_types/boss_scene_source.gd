## ボス制作シーンの表示設定。ランの状態と行動はC++が持つ。
@tool
extends Node2D
@export var presentation_scene: PackedScene
@export var body_texture: Texture2D
@export var neck_texture: Texture2D
@export var compass_texture: Texture2D
@export var head_textures: Dictionary = {}
@export_range(1.0,32.0) var neck_spacing_pixels := 14.0
@export var energy_shader: Shader = preload("res://shaders/hydra_energy.gdshader")
@export var tornado_scene: PackedScene = preload("res://scenes/bosses/hydra_tornado.tscn")
@export_range(0.0,1.0) var compass_spin_fraction := 0.5
