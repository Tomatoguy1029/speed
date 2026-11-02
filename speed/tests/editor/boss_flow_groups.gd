## 条件選択を小さなまとまりに分け、接続変更を安全に保存・復元する。
extends SceneTree

var failures := 0
var graph: GraphEdit
var rules: Resource
var history := UndoRedo.new()
var finished := false

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	print("[boss-flow-groups] ", "PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _settle() -> void:
	for frame in 6: await process_frame

func _apply(state: Dictionary) -> void:
	for field in state: rules.set(field, state[field].duplicate(true))
	graph.show_rules(rules)

func _edit(before: Dictionary, after: Dictionary, title: String) -> void:
	history.create_action(title)
	history.add_do_method(_apply.bind(after))
	history.add_undo_method(_apply.bind(before))
	history.commit_action()

func _incoming(target: String) -> Array[String]:
	var sources: Array[String] = []
	for connection in graph.get_connection_list():
		if String(connection.to_node) == target: sources.append(String(connection.from_node))
	return sources

func exercise() -> void:
	create_timer(20.0).timeout.connect(func():
		if not finished:
			push_error("[boss-flow-groups] editor exercise timed out")
			quit(1))
	root.size = Vector2i(1280, 900)
	rules = load("res://data/bosses/ai/hydra_action_rules.tres").duplicate(true)
	rules.layout = {}
	graph = load("res://tools/editor/boss_flow/technique_graph.gd").new()
	graph.theme = ThemeDB.get_default_theme()
	root.add_child(graph)
	graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	graph.edit_requested.connect(_edit)
	graph.show_rules(rules)
	await _settle()

	var normal_hubs := {}
	var hub_counts := {}
	var ids: Array[String] = rules.node_ids()
	var every_technique_present := true
	var single_owner := true
	for id in ids:
		every_technique_present = every_technique_present and graph.get_node_or_null(NodePath(id)) is GraphNode
		var incoming := _incoming(id)
		var connected: bool = rules.graph_nodes.get(id, {}).get("connected", true)
		single_owner = single_owner and incoming.size() == (1 if connected else 0)
		for hub in incoming:
			hub_counts[hub] = int(hub_counts.get(hub, 0)) + 1
			if graph.category_for(id) == "normal": normal_hubs[hub] = true
	check(every_technique_present, "splitting condition-selection hubs keeps every technique visible")
	check(single_owner, "every connected technique has exactly one condition-selection hub")
	check(normal_hubs.size() >= 3, "normal techniques are split across multiple small condition-selection hubs")
	var bounded := true
	for count in hub_counts.values(): bounded = bounded and count <= 4
	check(bounded, "no default condition-selection hub collects more than four techniques")

	if normal_hubs.size() >= 2:
		var target := ""
		for id in ids:
			if graph.category_for(id) == "normal" and not _incoming(id).is_empty():
				target = id
				break
		var previous: String = _incoming(target)[0]
		var destination := ""
		for hub in normal_hubs:
			if hub != previous:
				destination = hub
				break
		var gates: Dictionary = rules.conditions.duplicate(true)
		var costs: Dictionary = rules.costs.duplicate(true)
		graph.connection_request.emit(destination, 0, target, 0)
		await _settle()
		check(_incoming(target) == [destination], "connecting a technique to another condition-selection hub replaces its previous edge")
		check(rules.conditions == gates and rules.costs == costs, "changing a technique's group preserves its trigger conditions and costs")
		history.undo()
		await _settle()
		check(_incoming(target) == [previous], "one undo restores the previous condition-selection hub")
		history.redo()
		await _settle()
		check(_incoming(target) == [destination], "redo restores the new condition-selection hub")
		DirAccess.make_dir_recursive_absolute("res://.content/tests")
		var path := "res://.content/tests/boss_flow_groups.tres"
		var saved := ResourceSaver.save(rules, path)
		check(saved == OK, "grouped technique rules save successfully")
		if saved == OK:
			var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			graph.show_rules(restored)
			await _settle()
			check(_incoming(target) == [destination], "saving and reloading preserves the selected condition-selection hub")
	else:
		check(false, "there are separate normal condition-selection hubs available for reconnecting techniques")
	graph.show_rules(rules)
	await _settle()
	var group_count: int = rules.condition_groups.size()
	graph.add_group()
	check(rules.condition_groups.size() == group_count + 1, "an author can add a separate condition-selection hub")
	history.undo()
	check(rules.condition_groups.size() == group_count, "adding a condition-selection hub is undoable")
	graph._select_nodes(["choose_normal"])
	var initial_count: int = rules.node_ids().size()
	var member_count: int = rules.condition_groups.choose_normal.nodes.size()
	graph.command("duplicate")
	await _settle()
	check(rules.condition_groups.size() == group_count + 1 and rules.node_ids().size() == initial_count + member_count, "duplicating a condition-selection hub includes its techniques and internal connections")
	history.undo()
	check(rules.condition_groups.size() == group_count and rules.node_ids().size() == initial_count, "one undo removes a copied hub and its techniques together")
	rules.layout["choose_normal"] = Vector2(240, 110)
	graph.show_rules(rules)
	await _settle()
	var hand_placed: Dictionary = rules.layout.duplicate(true)
	graph.arrange_categories()
	await _settle()
	var stacked := true
	for group in rules.condition_groups:
		var members: Array = rules.condition_groups[group].get("nodes", [])
		if members.is_empty(): continue
		var hub := graph.get_node_or_null(NodePath(group)) as GraphNode
		var first := graph.get_node_or_null(NodePath(members[0])) as GraphNode
		if hub == null or first == null: continue
		if first.position_offset.x <= hub.position_offset.x + hub.size.x or not is_equal_approx(first.position_offset.y, hub.position_offset.y): print("[boss-flow-groups] layout detail ", group, " hub=", hub.position_offset, " size=", hub.size, " first=", first.position_offset, " member=", members[0])
		stacked = stacked and first.position_offset.x > hub.position_offset.x + hub.size.x
		stacked = stacked and is_equal_approx(first.position_offset.y, hub.position_offset.y)
		for i in range(1, members.size()):
			var member := graph.get_node_or_null(NodePath(members[i])) as GraphNode
			if member != null: stacked = stacked and is_equal_approx(member.position_offset.x, first.position_offset.x) and member.position_offset.y > first.position_offset.y
	check(stacked, "automatic layout puts a hub left of its vertically stacked targets with a straight first edge")
	history.undo()
	check(rules.layout == hand_placed, "undo restores the original hand placement after automatic layout")
	var moved := GraphNode.new()
	moved.name = "snap_moved"
	moved.size = Vector2(180, 120)
	moved.position_offset = Vector2(10000, 5000)
	graph.add_child(moved)
	var nearby := GraphNode.new()
	nearby.name = "snap_nearby"
	nearby.size = Vector2(180, 120)
	nearby.position_offset = Vector2(10250, 5001)
	graph.add_child(nearby)
	var distant := GraphNode.new()
	distant.name = "snap_distant"
	distant.size = Vector2(180, 120)
	distant.position_offset = Vector2(15000, 4999)
	graph.add_child(distant)
	await _settle()
	graph.zoom = 1.0
	moved.selected = true
	graph._assist(moved)
	check(is_equal_approx(moved.position_offset.y, nearby.position_offset.y), "nearby node wins over a distant node with almost the same height")

	history.clear_history()
	history.free()
	graph.queue_free()
	await process_frame
	graph = null
	rules = null
	finished = true
	print("[boss-flow-groups] failures=", failures)
	quit(1 if failures else 0)
