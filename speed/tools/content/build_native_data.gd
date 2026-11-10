## 比較で対応する追跡敵の固定値を、編集元と本番の倍率から生成する。
@tool
extends RefCounted
const AttackDefaults = preload("res://scripts/data_types/attack_defaults.gd")

const PROBE_CONFIG_FIELDS := ["start_radius", "base_max_speed", "stick_dead_zone", "mouse_dead_zone", "steer_cruise", "glide_hold", "glide_fade", "cruise_floor", "energy_cut", "cruise_drag", "overcap_decay", "field_radius", "boundary_push", "ship_radius", "crash_restitution", "ship_hurt_time", "draw_min_charge", "draw_length", "draw_step", "draw_confirm_delay", "draw_run_time", "draw_time_scale", "draw_run_slow_ref", "draw_run_scale_min", "boost_duration", "carry", "launch_ratio", "glide_speed_ratio", "base_attack", "atk_scale", "ram_speed_ratio", "crit_armor", "touch_damage", "contact_cooldown", "bounce_keep", "bounce_min_speed", "kill_hitstop", "kill_hitstop_cap", "kill_hitstop_regen", "hitstop_big_mult", "hitstop_crit_mult", "max_enemy_radius", "gem_max", "drop_base", "drop_max", "drop_power_exp", "big_crystal_shift_time", "big_crystal_xp", "big_crystal_weights_start", "big_crystal_weights_end", "world_tick_div", "grid_cell", "trace_radius", "character_scale"]

