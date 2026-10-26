extends RefCounted
var random := RandomNumberGenerator.new()
var diagnostics: Dictionary = {}
var record_details := false

static func category(actions: Array) -> String:
	return "parallel" if actions.size() > 1 else String(actions[0].get("category", "single")) if not actions.is_empty() else ""

func weights_for(section: Dictionary, last: Array) -> Dictionary:
	for rule in section.get("probability_rules", []):
		if rule.get("previous", "") == category(last): return rule.weights
	return section.get("weights", {"single": 100.0})

func choose(candidates: Array, section: Dictionary, last: Array, _forbidden: Array = []) -> Array:
	var groups := {}
	for candidate in candidates:
		var kind: String = candidate.get("category", "single")
		if not groups.has(kind): groups[kind] = {}
		var id: String = candidate.id
		if not groups[kind].has(id): groups[kind][id] = []
		groups[kind][id].append([candidate])
	var cap := float(section.get("available", section.get("cap", INF)))
	var parallel := {}
	for i in candidates.size():
		if candidates[i].get("category", "single") != "single": continue
		for j in range(i + 1, candidates.size()):
			if candidates[j].get("category", "single") != "single": continue
			var pair := [candidates[i], candidates[j]]
			if not compatible([pair[0]], pair[1], cap, _forbidden): continue
			var key := identity(pair)
			if not parallel.has(key): parallel[key] = []
			parallel[key].append(pair)
	if not parallel.is_empty(): groups.parallel = parallel
	var weights := weights_for(section, last)
	var previous := identity(last)
	if section.get("avoid_repeat", true) and not previous.is_empty():
		var alternatives := groups.duplicate(true)
		var positive := false
		for kind in alternatives.keys():
			alternatives[kind].erase(previous)
			if alternatives[kind].is_empty(): alternatives.erase(kind)
			elif float(weights.get(kind, 0.0)) > 0.0: positive = true
		if positive: groups = alternatives
	var actions: Array = sample(groups, weights)
	if record_details:
		diagnostics["previous_identity"] = previous
		diagnostics["avoid_repeat"] = section.get("avoid_repeat", true)
		diagnostics["eligible_identities"] = {}
		for kind in groups: diagnostics.eligible_identities[kind] = groups[kind].keys()
	# 3個以上は選択済みペアから必要時だけ拡張し、全ての部分集合を作らない。
	if actions.size() > 1:
		var remaining := candidates.duplicate()
		while not remaining.is_empty() and random.randf() < 0.5:
			var next: Dictionary = remaining.pop_at(random.randi_range(0, remaining.size() - 1))
			if next.get("category", "single") == "single" and compatible(actions, next, cap, _forbidden):
				if not section.get("avoid_repeat", true) or identity(actions + [next]) != previous: actions = actions + [next]
	return actions

static func identity(actions: Array) -> String:
	var ids := PackedStringArray()
	for action in actions: ids.append(String(action.id))
	ids.sort()
	return "|".join(ids)

static func compatible(actions: Array, next: Dictionary, cap: float, forbidden: Array) -> bool:
	var cost := float(next.cost)
	for action in actions:
		cost += float(action.cost)
		if action.get("exclusive", false) or next.get("exclusive", false): return false
		for part in action.get("parts", []):
			if part in next.get("parts", []): return false
		for pair in forbidden:
			if pair.size() == 2 and ((pair[0] == action.id and pair[1] == next.id) or (pair[1] == action.id and pair[0] == next.id)): return false
	return cost <= cap + 0.00001

func sample(groups: Dictionary, weights: Dictionary) -> Array:
	var total := 0.0
	for kind in groups: total += maxf(0.0, float(weights.get(kind, 0.0)))
	diagnostics = {"available": groups.keys(), "weights": weights, "total": total}
	if total <= 0.0: return []
	var cursor := random.randf() * total
	if record_details: diagnostics["draw"] = cursor
	for kind in groups:
		cursor -= maxf(0.0, float(weights.get(kind, 0.0)))
		if cursor < 0.0:
			var ids: Array = groups[kind].keys()
			var variants: Array = groups[kind][ids[random.randi_range(0, ids.size() - 1)]]
			return variants[random.randi_range(0, variants.size() - 1)]
	return []
