## 比較で対応する追跡敵の固定値を、編集元と本番の倍率から生成する。
@tool
extends RefCounted

static func compile_enemy(definition: EnemyDef, config: GameConfig) -> Dictionary:
	if definition == null or config == null or definition.behavior != &"chase":
		return {}
	var radius := definition.radius * config.character_scale
	radius *= definition.visual_value("scale", 1.0) * definition.visual_value("collision_scale", 1.0)
	var row := {"id": String(definition.id), "behavior": String(definition.behavior),
		"hp": definition.base_hp(config) * config.enemy_hp_mult,
		"armor": definition.armor * config.enemy_armor_mult, "radius": radius,
		"speed": definition.speed, "fire_interval": float(definition.params.get("fire_interval", 0.0)),
		"color": [definition.color.r, definition.color.g, definition.color.b, definition.color.a]}
	for key in ["hp", "armor", "radius", "speed", "fire_interval"]:
		if not is_finite(float(row[key])) or float(row[key]) < 0.0:
			return {}
	if row.id.is_empty() or row.hp <= 0.0 or row.radius <= 0.0:
		return {}
	return {"version": 1, "enemies": [row]}
