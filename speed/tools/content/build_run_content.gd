## Resourceの実効値を解決し、共通スキーマの書込へ渡す。
extends RefCounted
const Schema = preload("res://tools/content/generated/run_schema.gd")
const Legacy = preload("res://tools/content/build_native_data.gd")

static func chase_records(definition: EnemyDef, config: GameConfig, stage: RuntimeStage = null) -> Dictionary:
	if definition == null or definition.behavior != &"chase": return {}
	var resolved := Legacy.compile_enemy(definition,config,stage)
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
	var reward := definition.resolve_xp_reward()
	if reward.is_empty() or config.xp_crystal_values.size()!=3: return {}
	for i in range(3): row[["reward_low","reward_mid","reward_high"][i]] = int(reward.counts[i])
	row.gold_eligible = reward.gold_eligible
	var data := {}
	for record in Schema.SCHEMA.records: data[record.name] = []
	data.RunConfig = [{"id":1,"aim_lag":resolved.motion.aim_lag,"aim_speed":resolved.motion.aim_speed,"crystal_low":config.xp_crystal_values[0],"crystal_mid":config.xp_crystal_values[1],"crystal_high":config.xp_crystal_values[2]}]
	for field in Schema.SCHEMA.records[0].fields:
		if field.has("config"): data.RunConfig[0][field.name] = config.get(field.config)
		elif field.has("value"): data.RunConfig[0][field.name] = field.value
	data.StringEntry = [{"id":1,"value":String(definition.id)}]
	data.DefinitionIndex = [{"id":1,"enemy":1}]
	data.ChaseDefinition = [row]
	return data

static func compile_chase(definition: EnemyDef, config: GameConfig, input_sha256: PackedByteArray) -> PackedByteArray:
	return Schema.write_content(chase_records(definition,config),input_sha256)

## 同じRuntimeStageから生成し、検査済みの版へ索引を最後に切り替える。
static func build(stage: RuntimeStage, config: GameConfig, output: String, input_sha256: String, definitions := {}) -> Error:
	if stage == null or stage.resources == null or input_sha256.length()!=64: return ERR_INVALID_DATA
	var data := {}
	for record in Schema.SCHEMA.records: data[record.name] = []
	for i in stage.resources.enemy_ids.size():
		var id: String = stage.resources.enemy_ids[i]
		var definition: EnemyDef = definitions.get(StringName(id))
		if definition == null:
			definition = ResourceLoader.load("res://data/enemies/%s.tres" % id,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyDef
		if definition == null or String(definition.id)!=id: return ERR_INVALID_DATA
		var tuning: Dictionary = stage.enemy_tuning.get(id,{})
		if not StageEnemyTuning.error_for(definition,tuning).is_empty(): return ERR_INVALID_DATA
		definition = StageEnemyTuning.resolve(definition,tuning)
		var resolved := chase_records(definition,config,stage)
		if resolved.is_empty(): return ERR_UNAVAILABLE
		var row: Dictionary = resolved.ChaseDefinition[0]
		row.id = i+1
		data.ChaseDefinition.append(row)
		data.StringEntry.append({"id":i+1,"value":id})
		data.DefinitionIndex.append({"id":i+1,"enemy":i+1})
		data.RunConfig = resolved.RunConfig
	if data.RunConfig.is_empty(): return ERR_INVALID_DATA
	var source_sha256 := input_sha256
	var paths := stage.resources.paths.duplicate()
	paths.sort()
	var resolved_input := source_sha256.to_utf8_buffer()
	resolved_input.append_array(Schema.write_content(data,PackedByteArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])))
	resolved_input.append_array("\n".join(paths).to_utf8_buffer())
	input_sha256 = Schema.sha256(resolved_input).hex_encode()
	var bytes := Schema.write_content(data,input_sha256.hex_decode())
	if bytes.is_empty() or not ClassDB.class_exists(&"SpeedRunCore"): return ERR_INVALID_DATA
	var validator = ClassDB.instantiate(&"SpeedRunCore")
	if not validator.configure_content(bytes): return ERR_INVALID_DATA
	validator.close()
	var directory := output.path_join(input_sha256+"_"+bytes.slice(56,88).hex_encode())
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error!=OK: return error
	var binary_path := directory.path_join("content.bin")
	var resources_path := directory.path_join("run_resources.tres")
	if not FileAccess.file_exists(binary_path):
		var file := FileAccess.open(binary_path,FileAccess.WRITE)
		if file == null: return FileAccess.get_open_error()
		file.store_buffer(bytes)
		file.close()
	if FileAccess.get_file_as_bytes(binary_path)!=bytes: return ERR_FILE_CORRUPT
	var resources = preload("res://tools/content/run_resources.gd").new()
	resources.input_sha256 = input_sha256
	resources.paths = stage.resources.paths.duplicate()
	resources.paths.sort()
	for i in resources.paths.size(): resources.keys[i+1] = resources.paths[i]
	if not FileAccess.file_exists(resources_path):
		error = ResourceSaver.save(resources,resources_path)
		if error!=OK: return error
	else:
		var saved = ResourceLoader.load(resources_path,"",ResourceLoader.CACHE_MODE_IGNORE)
		if saved == null or saved.input_sha256!=input_sha256 or saved.paths!=resources.paths: return ERR_FILE_CORRUPT
	var index := {"format":1,"stage_id":str(stage.index),"source_sha256":source_sha256,"input_sha256":input_sha256,"payload_sha256":bytes.slice(56,88).hex_encode(),"binary":binary_path,"resources":resources_path,"resources_sha256":FileAccess.get_sha256(resources_path)}
	var pending_path := output.path_join("stage_%d.pending.json" % stage.index)
	var final_path := output.path_join("stage_%d.json" % stage.index)
	var file := FileAccess.open(pending_path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(index))
	file.close()
	var checked := preload("res://scripts/runtime/run_content_loader.gd").read_bundle(pending_path,input_sha256)
	if checked.is_empty(): return ERR_INVALID_DATA
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(pending_path),ProjectSettings.globalize_path(final_path))
