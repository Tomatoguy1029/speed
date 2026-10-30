## 比較で対応する追跡敵の固定値を、編集元と本番の倍率から生成する。
@tool
extends RefCounted

const PROBE_CONFIG_FIELDS := ["start_radius", "base_max_speed", "stick_dead_zone", "mouse_dead_zone", "steer_cruise", "glide_hold", "glide_fade", "cruise_floor", "energy_cut", "cruise_drag", "overcap_decay", "field_radius", "boundary_push", "ship_radius", "crash_restitution", "ship_hurt_time", "draw_min_charge", "draw_length", "draw_step", "draw_confirm_delay", "draw_run_time", "draw_time_scale", "draw_run_slow_ref", "draw_run_scale_min", "boost_duration", "carry", "launch_ratio", "glide_speed_ratio", "base_attack", "atk_scale", "ram_speed_ratio", "crit_armor", "touch_damage", "contact_cooldown", "bounce_keep", "bounce_min_speed", "kill_hitstop", "kill_hitstop_cap", "kill_hitstop_regen", "hitstop_big_mult", "hitstop_crit_mult", "max_enemy_radius", "gem_max", "drop_base", "drop_max", "drop_power_exp", "big_crystal_shift_time", "big_crystal_xp", "big_crystal_weights_start", "big_crystal_weights_end", "world_tick_div", "grid_cell", "trace_radius", "character_scale"]

static func compile_enemy(definition: EnemyDef, config: GameConfig) -> Dictionary:
	if definition == null or config == null or definition.behavior not in [&"chase", &"shield"]:
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
	var definition := load("res://data/enemies/drifter.tres") as EnemyDef
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
	var data := {"version": 1, "boss_start": stage.boss_start(config), "density": config.density_mult,
		"bonus_pop": config.bonus_pop, "phases": [], "curves": [], "windows": [], "types": {}}
	var types := {}
	for phase: PhaseDef in stage.phases:
		var row := {"id": String(phase.id), "start": phase.start, "pop_from": phase.pop_from, "pop_to": phase.pop_to,
			"rate": phase.rate, "xp_bonus": phase.xp_bonus, "attack_budget": phase.attack_budget, "mix": phase.mix.duplicate()}
		for key in ["surge_interval", "surge_pop", "surge_ranged", "surge_elite"]: row[key] = phase.surge_value(key, config)
		data.phases.append(row)
		for type in phase.mix: types[String(type)] = true
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
