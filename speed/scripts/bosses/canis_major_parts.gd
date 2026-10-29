## 確定済みの法線画像を共通照明へ接続する。左右の脚は法線のX方向も反転する。
extends Node2D
const LIGHTING = preload("res://data/visuals/enemy_lighting.tres")
func _ready() -> void:
	for part in get_children():
		var sprite := part.get_node("Sprite") as Sprite2D
		sprite.material = sprite.material.duplicate()
		var lighting := sprite.material as ShaderMaterial
		lighting.set_shader_parameter("normal_flip_x", sprite.flip_h)
		for field in ["ambient", "normal_strength", "key_energy", "fill_energy"]:
			lighting.set_shader_parameter(field, LIGHTING.get(field))
		for entry in [["key_direction", LIGHTING.key_angle], ["fill_direction", LIGHTING.fill_angle]]:
			var direction := Vector2.from_angle(deg_to_rad(float(entry[1])))
			lighting.set_shader_parameter(entry[0], Vector3(direction.x, direction.y, LIGHTING.height).normalized())
