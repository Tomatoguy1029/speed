## Resourceの実効値を解決し、共通スキーマの書込へ渡す。
@tool
extends RefCounted
const Schema = preload("res://tools/content/generated/run_schema.gd")
const AttackDefaults = preload("res://scripts/data_types/attack_defaults.gd")
const Legacy = preload("res://tools/content/build_native_data.gd")
const BossProgram = preload("res://tools/content/build_boss_program.gd")

## 固定試作の値と輪郭を、通常ステージと単独試行の同じ入力へ通す。
static func _prepare_reference_fx(data: Dictionary) -> Error:
	var error := preload("res://tools/content/build_enemy_fx.gd").apply(data)
	if error != OK: return error
	error = preload("res://tools/content/build_canis_fx.gd").apply(data)
	if error != OK: return error
	error = preload("res://tools/content/build_boss_image_fx.gd").apply(data)
	if error != OK: return error
	return preload("res://tools/content/build_canis_image_fx.gd").apply(data)

static func _write_reference_content(data: Dictionary, signature: PackedByteArray) -> PackedByteArray:
	if _prepare_reference_fx(data) != OK: return PackedByteArray()
	return Schema.write_content(data, signature)

## エディターの生成では実行中のAutoloadを使わず、保存済み制作資源を読む。
## ライブ編集は従来どおり、実行中の定義と索引を使う。
static func _catalog() -> ContentCatalog:
	return load("res://data/content_catalog.tres") as ContentCatalog if Engine.is_editor_hint() or ContentManager.catalog==null else ContentManager.catalog

static func _definition(category: StringName, id: StringName) -> Resource:
	if not Engine.is_editor_hint() and ContentManager.catalog!=null: return ContentManager.definition(category,id)
	var entry := _catalog().find(category,id)
	return load(entry.path) if entry!=null else null

static func _definitions(category: StringName) -> Dictionary:
	if Engine.is_editor_hint() or ContentManager.catalog==null: return _catalog().table(category)
	return ContentManager.enemies if category==&"enemies" else ContentManager.bosses

static func _heroes() -> Array:
	if not Engine.is_editor_hint() and ContentManager.catalog!=null: return ContentManager.heroes.values()
	var result := []
	for id in _catalog().table(&"heroes"): result.append(_definition(&"heroes",id))
	return result

static func _visual_index() -> StageResources:
	return load("res://.content/visual_index.tres") as StageResources if Engine.is_editor_hint() or ContentManager.visual_index==null else ContentManager.visual_index

## ボスも同じ値型のスキーマへ書く。Scriptと表示シーンは戦闘バイナリへ渡さない。
static func boss_technique_records(definition: BossDef, move: BossTechnique) -> Dictionary:
	if definition!=null and definition.id==&"draco": return draco_technique_records(definition,move)
	if definition!=null and definition.id==&"canis_major": return canis_technique_records(definition,move)
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

## ドラコはSourceの3形態を生成する。未登録技は生成エラーとして残す。
static func draco_technique_records(definition: BossDef, move: BossTechnique) -> Dictionary:
	if definition==null or definition.id!=&"draco" or move==null or move.technique not in [&"bite",&"breath",&"charge",&"leap",&"tail_slam",&"tail_sweep",&"star_fan",&"meteor",&"rifts",&"picaro_wall",&"inhale",&"spiral",&"clones"]: return {}
	var source: BossTechnique = BossProgram.snapshot(move)
	var boss := {"id":1,"external_id":"draco","kind":4,"turn":definition.turn,"speed":definition.speed}
	for key in ["lock_lead","horn_width","horn_length_ratio","horn_length_ratio_p2","near_clearance","reposition_time","stuck_time","extract_time","extract_speed","approach_range","approach_speed","kick_trigger_arc"]: boss[key] = 0.0
	var records := {"BossDefinition":[boss],"BossTechniqueDefinition":[],"BossTechniqueStage":[],"DracoBiteDefinition":[],"DracoBreathDefinition":[],"DracoChargeDefinition":[],"DracoLeapDefinition":[],"DracoTailSlamDefinition":[],"DracoTailSweepDefinition":[],"DracoStarFanDefinition":[],"DracoMeteorDefinition":[],"DracoClonesDefinition":[],"DracoRiftsDefinition":[],"DracoInhaleDefinition":[],"DracoInhaleArc":[],"DracoSpiralDefinition":[],"DracoPicaroWallDefinition":[],"DracoPicaroWallCandidate":[]}
	for phase in [1,2,3]:
		var values: Dictionary = source.values().duplicate(true)
		# Draco.rule()はSource上、形態別の値上書きを行わない。
		var row := {}
		for field in Schema.SCHEMA.records.filter(func(v):return v.name=="BossTechniqueDefinition")[0].fields: row[field.name] = false if field.type=="bool" else "" if field.type=="string" else 0
		row.merge({"id":phase,"boss":1,"external_id":str(source.technique),"kind":{&"bite":96,&"breath":97,&"charge":98,&"leap":99,&"tail_slam":100,&"tail_sweep":101,&"star_fan":102,&"meteor":103,&"clones":105,&"rifts":104,&"picaro_wall":106,&"inhale":108,&"spiral":107}[source.technique],"phase":phase,"track_during_warn":source.track_during_warn,"post_gap":source.post_gap,"passes":1,"cuts":1},true)
		for key in ["warn","active","recover","damage","reach","width"]: row[key] = float(values.get(key,0.0))
		records.BossTechniqueDefinition.append(row)
		if source.technique==&"bite": records.DracoBiteDefinition.append({"id":phase,"technique":phase,"lead_cap":float(values.lead_cap),"retract":float(values.retract)})
		elif source.technique==&"spiral":
			var detail := {"id":phase,"technique":phase}
			detail.radius_factor = float(values.radius_factor)
			detail.aspect_ratio = float(values.aspect_ratio)
			detail.inner_radius_factor = float(values.inner_radius_factor)
			detail.coil_time = float(values.coil_time)
			detail.pause = float(values.pause)
			detail.head_offset = float(values.head_offset)
			detail.exit_duration = float(values.exit_duration)
			detail.spiral_length = float(values.spiral_length)
			detail.shrink_time = float(values.shrink_time)
			detail.touch_invuln = float(values.touch_invuln)
			records.DracoSpiralDefinition.append(detail)
		elif source.technique==&"inhale":
			var detail := {"id":phase,"technique":phase}
			detail.inhale_time = float(values.inhale_time)
			detail.pull_range = float(values.pull_range)
			detail.pull_speed = float(values.pull_speed)
			detail.picaro_pull_speed = float(values.picaro_pull_speed)
			detail.mouth_radius = float(values.mouth_radius)
			detail.bite_damage = float(values.bite_damage)
			detail.beam_time = float(values.beam_time)
			detail.beam_extend = float(values.beam_extend)
			detail.beam_warn = float(values.beam_warn)
			detail.comets_per_star = int(values.comets_per_star)
			detail.comet_cap = int(values.comet_cap)
			detail.comet_speed = float(values.comet_speed)
			detail.projectile=1;detail.beam_definition=1
			records.DracoInhaleDefinition.append(detail)
			for arc: Resource in source.arcs:
				records.DracoInhaleArc.append({"id":records.DracoInhaleArc.size()+1,"technique":phase,"offset_x":arc.offset.x,"offset_y":arc.offset.y,"radius":arc.radius,"angle_degrees":arc.angle_degrees,"spread_degrees":arc.spread_degrees,"count":arc.count})
		elif source.technique==&"picaro_wall":
			var detail := {"id":phase,"technique":phase,"count":int(values.count),"arrows":int(values.arrows)}
			for key in ["interval","flight","impact_warn","radius"]: detail[key]=float(values[key])
			records.DracoPicaroWallDefinition.append(detail)
		elif source.technique==&"clones": records.DracoClonesDefinition.append({"id":phase,"technique":phase,"clone_enemy":1,"part_enemy":1,"hydra_source":1,"bite":1,"wind":1,"rubble":1,"beam":1,"thunder":1,"clone_hp":float(values.clone_hp),"clone_stars":int(values.clone_stars),"neck_rest":float(load("res://data/bosses/hydra.tres").params.neck_rest)})
		elif source.technique==&"rifts":
			var detail := {"id":phase,"technique":phase,"claw_count":int(values.claw_count)}
			for key in ["claw_angle","claw_gap","claw_offset","claw_overshoot","interval","scratch_time","scratch_width"]:detail[key]=float(values[key])
			records.DracoRiftsDefinition.append(detail)
		elif source.technique==&"meteor": records.DracoMeteorDefinition.append({"id":phase,"technique":phase,"rock_enemy":1,"rocks":int(values.rocks),"rock_distance":float(values.rock_distance),"rock_spacing":float(values.rock_spacing)})
		elif source.technique==&"star_fan": records.DracoStarFanDefinition.append({"id":phase,"technique":phase,"projectile":1,"lead_cap":float(values.lead_cap),"count":int(values.count),"arc":float(values.arc),"radius":float(values.radius),"speed":float(values.speed)})
		elif source.technique==&"tail_sweep": records.DracoTailSweepDefinition.append({"id":phase,"technique":phase,"half_angle":float(values.half_angle)})
		elif source.technique==&"tail_slam": records.DracoTailSlamDefinition.append({"id":phase,"technique":phase,"lead_cap":float(values.lead_cap),"radius":float(values.radius)})
		elif source.technique==&"leap": records.DracoLeapDefinition.append({"id":phase,"technique":phase,"lead_cap":float(values.lead_cap)})
		elif source.technique==&"charge": records.DracoChargeDefinition.append({"id":phase,"technique":phase,"lead_cap":float(values.lead_cap),"overshoot":float(values.overshoot)})
		else: records.DracoBreathDefinition.append({"id":phase,"technique":phase,"rock_enemy":1,"rocks":int(values.rocks),"rock_distance":float(values.rock_distance),"rock_spacing":float(values.rock_spacing),"half_angle":float(values.half_angle),"sweep":float(values.sweep)})
	return records

static func draco_set_records(definition: BossDef, moves: Array) -> Dictionary:
	var records := {"BossDefinition":[],"BossTechniqueDefinition":[],"BossTechniqueStage":[],"DracoBiteDefinition":[],"DracoBreathDefinition":[],"DracoChargeDefinition":[],"DracoLeapDefinition":[],"DracoTailSlamDefinition":[],"DracoTailSweepDefinition":[],"DracoStarFanDefinition":[],"DracoMeteorDefinition":[],"DracoClonesDefinition":[],"DracoRiftsDefinition":[],"DracoInhaleDefinition":[],"DracoInhaleArc":[],"DracoSpiralDefinition":[],"DracoPicaroWallDefinition":[],"DracoPicaroWallCandidate":[]}
	var seen := {}
	for move: BossTechnique in moves:
		if move==null or seen.has(move.technique): return {}
		seen[move.technique] = true
		var source := draco_technique_records(definition,move)
		if source.is_empty(): return {}
		if records.BossDefinition.is_empty(): records.BossDefinition = source.BossDefinition
		var offset: int = records.BossTechniqueDefinition.size()
		for row: Dictionary in source.BossTechniqueDefinition:
			row.id += offset
			records.BossTechniqueDefinition.append(row)
		for key in source:
			if key in ["BossDefinition","BossTechniqueDefinition"]: continue
			for row: Dictionary in source[key]:
				row.id = records[key].size()+1
				row.technique += offset
				records[key].append(row)
	return records

static func draco_technique_package(definition: BossDef, move: BossTechnique, config: GameConfig) -> Dictionary:
	var package := boss_body_package(definition,config)
	var records := draco_technique_records(definition,move)
	if package.is_empty() or records.is_empty(): return {}
	for key in records: package.records[key] = records[key]
	if move.technique in [&"breath",&"meteor"]: append_draco_breath_rock(package,move,config)
	if move.technique==&"star_fan": append_draco_star_bolt(package,move)
	if move.technique==&"inhale": append_draco_inhale_bolt(package,move)
	if move.technique==&"picaro_wall": append_draco_picaro_wall(package,move,config)
	if move.technique==&"clones": append_draco_clones(package,move,config)
	append_draco_style(package,move)
	if _prepare_reference_fx(package.records) != OK: return {}
	return package

## 通常隕石から独立した投石定義を、固定報酬の正規解決で生成する。
static func append_draco_breath_rock(package: Dictionary, move: BossTechnique, config: GameConfig) -> void:
	var definition: EnemyDef = load("res://data/enemies/meteor.tres").duplicate(true)
	definition.hp = float(move.rock_hp);definition.stage_hp = definition.hp
	definition.radius = float(move.rock_radius);definition.speed = 0.0
	definition.xp_reward_counts = PackedInt32Array([0,0,0])
	var source := chase_package(definition,config)
	var data: Dictionary = package.records
	var enemy: Dictionary = source.records.EnemyRecord[0].duplicate(true)
	enemy.id = data.EnemyRecord.size()+1
	# meteor_index付きのSourceはcharacter_scaleを掛けない。
	enemy.scaling_character = 1.0
	enemy.radius = enemy.scaling_radius*enemy.scaling_visual*enemy.scaling_collision
	var visual: Dictionary = source.visuals[enemy.visual_id-1].duplicate(true)
	visual.id = data.ResourceKey.size()+1
	enemy.visual_id = visual.id
	data.ResourceKey.append({"id":visual.id,"role":visual.role})
	package.visuals.append(visual)
	data.EnemyRecord.append(enemy)
	data.StringEntry.append({"id":enemy.id,"value":"draco_"+str(move.technique)+"_rock"})
	data.DefinitionIndex.append({"id":enemy.id,"enemy":enemy.id})
	var population: Dictionary = source.records.PopulationType[0].duplicate(true)
	population.id = data.PopulationType.size()+1;population.enemy=enemy.id
	data.PopulationType.append(population)
	var hull: Dictionary = source.records.FriendHullLook[0].duplicate(true)
	hull.id = data.FriendHullLook.size()+1;hull.enemy = enemy.id
	data.FriendHullLook.append(hull)
	for row in data["DracoMeteorDefinition" if move.technique==&"meteor" else "DracoBreathDefinition"]: row.rock_enemy = enemy.id

## 固定の描画設定は生成時に解決する。
static func append_draco_style(package: Dictionary, move: BossTechnique) -> void:
	var visual: Node2D = move.visual.instantiate()
	load("res://data/visuals/effect_settings.tres").apply_to(visual)
	var style := {}
	if move.technique==&"tail_sweep":
		for key in ["base_color","progress_color","outline_color","outline_width"]: style[key]=visual.get(key)
	else:
		style.visual_kind = String(visual.get("technique_id"))
		for key in ["telegraph_line_width","active_line_width","telegraph_fill_opacity","telegraph_progress_opacity","telegraph_edge_opacity","motion_trail_opacity","impact_lifetime","collapse_lifetime"]: style[key] = float(visual.get(key))
	visual.free()
	if move.technique==&"inhale":style.pull_range=float(move.pull_range)
	var appearance := {}
	for asset: Dictionary in package.visuals:
		if asset.get("boss","")=="draco": appearance=asset.appearance;break
	if not appearance.has("draco_styles"): appearance.draco_styles = {}
	appearance.draco_styles[str(move.technique)] = style

