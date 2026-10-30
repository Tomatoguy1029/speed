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
		"color": [definition.color.r, definition.color.g, definition.color.b, definition.color.a],
		"xp": definition.xp, "knockback": definition.knockback_scale(config),
		"hitstop_multiplier": definition.hitstop_multiplier}
	for key in ["hp", "armor", "radius", "speed", "fire_interval", "xp", "knockback", "hitstop_multiplier"]:
		if not is_finite(float(row[key])) or float(row[key]) < 0.0:
			return {}
	if row.id.is_empty() or row.hp <= 0.0 or row.radius <= 0.0:
		return {}
	return {"version": 2, "enemies": [row]}

## 共通生成から使う比較条件。未移行の通常ゲーム用データと混同しない。
static func build_probe(path: String) -> Error:
	var definition := load("res://data/enemies/drifter.tres") as EnemyDef
	var config := load("res://data/config.tres") as GameConfig
	var data := compile_enemy(definition, config)
	if data.is_empty(): return ERR_INVALID_DATA
	data["visual_scale"] = 1.0 / definition.visual_value("collision_scale", 1.0)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK: return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "", true, true))
	error = file.get_error()
	file.close()
	return error