static func compile_enemy(definition: EnemyDef, config: GameConfig, stage: StageDef = null) -> Dictionary:
	if definition == null or config == null or definition.behavior not in [&"chase", &"shield", &"biter", &"hound", &"meteor", &"obstacle", &"saw", &"beamer", &"missile", &"rocket", &"drift", &"part", &"battleship", &"sniper", &"marlin", &"pulser", &"dolphin", &"lynx", &"soldier", &"auriga", &"clock", &"reticle",&"aquarius",&"cross",&"bomber",&"phoenix",&"aquila",&"split",&"defender",&"crab",&"crow",&"cepheus",&"pump",&"triangle_star",&"corona",&"ruler",&"triangle"]:
		return {}
	var radius := definition.radius * config.character_scale
	radius *= definition.visual_value("scale", 1.0) * definition.visual_value("collision_scale", 1.0)
	var row := {"id": String(definition.id), "behavior": String(definition.behavior),
		"hp": definition.base_hp(config) * config.enemy_hp_mult,
		"armor": definition.armor * config.enemy_armor_mult, "radius": radius,
		"speed": definition.speed, "turn":definition.turn if definition.turn>0.0 else 4.0, "fire_interval": float(definition.params.get("fire_interval", 0.0)),
		"color": [definition.color.r, definition.color.g, definition.color.b, definition.color.a],
		"xp": definition.xp, "knockback": definition.knockback_scale(config),
		"hitstop_multiplier": definition.hitstop_multiplier}
	var gates := {&"":0,&"none":0,&"solid":1,&"membrane":2,&"ghost":3,&"immortal":4,&"claw":5,&"back":6,&"guard":7}
	if not gates.has(definition.gate): return {}
	row.gate = gates[definition.gate]
	row.gate_arc = float(definition.params.get("front_arc",1.6))
	if not is_finite(row.gate_arc) or row.gate_arc<0.0: return {}
	var attack_value := stage.enemy_attack_value(definition.id) if stage != null else 1.0
	row.attack = {"value": attack_value, "priority": stage.enemy_attack_priority(definition.id) if stage != null else 0.0,
		"telegraph": float(definition.params.get("telegraph",0.0)), "weight": definition.attack_weight, "managed": bool(stage.attack_managed_by_type.get(String(definition.id),true)) if stage is RuntimeStage else attack_value > 0.0}
	row.spawn = {"rank": definition.rank, "size_var": definition.size_var}
	row.scaling = {"radius": definition.radius, "hp": definition.base_hp(config), "armor": definition.armor,
		"hp_mult": config.enemy_hp_mult, "armor_mult": config.enemy_armor_mult, "character": config.character_scale,
		"visual": definition.visual_value("scale", 1.0), "collision": definition.visual_value("collision_scale", 1.0),
		"fixed_sprite": definition.id in EnemyDef.NATIVE_SPRITES}
	for key in ["hp", "armor", "radius", "speed", "fire_interval", "xp", "knockback", "hitstop_multiplier"]:
		if not is_finite(float(row[key])) or float(row[key]) < 0.0:
			return {}
	if row.id.is_empty() or row.hp <= 0.0 or row.radius <= 0.0:
		return {}
	if definition.behavior in [&"biter", &"hound", &"defender"]:
		row.bite = {"turn":definition.turn if definition.turn > 0.0 else 4.0}
		for key in ["bite_reach","bite_telegraph","bite_rest","bite_radius","bullet_dmg"]:
			if not definition.params.has(key): return {}
			row.bite[key] = float(definition.params[key])
		for value in row.bite.values():
			if not is_finite(value) or value < 0.0: return {}
		if row.bite.bite_telegraph <= 0.0: return {}
	if definition.behavior == &"hound":
		row.pack = {"count":maxi(1,int(definition.params.pack_count)), "accel":definition.accel if definition.accel > 0.0 else 2.0}
		for pair in [["gap","pack_gap"],["reach","pack_neighbor_radius"],["alignment","pack_alignment"],["cohesion","pack_cohesion"],["separation","pack_separation"]]:
			row.pack[pair[0]] = float(definition.params[pair[1]])
		for value in row.pack.values():
			if not is_finite(value): return {}
	if definition.behavior == &"lynx":
		row.lynx = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for pair in [["keep","keep"],["warn","telegraph"],["slash_speed","slash_speed"],["slash_size","slash_size"],["slash_range","slash_range"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.lynx[pair[0]] = float(definition.params[pair[1]])
		for value in row.lynx.values():
			if not is_finite(value) or value<0.0: return {}
		if row.lynx.warn<=0.0 or row.fire_interval<=0.0: return {}
	if definition.behavior == &"triangle":
		row.triangle={}
		for pair in [["move_time","move_time"],["stop_time","stop_time"],["span","span"],["trail_width","trail_width"],["trail_damage","trail_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.triangle[pair[0]]=float(definition.params[pair[1]])
		row.triangle.admission_duration=row.triangle.move_time+0.1
		for value in row.triangle.values():
			if not is_finite(value) or value<0.0: return {}
		if row.triangle.move_time<=0.0: return {}
	if definition.behavior == &"ruler":
		row.ruler={"accel":definition.accel,"beam_start_gap":maxf(0.0,float(definition.params.get("beam_start_gap",0.0)))}
		for pair in [["keep","keep"],["split_delay","split_delay"],["half_gap","half_gap"],["emit_back","emit_back"],["deploy_speed","deploy_speed"],["deploy_time","deploy_time"],["warn","telegraph"],["beam_len","beam_len"],["beam_width","beam_width"],["beam_time","beam_time"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.ruler[pair[0]]=float(definition.params[pair[1]])
		row.ruler.admission_duration=row.ruler.warn+row.ruler.beam_time+0.1
		for value in row.ruler.values():
			if not is_finite(value) or value<0.0: return {}
		if row.ruler.warn<=0.0: return {}
	if definition.behavior == &"cepheus":
		row.cepheus = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for key in ["keep","fire_interval","reinforce_interval","summon_time","mutiny_time","spacing","row_near","row_far","fan_radius","fan_step"]:
			if not definition.params.has(key): return {}
			row.cepheus[key] = float(definition.params[key])
		for value in row.cepheus.values():
			if not is_finite(value) or value<0.0: return {}
		if row.cepheus.summon_time<=0.0 or row.cepheus.fire_interval<=0.0 or row.cepheus.reinforce_interval<=0.0: return {}
	if definition.behavior == &"soldier":
		row.soldier = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for pair in [["bolt_speed","bolt_speed"],["damage","bullet_dmg"],["mutiny_shot","mutiny_shot"]]:
			if not definition.params.has(pair[1]): return {}
			row.soldier[pair[0]] = float(definition.params[pair[1]])
		for value in row.soldier.values():
			if not is_finite(value) or value<0.0: return {}
	if definition.behavior == &"auriga":
		row.auriga = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for pair in [["trail_step","trail_step"],["trail_time","trail_time"],["trail_width","trail_width"],["wheel_gap","wheel_gap"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.auriga[pair[0]] = float(definition.params[pair[1]])
		for value in row.auriga.values():
			if not is_finite(value) or value<0.0: return {}
	if definition.behavior == &"clock":
		row.clock = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for pair in [["warn","telegraph"],["hand_long","hand_long"],["hand_short","hand_short"],["hand_width","hand_width"],["long_speed","long_speed"],["short_speed","short_speed"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.clock[pair[0]] = float(definition.params[pair[1]])
		for key in row.clock:
			if not is_finite(row.clock[key]) or (key not in ["long_speed","short_speed"] and row.clock[key]<0.0): return {}
	if definition.behavior == &"corona":
		row.corona = {"capture_max":int(definition.params.get("capture_max",0))}
		for pair in [["capture_interval","capture_interval"],["pull_radius","pull_radius"],["pull","pull"],["ring","ring"],["spin","spin"],["telegraph","telegraph"],["align_angle","align_angle"],["throw_life","throw_life"],["throw_speed","throw_speed"],["effect","throw_effect_scale"]]:
			if not definition.params.has(pair[1]): return {}
			row.corona[pair[0]] = float(definition.params[pair[1]])
		for key in row.corona:
			if not is_finite(row.corona[key]) or (key!="spin" and row.corona[key]<0.0): return {}
		if row.corona.capture_max<1: return {}
		row.corona.admission_duration = row.corona.telegraph+TAU/maxf(absf(row.corona.spin),0.1)+row.corona.throw_life
		row.corona_types = []
		for key: String in definition.params:
			if not key.begins_with("throw_weight_"): continue
			var kind := key.trim_prefix("throw_weight_")
			if not definition.params.has("throw_damage_"+kind): continue
			var weight := float(definition.params[key])
			var damage := float(definition.params["throw_damage_"+kind])
			if not is_finite(weight) or not is_finite(damage) or damage<0.0: return {}
			row.corona_types.append({"id":row.corona_types.size()+1,"owner":1,"name":kind,"weight":maxf(0.0,weight),"damage":damage})
	if definition.behavior == &"pump":
		row.pump = {"accel":definition.accel,"store_max":int(definition.params.get("store_max",0)),"release_base":int(definition.params.get("release_base",0)),"mouth_radius":18.5*config.character_scale*definition.visual_value("scale",1.0)}
		for pair in [["pull_radius","pull_radius"],["pull","pull"],["swallow_reach","swallow_reach"],["swallow_interval","swallow_interval"],["grow","grow"],["telegraph","telegraph"],["lock_time","lock_time"],["shell_speed","shell_speed"],["shell_radius","shell_r"],["shell_range","shell_range"],["burst_radius","burst_radius"],["damage","bullet_dmg"],["recover","recover"],["release_per","release_per"],["release_speed","release_speed"],["release_damage","release_dmg"],["release_radius","release_radius"]]:
			if not definition.params.has(pair[1]): return {}
			row.pump[pair[0]] = float(definition.params[pair[1]])
		row.pump.admission_duration = row.pump.telegraph+0.3
		for value in row.pump.values():
			if not is_finite(value) or value<0.0: return {}
		if row.pump.telegraph<=0.0 or row.pump.store_max<1: return {}
	if definition.behavior == &"crab":
		row.crab = {}
		for pair in [["approach","approach"],["reach","reach"],["telegraph","telegraph"],["open_time","open_time"],["turn_angle","turn_angle"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			var value := float(definition.params[pair[1]])
			if not is_finite(value) or value<0.0: return {}
			row.crab[pair[0]] = value
		row.crab.admission_duration = row.crab.telegraph+row.crab.open_time+0.1
	if definition.behavior == &"aquila":
		row.aquila = {}
		for pair in [["keep","keep"],["aim_time","aim_time"],["lock_time","lock_time"],["dash_speed","dash_speed"],["dash_time","dash_time"],["drop_step","drop_step"],["blast_radius","blast_radius"],["blast_delay","blast_delay"],["damage","bullet_dmg"],["recover","recover"]]:
			if not definition.params.has(pair[1]): return {}
			var value := float(definition.params[pair[1]])
			if not is_finite(value) or value<0.0: return {}
			row.aquila[pair[0]] = value
		if row.aquila.lock_time<=0.0 or row.aquila.dash_speed<=0.0 or row.aquila.drop_step<=0.0: return {}
		row.aquila.admission_duration = row.aquila.aim_time+row.aquila.lock_time+row.aquila.dash_time+row.aquila.blast_delay+AttackDefaults.ZONE_FLASH
	if definition.behavior == &"phoenix":
		row.phoenix = {}
		for pair in [["retreat_distance","retreat_distance"],["retreat_time","retreat_time"],["telegraph","telegraph"],["dive_time","dive_time"],["impact_radius","impact_radius"],["impact_time","impact_time"],["impact_damage","impact_dmg"],["recover_time","recover_time"]]:
			if not definition.params.has(pair[1]): return {}
			var value := float(definition.params[pair[1]])
			if not is_finite(value) or value<0.0: return {}
			row.phoenix[pair[0]] = maxf(value,0.01) if pair[0] in ["retreat_time","telegraph","dive_time","recover_time"] else (maxf(value,0.05) if pair[0]=="impact_time" else value)
		row.phoenix.admission_duration = row.phoenix.retreat_time+row.phoenix.telegraph+row.phoenix.dive_time+row.phoenix.impact_time+0.1
	if definition.behavior == &"bomber":
		row.bomber = {"accel":definition.accel}
		for pair in [["trigger","trigger"],["rush","rush"],["blast_delay","blast_delay"],["blast_radius","blast_radius"],["blast_damage","blast_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.bomber[pair[0]] = float(definition.params[pair[1]])
		row.bomber.admission_duration = float(definition.params.get("telegraph",0.0))+row.bomber.blast_delay+0.1
		for value in row.bomber.values():
			if not is_finite(value) or value<0.0: return {}
	if definition.behavior == &"cross":
		row.cross_enemy = {"accel":definition.accel}
		for pair in [["stand_off","stand_off"],["align_tol","align_tol"],["telegraph","telegraph"],["beam_time","beam_time"],["beam_length","beam_len"],["beam_width","beam_width"],["rest","rest"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.cross_enemy[pair[0]] = float(definition.params[pair[1]])
		row.cross_enemy.admission_duration = row.cross_enemy.telegraph+row.cross_enemy.beam_time+0.1
		for value in row.cross_enemy.values():
			if not is_finite(value) or value<0.0: return {}
		if row.cross_enemy.telegraph<=0.0: return {}
	if definition.behavior == &"aquarius":
		row.aquarius = {"accel":definition.accel,"beams":int(definition.params.get("beams",0))}
		for pair in [["approach","approach"],["telegraph","telegraph"],["beam_time","beam_time"],["beam_length","beam_len"],["beam_width","beam_width"],["spread","beam_spread"],["rest","rest"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.aquarius[pair[0]] = float(definition.params[pair[1]])
		row.aquarius.admission_duration = row.aquarius.telegraph+row.aquarius.beam_time+0.1
		for value in row.aquarius.values():
			if not is_finite(value) or value<0.0: return {}
		if row.aquarius.telegraph<=0.0 or row.aquarius.beams<1: return {}
	if definition.behavior == &"crow":
		row.crow = {"flock":int(definition.params.get("flock",0))}
		if row.crow.flock<0 or row.crow.flock>2147483647: return {}
		for key in ["aim_spread","flock_gap","gather_width","gather_behind","gather_speed","exit_margin"]:
			if not definition.params.has(key): return {}
			row.crow[key] = float(definition.params[key])
			if not is_finite(row.crow[key]): return {}
	if definition.behavior == &"defender":
		row.defender = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for key in ["guard_arrive","guard_distance","guard_radius","guard_spacing"]:
			if not definition.params.has(key): return {}
			row.defender[key] = float(definition.params[key])
			if not is_finite(row.defender[key]): return {}
	if definition.behavior == &"split":
		row.split = {}
		for key in ["bud_interval","split_speed","split_guard"]:
			row.split[key] = float(definition.params.get(key,200.0 if key=="split_speed" else 0.0))
			if not is_finite(row.split[key]) or row.split[key]<0.0: return {}
		for key in ["max_buds","death_split","split_extra"]:
			row.split[key] = int(definition.params.get(key,0))
			if row.split[key]<0 or row.split[key]>2147483647: return {}
		if row.split.death_split>2147483647-row.split.split_extra: return {}
	if definition.behavior == &"reticle":
		row.reticle = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for pair in [["aim_time","aim_time"],["break_interval","break_interval"],["exit_margin","exit_margin"],["follow_gap","follow_gap"],["follow_reach","follow_reach"],["retreat_speed","retreat_speed"],["small_r","small_r"]]:
			if not definition.params.has(pair[1]): return {}
			row.reticle[pair[0]] = float(definition.params[pair[1]])
		for value in row.reticle.values():
			if not is_finite(value) or value<0.0: return {}
		if row.reticle.aim_time<=0.0: return {}
	if definition.behavior == &"dolphin":
		row.dolphin = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for pair in [["keep","keep"],["warn","telegraph"],["aim_turn","aim_turn"],["arc","wave_arc"],["radius","wave_radius"],["speed","wave_speed"],["width","wave_width"],["damage","bullet_dmg"],["enemy_damage","enemy_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.dolphin[pair[0]] = float(definition.params[pair[1]])
		for value in row.dolphin.values():
			if not is_finite(value) or value<0.0: return {}
		if row.dolphin.warn<=0.0 or row.fire_interval<=0.0: return {}
	if definition.behavior == &"pulser":
		row.pulser = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for pair in [["keep","keep"],["warn","telegraph"],["arc","wave_arc"],["radius","wave_radius"],["speed","wave_speed"],["width","wave_width"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.pulser[pair[0]] = float(definition.params[pair[1]])
		for value in row.pulser.values():
			if not is_finite(value) or value<0.0: return {}
		if row.pulser.warn<=0.0 or row.fire_interval<=0.0: return {}
	if definition.behavior == &"marlin":
		row.marlin = {"accel":definition.accel if definition.accel>0.0 else 2.0}
		for key in ["keep","telegraph","dash_speed","dash_time","recover"]:
			if not definition.params.has(key): return {}
			row.marlin[key] = float(definition.params[key])
		for value in row.marlin.values():
			if not is_finite(value) or value<0.0: return {}
		if row.fire_interval<=0.0: return {}
	if definition.behavior == &"sniper":
		row.sniper = {"accel":definition.accel if definition.accel>0.0 else 2.0,"damage":float(definition.params.get("bullet_dmg",0.0))}
		for key in ["keep","band_len","band_width","band_narrow","track_turn","search_turn","search_sway","search_period","lock_fill","lock_decay","laser_charge","laser_delay","laser_time","laser_width","cooldown"]:
			if not definition.params.has(key): return {}
			row.sniper[key] = float(definition.params[key])
		for value in row.sniper.values():
			if not is_finite(value) or value<0.0: return {}
		for key in ["lock_fill","search_period","band_width","band_narrow","laser_charge"]:
			if row.sniper[key]<=0.0: return {}
	if definition.behavior == &"battleship":
		row.battleship = {"weak_arc":definition.weak_arc,"volley":int(definition.params.get("volley",0)),"admission_duration":float(definition.params.get("telegraph",0.0))+float(definition.params.get("dash_time",definition.params.get("beam_time",definition.params.get("blast_delay",0.2))))+0.1}
		for pair in [["telegraph","telegraph"],["bullet_speed","bullet_speed"],["damage","bullet_dmg"],["slow","slow"],["spread","spread"]]:
			if not definition.params.has(pair[1]): return {}
			row.battleship[pair[0]] = float(definition.params[pair[1]])
		for value in row.battleship.values():
			if not is_finite(value) or value<0.0: return {}
		if row.battleship.telegraph<=0.0 or row.fire_interval<=0.0: return {}
	if definition.behavior == &"drift":
		row.drift = {"has_life":definition.params.has("life"),"life":float(definition.params.get("life",0.0)),"ram_guard":definition.gate==&"guard"}
		if not is_finite(row.drift.life) or row.drift.life<0.0: return {}
	if definition.behavior == &"rocket":
		row.rocket = {"blast_duration":AttackDefaults.ZONE_FLASH,"admission_duration":float(definition.params.get("telegraph",definition.params.get("windup",0.0)))+float(definition.params.get("dash_time",definition.params.get("beam_time",definition.params.get("blast_delay",0.2))))+0.1}
		for pair in [["life","life"],["fuse","fuse"],["blast_radius","blast_radius"],["blast_damage","blast_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.rocket[pair[0]] = float(definition.params[pair[1]])
		for value in row.rocket.values():
			if not is_finite(value) or value<0.0: return {}
		if row.rocket.life<=0.0: return {}
	if definition.behavior == &"missile":
		row.missile = {"accel":definition.accel,"admission_duration":float(definition.params.get("telegraph",0.0))+float(definition.params.get("dash_time",definition.params.get("beam_time",definition.params.get("blast_delay",0.2))))+0.1}
		for pair in [["keep","keep"],["telegraph","telegraph"],["missile_speed","missile_speed"],["missile_turn","missile_turn"],["damage","bullet_dmg"],["slow","slow"]]:
			if not definition.params.has(pair[1]): return {}
			row.missile[pair[0]] = float(definition.params[pair[1]])
		for value in row.missile.values():
			if not is_finite(value) or value<0.0: return {}
		if row.missile.telegraph<=0.0 or row.fire_interval<=0.0: return {}
	if definition.behavior == &"beamer":
		row.beamer = {"accel":definition.accel,"cross":bool(definition.params.get("cross",false))}
		for pair in [["keep","keep"],["telegraph","telegraph"],["beam_time","beam_time"],["beam_length","beam_len"],["beam_width","beam_width"],["damage","bullet_dmg"]]:
			if not definition.params.has(pair[1]): return {}
			row.beamer[pair[0]] = float(definition.params[pair[1]])
		row.beamer.admission_duration = row.beamer.telegraph+row.beamer.beam_time+0.1
		for key in ["accel","admission_duration","keep","telegraph","beam_time","beam_length","beam_width","damage"]:
			if not is_finite(row.beamer[key]) or row.beamer[key]<0.0: return {}
		if row.beamer.telegraph<=0.0 or row.fire_interval<=0.0: return {}
	if definition.behavior == &"shield":
		row.shield = {"accel": definition.accel if definition.accel > 0.0 else 2.0,
			"turn": definition.turn if definition.turn > 0.0 else 4.0, "weak_arc": definition.weak_arc}
		for key in ["front_arc", "reflect_speed", "reflect_life", "reflect_dmg", "reflect_interval", "shield_time"]:
			if not definition.params.has(key): return {}
			row.shield[key] = float(definition.params[key])
		for value in row.shield.values():
			if not is_finite(value) or value < 0.0: return {}
	if not is_finite(config.enemy_aim_lag) or config.enemy_aim_lag <= 0.0 or not is_finite(config.enemy_aim_speed) or config.enemy_aim_speed <= 0.0: return {}
	return {"version": 2, "enemies": [row], "motion": {"aim_lag": config.enemy_aim_lag, "aim_speed": config.enemy_aim_speed}}

## 共通生成から使う比較条件。未移行の通常ゲーム用データと混同しない。
static func build_probe(path: String) -> Error:
	var definition := load("res://data/enemies/splitling.tres") as EnemyDef
	var config := load("res://data/config.tres") as GameConfig
	var data := compile_enemy(definition, config)
	if data.is_empty(): return ERR_INVALID_DATA
	data["config"] = {}
	for key in PROBE_CONFIG_FIELDS: data.config[key] = config.get(key)
	data.config["xp_bonus"] = 1.0
	var weapon := load("res://data/weapons/W01_forward.tres") as WeaponDef
	if weapon == null: return ERR_INVALID_DATA
	data["forward"] = weapon.params.duplicate(true)
	data["visual_scale"] = 1.0 / definition.visual_value("collision_scale", 1.0)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK: return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "", true, true))
	error = file.get_error()
	file.close()
	return error

## 将来の出現個体は決めず、編集値から決まる曲線の傾きと強化区間だけを展開する。
static func compile_spawn_timeline(stage: StageDef, config: GameConfig) -> Dictionary:
	if stage == null or config == null or stage.phases.is_empty(): return {}
	var data := {"version": 2, "boss_start": stage.boss_start(config), "density": config.density_mult,
		"bonus_pop": config.bonus_pop, "phases": [], "curves": [], "windows": [], "types": {}}
	var bundle := compile_spawn_clips(stage,config)
	if bundle.is_empty(): return {}
	data.clip_bundle = bundle
	var types := {}
	for clip: RuntimeClip in stage.clips:
		for prepared in clip.prepared:
			for layout in prepared.layouts:
				for marker in layout.markers: types[String(marker.type)] = true
	for phase: PhaseDef in stage.phases:
		var row := {"id": String(phase.id), "start": phase.start, "pop_from": phase.pop_from, "pop_to": phase.pop_to,
			"rate": phase.rate, "xp_bonus": phase.xp_bonus, "attack_budget": phase.attack_budget, "mix": phase.mix.duplicate(), "wave_interval": phase.wave_interval, "wave_type": String(phase.wave_type)}
		for key in ["surge_interval", "surge_pop", "surge_ranged", "surge_elite"]: row[key] = phase.surge_value(key, config)
		data.phases.append(row)
		for type in phase.mix: types[String(type)] = true
		if phase.wave_interval > 0.0 and phase.wave_type != &"": types[String(phase.wave_type)] = true
	for curve: SpawnCurve in stage.zako_curves:
		var points := []
		for i in curve.points.size(): points.append([curve.points[i].x, curve.points[i].y, SpawnCurve._slope(curve.points, i) if curve.points.size() > 1 else 0.0])
		data.curves.append({"type": String(curve.type), "points": points})
		types[String(curve.type)] = true
	for window in stage.surge_windows(config): data.windows.append([window.x, window.y if is_finite(window.y) else -1.0])
	for type in types:
		var definition := load("res://data/enemies/%s.tres" % type) as EnemyDef
		if definition == null: return {}
		definition = StageEnemyTuning.resolve(definition, stage.enemy_tuning.get(type, {}))
		data.types[type] = {"rank": definition.rank, "max_alive": definition.max_alive, "ranged": definition.ranged}
	return data

## 通常のステージ生成結果から、比較用のネイティブ入力を作る。
static func build_spawn_timelines(output: String) -> Error:
	var config := load("res://data/config.tres") as GameConfig
	for name in DirAccess.get_files_at(output):
		if not name.begins_with("stage_") or not name.ends_with(".tres"): continue
		var stage := ResourceLoader.load(output.path_join(name), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RuntimeStage
		if stage == null: return ERR_INVALID_DATA
		var data := compile_spawn_timeline(stage, config)
		if data.is_empty(): return ERR_INVALID_DATA
		var file := FileAccess.open(output.path_join("dev/native_spawn_%d.bin" % stage.index), FileAccess.WRITE)
		if file == null: return FileAccess.get_open_error()
		file.store_var(data)
		var error := file.get_error()
		file.close()
		if error != OK: return error
	return OK

## 固定の配置と出現方向の組合せを先に変換する。画面の広さと機体の向きは実行中に適用する。
static func compile_formation(source: Dictionary) -> Dictionary:
	var out := {"version":2,"layouts":[],"entries":[]}
	for entry in source.get("entries",[]):
		out.entries.append({"weight":entry.weight,"pos":entry.pos})
	for layout in source.get("layouts",[]):
		var placements := []
		var types := []
		for marker in layout.markers: types.append(String(marker.type))
		for entry in source.get("entries",[]):
			var markers := []
			var basis := Transform2D(float(entry.rot),Vector2.ZERO)
			for marker in layout.markers:
				var local := basis * Transform2D(float(marker.rot),Vector2(marker.pos))
				markers.append({"type":String(marker.type),"offset":local.origin,"rotation":local.get_rotation()})
			placements.append(markers)
		out.layouts.append({"weight":layout.weight,"value":layout.get("value",-1.0),"managed":layout.get("attack_managed"),"types":types,"placements":placements})
	return out

## RuntimeStageへ展開済みのクリップを使い、実行中の群れと時計は保存しない。
static func compile_spawn_clips(stage: StageDef, config: GameConfig) -> Dictionary:
	var out := {"version":1,"base_view":config.base_view,"clips":[],"formations":[]}
	for source in stage.clips:
		if not source is RuntimeClip: return {}
		var references := []
		for prepared in source.prepared:
			references.append(out.formations.size())
			out.formations.append(compile_formation(prepared))
		var types := []
		for type in source.types: types.append(String(type))
		out.clips.append({"start":source.time,"end":source.end_time(),"groups":source.groups,"interval":source.interval,
			"priority":source.attack_priority,"types":types,"formations":references})
	return out

## 噛みつきの固定寿命と、生成済み表示資源が持つ終了演出を実行用へ渡す。
static func compile_bite_zone(visual_library: Resource) -> Dictionary:
	var scene := "res://scenes/attacks/zone_bite.tscn"
	if not ResourceLoader.exists(scene): scene = "res://scenes/attacks/zone.tscn"
	var layers: Dictionary = visual_library.get_meta("looks",{}).get(scene,{}) if visual_library != null else {}
	return {"version":1,"duration":AttackDefaults.ZONE_FLASH,"scene":scene,
		"hit":layers.get("Hit") != null or not layers.get("Hit_sprites",[]).is_empty(),
		"fade":layers.get("Fade") != null or not layers.get("Fade_sprites",[]).is_empty()}