## 号令の実効値と、旧method trackに対応する段階を生成する。
static func canis_technique_records(definition: BossDef, move: BossTechnique) -> Dictionary:
	if move==null or move.technique not in [&"command",&"howl",&"pounce",&"sirius",&"bay",&"blaze",&"stream",&"hunt",&"hunt_pounce",&"nova",&"relay",&"sirius_flame"]: return {}
	var source: BossTechnique = BossProgram.snapshot(move)
	var boss := {"id":1,"external_id":"canis_major","kind":2,"turn":definition.turn,"speed":definition.speed}
	for key in ["lock_lead","horn_width","horn_length_ratio","horn_length_ratio_p2","near_clearance","reposition_time","stuck_time","extract_time","extract_speed","approach_range","approach_speed","kick_trigger_arc"]: boss[key] = 0.0
	var records := {"BossDefinition":[boss],"BossTechniqueDefinition":[],"BossTechniqueStage":[],"CanisCommandDefinition":[],"CanisHowlDefinition":[],"CanisPounceDefinition":[],"CanisSiriusDefinition":[],"CanisBayDefinition":[],"CanisBlazeDefinition":[],"CanisStreamDefinition":[],"CanisHuntDefinition":[],"CanisHuntPounceDefinition":[],"CanisNovaDefinition":[],"CanisRelayDefinition":[],"CanisSiriusFlameDefinition":[]}
	for phase in [1,2]:
		var values: Dictionary = source.values().duplicate(true)
		if phase==2:
			for key: String in source.values():
				if key.ends_with("_p2"): values[key.trim_suffix("_p2")] = source.values()[key]
		var row := {}
		for record in Schema.SCHEMA.records:
			if record.name!="BossTechniqueDefinition": continue
			for field in record.fields: row[field.name] = false if field.type=="bool" else "" if field.type=="string" else 0
		row.merge({"id":phase,"boss":1,"external_id":str(move.technique),"kind":40 if move.technique==&"command" else 41 if move.technique==&"howl" else 42 if move.technique==&"pounce" else 43 if move.technique==&"sirius" else 44 if move.technique==&"bay" else 45 if move.technique==&"blaze" else 46 if move.technique==&"stream" else 47 if move.technique==&"hunt" else 48 if move.technique==&"hunt_pounce" else 49 if move.technique==&"nova" else 50 if move.technique==&"relay" else 51,"phase":phase,"track_during_warn":source.track_during_warn,"post_gap":source.post_gap,"passes":1,"cuts":1},true)
		for key in ["warn","recover","cd","damage"]: row[key] = float(values.get(key,0.0))
		if move.technique==&"sirius_flame":
			row.active = float(values.duration)
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase,"flame":phase+2}
			for key in ["emit_rate","turn","advance","advance_until"]: detail[key] = float(values[key])
			records.CanisSiriusFlameDefinition.append(detail)
		elif move.technique==&"relay":
			row.active = float(values.final_time)
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase,"hound_flame":phase+6,"final_flame":phase,"min_hounds":int(values.min_hounds)}
			for key in ["interval","each_warn","final_warn","final_lock","final_turn"]: detail[key] = float(values[key])
			records.CanisRelayDefinition.append(detail)
		elif move.technique==&"nova":
			row.active = maxf(0.001,float(values.after))
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase}
			for key in ["count","min_hounds","rings","pair_dist","pair_side","gather_speed","body_radius","ring_gap","ring_speed","ring_band","ring_end","after"]: detail[key] = int(values[key]) if key in ["count","min_hounds","rings"] else float(values[key])
			var steering: Dictionary = load("res://data/bosses/canis_major_moves/bay.tres").values()
			for key in ["arrive","decel","face_turn","turn_slow","turn_fast","turn_switch","accel"]: detail[key] = float(steering[key])
			records.CanisNovaDefinition.append(detail)
		elif move.technique==&"hunt_pounce":
			row.active = 0.001
			records.BossTechniqueDefinition.append(row)
			records.CanisHuntPounceDefinition.append({"id":phase,"technique":phase,"stream":phase+2,"pounce":phase+4,"gap":float(values.gap)})
		elif move.technique==&"hunt":
			row.active = float(values.beam_time)
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase,"stream":phase+2,"flame":phase,"min_hounds":5}
			for key in ["gap","aim_warn","aim_lock","aim_lead","aim_turn"]: detail[key] = float(values[key])
			records.CanisHuntDefinition.append(detail)
		elif move.technique==&"stream":
			row.active = float(values.lunge_time)
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase}
			for key in ["interval","each_warn","lunge_speed","lunge_time","min_hounds"]: detail[key] = int(values[key]) if key=="min_hounds" else float(values[key])
			records.CanisStreamDefinition.append(detail)
		elif move.technique==&"blaze":
			row.active = maxf(0.001,float(values.ignite_at)+maxi(0,int(values.count)-1)*float(values.ignite_step))
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase,"flame":phase+4}
			for key in ["count","min_hounds","ignite_at","ignite_step","run_speed","stop_dist","max_run","blink","explode_radius"]: detail[key] = int(values[key]) if key in ["count","min_hounds"] else float(values[key])
			var steering: Dictionary = load("res://data/bosses/canis_major_moves/bay.tres").values()
			for key in ["arrive","decel","face_turn","turn_slow","turn_fast","turn_switch","accel"]: detail[key] = float(steering[key])
			records.CanisBlazeDefinition.append(detail)
		elif move.technique==&"bay":
			row.active = maxf(0.001,float(values.pounce_at))
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase,"pounce":phase+2}
			for field in Schema.SCHEMA.records.filter(func(v): return v.name=="CanisBayDefinition")[0].fields:
				if field.name in ["id","technique","pounce"]: continue
				detail[field.name] = int(values[field.name]) if field.type=="u32" else float(values[field.name])
			for key in ["front_angle","back_angle"]: detail[key] = deg_to_rad(detail[key])
			records.CanisBayDefinition.append(detail)
		elif move.technique==&"sirius":
			row.active = float(values.beam_time)
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase,"flame":phase}
			for key in ["shots","shot_gap","lock","lead","aim_turn"]: detail[key] = int(values[key]) if key=="shots" else float(values[key])
			records.CanisSiriusDefinition.append(detail)
		elif move.technique==&"pounce":
			row.active = float(values.active)
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase}
			for field in Schema.SCHEMA.records.filter(func(v): return v.name=="CanisPounceDefinition")[0].fields:
				if field.name in ["id","technique"]: continue
				detail[field.name] = int(values[field.name]) if field.type=="u32" else float(values[field.name])
			records.CanisPounceDefinition.append(detail)
		elif move.technique==&"howl":
			row.active = float(values.follow_time)+maxi(0,int(values.ring_count)-1)*float(values.seq_interval)+float(values.seq_warn)+float(values.tail)+0.05
			records.BossTechniqueDefinition.append(row)
			var detail := {"id":phase,"technique":phase}
			for field in Schema.SCHEMA.records.filter(func(v): return v.name=="CanisHowlDefinition")[0].fields:
				if field.name in ["id","technique"]: continue
				detail[field.name] = int(values[field.name]) if field.type=="u32" else float(values[field.name])
			records.CanisHowlDefinition.append(detail)
		else:
			row.active = float(values.lunge_time)+0.05
			records.BossTechniqueDefinition.append(row)
			records.CanisCommandDefinition.append({"id":phase,"technique":phase,"lunge_speed":float(values.lunge_speed),"lunge_time":float(values.lunge_time),"min_hounds":int(values.min_hounds)})
			for stage in [{"command":1,"at":row.warn},{"command":2,"at":row.warn+float(values.lunge_time)+0.05}]: records.BossTechniqueStage.append({"id":records.BossTechniqueStage.size()+1,"technique":phase,"command":stage.command,"at":stage.at})
	if move.technique in [&"hunt",&"hunt_pounce"]:
		var stream := canis_technique_records(definition,load("res://data/bosses/canis_major_moves/stream.tres"))
		for row: Dictionary in stream.BossTechniqueDefinition:
			row.id += 2
			records.BossTechniqueDefinition.append(row)
		for row: Dictionary in stream.CanisStreamDefinition:
			row.technique += 2
			records.CanisStreamDefinition.append(row)
	if move.technique in [&"bay",&"hunt_pounce"]:
		var offset := 4 if move.technique==&"hunt_pounce" else 2
		var jump := canis_technique_records(definition,load("res://data/bosses/canis_major_moves/pounce.tres"))
		for row: Dictionary in jump.BossTechniqueDefinition:
			row.id += offset
			records.BossTechniqueDefinition.append(row)
		for row: Dictionary in jump.CanisPounceDefinition:
			row.technique += offset
			records.CanisPounceDefinition.append(row)
	return records

static func canis_technique_package(definition: BossDef, move: BossTechnique, config: GameConfig) -> Dictionary:
	var package := boss_body_package(definition,config)
	var records := canis_technique_records(definition,move)
	if package.is_empty() or records.is_empty(): return {}
	for key in records: package.records[key] = records[key]
	if move.technique==&"blaze":
		for phase in [1,2]:
			package.records.CanisFlameDefinition[phase+3].duration = move.ignite_step
			package.records.CanisFlameDefinition[phase+3].particle_life = move.ignite_step
			var visual: int = package.records.ResourceKey.size()+1
			package.records.ResourceKey.append({"id":visual,"role":7})
			package.visuals.append({"id":visual,"role":7,"path":move.explosion_fire.resource_path,"canis_burst":phase})
	if move.technique==&"sirius_flame":
		for phase in [1,2]:
			var values: Dictionary = BossProgram.snapshot(move).values().duplicate(true)
			var profile: Dictionary = package.records.CanisFlameDefinition[phase+1]
			for pair in [["particle_life","life"],["duration","duration"],["damage","damage"],["spread","spread"],["speed","particle_speed"],["drag","drag"],["r_start","r_start"],["r_end","r_end"],["hit_scale","hit_scale"]]: profile[pair[0]] = float(values[pair[1]])
	if move.technique==&"relay":
		for phase in [1,2]:
			var values: Dictionary = BossProgram.snapshot(move).values().duplicate(true)
			var profile: Dictionary = package.records.CanisFlameDefinition[phase-1]
			profile.merge({"external_id":"relay","particle_life":float(values.beam_particle_life),"length":float(values.final_length),"width":float(values.final_width),"duration":float(values.final_time),"damage":float(values.final_damage),"trail_life":0.0,"trail_damage":0.0},true)
			var hound: Dictionary = profile.duplicate(true)
			hound.merge({"id":package.records.CanisFlameDefinition.size()+1,"length":float(values.hound_beam_length),"width":float(values.hound_beam_width),"duration":float(values.hound_beam_time),"damage":float(values.hound_damage)},true)
			package.records.CanisFlameDefinition.append(hound)
			var key: int = package.records.ResourceKey.size()+1
			package.records.ResourceKey.append({"id":key,"role":7})
			package.visuals.append({"id":key,"role":7,"path":move.flame_settings.resource_path,"canis_flame":hound.id})
			for asset: Dictionary in package.visuals:
				if int(asset.get("canis_flame",0))==phase: asset.path = move.flame_settings.resource_path
	if move.technique in [&"sirius",&"hunt"]:
		for phase in [1,2]:
			var values: Dictionary = BossProgram.snapshot(move).values().duplicate(true)
			if phase==2:
				for key: String in values.keys():
					if key.ends_with("_p2"): values[key.trim_suffix("_p2")] = values[key]
			var profile: Dictionary = package.records.CanisFlameDefinition[phase-1]
			profile.merge({"particle_life":float(values.beam_particle_life),"length":float(values.beam_length),"width":float(values.beam_width),"duration":float(values.beam_time),"damage":float(values.damage),"trail_delay":float(values.get("trail_delay",0.0)),"trail_life":float(values.get("trail_time",0.0)),"trail_width":float(values.get("trail_width",0.0)),"trail_damage":float(values.get("trail_damage",0.0))},true)
			profile.external_id = str(move.technique)
			for asset: Dictionary in package.visuals:
				if int(asset.get("canis_flame",0))==phase: asset.path = move.flame_settings.resource_path
	if _prepare_reference_fx(package.records) != OK: return {}
	return package

## 全技で同じ子技を参照し、炎と表示もスキーマの参照先に合わせてまとめる。
static func canis_set_package(definition: BossDef, moves: Array, config: GameConfig) -> Dictionary:
	var package := boss_body_package(definition,config)
	if package.is_empty(): return {}
	var sources := []
	var identities := {}
	var seen := {}
	for move: BossTechnique in moves:
		if move==null or seen.has(move.technique): return {}
		seen[move.technique] = move
		var part := canis_technique_package(definition,move,config)
		if part.is_empty(): return {}
		sources.append({"move":String(move.technique),"package":part})
		for original: Dictionary in part.records.BossTechniqueDefinition:
			if original.external_id!=String(move.technique): continue
			var row := original.duplicate(true)
			row.id = package.records.BossTechniqueDefinition.size()+1
			identities[[row.external_id,row.phase]] = row.id
			package.records.BossTechniqueDefinition.append(row)
	# 単独試行で選ばれなかった内包技も、同じ参照表に一度だけ登録する。
	for source: Dictionary in sources:
		for original: Dictionary in source.package.records.BossTechniqueDefinition:
			var key := [original.external_id,original.phase]
			if identities.has(key): continue
			var row := original.duplicate(true)
			row.id = package.records.BossTechniqueDefinition.size()+1
			identities[key] = row.id
			package.records.BossTechniqueDefinition.append(row)
	package.records.CanisFlameDefinition.clear()
	package.visuals = package.visuals.filter(func(asset): return not asset.has("canis_flame"))
	var resource_ids := {}
	package.records.ResourceKey.clear()
	for asset: Dictionary in package.visuals:
		resource_ids[asset.id] = package.records.ResourceKey.size()+1
		asset.id = resource_ids[asset.id]
		package.records.ResourceKey.append({"id":asset.id,"role":asset.role})
	for enemy: Dictionary in package.records.EnemyRecord: enemy.visual_id = resource_ids[enemy.visual_id]
	var registered := {}
	for source: Dictionary in sources:
		var records := {"BossDefinition":source.package.records.BossDefinition}
		var references := {"BossTechniqueDefinition":{}}
		for row: Dictionary in source.package.records.BossTechniqueDefinition:
			references.BossTechniqueDefinition[row.id] = identities[[row.external_id,row.phase]]
		for record: Dictionary in Schema.SCHEMA.records:
			if record.name in ["BossTechniqueDefinition","CanisBodyDefinition","CanisFlameDefinition"]: continue
			if record.name!="BossTechniqueStage" and not String(record.name).begins_with("Canis"): continue
			for original: Dictionary in source.package.records.get(record.name,[]):
				var move: String = source.package.records.BossTechniqueDefinition[original.technique-1].external_id
				if move!=source.move and seen.has(StringName(move)): continue
				var key := [record.name,references.BossTechniqueDefinition[original.technique],original.id if record.name=="BossTechniqueStage" else 0]
				if registered.has(key): continue
				registered[key] = true
				if not records.has(record.name): records[record.name] = []
				var row := original.duplicate(true)
				if record.name in ["CanisNovaDefinition","CanisBlazeDefinition"] and seen.has(&"bay"):
					var steering: Dictionary = seen[&"bay"].values()
					for field in ["arrive","decel","face_turn","turn_slow","turn_fast","turn_switch","accel"]: row[field] = float(steering[field])
				row.id = records[record.name].size()+1
				records[record.name].append(row)
				for field: Dictionary in record.fields:
					if field.get("ref","")!="CanisFlameDefinition": continue
					var profile: Dictionary = source.package.records.CanisFlameDefinition[row[field.name]-1]
					if not records.has("CanisFlameDefinition"): records.CanisFlameDefinition = []
					if not records.CanisFlameDefinition.any(func(value): return value.id==profile.id): records.CanisFlameDefinition.append(profile)
		var maps := merge_boss_records(package.records,records,references)
		for original: Dictionary in source.package.visuals:
			if not original.has("canis_flame") and not original.has("canis_burst"): continue
			if original.has("canis_flame") and not maps.get("CanisFlameDefinition",{}).has(original.canis_flame): continue
			var asset := original.duplicate(true)
			if asset.has("canis_flame"): asset.canis_flame = maps.CanisFlameDefinition[asset.canis_flame]
			if asset.has("canis_burst"): asset.canis_burst = maps.CanisBlazeDefinition[asset.canis_burst]
			asset.id = package.records.ResourceKey.size()+1
			package.records.ResourceKey.append({"id":asset.id,"role":asset.role})
			package.visuals.append(asset)
	if _prepare_reference_fx(package.records) != OK: return {}
	return package

