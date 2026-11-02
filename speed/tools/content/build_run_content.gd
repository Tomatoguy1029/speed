## Resourceの実効値を解決し、共通スキーマの書込へ渡す。
extends RefCounted
const Schema = preload("res://tools/content/generated/run_schema.gd")
const Wave = preload("res://scripts/attacks/wave.gd")
const Slash = preload("res://scripts/attacks/slash.gd")
const Missile = preload("res://scripts/attacks/missile.gd")
const Legacy = preload("res://tools/content/build_native_data.gd")
const BossProgram = preload("res://tools/content/build_boss_program.gd")

## ボスも同じ値型のスキーマへ書く。Scriptと表示シーンは戦闘バイナリへ渡さない。
static func boss_technique_records(definition: BossDef, move: BossTechnique) -> Dictionary:
	if definition!=null and definition.id==&"centaurus": return centaurus_technique_records(definition,move)
	if definition==null or definition.id!=&"monoceros" or move==null or move.technique not in [&"charge",&"kick",&"sweep",&"lance",&"return_charge",&"horn_wave",&"horn_dance",&"sword_flash"]: return {}
	var source: BossTechnique = BossProgram.snapshot(move)
	var boss := {"id":1,"external_id":String(definition.id),"kind":0,"turn":definition.turn,"speed":definition.speed}
	for key in ["lock_lead","horn_width","horn_length_ratio","horn_length_ratio_p2","near_clearance","reposition_time","stuck_time","extract_time","extract_speed","approach_range","approach_speed","kick_trigger_arc"]:
		if not definition.params.has(key): return {}
		boss[key] = float(definition.params[key])
	var records := {"BossDefinition":[boss],"BossTechniqueDefinition":[],"BossTechniqueStage":[]}
	for phase in [1,2]:
		var values: Dictionary = source.values().duplicate(true)
		if phase>=2:
			for key: String in source.values():
				if key.ends_with("_p2"): values[key.trim_suffix("_p2")] = source.values()[key]
		var resolved: BossTechnique = source.duplicate(true)
		var row := {"id":phase,"boss":1,"external_id":String(source.technique),"kind":[&"charge",&"kick",&"sweep",&"lance",&"return_charge",&"horn_wave",&"horn_dance",&"sword_flash"].find(source.technique),"phase":phase,"track_during_warn":source.track_during_warn,"post_gap":source.post_gap}
		for key in ["warn","active","recover","cd","damage","distance","reach","hold","return_speed","approach_speed_start","approach_accel","approach_speed_max","approach_turn","approach_min","approach_max","stop_range","twist_time","twist","stop_time","stop_decel","windup_twist","arc","return_time","lock_time","aim_turn","back_speed","head_length","width","speed","boom_interval","boom_ahead","stop_decay","shatter_time","overshoot","brake_time","brake_speed_ratio","turn_time","turn_lock","head_lead","windup_turn","pull","swing_time","swing_turn","release_offset","recharge","wave_speed","wave_start","wave_max","wave_half_angle","wave_width","aim_lock","min_run","circle_turn","circle_speed","circle_late_time","circle_speed_late","circle_decel","circle_accel","align_angle","align_min_distance","align_min_time","circle_max_time","glow_angle","end_time","end_decay","first_windup","lunge_speed","lunge_decay","slash_min","slash_max","slash_angle","slash_length","slash_width","slash_hit_time","cut_gap"]:
			row[key] = float(values.get(key,0.0))
			if key in values: resolved.set(key,row[key])
		row.passes = int(values.get("passes",1))
		row.cuts = int(values.get("cuts",1))
		if row.kind==3: row.active = row.distance/maxf(row.speed,0.001)
		if row.kind==5:
			row.warn = float(values.windup)
			row.active = row.swing_time*2.0+row.recharge+row.return_time
		if row.kind==6:
			row.warn = float(values.aim_time)
			row.active = row.passes*0.6+(row.passes-1)*row.circle_late_time+row.end_time
		if row.kind==7:
			row.warn = float(values.windup)
			row.active = maxf(row.swing_time,0.001)
		if row.active<=0.0: return {}
		var commands: Array = [] if row.kind>=2 else BossProgram.charge_stage_commands(resolved,boss.lock_lead)
		if row.kind<2 and commands.size()!=3: return {}
		records.BossTechniqueDefinition.append(row)
		for command in commands:
			command.id = records.BossTechniqueStage.size()+1
			command.technique = phase
			records.BossTechniqueStage.append(command)
	return records

## ケンタウルスの値から、型付きの段階と矢の外観を生成する。
static func centaurus_technique_records(definition: BossDef, move: BossTechnique) -> Dictionary:
	if move==null or move.technique not in [&"volley",&"rear_attack",&"rain",&"power_shot",&"stomp",&"fan_volley",&"shower_chase",&"shower_wall",&"shower_path"]: return {}
	var source: BossTechnique = BossProgram.snapshot(move)
	var records := {"BossDefinition":[],"BossTechniqueDefinition":[],"BossTechniqueStage":[],"CentaurusVolleyDefinition":[],"CentaurusRearDefinition":[],"CentaurusRainDefinition":[],"CentaurusPowerDefinition":[],"CentaurusShowerDefinition":[],"CentaurusFanDefinition":[],"CentaurusStompDefinition":[],"CentaurusStompFoot":[],"LightArrowDefinition":[]}
	var boss := {"id":1,"external_id":"centaurus","kind":1,"turn":definition.turn,"speed":definition.speed}
	for key in ["lock_lead","horn_width","horn_length_ratio","horn_length_ratio_p2","near_clearance","reposition_time","stuck_time","extract_time","extract_speed","approach_range","approach_speed","kick_trigger_arc"]: boss[key] = 0.0
	records.BossDefinition = [boss]
	if move.technique in [&"volley",&"rain",&"power_shot",&"fan_volley",&"shower_chase",&"shower_wall",&"shower_path"]:
		var scene: PackedScene = source.get("shot_visual")
		if scene==null: scene = load("res://data/bosses/centaurus_moves/fan_volley.tres").shot_visual
		var visual: AttackVisual = scene.instantiate()
		if move.technique in [&"shower_chase",&"shower_wall",&"shower_path"]:
			visual.visual_profile_key = "boss/move/centaurus/"+str(move.technique)
			visual.visual_profile_fallback = "res://scenes/attacks/light_arrow.tscn"
		visual._apply_effect_settings()
		var style := {"id":1,"cosmic":move.technique==&"power_shot","contact":1,"flight_scale":visual.flight_scale}
		for key in ["shot_length_scale","shot_width_scale","core_width","cosmic_speed","cosmic_star_count"]: style[key] = visual.get(key)
		for color_pair in [["arrow",visual.get("arrow_color")],["cosmic_a",visual.get("cosmic_color_a")],["cosmic_b",visual.get("cosmic_color_b")],["tint",visual.effect_tint]]:
			for channel in ["r","g","b","a"]: style[color_pair[0]+"_"+channel] = color_pair[1][channel]
		visual.free()
		records.LightArrowDefinition = [style]
	for phase in [1,2]:
		var values: Dictionary = source.values().duplicate(true)
		if phase==2:
			for key: String in source.values():
				if key.ends_with("_p2"): values[key.trim_suffix("_p2")] = source.values()[key]
		var row := {}
		for record in Schema.SCHEMA.records:
			if record.name!="BossTechniqueDefinition": continue
			for field in record.fields: row[field.name] = false if field.type=="bool" else "" if field.type=="string" else 0
		row.merge({"id":phase,"boss":1,"external_id":str(move.technique),"kind":8 if move.technique==&"volley" else 9 if move.technique==&"rear_attack" else 10 if move.technique==&"rain" else 11 if move.technique==&"power_shot" else 12 if move.technique==&"stomp" else 13 if move.technique==&"fan_volley" else 14,"phase":phase,"track_during_warn":source.track_during_warn,"post_gap":source.post_gap,"passes":1,"cuts":1},true)
		for key in ["warn","recover","cd","damage","speed"]: row[key] = float(values.get(key,0.0))
		if move.technique in [&"shower_chase",&"shower_wall",&"shower_path"]:
			var pattern: int = ["chase","wall","path"].find(str(values.pattern))
			if pattern<0: return {}
			var placement: float = (int(values.count)-1)*float(values.interval) if pattern==0 else (int(values.count)-1)*0.5*float(values.step) if pattern==1 else (int(values.count)-1)*float(values.step)
			row.active = maxf(0.0,placement)+float(values.mark_time)+float(values.rain_time)
			records.BossTechniqueDefinition.append(row)
			var shower := {"id":phase,"technique":phase,"pattern":pattern,"count":int(values.count),"projectile":1}
			for key in ["mark_time","rain_time","linger","radius","interval","lead","spacing","step","wall_ratio","wall_min","wall_max","ahead"]: shower[key] = float(values[key])
			var fan: BossTechnique = load("res://data/bosses/centaurus_moves/fan_volley.tres")
			shower.arrow_radius = fan.radius
			shower.arrow_length = fan.length
			records.CentaurusShowerDefinition.append(shower)
		elif move.technique==&"fan_volley":
			row.active = (int(values.shots)-1)*float(values.interval)
			records.BossTechniqueDefinition.append(row)
			records.CentaurusFanDefinition.append({"id":phase,"technique":phase,"shots":int(values.shots),"count":int(values.count),"interval":float(values.interval),"spread":deg_to_rad(float(values.spread)),"radius":float(values.radius),"length":float(values.length),"travel":float(values.travel),"projectile":1})
		elif move.technique==&"stomp":
			row.active = float(values.active)
			records.BossTechniqueDefinition.append(row)
			records.CentaurusStompDefinition.append({"id":phase,"technique":phase,"radius":float(values.range_radius),"half_angle":deg_to_rad(float(values.half_angle))})
			for foot in centaurus_stomp_feet(load("res://data/visuals/centaurus_animation.tres"),phase):
				foot.id = records.CentaurusStompFoot.size()+1
				records.CentaurusStompFoot.append(foot)
		elif move.technique==&"power_shot":
			row.active = 0.05
			records.BossTechniqueDefinition.append(row)
			records.CentaurusPowerDefinition.append({"id":phase,"technique":phase,"count":maxi(1,int(values.count)),"alert":float(values.alert),"radius":float(values.radius),"travel":float(values.travel),"spread":float(values.spread),"projectile":1})
			var stages := [{"command":7,"at":maxf(0.01,row.warn-float(values.alert))},{"command":3,"at":row.warn},{"command":4,"at":row.warn+0.05}]
			stages.sort_custom(func(a,b): return a.at<b.at)
			for stage in stages: records.BossTechniqueStage.append({"id":records.BossTechniqueStage.size()+1,"technique":phase,"command":stage.command,"at":stage.at})
		elif move.technique==&"rain":
			row.active = int(values.traces)*float(values.trace_length)/maxf(float(values.trace_speed),1.0)+(int(values.traces)-1)*float(values.trace_gap)+float(values.drop_delay)+float(values.fall)+float(values.linger)+0.3
			records.BossTechniqueDefinition.append(row)
			var rain := {"id":phase,"technique":phase,"projectile":1}
			for key in ["traces","arrows_per_step"]: rain[key] = int(values[key])
			for key in ["arrow_gap","circle_radius","drop_delay","drop_height","fade","fall","forward","linger","trace_bend","trace_gap","trace_length","trace_speed"]: rain[key] = float(values[key])
			var fan: BossTechnique = load("res://data/bosses/centaurus_moves/fan_volley.tres")
			rain.arrow_radius = fan.radius
			rain.arrow_length = fan.length
			records.CentaurusRainDefinition.append(rain)
			records.BossTechniqueStage.append({"id":records.BossTechniqueStage.size()+1,"technique":phase,"command":6,"at":row.warn})
		elif move.technique==&"rear_attack":
			row.active = float(values.active)
			records.BossTechniqueDefinition.append(row)
			records.CentaurusRearDefinition.append({"id":phase,"technique":phase,"back_offset":float(values.back_offset),"radius":float(values.range_radius)})
			records.BossTechniqueStage.append({"id":records.BossTechniqueStage.size()+1,"technique":phase,"command":5,"at":row.warn})
			records.BossTechniqueStage.append({"id":records.BossTechniqueStage.size()+1,"technique":phase,"command":4,"at":row.warn+row.active+0.05})
		else:
			var count: int = int(values.count)
			row.active = float(values.interval)*float(count-1)+0.05
			records.BossTechniqueDefinition.append(row)
			records.CentaurusVolleyDefinition.append({"id":phase,"technique":phase,"count":count,"interval":float(values.interval),"radius":float(values.radius),"travel":float(values.travel),"projectile":1})
			for k in count: records.BossTechniqueStage.append({"id":records.BossTechniqueStage.size()+1,"technique":phase,"command":3,"at":row.warn+float(values.interval)*k})
			records.BossTechniqueStage.append({"id":records.BossTechniqueStage.size()+1,"technique":phase,"command":4,"at":row.warn+row.active})
	return records

