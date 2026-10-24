## ほうおう座の炎と火の粉の見た目。ゲームの攻撃範囲・威力とは独立して調整する。
extends Resource

@export var ember_color := Color("#b82f19")
@export var flame_color := Color("#f77924")
@export var hot_color := Color("#ffda70")
@export var smoke_color := Color("#422c35")
@export_range(0.2, 1.4, 0.05) var amount := 0.85
@export_range(0.1, 3.0, 0.05) var speed := 1.0
@export_range(1.0, 8.0, 0.5) var pixel_size := 3.0
@export_range(0.0, 2.0, 0.05) var turbulence := 1.0
@export_range(0.0, 1.0, 0.05) var sparks := 0.45
@export_range(0.0, 1.0, 0.05) var opacity := 0.85
@export_range(0.0, 2.0, 0.05) var emission := 0.65
## 炎の舌を縦へ伸ばす比率と、消える間に上へ持ち上げる量（炎半径に対する比）。
@export_range(1.0, 4.0, 0.1) var stretch := 2.6
@export_range(0.0, 0.3, 0.01) var lift := 0.24

func apply(material: ShaderMaterial) -> void:
	for key in ["ember_color", "flame_color", "hot_color", "smoke_color", "amount", "speed", "pixel_size", "turbulence", "sparks", "opacity", "emission", "stretch", "lift"]:
		material.set_shader_parameter(key, get(key))