## ケンタウルスの値から、型付きの段階と矢の外観を生成する。
static func centaurus_technique_records(definition: BossDef, move: BossTechnique) -> Dictionary:
	if move!=null and move.technique in [&"combo_rain_volley",&"combo_shower_shot"]: return centaurus_combo_records(definition,move)
	if move==null or move.technique not in [&"volley",&"rear_attack",&"rain",&"power_shot",&"stomp",&"fan_volley",&"sail_run",&"shower_chase",&"shower_wall",&"shower_path"]: return {}
	var source: BossTechnique = BossProgram.snapshot(move)
	var records := {"BossDefinition":[],"BossTechniqueDefinition":[],"BossTechniqueStage":[],"CentaurusVolleyDefinition":[],"CentaurusRearDefinition":[],"CentaurusRainDefinition":[],"CentaurusPowerDefinition":[],"CentaurusShowerDefinition":[],"CentaurusFanDefinition":[],"CentaurusSailDefinition":[],"CentaurusComboDefinition":[],"CentaurusStompDefinition":[],"CentaurusStompFoot":[],"LightArrowDefinition":[]}
	var boss := {"id":1,"external_id":"centaurus","kind":1,"turn":definition.turn,"speed":definition.speed}
	for key in ["lock_lead","horn_width","horn_length_ratio","horn_length_ratio_p2","near_clearance","reposition_time","stuck_time","extract_time","extract_speed","approach_range","approach_speed","kick_trigger_arc"]: boss[key] = 0.0
	records.BossDefinition = [boss]
	if move.technique in [&"volley",&"rain",&"power_shot",&"fan_volley",&"sail_run",&"shower_chase",&"shower_wall",&"shower_path"]:
		var scene: PackedScene = source.get("shot_visual")
		if scene==null: scene = load("res://data/bosses/centaurus_moves/fan_volley.tres").shot_visual
		var visual: AttackVisual = scene.instantiate()
		if move.technique in [&"shower_chase",&"shower_wall",&"shower_path"]:
			visual.visual_profile_key = "boss/move/centaurus/"+str(move.technique)
			visual.visual_profile_fallback = "res://scenes/attacks/light_arrow.tscn"
		var visual_tint := AttackVisual.apply_effect_settings_to(visual)
		var style := {"id":1,"cosmic":move.technique==&"power_shot","contact":1,"flight_scale":visual.flight_scale}
		for key in ["shot_length_scale","shot_width_scale","core_width","cosmic_speed","cosmic_star_count"]: style[key] = visual.get(key)
		for color_pair in [["arrow",visual.get("arrow_color")],["cosmic_a",visual.get("cosmic_color_a")],["cosmic_b",visual.get("cosmic_color_b")],["tint",visual_tint]]:
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
		row.merge({"id":phase,"boss":1,"external_id":str(move.technique),"kind":8 if move.technique==&"volley" else 9 if move.technique==&"rear_attack" else 10 if move.technique==&"rain" else 11 if move.technique==&"power_shot" else 12 if move.technique==&"stomp" else 13 if move.technique==&"fan_volley" else 15 if move.technique==&"sail_run" else 14,"phase":phase,"track_during_warn":source.track_during_warn,"post_gap":source.post_gap,"passes":1,"cuts":1},true)
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
		elif move.technique==&"sail_run":
			row.active = maxf(0.001,float(values.duration))
			records.BossTechniqueDefinition.append(row)
			var sail := {"id":phase,"technique":phase,"projectile":1}
			for key in ["approach_speed","radius_min","radius_max","duration","interval","radius","length","travel"]: sail[key] = float(values[key])
			sail.arc = deg_to_rad(float(values.arc))
			records.CentaurusSailDefinition.append(sail)
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

## 種類別の索引と参照を共通スキーマから付け替え、複数技を一つへまとめる。
static func merge_centaurus_records(target: Dictionary, source: Dictionary) -> void:
	merge_boss_records(target,source)

static func merge_boss_records(target: Dictionary, source: Dictionary, references: Dictionary = {}) -> Dictionary:
	var maps := references.duplicate(true)
	if not maps.has("BossDefinition"): maps.BossDefinition = {1:1}
	for key in source:
		if key=="BossDefinition": continue
		if not target.has(key): target[key] = []
		maps[key] = {}
		for row: Dictionary in source[key]: maps[key][row.id] = target[key].size()+maps[key].size()+1
	for record: Dictionary in Schema.SCHEMA.records:
		if record.name not in source or record.name=="BossDefinition": continue
		for original: Dictionary in source[record.name]:
			var row := original.duplicate(true)
			row.id = maps[record.name][row.id]
			for field: Dictionary in record.fields:
				if field.has("ref") and maps.has(field.ref): row[field.name] = maps[field.ref][row[field.name]]
			target[record.name].append(row)
	if target.get("BossDefinition",[]).is_empty(): target.BossDefinition = source.BossDefinition
	return maps

## 連携は子の値を保持し、前半の硬直を挟まずgapから後半へ進む。
static func centaurus_combo_records(definition: BossDef, move: BossTechnique, parts: Array = []) -> Dictionary:
	if move.technique not in [&"combo_rain_volley",&"combo_shower_shot"]: return {}
	var names: Array = ["rain","volley"] if move.technique==&"combo_rain_volley" else ["shower_chase","power_shot"]
	if parts.is_empty():
		for name in names: parts.append(load("res://data/bosses/centaurus_moves/"+name+".tres"))
	if parts.size()!=2 or str(parts[0].technique)!=names[0] or str(parts[1].technique)!=names[1]: return {}
	var records := centaurus_technique_records(definition,parts[0])
	var second := centaurus_technique_records(definition,parts[1])
	if records.is_empty() or second.is_empty(): return {}
	merge_centaurus_records(records,second)
	for phase in [1,2]:
		var first: Dictionary = records.BossTechniqueDefinition[phase-1]
		var last: Dictionary = records.BossTechniqueDefinition[phase+1]
		var row := first.duplicate(true)
		row.merge({"id":records.BossTechniqueDefinition.size()+1,"external_id":str(move.technique),"kind":16,"warn":0.0,"active":first.warn+first.active+float(move.gap)+last.warn+last.active+last.recover,"recover":0.0,"cd":float(move.cd),"track_during_warn":move.track_during_warn,"post_gap":move.post_gap},true)
		records.BossTechniqueDefinition.append(row)
		records.CentaurusComboDefinition.append({"id":phase,"technique":row.id,"first":first.id,"second":last.id,"gap":float(move.gap)})
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
static func centaurus_technique_package(definition: BossDef, move: BossTechnique, config: GameConfig, parts: Array = []) -> Dictionary:
	var package := boss_body_package(definition,config)
	var records := centaurus_combo_records(definition,move,parts) if move.technique in [&"combo_rain_volley",&"combo_shower_shot"] else centaurus_technique_records(definition,move)
	if package.is_empty() or records.is_empty(): return {}
	var offset: int = package.records.LightArrowDefinition.size()
	for style in records.LightArrowDefinition:
		style.id += offset
		package.records.LightArrowDefinition.append(style)
	for volley in records.CentaurusVolleyDefinition: volley.projectile += offset
	for rain in records.CentaurusRainDefinition: rain.projectile += offset
	for power in records.CentaurusPowerDefinition: power.projectile += offset
	for fan in records.CentaurusFanDefinition: fan.projectile += offset
	for sail in records.CentaurusSailDefinition: sail.projectile += offset
	for shower in records.CentaurusShowerDefinition: shower.projectile += offset
	for key in records:
		if key!="LightArrowDefinition": package.records[key] = records[key]
	var arrow_scene: PackedScene = move.get("shot_visual")
	if move.technique in [&"shower_chase",&"shower_wall",&"shower_path"]: arrow_scene = load("res://data/bosses/centaurus_moves/fan_volley.tres").shot_visual
	var scenes: Array = [arrow_scene,move.visual]
	if move.technique in [&"combo_rain_volley",&"combo_shower_shot"]:
		if parts.is_empty():
			for name in (["rain","volley"] if move.technique==&"combo_rain_volley" else ["shower_chase","power_shot"]): parts.append(load("res://data/bosses/centaurus_moves/"+name+".tres"))
		for part in parts:
			var shot: PackedScene = part.get("shot_visual")
			if shot==null and str(part.technique).begins_with("shower_"): shot = load("res://data/bosses/centaurus_moves/fan_volley.tres").shot_visual
			scenes.append_array([shot,part.visual])
	for scene: PackedScene in scenes:
		if scene==null: continue
		var asset: int = package.records.ResourceKey.size()+1
		package.records.ResourceKey.append({"id":asset,"role":7})
		package.visuals.append({"id":asset,"role":7,"path":scene.resource_path})
	if _prepare_reference_fx(package.records) != OK: return {}
	return package

## 複数の技を同じボスの定義表へまとめる。実行は既存の型付きフローへ任せる。
static func boss_technique_set_records(definition: BossDef, moves: Array) -> Dictionary:
	if definition!=null and definition.id==&"draco": return draco_set_records(definition,moves)
	if definition!=null and definition.id==&"centaurus": return centaurus_set_records(definition,moves)
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

## 子の技は一度だけ登録し、連携は同じ形態の定義を参照する。
static func centaurus_set_records(definition: BossDef, moves: Array) -> Dictionary:
	var records := {}
	var seen := {}
	for move: BossTechnique in moves:
		if move==null or seen.has(move.technique): return {}
		seen[move.technique] = true
		if move.technique in [&"combo_rain_volley",&"combo_shower_shot"]: continue
		var source := centaurus_technique_records(definition,move)
		if source.is_empty(): return {}
		merge_centaurus_records(records,source)
	if records.is_empty(): return {}
	for move: BossTechnique in moves:
		if move.technique not in [&"combo_rain_volley",&"combo_shower_shot"]: continue
		var names: Array = ["rain","volley"] if move.technique==&"combo_rain_volley" else ["shower_chase","power_shot"]
		for phase in [1,2]:
			var first: Array = records.BossTechniqueDefinition.filter(func(row): return row.external_id==names[0] and row.phase==phase)
			var last: Array = records.BossTechniqueDefinition.filter(func(row): return row.external_id==names[1] and row.phase==phase)
			if first.size()!=1 or last.size()!=1: return {}
			var row: Dictionary = first[0].duplicate(true)
			row.merge({"id":records.BossTechniqueDefinition.size()+1,"external_id":str(move.technique),"kind":16,"warn":0.0,"active":first[0].warn+first[0].active+float(move.gap)+last[0].warn+last[0].active+last[0].recover,"recover":0.0,"cd":float(move.cd),"track_during_warn":move.track_during_warn,"post_gap":move.post_gap},true)
			records.BossTechniqueDefinition.append(row)
			records.CentaurusComboDefinition.append({"id":records.CentaurusComboDefinition.size()+1,"technique":row.id,"first":first[0].id,"second":last[0].id,"gap":float(move.gap)})
	return records