## 脚のコマと補間値を生成し、実行中に表示Resourceを参照しない。
static func centaurus_stomp_feet(animation: Resource, technique: int) -> Array:
	var frames: Array = animation.clips.get("stomp",[])
	if frames.is_empty(): frames = [{"pose":animation.poses.get("neutral",{}),"duration":0.02}]
	var out: Array = []
	for index in frames.size():
		var frame: Dictionary = frames[index]
		for leg in 2:
			var path: String = ["FrontLeftLeg","FrontRightLeg"][leg]
			var entry: Dictionary = frame.pose.get(path,animation.poses.get("neutral",{}).get(path,{}))
			var next: Dictionary = frames[mini(index+1,frames.size()-1)].pose.get(path,{})
			var pivot: Vector2 = animation.part_pivots.get(path,Vector2.ZERO)
			var origin: Vector2 = entry.get("pivot_origin",Vector2.ZERO)
			var position: Vector2 = entry.get("position",Vector2.ZERO)
			var scale: Vector2 = entry.get("scale",Vector2.ONE)
			var contact: Vector2 = Vector2(11.5 if leg==0 else 7.5,52.0)
			out.append({"id":out.size()+1,"technique":technique,"frame":index,"leg":leg,"duration":maxf(0.02,float(frame.get("duration",0.15))),"interpolate":bool(frame.get("interpolate",false)) and index<frames.size()-1 and not next.is_empty(),"pivot":animation.part_pivots.has(path) and entry.has("pivot_origin"),"x":position.x,"y":position.y,"scale_x":scale.x,"scale_y":scale.y,"rotation":float(entry.get("rotation",0.0)),"skew":float(entry.get("skew",0.0)),"pivot_x":pivot.x,"pivot_y":pivot.y,"origin_x":origin.x,"origin_y":origin.y,"contact_x":contact.x,"contact_y":contact.y})
	return out

## 個別移行済みの技を、共通本体と同じ制作入口へまとめる。
static func centaurus_technique_package(definition: BossDef, move: BossTechnique, config: GameConfig) -> Dictionary:
	var package := boss_body_package(definition,config)
	var records := centaurus_technique_records(definition,move)
	if package.is_empty() or records.is_empty(): return {}
	var offset: int = package.records.LightArrowDefinition.size()
	for style in records.LightArrowDefinition:
		style.id += offset
		package.records.LightArrowDefinition.append(style)
	for volley in records.CentaurusVolleyDefinition: volley.projectile += offset
	for rain in records.CentaurusRainDefinition: rain.projectile += offset
	for power in records.CentaurusPowerDefinition: power.projectile += offset
	for fan in records.CentaurusFanDefinition: fan.projectile += offset
	for shower in records.CentaurusShowerDefinition: shower.projectile += offset
	for key in records:
		if key!="LightArrowDefinition": package.records[key] = records[key]
	var arrow_scene: PackedScene = move.get("shot_visual")
	if move.technique in [&"shower_chase",&"shower_wall",&"shower_path"]: arrow_scene = load("res://data/bosses/centaurus_moves/fan_volley.tres").shot_visual
	for scene: PackedScene in [arrow_scene,move.visual]:
		if scene==null: continue
		var asset: int = package.records.ResourceKey.size()+1
		package.records.ResourceKey.append({"id":asset,"role":7})
		package.visuals.append({"id":asset,"role":7,"path":scene.resource_path})
	return package

## 複数の技を同じボスの定義表へまとめる。実行は既存の型付きフローへ任せる。
static func boss_technique_set_records(definition: BossDef, moves: Array) -> Dictionary:
	var records := {"BossDefinition":[],"BossTechniqueDefinition":[],"BossTechniqueStage":[]}
	var seen := {}
	for move: BossTechnique in moves:
		if move==null or seen.has(move.technique): return {}
		seen[move.technique] = true
		var source := boss_technique_records(definition,move)
		if source.is_empty(): return {}
		var offset: int = records.BossTechniqueDefinition.size()
		if records.BossDefinition.is_empty(): records.BossDefinition = source.BossDefinition
		for row: Dictionary in source.BossTechniqueDefinition:
			row.id += offset
			records.BossTechniqueDefinition.append(row)
		for row: Dictionary in source.BossTechniqueStage:
			row.id = records.BossTechniqueStage.size()+1
			row.technique += offset
			records.BossTechniqueStage.append(row)
	return records

