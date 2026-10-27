## 通常育成完了後の候補と、ラン内だけの加算強化。固定データはPostMaxConfig、選択回数はRunStateが所有する。
class_name PostMaxProgression
extends RefCounted

var ctx: RunContext
## 特性・永続強化を含み、全MAX後の増分を除く基準値。
var baseline: Dictionary = {}
var data: PostMaxConfig:
	get: return ctx.cfg.post_max
var stacks: Dictionary:
	get: return ctx.state.post_max_stacks

func setup(context: RunContext) -> void:
	ctx = context

func factor(id: StringName) -> float:
	return data.factor(id, stacks)

func crit_reserve_limit() -> float:
	var trait_def := ContentManager.definition(&"traits", &"T09") as TraitDef
	var cap := minf(1.0, float(trait_def.params.get("max", 1.0)))
	var fully_trained := minf(cap, ctx.cfg.base_crit_chance + float(trait_def.params.get("per_stack", 0.0)) * ctx.cfg.trait_max_stacks)
	return maxf(0.0, cap - fully_trained)

## 各カードの実効値。倍率は増分、固定値は加算、充填は秒数。
func effect(id: StringName, counts: Dictionary) -> float:
	var v := data.amount(id, counts)
	match id:
		&"crit_chance": return minf(crit_reserve_limit(), v)
		&"invulnerability": return minf(maxf(0.0, data.maximum_invulnerability - float(baseline.get(id, 0.0))), v)
		&"repair": return minf(maxf(0.0, data.maximum_repair_fraction - float(baseline.get(id, 0.0))), v)
		&"weapon_interval": return minf(1.0 - data.minimum_time_ratio, v)
		&"charge_time": return data.reduced(float(baseline.get(id, ctx.cfg.dash_charge_time)), id, counts, data.minimum_charge_time)
	return v

func apply_stats() -> void:
	var s := ctx.state.stats
	baseline = {&"max_speed": s.max_speed, &"max_hp": s.max_hp, &"crit_chance": s.crit_chance,
		&"crit_mult": s.crit_mult, &"pickup_radius": s.pickup_radius, &"line_length": ctx.cfg.draw_length * s.length_mult,
		&"charge_time": s.charge_time, &"xp_gain": s.xp_mult,
		&"acceleration": ctx.cfg.steer_accel, &"turn_rate": ctx.cfg.steer_rate,
		&"invulnerability": ctx.cfg.invuln_time, &"repair": ctx.cfg.meteor_heal_frac,
		&"pickup_speed": 1.0}
	s.max_speed *= factor(&"max_speed")
	s.max_hp += effect(&"max_hp", stacks)
	s.crit_chance += effect(&"crit_chance", stacks)
	s.crit_mult += effect(&"crit_mult", stacks)
	s.xp_pickup_radius = s.pickup_radius * factor(&"pickup_radius")
	s.length_mult *= factor(&"line_length")
	s.charge_time = effect(&"charge_time", stacks)
	s.xp_gain_mult = factor(&"xp_gain")
	s.acceleration = ctx.cfg.steer_accel * factor(&"acceleration")
	s.turn_rate = ctx.cfg.steer_rate * factor(&"turn_rate")
	s.invulnerability = ctx.cfg.invuln_time + effect(&"invulnerability", stacks)
	s.repair_fraction = ctx.cfg.meteor_heal_frac + effect(&"repair", stacks)
	s.pickup_speed_mult = factor(&"pickup_speed")

func has_target(id: StringName) -> bool:
	if id not in [&"weapon_interval", &"projectile_speed", &"duration", &"knockback", &"area", &"followup"]:
		return true
	for weapon in ctx.state.weapons:
		var target := data.target(weapon)
		var key := String(id)
		if id == &"weapon_interval": key = "interval"
		if id == &"projectile_speed": key = "projectile"
		if target.has(key):
			if id != &"weapon_interval" or _interval_can_improve(weapon, target): return true
	return false

func _interval_can_improve(weapon: StringName, target: Dictionary) -> bool:
	var next := stacks.duplicate()
	next[&"weapon_interval"] = int(next.get(&"weapon_interval", 0)) + 1
	for base: float in interval_baselines(weapon, target).values():
		if data.reduced(base, &"weapon_interval", next, data.minimum_interval) < data.reduced(base, &"weapon_interval", stacks, data.minimum_interval) - 0.000001:
			return true
	return false

func interval_baselines(weapon: StringName, target: Dictionary) -> Dictionary:
	var behavior: WeaponBehavior = ctx.loadout.weapon_behaviors.get(weapon)
	var values := {}
	if behavior == null: return values
	for key in target.get("interval", []):
		var raw: Variant = behavior.def.params.get(key, 0.0)
		var base: float
		if raw is Array:
			base = float(raw[clampi(behavior.level - 1, 0, raw.size() - 1)])
		else:
			base = float(raw) / behavior.rate_k()
		values[key] = base
	return values

func eligible(id: StringName) -> bool:
	if not data.increments.has(String(id)) or float(data.increments[String(id)]) <= 0.0: return false
	if id == &"heal": return ctx.state.ship_hp < ctx.state.stats.max_hp
	if not has_target(id): return false
	var next := stacks.duplicate()
	next[id] = int(next.get(id, 0)) + 1
	return absf(effect(id, next) - effect(id, stacks)) > 0.000001

func cards() -> Array:
	var out: Array = []
	for key in data.increments:
		var id := StringName(key)
		if eligible(id):
			out.append({"kind": &"post_max", "id": id, "level": int(stacks.get(id, 0)) + 1,
				"weight": 1.0, "info": card_info(id)})
	return out

