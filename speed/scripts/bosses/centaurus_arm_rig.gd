## 接続点の設定・手付けIK・保存済みポーズの接続補正を共有する。
extends RefCounted

const ARMS := {"right": "RightArm", "left": "LeftArm"}
var root: Node2D

func _init(parts: Node2D) -> void:
	root = parts

func upper(side: String) -> Node2D:
	return root.get_node(ARMS[side]) as Node2D

func lower(side: String) -> Node2D:
	return upper(side).get_node("Elbow") as Node2D

func hand(side: String) -> Node2D:
	return lower(side).get_node("Hand") as Node2D

func definition(side: String) -> Dictionary:
	return root.animation_data.arm_joints.get(side, {})

func ensure_definitions() -> bool:
	var changed := false
	for side in ARMS:
		if definition(side).is_empty():
			reset_definition(side)
			changed = true
	return changed

func reset_definition(side: String) -> void:
	root.animation_data.arm_joints[side] = {
		"shoulder": Vector2.ZERO, "upper_end": lower(side).position,
		"lower_start": Vector2.ZERO, "lower_end": hand(side).position,
		"hand_start": Vector2.ZERO, "grip": Vector2(9, 10), "bend": 1.0,
	}
	var p := points(side)
	definition(side).bend = -1.0 if (p.wrist - p.shoulder).cross(p.elbow - p.shoulder) < 0.0 else 1.0
	_rebase_origins(side)

func points(side: String) -> Dictionary:
	var config := definition(side)
	return {"shoulder": upper(side).to_global(config.shoulder),
		"elbow": upper(side).to_global(config.upper_end),
		"wrist": lower(side).to_global(config.lower_end),
		"grip": hand(side).to_global(config.grip)}

func set_point(side: String, joint: String, world: Vector2) -> void:
	var config := definition(side)
	match joint:
		"shoulder": config.shoulder = upper(side).to_local(world)
		"elbow":
			config.upper_end = upper(side).to_local(world)
			config.lower_start = lower(side).to_local(world)
		"wrist":
			config.lower_end = lower(side).to_local(world)
			config.hand_start = hand(side).to_local(world)
		"grip": config.grip = hand(side).to_local(world)
	_rebase_origins(side)

func _rebase_origins(side: String) -> void:
	var poses: Array = root.animation_data.poses.values()
	for frames: Array in root.animation_data.clips.values():
		for frame: Dictionary in frames: poses.append(frame.pose)
	var path: String = ARMS[side]
	for pose: Dictionary in poses:
		if pose.has(path) and pose[path].get("connected", false):
			var entry: Dictionary = pose[path]
			entry.joint_origin = entry.position + Transform2D(float(entry.rotation), entry.scale, float(entry.get("skew", 0.0)), Vector2.ZERO) * definition(side).shoulder

func connected(side: String) -> bool:
	return bool(upper(side).get_meta("joint_enabled", false))

func set_connected(side: String, enabled: bool) -> void:
	upper(side).set_meta("joint_enabled", enabled)
	if enabled: _connect(side)

func _connect(side: String) -> void:
	var config := definition(side)
	var forearm := lower(side)
	var palm := hand(side)
	forearm.position = config.upper_end - _offset(forearm, config.lower_start)
	palm.position = config.lower_end - _offset(palm, config.hand_start)

func connect_active() -> void:
	for side in ARMS:
		if not definition(side).is_empty() and connected(side): _connect(side)

func _offset(node: Node2D, point: Vector2) -> Vector2:
	return node.transform * point - node.position

func _rotate_at(node: Node2D, pivot: Vector2, rotation: float) -> void:
	var parent := node.get_parent() as Node2D
	var at := parent.to_local(node.to_global(pivot))
	node.rotation = rotation
	node.position = at - _offset(node, pivot)

func set_rotation(side: String, joint: int, rotation: float) -> void:
	var config := definition(side)
	var node: Node2D = [upper(side), lower(side), hand(side)][joint]
	var pivot: Vector2 = [config.shoulder, config.lower_start, config.hand_start][joint]
	_rotate_at(node, pivot, rotation)
	set_connected(side, true)

func _aim(node: Node2D, start: Vector2, end: Vector2, target: Vector2) -> void:
	var parent := node.get_parent() as Node2D
	var direction := parent.to_local(target) - parent.to_local(node.to_global(start))
	var bone := _offset(node, end - start)
	if direction.length_squared() < 0.000001 or bone.length_squared() < 0.000001: return
	_rotate_at(node, start, node.rotation + bone.angle_to(direction))

func move_joint(side: String, joint: String, target: Vector2) -> bool:
	if joint == "grip": return solve(side, target)
	var config := definition(side)
	match joint:
		"shoulder":
			var arm := upper(side)
			var parent := arm.get_parent() as Node2D
			arm.position = parent.to_local(target) - _offset(arm, config.shoulder)
		"elbow": _aim(upper(side), config.shoulder, config.upper_end, target)
		"wrist": _aim(lower(side), config.lower_start, config.lower_end, target)
		_: return false
	set_connected(side, true)
	return true

