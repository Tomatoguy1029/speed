## 雷の予告と放電は、実際の円形当たり判定の内側に収める。
extends "res://scripts/render/attacks/zone_reticle.gd"
@export_range(0.0, 0.5, 0.01) var glow_opacity := 0.16
@export_range(0.0, 1.0, 0.05) var ring_opacity := 0.75
@export_range(0.5, 8.0, 0.25) var ring_width := 3.0
@export_range(2, 12, 1) var arm_count := 5
@export_range(0.1, 0.8, 0.05) var lightning_reach := 0.65
@export_range(0.5, 6.0, 0.25) var lightning_width := 2.0

func _apply_effect_settings() -> void:
	super()
	EFFECT_SETTINGS.apply_key(self, "enemy/aquila", scene_file_path)
	effect_tint = EFFECT_SETTINGS.resolved_values("enemy/aquila", scene_file_path).get("effect_tint", Color.WHITE)