## 共通本体の生成入力。技の登録は各ボスの移植経路が追加する。
static func boss_body_package(definition: BossDef, config: GameConfig) -> Dictionary:
	if definition==null or definition.id not in [&"monoceros",&"centaurus",&"canis_major"]: return {}
	# 機体・装備・接触など共通セクションの生成を既存の入口へそろえる。
	var package := chase_package(load("res://data/enemies/defender.tres" if definition.id==&"centaurus" else "res://data/enemies/hound.tres" if definition.id==&"canis_major" else "res://data/enemies/drifter.tres"),config)
	if package.is_empty(): return {}
	var data: Dictionary = package.records
	var row: Dictionary = data.EnemyRecord[0]
	if definition.id in [&"centaurus",&"canis_major"]:
		row = row.duplicate(true)
		row.id = 2
		data.EnemyRecord.append(row)
		data.StringEntry.append({"id":2,"value":String(definition.id)})
		data.DefinitionIndex.append({"id":2,"enemy":2})
		data.PopulationType.append({"id":2,"enemy":2,"rank":5,"maximum":1,"ranged":false})
	var hp: float = definition.hp if definition.use_def_stats else config.boss_hp
	var armor: float = definition.armor if definition.use_def_stats else config.boss_armor
	row.kind = 39 if definition.id==&"monoceros" else 40 if definition.id==&"centaurus" else 41
	row.radius = definition.radius*config.character_scale
	row.hp = hp*config.enemy_hp_mult
	row.armor = armor*config.enemy_armor_mult
	row.speed = definition.speed
	row.turn = definition.turn
	row.xp = 0.0
	row.scaling_radius = definition.radius
	row.scaling_hp = hp
	row.scaling_armor = armor
	row.scaling_hp_mult = config.enemy_hp_mult
	row.scaling_armor_mult = config.enemy_armor_mult
	row.scaling_character = config.character_scale
	row.scaling_visual = 1.0
	row.scaling_collision = 1.0
	row.fixed_sprite = true
	row.knockback = 0.0
	row.gate = 0
	data.StringEntry[row.id-1].value = String(definition.id)
	var boss := {"id":1,"external_id":String(definition.id),"kind":0 if definition.id==&"monoceros" else 1 if definition.id==&"centaurus" else 2,"turn":definition.turn,"speed":definition.speed}
	for key in ["lock_lead","horn_width","horn_length_ratio","horn_length_ratio_p2","near_clearance","reposition_time","stuck_time","extract_time","extract_speed","approach_range","approach_speed","kick_trigger_arc"]: boss[key] = float(definition.params.get(key,0.0))
	data.BossDefinition = [boss]
	var body := {"id":1,"boss":1,"enemy":row.id,"hp_floor_enabled":false}
	for key in ["entrance_time","initial_wait","phase_threshold","phase_time","final_beam_width","final_reach","final_warn_width","final_widen_time"]:
		if not definition.params.has(key): return {}
		body[key] = float(definition.params[key])
	data.BossBodyDefinition = [body]
	if definition.id==&"centaurus":
		var centaurus := {"id":1,"body":1,"guard":1}
		for field in Schema.SCHEMA.records.filter(func(value): return value.name=="CentaurusBodyDefinition")[0].fields:
			if field.name in ["id","body","guard"]: continue
			if not definition.params.has(field.name): return {}
			centaurus[field.name] = definition.params[field.name]
		data.CentaurusBodyDefinition = [centaurus]
		# 守る雑魚にも通常ステージと同じ塗装・照明の生成済み参照を渡す。
		var guard: EnemyDef = load("res://data/enemies/defender.tres")
		var guard_visual: Dictionary = package.visuals[5]
		if guard_visual.role==6:
			var look: EnemyLook = load(guard_visual.path)
			var lighting: Resource = load("res://data/visuals/enemy_lighting.tres")
			var settings := {}
			for name in ["key_energy","fill_energy","key_angle","fill_angle","height","ambient","normal_strength"]: settings[name] = guard.visual_value(name,lighting.get(name))
			guard_visual.merge({"settings":settings,"paint":look.colors_key(guard.armor_colors),"hull_preview":look.preview_key(guard.armor_colors),"biting":false,"pump":false,"biter_parts":""})
	if definition.id==&"canis_major":
		var canis := {"id":1,"boss":1,"hound":1}
		for key in ["speed_p2","entrance_bark","call_time","call_cd","lead_radius","lead_scan","lead_catch_up","led_hits","slot_back","slot_side","form_wobble","lane_open","lane_forward","form_speed_min","form_speed_max"]: canis[key] = float(definition.params[key])
		for key in ["pack_size","call_below","call_to","lead_max"]: canis[key] = int(definition.params[key])
		var color: Color = definition.params.led_color
		canis.merge({"led_r":color.r,"led_g":color.g,"led_b":color.b,"led_a":color.a})
		data.CanisBodyDefinition = [canis]
		for name in ["sirius","sirius_flame","blaze"]:
			var move: BossTechnique = load("res://data/bosses/canis_major_moves/%s.tres" % name)
			for phase in [1,2]:
				var values: Dictionary = move.values().duplicate(true)
				if phase==2:
					for field: String in move.values():
						if field.ends_with("_p2"): values[field.trim_suffix("_p2")] = move.values()[field]
				var profile := {"id":data.CanisFlameDefinition.size()+1,"boss":1,"external_id":name,"phase":phase,"kind":0 if name=="sirius" else 1 if name=="sirius_flame" else 2}
				for field in ["particle_life","length","width","duration","damage","spread","speed","drag","r_start","r_end","hit_scale","trail_delay","trail_life","trail_width","trail_damage"]: profile[field] = 0.0
				if name=="sirius":
					profile.merge({"particle_life":float(values.get("beam_particle_life",0.65)),"length":float(values.beam_length),"width":float(values.beam_width),"duration":float(values.beam_time),"damage":float(values.damage),"trail_delay":float(values.trail_delay),"trail_life":float(values.trail_time),"trail_width":float(values.trail_width),"trail_damage":float(values.trail_damage)},true)
				elif name=="sirius_flame":
					for pair in [["particle_life","life"],["duration","duration"],["damage","damage"],["spread","spread"],["speed","particle_speed"],["drag","drag"],["r_start","r_start"],["r_end","r_end"],["hit_scale","hit_scale"]]: profile[pair[0]] = float(values[pair[1]])
				else: profile.merge({"particle_life":float(values.ignite_step),"duration":float(values.ignite_step)},true)
				data.CanisFlameDefinition.append(profile)
				var preset: Resource = values.flame_settings if name=="sirius" else load("res://data/visuals/canis_fire_flame.tres" if name=="sirius_flame" else "res://data/visuals/canis_fire_ignite.tres")
				var visual: int = data.ResourceKey.size()+1
				data.ResourceKey.append({"id":visual,"role":7})
				package.visuals.append({"id":visual,"role":7,"path":preset.resource_path,"canis_flame":profile.id})
		var trail_visual: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":trail_visual,"role":7})
		package.visuals.append({"id":trail_visual,"role":7,"path":"res://data/visuals/canis_fire_trail.tres","canis_trail":true})
		var hound: EnemyDef = load("res://data/enemies/hound.tres")
		var hound_visual: Dictionary = package.visuals[5]
		if hound_visual.role==6:
			var look: EnemyLook = load(hound_visual.path)
			var lighting: Resource = load("res://data/visuals/enemy_lighting.tres")
			var settings := {}
			for name in ["key_energy","fill_energy","key_angle","fill_angle","height","ambient","normal_strength"]: settings[name] = hound.visual_value(name,lighting.get(name))
			hound_visual.merge({"settings":settings,"paint":look.colors_key(hound.armor_colors),"hull_preview":look.preview_key(hound.armor_colors),"biting":false,"pump":false,"biter_parts":""})
	var key: int = data.ResourceKey.size()+1
	data.ResourceKey.append({"id":key,"role":7})
	package.visuals.append({"id":key,"role":7,"path":"res://scenes/bosses/%s_presentation.tscn" % definition.id,"boss":String(definition.id),"appearance":definition.part_appearance.duplicate(true)})
	return package

## 実制作の技・条件・フローと、ラン共通の決着の値を同じ生成へまとめる。
static func boss_package(definition: BossDef, config: GameConfig, stage: RuntimeStage = null) -> Dictionary:
	if definition==null or definition.id!=&"monoceros": return {}
	var package := boss_body_package(definition,config)
	if package.is_empty(): return {}
	var rules = load("res://data/bosses/ai/monoceros_action_rules.tres")
	var flow = load("res://data/bosses/ai/monoceros_flow.tres")
	var techniques := boss_technique_set_records(definition,rules.techniques)
	if techniques.is_empty(): return {}
	for key in techniques: package.records[key] = techniques[key]
	var compiled := boss_flow_records(rules,flow,techniques.BossTechniqueDefinition)
	if compiled.is_empty(): return {}
	for key in compiled: package.records[key] = compiled[key]
	package.records.RunConfig[0].time_limit = stage.time_limit if stage!=null else -1.0
	package.records.LifecycleDefinition[0].legendary = String(stage.legendary_module_id) if stage!=null else ""
	var finish := {"id":1,"time_up_charge_time":config.time_up_charge_time}
	for key in ["replay_window","slow_time","zoom","blast_time","relic_appear_time","relic_hold_time","relic_collect_time","clear_time"]: finish[key] = config.get("boss_finish_"+key)
	package.records.BossFinishDefinition = [finish]
	if stage!=null and not stage.legendary_module_id.is_empty():
		var definition_resource = ContentManager.definition(&"legendary_modules",stage.legendary_module_id)
		if definition_resource==null: return {}
		for value in [{"path":"res://scenes/run/legendary_reveal.tscn","purpose":"reveal"},{"path":definition_resource.resource_path,"purpose":"legendary"}]:
			var key: int = package.records.ResourceKey.size()+1
			package.records.ResourceKey.append({"id":key,"role":Schema.ENUMS.VisualRole.BossFinish})
			value.id = key
			value.role = Schema.ENUMS.VisualRole.BossFinish
			package.visuals.append(value)
	return package

static func _flow_condition(records: Dictionary, gate: Dictionary) -> int:
	for key in gate:
		if key not in ["min","max","angle","half_angle","min_phase"]: return 0
	var id: int = records.BossFlowCondition.size()+1
	records.BossFlowCondition.append({"id":id,"minimum":float(gate.get("min",0.0)),"maximum":float(gate.get("max",100000.0)),"angle":deg_to_rad(float(gate.get("angle",0.0))),"half_angle":deg_to_rad(float(gate.get("half_angle",180.0))),"minimum_phase":int(gate.get("min_phase",1))})
	return id