func solve(side: String, grip_target: Vector2) -> bool:
	var config := definition(side)
	var arm := upper(side)
	var forearm := lower(side)
	var palm := hand(side)
	var palm_transform := palm.global_transform
	var old_elbow := forearm.position
	var old_hand := palm.position
	var wrist_target := grip_target - (palm.to_global(config.grip) - palm.to_global(config.hand_start))
	_connect(side)
	var p := points(side)
	var a: Vector2 = p.shoulder
	var length_a: float = a.distance_to(p.elbow)
	var length_b: float = forearm.to_global(config.lower_start).distance_to(p.wrist)
	if minf(length_a, length_b) < 0.0001:
		forearm.position = old_elbow
		palm.position = old_hand
		return false
	var direction := (wrist_target - a).normalized()
	if direction == Vector2.ZERO: direction = Vector2.DOWN
	var epsilon := minf(0.01, minf(length_a, length_b) * 0.1)
	var distance := clampf(a.distance_to(wrist_target), absf(length_a - length_b) + epsilon, length_a + length_b - epsilon)
	var along := (length_a * length_a + distance * distance - length_b * length_b) / (2.0 * distance)
	var elbow := a + direction * along + direction.orthogonal() * sqrt(maxf(0.0, length_a * length_a - along * along)) * float(config.bend)
	var target := a + direction * distance
	_aim(arm, config.shoulder, config.upper_end, elbow)
	_connect(side)
	_aim(forearm, config.lower_start, config.lower_end, target)
	_connect(side)
	# 非等方の拡大率でも、接続を保って届く範囲へ近づける。
	for iteration in 24:
		if forearm.to_global(config.lower_end).distance_to(wrist_target) < 0.05: break
		_aim(forearm, config.lower_start, config.lower_end, wrist_target)
		_connect(side)
		var parent := arm.get_parent() as Node2D
		var from := parent.to_local(forearm.to_global(config.lower_end)) - parent.to_local(a)
		var toward := parent.to_local(wrist_target) - parent.to_local(a)
		_rotate_at(arm, config.shoulder, arm.rotation + from.angle_to(toward))
		_connect(side)
	var wrist := forearm.to_global(config.lower_end)
	palm.global_transform = Transform2D(palm_transform.x, palm_transform.y,
		wrist - palm_transform.x * config.hand_start.x - palm_transform.y * config.hand_start.y)
	arm.set_meta("joint_enabled", true)
	return true

func side_for(node: Node2D) -> String:
	for side in ARMS:
		if node in [upper(side), lower(side), hand(side)]: return side
	return ""

func pivot_for(side: String, node: Node2D) -> Vector2:
	var config := definition(side)
	if node == upper(side): return config.shoulder
	if node == lower(side): return config.lower_start
	return config.hand_start

func preserve_pivot(side: String, node: Node2D, world: Vector2) -> void:
	var parent := node.get_parent() as Node2D
	var pivot := pivot_for(side, node)
	node.position = parent.to_local(world) - _offset(node, pivot)

func bind_bow(bow: Node2D, side: String) -> void:
	bow.set_meta("bow_hand", side)
	bow.set_meta("bow_offset", Vector2.ZERO)
	bow.set_meta("bow_rotation", bow.global_rotation - hand(side).global_rotation)
	follow_bows()

func update_bow_offset(bow: Node2D) -> void:
	var side := String(bow.get_meta("bow_hand", ""))
	if definition(side).is_empty(): return
	bow.set_meta("bow_offset", hand(side).to_local(bow.to_global(Vector2(5, 34))) - definition(side).grip)
	bow.set_meta("bow_rotation", bow.global_rotation - hand(side).global_rotation)

func follow_bows() -> void:
	for part: Node2D in root._editable.values():
		var side := String(part.get_meta("bow_hand", ""))
		if definition(side).is_empty(): continue
		var palm := hand(side)
		part.global_rotation = palm.global_rotation + float(part.get_meta("bow_rotation", 0.0))
		var parent := part.get_parent() as Node2D
		var at := palm.to_global(definition(side).grip + Vector2(part.get_meta("bow_offset", Vector2.ZERO)))
		part.position = parent.to_local(at) - _offset(part, Vector2(5, 34))

func capture_fields(pose: Dictionary) -> void:
	if root.animation_data.arm_joints.is_empty(): return
	for side in ARMS:
		if definition(side).is_empty(): continue
		var arm := upper(side)
		var entry: Dictionary = pose[ARMS[side]]
		entry.connected = connected(side)
		if connected(side): entry.joint_origin = arm.position + _offset(arm, definition(side).shoulder)
	for path in pose:
		var part: Node2D = root._editable[path]
		var side := String(part.get_meta("bow_hand", ""))
		if side.is_empty(): continue
		pose[path].bow_hand = side
		pose[path].bow_offset = part.get_meta("bow_offset", Vector2.ZERO)
		pose[path].bow_rotation = part.get_meta("bow_rotation", 0.0)

func apply_fields(pose: Dictionary) -> void:
	if root.animation_data.arm_joints.is_empty(): return
	for side in ARMS:
		var arm := upper(side)
		var entry: Dictionary = pose.get(ARMS[side], {})
		arm.set_meta("joint_enabled", bool(entry.get("connected", false)))
		if definition(side).is_empty() or not connected(side): continue
		if entry.has("joint_origin"):
			arm.position = entry.joint_origin - _offset(arm, definition(side).shoulder)
		_connect(side)
	for path in root._editable:
		var part: Node2D = root._editable[path]
		var entry: Dictionary = pose.get(path, {})
		part.set_meta("bow_hand", String(entry.get("bow_hand", "")))
		part.set_meta("bow_offset", entry.get("bow_offset", Vector2.ZERO))
		part.set_meta("bow_rotation", entry.get("bow_rotation", 0.0))
	follow_bows()
