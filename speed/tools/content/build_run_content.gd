## Resourceの実効値を解決し、共通スキーマの書込へ渡す。
extends RefCounted
const Schema = preload("res://tools/content/generated/run_schema.gd")
const Legacy = preload("res://tools/content/build_native_data.gd")

static func chase_package(definition: EnemyDef, config: GameConfig, stage: RuntimeStage = null) -> Dictionary:
	if definition == null or definition.behavior not in [&"chase",&"shield",&"biter",&"hound",&"meteor",&"obstacle",&"saw",&"gunner"]: return {}
	var resolved := Legacy.compile_enemy(definition,config,stage)
	if resolved.is_empty(): return {}
	var source: Dictionary = resolved.enemies[0]
	var row := {"id":1,"kind":{&"chase":0,&"shield":1,&"biter":2,&"hound":3,&"meteor":4,&"obstacle":5,&"saw":6,&"gunner":7}[definition.behavior],"turn":source.turn}
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
	row.visual_id = 6
	row.sprite_scale = 1.0/definition.visual_value("collision_scale",1.0)
	row.sprite_angle = PI/2.0 if definition.id in EnemyDef.NATIVE_SPRITES else -PI/2.0
	var data := {}
	for record in Schema.SCHEMA.records: data[record.name] = []
	data.RunConfig = [{"id":1,"aim_lag":resolved.motion.aim_lag,"aim_speed":resolved.motion.aim_speed,"crystal_low":config.xp_crystal_values[0],"crystal_mid":config.xp_crystal_values[1],"crystal_high":config.xp_crystal_values[2]}]
	for field in Schema.SCHEMA.records[0].fields:
		if field.has("config"): data.RunConfig[0][field.name] = config.get(field.config)
		elif field.has("value"): data.RunConfig[0][field.name] = field.value
	data.RunConfig[0].world_tick_div = maxi(1,int(config.world_tick_div))
	data.RunConfig[0].time_limit = stage.time_limit if stage != null else -1.0
	if stage!=null:
		for phase: PhaseDef in stage.phases:
			data.BudgetPhase.append({"id":data.BudgetPhase.size()+1,"start":phase.start,"budget":float(maxi(0,phase.attack_budget))})
	data.ContactDefinition = [
		{"id":1,"shape":1,"scale":0,"hit_policy":1,"add_ship_radius":true,"ship_sweep":false,"width":0.0},
		{"id":2,"shape":0,"scale":0,"hit_policy":0,"add_ship_radius":true,"ship_sweep":false,"width":0.0},
		{"id":3,"shape":7,"scale":0,"hit_policy":0,"add_ship_radius":true,"ship_sweep":false,"width":0.0},
		{"id":4,"shape":1,"scale":0,"hit_policy":0,"add_ship_radius":false,"ship_sweep":false,"width":0.0}]
	data.BeamDefinition = [{"id":1,"contact":3}]
	data.FriendShotDefinition = [{"id":1,"contact":4}]
	data.StringEntry = [{"id":1,"value":String(definition.id)}]
	data.DefinitionIndex = [{"id":1,"enemy":1}]
	data.EnemyRecord = [row]
	if definition.behavior in [&"biter",&"hound"]:
		var visual_scene := "res://scenes/attacks/zone_biter.tscn"
		var visual: Node = load(visual_scene).instantiate()
		data.BiteDefinition = [{"id":1,"reach":source.bite.bite_reach,"warn":source.bite.bite_telegraph,
			"rest":source.bite.bite_rest,"radius":source.bite.bite_radius,"damage":source.bite.bullet_dmg,
			"duration":ProjectileSystem.ZONE_FLASH,"visual_key":7,
			"hit":visual.get_node_or_null("Hit")!=null,"fade":visual.get_node_or_null("Fade")!=null}]
		visual.free()
	if definition.behavior==&"gunner":
		var gunner: Dictionary = source.gunner.duplicate()
		gunner.id = 1
		data.GunnerDefinition = [gunner]
	if definition.behavior==&"hound":
		var pack: Dictionary = source.pack.duplicate()
		pack.id = 1
		data.HoundDefinition = [pack]
	var sprite := stage.enemy_sprite_path(definition.id) if stage!=null else "res://assets/pixel/%s.png" % definition.id
	if definition.behavior==&"meteor":
		sprite = "res://assets/pixel/meteor_0.png"
		row.sprite_angle = 0.0
	var look: EnemyLook
	var skin := sprite.get_file().get_basename()
	var visual_index: StageResources = stage.resources if stage!=null and stage.resources!=null and not stage.resources.look_paths.is_empty() else ContentManager.visual_index
	if visual_index!=null and visual_index.look_paths.has(skin):
		sprite = visual_index.look_paths[skin]
		look = load(sprite) as EnemyLook
		if look==null or not look.prepared: return {}
		row.sprite_angle = look.angle
		if not look.size_from_collision: row.sprite_scale *= maxf(look.base.get_width(),look.base.get_height())*0.5/maxf(definition.radius,0.001)
	if not ResourceLoader.exists(sprite): return {}
	var visuals := [{"id":1,"role":1,"path":"res://assets/pixel/airship.png"},
		{"id":2,"role":2,"path":""},{"id":3,"role":3,"path":"res://assets/pixel/xp_crystal_facets.tres"},
		{"id":4,"role":4,"path":""},{"id":5,"role":5,"path":"res://assets/pixel/airship_canon.png"},
		{"id":6,"role":6 if look!=null else 0,"path":sprite}]
	if not data.BiteDefinition.is_empty(): visuals.append({"id":7,"role":8,"path":"res://scenes/attacks/zone_biter.tscn"})
	for visual: Dictionary in visuals: data.ResourceKey.append({"id":visual.id,"role":visual.role})
	var weapon := load("res://data/weapons/W01_forward.tres") as WeaponDef
	if weapon==null: return {}
	data.LoadoutDefinition = [{"id":1,"kind":0,"maximum_level":weapon.level_steps.size(),"external_id":String(weapon.id),"comet_only":weapon.comet_only}]
	data.LifecycleDefinition = [{"id":1,"death_freeze_time":config.death_freeze_time,"death_explosion_time":config.death_explosion_time,"death_game_over_time":config.death_game_over_time,"clear_bonus":config.clear_bonus,"legendary":String(stage.legendary_module_id) if stage!=null else "","death_world_dim":config.death_world_dim}]
	data.ProgressionDefinition = [{"id":1}]
	for field in Schema.SCHEMA.records:
		if field.name == "ProgressionDefinition":
			for item in field.fields:
				if item.name != "id": data.ProgressionDefinition[0][item.name] = config.get(item.name)
	var entry: ContentEntry = ContentManager.catalog.find(&"weapons",weapon.id)
	if entry==null: return {}
	for path in entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":1,"asset":key})
	if config.planet_radius>0.0:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":9})
		visuals.append({"id":key,"role":9,"path":"res://assets/pixel/planet.png"})
		data.FieldBodyDefinition = [{"id":1,"kind":0,"x":0.0,"y":0.0,"radius":config.planet_radius,"visual":key}]
	if config.moon_count>0:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":10})
		visuals.append({"id":key,"role":10,"path":"res://assets/pixel/moon.png"})
		data.MoonDefinition = [{"id":1,"count":config.moon_count,"orbit_min":1500.0,"orbit_max":config.field_radius-600.0,
			"angle_jitter":0.3,"radius_min":110.0,"radius_max":180.0,"angular_speed":config.moon_orbit_speed,"visual":key}]
	var bullet_visual: int = data.ResourceKey.size()+1
	data.ResourceKey.append({"id":bullet_visual,"role":11})
	visuals.append({"id":bullet_visual,"role":11,"path":""})
	data.ResourceKey.append({"id":bullet_visual+1,"role":12})
	visuals.append({"id":bullet_visual+1,"role":12,"path":""})
	data.HostileDefinition = [{"id":1,"kind":0,"radius":7.0,"life":4.0,"damage":7.0,"slow":0.0,"turn":0.0,
		"visual":bullet_visual,"stone_visual":bullet_visual+1,"contact":1}]
	if definition.behavior==&"shield":
		var shield := {"id":1,"reflected":2}
		for key in ["accel","turn","weak_arc","front_arc","reflect_speed","reflect_interval","shield_time"]: shield[key] = source.shield[key]
		data.ShieldDefinition = [shield]
		var reflected_visual: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":reflected_visual,"role":13})
		visuals.append({"id":reflected_visual,"role":13,"path":""})
		data.HostileDefinition.append({"id":2,"kind":2,"radius":5.0,"life":source.shield.reflect_life,"damage":source.shield.reflect_dmg,"slow":0.0,"turn":0.0,
			"visual":reflected_visual,"stone_visual":bullet_visual+1,"contact":1})
	for i in weapon.level_steps.size():
		data.ForwardDefinition.append({"id":i+1,"weapon":1,"level":i+1,
			"interval":float(weapon.params.interval_by_level[i]),"damage":float(weapon.params.damage_by_level[i]),
			"life":float(weapon.params.life),"spread":float(weapon.params.spread_step),"knock":float(weapon.params.knock),
			"pierce":int(weapon.params.pierce_by_level[i])})
	return {"records":data,"visuals":visuals}