static func _flow_node(records: Dictionary, node: Dictionary, rules: Resource, techniques: Dictionary, depth := 0) -> int:
	if depth>24 or node.get("type","") not in ["wait","action","sequence","parallel","branch"]: return 0
	var id: int = records.BossFlowNode.size()+1
	var row := {"id":id,"flow":1,"kind":["wait","action","sequence","parallel","branch"].find(node.type),"seconds":float(node.get("seconds",0.0)),"technique":0,"condition":0,"participant":int(node.get("participant",0))}
	if node.type=="action":
		if not techniques.has(String(node.get("id",""))): return 0
		row.technique = techniques[String(node.id)]
		row.condition = _flow_condition(records,rules.conditions.get(String(node.id),{}))
	elif node.type=="branch": row.condition = _flow_condition(records,node.get("condition",{}))
	if node.type in ["action","branch"] and row.condition==0: return 0
	records.BossFlowNode.append(row)
	var children: Array = node.get("children",[])
	if (node.type in ["sequence","parallel"] and children.is_empty()) or (node.type=="branch" and children.size()!=2): return 0
	for i in children.size():
		var child := _flow_node(records,children[i],rules,techniques,depth+1)
		if child==0: return 0
		records.BossFlowChild.append({"id":records.BossFlowChild.size()+1,"parent":id,"child":child,"order":i})
	return id

## フローの条件と木を索引へ変換する。Script・Callable・任意条件名は持ち込まない。
static func boss_flow_records(rules: Resource, flow: Resource, techniques: Array) -> Dictionary:
	if rules==null or flow==null or not BossProgram.validate({"rules":rules,"flow":flow}).is_empty(): return {}
	var records := {}
	for record in Schema.SCHEMA.records:
		if record.name.begins_with("BossFlow"): records[record.name] = []
	var ids := {}
	for technique in techniques:
		if technique.phase==1: ids[String(technique.external_id)] = technique.id
	for move in rules.techniques:
		if not ids.has(String(move.technique)): return {}
	records.BossFlowProgram = [{"id":1,"boss":1,"maximum_stamina":flow.maximum_stamina,"partial_rest":flow.partial_rest,"empty_rest":flow.empty_rest,"idle_only":rules.adapter in [&"monoceros",&"centaurus"],"allow_parallel":rules.allow_parallel_attacks,"has_bias":not rules.selection_bias.is_empty()}]
	var sources: Array = rules.techniques.map(func(move): return String(move.technique)) + rules.combos.keys()
	for source in sources:
		var combo: bool = rules.combos.has(source)
		var move: BossTechnique
		if not combo:
			for candidate in rules.techniques:
				if String(candidate.technique)==source: move = candidate
		for entry in rules.active_gate_entries_for(source):
			var gate: int = _flow_condition(records,entry.gate)
			if gate==0: return {}
			var node := _flow_node(records,rules.combos[source] if combo else {"type":"action","id":source},rules,ids)
			if node==0: return {}
			if not combo: records.BossFlowNode[node-1].condition = gate
			var category: int = ["normal","combo","major"].find(entry.category)
			if category<0: return {}
			records.BossFlowAction.append({"id":records.BossFlowAction.size()+1,"flow":1,"external_id":source,"node":node,"condition":gate,"category":category,"label":category,"group":entry.group,"cost":float(rules.costs.get(source,2.0 if combo else 1.0)),"weight":float(rules.selection_bias.get(source,1.0)),"post_gap":0.0 if combo else move.post_gap,"exclusive":true})
	for i in flow.sections.size():
		var section: Dictionary = flow.sections[i]
		var id: int = i+1
		records.BossFlowSection.append({"id":id,"flow":1,"order":i,"request":["normal","major","rest","any"].find(section.get("request","normal")),"cap":float(section.get("cap",flow.maximum_stamina)),"has_budget":section.has("section_budget"),"budget":float(section.get("section_budget",0.0)),"action_count":int(section.get("action_count",1)),"action_interval":float(section.get("action_interval",0.0)),"has_timeout":section.has("no_candidate_timeout"),"timeout":float(section.get("no_candidate_timeout",0.0)),"has_fallback":section.has("fallback"),"fallback":int(section.get("fallback",0)),"next":int(section.get("next",(i+1)%flow.sections.size())),"filter_groups":section.has("allowed_groups") or section.has("allowed_categories"),"filter_allowed":section.has("allowed_techniques"),"avoid_repeat":section.get("avoid_repeat",true)})
		for key in ["allowed_groups","allowed_categories","allowed_techniques","excluded_techniques"]:
			for value in section.get(key,[]): records.BossFlowFilter.append({"id":records.BossFlowFilter.size()+1,"section":id,"kind":["allowed_groups","allowed_categories","allowed_techniques","excluded_techniques"].find(key),"value":String(value)})
		var policies := [{"previous":-1,"weights":section.get("weights",{"single":100.0})}]
		var previous_seen := []
		for policy in section.get("probability_rules",[]):
			var previous: int = ["single","combo","major","parallel"].find(policy.get("previous",""))
			if previous<0 or previous in previous_seen: continue
			previous_seen.append(previous)
			policies.append({"previous":previous,"weights":policy.weights})
		for policy in policies:
			if policy.previous>=0 and policy.weights.is_empty(): records.BossFlowWeight.append({"id":records.BossFlowWeight.size()+1,"section":id,"previous":policy.previous,"category":0,"weight":0.0})
			for category in policy.weights:
				var kind: int = ["single","combo","major","parallel"].find(category)
				if kind<0: return {}
				records.BossFlowWeight.append({"id":records.BossFlowWeight.size()+1,"section":id,"previous":policy.previous,"category":kind,"weight":float(policy.weights[category])})
		for pair in section.get("forbidden",[]): records.BossFlowForbidden.append({"id":records.BossFlowForbidden.size()+1,"section":id,"left":String(pair[0]),"right":String(pair[1])})
	return records

