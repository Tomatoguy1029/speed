extends RefCounted
var program: Dictionary
var adapter: Object
var cursor := 0
var elapsed := 0.0
var state: StringName = &"running"
var ticket: Object
var child: RefCounted
var branches: Array = []

func _init(value: Dictionary, owner_adapter: Object) -> void:
	program = value
	adapter = owner_adapter

func tick(dt: float) -> StringName:
	if state != &"running" or dt <= 0.0: return state
	match program.get("type", "action"):
		"wait":
			elapsed += dt
			if elapsed >= float(program.get("seconds", 0.0)): state = &"finished"
		"action":
			if ticket == null:
				ticket = adapter.start_step(String(program.get("id", "")))
				if ticket == null: state = &"failed"
			elif not ticket.running(): state = &"finished"
		"sequence":
			var children: Array = program.get("children", [])
			if cursor >= children.size():
				state = &"finished"
			else:
				if child == null: child = get_script().new(children[cursor], adapter)
				var result: StringName = child.tick(dt)
				if result == &"failed": state = result
				elif result == &"finished":
					cursor += 1
					child = null
					if cursor >= children.size(): state = &"finished"
		"parallel":
			if branches.is_empty():
				for node in program.get("children", []): branches.append(get_script().new(node, adapter))
			var completed := 0
			for branch in branches:
				var result: StringName = branch.tick(dt)
				if result == &"failed":
					cancel()
					return state
				if result == &"finished": completed += 1
			if completed == branches.size(): state = &"finished"
		_:
			state = &"failed"
	return state

func cancel() -> void:
	if ticket != null: ticket.cancel()
	if child != null: child.cancel()
	for branch in branches: branch.cancel()
	state = &"failed"
