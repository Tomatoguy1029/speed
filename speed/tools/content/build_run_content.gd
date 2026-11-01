## Resourceの実効値を解決し、共通スキーマの書込へ渡す。
extends RefCounted
const Schema = preload("res://tools/content/generated/run_schema.gd")
const Legacy = preload("res://tools/content/build_native_data.gd")

static func chase_records(definition: EnemyDef, config: GameConfig) -> Dictionary:
	if definition == null or definition.behavior != &"chase": return {}
	var resolved := Legacy.compile_enemy(definition,config)
	if resolved.is_empty(): return {}
	var source: Dictionary = resolved.enemies[0]
	var row := {"id":1}
	for key in ["hp","armor","radius","speed","fire_interval","xp","knockback","hitstop_multiplier"]:
		row[key] = source[key]
	for pair in [["attack_value","value"],["attack_priority","priority"],["attack_weight","weight"],["telegraph","telegraph"],["attack_managed","managed"]]:
		row[pair[0]] = source.attack[pair[1]]
	row.rank = source.spawn.rank
	row.size_var = source.spawn.size_var
	for pair in [["r",0],["g",1],["b",2],["a",3]]:
		row["color_"+pair[0]] = source.color[pair[1]]
	for key in ["radius","hp","armor","hp_mult","armor_mult","character","visual","collision"]:
		row["scaling_"+key] = source.scaling[key]
	row.fixed_sprite = source.scaling.fixed_sprite
	var data := {}
	for record in Schema.SCHEMA.records: data[record.name] = []
	data.RunConfig = [{"id":1,"aim_lag":resolved.motion.aim_lag,"aim_speed":resolved.motion.aim_speed}]
	data.StringEntry = [{"id":1,"value":String(definition.id)}]
	data.DefinitionIndex = [{"id":1,"enemy":1}]
	data.ChaseDefinition = [row]
	return data

static func compile_chase(definition: EnemyDef, config: GameConfig, input_sha256: PackedByteArray) -> PackedByteArray:
	return Schema.write_content(chase_records(definition,config),input_sha256)