static func chase_package(definition: EnemyDef, config: GameConfig, stage: RuntimeStage = null) -> Dictionary:
	if definition == null or definition.behavior not in [&"chase",&"shield",&"biter",&"hound",&"meteor",&"obstacle",&"saw",&"gunner",&"beamer",&"missile",&"rocket",&"drift",&"part",&"dash",&"battleship",&"sniper",&"marlin",&"pulser",&"dolphin",&"lynx",&"soldier",&"auriga",&"clock",&"reticle",&"aquarius",&"cross",&"bomber",&"phoenix",&"aquila",&"split",&"defender",&"crab",&"crow",&"cepheus",&"pump",&"triangle_star",&"corona",&"ruler",&"triangle"]: return {}
	var resolved := Legacy.compile_enemy(definition,config,stage)
	if resolved.is_empty(): return {}
	var source: Dictionary = resolved.enemies[0]
	var row := {"id":1,"kind":{&"chase":0,&"shield":1,&"biter":2,&"hound":3,&"meteor":4,&"obstacle":5,&"saw":6,&"gunner":7,&"beamer":8,&"missile":9,&"rocket":10,&"drift":11,&"part":12,&"dash":13,&"battleship":14,&"sniper":15,&"marlin":16,&"pulser":17,&"dolphin":18,&"lynx":19,&"soldier":20,&"auriga":21,&"clock":22,&"reticle":23,&"aquarius":24,&"cross":25,&"bomber":28,&"phoenix":29,&"aquila":30,&"split":26,&"defender":27,&"crab":34,&"crow":37,&"cepheus":31,&"pump":35,&"triangle_star":32,&"corona":36,&"ruler":33,&"triangle":38}[definition.behavior],"turn":source.turn}
	for key in ["hp","armor","radius","speed","fire_interval","xp","knockback","hitstop_multiplier","gate","gate_arc"]:
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
	data.HeroConfig = [{"id":1,"scale":config.hero_scale,"glow_range":config.hero_glow_range,"guard_range":config.hero_guard_range,"star_radius":config.hero_star_radius,"next_time":config.hero_next_time,"spacing":config.landmark_spacing,"first_min":config.landmark_first_window.x,"first_max":config.landmark_first_window.y,"second_min":config.landmark_second_window.x,"second_max":config.landmark_second_window.y,"guards":config.hero_guards}]
	for definition_hero: HeroDef in ContentManager.heroes.values():
		var hero_id: int = data.HeroDefinition.size()+1
		data.HeroDefinition.append({"id":hero_id,"external_id":String(definition_hero.id),"stage":definition_hero.stage,"cooldown":definition_hero.cooldown,"duration":definition_hero.duration})
		if definition_hero.id==&"hercules":
			var fire := {"id":data.HerculesDefinition.size()+1,"hero":hero_id}
			for key in ["interval","fall_time","power","radius","burn_time","burn_power"]: fire[key] = float(definition_hero.params[key])
			data.HerculesDefinition.append(fire)
		if definition_hero.id==&"gemini": data.GeminiDefinition.append({"id":data.GeminiDefinition.size()+1,"hero":hero_id})
		if definition_hero.id==&"leo": data.LeoDefinition.append({"id":data.LeoDefinition.size()+1,"hero":hero_id,"width_mult":float(definition_hero.params.width_mult)})
		if definition_hero.id==&"perseus": data.PerseusDefinition.append({"id":data.PerseusDefinition.size()+1,"hero":hero_id,"boss_stun":float(definition_hero.params.boss_stun)})
		for star in definition_hero.stars: data.HeroStar.append({"id":data.HeroStar.size()+1,"hero":hero_id,"x":star.x,"y":star.y})
		for link in range(0,definition_hero.links.size(),2): data.HeroLink.append({"id":data.HeroLink.size()+1,"hero":hero_id,"a":definition_hero.links[link],"b":definition_hero.links[link+1]})
	data.PopulationDefinition = [{"id":1,"active":false,"density":config.density_mult,"bonus_pop":config.bonus_pop,"boss_start":0.0,"recycle_scale":config.spawn_recycle_scale,"region_cap":config.spawn_region_cap,"margin":config.spawn_margin,"field_radius":config.field_radius,"planet_radius":config.planet_radius,"total_cap":config.spawn_total_cap,"refill_time":config.spawn_refill_time}]
	data.EncounterDefinition = [{"id":1,"active":false,"interval":5.0}]
	data.CometDefinition = [{"id":1,"interval_min":config.comet_interval_min,"interval_max":config.comet_interval_max,"speed":config.comet_speed,"rare_chance":config.rare_comet_chance,"rare_after":config.rare_comet_after,"rare_hp_mult":config.rare_comet_hp_mult,"warp_chance":config.warp_chance}]
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
	if definition.params.has("chain_power"):
		var chain := {"id":1,"power":float(definition.params.chain_power),"radius":float(definition.params.blast_radius),"delay":float(definition.params.blast_delay),"damage":float(definition.params.blast_dmg)}
		for value in chain.values():
			if not is_finite(value) or value<0.0: return {}
		data.DeathChainDefinition = [chain]
	data.PopulationType = [{"id":1,"enemy":1,"rank":definition.rank,"maximum":definition.max_alive,"ranged":definition.ranged}]
	if definition.behavior in [&"biter",&"hound",&"defender"]:
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
	if definition.behavior==&"triangle":
		var item: Dictionary=source.triangle.duplicate()
		item.id=1
		item.star=1
		data.TriangleDefinition=[item]
	if definition.behavior==&"ruler":
		var item: Dictionary=source.ruler.duplicate()
		item.id=1
		data.RulerDefinition=[item]
	if definition.behavior==&"cepheus":
		var item: Dictionary = source.cepheus.duplicate()
		item.id = 1
		item.soldier = 1
		data.CepheusDefinition = [item]
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
	if definition.behavior==&"corona":
		var item: Dictionary = source.corona.duplicate()
		item.id = 1
		data.CoronaDefinition = [item]
		data.CoronaType = source.corona_types.duplicate(true)
	if definition.behavior==&"pump":
		var item: Dictionary = source.pump.duplicate()
		item.id = 1
		data.PumpDefinition = [item]
	if definition.behavior==&"crab":
		var item: Dictionary = source.crab.duplicate()
		item.id = 1
		data.CrabDefinition = [item]
	if definition.behavior==&"aquila":
		var item: Dictionary = source.aquila.duplicate()
		item.id = 1
		data.AquilaDefinition = [item]
	if definition.behavior==&"phoenix":
		var item: Dictionary = source.phoenix.duplicate()
		item.id = 1
		data.PhoenixDefinition = [item]
	if definition.behavior==&"bomber":
		var item: Dictionary = source.bomber.duplicate()
		item.id = 1
		data.BomberDefinition = [item]
	if definition.behavior==&"cross":
		var item: Dictionary = source.cross_enemy.duplicate()
		item.id = 1
		data.CrossEnemyDefinition = [item]
	if definition.behavior==&"aquarius":
		var item: Dictionary = source.aquarius.duplicate()
		item.id = 1
		data.AquariusDefinition = [item]
	if definition.behavior==&"crow":
		var item: Dictionary = source.crow.duplicate()
		item.id = 1
		data.CrowDefinition = [item]
	if definition.behavior==&"defender":
		var item: Dictionary = source.defender.duplicate()
		item.id = 1
		data.DefenderDefinition = [item]
	if definition.behavior==&"split":
		var item: Dictionary = source.split.duplicate()
		item.id = 1
		item.child = 1
		data.SplitDefinition = [item]
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
	if definition.behavior==&"triangle_star": data.TriangleStarDefinition = [{"id":1}]
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
		if definition.behavior not in [&"chase",&"rocket",&"drift",&"part",&"dash",&"battleship",&"sniper",&"marlin",&"pulser",&"dolphin",&"lynx",&"soldier",&"auriga",&"clock",&"reticle",&"aquarius",&"cross",&"bomber",&"phoenix",&"aquila",&"split",&"defender",&"crab",&"crow",&"cepheus",&"pump",&"triangle_star",&"corona",&"ruler",&"triangle"]: return {}
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
	var kill_sonic := load("res://data/traits/T05_killSonic.tres") as TraitDef
	if kill_sonic==null: return {}
	var kill_sonic_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":kill_sonic_id,"kind":1,"maximum_level":config.trait_max_stacks,"external_id":"T05","comet_only":false})
	for level in range(1,config.trait_max_stacks+1):
		data.KillSonicDefinition.append({"id":level,"equipment":kill_sonic_id,"level":level,"kills":int(kill_sonic.params.kills_base+kill_sonic.params.kills_per*level),"limit":int(kill_sonic.params.limit_by_level[level-1]),"radius":float(kill_sonic.params.radius_base+kill_sonic.params.radius_per*level),"damage":float(kill_sonic.params.damage_base+kill_sonic.params.damage_per*level),"radius_decay":float(kill_sonic.params.radius_decay),"damage_decay":float(kill_sonic.params.damage_decay),"knock":float(kill_sonic.params.knock),"life":0.4})
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
	var flash_slash := load("res://data/weapons/W28_flashSlash.tres") as WeaponDef
	if flash_slash==null: return {}
	var flash_slash_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":flash_slash_id,"kind":0,"maximum_level":flash_slash.level_steps.size(),"external_id":"W28","comet_only":flash_slash.comet_only})
	for level in flash_slash.level_steps.size():
		data.FlashSlashDefinition.append({"id":level+1,"weapon":flash_slash_id,"level":level+1,"cuts":int(flash_slash.params.cuts_by_level[level]),"streaks":int(flash_slash.params.streaks_by_level[level]),"multiplier":float(flash_slash.params.mult_by_level[level]),"pause":float(flash_slash.params.pause),"sweep":float(flash_slash.params.sweep)})
	var afterimage := load("res://data/weapons/W27_afterimage.tres") as WeaponDef
	if afterimage==null: return {}
	var afterimage_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":afterimage_id,"kind":0,"maximum_level":afterimage.level_steps.size(),"external_id":"W27","comet_only":afterimage.comet_only})
	for level in afterimage.level_steps.size():
		data.AfterimageDefinition.append({"id":level+1,"weapon":afterimage_id,"level":level+1,"count":clampi(int(afterimage.params.echo_count_by_level[level]),1,8),"total":maxf(0.0,float(afterimage.params.echo_total_by_level[level])),"delay":clampf(float(afterimage.params.echo_delay),0.02,0.5)})
	var escort := load("res://data/weapons/W26_dashRangeDrone.tres") as WeaponDef
	if escort==null: return {}
	var escort_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":escort_id,"kind":0,"maximum_level":escort.level_steps.size(),"external_id":"W26","comet_only":escort.comet_only})
	for level in escort.level_steps.size():
		var values := {"id":level+1,"weapon":escort_id,"level":level+1,"count":int(escort.params.drones_per_side_by_level[level])*2,"damage":float(escort.params.damage_by_level[level]),"tail":float(escort.params.tail_by_level[level]),"hit_radius":float(escort.params.drone_hit_radius),"area_increment":float(config.post_max.increments.area) if config.post_max.target(escort.id).has("area") else 0.0}
		for key in ["deploy_distance","idle_spacing","idle_back","return_rate"]: values[key] = float(escort.params[key])
		data.DashRangeDroneDefinition.append(values)
	var interceptor := load("res://data/weapons/W25_interceptor.tres") as WeaponDef
	if interceptor==null: return {}
	var interceptor_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":interceptor_id,"kind":0,"maximum_level":interceptor.level_steps.size(),"external_id":"W25","comet_only":false})
	var interceptor_target: Dictionary = config.post_max.target(interceptor.id)
	for level in interceptor.level_steps.size():
		var values := {"id":level+1,"weapon":interceptor_id,"level":level+1,"damage":float(interceptor.params.damage_by_level[level]),"interval":float(interceptor.params.interval_by_level[level]),"count":int(interceptor.params.drones_by_level[level]),"burst":int(interceptor.params.burst_by_level[level]),"color":Color(interceptor.params.color).to_rgba32(),"minimum_ratio":config.post_max.minimum_time_ratio,"minimum_interval":config.post_max.minimum_interval}
		for key in ["burst_interval","range","orbit","orbit_speed","target_interval","shot_radius","shot_speed","life"]: values[key] = float(interceptor.params[key])
		for key in ["projectile","duration","interval"]: values[key+"_increment"] = float(config.post_max.increments.get({"projectile":"projectile_speed","interval":"weapon_interval"}.get(key,key),0.0)) if interceptor_target.has(key) else 0.0
		data.InterceptorDefinition.append(values)
	var contact_arc := load("res://data/weapons/W17_contactArc.tres") as WeaponDef
	if contact_arc==null: return {}
	var contact_arc_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":contact_arc_id,"kind":0,"maximum_level":contact_arc.level_steps.size(),"external_id":"W17","comet_only":contact_arc.comet_only})
	var arc_target: Dictionary = config.post_max.target(contact_arc.id)
	for level in contact_arc.level_steps.size():
		data.ContactArcDefinition.append({"id":level+1,"weapon":contact_arc_id,"level":level+1,"damage":float(contact_arc.params.damage)*(1.0+0.3*(contact_arc.level_steps[level]-1)),"range":float(contact_arc.params.range),"cooldown":float(contact_arc.params.cooldown),"chains":(level+1)*int(contact_arc.params.chains_per_level),"branches":int(contact_arc.params.branches_by_level[level]),"knock":160.0,"area_increment":float(config.post_max.increments.area) if arc_target.has("area") else 0.0,"knockback_increment":float(config.post_max.increments.knockback) if arc_target.has("knockback") else 0.0,"visual_life":load("res://data/visuals/effect_settings.tres").number("weapon/contactArc","visible_seconds",0.22)})
	var sonic := load("res://data/weapons/W08_sonic.tres") as WeaponDef
	if sonic==null: return {}
	var sonic_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":sonic_id,"kind":0,"maximum_level":sonic.level_steps.size(),"external_id":"W08","comet_only":sonic.comet_only})
	var sonic_target: Dictionary = config.post_max.target(sonic.id)
	for level in sonic.level_steps.size():
		var values := {"id":level+1,"weapon":sonic_id,"level":level+1,"damage":float(sonic.params.damage_by_level[level]),"speed":float(sonic.params.speed_by_level[level]),"area_increment":float(config.post_max.increments.area) if sonic_target.has("area") else 0.0,"duration_increment":float(config.post_max.increments.duration) if sonic_target.has("duration") else 0.0}
		for key in ["life","emit_spacing","min_speed","nose","distance","pulse","side_speed","back_speed","decay","damage_delay"]: values[key] = float(sonic.params[key])
		data.SonicDefinition.append(values)
	var contact_wave := load("res://data/weapons/W04_contactWave.tres") as WeaponDef
	if contact_wave==null: return {}
	var contact_wave_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":contact_wave_id,"kind":0,"maximum_level":contact_wave.level_steps.size(),"external_id":"W04","comet_only":contact_wave.comet_only})
	var contact_target: Dictionary = config.post_max.target(contact_wave.id)
	for level in contact_wave.level_steps.size():
		var tier: int = contact_wave.level_steps[level]
		data.ContactWaveDefinition.append({"id":level+1,"weapon":contact_wave_id,"level":level+1,"radius":float(contact_wave.params.radius)*(1.0+0.1*(tier-1)),"damage":float(contact_wave.params.damage)*(1.0+0.3*(tier-1)),"knock":float(contact_wave.params.knock),"area_increment":float(config.post_max.increments.area) if contact_target.has("area") else 0.0,"knockback_increment":float(config.post_max.increments.knockback) if contact_target.has("knockback") else 0.0})
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
	var knockback := load("res://data/weapons/W03_knockback.tres") as WeaponDef
	if knockback==null or config.post_max==null: return {}
	var knockback_id: int = data.LoadoutDefinition.size()+1
	data.LoadoutDefinition.append({"id":knockback_id,"kind":0,"maximum_level":knockback.level_steps.size(),"external_id":"W03","comet_only":false})
	var knockback_target: Dictionary = config.post_max.target(knockback.id)
	for level in knockback.level_steps.size():
		data.KnockbackDefinition.append({"id":level+1,"weapon":knockback_id,"level":level+1,"chance":float(knockback.params.chance_by_level[level]),"chain_limit":int(knockback.params.chain_limit_by_level[level]),"speed":float(knockback.params.speed),"life":float(knockback.params.life),"base_damage":config.hull_debris_damage,"base_attack":config.base_attack,"base_knock":config.hull_debris_knock,"base_life":config.hull_debris_life,"projectile_increment":float(config.post_max.increments.get("projectile_speed",0.0)) if knockback_target.has("projectile") else 0.0,"duration_increment":float(config.post_max.increments.get("duration",0.0)) if knockback_target.has("duration") else 0.0,"knockback_increment":float(config.post_max.increments.get("knockback",0.0)) if knockback_target.has("knockback") else 0.0,"area_increment":float(config.post_max.increments.get("area",0.0)) if knockback_target.has("area") else 0.0})
	if config.post_max==null: return {}
	data.PostMaxChargeDefinition = [{"id":1,"increment":float(config.post_max.increments.get("charge_time",0.0)),"minimum_ratio":config.post_max.minimum_time_ratio,"minimum_time":config.post_max.minimum_charge_time}]
	for comet_id in ContentManager.catalog.table(&"weapons"):
		var comet_entry: ContentEntry = ContentManager.catalog.find(&"weapons",StringName(comet_id))
		if not comet_entry.comet_only: continue
		var comet_weapon: WeaponDef = load(comet_entry.path)
		if comet_weapon==null: return {}
		var comet_equipment: int = data.LoadoutDefinition.size()+1
		data.LoadoutDefinition.append({"id":comet_equipment,"kind":0,"maximum_level":comet_weapon.level_steps.size(),"external_id":String(comet_weapon.id),"comet_only":true})
		if comet_weapon.id==&"W22":
			var post: Dictionary = config.post_max.target(comet_weapon.id)
			for level in comet_weapon.level_steps.size():
				var factor: float = 1.0+0.1*(comet_weapon.level_steps[level]-1)
				var values := {"id":level+1,"weapon":comet_equipment,"level":level+1,"damage":float(comet_weapon.params.damage)*(1.0+0.3*(comet_weapon.level_steps[level]-1)),"width":float(comet_weapon.params.width)*factor,"radius_factor":factor,"delay":0.18,"visual_life":preload("res://scripts/render/equipment/bipolar.gd").BEAM_SECONDS,"color":Color(comet_weapon.params.color).to_rgba32(),"area_increment":float(config.post_max.increments.area) if post.has("area") else 0.0,"knockback_increment":float(config.post_max.increments.knockback) if post.has("knockback") else 0.0}
				for key in ["life","knock","min_length"]: values[key] = float(comet_weapon.params[key])
				data.BipolarDefinition.append(values)
		if comet_weapon.id==&"W21":
			var post: Dictionary = config.post_max.target(comet_weapon.id)
			for level in comet_weapon.level_steps.size():
				var values := {"id":level+1,"weapon":comet_equipment,"level":level+1,"damage":float(comet_weapon.params.damage)*(1.0+0.3*(comet_weapon.level_steps[level]-1)),"interval":float(comet_weapon.params.interval)/(1.0+0.12*(comet_weapon.level_steps[level]-1)),"visible":int(comet_weapon.params.visible),"minimum_ratio":config.post_max.minimum_time_ratio,"minimum_interval":config.post_max.minimum_interval}
				for key in ["capture_radius","hold","follow","shot_speed","size_ref","life","knock","clump_spacing"]: values[key] = float(comet_weapon.params[key])
				for key in ["projectile","duration","knockback","area","interval"]: values[key+"_increment"] = float(config.post_max.increments.get({"projectile":"projectile_speed","interval":"weapon_interval"}.get(key,key),0.0)) if post.has(key) else 0.0
				data.MassTowDefinition.append(values)
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
	data.PostMaxWeaponPowerDefinition.append({"id":7,"equipment":knockback_id,"damage_increment":float(config.post_max.increments.get("weapon_damage",0.0)),"followup_increment":float(config.post_max.increments.get("followup",0.0)) if knockback_target.has("followup") else 0.0})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":contact_wave_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if contact_target.has("followup") else 0.0})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":sonic_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if sonic_target.has("followup") else 0.0})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":contact_arc_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if arc_target.has("followup") else 0.0})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":flash_slash_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(flash_slash.id).has("followup") else 0.0})
	var flash_slash_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W28")
	if flash_slash_entry==null: return {}
	for path in flash_slash_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":flash_slash_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":flash_slash_id,"asset":key})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":afterimage_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(afterimage.id).has("followup") else 0.0})
	var afterimage_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W27")
	if afterimage_entry==null: return {}
	for path in afterimage_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":afterimage_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":afterimage_id,"asset":key})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":escort_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(escort.id).has("followup") else 0.0})
	var escort_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W26")
	if escort_entry==null: return {}
	for path in escort_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":escort_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":escort_id,"asset":key})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":interceptor_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if interceptor_target.has("followup") else 0.0})
	var interceptor_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W25")
	if interceptor_entry==null: return {}
	for path in interceptor_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":interceptor_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":interceptor_id,"asset":key})
	var bipolar_weapon: int = data.BipolarDefinition[0].weapon
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":bipolar_weapon,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(&"W22").has("followup") else 0.0})
	var bipolar_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W22")
	if bipolar_entry==null: return {}
	for path in bipolar_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":bipolar_weapon})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":bipolar_weapon,"asset":key})
	var tow_weapon: int = data.MassTowDefinition[0].weapon
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":tow_weapon,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(&"W21").has("followup") else 0.0})
	var tow_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W21")
	if tow_entry==null: return {}
	for path in tow_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":tow_weapon})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":tow_weapon,"asset":key})
	var arc_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W17")
	if arc_entry==null: return {}
	for path in arc_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":contact_arc_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":contact_arc_id,"asset":key})
	var sonic_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W08")
	if sonic_entry==null: return {}
	for path in sonic_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":sonic_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":sonic_id,"asset":key})
	var contact_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W04")
	if contact_entry==null: return {}
	for path in contact_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":contact_wave_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":contact_wave_id,"asset":key})
	var knockback_entry: ContentEntry = ContentManager.catalog.find(&"weapons",&"W03")
	if knockback_entry==null: return {}
	for path in knockback_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":knockback_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":knockback_id,"asset":key})
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
	var kill_sonic_entry: ContentEntry = ContentManager.catalog.find(&"traits",&"T05")
	if kill_sonic_entry==null: return {}
	for path in kill_sonic_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":kill_sonic_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":kill_sonic_id,"asset":key})
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
	preload("res://tools/content/run_progression_data.gd").append(data,config)
	return {"records":data,"visuals":visuals}

