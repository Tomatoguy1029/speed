@tool
extends Resource
@export var adapter: StringName = &""
@export_file("*.tscn") var trial_scene := ""
@export var techniques: Array[Resource] = []
@export var conditions: Dictionary = {}
@export var combos: Dictionary = {}
@export var costs: Dictionary = {}
@export var layout: Dictionary = {}
@export_storage var condition_groups: Dictionary = {}
@export_storage var graph_nodes: Dictionary = {}

func source_for(node: String) -> String:
	return String(graph_nodes.get(node, {}).get("source", node))

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
	var primary: Dictionary = graph_nodes.get(technique, {})
	if not primary.get("hidden", false) and primary.get("connected", true): gates.append(conditions.get(technique, {}))
	for id in graph_nodes:
		if id != technique and source_for(id) == technique and not graph_nodes[id].get("hidden", false) and graph_nodes[id].get("connected", true):
			gates.append(conditions.get(id, {}))
	return gates
