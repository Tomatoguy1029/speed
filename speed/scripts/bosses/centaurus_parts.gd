extends Node2D

const LIGHTING = preload("res://data/visuals/enemy_lighting.tres")
const BOW_REGIONS = [
	Rect2(300, 110, 116, 18), Rect2(317, 148, 98, 18),
	Rect2(340, 176, 76, 18), Rect2(375, 203, 41, 18),
	Rect2(462, 225, 9, 52), Rect2(484, 226, 10, 68),
	Rect2(300, 61, 116, 10), Rect2(301, 82, 114, 12),
	Rect2(407, 225, 9, 22), Rect2(424, 225, 9, 28), Rect2(443, 225, 9, 38),
]
const BOW_GRIPS = [Vector2(58, 15), Vector2(49, 14), Vector2(38, 12), Vector2(20, 16), Vector2(4, 26), Vector2(5, 34), Vector2(58, 5), Vector2(57, 8), Vector2(4, 11), Vector2(4, 14), Vector2(4, 19)]
## 保存済みの通常・縦向き・Bow Upの番号を保ち、選択欄だけを回転順に並べる。
const BOW_VARIANT_ORDER = [0, 1, 2, 3, 8, 9, 10, 4, 5, 6, 7]
const ANIMATIONS = preload("res://data/visuals/centaurus_animation.tres")
const ARM_RIG = preload("res://scripts/bosses/centaurus_arm_rig.gd")
var animation_data: Resource = ANIMATIONS
var arm_rig: RefCounted
var _bow_frames: Array[AtlasTexture] = []
var _editable: Dictionary = {}
var _bases: Array[Sprite2D] = []
var _rest: Dictionary = {}
var _clip := ""
var _clip_time := 0.0
var _shot_interval := 0.4

func _ready() -> void:
	var sheet: Texture2D = ($Bow/Bow.texture as AtlasTexture).atlas
	for region in BOW_REGIONS:
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = region
		texture.filter_clip = true
		_bow_frames.append(texture)
	$Bow.set_meta("bow_variant", 0)
	_set_bow_variant($Bow, 0)
	_configure_lighting(self)
	refresh_parts()
	arm_rig = ARM_RIG.new(self)
	_rest = capture_pose()
	for definition: Dictionary in animation_data.extra_parts: add_extra(definition)
	apply_pose(animation_data.poses.get("neutral", _rest))
	_open_editor_if_main.call_deferred()

func refresh_parts() -> void:
	_editable.clear()
	_bases.clear()
	_collect(self)

func _collect(parent: Node) -> void:
	for child in parent.get_children():
		if child is Sprite2D and child.name == &"Base": _bases.append(child)
		if child is Node2D and child.has_meta("part_label"):
			_editable[String(get_path_to(child))] = child
		_collect(child)

func capture_pose() -> Dictionary:
	var pose := {}
	for path in _editable:
		var part: Node2D = _editable[path]
		pose[path] = {"position": part.position, "rotation": part.rotation, "scale": part.scale,
			"skew": part.skew, "visible": part.visible, "z_index": part.z_index, "bow": part.get_meta("bow_variant", -1)}
		if animation_data.part_pivots.has(path):
			pose[path].pivot_origin = part.transform * animation_data.part_pivots[path]
	if arm_rig != null: arm_rig.capture_fields(pose)
	return pose

func apply_pose(pose: Dictionary) -> void:
	for path in _editable:
		var part: Node2D = _editable[path]
		var entry: Dictionary = pose.get(path, _rest.get(path, {}))
		if entry.is_empty():
			part.visible = false
			continue
		part.position = entry.position
		part.rotation = float(entry.rotation)
		part.scale = entry.scale
		part.skew = float(entry.get("skew", 0.0))
		if animation_data.part_pivots.has(path) and entry.has("pivot_origin"):
			var offset: Vector2 = part.transform * animation_data.part_pivots[path] - part.position
			part.position = entry.pivot_origin - offset
		part.visible = bool(entry.visible)
		part.z_index = int(entry.get("z_index", 0))
		if int(entry.get("bow", -1)) >= 0: _set_bow_variant(part, int(entry.bow))
	arm_rig.apply_fields(pose)
	sort_bases()