static func chase_records(definition: EnemyDef, config: GameConfig, stage: RuntimeStage = null) -> Dictionary:
	return chase_package(definition,config,stage).get("records",{})

static func compile_chase(definition: EnemyDef, config: GameConfig, input_sha256: PackedByteArray) -> PackedByteArray:
	return Schema.write_content(chase_records(definition,config),input_sha256)

## 同じRuntimeStageから生成し、検査済みの版へ索引を最後に切り替える。
static func encounter_records(data: Dictionary, profile: Dictionary, enemy_ids: PackedStringArray) -> Error:
	data.EncounterDefinition = [{"id":1,"active":bool(profile.get("enabled",false)),"interval":maxf(0.5,float(profile.get("interval",5.0)))}]
	if not data.EncounterDefinition[0].active: return OK
	for phase in profile.get("phases",[]): data.EncounterPhase.append({"id":data.EncounterPhase.size()+1,"name":String(phase)})
	for source in profile.get("patterns",[]):
		if not source is Dictionary: return ERR_INVALID_DATA
		var row := {"id":data.EncounterPattern.size()+1,"attempts":clampi(int(source.get("attempts",8)),1,32),"min_fodder":maxi(0,int(source.get("min_fodder",0)))}
		for pair in [["margin",20.0],["window",0.0],["draw_seconds",0.5],["exit_clearance",0.0],["rotation",PI],["scale_min",0.8],["scale_max",1.0],["min_spacing",0.0]]: row[pair[0]] = float(source.get(pair[0],pair[1]))
		data.EncounterPattern.append(row)
		for point in source.get("route",[]):
			if not point is Array or point.size()!=2: return ERR_INVALID_DATA
			data.EncounterPoint.append({"id":data.EncounterPoint.size()+1,"pattern":row.id,"x":float(point[0]),"y":float(point[1])})
		for region in source.get("regions",[]):
			if not region is Dictionary or not region.get("pos",[]) is Array or region.pos.size()!=2: return ERR_INVALID_DATA
			var type := String(region.get("type",""))
			if not ContentManager.enemies.has(StringName(type)) and not ContentManager.bosses.has(StringName(type)): return ERR_INVALID_DATA
			var minimum := clampi(int(region.get("min_count",1)),0,100)
			data.EncounterRegion.append({"id":data.EncounterRegion.size()+1,"pattern":row.id,"enemy":enemy_ids.find(type)+1,"x":float(region.pos[0]),"y":float(region.pos[1]),"angle":float(region.get("angle",0.0)),"jitter":float(region.get("jitter",0.0)),"min_count":minimum,"max_count":clampi(int(region.get("max_count",1)),minimum,100),"fodder":region.get("role","avoid")=="fodder","elite":bool(region.get("elite",false))})
	return OK

