## 粒子の密度場から形を作る共通ピクセル炎の調整値。
@tool
class_name PixelFireSettings
extends Resource

enum EmissionShape { POINT, LINE, BOX }
@export_group("粒子")
@export var emission_shape := EmissionShape.LINE:
	set(value):
		value = clampi(value, 0, 2)
		if emission_shape != value:
			emission_shape = value
			emit_changed()
@export var source_size := Vector2(52, 6):
	set(value):
		value = value.clamp(Vector2.ZERO, Vector2(1024, 1024))
		if source_size != value:
			source_size = value
			emit_changed()
@export_range(1, 160, 1) var birth_rate := 28.0:
	set(value):
		value = clampf(value, 1.0, 160.0)
		if birth_rate != value:
			birth_rate = value
			emit_changed()
@export_range(0.1, 2.5, 0.05) var lifetime := 1.1:
	set(value):
		value = clampf(value, 0.1, 2.5)
		if lifetime != value:
			lifetime = value
			emit_changed()
@export_range(20, 240, 5) var rise_speed := 108.0:
	set(value):
		value = clampf(value, 20.0, 240.0)
		if rise_speed != value:
			rise_speed = value
			emit_changed()
@export_range(0, 80, 1) var sway := 24.0:
	set(value):
		value = clampf(value, 0.0, 80.0)
		if sway != value:
			sway = value
			emit_changed()
@export_range(8, 50, 1) var particle_size := 27.0:
	set(value):
		value = clampf(value, 8.0, 50.0)
		if particle_size != value:
			particle_size = value
			emit_changed()
@export_range(32, 384, 1) var capacity := 192:
	set(value):
		value = clampi(value, 32, 384)
		if capacity != value:
			capacity = value
			emit_changed()
@export_group("外炎・内炎・芯")
@export var layer_rates := Vector3(1.0, 0.85, 0.7):
	set(value):
		value = value.clamp(Vector3.ZERO, Vector3.ONE * 4.0)
		if layer_rates != value:
			layer_rates = value
			emit_changed()
@export var layer_lifetimes := Vector3(1.0, 0.62, 0.3):
	set(value):
		value = value.clamp(Vector3.ZERO, Vector3.ONE * 4.0)
		if layer_lifetimes != value:
			layer_lifetimes = value
			emit_changed()
@export var layer_sizes := Vector3(1.0, 0.7, 0.44):
	set(value):
		value = value.clamp(Vector3.ZERO, Vector3.ONE * 4.0)
		if layer_sizes != value:
			layer_sizes = value
			emit_changed()
@export var outer_color := Color("#e95624"):
	set(value):
		if outer_color != value:
			outer_color = value
			emit_changed()
@export var inner_color := Color("#ffbc40"):
	set(value):
		if inner_color != value:
			inner_color = value
			emit_changed()
@export var core_color := Color("#ffe9a0"):
	set(value):
		if core_color != value:
			core_color = value
			emit_changed()
@export_group("密度場と輪郭")
@export var field_size := Vector2(220, 280):
	set(value):
		value = value.clamp(Vector2(32, 64), Vector2(1024, 1024))
		if field_size != value:
			field_size = value
			emit_changed()
@export_range(1, 4, 0.5) var density_pixel_size := 2.0:
	set(value):
		value = clampf(value, 1.0, 4.0)
		if density_pixel_size != value:
			density_pixel_size = value
			emit_changed()
@export_range(0.05, 0.9, 0.01) var merge_threshold := 0.32:
	set(value):
		value = clampf(value, 0.05, 0.9)
		if merge_threshold != value:
			merge_threshold = value
			emit_changed()
@export_range(0.01, 0.2, 0.01) var edge_softness := 0.04:
	set(value):
		value = clampf(value, 0.01, 0.2)
		if edge_softness != value:
			edge_softness = value
			emit_changed()
@export_range(0, 12, 0.5) var deformation := 4.5:
	set(value):
		value = clampf(value, 0.0, 12.0)
		if deformation != value:
			deformation = value
			emit_changed()
@export_range(1, 8, 1) var pixel_size := 4.0:
	set(value):
		value = clampf(value, 1.0, 8.0)
		if pixel_size != value:
			pixel_size = value
			emit_changed()
@export_range(6, 60, 1) var update_fps := 12.0:
	set(value):
		value = clampf(value, 6.0, 60.0)
		if update_fps != value:
			update_fps = value
			emit_changed()
@export_group("完成した炎の発光")
@export_range(0, 0.7, 0.01) var glow_strength := 0.16:
	set(value):
		value = clampf(value, 0.0, 0.7)
		if glow_strength != value:
			glow_strength = value
			emit_changed()
@export_range(1, 18, 1) var glow_radius := 7.0:
	set(value):
		value = clampf(value, 1.0, 18.0)
		if glow_radius != value:
			glow_radius = value
			emit_changed()