## 部位の重なり順を編集しても、全BaseをArmorの下へ保つ。
func sort_bases() -> void:
	var lowest := 4096
	for part: Node2D in _editable.values(): lowest = mini(lowest, _canvas_depth(part))
	for sprite in _bases:
		sprite.z_as_relative = false
		sprite.z_index = clampi(lowest - 1, -4096, 4096)

func _canvas_depth(item: CanvasItem) -> int:
	var depth := 0
	while item != null:
		depth += item.z_index
		if not item.z_as_relative: break
		item = item.get_parent() as CanvasItem
	return depth

func _set_bow_variant(part: Node2D, frame: int) -> void:
	frame = clampi(frame, 0, _bow_frames.size() - 1)
	var sprite := part.get_node_or_null("Bow") as Sprite2D
	if sprite == null: return
	part.set_meta("bow_variant", frame)
	sprite.texture = _bow_frames[frame]
	sprite.position = Vector2(5, 34) - BOW_GRIPS[frame]

func add_extra(definition: Dictionary) -> Node2D:
	var part: Node2D
	if definition.has("template"):
		var template := get_node_or_null(NodePath(definition.template)) as Node2D
		if template == null: return null
		part = template.duplicate() as Node2D
		part.set_meta("source_template", definition.template)
	else:
		part = Node2D.new()
		var sprite := Sprite2D.new()
		sprite.texture = definition.texture
		part.add_child(sprite)
	part.name = definition.name
	part.set_meta("part_label", definition.name)
	part.set_meta("extra_part", true)
	add_child(part)
	refresh_parts()
	return part

func release_bow(interval := 0.4) -> void:
	_shot_interval = maxf(0.05, interval)
	_clip_time = 0.0

func set_bow_pose(technique: StringName, mode: StringName, progress: float, delta := 0.0, pose_time := -1.0) -> void:
	var clip := "idle"
	if technique in [&"volley", &"power_shot"]:
		if mode == &"windup": clip = "shot_windup"
		elif mode == &"shooting": clip = "shot_release"
		elif mode == &"recovery": clip = "shot_recovery"
	elif technique == &"rain":
		if mode == &"windup": clip = "rain_windup"
		elif mode == &"rain": clip = "rain"
		elif mode == &"recovery": clip = "rain_recovery"
	elif technique in [&"shower_chase", &"shower_wall"]:
		if mode == &"windup": clip = "shower_windup"
		elif mode == &"rain": clip = "shower"
		elif mode == &"recovery": clip = "shower_recovery"
	elif technique == &"fan_volley":
		if mode == &"windup": clip = "fan_windup"
		elif mode == &"shooting": clip = "fan_release"
		elif mode == &"recovery": clip = "fan_recovery"
	elif technique == &"stomp":
		if mode == &"windup": clip = "stomp_windup"
		elif mode == &"strike": clip = "stomp"
		elif mode == &"recovery": clip = "stomp_recovery"
	if mode == &"leap": clip = "leap"
	elif mode == &"retreat": clip = "run"
	if clip != _clip:
		_clip = clip
		_clip_time = 0.0
	_clip_time += delta
	var length: float = animation_data.duration(clip)
	var time := _clip_time
	if mode == &"windup": time = clampf(progress, 0.0, 1.0) * length
	elif clip in ["shot_release", "fan_release"]: time = _clip_time / _shot_interval * length
	elif clip in ["idle", "rain", "shower", "run"] and length > 0.0: time = fmod(_clip_time, length)
	if clip == "stomp" and pose_time >= 0.0: time = pose_time
	apply_pose(animation_data.sample(clip, time))


func _configure_lighting(parent: Node) -> void:
	for child in parent.get_children():
		if child is Sprite2D and child.material is ShaderMaterial:
			child.material = child.material.duplicate()
			var material := child.material as ShaderMaterial
			material.set_shader_parameter("normal_flip_x", child.flip_h)
			for field in ["ambient", "normal_strength", "key_energy", "fill_energy"]:
				material.set_shader_parameter(field, LIGHTING.get(field))
			for entry in [["key_direction", LIGHTING.key_angle], ["fill_direction", LIGHTING.fill_angle]]:
				var direction := Vector2.from_angle(deg_to_rad(float(entry[1])))
				material.set_shader_parameter(entry[0], Vector3(direction.x, direction.y, LIGHTING.height).normalized())
		_configure_lighting(child)

func _open_editor_if_main() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/bosses/centaurus_parts_preview.tscn")
