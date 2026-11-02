## Resourceの実効値を解決し、共通スキーマの書込へ渡す。
extends RefCounted
const Schema = preload("res://tools/content/generated/run_schema.gd")
const Wave = preload("res://scripts/attacks/wave.gd")
const Slash = preload("res://scripts/attacks/slash.gd")
const Missile = preload("res://scripts/attacks/missile.gd")
const Legacy = preload("res://tools/content/build_native_data.gd")

static func chase_package(definition: EnemyDef, config: GameConfig, stage: RuntimeStage = null) -> Dictionary:
	if definition == null or definition.behavior not in [&"chase",&"shield",&"biter",&"hound",&"meteor",&"obstacle",&"saw",&"gunner",&"beamer",&"missile",&"rocket",&"drift",&"part",&"dash",&"battleship",&"sniper",&"marlin",&"pulser",&"dolphin",&"lynx",&"soldier",&"auriga",&"clock",&"reticle",&"aquarius"]: return {}
	var resolved := Legacy.compile_enemy(definition,config,stage)
	if resolved.is_empty(): return {}
	var source: Dictionary = resolved.enemies[0]
	var row := {"id":1,"kind":{&"chase":0,&"shield":1,&"biter":2,&"hound":3,&"meteor":4,&"obstacle":5,&"saw":6,&"gunner":7,&"beamer":8,&"missile":9,&"rocket":10,&"drift":11,&"part":12,&"dash":13,&"battleship":14,&"sniper":15,&"marlin":16,&"pulser":17,&"dolphin":18,&"lynx":19,&"soldier":20,&"auriga":21,&"clock":22,&"reticle":23,&"aquarius":24}[definition.behavior],"turn":source.turn}
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
	row.reward_scattered = int(definition.params.get("gem_count",1))>1
	row.reward_burst = row.reward_scattered and definition.id!=&"splitter"
	row.visual_id = 6
	row.sprite_scale = 1.0/definition.visual_value("collision_scale",1.0)
	row.sprite_angle = PI/2.0 if definition.id in EnemyDef.NATIVE_SPRITES else -PI/2.0
	var data := {}
	for record in Schema.SCHEMA.records: data[record.name] = []
	data.PopulationDefinition = [{"id":1,"active":false,"density":config.density_mult,"bonus_pop":config.bonus_pop,"boss_start":0.0,"recycle_scale":config.spawn_recycle_scale,"region_cap":config.spawn_region_cap,"margin":config.spawn_margin,"field_radius":config.field_radius,"planet_radius":config.planet_radius,"total_cap":config.spawn_total_cap,"refill_time":config.spawn_refill_time}]
	data.WarpDefinition = [{"id":1,"radius":config.warp_radius,"life":config.warp_life,"bonus_time":config.bonus_time}]
	data.GravityDefinition = [{"id":1,"life":config.gravity_life,"radius":config.gravity_radius,"pull":config.gravity_pull}]
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
	data.ContactDefinition.append({"id":5,"shape":5,"scale":0,"hit_policy":0,"add_ship_radius":true,"ship_sweep":false,"width":0.0})
	data.WaveDefinition = [{"id":1,"contact":5,"enemy_min_distance":Wave.ENEMY_MIN_DISTANCE,"enemy_knock":Wave.ENEMY_KNOCK}]
	data.ContactDefinition.append({"id":6,"shape":1,"scale":0,"hit_policy":3,"add_ship_radius":true,"ship_sweep":false,"width":0.0})
	data.WallDefinition = [{"id":1,"contact":6}]
	data.ContactDefinition.append({"id":7,"shape":3,"scale":0,"hit_policy":1,"add_ship_radius":true,"ship_sweep":false,"width":0.0})
	for claw in 3:
		var points: PackedVector2Array = Slash.slash_local(claw)
		for sample in points.size():
			data.SlashDefinition.append({"id":data.SlashDefinition.size()+1,"claw":claw,"sample":sample,"x":points[sample].x,"y":points[sample].y,"thickness":Slash.SLASH_THICK,"contact":7})
	var bolt_visual: AttackVisual = load("res://scenes/attacks/bolt.tscn").instantiate()
	bolt_visual._apply_effect_settings()
	var bolt_tint: Color = bolt_visual.effect_tint
	data.BoltDefinition = [{"id":1,"radius":7.0,"life":4.0,"flight_scale":bolt_visual.flight_scale,"tint_r":bolt_tint.r,"tint_g":bolt_tint.g,"tint_b":bolt_tint.b,"tint_a":bolt_tint.a,"contact":1}]
	bolt_visual.free()
	for cosmic in [false,true]:
		var arrow: AttackVisual = load("res://scenes/attacks/cosmic_arrow.tscn" if cosmic else "res://scenes/attacks/light_arrow.tscn").instantiate()
		arrow._apply_effect_settings()
		var style := {"id":data.LightArrowDefinition.size()+1,"cosmic":cosmic,"contact":1,"flight_scale":arrow.flight_scale}
		for key in ["shot_length_scale","shot_width_scale","core_width","cosmic_speed","cosmic_star_count"]: style[key] = arrow.get(key)
		for color_pair in [["arrow",arrow.get("arrow_color")],["cosmic_a",arrow.get("cosmic_color_a")],["cosmic_b",arrow.get("cosmic_color_b")],["tint",arrow.effect_tint]]:
			for channel in ["r","g","b","a"]: style[color_pair[0]+"_"+channel] = color_pair[1][channel]
		data.LightArrowDefinition.append(style)
		arrow.free()
	data.FriendShotDefinition = [{"id":1,"contact":4}]
	data.StringEntry = [{"id":1,"value":String(definition.id)}]
	data.DefinitionIndex = [{"id":1,"enemy":1}]
	data.EnemyRecord = [row]
	data.PopulationType = [{"id":1,"enemy":1,"rank":definition.rank,"maximum":definition.max_alive,"ranged":definition.ranged}]
	if definition.behavior in [&"biter",&"hound"]:
		var visual_scene := "res://scenes/attacks/zone_biter.tscn"
		var visual: Node = load(visual_scene).instantiate()
		data.BiteDefinition = [{"id":1,"reach":source.bite.bite_reach,"warn":source.bite.bite_telegraph,
			"rest":source.bite.bite_rest,"radius":source.bite.bite_radius,"damage":source.bite.bullet_dmg,
			"duration":ProjectileSystem.ZONE_FLASH,"visual_key":7,
			"hit":visual.get_node_or_null("Hit")!=null,"fade":visual.get_node_or_null("Fade")!=null}]
		visual.free()
	if definition.behavior==&"lynx":
		var item: Dictionary = source.lynx.duplicate()
		item.id = 1
		data.LynxDefinition = [item]
	if definition.behavior==&"soldier":
		var item: Dictionary = source.soldier.duplicate()
		item.id = 1
		data.SoldierDefinition = [item]
	if definition.behavior==&"auriga":
		var item: Dictionary = source.auriga.duplicate()
		item.id = 1
		data.AurigaDefinition = [item]
	if definition.behavior==&"clock":
		var item: Dictionary = source.clock.duplicate()
		item.id = 1
		data.ClockDefinition = [item]
	if definition.behavior==&"aquarius":
		var item: Dictionary = source.aquarius.duplicate()
		item.id = 1
		data.AquariusDefinition = [item]
	if definition.behavior==&"reticle":
		var item: Dictionary = source.reticle.duplicate()
		item.id = 1
		data.ReticleDefinition = [item]
	if definition.behavior==&"dolphin":
		var dolphin: Dictionary = source.dolphin.duplicate()
		dolphin.id = 1
		data.DolphinDefinition = [dolphin]
	if definition.behavior==&"pulser":
		var pulser: Dictionary = source.pulser.duplicate()
		pulser.id = 1
		data.PulserDefinition = [pulser]
	if definition.behavior==&"marlin":
		var marlin: Dictionary = source.marlin.duplicate()
		marlin.id = 1
		data.MarlinDefinition = [marlin]
	if definition.behavior==&"sniper":
		var sniper: Dictionary = source.sniper.duplicate()
		sniper.id = 1
		data.SniperDefinition = [sniper]
	if definition.behavior==&"battleship":
		var battleship: Dictionary = source.battleship.duplicate()
		battleship.id = 1
		data.BattleshipDefinition = [battleship]
	if definition.behavior==&"dash":
		var dash: Dictionary = source.dash.duplicate()
		dash.id = 1
		data.DashDefinition = [dash]
	if definition.behavior==&"part": data.PartDefinition = [{"id":1}]
	if definition.behavior==&"drift":
		var drift: Dictionary = source.drift.duplicate()
		drift.id = 1
		data.DriftDefinition = [drift]
	if definition.behavior==&"rocket":
		var rocket: Dictionary = source.rocket.duplicate()
		rocket.id = 1
		rocket.contact = 2
		data.RocketDefinition = [rocket]
	if definition.behavior==&"missile":
		var missile: Dictionary = source.missile.duplicate()
		missile.id = 1
		data.MissileEnemyDefinition = [missile]
	if definition.behavior==&"beamer":
		var beamer: Dictionary = source.beamer.duplicate()
		beamer.id = 1
		data.BeamerDefinition = [beamer]
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
	var tow_tint: Color = preload("res://data/visuals/effect_settings.tres").tinted("weapon/massTow",Color.WHITE)
	data.FriendHullDefinition = [{"id":1,"contact":4,"saw_knock":300.0,"saw_spin":14.0,"tint_r":tow_tint.r,"tint_g":tow_tint.g,"tint_b":tow_tint.b,"tint_a":tow_tint.a}]
	data.FriendHullLook = [{"id":1,"enemy":1,"scale":row.sprite_scale,"angle":row.sprite_angle,"fixed_angle":look.fixed_angle if look!=null else false}]
	var saw_points: PackedVector2Array = preload("res://scripts/render/friendly/saw.gd").unit_points()
	for point in saw_points: data.FriendSawPoint.append({"id":data.FriendSawPoint.size()+1,"x":point.x,"y":point.y})
	var polygon := PackedVector2Array()
	if not ResourceLoader.exists(sprite):
		if definition.behavior not in [&"rocket",&"drift",&"part",&"dash",&"battleship",&"sniper",&"marlin",&"pulser",&"dolphin",&"lynx",&"soldier",&"auriga",&"clock",&"reticle",&"aquarius"]: return {}
		polygon = RunPresentation._placeholder_points(definition.shape)
		sprite = ""
		row.sprite_angle = 0.0
	data.FriendHullLook[0].scale = row.sprite_scale
	data.FriendHullLook[0].angle = row.sprite_angle
	var visuals := [{"id":1,"role":1,"path":"res://assets/pixel/airship.png"},
		{"id":2,"role":2,"path":""},{"id":3,"role":3,"path":"res://assets/pixel/xp_crystal_facets.tres"},
		{"id":4,"role":4,"path":""},{"id":5,"role":5,"path":"res://assets/pixel/airship_canon.png"},
		{"id":6,"role":Schema.ENUMS.VisualRole.EnemyPolygon if not polygon.is_empty() else (6 if look!=null else 0),"path":sprite}]
	if not polygon.is_empty(): visuals[5].points = polygon
	if not data.BiteDefinition.is_empty(): visuals.append({"id":7,"role":8,"path":"res://scenes/attacks/zone_biter.tscn"})
	for visual: Dictionary in visuals: data.ResourceKey.append({"id":visual.id,"role":visual.role})
	var weapon := load("res://data/weapons/W01_forward.tres") as WeaponDef
	if weapon==null: return {}
	data.LoadoutDefinition = [{"id":1,"kind":0,"maximum_level":weapon.level_steps.size(),"external_id":String(weapon.id),"comet_only":weapon.comet_only}]
	for id in ["T34","T35","T36","T07","T08","T09","T10","T11","T12","T14","T31"]:
		var trait_def := load("res://data/traits/%s_%s.tres" % [id,{"T34":"bigSwing","T35":"multiShot","T36":"fullBurst","T07":"quickCharge","T08":"capacity","T09":"critRate","T10":"speed","T11":"attack","T12":"pickup","T14":"length","T31":"glideDuration"}[id]]) as TraitDef
		if trait_def==null: return {}
		var equipment_id: int = data.LoadoutDefinition.size()+1
		data.LoadoutDefinition.append({"id":equipment_id,"kind":1,"maximum_level":config.trait_max_stacks,"external_id":id,"comet_only":false})
		for level in range(1,config.trait_max_stacks+1):
			data.NumericTraitLevel.append({"id":data.NumericTraitLevel.size()+1,"equipment":equipment_id,"level":level,
				"area_bonus":trait_def.stack_bonus(level) if id=="T34" else 0.0,
				"shot_bonus":trait_def.stack_bonus(level) if id=="T35" else 0.0,
				"full_gauge_rate":float(trait_def.params.rate_base)+float(trait_def.params.rate_per)*level if id=="T36" else 0.0,
				"charge_bonus":trait_def.stack_bonus(level) if id=="T07" else 0.0,
				"capacity_bonus":trait_def.stack_bonus(level) if id=="T08" else 0.0,
				"crit_bonus":trait_def.stack_bonus(level) if id=="T09" else 0.0,
				"speed_bonus":trait_def.stack_bonus(level) if id=="T10" else 0.0,
				"attack_bonus":trait_def.stack_bonus(level) if id=="T11" else 0.0,
				"pickup_bonus":trait_def.stack_bonus(level) if id=="T12" else 0.0,
				"length_bonus":trait_def.stack_bonus(level) if id=="T14" else 0.0,
				"glide_bonus":trait_def.stack_bonus(level) if id=="T31" else 0.0})
	var gear := load("res://data/traits/T04_fullCharge.tres") as TraitDef
	if gear==null: return {}
	var gear_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":gear_id,"kind":1,"maximum_level":config.trait_max_stacks,"external_id":"T04","comet_only":false})
	for level in range(1,config.trait_max_stacks+1):
		data.FullChargeDefinition.append({"id":level,"equipment":gear_id,"level":level,"multiplier":float(gear.params.mult_base)+float(gear.params.mult_per)*level})
	var crit_beam := load("res://data/traits/T06_critBeam.tres") as TraitDef
	if crit_beam==null: return {}
	var crit_beam_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":crit_beam_id,"kind":1,"maximum_level":config.trait_max_stacks,"external_id":"T06","comet_only":false})
	for level in range(1,config.trait_max_stacks+1):
		data.CritBeamDefinition.append({"id":level,"equipment":crit_beam_id,"level":level,"cooldown":float(crit_beam.params.cooldown),"damage":float(crit_beam.params.damage_base)+float(crit_beam.params.damage_per)*level,"length":float(crit_beam.params.length_base)+float(crit_beam.params.length_per)*level,"width":float(crit_beam.params.width_base)+float(crit_beam.params.width_per)*level,"knock":float(crit_beam.params.knock)})
	var vortex := load("res://data/traits/T03_vortex.tres") as TraitDef
	if vortex==null: return {}
	var vortex_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":vortex_id,"kind":1,"maximum_level":config.trait_max_stacks,"external_id":"T03","comet_only":false})
	for level in range(1,config.trait_max_stacks+1):
		data.VortexDefinition.append({"id":level,"equipment":vortex_id,"level":level,"damage":float(vortex.params.damage_base)+float(vortex.params.damage_per)*level,"radius":float(vortex.params.radius_by_level[level-1]),"kills":float(vortex.params.kills_by_level[level-1]),"charge":float(vortex.params.charge),"hold":float(vortex.params.hold),"collapse":float(vortex.params.collapse)})
	var run_up := load("res://data/traits/T32_runUp.tres") as TraitDef
	if run_up==null: return {}
	var run_up_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":run_up_id,"kind":1,"maximum_level":config.trait_max_stacks,"external_id":"T32","comet_only":false})
	for level in range(1,config.trait_max_stacks+1):
		data.RunUpDefinition.append({"id":level,"equipment":run_up_id,"level":level,"distance":float(run_up.params.distance),"multiplier":float(run_up.params.mult_base)+float(run_up.params.mult_per)*level,"radius":float(run_up.params.radius_base)+float(run_up.params.radius_per)*level,"area_damage":float(run_up.params.area_damage)})
	var rampage := load("res://data/traits/T33_rampage.tres") as TraitDef
	if rampage==null: return {}
	var rampage_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":rampage_id,"kind":1,"maximum_level":config.trait_max_stacks,"external_id":"T33","comet_only":false})
	for level in range(1,config.trait_max_stacks+1):
		data.RampageDefinition.append({"id":level,"equipment":rampage_id,"level":level,"bonus":float(rampage.params.bonus_base)+float(rampage.params.bonus_per)*level,"kills":int(rampage.params.kills),"half_life":float(rampage.params.half_life)})
	var duplicator := load("res://data/traits/T37_duplicator.tres") as TraitDef
	if duplicator==null: return {}
	var duplicator_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":duplicator_id,"kind":1,"maximum_level":config.trait_max_stacks,"external_id":"T37","comet_only":false})
	for level in range(1,config.trait_max_stacks+1):
		data.DuplicatorDefinition.append({"id":level,"equipment":duplicator_id,"level":level,"chance":float(duplicator.params.chance_by_level[level-1]),"damage":float(duplicator.params.damage_by_level[level-1]),"maximum":int(duplicator.params.max),"angle_min":float(duplicator.params.angle_min),"angle_max":float(duplicator.params.angle_max)})
	var scatter := load("res://data/weapons/W02_scatter.tres") as WeaponDef
	if scatter==null: return {}
	var scatter_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":scatter_id,"kind":0,"maximum_level":scatter.level_steps.size(),"external_id":"W02","comet_only":scatter.comet_only})
	for level in scatter.level_steps.size():
		data.ScatterDefinition.append({"id":level+1,"weapon":scatter_id,"level":level+1,"interval":float(scatter.params.interval_by_level[level]),"damage":float(scatter.params.damage_by_level[level]),"shots":int(scatter.params.shots_by_level[level]),"life":float(scatter.params.life),"spread":float(scatter.params.spread_step),"knock":float(scatter.params.knock)})
	var rear := load("res://data/weapons/W23_rear.tres") as WeaponDef
	if rear==null: return {}
	var rear_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":rear_id,"kind":0,"maximum_level":rear.level_steps.size(),"external_id":"W23","comet_only":rear.comet_only})
	var mount: Vector2 = preload("res://scripts/weapons/rear.gd").MOUNT_PIXEL-Vector2(15.5,30.0)
	for level in rear.level_steps.size():
		data.RearDefinition.append({"id":level+1,"weapon":rear_id,"level":level+1,"interval":float(rear.params.interval_by_level[level]),"damage":float(rear.params.damage_by_level[level]),"pierce":int(rear.params.pierce_by_level[level]),"life":float(rear.params.life),"spread":float(rear.params.spread_step),"knock":float(rear.params.knock),"color":Color(rear.params.color).to_rgba32(),"mount_x":mount.x,"mount_y":mount.y,"muzzle_distance":12.5})
	var barrier := load("res://data/weapons/W05_barrier.tres") as WeaponDef
	if barrier==null: return {}
	var barrier_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":barrier_id,"kind":0,"maximum_level":barrier.level_steps.size(),"external_id":"W05","comet_only":barrier.comet_only})
	for level in barrier.level_steps.size():
		data.BarrierDefinition.append({"id":level+1,"weapon":barrier_id,"level":level+1,"durability":float(barrier.params.durability_by_level[level]),"revive":float(barrier.params.revive_by_level[level]),"radius":float(barrier.params.radius_by_level[level]),"damage":float(barrier.params.damage_by_level[level]),"shell_radius":float(barrier.params.shell_radius),"knock":float(barrier.params.knock)})
	var end_blast := load("res://data/weapons/W29_endBlast.tres") as WeaponDef
	if end_blast==null: return {}
	var end_blast_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":end_blast_id,"kind":0,"maximum_level":end_blast.level_steps.size(),"external_id":"W29","comet_only":false})
	for level in end_blast.level_steps.size():
		data.EndBlastDefinition.append({"id":level+1,"weapon":end_blast_id,"level":level+1,"radius":float(end_blast.params.radius_by_level[level]),"damage":float(end_blast.params.damage_by_level[level]),"secondary":int(end_blast.params.secondary_by_level[level]),"secondary_radius":float(end_blast.params.secondary_radius),"secondary_damage":float(end_blast.params.secondary_damage),"secondary_delay":float(end_blast.params.secondary_delay),"secondary_step":float(end_blast.params.secondary_step),"knock":float(end_blast.params.knock)})
	var mines := load("res://data/weapons/W07_mines.tres") as WeaponDef
	if mines==null or config.post_max==null: return {}
	var mines_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":mines_id,"kind":0,"maximum_level":mines.level_steps.size(),"external_id":"W07","comet_only":false})
	var mines_target: Dictionary = config.post_max.target(mines.id)
	var mine_profile: Dictionary = preload("res://scripts/render/fx/burst_runtime.gd").profile("weapon/mines")
	for level in mines.level_steps.size():
		data.MinesDefinition.append({"id":level+1,"weapon":mines_id,"level":level+1,"count":int(mines.params.count_by_level[level]),"damage":float(mines.params.damage_by_level[level]),"radius":float(mines.params.radius_by_level[level]),"life":float(mines.params.life_by_level[level]),"maximum":int(mines.params.max),"trigger":float(mines.params.trigger),"spread":float(mines.params.spread),"range_min":float(mines.params.range_min),"range_max":float(mines.params.range_max),"duration_increment":float(config.post_max.increments.get("duration",0.0)) if "life_by_level" in mines_target.get("duration",[]) else 0.0,"knockback_increment":float(config.post_max.increments.get("knockback",0.0)) if mines_target.has("knockback") else 0.0,"visual_life":maxf(float(mine_profile.life),0.4)*float(mine_profile.time_scale)})
	if config.post_max==null: return {}
	data.PostMaxChargeDefinition = [{"id":1,"increment":float(config.post_max.increments.get("charge_time",0.0)),"minimum_ratio":config.post_max.minimum_time_ratio,"minimum_time":config.post_max.minimum_charge_time}]
	var crit_definition := load("res://data/traits/T09_critRate.tres") as TraitDef
	if crit_definition==null: return {}
	data.PostMaxCritDefinition = [{"id":1,"trait_maximum":float(crit_definition.params.get("max",1.0)),"trained_bonus":crit_definition.stack_bonus(config.trait_max_stacks),"increment":float(config.post_max.increments.get("crit_chance",0.0))}]
	data.PostMaxMotionDefinition = [{"id":1,"max_speed_increment":float(config.post_max.increments.get("max_speed",0.0))}]
	data.PostMaxWeaponPowerDefinition = [{"id":1,"equipment":1,"damage_increment":float(config.post_max.increments.get("weapon_damage",0.0)),"followup_increment":float(config.post_max.increments.get("followup",0.0)) if config.post_max.target(weapon.id).has("followup") else 0.0}]
	data.PostMaxWeaponPowerDefinition.append({"id":2,"equipment":scatter_id,"damage_increment":float(config.post_max.increments.get("weapon_damage",0.0)),"followup_increment":float(config.post_max.increments.get("followup",0.0)) if config.post_max.target(scatter.id).has("followup") else 0.0})
	var target: Dictionary = config.post_max.target(scatter.id)
	data.ScatterPostDefinition = [{"id":1,"interval_increment":float(config.post_max.increments.get("weapon_interval",0.0)) if target.has("interval") else 0.0,"projectile_increment":float(config.post_max.increments.get("projectile_speed",0.0)) if target.has("projectile") else 0.0,"duration_increment":float(config.post_max.increments.get("duration",0.0)) if "life" in target.get("duration",[]) else 0.0,"knockback_increment":float(config.post_max.increments.get("knockback",0.0)) if target.has("knockback") else 0.0,"minimum_ratio":config.post_max.minimum_time_ratio,"minimum_interval":config.post_max.minimum_interval}]
	data.PostMaxWeaponPowerDefinition.append({"id":3,"equipment":rear_id,"damage_increment":float(config.post_max.increments.get("weapon_damage",0.0)),"followup_increment":float(config.post_max.increments.get("followup",0.0)) if config.post_max.target(rear.id).has("followup") else 0.0})
	var rear_target: Dictionary = config.post_max.target(rear.id)
	data.RearPostDefinition = [{"id":1,"interval_increment":float(config.post_max.increments.get("weapon_interval",0.0)) if rear_target.has("interval") else 0.0,"projectile_increment":float(config.post_max.increments.get("projectile_speed",0.0)) if rear_target.has("projectile") else 0.0,"duration_increment":float(config.post_max.increments.get("duration",0.0)) if "life" in rear_target.get("duration",[]) else 0.0,"knockback_increment":float(config.post_max.increments.get("knockback",0.0)) if rear_target.has("knockback") else 0.0,"minimum_ratio":config.post_max.minimum_time_ratio,"minimum_interval":config.post_max.minimum_interval}]
	data.PostMaxWeaponPowerDefinition.append({"id":4,"equipment":barrier_id,"damage_increment":float(config.post_max.increments.get("weapon_damage",0.0)),"followup_increment":float(config.post_max.increments.get("followup",0.0)) if config.post_max.target(barrier.id).has("followup") else 0.0})
	data.PostMaxWeaponPowerDefinition.append({"id":5,"equipment":end_blast_id,"damage_increment":float(config.post_max.increments.get("weapon_damage",0.0)),"followup_increment":float(config.post_max.increments.get("followup",0.0)) if config.post_max.target(end_blast.id).has("followup") else 0.0})
	data.PostMaxWeaponPowerDefinition.append({"id":6,"equipment":mines_id,"damage_increment":float(config.post_max.increments.get("weapon_damage",0.0)),"followup_increment":float(config.post_max.increments.get("followup",0.0)) if mines_target.has("followup") else 0.0})
	var mines_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W07")
	if mines_entry==null: return {}
	for path in mines_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":mines_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":mines_id,"asset":key})
	var end_blast_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W29")
	if end_blast_entry==null: return {}
	for path in end_blast_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":end_blast_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":end_blast_id,"asset":key})
	var barrier_target: Dictionary = config.post_max.target(barrier.id)
	data.BarrierPostDefinition = [{"id":1,"interval_increment":float(config.post_max.increments.get("weapon_interval",0.0)) if barrier_target.has("interval") else 0.0,"knockback_increment":float(config.post_max.increments.get("knockback",0.0)) if barrier_target.has("knockback") else 0.0,"minimum_ratio":config.post_max.minimum_time_ratio,"minimum_interval":config.post_max.minimum_interval}]
	data.PostMaxPickupDefinition = [{"id":1,"xp_radius_increment":float(config.post_max.increments.get("pickup_radius",0.0))}]
	data.PostMaxDrawDefinition = [{"id":1,"line_length_increment":float(config.post_max.increments.get("line_length",0.0))}]
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
	var scatter_entry: ContentEntry = ContentManager.catalog.find(&"weapons",scatter.id)
	if scatter_entry==null: return {}
	for path in scatter_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":scatter_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":scatter_id,"asset":key})
	var rear_entry: ContentEntry = ContentManager.catalog.find(&"weapons",rear.id)
	if rear_entry==null: return {}
	for path in rear_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":rear_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":rear_id,"asset":key})
	var barrier_entry: ContentEntry = ContentManager.catalog.find(&"weapons",barrier.id)
	if barrier_entry==null: return {}
	for path in barrier_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":barrier_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":barrier_id,"asset":key})
	var gear_entry: ContentEntry = ContentManager.catalog.find(&"traits",gear.id)
	if gear_entry==null: return {}
	for path in gear_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":gear_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":gear_id,"asset":key})
	var crit_beam_entry: ContentEntry = ContentManager.catalog.find(&"traits",&"T06")
	if crit_beam_entry==null: return {}
	for path in crit_beam_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":crit_beam_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":crit_beam_id,"asset":key})
	var vortex_entry: ContentEntry = ContentManager.catalog.find(&"traits",&"T03")
	if vortex_entry==null: return {}
	for path in vortex_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":vortex_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":vortex_id,"asset":key})
	var run_up_entry: ContentEntry = ContentManager.catalog.find(&"traits",&"T32")
	if run_up_entry==null: return {}
	for path in run_up_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":run_up_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":run_up_id,"asset":key})
	var rampage_entry: ContentEntry = ContentManager.catalog.find(&"traits",rampage.id)
	if rampage_entry==null: return {}
	for path in rampage_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":rampage_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":rampage_id,"asset":key})
	var duplicator_entry: ContentEntry = ContentManager.catalog.find(&"traits",duplicator.id)
	if duplicator_entry==null: return {}
	for path in duplicator_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":duplicator_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":duplicator_id,"asset":key})
	var full_burst_entry: ContentEntry = ContentManager.catalog.find(&"traits",&"T36")
	if full_burst_entry==null: return {}
	var full_burst_id: int = data.LoadoutDefinition.filter(func(row: Dictionary): return row.external_id=="T36")[0].id
	for path in full_burst_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":full_burst_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":full_burst_id,"asset":key})
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
	var star: AttackVisual = load("res://scenes/attacks/star_bolt.tscn").instantiate()
	star._apply_effect_settings()
	var star_library: Resource = load("res://.content/attack_visuals.res")
	if star_library.get_meta("looks",{}).get("res://scenes/attacks/star_bolt.tscn",{}).get("Flight")==null:
		star.free()
		return {}
	var star_visual: int = data.ResourceKey.size()+1
	data.ResourceKey.append({"id":star_visual,"role":Schema.ENUMS.VisualRole.StarBolt})
	visuals.append({"id":star_visual,"role":Schema.ENUMS.VisualRole.StarBolt,"path":"res://.content/attack_visuals.res","scene":"res://scenes/attacks/star_bolt.tscn"})
	data.StarBoltDefinition = [{"id":1,"radius":9.0,"life":6.0,"flight_scale":star.flight_scale,"turn_with_velocity":star.turn_with_velocity,
		"tint_r":star.effect_tint.r,"tint_g":star.effect_tint.g,"tint_b":star.effect_tint.b,"tint_a":star.effect_tint.a,"visual":star_visual,"stone_visual":bullet_visual+1,"contact":1}]
	star.free()
	data.LightLanceDefinition = [{"id":1,"life":0.5,"flight_time":0.18,"maximum":220}]
	var shell_fixed: Dictionary = preload("res://data/visuals/pump_shell_runtime.tres").get_meta("values")
	var shell_tint: Color = shell_fixed.effect_tint
	data.ShellDefinition = [{"id":1,"contact":1,"flight_scale":shell_fixed.flight_scale,"tint_r":shell_tint.r,"tint_g":shell_tint.g,"tint_b":shell_tint.b,"tint_a":shell_tint.a}]
	data.ShellSource = [{"id":1,"enemy":1,"mouth_radius":18.5*config.character_scale*definition.visual_value("scale",1.0),"store_max":maxi(1,int(definition.params.get("store_max",1)))}]
	data.FloodDefinition = [{"id":1,"beam":1,"tail":1.4,"collapse":0.35,"margin":1.12}]
	data.ZoneDefinition = []
	var zone_names := ["zone","zone_reticle","zone_lightning","zone_bite","zone_aquila","zone_phoenix","zone_bomber","zone_pump"]
	for style in zone_names.size():
		var path: String = "res://scenes/attacks/%s.tscn" % zone_names[style]
		var zone_scene: PackedScene = load(path)
		var zone_visual: Node = zone_scene.instantiate()
		var settings: Resource = load("res://data/visuals/effect_settings.tres")
		var values: Dictionary = settings.resolved_values("enemy/aquila",path) if style==4 else settings.values_for(path)
		var tint: Color = values.get("effect_tint",zone_visual.effect_tint)
		var meta: Dictionary = star_library.get_meta("looks",{}).get(path,{})
		var record := {"id":style+1,"style":style,"contact":2,"active":ProjectileSystem.ZONE_FLASH,"hit_duration":zone_visual.hit_duration,"fade_duration":zone_visual.fade_duration,"hit":meta.get("Hit") is Mesh or not meta.get("Hit_sprites",[]).is_empty(),"fade":meta.get("Fade") is Mesh or not meta.get("Fade_sprites",[]).is_empty(),"tint_r":tint.r,"tint_g":tint.g,"tint_b":tint.b,"tint_a":tint.a}
		for key in ["glow_opacity","ring_opacity","ring_width","arm_count","lightning_reach","lightning_width"]: record[key] = float(values.get(key,zone_visual.get(key) if style==4 else 0.0))
		data.ZoneDefinition.append(record)
		zone_visual.free()
	var debris_settings: Resource = load("res://data/visuals/effect_settings.tres")
	var debris_tint: Color = debris_settings.tinted("",Color.WHITE)
	data.FriendDebrisDefinition = [{"id":1,"life":config.hull_debris_life,"knock":config.hull_debris_knock,"spread":deg_to_rad(config.hull_debris_spread),
		"character_scale":config.character_scale,"trail_life":config.corpse_trail_life,"trail_width":debris_settings.number("","debris_trail_width",1.0),
		"trail_points":config.corpse_trail_points,"maximum":200,"contact":4,"tint_r":debris_tint.r,"tint_g":debris_tint.g,"tint_b":debris_tint.b,"tint_a":debris_tint.a}]
	data.LumpDefinition = [{"id":1,"life":4.0,"projectile":1}]
	data.RingHoldDefinition = [{"id":1,"projectile_radius":8.0,"life":4.0,"projectile":1}]
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
	data.HostileDefinition.append({"id":data.HostileDefinition.size()+1,"kind":1,"radius":Missile.RADIUS,"life":Missile.LIFE,"damage":Missile.DEFAULT_DAMAGE,"slow":0.0,"turn":0.0,
		"visual":bullet_visual,"stone_visual":bullet_visual+1,"contact":1})
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
		var hull_look: Dictionary = resolved.FriendHullLook[0].duplicate()
		hull_look.id = row.id
		hull_look.enemy = row.id
		data.FriendHullLook.append(hull_look)
		var shell_source: Dictionary = resolved.ShellSource[0].duplicate()
		shell_source.id = row.id
		shell_source.enemy = row.id
		data.ShellSource.append(shell_source)
		for bite: Dictionary in resolved.BiteDefinition:
			bite.id = row.id
			data.BiteDefinition.append(bite)
		for item: Dictionary in resolved.LynxDefinition:
			item.id = row.id
			data.LynxDefinition.append(item)
		for item: Dictionary in resolved.SoldierDefinition:
			item.id = row.id
			data.SoldierDefinition.append(item)
		for item: Dictionary in resolved.AurigaDefinition:
			item.id = row.id
			data.AurigaDefinition.append(item)
		for item: Dictionary in resolved.ClockDefinition:
			item.id = row.id
			data.ClockDefinition.append(item)
		for item: Dictionary in resolved.AquariusDefinition:
			item.id = row.id
			data.AquariusDefinition.append(item)
		for item: Dictionary in resolved.ReticleDefinition:
			item.id = row.id
			data.ReticleDefinition.append(item)
		for dolphin: Dictionary in resolved.DolphinDefinition:
			dolphin.id = row.id
			data.DolphinDefinition.append(dolphin)
		for pulser: Dictionary in resolved.PulserDefinition:
			pulser.id = row.id
			data.PulserDefinition.append(pulser)
		for marlin: Dictionary in resolved.MarlinDefinition:
			marlin.id = row.id
			data.MarlinDefinition.append(marlin)
		for sniper: Dictionary in resolved.SniperDefinition:
			sniper.id = row.id
			data.SniperDefinition.append(sniper)
		for battleship: Dictionary in resolved.BattleshipDefinition:
			battleship.id = row.id
			data.BattleshipDefinition.append(battleship)
		for dash: Dictionary in resolved.DashDefinition:
			dash.id = row.id
			data.DashDefinition.append(dash)
		for part: Dictionary in resolved.PartDefinition:
			part.id = row.id
			data.PartDefinition.append(part)
		for drift: Dictionary in resolved.DriftDefinition:
			drift.id = row.id
			data.DriftDefinition.append(drift)
		for rocket: Dictionary in resolved.RocketDefinition:
			rocket.id = row.id
			data.RocketDefinition.append(rocket)
		for missile: Dictionary in resolved.MissileEnemyDefinition:
			missile.id = row.id
			data.MissileEnemyDefinition.append(missile)
		for beamer: Dictionary in resolved.BeamerDefinition:
			beamer.id = row.id
			data.BeamerDefinition.append(beamer)
		for gunner: Dictionary in resolved.GunnerDefinition:
			gunner.id = row.id
			data.GunnerDefinition.append(gunner)
		for hound: Dictionary in resolved.HoundDefinition:
			hound.id = row.id
			data.HoundDefinition.append(hound)
		data.StringEntry.append({"id":i+1,"value":id})
		data.DefinitionIndex.append({"id":i+1,"enemy":i+1})
		data.NumericTraitLevel = resolved.NumericTraitLevel
		data.RunConfig = resolved.RunConfig
		data.ContactDefinition = resolved.ContactDefinition
		data.BeamDefinition = resolved.BeamDefinition
		data.WaveDefinition = resolved.WaveDefinition
		data.PopulationDefinition = resolved.PopulationDefinition
		data.PopulationType.append({"id":row.id,"enemy":row.id,"rank":definition.rank,"maximum":definition.max_alive,"ranged":definition.ranged})
		data.WarpDefinition = resolved.WarpDefinition
		data.GravityDefinition = resolved.GravityDefinition
		data.WallDefinition = resolved.WallDefinition
		data.SlashDefinition = resolved.SlashDefinition
		data.BoltDefinition = resolved.BoltDefinition
		data.LightArrowDefinition = resolved.LightArrowDefinition
		data.FriendShotDefinition = resolved.FriendShotDefinition
		data.BudgetPhase = resolved.BudgetPhase
		if data.ResourceKey.is_empty():
			data.ResourceKey = resolved.ResourceKey.slice(0,5)
			visuals.assign(package.visuals.slice(0,5))
			data.FriendHullDefinition = resolved.FriendHullDefinition.duplicate(true)
			data.ZoneDefinition = resolved.ZoneDefinition.duplicate(true)
			data.FloodDefinition = resolved.FloodDefinition.duplicate(true)
			data.LightLanceDefinition = resolved.LightLanceDefinition.duplicate(true)
			data.ShellDefinition = resolved.ShellDefinition.duplicate(true)
			data.FriendSawPoint = resolved.FriendSawPoint.duplicate(true)
			data.FriendDebrisDefinition = resolved.FriendDebrisDefinition.duplicate(true)
			data.LumpDefinition = resolved.LumpDefinition.duplicate(true)
			data.RingHoldDefinition = resolved.RingHoldDefinition.duplicate(true)
			data.StarBoltDefinition = resolved.StarBoltDefinition.duplicate(true)
			data.LoadoutDefinition = resolved.LoadoutDefinition
			data.ForwardDefinition = resolved.ForwardDefinition
			data.ScatterDefinition = resolved.ScatterDefinition
			data.ScatterPostDefinition = resolved.ScatterPostDefinition
			data.RearDefinition = resolved.RearDefinition
			data.RearPostDefinition = resolved.RearPostDefinition
			data.MinesDefinition = resolved.MinesDefinition
			data.EndBlastDefinition = resolved.EndBlastDefinition
			data.BarrierDefinition = resolved.BarrierDefinition
			data.BarrierPostDefinition = resolved.BarrierPostDefinition
			data.FullChargeDefinition = resolved.FullChargeDefinition
			data.CritBeamDefinition = resolved.CritBeamDefinition
			data.VortexDefinition = resolved.VortexDefinition
			data.RunUpDefinition = resolved.RunUpDefinition
			data.RampageDefinition = resolved.RampageDefinition
			data.DuplicatorDefinition = resolved.DuplicatorDefinition
			data.ProgressionDefinition = resolved.ProgressionDefinition
			data.LifecycleDefinition = resolved.LifecycleDefinition
			for section in ["PostMaxChargeDefinition","PostMaxCritDefinition","PostMaxMotionDefinition","PostMaxWeaponPowerDefinition","PostMaxPickupDefinition","PostMaxDrawDefinition"]:
				data[section] = resolved[section]
			equipment_resources = package.visuals.filter(func(key: Dictionary): return key.role==7)
			data.FieldBodyDefinition = resolved.FieldBodyDefinition.duplicate(true)
			data.MoonDefinition = resolved.MoonDefinition.duplicate(true)
			for projectile: Dictionary in resolved.HostileDefinition:
				if projectile.kind==2: continue
				var attack := projectile.duplicate()
				attack.id = data.HostileDefinition.size()+1
				data.HostileDefinition.append(attack)
			field_visuals = package.visuals.filter(func(key: Dictionary): return key.role in [9,10])
			attack_visuals = package.visuals.filter(func(key: Dictionary): return key.role in [11,12,13,Schema.ENUMS.VisualRole.StarBolt])
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
			appearance_metadata[visual.id] = {"settings":settings,"paint":look.colors_key(definition.armor_colors),"hull_preview":look.preview_key(definition.armor_colors),"biting":definition.behavior==&"biter",
				"biter_parts":"res://data/visuals/biter_parts.tres" if id=="biter" and look.source_path=="res://data/visuals/looks/biter.tres" else ""}
	if data.RunConfig.is_empty(): return ERR_INVALID_DATA
	if not data.BiteDefinition.is_empty():
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":8})
		visuals.append({"id":key,"role":8,"path":"res://scenes/attacks/zone_biter.tscn"})
		for bite: Dictionary in data.BiteDefinition: bite.visual_key = key
	for resource: Dictionary in equipment_resources:
		var row := resource.duplicate()
		row.erase("equipment")
		row.id = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":row.id,"role":row.role})
		visuals.append(row)
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":int(resource.get("equipment",1)),"asset":row.id})
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
		for star: Dictionary in data.StarBoltDefinition:
			if row.role==Schema.ENUMS.VisualRole.StarBolt: star.visual = row.id
			elif row.role==12: star.stone_visual = row.id
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
	if not stage.phases.is_empty():
		data.PopulationDefinition[0].active = true
		data.PopulationDefinition[0].boss_start = stage.boss_start(config)
		var enemy_indices := {}
		for enemy in data.StringEntry: enemy_indices[StringName(enemy.value)] = enemy.id
		for phase: PhaseDef in stage.phases:
			var phase_row := {"id":data.PopulationPhase.size()+1,"external_id":String(phase.id),"start":phase.start,"pop_from":phase.pop_from,"pop_to":phase.pop_to,"rate":phase.rate,"xp_bonus":phase.xp_bonus,"attack_budget":phase.attack_budget,"wave_interval":phase.wave_interval,"wave_type":enemy_indices.get(phase.wave_type,0)}
			if phase.wave_interval>0.0 and phase_row.wave_type==0: return ERR_UNAVAILABLE
			for key in ["surge_interval","surge_pop","surge_ranged","surge_elite"]: phase_row[key] = phase.surge_value(key,config)
			data.PopulationPhase.append(phase_row)
			for enemy in phase.mix:
				if not enemy_indices.has(StringName(enemy)): return ERR_UNAVAILABLE
				data.PopulationMix.append({"id":data.PopulationMix.size()+1,"phase":phase_row.id,"enemy":enemy_indices[StringName(enemy)],"weight":float(phase.mix[enemy])})
		for curve: SpawnCurve in stage.zako_curves:
			if not enemy_indices.has(curve.type): return ERR_UNAVAILABLE
			var curve_row := {"id":data.PopulationCurve.size()+1,"enemy":enemy_indices[curve.type]}
			data.PopulationCurve.append(curve_row)
			for n in curve.points.size(): data.PopulationPoint.append({"id":data.PopulationPoint.size()+1,"curve":curve_row.id,"time":curve.points[n].x,"value":curve.points[n].y,"slope":SpawnCurve._slope(curve.points,n) if curve.points.size()>1 else 0.0})
		for window in stage.surge_windows(config): data.PopulationWindow.append({"id":data.PopulationWindow.size()+1,"start":window.x,"end":window.y if is_finite(window.y) else -1.0})

	var source_sha256 := input_sha256
	var paths := stage.resources.paths.duplicate()
	paths.append("res://.content/meteor_pieces.res")
	for asset in ["res://scripts/render/attacks/friend_debris.gd","res://assets/pixel/pump.png","res://.content/attack_visuals.res","res://scripts/render/attacks/zone.gd","res://scripts/render/fx/blast_bursts.gd","res://scripts/render/attacks/flood.gd","res://shaders/water_flood.gdshader","res://assets/fx/water_noise.png","res://scripts/render/light_lance.gd","res://scripts/render/equipment/critBeam.gd","res://scripts/render/attacks/shell_frame.gd","res://shaders/pump_shell_runtime.gdshader"]:
		if not paths.has(asset): paths.append(asset)
	if not paths.has("res://assets/fx/light_arrow.svg"): paths.append("res://assets/fx/light_arrow.svg")
	for visual: Dictionary in visuals:
		if visual.role!=7 and not visual.path.is_empty() and not paths.has(visual.path): paths.append(visual.path)
	for metadata: Dictionary in appearance_metadata.values():
		if not metadata.biter_parts.is_empty() and not paths.has(metadata.biter_parts): paths.append(metadata.biter_parts)
	for asset in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png","res://assets/pixel/airship_turret_base.png","res://assets/pixel/airship_turret.png","res://assets/pixel/airship_armor.png","res://assets/pixel/airship_mine.png"]:
		if not paths.has(asset): paths.append(asset)
	for placement: BackgroundPlacement in stage.backgrounds:
		for asset: String in [placement.texture_path,placement.fire_preset_path]:
			if not asset.is_empty() and not paths.has(asset): paths.append(asset)
	for key in stage.fire_uses:
		var asset: String = str(stage.fire_uses[key].get("preset",""))
		if not asset.is_empty() and not paths.has(asset): paths.append(asset)
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
	resolved_input.append_array(var_to_bytes([stage.background_color,stage.backgrounds.map(func(item): return [item.texture_path,item.offset,item.scale,item.rotation_degrees,item.display_tint(),item.bounds(),item.parallax,item.fire_preset_path,item.fire_offset,item.fire_scale]),stage.fire_uses]))
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
	resources.background_color = stage.background_color
	resources.backgrounds.assign(stage.backgrounds.duplicate(true))
	resources.fire_uses = stage.fire_uses.duplicate(true)
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