static func chase_records(definition: EnemyDef, config: GameConfig, stage: RuntimeStage = null) -> Dictionary:
	return chase_package(definition,config,stage).get("records",{})

static func compile_chase(definition: EnemyDef, config: GameConfig, input_sha256: PackedByteArray) -> PackedByteArray:
	return Schema.write_content(chase_records(definition,config),input_sha256)

## 同じRuntimeStageから生成し、検査済みの版へ索引を最後に切り替える。
static func build(stage: RuntimeStage, config: GameConfig, output: String, input_sha256: String, definitions := {}) -> Error:
	if stage == null or stage.resources == null or input_sha256.length()!=64: return ERR_INVALID_DATA
	var data := {}
	var appearance_metadata := {}
	var equipment_resources: Array = []
	var visuals: Array[Dictionary] = []
	var field_visuals: Array = []
	var attack_visuals: Array = []
	for record in Schema.SCHEMA.records: data[record.name] = []
	var enemy_ids := stage.resources.enemy_ids.duplicate()
	for terrain in ["meteor","iron","saw"]:
		if not terrain in enemy_ids: enemy_ids.append(terrain)
	for i in enemy_ids.size():
		var id: String = enemy_ids[i]
		var definition: EnemyDef = definitions.get(StringName(id))
		if definition == null:
			definition = ResourceLoader.load("res://data/enemies/%s.tres" % id,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyDef
		if definition == null or String(definition.id)!=id: return ERR_INVALID_DATA
		var tuning: Dictionary = stage.enemy_tuning.get(id,{})
		if not StageEnemyTuning.error_for(definition,tuning).is_empty(): return ERR_INVALID_DATA
		definition = StageEnemyTuning.resolve(definition,tuning)
		var package := chase_package(definition,config,stage)
		if package.is_empty(): return ERR_UNAVAILABLE
		var resolved: Dictionary = package.records
		var row: Dictionary = resolved.EnemyRecord[0]
		row.id = i+1
		row.visual_id = i+6
		data.EnemyRecord.append(row)
		for bite: Dictionary in resolved.BiteDefinition:
			bite.id = row.id
			data.BiteDefinition.append(bite)
		for gunner: Dictionary in resolved.GunnerDefinition:
			gunner.id = row.id
			data.GunnerDefinition.append(gunner)
		for hound: Dictionary in resolved.HoundDefinition:
			hound.id = row.id
			data.HoundDefinition.append(hound)
		data.StringEntry.append({"id":i+1,"value":id})
		data.DefinitionIndex.append({"id":i+1,"enemy":i+1})
		data.RunConfig = resolved.RunConfig
		data.ContactDefinition = resolved.ContactDefinition
		data.BeamDefinition = resolved.BeamDefinition
		data.FriendShotDefinition = resolved.FriendShotDefinition
		data.BudgetPhase = resolved.BudgetPhase
		if data.ResourceKey.is_empty():
			data.ResourceKey = resolved.ResourceKey.slice(0,5)
			visuals.assign(package.visuals.slice(0,5))
			data.LoadoutDefinition = resolved.LoadoutDefinition
			data.ForwardDefinition = resolved.ForwardDefinition
			data.ProgressionDefinition = resolved.ProgressionDefinition
			data.LifecycleDefinition = resolved.LifecycleDefinition
			equipment_resources = package.visuals.filter(func(key: Dictionary): return key.role==7)
			data.FieldBodyDefinition = resolved.FieldBodyDefinition.duplicate(true)
			data.MoonDefinition = resolved.MoonDefinition.duplicate(true)
			data.HostileDefinition = resolved.HostileDefinition.slice(0,1).duplicate(true)
			field_visuals = package.visuals.filter(func(key: Dictionary): return key.role in [9,10])
			attack_visuals = package.visuals.filter(func(key: Dictionary): return key.role in [11,12,13])
		for attack_visual: Dictionary in package.visuals:
			if attack_visual.role==13 and not attack_visuals.any(func(value: Dictionary): return value.role==13): attack_visuals.append(attack_visual)
		for shield_source: Dictionary in resolved.ShieldDefinition:
			var shield := shield_source.duplicate()
			var reflected: Dictionary = resolved.HostileDefinition[1].duplicate()
			reflected.id = data.HostileDefinition.size()+1
			shield.id = row.id
			shield.reflected = reflected.id
			data.HostileDefinition.append(reflected)
			data.ShieldDefinition.append(shield)
		var visual: Dictionary = package.visuals[5].duplicate()
		visual.id = i+6
		data.ResourceKey.append({"id":visual.id,"role":visual.role})
		visuals.append(visual)
		if visual.role==6:
			var look: EnemyLook = load(visual.path)
			var lighting: Resource = load("res://data/visuals/enemy_lighting.tres")
			var settings := {}
			for key in ["key_energy","fill_energy","key_angle","fill_angle","height","ambient","normal_strength"]:
				settings[key] = definition.visual_value(key,lighting.get(key))
			appearance_metadata[visual.id] = {"settings":settings,"paint":look.colors_key(definition.armor_colors),"biting":definition.behavior==&"biter",
				"biter_parts":"res://data/visuals/biter_parts.tres" if id=="biter" and look.source_path=="res://data/visuals/looks/biter.tres" else ""}
	if data.RunConfig.is_empty(): return ERR_INVALID_DATA
	if not data.BiteDefinition.is_empty():
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":8})
		visuals.append({"id":key,"role":8,"path":"res://scenes/attacks/zone_biter.tscn"})
		for bite: Dictionary in data.BiteDefinition: bite.visual_key = key
	for resource: Dictionary in equipment_resources:
		var row := resource.duplicate()
		row.id = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":row.id,"role":row.role})
		visuals.append(row)
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":1,"asset":row.id})
	for resource: Dictionary in field_visuals:
		var row := resource.duplicate()
		row.id = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":row.id,"role":row.role})
		visuals.append(row)
		if row.role==9: data.FieldBodyDefinition[0].visual = row.id
		else: data.MoonDefinition[0].visual = row.id
	for resource: Dictionary in attack_visuals:
		var row := resource.duplicate()
		row.id = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":row.id,"role":row.role})
		visuals.append(row)
		for attack: Dictionary in data.HostileDefinition:
			if row.role==12: attack.stone_visual = row.id
			elif (row.role==13 and attack.kind==2) or (row.role==11 and attack.kind!=2): attack.visual = row.id
	var terrain := {"id":1}
	for key in ["meteor_count","iron_count","saw_count","planet_radius","meteor_coin_chance","meteor_heal_chance","meteor_magnet_chance","saw_speed","saw_power","saw_life"]:
		terrain[key] = config.get(key)
	for id in ["meteor","iron","saw"]: terrain[id] = enemy_ids.find(id)+1
	for variant in 2:
		var path := "res://assets/pixel/%s_spritesheet.png" % ("meteor" if variant==0 else "meteor2")
		var texture: Texture2D = load(path)
		if texture==null: return ERR_CANT_OPEN
		var size := float(texture.get_height())
		terrain["meteor_radius_%d" % variant] = size*0.5
		for damage in 3:
			var key: int = data.ResourceKey.size()+1
			data.ResourceKey.append({"id":key,"role":0})
			visuals.append({"id":key,"role":0,"path":path,"rect":Rect2(size*damage,0.0,size,size)})
			terrain["meteor_visual_%d" % (variant*3+damage)] = key
	data.RockFieldDefinition = [terrain]
	var source_sha256 := input_sha256
	var paths := stage.resources.paths.duplicate()
	paths.append("res://.content/meteor_pieces.res")
	for visual: Dictionary in visuals:
		if visual.role!=7 and not visual.path.is_empty() and not paths.has(visual.path): paths.append(visual.path)
	for metadata: Dictionary in appearance_metadata.values():
		if not metadata.biter_parts.is_empty() and not paths.has(metadata.biter_parts): paths.append(metadata.biter_parts)
	for asset in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]:
		if not paths.has(asset): paths.append(asset)
	paths.sort()
	var profiles_error: Error = preload("res://tools/content/build_visuals.gd").validate()
	if profiles_error!=OK: return profiles_error
	var manifest := preload("res://tools/content/build_run_resources.gd").collect(paths,visuals,ContentManager.catalog)
	if manifest.is_empty(): return ERR_INVALID_DATA
	paths = manifest.paths
	var resolved_input := source_sha256.to_utf8_buffer()
	resolved_input.append_array(Schema.write_content(data,PackedByteArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])))
	resolved_input.append_array("\n".join(paths).to_utf8_buffer())
	resolved_input.append_array(var_to_bytes(appearance_metadata))
	resolved_input.append_array(var_to_bytes(manifest.hashes))
	resolved_input.append_array(var_to_bytes([manifest.keys,manifest.equipment,manifest.order,manifest.signatures,visuals]))
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
	resources.paths = paths
	resources.dependencies = manifest.hashes
	resources.equipment = manifest.equipment
	resources.order = manifest.order
	resources.signatures = manifest.signatures
	resources.keys = manifest.keys
	resources.visuals.assign(visuals.duplicate(true))
	for visual: Dictionary in resources.visuals:
		if appearance_metadata.has(visual.id): visual.merge(appearance_metadata[visual.id])
	for visual: Dictionary in visuals:
		if not visual.path.is_empty(): resources.keys[visual.id] = visual.path
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
