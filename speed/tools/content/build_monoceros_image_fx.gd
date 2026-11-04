## 一角獣の部位階層、歩行・角の各フレームを制作元から固定する。
extends RefCounted
const SCENE := "res://scenes/bosses/monoceros_presentation.tscn"
const PARTS := "res://scenes/bosses/monoceros_parts.tscn"
const GAIT := "res://data/visuals/monoceros_gait.tres"
const BOSS := "res://data/bosses/monoceros.tres"
const EFFECT := "res://data/visuals/effect_settings.tres"
const MASKS := "res://assets/effects/boss_contact/monoceros_masks.tres"
const HORN := "res://assets/pixel/monoceros/horn/horn.tres"
const MOVES := ["", "charge", "kick", "sweep", "lance", "return_charge", "horn_wave", "horn_dance", "sword_flash"]
const FEET := ["FrontLeftLeg", "FrontRightLeg", "RearLeftLeg", "RearRightLeg"]
const TUNING := {"body_follow":"body_follow_seconds", "neck_follow":"neck_follow_seconds", "head_follow":"head_follow_seconds",
	"tail_follow":"tail_follow_seconds", "flame_follow":"flame_follow_seconds", "body_lag":"body_lag_degrees",
	"head_turn":"head_turn_degrees", "tail_turn":"tail_turn_degrees"}

static func input_paths() -> Array[String]:
	var paths: Array[String] = [SCENE, PARTS, GAIT, BOSS, EFFECT, MASKS, HORN,
		"res://scripts/bosses/monoceros_parts.gd", "res://scripts/render/bosses/monoceros.gd",
		"res://scripts/render/visual_effect_settings.gd"]
	var masks: Resource = load(MASKS)
	for path in masks.get_meta("inputs", {}): paths.append(path)
	return paths

static func _collect(parent: Node, root: Node, nodes: Array, paths: Dictionary) -> void:
	for child in parent.get_children():
		if child is Node2D:
			paths[String(root.get_path_to(child))] = nodes.size()+1
			nodes.append(child)
		_collect(child,root,nodes,paths)

## CanvasTextureとAtlasTextureの元シートと矩形を返す。
static func _texture(texture: Texture2D, ids: Dictionary) -> Dictionary:
	if texture == null: return {}
	var region := Rect2(Vector2.ZERO,texture.get_size())
	if texture is AtlasTexture:
		region = texture.region
		texture = texture.atlas
	if texture is CanvasTexture: texture = texture.diffuse_texture
	if texture == null or not ids.has(texture.resource_path): return {}
	return {"mask":ids[texture.resource_path],"x":int(region.position.x),"y":int(region.position.y),
		"w":int(region.size.x),"h":int(region.size.y)}

static func apply(data: Dictionary) -> Error:
	if not data.has("BossImageMaskRecord"): return ERR_INVALID_DATA
	var masks: Resource = load(MASKS)
	var gait: SpriteFrames = load(GAIT)
	var boss: Resource = load(BOSS)
	var settings: Resource = load(EFFECT)
	var scene: PackedScene = load(SCENE)
	if masks == null or gait == null or boss == null or settings == null or scene == null: return ERR_FILE_NOT_FOUND
	var sheets: Dictionary = masks.get_meta("sheets",{})
	var names := sheets.keys()
	names.sort()
	var ids := {}
	for path in names:
		var sheet: Dictionary = sheets[path]
		var id: int = data.BossImageMaskRecord.size()+1
		ids[String(path)] = id
		data.BossImageMaskRecord.append({"id":id,"width":sheet.width,"height":sheet.height,"alpha_bits_hex":(sheet.bits as PackedByteArray).hex_encode()})
	var root := scene.instantiate()
	var nodes: Array = []
	var paths := {}
	_collect(root,root,nodes,paths)
	data.MonocerosImageNode = []
	data.MonocerosImageSprite = []
	for node: Node2D in nodes:
		var path := String(root.get_path_to(node))
		var parent_path := String(root.get_path_to(node.get_parent()))
		var editable := node.has_meta("part_label")
		var appearance_path := path.trim_prefix("Parts/")
		var appearance: Dictionary = boss.part_appearance.get(appearance_path,{}) if editable else {}
		var offset: Array = appearance.get("offset",[0,0])
		data.MonocerosImageNode.append({"id":paths[path],"parent":paths.get(parent_path,0),"path":path,
			"x":node.position.x,"y":node.position.y,"rotation":node.rotation,"scale_x":node.scale.x,"scale_y":node.scale.y,
			"skew":node.skew,"visible":node.visible,"editable":editable,"offset_x":float(offset[0]),"offset_y":float(offset[1])})
		if not node is Sprite2D: continue
		var sprite: Sprite2D = node
		var info := _texture(sprite.texture,ids)
		if info.is_empty(): root.free(); return ERR_INVALID_DATA
		var slot := -1
		for i in FEET.size():
			if path.begins_with("Parts/"+FEET[i]+"/Foot/Sprite/"): slot = i
		data.MonocerosImageSprite.append({"id":data.MonocerosImageSprite.size()+1,"node":paths[path],"mask":info.mask,
			"region_x":info.x,"region_y":info.y,"region_w":info.w,"region_h":info.h,"offset_x":sprite.offset.x,"offset_y":sprite.offset.y,
			"centered":sprite.centered,"flip_h":sprite.flip_h,"flip_v":sprite.flip_v,"hframes":sprite.hframes,"vframes":sprite.vframes,
			"frame":sprite.frame,"gait_slot":slot,"gait_armor":sprite.name==&"Armor","horn":path=="Parts/Head/Lower/Horn"})
	data.MonocerosImageGait = []
	if gait.get_frame_count(&"run") != gait.get_frame_count(&"armor"): root.free(); return ERR_INVALID_DATA
	for i in gait.get_frame_count(&"run"):
		var base := _texture(gait.get_frame_texture(&"run",i),ids)
		var armor := _texture(gait.get_frame_texture(&"armor",i),ids)
		if base.is_empty() or armor.is_empty(): root.free(); return ERR_INVALID_DATA
		data.MonocerosImageGait.append({"id":i+1,"duration":gait.get_frame_duration(&"run",i)/gait.get_animation_speed(&"run"),
			"base_mask":base.mask,"base_x":base.x,"base_y":base.y,"base_w":base.w,"base_h":base.h,
			"armor_mask":armor.mask,"armor_x":armor.x,"armor_y":armor.y,"armor_w":armor.w,"armor_h":armor.h})
	var horn: Texture2D = load(HORN)
	var durations: PackedFloat32Array = horn.get_meta("durations")
	var lengths: PackedFloat32Array = horn.get_meta("core_lengths")
	if durations.size()!=lengths.size(): root.free(); return ERR_INVALID_DATA
	data.MonocerosImageHorn = []
	for i in lengths.size(): data.MonocerosImageHorn.append({"id":i+1,"duration":durations[i],"core_length":lengths[i]})
	data.MonocerosImageTuning = []
	for move in MOVES:
		var body: Dictionary = settings.values_for("boss/body/monoceros")
		var overrides: Dictionary = settings.component_values("boss/move/monoceros/"+move,"body")
		var row := {"id":data.MonocerosImageTuning.size()+1,"move":move}
		for key in TUNING:
			var field: String = TUNING[key]
			row[key] = float(overrides.get(field,body.get(field,root.get(field))))
		data.MonocerosImageTuning.append(row)
	root.free()
	return OK
