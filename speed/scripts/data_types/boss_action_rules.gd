@tool
extends Resource
@export var adapter: StringName = &""
@export_file("*.tscn") var trial_scene := ""
@export var techniques: Array[Resource] = []
@export var allow_parallel_attacks := false
@export var conditions: Dictionary = {}
@export var combos: Dictionary = {}
@export var costs: Dictionary = {}
@export var selection_bias: Dictionary = {}
@export var layout: Dictionary = {}
@export_storage var condition_groups: Dictionary = {}
@export_storage var graph_nodes: Dictionary = {}

func source_for(node: String) -> String:
	return String(graph_nodes.get(node, {}).get("source", node))

func group_for_node(node: String) -> String:
	for group in condition_groups:
		if node in condition_groups[group].get("nodes", []): return String(group)
	return ""

func category_for_group(group: String) -> String:
	if not condition_groups.has(group): return ""
	var saved := String(condition_groups[group].get("category", ""))
	if saved in ["normal", "combo", "major"]: return saved
	for kind in ["normal", "combo", "major"]:
		if group.begins_with("choose_" + kind): return kind
	for node in condition_groups[group].get("nodes", []):
		var source := source_for(String(node))
		for move in techniques:
			if String(move.technique) == source: return "normal" if move.category == &"single" else String(move.category)
		if combos.has(source): return "combo"
	return "normal"

func active_gate_entries_for(technique: String) -> Array:
	var entries: Array = []
	var ids := [technique]
	for node in graph_nodes:
		if String(node) != technique and source_for(String(node)) == technique: ids.append(String(node))
	for id in ids:
		var info: Dictionary = graph_nodes.get(id, {})
		if info.get("hidden", false) or not info.get("connected", true): continue
		var group := group_for_node(id)
		var kind := category_for_group(group)
		if kind.is_empty():
			kind = "combo" if combos.has(technique) else "normal"
			for move in techniques:
				if String(move.technique) == technique: kind = "normal" if move.category == &"single" else String(move.category)
		entries.append({"node": id, "group": group, "category": kind, "gate": conditions.get(id, {})})
	return entries

func node_ids() -> Array[String]:
	var ids: Array[String] = []
	for move in techniques: ids.append(String(move.technique))
	for id in combos:
		if not ids.has(id): ids.append(id)
	for id in graph_nodes:
		if not ids.has(id): ids.append(id)
	return ids.filter(func(id): return not graph_nodes.get(id, {}).get("hidden", false))

func active_gates_for(technique: String) -> Array:
	var gates: Array = []
	for entry in active_gate_entries_for(technique): gates.append(entry.gate)
	return gates
