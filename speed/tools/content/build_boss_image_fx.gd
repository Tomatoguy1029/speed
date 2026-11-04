## 制作済みのケンタウルス部位とキーを、戦闘の画像境界へそのまま渡す。
extends RefCounted

const SCENE := "res://scenes/bosses/centaurus_parts.tscn"
const ANIMATION := "res://data/visuals/centaurus_animation.tres"
const MASKS := "res://assets/effects/boss_contact/centaurus_masks.tres"
const PARTS := preload("res://scripts/bosses/centaurus_parts.gd")

static func input_paths() -> Array[String]:
	var paths: Array[String] = [SCENE, ANIMATION, MASKS, "res://scripts/bosses/centaurus_parts.gd", "res://scripts/data_types/boss_part_animation.gd"]
	var masks: Resource = load(MASKS)
	for path in masks.get_meta("inputs", {}): paths.append(path)
	return paths

static func _collect(parent: Node, root: Node, nodes: Array, paths: Dictionary) -> void:
	for child in parent.get_children():
		if child is Node2D and child.has_meta("part_label"):
			paths[String(root.get_path_to(child))] = nodes.size() + 1
			nodes.append(child)
		_collect(child, root, nodes, paths)

static func _pose_rows(data: Dictionary, pose: Dictionary, key: int, paths: Dictionary) -> void:
	for path in pose:
		if not paths.has(String(path)): continue
		var p: Dictionary = pose[path]
		var origin: Vector2 = p.get("pivot_origin", Vector2.ZERO)
		data.CentaurusImagePose.append({"id":data.CentaurusImagePose.size()+1, "key":key, "node":paths[String(path)],
			"x":p.position.x,"y":p.position.y,"rotation":p.rotation,"scale_x":p.scale.x,"scale_y":p.scale.y,
			"skew":p.get("skew",0.0),"visible":p.visible,"bow":p.get("bow",-1),
			"pivot_origin":p.has("pivot_origin"),"pivot_x":origin.x,"pivot_y":origin.y})

static func apply(data: Dictionary) -> Error:
	var animation: Resource = load(ANIMATION)
	var masks: Resource = load(MASKS)
	if animation == null or masks == null: return ERR_FILE_NOT_FOUND
	# 保存されていない接続機能が後から増えた場合は、黙って近似せず生成を止める。
	if not animation.extra_parts.is_empty() or not animation.arm_joints.is_empty(): return ERR_UNAVAILABLE
	var sheets: Dictionary = masks.get_meta("sheets", {})
	var sheet_paths := sheets.keys()
	sheet_paths.sort()
	var sheet_ids := {}
	data.BossImageMaskRecord = []
	for path in sheet_paths:
		var sheet: Dictionary = sheets[path]
		var id: int = data.BossImageMaskRecord.size()+1
		sheet_ids[String(path)] = id
		data.BossImageMaskRecord.append({"id":id,"width":sheet.width,"height":sheet.height,"alpha_bits_hex":(sheet.bits as PackedByteArray).hex_encode()})
	var scene: PackedScene = load(SCENE)
	if scene == null: return ERR_FILE_NOT_FOUND
	var root := scene.instantiate()
	var nodes: Array = []
	var paths := {}
	_collect(root, root, nodes, paths)
	data.CentaurusImageNode = []
	data.CentaurusImageSprite = []
	for node: Node2D in nodes:
		var path := String(root.get_path_to(node))
		var parent_path := String(root.get_path_to(node.get_parent()))
		var pivot: Vector2 = animation.part_pivots.get(path, Vector2.ZERO)
		data.CentaurusImageNode.append({"id":paths[path],"parent":paths.get(parent_path,0),"path":path,
			"x":node.position.x,"y":node.position.y,"rotation":node.rotation,"scale_x":node.scale.x,"scale_y":node.scale.y,
			"skew":node.skew,"visible":node.visible,"pivot":animation.part_pivots.has(path),"pivot_x":pivot.x,"pivot_y":pivot.y})
		for sprite in node.get_children():
			if not sprite is Sprite2D: continue
			var texture: Texture2D = sprite.texture
			if not texture is AtlasTexture: root.free(); return ERR_INVALID_DATA
			var region: Rect2 = texture.region
			texture = texture.atlas
			if texture is CanvasTexture: texture = texture.diffuse_texture
			if texture == null or not sheet_ids.has(texture.resource_path): root.free(); return ERR_INVALID_DATA
			data.CentaurusImageSprite.append({"id":data.CentaurusImageSprite.size()+1,"node":paths[path],"mask":sheet_ids[texture.resource_path],
				"region_x":int(region.position.x),"region_y":int(region.position.y),"region_w":int(region.size.x),"region_h":int(region.size.y),
				"x":sprite.position.x,"y":sprite.position.y,"rotation":sprite.rotation,"scale_x":sprite.scale.x,"scale_y":sprite.scale.y,"skew":sprite.skew,
				"offset_x":sprite.offset.x,"offset_y":sprite.offset.y,"centered":sprite.centered,"flip_h":sprite.flip_h,"flip_v":sprite.flip_v,
				"visible":sprite.visible,"bow":path=="Bow" and sprite.name==&"Bow"})
	root.free()
	data.CentaurusImageBow = []
	for index in PARTS.BOW_REGIONS.size():
		var region: Rect2 = PARTS.BOW_REGIONS[index]
		var grip: Vector2 = PARTS.BOW_GRIPS[index]
		data.CentaurusImageBow.append({"id":index+1,"region_x":int(region.position.x),"region_y":int(region.position.y),
			"region_w":int(region.size.x),"region_h":int(region.size.y),"grip_x":grip.x,"grip_y":grip.y})
	data.CentaurusImageClip = []
	data.CentaurusImageKey = []
	data.CentaurusImagePose = []
	# key 1 はclipが存在しない場合のneutral。
	data.CentaurusImageKey.append({"id":1,"clip":0,"duration":0.02,"interpolate":false})
	_pose_rows(data,animation.poses.get("neutral",{}),1,paths)
	var names: Array = animation.clips.keys()
	names.sort()
	for name in names:
		var clip: int = data.CentaurusImageClip.size()+1
		data.CentaurusImageClip.append({"id":clip,"name":String(name)})
		for frame: Dictionary in animation.clips[name]:
			var key: int = data.CentaurusImageKey.size()+1
			data.CentaurusImageKey.append({"id":key,"clip":clip,"duration":maxf(0.02,float(frame.get("duration",0.15))),"interpolate":frame.get("interpolate",false)})
			_pose_rows(data,frame.pose,key,paths)
	return OK