## 実験場のボスも、個別制作で使う型付きパッケージを同じ表へ加える。
static func append_bosses(data: Dictionary, visuals: Array[Dictionary], definitions: Dictionary, config: GameConfig, stage: RuntimeStage) -> Error:
	var ids := definitions.keys()
	ids.sort()
	for id in ids:
		var package := boss_package(definitions[id],config,stage)
		if package.is_empty(): return ERR_UNAVAILABLE
		var source: Dictionary = package.records
		var maps := {"EnemyRecord":{}}
		for body: Dictionary in source.BossBodyDefinition:
			var enemy: Dictionary = source.EnemyRecord[body.enemy-1].duplicate(true)
			var index: int = data.EnemyRecord.size()+1
			maps.EnemyRecord[enemy.id] = index
			enemy.id = index
			enemy.visual_id = data.EnemyRecord[0].visual_id
			data.EnemyRecord.append(enemy)
			data.StringEntry.append({"id":index,"value":String(id)})
			data.DefinitionIndex.append({"id":index,"enemy":index})
			data.PopulationType.append({"id":data.PopulationType.size()+1,"enemy":index,"rank":5,"maximum":1,"ranged":false})
			var hull: Dictionary = source.FriendHullLook[0].duplicate(true)
			hull.id = data.FriendHullLook.size()+1
			hull.enemy = index
			data.FriendHullLook.append(hull)
		for record: Dictionary in Schema.SCHEMA.records:
			if not String(record.name).begins_with("Boss"): continue
			maps[record.name] = {}
			for row: Dictionary in source[record.name]: maps[record.name][row.id] = data[record.name].size()+maps[record.name].size()+1
		for record: Dictionary in Schema.SCHEMA.records:
			if not String(record.name).begins_with("Boss"): continue
			for original: Dictionary in source[record.name]:
				var row := original.duplicate(true)
				row.id = maps[record.name][row.id]
				for field: Dictionary in record.fields:
					if field.has("ref"): row[field.name] = maps[field.ref][row[field.name]]
				if record.name=="BossFlowNode":
					if row.technique>0: row.technique = maps.BossTechniqueDefinition[row.technique]
					if row.condition>0: row.condition = maps.BossFlowCondition[row.condition]
				data[record.name].append(row)
		for original: Dictionary in package.visuals:
			if not original.has("boss") and original.role!=Schema.ENUMS.VisualRole.BossFinish: continue
			var visual := original.duplicate(true)
			visual.id = data.ResourceKey.size()+1
			data.ResourceKey.append({"id":visual.id,"role":visual.role})
			visuals.append(visual)
	return OK