## 共通本体の生成入力。技の登録は各ボスの移植経路が追加する。
static func boss_body_package(definition: BossDef, config: GameConfig) -> Dictionary:
	if definition==null or definition.id not in [&"monoceros",&"centaurus",&"canis_major",&"hydra",&"draco"]: return {}
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
	row.kind = 39 if definition.id==&"monoceros" else 40 if definition.id==&"centaurus" else 41 if definition.id==&"canis_major" else 43 if definition.id==&"draco" else 42
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
	var boss := {"id":1,"external_id":String(definition.id),"kind":0 if definition.id==&"monoceros" else 1 if definition.id==&"centaurus" else 2 if definition.id==&"canis_major" else 4 if definition.id==&"draco" else 3,"turn":definition.turn,"speed":definition.speed}
	for key in ["lock_lead","horn_width","horn_length_ratio","horn_length_ratio_p2","near_clearance","reposition_time","stuck_time","extract_time","extract_speed","approach_range","approach_speed","kick_trigger_arc"]: boss[key] = float(definition.params.get(key,0.0))
	data.BossDefinition = [boss]
	var body := {"id":1,"boss":1,"enemy":row.id,"hp_floor_enabled":false}
	for key in ["entrance_time","initial_wait","phase_threshold","phase_time","final_beam_width","final_reach","final_warn_width","final_widen_time"]:
		if definition.id==&"draco":
			body[key] = float(definition.params.get(key,{"entrance_time":0.0,"initial_wait":0.0,"phase_threshold":0.7,"phase_time":1.0,"final_beam_width":0.0,"final_reach":0.0,"final_warn_width":0.0,"final_widen_time":1.0}[key]))
		else:
			if not definition.params.has(key) and definition.id!=&"hydra": return {}
			body[key] = float(definition.params.get(key,{"phase_threshold":0.75,"final_reach":1400.0,"final_widen_time":0.35}.get(key,0.0)))
	data.BossBodyDefinition = [body]
	if definition.id==&"hydra":
		row.armor = 0.0
		row.scaling_armor = 0.0
		var hydra := {"id":1,"boss":1,"accel":definition.accel,"arena_x":definition.params.arena_size.x,"arena_y":definition.params.arena_size.y}
		for name in ["bite","vortex","debris","beam","thunder","immortal"]:
			var source: EnemyDef = load("res://data/enemies/hydra_%s.tres" % name)
			var head: Dictionary = chase_package(source,config).records.EnemyRecord[0].duplicate(true)
			head.id = data.EnemyRecord.size()+1
			head.visual_id = row.visual_id
			data.EnemyRecord.append(head)
			data.PartDefinition.append({"id":head.id})
			data.StringEntry.append({"id":head.id,"value":"hydra_"+name})
			data.DefinitionIndex.append({"id":head.id,"enemy":head.id})
			data.PopulationType.append({"id":head.id,"enemy":head.id,"rank":5,"maximum":1,"ranged":false})
			hydra[name] = head.id
		for field in Schema.SCHEMA.records.filter(func(value): return value.name=="HydraBodyDefinition")[0].fields:
			if hydra.has(field.name): continue
			hydra[field.name] = definition.params[field.name]
		var immortal_definition: int = hydra.immortal
		hydra.erase("immortal")
		data.HydraBodyDefinition = [hydra]
		var rubble_package: Dictionary = chase_package(load("res://data/enemies/hydra_rubble.tres"),config)
		var rubble_source: Dictionary = rubble_package.records
		var rubble: Dictionary = rubble_source.EnemyRecord[0].duplicate(true)
		rubble.id = data.EnemyRecord.size()+1
		var rubble_visual: Dictionary = rubble_package.visuals[5].duplicate(true)
		rubble_visual.id = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":rubble_visual.id,"role":rubble_visual.role})
		package.visuals.append(rubble_visual)
		rubble.visual_id = rubble_visual.id
		data.EnemyRecord.append(rubble)
		var drift: Dictionary = rubble_source.DriftDefinition[0].duplicate(true)
		drift.id = rubble.id
		data.DriftDefinition.append(drift)
		data.StringEntry.append({"id":rubble.id,"value":"hydra_rubble"})
		data.DefinitionIndex.append({"id":rubble.id,"enemy":rubble.id})
		data.PopulationType.append({"id":rubble.id,"enemy":rubble.id,"rank":0,"maximum":100,"ranged":false})
		var regrow := {"id":1,"boss":1,"growth_first":float(definition.params.growth_thresholds[0]),"growth_second":float(definition.params.growth_thresholds[1])}
		for key in ["regrow","regrow_per_head","regrow_combo","fire_regrow_scale","chance_time","growth_time","debris_dmg"]: regrow[key] = float(definition.params[key])
		data.HydraRegrowDefinition = [regrow]
		var swim := {"id":1,"boss":1,"immortal":immortal_definition}
		for key in ["separation_time","immortal_hp","snake_speed","snake_turn","snake_accel","bearer_speed","solo_bearer_distance"]: swim[key] = float(definition.params[key])
		for key in ["look_player_turn","attack_speed","lunge_momentum"]: swim[key] = float(definition.params.squad[key])
		data.HydraSwimDefinition = [swim]
		var squad := {"id":1,"boss":1}
		var squad_values: Dictionary = definition.params.squad
		squad["counter_max"] = float(squad_values["counter_max"])
		squad["counter_gap"] = float(squad_values["counter_gap"])
		squad["counter_sight"] = float(squad_values["counter_sight"])
		squad["counter_range_cap"] = float(squad_values["counter_range_cap"])
		squad["counter_extra"] = float(squad_values["counter_extra"])
		squad["pincer_weight"] = float(squad_values["pincer_weight"])
		squad["wave_weight"] = float(squad_values["wave_weight"])
		squad["wall_weight"] = float(squad_values["wall_weight"])
		squad["wall_near_weight"] = float(squad_values["wall_near_weight"])
		squad["repeat_weight"] = float(squad_values["repeat_weight"])
		squad["wall_time_x"] = float(squad_values["wall_time"].x)
		squad["wall_time_y"] = float(squad_values["wall_time"].y)
		squad["tactic_time_x"] = float(squad_values["tactic_time"].x)
		squad["tactic_time_y"] = float(squad_values["tactic_time"].y)
		squad["pincer_velocity"] = float(squad_values["pincer_velocity"])
		squad["pincer_idle_noise"] = float(squad_values["pincer_idle_noise"])
		squad["pincer_noise"] = float(squad_values["pincer_noise"])
		squad["attack_arrival"] = float(squad_values["attack_arrival"])
		squad["pincer_timeout"] = float(squad_values["pincer_timeout"])
		squad["pincer_gap_x"] = float(squad_values["pincer_gap"].x)
		squad["pincer_gap_y"] = float(squad_values["pincer_gap"].y)
		squad["initial_gap_x"] = float(squad_values["initial_gap"].x)
		squad["initial_gap_y"] = float(squad_values["initial_gap"].y)
		squad["wave_candidates"] = float(squad_values["wave_candidates"])
		squad["wave_repeat_weight"] = float(squad_values["wave_repeat_weight"])
		squad["wave_separation"] = float(squad_values["wave_separation"])
		squad["wave_timeout"] = float(squad_values["wave_timeout"])
		squad["wave_gap_x"] = float(squad_values["wave_gap"].x)
		squad["wave_gap_y"] = float(squad_values["wave_gap"].y)
		squad["pick_band"] = float(squad_values["pick_band"])
		squad["pick_distance"] = float(squad_values["pick_distance"])
		squad["pick_rest"] = float(squad_values["pick_rest"])
		squad["pick_front_weight"] = float(squad_values["pick_front_weight"])
		squad["pick_front_distance"] = float(squad_values["pick_front_distance"])
		squad["lunge_momentum"] = float(squad_values["lunge_momentum"])
		squad["look_forward_noise"] = float(squad_values["look_forward_noise"])
		squad["look_forward_turn"] = float(squad_values["look_forward_turn"])
		squad["look_player_turn"] = float(squad_values["look_player_turn"])
		squad["look_wave"] = float(squad_values["look_wave"])
		squad["look_wave_speed"] = float(squad_values["look_wave_speed"])
		squad["look_near_extra"] = float(squad_values["look_near_extra"])
		squad["alignment_cap"] = float(squad_values["alignment_cap"])
		squad["alignment_weight"] = float(squad_values["alignment_weight"])
		squad["arrival"] = float(squad_values["arrival"])
		squad["arrival_drift"] = float(squad_values["arrival_drift"])
		squad["arrival_drift_distance"] = float(squad_values["arrival_drift_distance"])
		squad["attack_speed"] = float(squad_values["attack_speed"])
		squad["avoid_reduction"] = float(squad_values["avoid_reduction"])
		squad["bearer_arrival"] = float(squad_values["bearer_arrival"])
		squad["bearer_band_x"] = float(squad_values["bearer_band"].x)
		squad["bearer_band_y"] = float(squad_values["bearer_band"].y)
		squad["bearer_drift"] = float(squad_values["bearer_drift"])
		squad["bearer_near_speed"] = float(squad_values["bearer_near_speed"])
		squad["bearer_panic_speed"] = float(squad_values["bearer_panic_speed"])
		squad["bearer_radius"] = float(squad_values["bearer_radius"])
		squad["bearer_replan"] = float(squad_values["bearer_replan"])
		squad["bearer_ring"] = float(squad_values["bearer_ring"])
		squad["bearer_speed"] = float(squad_values["bearer_speed"])
		squad["bearer_turn"] = float(squad_values["bearer_turn"])
		squad["bearer_wall_band_x"] = float(squad_values["bearer_wall_band"].x)
		squad["bearer_wall_band_y"] = float(squad_values["bearer_wall_band"].y)
		squad["block_arrival"] = float(squad_values["block_arrival"])
		squad["block_count"] = float(squad_values["block_count"])
		squad["block_distance"] = float(squad_values["block_distance"])
		squad["block_force_cap"] = float(squad_values["block_force_cap"])
		squad["block_fraction"] = float(squad_values["block_fraction"])
		squad["block_predict"] = float(squad_values["block_predict"])
		squad["block_response"] = float(squad_values["block_response"])
		squad["block_separation"] = float(squad_values["block_separation"])
		squad["block_speed"] = float(squad_values["block_speed"])
		squad["block_spread"] = float(squad_values["block_spread"])
		squad["block_turn"] = float(squad_values["block_turn"])
		squad["body_length"] = float(squad_values["body_length"])
		squad["body_radius"] = float(squad_values["body_radius"])
		squad["body_step"] = float(squad_values["body_step"])
		squad["body_weight"] = float(squad_values["body_weight"])
		squad["chase_extra"] = float(squad_values["chase_extra"])
		squad["close_angles_0"] = float(squad_values["close_angles"][0])
		squad["close_angles_1"] = float(squad_values["close_angles"][1])
		squad["close_angles_2"] = float(squad_values["close_angles"][2])
		squad["close_angles_3"] = float(squad_values["close_angles"][3])
		squad["close_radii_0"] = float(squad_values["close_radii"][0])
		squad["close_radii_1"] = float(squad_values["close_radii"][1])
		squad["close_sight"] = float(squad_values["close_sight"])
		squad["close_speed"] = float(squad_values["close_speed"])
		squad["cohesion_cap"] = float(squad_values["cohesion_cap"])
		squad["cohesion_weight"] = float(squad_values["cohesion_weight"])
		squad["detour_radius"] = float(squad_values["detour_radius"])
		squad["detour_seek"] = float(squad_values["detour_seek"])
		squad["far_distance"] = float(squad_values["far_distance"])
		squad["far_speed"] = float(squad_values["far_speed"])
		squad["flee_candidates"] = float(squad_values["flee_candidates"])
		squad["flee_distance_weight"] = float(squad_values["flee_distance_weight"])
		squad["flee_far_weight"] = float(squad_values["flee_far_weight"])
		squad["flee_guard_weight"] = float(squad_values["flee_guard_weight"])
		squad["flee_margin"] = float(squad_values["flee_margin"])
		squad["flee_noise"] = float(squad_values["flee_noise"])
		squad["flee_view_weight"] = float(squad_values["flee_view_weight"])
		squad["flee_wall_weight"] = float(squad_values["flee_wall_weight"])
		squad["force_cap"] = float(squad_values["force_cap"])
		squad["front_count"] = float(squad_values["front_count"])
		squad["front_fraction"] = float(squad_values["front_fraction"])
		squad["front_loyalty"] = float(squad_values["front_loyalty"])
		squad["front_near_count"] = float(squad_values["front_near_count"])
		squad["front_outer"] = float(squad_values["front_outer"])
		squad["front_pick_distance"] = float(squad_values["front_pick_distance"])
		squad["front_radius_x"] = float(squad_values["front_radius"].x)
		squad["front_radius_y"] = float(squad_values["front_radius"].y)
		squad["front_sight"] = float(squad_values["front_sight"])
		squad["front_spacing"] = float(squad_values["front_spacing"])
		squad["front_speed"] = float(squad_values["front_speed"])
		squad["front_spread"] = float(squad_values["front_spread"])
		squad["front_spread_max"] = float(squad_values["front_spread_max"])
		squad["gain"] = float(squad_values["gain"])
		squad["goal_response"] = float(squad_values["goal_response"])
		squad["neighbor_radius"] = float(squad_values["neighbor_radius"])
		squad["neighbor_soft"] = float(squad_values["neighbor_soft"])
		squad["panic_cooldown"] = float(squad_values["panic_cooldown"])
		squad["panic_distance"] = float(squad_values["panic_distance"])
		squad["panic_radius"] = float(squad_values["panic_radius"])
		squad["panic_time"] = float(squad_values["panic_time"])
		squad["predict"] = float(squad_values["predict"])
		squad["reorient"] = float(squad_values["reorient"])
		squad["reorient_gap"] = float(squad_values["reorient_gap"])
		squad["replan_x"] = float(squad_values["replan"].x)
		squad["replan_y"] = float(squad_values["replan"].y)
		squad["seek_cap"] = float(squad_values["seek_cap"])
		squad["separation_cap"] = float(squad_values["separation_cap"])
		squad["separation_radius"] = float(squad_values["separation_radius"])
		squad["separation_tau"] = float(squad_values["separation_tau"])
		squad["separation_weight"] = float(squad_values["separation_weight"])
		squad["sight_distance"] = float(squad_values["sight_distance"])
		squad["sight_floor"] = float(squad_values["sight_floor"])
		squad["slot_margin"] = float(squad_values["slot_margin"])
		squad["turn"] = float(squad_values["turn"])
		squad["urgency"] = float(squad_values["urgency"])
		squad["velocity_cap"] = float(squad_values["velocity_cap"])
		squad["velocity_floor"] = float(squad_values["velocity_floor"])
		squad["view_margin_x"] = float(squad_values["view_margin"].x)
		squad["view_margin_y"] = float(squad_values["view_margin"].y)
		squad["wall_max"] = float(squad_values["wall_max"])
		squad["wall_spread"] = float(squad_values["wall_spread"])
		squad["busy_windup"] = float(squad_values.busy_speed[&"windup"])
		squad["busy_active"] = float(squad_values.busy_speed[&"active"])
		squad["busy_hold"] = float(squad_values.busy_speed[&"hold"])
		squad["look_attack_on_x"] = float(squad_values.look.attack.on.x)
		squad["look_attack_on_y"] = float(squad_values.look.attack.on.y)
		squad["look_attack_off_x"] = float(squad_values.look.attack.off.x)
		squad["look_attack_off_y"] = float(squad_values.look.attack.off.y)
		squad["look_attack_limit"] = float(squad_values.look.attack.limit)
		squad["look_front_on_x"] = float(squad_values.look.front.on.x)
		squad["look_front_on_y"] = float(squad_values.look.front.on.y)
		squad["look_front_off_x"] = float(squad_values.look.front.off.x)
		squad["look_front_off_y"] = float(squad_values.look.front.off.y)
		squad["look_front_limit"] = float(squad_values.look.front.limit)
		squad["look_close_on_x"] = float(squad_values.look.close.on.x)
		squad["look_close_on_y"] = float(squad_values.look.close.on.y)
		squad["look_close_off_x"] = float(squad_values.look.close.off.x)
		squad["look_close_off_y"] = float(squad_values.look.close.off.y)
		squad["look_close_limit"] = float(squad_values.look.close.limit)
		squad["look_block_on_x"] = float(squad_values.look.block.on.x)
		squad["look_block_on_y"] = float(squad_values.look.block.on.y)
		squad["look_block_off_x"] = float(squad_values.look.block.off.x)
		squad["look_block_off_y"] = float(squad_values.look.block.off.y)
		squad["look_block_limit"] = float(squad_values.look.block.limit)
		squad["look_bearer_on_x"] = float(squad_values.look.bearer.on.x)
		squad["look_bearer_on_y"] = float(squad_values.look.bearer.on.y)
		squad["look_bearer_off_x"] = float(squad_values.look.bearer.off.x)
		squad["look_bearer_off_y"] = float(squad_values.look.bearer.off.y)
		squad["look_bearer_limit"] = float(squad_values.look.bearer.limit)
		squad["range_bite"] = float(squad_values.attack_ranges[&"bite"])
		squad["range_thunder"] = float(squad_values.attack_ranges[&"thunder"])
		squad["range_vortex"] = float(squad_values.attack_ranges[&"vortex"])
		squad["range_debris"] = float(squad_values.attack_ranges[&"debris"])
		squad["range_beam"] = float(squad_values.attack_ranges[&"beam"])
		data.HydraSquadDefinition = [squad]
		# 移植済み通常技だけを生成する。ほかの種類は各種類の移行で登録する。
		var normal_records := hydra_normal_records(definition,load("res://data/bosses/hydra_moves/bite_thrust.tres"))
		for key in normal_records: data[key] = normal_records[key]
	if definition.id==&"draco":
		var draco := {"id":1,"boss":1,"head_radius":definition.radius,"part_hp":definition.hp,"part_armor":definition.armor}
		for key in ["body_length","body_width","head_scale","body_wave","aim_lead_cap","approach_distance"]: draco[key] = float(definition.params[key])
		draco.entrance_quiet = float(definition.params.get("entrance_quiet",2.5))
		draco.body_segments = int(definition.params.body_segments)
		draco.threshold_1 = float(definition.params.thresholds[0])
		draco.threshold_2 = float(definition.params.thresholds[1])
		data.DracoBodyDefinition = [draco]
		data.DracoFinaleDefinition = [{"id":1,"boss":1,"finish_passes":maxi(1,int(definition.params.get("finish_passes",8))),"finish_pass_time":maxf(0.15,float(definition.params.get("finish_pass_time",0.32)))}]
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
		var burning_visual: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":burning_visual,"role":7})
		package.visuals.append({"id":burning_visual,"role":7,"path":"res://data/visuals/canis_fire_hound.tres","canis_burning":true})
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
	package.visuals.append({"id":key,"role":7,"path":("res://scenes/bosses/hydra_frame.tscn" if definition.id==&"hydra" else "res://scenes/bosses/%s_presentation.tscn" % definition.id),"boss":String(definition.id),"appearance":definition.part_appearance.duplicate(true)})
	if _prepare_reference_fx(package.records) != OK: return {}
	return package

## 候補の順序と重複を保ち、生成済みの敵定義へ結ぶ。資源は既存のdraco用一覧を使う。
static func draco_cycle_candidates(definition: BossDef) -> Array:
	var choices: Array = definition.params.get("picaro_candidates",[]).duplicate()
	if choices.is_empty():
		for id in _catalog().table(&"enemies"):
			var entry: ContentEntry = _catalog().find(&"enemies",id)
			var source := load(entry.path) as EnemyDef
			if source!=null and source.rank>0 and source.gate not in [&"solid",&"immortal"]: choices.append(id)
	return choices if not choices.is_empty() else [&"biter"]

static func append_draco_cycle(data: Dictionary, definition: BossDef, boss: int) -> Error:
	var cycle: int = data.DracoCycleDefinition.size()+1
	data.DracoCycleDefinition.append({"id":cycle,"boss":boss,"collect_time":float(definition.params.get("collect_time",12.0)),"count":int(definition.params.get("picaro_count",3))})
	for id in draco_cycle_candidates(definition):
		var found: Array = data.StringEntry.filter(func(row):return row.value==String(id))
		if found.size()!=1: return ERR_INVALID_DATA
		data.DracoCycleCandidate.append({"id":data.DracoCycleCandidate.size()+1,"cycle":cycle,"enemy":found[0].id,"excluded":StringName(id) in definition.params.get("picaro_excluded",[])})
	return OK