func select(id: StringName) -> bool:
	if not ctx.loadout.normal_progression_complete() or not eligible(id): return false
	if id == &"heal":
		ctx.ship.heal(ctx.state.stats.max_hp * float(data.increments.heal))
	else:
		stacks[id] = int(stacks.get(id, 0)) + 1
	return true

func card_info(id: StringName) -> Dictionary:
	var next := stacks.duplicate()
	next[id] = int(next.get(id, 0)) + 1
	var before := effect(id, stacks)
	var after := effect(id, next)
	var text: String
	var tooltip_text := ""
	if id == &"heal":
		var hp := ctx.state.ship_hp
		text = TranslationServer.translate("postmax.heal_desc").format({percent = _number(float(data.increments.heal) * 100.0),
			a = _number(hp), b = _number(minf(ctx.state.stats.max_hp, hp + ctx.state.stats.max_hp * float(data.increments.heal)))})
	elif id == &"weapon_interval":
		# 絶対秒の下限に先に届く武器があるため、要求倍率ではなく武器ごとの実効短縮を表示する。
		var lines: Array[String] = []
		var details: Array[String] = []
		for weapon in ctx.state.weapons:
			var values := interval_baselines(weapon, data.target(weapon))
			var reductions_before: Array[float] = []
			var reductions_after: Array[float] = []
			var entry := ContentManager.catalog.find(&"weapons", weapon)
			for key in values:
				var base: float = values[key]
				var a := data.reduced(base, id, stacks, data.minimum_interval)
				var b := data.reduced(base, id, next, data.minimum_interval)
				if is_equal_approx(a, b): continue
				reductions_before.append((1.0 - a / base) * 100.0)
				reductions_after.append((1.0 - b / base) * 100.0)
				details.append("%s %s: %.3f → %.3fs (−%s → −%s%%)" % [entry.get_display_name(), TranslationServer.translate("postmax.interval." + String(key)), a, b,
					_number((1.0 - a / base) * 100.0), _number((1.0 - b / base) * 100.0)])
			if not reductions_before.is_empty():
				lines.append("%s\n−%s → −%s%%" % [entry.get_display_name(), _range(reductions_before), _range(reductions_after)])
		text = TranslationServer.translate("postmax.interval_total") + "\n" + "\n".join(lines)
		tooltip_text = TranslationServer.translate("postmax.interval_total") + "\n" + "\n".join(details)
	else:
		var unit := "%"
		var value_before := before * 100.0
		var value_after := after * 100.0
		if id in [&"crit_chance", &"repair"]:
			unit = TranslationServer.translate("postmax.points")
		elif id in [&"max_hp", &"crit_mult", &"invulnerability"]:
			value_before = before
			value_after = after
			unit = "HP" if id == &"max_hp" else ("s" if id == &"invulnerability" else "×")
		elif id == &"charge_time":
			value_before = (1.0 - before / float(baseline[id])) * 100.0
			value_after = (1.0 - after / float(baseline[id])) * 100.0
		text = TranslationServer.translate("postmax.total").format({a = _number(value_before), b = _number(value_after), unit = unit})
		if baseline.has(id):
			text += "\n" + TranslationServer.translate("postmax.current").format({a = _number(current_value(id, stacks)), b = _number(current_value(id, next))})
		if id == &"max_hp": text += "\n" + TranslationServer.translate("postmax.keep_hp")
	var targets_text := target_text(id)
	if not targets_text.is_empty(): text += "\n" + targets_text
	var change := after - before
	var summary: String
	match id:
		&"heal": summary = "+%s%% HP" % _number(float(data.increments.heal) * 100.0)
		&"weapon_interval": summary = TranslationServer.translate("postmax.summary.interval").format({n = _number(change * 100.0)})
		&"charge_time": summary = TranslationServer.translate("postmax.summary.charge").format({n = _number(-change)})
		&"max_hp": summary = "+%s HP" % _number(change)
		&"invulnerability": summary = TranslationServer.translate("postmax.summary.invulnerability").format({n = _number(change)})
		&"crit_mult": summary = TranslationServer.translate("postmax.summary.multiplier").format({n = _number(change)})
		&"crit_chance", &"repair": summary = TranslationServer.translate("postmax.summary.points").format({n = _number(change * 100.0)})
		_: summary = "+%s%%" % _number(change * 100.0)
	return {"tag": TranslationServer.translate("postmax.tag"), "name": TranslationServer.translate("postmax." + String(id)),
		"desc": summary, "tooltip_desc": text if tooltip_text.is_empty() else tooltip_text,
		"color": Color("#9fe8ff")}

func current_value(id: StringName, counts: Dictionary) -> float:
	var base := float(baseline.get(id, 0.0))
	if id == &"charge_time": return effect(id, counts)
	if id in [&"max_hp", &"crit_chance", &"crit_mult", &"invulnerability", &"repair"]:
		var v := base + effect(id, counts)
		return v * 100.0 if id in [&"crit_chance", &"repair"] else v
	return base * (1.0 + effect(id, counts))

func target_text(id: StringName) -> String:
	var labels: Array[String] = []
	if id == &"area" or id == &"followup":
		for weapon in ctx.state.weapons:
			if data.target(weapon).has(String(id)):
				labels.append(TranslationServer.translate("postmax.target." + String(weapon) + "." + String(id)))
	return "\n".join(labels)

func _number(v: float) -> String:
	return ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func _range(values: Array[float]) -> String:
	var low: float = values.min()
	var high: float = values.max()
	return _number(low) if is_equal_approx(low, high) else "%s–%s" % [_number(low), _number(high)]