static func build(stage: RuntimeStage, config: GameConfig, output: String, input_sha256: String, definitions := {}, extra_formations: Array = [], boss_definitions: Dictionary = {}) -> Error:
	if stage == null or stage.resources == null or input_sha256.length()!=64: return ERR_INVALID_DATA
	var data := {}
	var appearance_metadata := {}
	var equipment_resources: Array = []
	var visuals: Array[Dictionary] = []
	var field_visuals: Array = []
	var attack_visuals: Array = []
	for record in Schema.SCHEMA.records: data[record.name] = []
	var enemy_ids := stage.resources.enemy_ids.duplicate()
	var encounter_profile: Dictionary = stage.encounter_profile.duplicate(true)
	if encounter_profile.get("enabled",false):
		for path in encounter_profile.get("baseline",{}):
			if String(path).begins_with("res://data/stages/"): continue
			if not (String(path).begins_with("res://data/") or String(path).begins_with("res://scripts/") or String(path).begins_with("res://gyms/enemy_lab/")) or FileAccess.get_sha256(path)!=encounter_profile.baseline[path]:
				encounter_profile.enabled = false
				push_warning("採用した配置規則の基準が変わったため、既存の扱いに合わせて無効にします。")
				break
	if encounter_profile.get("enabled",false):
		for pattern in encounter_profile.get("patterns",[]):
			for region in pattern.get("regions",[]):
				var type := String(region.get("type",""))
				if ContentManager.enemies.has(StringName(type)) and not enemy_ids.has(type): enemy_ids.append(type)

	for terrain in ["meteor","iron","saw"]:
		if not terrain in enemy_ids: enemy_ids.append(terrain)
	for candidate_id: String in enemy_ids.duplicate():
		var candidate: EnemyDef = definitions.get(StringName(candidate_id))
		if candidate==null: candidate = load("res://data/enemies/%s.tres" % candidate_id)
		if candidate!=null and candidate.behavior==&"triangle" and not "triangle_star" in enemy_ids: enemy_ids.append("triangle_star")
		if candidate!=null and candidate.behavior==&"cepheus" and not "cepheus_soldier" in enemy_ids: enemy_ids.append("cepheus_soldier")
		if candidate!=null and candidate.behavior==&"split" and not "splitling" in enemy_ids: enemy_ids.append("splitling")
	for i in enemy_ids.size():
		var id: String = enemy_ids[i]
		var definition: EnemyDef = definitions.get(StringName(id))
		if definition == null:
			definition = ResourceLoader.load("res://data/enemies/%s.tres" % id,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyDef
		if definition == null or String(definition.id)!=id: return ERR_INVALID_DATA
		var tuning: Dictionary = stage.enemy_tuning.get(id,{})
		if not StageEnemyTuning.error_for(definition,tuning).is_empty(): return ERR_INVALID_DATA
		for key: String in tuning:
			data.EnemyTuningValue.append({"id":data.EnemyTuningValue.size()+1,"enemy":i+1,"key":key,"value":float(tuning[key])})
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
		for chain: Dictionary in resolved.DeathChainDefinition:
			chain.id = row.id
			data.DeathChainDefinition.append(chain)
		for bite: Dictionary in resolved.BiteDefinition:
			bite.id = row.id
			data.BiteDefinition.append(bite)
		for item: Dictionary in resolved.LynxDefinition:
			item.id = row.id
			data.LynxDefinition.append(item)
		for item: Dictionary in resolved.TriangleDefinition:
			item.id=row.id
			item.star=enemy_ids.find("triangle_star")+1
			data.TriangleDefinition.append(item)
		for item: Dictionary in resolved.RulerDefinition:
			item.id=row.id
			data.RulerDefinition.append(item)
		for item: Dictionary in resolved.CepheusDefinition:
			item.id = row.id
			item.soldier = enemy_ids.find("cepheus_soldier")+1
			data.CepheusDefinition.append(item)
		for item: Dictionary in resolved.SoldierDefinition:
			item.id = row.id
			data.SoldierDefinition.append(item)
		for item: Dictionary in resolved.AurigaDefinition:
			item.id = row.id
			data.AurigaDefinition.append(item)
		for item: Dictionary in resolved.ClockDefinition:
			item.id = row.id
			data.ClockDefinition.append(item)
		for item: Dictionary in resolved.CoronaDefinition:
			item.id = row.id
			data.CoronaDefinition.append(item)
		for item: Dictionary in resolved.CoronaType:
			item.id = data.CoronaType.size()+1
			item.owner = row.id
			data.CoronaType.append(item)
		for item: Dictionary in resolved.PumpDefinition:
			item.id = row.id
			data.PumpDefinition.append(item)
		for item: Dictionary in resolved.CrabDefinition:
			item.id = row.id
			data.CrabDefinition.append(item)
		for item: Dictionary in resolved.AquilaDefinition:
			item.id = row.id
			data.AquilaDefinition.append(item)
		for item: Dictionary in resolved.PhoenixDefinition:
			item.id = row.id
			data.PhoenixDefinition.append(item)
		for item: Dictionary in resolved.BomberDefinition:
			item.id = row.id
			data.BomberDefinition.append(item)
		for item: Dictionary in resolved.CrossEnemyDefinition:
			item.id = row.id
			data.CrossEnemyDefinition.append(item)
		for item: Dictionary in resolved.AquariusDefinition:
			item.id = row.id
			data.AquariusDefinition.append(item)
		for item: Dictionary in resolved.CrowDefinition:
			item.id = row.id
			data.CrowDefinition.append(item)
		for item: Dictionary in resolved.DefenderDefinition:
			item.id = row.id
			data.DefenderDefinition.append(item)
		for item: Dictionary in resolved.SplitDefinition:
			item.id = row.id
			data.SplitDefinition.append(item)
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
		for star: Dictionary in resolved.TriangleStarDefinition:
			star.id = row.id
			data.TriangleStarDefinition.append(star)
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
		data.HeroConfig = resolved.HeroConfig
		data.HerculesDefinition = resolved.HerculesDefinition
		data.GeminiDefinition = resolved.GeminiDefinition
		data.LeoDefinition = resolved.LeoDefinition
		data.PerseusDefinition = resolved.PerseusDefinition
		data.HeroDefinition = resolved.HeroDefinition
		data.HeroStar = resolved.HeroStar
		data.HeroLink = resolved.HeroLink
		data.RunConfig = resolved.RunConfig
		data.ContactDefinition = resolved.ContactDefinition
		data.BeamDefinition = resolved.BeamDefinition
		data.WaveDefinition = resolved.WaveDefinition
		data.PopulationDefinition = resolved.PopulationDefinition
		data.PopulationType.append({"id":row.id,"enemy":row.id,"rank":definition.rank,"maximum":definition.max_alive,"ranged":definition.ranged})
		data.CometDefinition = resolved.CometDefinition
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
			data.KnockbackDefinition = resolved.KnockbackDefinition
			data.MinesDefinition = resolved.MinesDefinition
			data.EndBlastDefinition = resolved.EndBlastDefinition
			data.InterceptorDefinition = resolved.InterceptorDefinition
			data.FlashSlashDefinition = resolved.FlashSlashDefinition
			data.AfterimageDefinition = resolved.AfterimageDefinition
			data.DashRangeDroneDefinition = resolved.DashRangeDroneDefinition
			data.BipolarDefinition = resolved.BipolarDefinition
			data.MassTowDefinition = resolved.MassTowDefinition
			data.ContactArcDefinition = resolved.ContactArcDefinition
			data.SonicDefinition = resolved.SonicDefinition
			data.ContactWaveDefinition = resolved.ContactWaveDefinition
			data.BarrierDefinition = resolved.BarrierDefinition
			data.BarrierPostDefinition = resolved.BarrierPostDefinition
			data.FullChargeDefinition = resolved.FullChargeDefinition
			data.KillSonicDefinition = resolved.KillSonicDefinition
			data.CritBeamDefinition = resolved.CritBeamDefinition
			data.VortexDefinition = resolved.VortexDefinition
			data.RunUpDefinition = resolved.RunUpDefinition
			data.RampageDefinition = resolved.RampageDefinition
			data.DuplicatorDefinition = resolved.DuplicatorDefinition
			data.ProgressionDefinition = resolved.ProgressionDefinition
			data.LifecycleDefinition = resolved.LifecycleDefinition
			for section in ["PostMaxDefinition","PostMaxTarget","PostMaxInterval","PostMaxChargeDefinition","PostMaxCritDefinition","PostMaxMotionDefinition","PostMaxWeaponPowerDefinition","PostMaxPickupDefinition","PostMaxDrawDefinition"]:
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
			appearance_metadata[visual.id] = {"settings":settings,"paint":look.colors_key(definition.armor_colors),"hull_preview":look.preview_key(definition.armor_colors),"biting":definition.behavior==&"biter","pump":definition.behavior==&"pump",
				"biter_parts":"res://data/visuals/biter_parts.tres" if id=="biter" and look.source_path=="res://data/visuals/looks/biter.tres" else ""}
			if definition.behavior==&"ruler":
				appearance_metadata[visual.id].ruler=true
				appearance_metadata[visual.id].lower_paint=look.split_other.colors_key(definition.armor_colors) if look.split_other!=null else ""
	for item: Dictionary in data.SplitDefinition:
		item.child = enemy_ids.find("splitling")+1
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


	var formation_enemy_indices := {}
	for enemy in data.StringEntry: formation_enemy_indices[StringName(enemy.value)] = enemy.id
	var clips := Legacy.compile_spawn_clips(stage,config)
	if clips.is_empty(): return ERR_INVALID_DATA
	# 実験場の手動配置の定義は、自動クリップを追加せず同じ生成形式へ通す。
	for source: Dictionary in extra_formations: clips.formations.append(Legacy.compile_formation(source))
	for formation: Dictionary in clips.formations:
		var formation_id: int = data.FormationDefinition.size()+1
		data.FormationDefinition.append({"id":formation_id,"base_view":config.base_view})
		var entry_ids: Array[int] = []
		for entry: Dictionary in formation.entries:
			var entry_id: int = data.FormationEntry.size()+1
			entry_ids.append(entry_id)
			data.FormationEntry.append({"id":entry_id,"formation":formation_id,"weight":entry.weight,"x":entry.pos.x,"y":entry.pos.y})
		for layout: Dictionary in formation.layouts:
			var layout_id: int = data.FormationLayout.size()+1
			data.FormationLayout.append({"id":layout_id,"formation":formation_id,"weight":layout.weight,"value":layout.value,"managed":-1 if layout.managed==null else int(bool(layout.managed))})
			for type in layout.types:
				if not formation_enemy_indices.has(StringName(type)): return ERR_UNAVAILABLE
				data.FormationType.append({"id":data.FormationType.size()+1,"layout":layout_id,"enemy":formation_enemy_indices[StringName(type)]})
			for e in layout.placements.size():
				for marker: Dictionary in layout.placements[e]:
					data.FormationMarker.append({"id":data.FormationMarker.size()+1,"layout":layout_id,"entry":entry_ids[e],"enemy":formation_enemy_indices[StringName(marker.type)],"x":marker.offset.x,"y":marker.offset.y,"rotation":marker.rotation})
	for clip: Dictionary in clips.clips:
		var clip_id: int = data.PopulationClip.size()+1
		data.PopulationClip.append({"id":clip_id,"start":clip.start,"end":clip.end if is_finite(clip.end) else -1.0,"interval":clip.interval,"groups":clip.groups,"priority":clip.priority})
		for type in clip.types:
			if not formation_enemy_indices.has(StringName(type)): return ERR_UNAVAILABLE
			data.PopulationClipType.append({"id":data.PopulationClipType.size()+1,"clip":clip_id,"enemy":formation_enemy_indices[StringName(type)]})
		for formation in clip.formations:
			data.PopulationClipFormation.append({"id":data.PopulationClipFormation.size()+1,"clip":clip_id,"formation":formation+1})

	var encounter_error := encounter_records(data,encounter_profile,enemy_ids)
	if encounter_error!=OK: return encounter_error
	var bosses_error := append_bosses(data,visuals,boss_definitions,config,stage)
	if bosses_error!=OK: return bosses_error
	var source_sha256 := input_sha256
	var paths := stage.resources.paths.duplicate()
	paths.append("res://.content/meteor_pieces.res")
	if not paths.has("res://.content/hero_aura.res"): paths.append("res://.content/hero_aura.res")
	for asset in ["res://scripts/render/attacks/friend_debris.gd","res://assets/pixel/pump.png","res://.content/attack_visuals.res","res://scripts/render/attacks/zone.gd","res://scripts/render/fx/blast_bursts.gd","res://scripts/render/attacks/flood.gd","res://shaders/water_flood.gdshader","res://assets/fx/water_noise.png","res://scripts/render/light_lance.gd","res://scripts/render/equipment/critBeam.gd","res://scripts/render/attacks/shell_frame.gd","res://shaders/pump_shell_runtime.gdshader"]:
		if not paths.has(asset): paths.append(asset)
	if not paths.has("res://assets/fx/light_arrow.svg"): paths.append("res://assets/fx/light_arrow.svg")
	for visual: Dictionary in visuals:
		if visual.role!=7 and not visual.path.is_empty() and not paths.has(visual.path): paths.append(visual.path)
	for metadata: Dictionary in appearance_metadata.values():
		if not metadata.biter_parts.is_empty() and not paths.has(metadata.biter_parts): paths.append(metadata.biter_parts)
	for asset in ["res://assets/pixel/airship_electronic_probe.png","res://assets/pixel/airship_blue_flame.png","res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png","res://assets/pixel/airship_turret_base.png","res://assets/pixel/airship_turret.png","res://assets/pixel/airship_armor.png","res://assets/pixel/airship_mine.png"]:
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
