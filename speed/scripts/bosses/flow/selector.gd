extends RefCounted
var random := RandomNumberGenerator.new()
var diagnostics: Dictionary = {}

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
	return sample(groups, weights_for(section, last))

func sample(groups: Dictionary, weights: Dictionary) -> Array:
	var total := 0.0
	for kind in groups: total += maxf(0.0, float(weights.get(kind, 0.0)))
	diagnostics = {"available": groups.keys(), "weights": weights, "total": total}
	if total <= 0.0: return []
	var cursor := random.randf() * total
	for kind in groups:
		cursor -= maxf(0.0, float(weights.get(kind, 0.0)))
		if cursor < 0.0:
			var ids: Array = groups[kind].keys()
			var variants: Array = groups[kind][ids[random.randi_range(0, ids.size() - 1)]]
			return variants[random.randi_range(0, variants.size() - 1)]
	return []