## 首の通常技の編集値を、分離前後で使う同じ型付き定義へ変換する。
static func hydra_normal_records(definition: BossDef, bite: BossTechnique, action_rules: Resource = null) -> Dictionary:
	if definition==null or definition.id!=&"hydra" or bite==null or bite.technique not in [&"bite_thrust",&"bite_sweep",&"beam_bolt",&"beam_fixed",&"wind_blades",&"rubble_lump",&"rubble_fan",&"thunder_drop",&"thunder_headbutt",&"wind_band"] or bite.head_kind not in [&"bite",&"beam",&"vortex",&"debris",&"thunder"]: return {}
	var records := {}
	if action_rules==null: action_rules = load("res://data/bosses/ai/hydra_action_rules.tres")
	var values: Dictionary = definition.params.merged(bite.values(),true)
	var normal := {}
	for field in Schema.SCHEMA.records.filter(func(v): return v.name=="BossTechniqueDefinition")[0].fields: normal[field.name] = false if field.type=="bool" else "" if field.type=="string" else 0
	normal.merge({"id":1,"boss":1,"external_id":String(bite.technique),"kind":64 if bite.technique==&"bite_thrust" else 65 if bite.technique==&"bite_sweep" else 66 if bite.technique==&"beam_bolt" else 67 if bite.technique==&"beam_fixed" else 81 if bite.technique==&"rubble_fan" else 80 if bite.technique==&"rubble_lump" else 68 if bite.technique==&"wind_blades" else 91 if bite.technique==&"thunder_drop" else 92 if bite.technique==&"thunder_headbutt" else 75,"phase":1,"track_during_warn":bite.track_during_warn,"post_gap":bite.post_gap,"warn":float(values.normal_charge),"active":float(values.normal_lunge if bite.technique in [&"bite_thrust",&"thunder_headbutt"] else values.sweep_time if bite.technique==&"bite_sweep" else values.beam_time if bite.technique==&"beam_fixed" else 2.0*float(values.blade_interval) if bite.technique==&"wind_blades" else values.thunder_flash if bite.technique==&"thunder_drop" else values.wind_time if bite.technique==&"wind_band" else 0.0),"hold":float(values.normal_hold),"damage":0.0 if bite.technique==&"wind_band" else float(values.beam_dmg if bite.head_kind==&"beam" or bite.technique==&"thunder_drop" else values.lump_dmg if bite.head_kind==&"debris" else values.bite_dmg),"passes":1,"cuts":1},true)
	records.BossTechniqueDefinition = [normal]
	records.HydraNormalDefinition = [{"id":1,"technique":1,"head_kind":[&"bite",&"vortex",&"debris",&"beam",&"thunder"].find(bite.head_kind),"aim_tracking":float(values.get("aim_tracking",0.0)),"attack_cd":float(values.attack_cd),"bite_radius":float(values.get("bite_radius",0.0)),"cost":float(action_rules.costs.get(String(bite.technique),1.0))}]
	if bite.technique==&"bite_sweep": records.HydraSweepDefinition = [{"id":1,"technique":1,"arc":float(values.sweep_arc),"reach":float(values.sweep_reach)}]
	if bite.technique==&"beam_bolt": records.HydraBoltDefinition = [{"id":1,"technique":1,"length":float(values.bolt_length),"width":float(values.bolt_width),"speed":float(values.bolt_speed),"life":float(values.bolt_life)}]
	if bite.technique==&"beam_fixed": records.HydraFixedBeamDefinition = [{"id":1,"technique":1,"length":float(values.beam_len),"width":float(values.beam_width)}]
	if bite.technique==&"wind_blades": records.HydraWindBladesDefinition = [{"id":1,"technique":1,"interval":float(values.blade_interval),"size":float(values.blade_size),"width":float(values.blade_width),"life":float(values.blade_life),"speed":float(values.blade_speed),"spread":float(values.blade_spread)}]
	if bite.technique in [&"thunder_drop",&"thunder_headbutt"]: records.HydraThunderDefinition = [{"id":1,"technique":1,"radius":float(values.thunder_radius),"flash":float(values.thunder_flash),"lock_fraction":float(values.get("target_lock_fraction",1.0)),"lead":float(values.get("thunder_lead",0.0)),"damage":float(values.beam_dmg)}]
	if bite.technique==&"wind_band": records.HydraWindBandDefinition = [{"id":1,"technique":1,"length":float(values.wind_length),"width":float(values.wind_width),"force":float(values.wind_force)}]
	records.HydraNormalGate = []
	for gate: Dictionary in action_rules.active_gates_for(String(bite.technique)):
		records.HydraNormalGate.append({"id":records.HydraNormalGate.size()+1,"technique":1,"minimum":float(gate.get("min",0.0)),"maximum":float(gate.get("max",1.7976931348623157e308)),"angle":deg_to_rad(float(gate.get("angle",0.0))),"half_angle":deg_to_rad(float(gate.get("half_angle",180.0))),"distance_origin":int(gate.get("distance_origin",0)),"angle_origin":int(gate.get("angle_origin",0)),"ignore_when_separated":bool(gate.get("ignore_when_separated",false))})
	return records

static func hydra_major_records(definition: BossDef, move: BossTechnique, action_rules: Resource = null) -> Dictionary:
	if definition==null or definition.id!=&"hydra" or move==null or move.technique not in [&"curve",&"grid",&"beam_pincer",&"tornado",&"debris_shatter",&"north",&"sequence",&"swarm"]: return {}
	if action_rules==null: action_rules = load("res://data/bosses/ai/hydra_action_rules.tres")
	var values: Dictionary = definition.params.merged(move.values(),true)
	var normal := {}
	for field in Schema.SCHEMA.records.filter(func(v): return v.name=="BossTechniqueDefinition")[0].fields: normal[field.name] = false if field.type=="bool" else "" if field.type=="string" else 0
	normal.merge({"id":1,"boss":1,"external_id":String(move.technique),"kind":90 if move.technique==&"swarm" else 89 if move.technique==&"sequence" else 88 if move.technique==&"north" else 83 if move.technique==&"debris_shatter" else 82 if move.technique==&"tornado" else 72 if move.technique==&"curve" else 73 if move.technique==&"grid" else 74,"phase":1,"track_during_warn":move.track_during_warn,"post_gap":move.post_gap,"warn":maxf(0.001,float(values.warning_time)),"active":maxf(float(values.performance_time),float(values.get("north_flight",0.0))),"recover":float(values.tech_recovery),"cd":float(values.cooldown),"damage":float(values.bite_dmg if move.technique in [&"north",&"sequence",&"swarm"] else values.lump_dmg if move.technique==&"tornado" else values.beam_dmg),"passes":1,"cuts":1},true)
	var records := {"HydraMajorDefinition":[{"id":1,"technique":1,"combo":move.category==&"combo","timeline_available":load("res://scenes/bosses/hydra_boss_timeline.tres").has_animation(move.technique),"cost":float(action_rules.costs.get(String(move.technique),1.0)),"global_cd":float(values.tech_cd),"combo_cd":float(values.combo_cooldown),"major_recovery_padding":0.2}],"BossTechniqueDefinition":[normal]}
	if move.technique==&"curve": records.HydraCurveDefinition = [{"id":1,"technique":1,"length":float(values.beam_len),"width":float(values.beam_width),"delay":float(values.curve_delay),"time":float(values.curve_time),"lag":float(values.curve_lag),"turn":float(values.curve_turn)}]

	if move.technique==&"swarm":
		records.erase("HydraCurveDefinition")
		records.HydraSwarmDefinition=[{"id":1,"technique":1,"radius":float(values.bite_radius),"flight":float(values.swarm_flight),"charge":float(values.sequence_charge),"gap":float(values.swarm_gap),"reach":float(values.swarm_reach),"formation_margin":float(values.formation_margin),"formation_timeout":float(values.formation_timeout),"formation_tolerance":float(values.formation_tolerance)}]
	if move.technique==&"sequence":
		records.erase("HydraCurveDefinition")
		records.HydraSequenceDefinition=[{"id":1,"technique":1,"radius":float(values.bite_radius),"lunge":float(values.normal_lunge),"charge":float(values.sequence_charge),"gap":float(values.sequence_gap),"half_angle":float(values.north_half_angle)}]
	if move.technique==&"north":
		records.erase("HydraCurveDefinition")
		records.HydraNorthDefinition=[{"id":1,"technique":1,"radius":float(values.bite_radius),"flight":float(values.north_flight),"lock_time":clampf(float(values.north_lock_time),0.0,normal.warn),"spread":float(values.north_spread),"half_angle":float(values.north_half_angle)}]
	if move.technique==&"beam_pincer":
		records.erase("HydraCurveDefinition")
		records.HydraPincerDefinition=[{"id":1,"technique":1,"length":float(values.beam_len),"width":float(values.beam_width),"delay":float(values.pincer_delay),"time":float(values.pincer_time),"open_angle":float(values.pincer_open_angle),"close_angle":float(values.pincer_close_angle)}]
	if move.technique==&"grid":
		records.erase("HydraCurveDefinition")
		records.HydraGridDefinition=[{"id":1,"technique":1,"width":float(values.beam_width),"delay":float(values.normal_charge),"time":float(values.grid_time),"planning_width":float(definition.params.beam_width),"clearance":float(definition.params.grid_clearance),"tolerance":float(definition.params.grid_tolerance),"formation_timeout":float(definition.params.formation_timeout),"minimum":int(definition.params.grid_minimum)}]
		records.HydraGridLayout=[];records.HydraGridSlot=[];records.HydraGridPath=[]
		var regions := [&"center",&"right",&"left",&"up",&"down"]
		for name in definition.params.grid_layouts:
			var layout: Dictionary=definition.params.grid_layouts[name]
			var id: int=records.HydraGridLayout.size()+1
			var mask := 0
			for region in 5:
				if definition.params.grid_regions.get(regions[region],&"provisional")==name:mask|=1<<region
			if mask==0:continue
			records.HydraGridLayout.append({"id":id,"technique":1,"name":String(name),"region_mask":mask})
			var slots: Array=layout.slots.duplicate(true);slots.sort_custom(func(a,b):return int(a.priority)<int(b.priority))
			for index in slots.size():
				var slot: Dictionary=slots[index]
				records.HydraGridSlot.append({"id":records.HydraGridSlot.size()+1,"layout":id,"order":index,"from_x":float(slot.from.x),"from_y":float(slot.from.y),"to_x":float(slot.to.x),"to_y":float(slot.to.y)})
			for index in layout.path.size():
				var point: Vector2=layout.path[index]
				records.HydraGridPath.append({"id":records.HydraGridPath.size()+1,"layout":id,"order":index,"x":float(point.x),"y":float(point.y)})
	return records

static func hydra_technique_package(definition: BossDef, move: BossTechnique, config: GameConfig, action_rules: Resource = null) -> Dictionary:
	var records := hydra_major_records(definition,move,action_rules) if move.technique in [&"curve",&"grid",&"beam_pincer",&"tornado",&"debris_shatter",&"north",&"sequence",&"swarm"] else hydra_normal_records(definition,move,action_rules)
	if records.is_empty(): return {}
	var package := boss_body_package(definition,config)
	if package.is_empty(): return {}
	# 単独の確認用パッケージでは、本体の仮通常技を大技へ置き換える。
	for record in Schema.SCHEMA.records:
		if record.name.begins_with("Hydra") and record.fields.any(func(field):return field.get("ref","")=="BossTechniqueDefinition"): package.records[record.name] = []
	for key in records: package.records[key] = records[key]
	if move.technique in [&"rubble_lump",&"rubble_fan"]:
		var values: Dictionary = definition.params.merged(move.values(),true)
		var enemy: int = package.records.StringEntry.filter(func(row): return row.value=="hydra_rubble")[0].id
		package.records.HydraRubbleDefinition = [{"id":1,"technique":1,"enemy":enemy,"radius":float(values.rubble_small_radius if move.technique==&"rubble_fan" else values.lump_r),"speed":float(values.lump_speed),"life":float(load("res://data/enemies/hydra_rubble.tres").params.life),"count":int(values.rubble_count) if move.technique==&"rubble_fan" else 1,"spread":float(values.rubble_spread) if move.technique==&"rubble_fan" else 0.0}]
	if move.technique==&"tornado":
		var values: Dictionary = definition.params.merged(move.values(),true)
		var enemy: int = package.records.StringEntry.filter(func(row): return row.value=="hydra_rubble")[0].id
		package.records.HydraTornadoDefinition = [{"id":1,"technique":1,"enemy":enemy,"charge":float(values.tornado_charge),"life":float(values.tornado_life),"speed":float(values.tornado_speed),"width":float(values.tornado_width)}]
	if move.technique==&"debris_shatter":
		var values: Dictionary = definition.params.merged(move.values(),true)
		var enemy: int = package.records.StringEntry.filter(func(row): return row.value=="hydra_rubble")[0].id
		package.records.HydraShatterDefinition = [{"id":1,"technique":1,"enemy":enemy,"count":int(values.rubble_count),"length":float(values.beam_len),"width":float(values.beam_width),"shard_damage":float(values.shard_dmg),"shard_speed":float(values.shard_speed),"arc":float(values.shatter_arc),"deploy":float(values.shatter_deploy),"time":float(values.shatter_time)}]
	var shot: PackedScene = move.get("shot_visual") if move.has_field("shot_visual") else null
	if shot!=null:
		var key: int = package.records.ResourceKey.size()+1
		package.records.ResourceKey.append({"id":key,"role":7})
		package.visuals.append({"id":key,"role":7,"path":shot.resource_path,"hydra_move":String(move.technique)})
	if _prepare_reference_fx(package.records) != OK: return {}
	return package

## 実制作の技・条件・フローと、ラン共通の決着の値を同じ生成へまとめる。

static func hydra_set_package(definition: BossDef, rules: Resource, config: GameConfig) -> Dictionary:
	var package := boss_body_package(definition,config)
	if package.is_empty(): return {}
	var tables := {"BossTechniqueDefinition":true}
	var changed := true
	while changed:
		changed=false
		for record: Dictionary in Schema.SCHEMA.records:
			if not String(record.name).begins_with("Hydra") or tables.has(record.name): continue
			for field: Dictionary in record.fields:
				if tables.has(field.get("ref","")): tables[record.name]=true;changed=true;break
	for name in tables: package.records[name]=[]
	for move: BossTechnique in rules.techniques:
		var part := hydra_technique_package(definition,move,config,rules)
		if part.is_empty(): return {}
		var maps := {}
		for record: Dictionary in Schema.SCHEMA.records:
			if not tables.has(record.name): continue
			maps[record.name]={}
			for row: Dictionary in part.records[record.name]: maps[record.name][row.id]=package.records[record.name].size()+maps[record.name].size()+1
		for record: Dictionary in Schema.SCHEMA.records:
			if not tables.has(record.name): continue
			for original: Dictionary in part.records[record.name]:
				var row: Dictionary=original.duplicate(true);row.id=maps[record.name][row.id]
				for field: Dictionary in record.fields:
					if maps.has(field.get("ref","")): row[field.name]=maps[field.ref][row[field.name]]
				package.records[record.name].append(row)
		for original: Dictionary in part.visuals:
			if not original.has("hydra_move"): continue
			var visual: Dictionary=original.duplicate(true);visual.id=package.records.ResourceKey.size()+1
			package.records.ResourceKey.append({"id":visual.id,"role":visual.role});package.visuals.append(visual)
	if _prepare_reference_fx(package.records) != OK: return {}
	return package

static func boss_package(definition: BossDef, config: GameConfig, stage: RuntimeStage = null, program: Dictionary = {}) -> Dictionary:
	if definition==null or definition.id not in [&"monoceros",&"centaurus",&"canis_major",&"hydra",&"draco"]: return {}
	var package := boss_body_package(definition,config)
	if package.is_empty(): return {}
	var source: Dictionary = BossProgram.snapshot(program) if not program.is_empty() else {"rules":load("res://data/bosses/ai/"+str(definition.id)+"_action_rules.tres"),"flow":load("res://data/bosses/ai/"+str(definition.id)+"_flow.tres")}
	var rules: Resource = source.get("rules")
	var flow: Resource = source.get("flow")
	if rules==null or flow==null or not BossProgram.validate(source).is_empty(): return {}
	if definition.id==&"hydra" and rules.adapter==&"":
		rules=rules.duplicate(true)
		rules.adapter=&"hydra"
	if String(rules.adapter)!=String(definition.id): return {}
	if definition.id==&"hydra":
		package = hydra_set_package(definition,rules,config)
		if package.is_empty(): return {}
	if definition.id==&"canis_major":
		package = canis_set_package(definition,rules.techniques,config)
		if package.is_empty(): return {}
	var techniques: Dictionary = {} if definition.id in [&"canis_major",&"hydra"] else boss_technique_set_records(definition,rules.techniques)
	if techniques.is_empty() and definition.id not in [&"canis_major",&"hydra"]: return {}
	if definition.id==&"centaurus": merge_centaurus_records(package.records,techniques)
	else:
		for key in techniques: package.records[key] = techniques[key]
	if definition.id==&"draco":
		for move in rules.techniques:
			if move.technique in [&"breath",&"meteor"]: append_draco_breath_rock(package,move,config)
			if move.technique==&"star_fan": append_draco_star_bolt(package,move)
			if move.technique==&"inhale": append_draco_inhale_bolt(package,move)
			if move.technique==&"picaro_wall": append_draco_picaro_wall(package,move,config)
			if move.technique==&"clones": append_draco_clones(package,move,config)
			append_draco_style(package,move)
	var compiled := boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
	if compiled.is_empty(): return {}
	if definition.id==&"centaurus":
		# 直接反応する技にも、制作の条件そのものを生成する。
		for move in rules.techniques:
			var rows: Array = package.records.BossTechniqueDefinition.filter(func(row): return row.external_id==str(move.technique) and row.phase==1)
			var gate := _flow_condition(compiled,rules.conditions.get(str(move.technique),{}))
			if rows.size()!=1 or gate==0: return {}
			compiled.BossFlowNode.append({"id":compiled.BossFlowNode.size()+1,"flow":1,"kind":1,"seconds":0.0,"technique":rows[0].id,"condition":gate,"participant":0})
		var paths := {}
		for move in rules.techniques:
			var shot: PackedScene = move.get("shot_visual")
			if shot==null and str(move.technique).begins_with("shower_"): shot = load("res://data/bosses/centaurus_moves/fan_volley.tres").shot_visual
			for scene: PackedScene in [shot,move.visual]:
				if scene==null or paths.has(scene.resource_path): continue
				paths[scene.resource_path] = true
				var key: int = package.records.ResourceKey.size()+1
				package.records.ResourceKey.append({"id":key,"role":7})
				package.visuals.append({"id":key,"role":7,"path":scene.resource_path})
	for key in compiled: package.records[key] = compiled[key]
	package.records.RunConfig[0].time_limit = stage.time_limit if stage!=null else -1.0
	package.records.LifecycleDefinition[0].legendary = String(stage.legendary_module_id) if stage!=null else ""
	var finish := {"id":1,"time_up_charge_time":config.time_up_charge_time}
	for key in ["replay_window","slow_time","zoom","blast_time","relic_appear_time","relic_hold_time","relic_collect_time","clear_time"]: finish[key] = config.get("boss_finish_"+key)
	package.records.BossFinishDefinition = [finish]
	if stage!=null and not stage.legendary_module_id.is_empty():
		var definition_resource = _definition(&"legendary_modules",stage.legendary_module_id)
		if definition_resource==null: return {}
		for value in [{"path":"res://scenes/run/legendary_reveal.tscn","purpose":"reveal"},{"path":definition_resource.resource_path,"purpose":"legendary"}]:
			var key: int = package.records.ResourceKey.size()+1
			package.records.ResourceKey.append({"id":key,"role":Schema.ENUMS.VisualRole.BossFinish})
			value.id = key
			value.role = Schema.ENUMS.VisualRole.BossFinish
			package.visuals.append(value)
	if _prepare_reference_fx(package.records) != OK: return {}
	return package

