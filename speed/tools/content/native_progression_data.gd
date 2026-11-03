## 比較用の固定成長データ。編集値とカタログ順を更新前に確定する。
extends RefCounted
const FIELDS := ["xp_base","xp_growth","xp_curve","level_heal","weapon_slots","trait_slots","weapon_max_level","trait_max_stacks","start_weapon_choices","owned_card_bias","reroll_count","levelup_bonus_chance","levelup_bonus_more","levelup_bonus_last","fallback_heal","base_max_speed","base_hp","dash_charge_time","base_crit_chance","crit_mult","pickup_radius","steer_accel","steer_rate","invuln_time","meteor_heal_frac"]
static func compile(cfg: GameConfig, profile: Dictionary) -> Dictionary:
	var data := {"version":1,"config":{},"profile":profile.duplicate(true),"weapons":[],"traits":[],"bonuses":{},"crit_max":1.0}
	for key in FIELDS: data.config[key] = cfg.get(key)
	data.rerolls = cfg.reroll_count + roundi(float(profile.add.get(&"reroll",0.0)))
	for category in [&"weapons",&"traits"]:
		for id in ContentManager.catalog.table(category):
			var entry = ContentManager.catalog.find(category,id)
			var definition = ContentManager.definition(category,id)
			data[category].append({"id":id,"comet_only":entry.comet_only if category==&"weapons" else false})
			if category==&"traits":
				var values := []
				for n in cfg.trait_max_stacks+1: values.append(definition.stack_bonus(n))
				data.bonuses[id] = values
				if id==&"T09": data.crit_max = float(definition.params.get("max",1.0))
	data.forward = ContentManager.definition(&"weapons",&"W01").params.duplicate(true)
	data.character_scale = cfg.character_scale
	return data
