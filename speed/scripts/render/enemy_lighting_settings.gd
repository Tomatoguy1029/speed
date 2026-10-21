## 敵装甲の照明。実験場の外観パネルとGodotのインスペクターで調整する。
extends Resource

@export_range(0.0, 3.0, 0.01) var key_energy := 0.55
@export_range(0.0, 3.0, 0.01) var fill_energy := 0.12
@export_range(-180.0, 180.0, 1.0) var key_angle := -45.0
@export_range(-180.0, 180.0, 1.0) var fill_angle := 135.0
@export_range(0.0, 1.0, 0.01) var height := 0.25
@export_range(0.0, 1.0, 0.01) var ambient := 0.08
@export_range(0.0, 3.0, 0.05) var normal_strength := 1.0