static func _flow_condition(records: Dictionary, gate: Dictionary, hydra := false, draco := false) -> int:
	for key in gate:
		if key not in ["min","max","angle","half_angle","min_phase"] and not (hydra and key in ["distance_origin","angle_origin","ignore_when_separated"]) and not (draco and key=="max_phase"): return 0
	var id: int = records.BossFlowCondition.size()+1
	records.BossFlowCondition.append({"id":id,"minimum":float(gate.get("min",0.0)),"maximum":float(gate.get("max",100000.0)),"angle":deg_to_rad(float(gate.get("angle",0.0))),"half_angle":deg_to_rad(float(gate.get("half_angle",180.0))),"minimum_phase":int(gate.get("min_phase",1))})
	if draco: records.DracoFlowGateDefinition.append({"id":records.DracoFlowGateDefinition.size()+1,"condition":id,"maximum_phase":int(gate.get("max_phase",3))})
	return id

static func _flow_node(records: Dictionary, node: Dictionary, rules: Resource, techniques: Dictionary, depth := 0) -> int:
	if depth>24 or node.get("type","") not in ["wait","action","sequence","parallel","branch"]: return 0
	var id: int = records.BossFlowNode.size()+1
	var row := {"id":id,"flow":1,"kind":["wait","action","sequence","parallel","branch"].find(node.type),"seconds":float(node.get("seconds",0.0)),"technique":0,"condition":0,"participant":int(node.get("participant",0))}
	if node.type=="action":
		if not techniques.has(String(node.get("id",""))): return 0
		row.technique = techniques[String(node.id)]
		row.condition = _flow_condition(records,rules.conditions.get(String(node.id),{}),rules.adapter==&"hydra",rules.adapter==&"draco")
	elif node.type=="branch": row.condition = _flow_condition(records,node.get("condition",{}),rules.adapter==&"hydra",rules.adapter==&"draco")
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
		if record.name.begins_with("BossFlow") or record.name=="DracoFlowGateDefinition": records[record.name] = []
	var ids := {}
	for technique in techniques:
		if technique.phase==1: ids[String(technique.external_id)] = technique.id
	for move in rules.techniques:
		if not ids.has(String(move.technique)): return {}
	records.BossFlowProgram = [{"id":1,"boss":1,"maximum_stamina":flow.maximum_stamina,"partial_rest":flow.partial_rest,"empty_rest":flow.empty_rest,"idle_only":rules.adapter in [&"monoceros",&"centaurus",&"canis_major",&"draco"],"allow_parallel":rules.allow_parallel_attacks,"has_bias":not rules.selection_bias.is_empty()}]
	var sources: Array = rules.techniques.map(func(move): return String(move.technique)) + rules.combos.keys()
	for source_value in sources:
		var source := String(source_value)
		var combo: bool = rules.combos.has(source)
		var move: BossTechnique
		if not combo:
			for candidate in rules.techniques:
				if String(candidate.technique)==source: move = candidate
		for entry in rules.active_gate_entries_for(source):
			var gate: int = _flow_condition(records,entry.gate,rules.adapter==&"hydra",rules.adapter==&"draco")
			if gate==0: return {}
			var node := _flow_node(records,rules.combos[source] if combo else {"type":"action","id":source},rules,ids)
			if node==0: return {}
			if not combo: records.BossFlowNode[node-1].condition = gate
			var category: int = ["normal","combo","major"].find(entry.category)
			if category<0: return {}
			records.BossFlowAction.append({"id":records.BossFlowAction.size()+1,"flow":1,"external_id":source,"node":node,"condition":gate,"category":category,"label":category,"group":entry.group,"cost":float(rules.costs.get(source,2.0 if combo else 1.0)),"weight":float(rules.selection_bias.get(source,1.0)),"post_gap":0.0 if combo else move.post_gap,"exclusive":true})
	if rules.adapter==&"hydra":
		var original: Array=records.BossFlowAction.duplicate(true)
		records.BossFlowAction.clear()
		for action: Dictionary in original:
			var node: Dictionary=records.BossFlowNode[action.node-1]
			var normal: bool=node.kind==1 and techniques[node.technique-1].kind in [64,65,66,67,68,75,80,81,91,92]
			for neck in (8 if normal else 1):
				var next: Dictionary=action.duplicate(true);next.id=records.BossFlowAction.size()+1
				if normal:
					var child: Dictionary=node.duplicate(true);child.id=records.BossFlowNode.size()+1;child.participant=neck+1
					records.BossFlowNode.append(child);next.node=child.id;next.exclusive=false
				records.BossFlowAction.append(next)
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
	row.weak_arc = definition.weak_arc
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
	for definition_hero: HeroDef in _heroes():
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
	data.RunConfig[0].fx_boss_ram_hitstop = float(preload("res://data/visuals/fx_reference.tres").for_id("G10-boss-hit").hitstop)
	data.RunConfig[0].fx_boss_touch_damage = preload("res://data/visuals/fx_reference.tres").boss_touch_damage
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
	data.WaveDefinition = [{"id":1,"contact":5,"enemy_min_distance":AttackDefaults.ENEMY_MIN_DISTANCE,"enemy_knock":AttackDefaults.ENEMY_KNOCK}]
	data.ContactDefinition.append({"id":6,"shape":1,"scale":0,"hit_policy":3,"add_ship_radius":true,"ship_sweep":false,"width":0.0})
	data.WallDefinition = [{"id":1,"contact":6}]
	data.ContactDefinition.append({"id":7,"shape":3,"scale":0,"hit_policy":1,"add_ship_radius":true,"ship_sweep":false,"width":0.0})
	for claw in 3:
		var points: PackedVector2Array = AttackDefaults.slash_local(claw)
		for sample in points.size():
			data.SlashDefinition.append({"id":data.SlashDefinition.size()+1,"claw":claw,"sample":sample,"x":points[sample].x,"y":points[sample].y,"thickness":AttackDefaults.SLASH_THICK,"contact":7})
	var bolt_visual: AttackVisual = load("res://scenes/attacks/bolt.tscn").instantiate()
	var bolt_tint := AttackVisual.apply_effect_settings_to(bolt_visual)
	data.BoltDefinition = [{"id":1,"radius":7.0,"life":4.0,"flight_scale":bolt_visual.flight_scale,"tint_r":bolt_tint.r,"tint_g":bolt_tint.g,"tint_b":bolt_tint.b,"tint_a":bolt_tint.a,"contact":1}]
	bolt_visual.free()
	for cosmic in [false,true]:
		var arrow: AttackVisual = load("res://scenes/attacks/cosmic_arrow.tscn" if cosmic else "res://scenes/attacks/light_arrow.tscn").instantiate()
		var arrow_tint := AttackVisual.apply_effect_settings_to(arrow)
		var style := {"id":data.LightArrowDefinition.size()+1,"cosmic":cosmic,"contact":1,"flight_scale":arrow.flight_scale}
		for key in ["shot_length_scale","shot_width_scale","core_width","cosmic_speed","cosmic_star_count"]: style[key] = arrow.get(key)
		for color_pair in [["arrow",arrow.get("arrow_color")],["cosmic_a",arrow.get("cosmic_color_a")],["cosmic_b",arrow.get("cosmic_color_b")],["tint",arrow_tint]]:
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
			"duration":AttackDefaults.ZONE_FLASH,"visual_key":7,
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
	var visual_index: StageResources = stage.resources if stage!=null and stage.resources!=null and not stage.resources.look_paths.is_empty() else _visual_index()
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
	var mount: Vector2 = AttackDefaults.REAR_MOUNT_PIXEL-Vector2(15.5,30.0)
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
	for comet_id in _catalog().table(&"weapons"):
		var comet_entry: ContentEntry = _catalog().find(&"weapons",StringName(comet_id))
		if not comet_entry.comet_only: continue
		var comet_weapon: WeaponDef = load(comet_entry.path)
		if comet_weapon==null: return {}
		var comet_equipment: int = data.LoadoutDefinition.size()+1
		data.LoadoutDefinition.append({"id":comet_equipment,"kind":0,"maximum_level":comet_weapon.level_steps.size(),"external_id":String(comet_weapon.id),"comet_only":true})
		if comet_weapon.id==&"W22":
			var post: Dictionary = config.post_max.target(comet_weapon.id)
			for level in comet_weapon.level_steps.size():
				var factor: float = 1.0+0.1*(comet_weapon.level_steps[level]-1)
				var values := {"id":level+1,"weapon":comet_equipment,"level":level+1,"damage":float(comet_weapon.params.damage)*(1.0+0.3*(comet_weapon.level_steps[level]-1)),"width":float(comet_weapon.params.width)*factor,"radius_factor":factor,"delay":0.18,"visual_life":preload("res://scripts/data_types/attack_defaults.gd").BIPOLAR_BEAM_SECONDS,"color":Color(comet_weapon.params.color).to_rgba32(),"area_increment":float(config.post_max.increments.area) if post.has("area") else 0.0,"knockback_increment":float(config.post_max.increments.knockback) if post.has("knockback") else 0.0}
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
	var flash_slash_entry: ContentEntry = _catalog().find(&"weapons",&"W28")
	if flash_slash_entry==null: return {}
	for path in flash_slash_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":flash_slash_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":flash_slash_id,"asset":key})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":afterimage_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(afterimage.id).has("followup") else 0.0})
	var afterimage_entry: ContentEntry = _catalog().find(&"weapons",&"W27")
	if afterimage_entry==null: return {}
	for path in afterimage_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":afterimage_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":afterimage_id,"asset":key})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":escort_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(escort.id).has("followup") else 0.0})
	var escort_entry: ContentEntry = _catalog().find(&"weapons",&"W26")
	if escort_entry==null: return {}
	for path in escort_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":escort_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":escort_id,"asset":key})
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":interceptor_id,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if interceptor_target.has("followup") else 0.0})
	var interceptor_entry: ContentEntry = _catalog().find(&"weapons",&"W25")
	if interceptor_entry==null: return {}
	for path in interceptor_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":interceptor_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":interceptor_id,"asset":key})
	var bipolar_weapon: int = data.BipolarDefinition[0].weapon
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":bipolar_weapon,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(&"W22").has("followup") else 0.0})
	var bipolar_entry: ContentEntry = _catalog().find(&"weapons",&"W22")
	if bipolar_entry==null: return {}
	for path in bipolar_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":bipolar_weapon})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":bipolar_weapon,"asset":key})
	var tow_weapon: int = data.MassTowDefinition[0].weapon
	data.PostMaxWeaponPowerDefinition.append({"id":data.PostMaxWeaponPowerDefinition.size()+1,"equipment":tow_weapon,"damage_increment":float(config.post_max.increments.weapon_damage),"followup_increment":float(config.post_max.increments.followup) if config.post_max.target(&"W21").has("followup") else 0.0})
	var tow_entry: ContentEntry = _catalog().find(&"weapons",&"W21")
	if tow_entry==null: return {}
	for path in tow_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":tow_weapon})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":tow_weapon,"asset":key})
	var arc_entry: ContentEntry = _catalog().find(&"weapons",&"W17")
	if arc_entry==null: return {}
	for path in arc_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":contact_arc_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":contact_arc_id,"asset":key})
	var sonic_entry: ContentEntry = _catalog().find(&"weapons",&"W08")
	if sonic_entry==null: return {}
	for path in sonic_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":sonic_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":sonic_id,"asset":key})
	var contact_entry: ContentEntry = _catalog().find(&"weapons",&"W04")
	if contact_entry==null: return {}
	for path in contact_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":contact_wave_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":contact_wave_id,"asset":key})
	var knockback_entry: ContentEntry = _catalog().find(&"weapons",&"W03")
	if knockback_entry==null: return {}
	for path in knockback_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":knockback_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":knockback_id,"asset":key})
	var mines_entry: ContentEntry = _catalog().find(&"weapons",&"W07")
	if mines_entry==null: return {}
	for path in mines_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":mines_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":mines_id,"asset":key})
	var end_blast_entry: ContentEntry = _catalog().find(&"weapons",&"W29")
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
	var entry: ContentEntry = _catalog().find(&"weapons",weapon.id)
	if entry==null: return {}
	for path in entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":1,"asset":key})
	var scatter_entry: ContentEntry = _catalog().find(&"weapons",scatter.id)
	if scatter_entry==null: return {}
	for path in scatter_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":scatter_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":scatter_id,"asset":key})
	var rear_entry: ContentEntry = _catalog().find(&"weapons",rear.id)
	if rear_entry==null: return {}
	for path in rear_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":rear_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":rear_id,"asset":key})
	var barrier_entry: ContentEntry = _catalog().find(&"weapons",barrier.id)
	if barrier_entry==null: return {}
	for path in barrier_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":barrier_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":barrier_id,"asset":key})
	var gear_entry: ContentEntry = _catalog().find(&"traits",gear.id)
	if gear_entry==null: return {}
	for path in gear_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":gear_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":gear_id,"asset":key})
	var kill_sonic_entry: ContentEntry = _catalog().find(&"traits",&"T05")
	if kill_sonic_entry==null: return {}
	for path in kill_sonic_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":kill_sonic_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":kill_sonic_id,"asset":key})
	var crit_beam_entry: ContentEntry = _catalog().find(&"traits",&"T06")
	if crit_beam_entry==null: return {}
	for path in crit_beam_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":crit_beam_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":crit_beam_id,"asset":key})
	var vortex_entry: ContentEntry = _catalog().find(&"traits",&"T03")
	if vortex_entry==null: return {}
	for path in vortex_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":vortex_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":vortex_id,"asset":key})
	var run_up_entry: ContentEntry = _catalog().find(&"traits",&"T32")
	if run_up_entry==null: return {}
	for path in run_up_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":run_up_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":run_up_id,"asset":key})
	var rampage_entry: ContentEntry = _catalog().find(&"traits",rampage.id)
	if rampage_entry==null: return {}
	for path in rampage_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":rampage_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":rampage_id,"asset":key})
	var duplicator_entry: ContentEntry = _catalog().find(&"traits",duplicator.id)
	if duplicator_entry==null: return {}
	for path in duplicator_entry.resources:
		var key: int = data.ResourceKey.size()+1
		data.ResourceKey.append({"id":key,"role":7})
		visuals.append({"id":key,"role":7,"path":path,"equipment":duplicator_id})
		data.LoadoutAsset.append({"id":data.LoadoutAsset.size()+1,"equipment":duplicator_id,"asset":key})
	var full_burst_entry: ContentEntry = _catalog().find(&"traits",&"T36")
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
	var star_tint := AttackVisual.apply_effect_settings_to(star)
	var star_library: Resource = load("res://.content/attack_visuals.res")
	if star_library.get_meta("looks",{}).get("res://scenes/attacks/star_bolt.tscn",{}).get("Flight")==null:
		star.free()
		return {}
	var star_visual: int = data.ResourceKey.size()+1
	data.ResourceKey.append({"id":star_visual,"role":Schema.ENUMS.VisualRole.StarBolt})
	visuals.append({"id":star_visual,"role":Schema.ENUMS.VisualRole.StarBolt,"path":"res://.content/attack_visuals.res","scene":"res://scenes/attacks/star_bolt.tscn"})
	data.StarBoltDefinition = [{"id":1,"radius":9.0,"life":6.0,"flight_scale":star.flight_scale,"turn_with_velocity":star.turn_with_velocity,
		"tint_r":star_tint.r,"tint_g":star_tint.g,"tint_b":star_tint.b,"tint_a":star_tint.a,"visual":star_visual,"stone_visual":bullet_visual+1,"contact":1}]
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
		var tint: Color = values.get("effect_tint",Color.WHITE)
		var meta: Dictionary = star_library.get_meta("looks",{}).get(path,{})
		var record := {"id":style+1,"style":style,"contact":2,"active":AttackDefaults.ZONE_FLASH,"hit_duration":zone_visual.hit_duration,"fade_duration":zone_visual.fade_duration,"hit":meta.get("Hit") is Mesh or not meta.get("Hit_sprites",[]).is_empty(),"fade":meta.get("Fade") is Mesh or not meta.get("Fade_sprites",[]).is_empty(),"tint_r":tint.r,"tint_g":tint.g,"tint_b":tint.b,"tint_a":tint.a}
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
	data.HostileDefinition.append({"id":data.HostileDefinition.size()+1,"kind":1,"radius":AttackDefaults.RADIUS,"life":AttackDefaults.LIFE,"damage":AttackDefaults.DEFAULT_DAMAGE,"slow":0.0,"turn":0.0,
		"visual":bullet_visual,"stone_visual":bullet_visual+1,"contact":1})
	for i in weapon.level_steps.size():
		data.ForwardDefinition.append({"id":i+1,"weapon":1,"level":i+1,
			"interval":float(weapon.params.interval_by_level[i]),"damage":float(weapon.params.damage_by_level[i]),
			"life":float(weapon.params.life),"spread":float(weapon.params.spread_step),"knock":float(weapon.params.knock),
			"pierce":int(weapon.params.pierce_by_level[i])})
	preload("res://tools/content/run_progression_data.gd").append(data,config,func(id: StringName): return _definition(&"weapons",id))
	if _prepare_reference_fx(data) != OK: return {}
	return {"records":data,"visuals":visuals}

static func chase_records(definition: EnemyDef, config: GameConfig, stage: RuntimeStage = null) -> Dictionary:
	return chase_package(definition,config,stage).get("records",{})

static func compile_chase(definition: EnemyDef, config: GameConfig, input_sha256: PackedByteArray) -> PackedByteArray:
	return _write_reference_content(chase_records(definition,config),input_sha256)

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
			if not _definitions(&"enemies").has(StringName(type)) and not _definitions(&"bosses").has(StringName(type)): return ERR_INVALID_DATA
			var minimum := clampi(int(region.get("min_count",1)),0,100)
			data.EncounterRegion.append({"id":data.EncounterRegion.size()+1,"pattern":row.id,"enemy":enemy_ids.find(type)+1,"x":float(region.pos[0]),"y":float(region.pos[1]),"angle":float(region.get("angle",0.0)),"jitter":float(region.get("jitter",0.0)),"min_count":minimum,"max_count":clampi(int(region.get("max_count",1)),minimum,100),"fodder":region.get("role","avoid")=="fodder","elite":bool(region.get("elite",false))})
	return OK

## 実験場のボスも、個別制作で使う型付きパッケージを同じ表へ加える。
static func append_bosses(data: Dictionary, visuals: Array[Dictionary], definitions: Dictionary, config: GameConfig, stage: RuntimeStage, programs: Dictionary = {}) -> Error:
	var ids := definitions.keys()
	ids.sort()
	for id in ids:
		var package := boss_package(definitions[id],config,stage,programs.get(String(id),{}))
		if package.is_empty(): return ERR_UNAVAILABLE
		var source: Dictionary = package.records
		# 固有表と、その表が使う共通攻撃の定義を参照関係から一緒に加える。
		var tables := {}
		for record: Dictionary in Schema.SCHEMA.records:
			if String(record.name).begins_with("Boss") or record.name=="DracoFlowGateDefinition": tables[record.name] = true
		var expanded := true
		while expanded:
			expanded = false
			for record: Dictionary in Schema.SCHEMA.records:
				if source.get(record.name,[]).is_empty(): continue
				for field: Dictionary in record.fields:
					var target: String = field.get("ref","")
					if target.is_empty() or target in ["EnemyRecord","ResourceKey"]: continue
					if tables.has(target) and not tables.has(record.name):
						tables[record.name] = true
						expanded = true
		# 共通攻撃・接触は依存先だけを追加し、そこを使う別の攻撃表へは広げない。
		expanded = true
		while expanded:
			expanded = false
			for record: Dictionary in Schema.SCHEMA.records:
				if not tables.has(record.name) or source.get(record.name,[]).is_empty(): continue
				for field: Dictionary in record.fields:
					var target: String = field.get("ref","")
					if not target.is_empty() and target not in ["EnemyRecord","ResourceKey"] and not tables.has(target):
						tables[target] = true
						expanded = true
		var maps := {"EnemyRecord":{},"ResourceKey":{}}
		var added_enemies := {}
		for body: Dictionary in source.BossBodyDefinition:
			var enemy: Dictionary = source.EnemyRecord[body.enemy-1].duplicate(true)
			var index: int = data.EnemyRecord.size()+1
			maps.EnemyRecord[enemy.id] = index
			maps.ResourceKey[enemy.visual_id] = data.EnemyRecord[0].visual_id
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
		for original: Dictionary in source.EnemyRecord:
			if maps.EnemyRecord.has(original.id): continue
			var enemy := original.duplicate(true)
			var name: String = source.StringEntry[original.id-1].value
			var found: Array = data.StringEntry.filter(func(row):return row.value==name)
			if not found.is_empty():
				maps.EnemyRecord[original.id]=found[0].id
				maps.ResourceKey[original.visual_id]=data.EnemyRecord[found[0].id-1].visual_id
				continue
			var visual: Dictionary = package.visuals[original.visual_id-1].duplicate(true)
			visual.id=data.ResourceKey.size()+1
			data.ResourceKey.append({"id":visual.id,"role":visual.role});visuals.append(visual)
			maps.ResourceKey[original.visual_id]=visual.id
			enemy.id=data.EnemyRecord.size()+1;enemy.visual_id=visual.id
			maps.EnemyRecord[original.id]=enemy.id;added_enemies[original.id]=true;data.EnemyRecord.append(enemy)
			data.StringEntry.append({"id":enemy.id,"value":name});data.DefinitionIndex.append({"id":enemy.id,"enemy":enemy.id})
			for original_type: Dictionary in source.PopulationType:
				if original_type.enemy!=original.id:continue
				var population:=original_type.duplicate(true);population.id=data.PopulationType.size()+1;population.enemy=enemy.id;data.PopulationType.append(population)
			for original_hull: Dictionary in source.FriendHullLook:
				if original_hull.enemy!=original.id: continue
				var hull := original_hull.duplicate(true);hull.id=data.FriendHullLook.size()+1;hull.enemy=enemy.id;data.FriendHullLook.append(hull)
		# 技で追加する敵には、その敵の移動・接触などの型付き表も付ける。
		for record: Dictionary in Schema.SCHEMA.records:
			if tables.has(record.name) or record.name in ["EnemyRecord","DefinitionIndex","PopulationType","FriendHullLook"]: continue
			var selected_rows := []
			for row: Dictionary in source[record.name]:
				for field: Dictionary in record.fields:
					if field.get("ref","")=="EnemyRecord" and added_enemies.has(row[field.name]):
						selected_rows.append(row);break
			if not selected_rows.is_empty():
				source[record.name] = selected_rows
				tables[record.name] = true
		expanded = true
		while expanded:
			expanded = false
			for record: Dictionary in Schema.SCHEMA.records:
				if not tables.has(record.name) or source[record.name].is_empty(): continue
				for field: Dictionary in record.fields:
					var target: String=field.get("ref","")
					if not target.is_empty() and target not in ["EnemyRecord","ResourceKey"] and not tables.has(target):
						tables[target]=true;expanded=true

		for record: Dictionary in Schema.SCHEMA.records:
			if not tables.has(record.name): continue
			if record.name=="BossFinishDefinition" and not data[record.name].is_empty():
				maps[record.name] = {1:1}
				continue
			maps[record.name] = {}
			for row: Dictionary in source[record.name]: maps[record.name][row.id] = maps.EnemyRecord[row.id] if record.fields[0].get("ref","")=="EnemyRecord" else data[record.name].size()+maps[record.name].size()+1
		# 共通弾などが使う資源も、ボス固有素材と同じ番号変換を通す。
		var resource_refs := {}
		for record: Dictionary in Schema.SCHEMA.records:
			if not tables.has(record.name): continue
			for field: Dictionary in record.fields:
				if field.get("ref","")!="ResourceKey": continue
				for row: Dictionary in source[record.name]: resource_refs[row[field.name]] = true

		for original: Dictionary in package.visuals:
			if not resource_refs.has(original.id) and not original.has("boss") and original.role!=Schema.ENUMS.VisualRole.BossFinish and not original.has("hydra_move") and not original.has("canis_flame") and not original.has("canis_burst") and not original.get("canis_burning",false) and not original.get("canis_trail",false): continue
			if maps.ResourceKey.has(original.id): continue
			var visual := original.duplicate(true)
			if visual.has("canis_flame"): visual.canis_flame = maps.CanisFlameDefinition[visual.canis_flame]
			if visual.has("canis_burst"): visual.canis_burst = maps.CanisBlazeDefinition[visual.canis_burst]
			visual.id = data.ResourceKey.size()+1
			data.ResourceKey.append({"id":visual.id,"role":visual.role})
			visuals.append(visual)
			maps.ResourceKey[original.id] = visual.id
		for record: Dictionary in Schema.SCHEMA.records:
			if not tables.has(record.name): continue
			if record.name=="BossFinishDefinition" and not data[record.name].is_empty(): continue
			for original: Dictionary in source[record.name]:
				var row := original.duplicate(true)
				row.id = maps[record.name][row.id]
				for field: Dictionary in record.fields:
					if field.has("ref"): row[field.name] = maps[field.ref][original[field.name]]
				if record.name=="BossFlowNode":
					if row.technique>0: row.technique = maps.BossTechniqueDefinition[row.technique]
					if row.condition>0: row.condition = maps.BossFlowCondition[row.condition]
				data[record.name].append(row)
	return OK

## 開発用の追加生成でも、ボス・技内部の種類を含む既存の定義番号を保つ。
static func preserve_definition_order(data: Dictionary, previous: PackedStringArray) -> Error:
	if previous.is_empty(): return OK
	var names := {}
	for row: Dictionary in data.StringEntry:
		if names.has(row.value): return ERR_INVALID_DATA
		names[row.value] = int(row.id)
	var order := previous.duplicate()
	for row: Dictionary in data.StringEntry:
		if not row.value in order: order.append(row.value)
	if order.size() != names.size(): return ERR_INVALID_DATA
	var remap := {}
	for i in order.size():
		if not names.has(order[i]) or remap.has(names[order[i]]): return ERR_INVALID_DATA
		remap[names[order[i]]] = i + 1
	# id自体が敵定義への参照になっている種類別の表と、その参照先も同時に移す。
	var aliases := {"EnemyRecord":true, "StringEntry":true, "DefinitionIndex":true}
	var changed := true
	while changed:
		changed = false
		for record: Dictionary in Schema.SCHEMA.records:
			if not aliases.has(record.name) and aliases.has(record.fields[0].get("ref", "")):
				aliases[record.name] = true
				changed = true
	for record: Dictionary in Schema.SCHEMA.records:
		for row: Dictionary in data[record.name]:
			for field: Dictionary in record.fields:
				if (field.name == "id" and aliases.has(record.name)) or aliases.has(field.get("ref", "")):
					var original: int = row.get(field.name, field.get("value", 0))
					if original == 0: continue
					if not remap.has(original): return ERR_INVALID_DATA
					row[field.name] = remap[original]
		if aliases.has(record.name): data[record.name].sort_custom(func(left, right): return left.id < right.id)
	return OK

static func authoring_enemy(id: String, definitions: Dictionary) -> EnemyDef:
	var definition: EnemyDef = definitions.get(StringName(id))
	if definition != null: return definition
	var entry: ContentEntry = _catalog().find(&"enemies", id)
	return ResourceLoader.load(entry.path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyDef if entry != null else null

static var preparation_build_count := 0

## 戦闘と固定外観に使う入力だけを照合する。UI・開発パネルの変更は資源表で拾う。
static func preparation_signature(stage: RuntimeStage, config: GameConfig, definitions: Dictionary, extra: Array, bosses: Dictionary, programs: Dictionary) -> String:
	var paths := PackedStringArray()
	var cache := preload("res://addons/content_build/incremental.gd").new()
	for directory in ["res://data","res://tools/content","res://scripts/data_types","res://scripts/render","res://assets","res://shaders"]:
		cache.files(directory,paths)
	for i in range(paths.size()-1,-1,-1):
		var path: String = paths[i]
		if not preload("res://addons/content_build/inputs.gd").affects_stage(path) or path == "res://data/content_catalog.tres" or path.begins_with("res://data/stages/") or path.begins_with("res://data/codex/") or path.begins_with("res://data/text/") or path.begins_with("res://assets/ui/") or path.begins_with("res://assets/audio/"):
			paths.remove_at(i)
		elif path.begins_with("res://data/bosses/") and path != "res://data/bosses/%s.tres" % stage.boss_id and not (stage.boss_id == &"draco" and path == "res://data/bosses/hydra.tres"):
			paths.remove_at(i)
	for path in stage.resources.paths:
		if String(path).begins_with("res://.content/") and not path in paths: paths.append(path)
	if not stage.boss_id.is_empty(): paths.append("res://.content/boss_%s.tres" % stage.boss_id)
	if stage.boss_id == &"draco": paths.append("res://.content/boss_hydra.tres")
	var values: Variant = BossProgram.canonical([stage,config,definitions,extra,bosses,programs])
	var bytes := cache.digest(paths).to_utf8_buffer()
	bytes.append_array(var_to_bytes(values))
	return Schema.sha256(bytes).hex_encode()

static func build(stage: RuntimeStage, config: GameConfig, output: String, input_sha256: String, definitions := {}, extra_formations: Array = [], boss_definitions: Dictionary = {}, previous_resources: Resource = null, boss_programs: Dictionary = {}, previous_definition_ids := PackedStringArray(), reuse_prepared := true) -> Error:
	if stage == null or stage.resources == null or input_sha256.length()!=64: return ERR_INVALID_DATA
	var data := {}
	var appearance_metadata := {}
	var equipment_resources: Array = []
	var visuals: Array[Dictionary] = []
	var field_visuals: Array = []
	var attack_visuals: Array = []
	for record in Schema.SCHEMA.records: data[record.name] = []
	var preparation_key := preparation_signature(stage,config,definitions,extra_formations,boss_definitions,boss_programs)
	var preparation_path := "res://.content/dev/prepared/"+preparation_key+".res"
	var prepared: Resource = ResourceLoader.load(preparation_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) if reuse_prepared and FileAccess.file_exists(preparation_path) else null
	var cycle_dependencies: Array = []
	if prepared != null and prepared.get_meta("data",null) is Dictionary:
		data = prepared.get_meta("data").duplicate(true)
		visuals.assign(prepared.get_meta("visuals").duplicate(true))
		appearance_metadata = prepared.get_meta("appearance").duplicate(true)
		cycle_dependencies.assign(prepared.get_meta("cycles"))
	else:
		var enemy_ids := stage.resources.enemy_ids.duplicate()
		var cycle_source: BossDef = boss_definitions.get(&"draco",boss_definitions.get("draco"))
		if cycle_source==null and stage.boss_id==&"draco": cycle_source = load("res://data/bosses/draco.tres")
		cycle_dependencies = []
		if cycle_source!=null:
			cycle_dependencies = draco_cycle_candidates(cycle_source)
			for id in cycle_dependencies:
				if not String(id) in enemy_ids: enemy_ids.append(String(id))
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
					if _definitions(&"enemies").has(StringName(type)) and not enemy_ids.has(type): enemy_ids.append(type)

		for terrain in ["meteor","iron","saw"]:
			if not terrain in enemy_ids: enemy_ids.append(terrain)
		for candidate_id: String in enemy_ids.duplicate():
			var candidate := authoring_enemy(candidate_id, definitions)
			if candidate == null: return ERR_INVALID_DATA
			if candidate!=null and candidate.behavior==&"triangle" and not "triangle_star" in enemy_ids: enemy_ids.append("triangle_star")
			if candidate!=null and candidate.behavior==&"cepheus" and not "cepheus_soldier" in enemy_ids: enemy_ids.append("cepheus_soldier")
			if candidate!=null and candidate.behavior==&"split" and not "splitling" in enemy_ids: enemy_ids.append("splitling")
		for i in enemy_ids.size():
			var id: String = enemy_ids[i]
			var definition := authoring_enemy(id, definitions)
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
			if id=="iron": visual.iron = true
			visual.mark_key = "shape:"+String(definition.shape) if visual.path.is_empty() else "sprite:"+id
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
		var resolved_bosses: Dictionary = boss_definitions.duplicate()
		if not stage.boss_id.is_empty() and not resolved_bosses.has(stage.boss_id): resolved_bosses[stage.boss_id] = _definition(&"bosses",stage.boss_id)
		var bosses_error := append_bosses(data,visuals,resolved_bosses,config,stage,boss_programs)
		if bosses_error!=OK: return bosses_error
		if stage.boss_enabled:
			var body_id := 0
			for body: Dictionary in data.BossBodyDefinition:
				if data.BossDefinition[body.boss-1].external_id==String(stage.boss_id): body_id = body.id
			if body_id==0: return ERR_UNAVAILABLE
			data.StageBossDefinition = [{"id":1,"body":body_id,"start":stage.boss_start(config),"spread":config.boss_time_spread if stage.boss_time<0.0 else 0.0}]
		for boss: Dictionary in data.BossDefinition:
			if boss.external_id!="draco": continue
			var source: BossDef = resolved_bosses.get(&"draco",resolved_bosses.get("draco"))
			if source==null or append_draco_cycle(data,source,boss.id)!=OK: return ERR_INVALID_DATA
		prepared = Resource.new()
		prepared.set_meta("data",data)
		prepared.set_meta("visuals",visuals)
		prepared.set_meta("appearance",appearance_metadata)
		prepared.set_meta("cycles",cycle_dependencies)
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(preparation_path.get_base_dir()))
		if directory_error != OK: return directory_error
		var preparation_error := ResourceSaver.save(prepared,preparation_path,ResourceSaver.FLAG_COMPRESS)
		if preparation_error != OK: return preparation_error
		preparation_build_count += 1
	var order_error := preserve_definition_order(data, previous_definition_ids)
	if order_error != OK: return order_error
	# 開発中の追加定義は既存の装備・保留要求の資源番号を維持する。
	if previous_resources!=null:
		var remap := {}
		var used := {}
		var next_id := 1
		for key: int in previous_resources.keys: next_id = maxi(next_id,key+1)
		for entry: Dictionary in previous_resources.visuals: next_id = maxi(next_id,int(entry.id)+1)
		for entry: Dictionary in visuals:
			var assigned := 0
			for old: Dictionary in previous_resources.visuals:
				if used.has(old.id): continue
				var matches := true
				for key in ["role","path","equipment","rect","scene"]:
					if entry.get(key)!=old.get(key): matches = false
				if matches:
					assigned = old.id
					break
			if assigned==0:
				assigned = next_id
				next_id += 1
			remap[entry.id] = assigned
			used[assigned] = true
		for old: Dictionary in previous_resources.visuals:
			if not used.has(old.id): return ERR_INVALID_DATA
		for record: Dictionary in Schema.SCHEMA.records:
			for row: Dictionary in data[record.name]:
				for field: Dictionary in record.fields:
					if field.get("ref")=="ResourceKey" or (record.name=="ResourceKey" and field.name=="id"):
						var original: int = row.get(field.name,field.get("value",0))
						if original!=0: row[field.name] = remap[original]
		var next_metadata := {}
		for key: int in appearance_metadata: next_metadata[remap[key]] = appearance_metadata[key]
		appearance_metadata = next_metadata
		for entry: Dictionary in visuals: entry.id = remap[entry.id]
		visuals.sort_custom(func(a,b): return a.id<b.id)
		data.ResourceKey.sort_custom(func(a,b): return a.id<b.id)
	var source_sha256 := input_sha256
	var paths := stage.resources.paths.duplicate()
	for id in cycle_dependencies:
		var entry: ContentEntry = _catalog().find(&"enemies",StringName(id))
		if entry==null: return ERR_INVALID_DATA
		if not entry.path in paths: paths.append(entry.path)
	paths.append("res://.content/meteor_pieces.res")
	if not paths.has("res://.content/hero_aura.res"): paths.append("res://.content/hero_aura.res")
	for asset in ["res://assets/pixel/iron_debris_2.png","res://assets/pixel/iron_debris_3.png","res://scripts/render/attacks/friend_debris.gd","res://assets/pixel/pump.png","res://.content/attack_visuals.res","res://scripts/render/attacks/zone.gd","res://scripts/render/fx/blast_bursts.gd","res://scripts/render/attacks/flood.gd","res://shaders/water_flood.gdshader","res://assets/fx/water_noise.png","res://scripts/render/light_lance.gd","res://scripts/render/equipment/critBeam.gd","res://scripts/render/attacks/shell_frame.gd","res://shaders/pump_shell_runtime.gdshader"]:
		if not paths.has(asset): paths.append(asset)
	if not paths.has("res://assets/fx/light_arrow.svg"): paths.append("res://assets/fx/light_arrow.svg")
	for visual: Dictionary in visuals:
		var canis_effect := visual.has("canis_flame") or visual.has("canis_burning") or visual.has("canis_burst") or visual.has("canis_trail")
		if (visual.role!=7 or visual.has("boss") or visual.has("hydra_move") or canis_effect) and not visual.path.is_empty() and not paths.has(visual.path): paths.append(visual.path)
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
	var manifest := preload("res://tools/content/build_run_resources.gd").collect(paths,visuals,_catalog(),previous_resources.keys if previous_resources!=null else {})
	if manifest.is_empty(): return ERR_INVALID_DATA
	paths = manifest.paths
	var resolved_input := source_sha256.to_utf8_buffer()
	resolved_input.append_array(_write_reference_content(data,PackedByteArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])))
	resolved_input.append_array("\n".join(paths).to_utf8_buffer())
	resolved_input.append_array(var_to_bytes(appearance_metadata))
	resolved_input.append_array(var_to_bytes([stage.background_color,stage.backgrounds.map(func(item): return [item.texture_path,item.offset,item.scale,item.rotation_degrees,item.display_tint(),item.bounds(),item.parallax,item.fire_preset_path,item.fire_offset,item.fire_scale]),stage.fire_uses]))
	resolved_input.append_array(var_to_bytes(manifest.hashes))
	resolved_input.append_array(var_to_bytes([manifest.keys,manifest.equipment,manifest.order,manifest.signatures,visuals]))
	input_sha256 = Schema.sha256(resolved_input).hex_encode()
	var bytes := _write_reference_content(data,input_sha256.hex_decode())
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
	var resources = preload("res://scripts/data_types/run_resources.gd").new()
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

## 星弾の技専用の色と素材を、保存済みの攻撃外観へ解決する。
static func append_draco_star_bolt(package: Dictionary, move: BossTechnique) -> void:
	var scene: PackedScene=move.shot_visual
	var visual: AttackVisual=scene.instantiate()
	var tint:=AttackVisual.apply_effect_settings_to(visual)
	var asset: int=package.records.ResourceKey.size()+1
	package.records.ResourceKey.append({"id":asset,"role":Schema.ENUMS.VisualRole.StarBolt})
	package.visuals.append({"id":asset,"role":Schema.ENUMS.VisualRole.StarBolt,"path":"res://.content/attack_visuals.res","scene":scene.resource_path})
	var row: Dictionary=package.records.StarBoltDefinition[0].duplicate(true)
	row.merge({"id":package.records.StarBoltDefinition.size()+1,"flight_scale":visual.flight_scale,"turn_with_velocity":visual.turn_with_velocity,"tint_r":tint.r,"tint_g":tint.g,"tint_b":tint.b,"tint_a":tint.a,"visual":asset},true)
	package.records.StarBoltDefinition.append(row)
	for fan: Dictionary in package.records.DracoStarFanDefinition:fan.projectile=row.id
	visual.free()

## 技が生成する敵を同じスキーマの参照表ごと追加する。共通設定は複製しない。
static func append_draco_enemy(package: Dictionary, definition: EnemyDef, config: GameConfig) -> int:
	var data: Dictionary = package.records
	for entry: Dictionary in data.StringEntry:
		if entry.value==String(definition.id): return int(entry.id)
	var source_package := chase_package(definition,config)
	var source: Dictionary = source_package.records
	var tables := {}
	for record: Dictionary in Schema.SCHEMA.records:
		if record.name in ["EnemyRecord","DefinitionIndex","StringEntry"]: continue
		for field: Dictionary in record.fields:
			if field.get("ref","")=="EnemyRecord": tables[record.name]=true
	var expanded := true
	while expanded:
		expanded=false
		for record: Dictionary in Schema.SCHEMA.records:
			if not tables.has(record.name) or source.get(record.name,[]).is_empty(): continue
			for field: Dictionary in record.fields:
				var target: String=field.get("ref","")
				if target.is_empty() or target in ["EnemyRecord","ResourceKey"] or tables.has(target):continue
				tables[target]=true;expanded=true
	var maps := {"EnemyRecord":{},"ResourceKey":{}}
	for original: Dictionary in source_package.visuals:
		var visual:=original.duplicate(true);visual.id=data.ResourceKey.size()+1
		maps.ResourceKey[original.id]=visual.id
		data.ResourceKey.append({"id":visual.id,"role":visual.role});package.visuals.append(visual)
	for original: Dictionary in source.EnemyRecord:
		maps.EnemyRecord[original.id]=data.EnemyRecord.size()+maps.EnemyRecord.size()+1
	for original: Dictionary in source.EnemyRecord:
		var enemy:=original.duplicate(true);enemy.id=maps.EnemyRecord[original.id];enemy.visual_id=maps.ResourceKey[original.visual_id]
		data.EnemyRecord.append(enemy);data.StringEntry.append({"id":enemy.id,"value":source.StringEntry[original.id-1].value});data.DefinitionIndex.append({"id":enemy.id,"enemy":enemy.id})
	for record: Dictionary in Schema.SCHEMA.records:
		if not tables.has(record.name): continue
		maps[record.name]={}
		for row: Dictionary in source[record.name]:
			var id_field: Dictionary=record.fields[0]
			maps[record.name][row.id]=maps.EnemyRecord[row.id] if id_field.get("ref","")=="EnemyRecord" else data[record.name].size()+maps[record.name].size()+1
	for record: Dictionary in Schema.SCHEMA.records:
		if not tables.has(record.name): continue
		for original: Dictionary in source[record.name]:
			var row:=original.duplicate(true)
			for field: Dictionary in record.fields:
				if field.has("ref"): row[field.name]=maps[field.ref][original[field.name]]
			row.id=maps[record.name][original.id];data[record.name].append(row)
	return int(maps.EnemyRecord[1])

static func append_draco_picaro_wall(package: Dictionary, move: BossTechnique, config: GameConfig) -> void:
	var candidates: Array=move.wall_candidates.duplicate()
	if candidates.is_empty(): candidates=[&"lynx"]
	var enemies: Array[int]=[]
	for id in candidates: enemies.append(append_draco_enemy(package,load(_catalog().find(&"enemies",StringName(id)).path),config))
	for detail: Dictionary in package.records.DracoPicaroWallDefinition:
		for enemy: int in enemies: package.records.DracoPicaroWallCandidate.append({"id":package.records.DracoPicaroWallCandidate.size()+1,"technique":detail.technique,"enemy":enemy})

static func append_draco_inhale_bolt(package: Dictionary, move: BossTechnique) -> void:
	var visual: AttackVisual=move.shot_visual.instantiate()
	var tint:=AttackVisual.apply_effect_settings_to(visual)
	var row: Dictionary=package.records.BoltDefinition[0].duplicate(true)
	row.merge({"id":package.records.BoltDefinition.size()+1,"flight_scale":visual.flight_scale,"tint_r":tint.r,"tint_g":tint.g,"tint_b":tint.b,"tint_a":tint.a},true)
	package.records.BoltDefinition.append(row)
	for detail: Dictionary in package.records.DracoInhaleDefinition:detail.projectile=row.id
	visual.free()


## 複製の敵定義と、Hostが再利用する五つのヒドラ通常技を同じ参照表へ足す。
static func append_draco_clones(package: Dictionary, move: BossTechnique, config: GameConfig) -> void:
	var data: Dictionary=package.records
	var hydra: BossDef=load("res://data/bosses/hydra.tres")
	var hydra_boss := {"id":data.BossDefinition.size()+1,"external_id":"hydra","kind":3,"turn":hydra.turn,"speed":hydra.speed}
	for field in Schema.SCHEMA.records.filter(func(v):return v.name=="BossDefinition")[0].fields:
		if not hydra_boss.has(field.name):hydra_boss[field.name]=float(hydra.params.get(field.name,0.0))
	data.BossDefinition.append(hydra_boss)
	var enemies := {}
	for name in ["draco_copy","draco_copy_part","hydra_rubble","hydra"]:
		var definition: EnemyDef=load("res://data/enemies/hydra_rubble.tres").duplicate(true) if name=="hydra_rubble" else EnemyDef.new()
		if name!="hydra_rubble":definition.id=StringName(name);definition.behavior=&"drift";definition.hp=float(move.clone_hp) if name=="draco_copy" else 999999.0;definition.radius=1.0;definition.speed=0.0;definition.rank=0
		var source: Dictionary=chase_package(definition,config).records
		var enemy: Dictionary=source.EnemyRecord[0].duplicate(true)
		enemy.id=data.EnemyRecord.size()+1;enemy.visual_id=data.EnemyRecord[0].visual_id
		# 通常のヒドラ本体と一緒に生成しても、技内部の出所定義が同名にならないようにする。
		data.EnemyRecord.append(enemy);data.StringEntry.append({"id":enemy.id,"value":"draco_clone_hydra" if name=="hydra" else name});data.DefinitionIndex.append({"id":enemy.id,"enemy":enemy.id})
		var drift: Dictionary=source.DriftDefinition[0].duplicate(true);drift.id=enemy.id;data.DriftDefinition.append(drift)
		var population: Dictionary=source.PopulationType[0].duplicate(true);population.id=data.PopulationType.size()+1;population.enemy=enemy.id;data.PopulationType.append(population)
		enemies[name]=enemy.id
	var techniques := []
	for name in ["bite_thrust","wind_band","rubble_fan","beam_fixed","thunder_drop"]:
		var normal: BossTechnique=load("res://data/bosses/hydra_moves/"+name+".tres")
		var source: Dictionary=hydra_normal_records(hydra,normal)
		var shot: PackedScene=normal.get("shot_visual") if normal.has_field("shot_visual") else null
		if shot!=null:
			var key: int=data.ResourceKey.size()+1
			data.ResourceKey.append({"id":key,"role":7});package.visuals.append({"id":key,"role":7,"path":shot.resource_path,"hydra_move":name})
		if name=="rubble_fan":
			var values: Dictionary=hydra.params.merged(normal.values(),true)
			source.HydraRubbleDefinition=[{"id":1,"technique":1,"enemy":enemies.hydra_rubble,"radius":float(values.rubble_small_radius),"speed":float(values.lump_speed),"life":float(load("res://data/enemies/hydra_rubble.tres").params.life),"count":int(values.rubble_count),"spread":float(values.rubble_spread)}]
		var maps: Dictionary=merge_boss_records(data,source,{"BossDefinition":{1:hydra_boss.id}})
		techniques.append(maps.BossTechniqueDefinition[1])
	for row in data.DracoClonesDefinition:
		row.clone_enemy=enemies.draco_copy;row.part_enemy=enemies.draco_copy_part;row.hydra_source=enemies.hydra
		for j in 5:row[["bite","wind","rubble","beam","thunder"][j]]=techniques[j]
