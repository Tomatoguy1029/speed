## 本番パーツの画像と配置を、共通の画像接触へ追加する。
@tool
extends RefCounted

const SCENE := "res://scenes/bosses/canis_major_parts.tscn"
const MASKS := "res://data/visuals/canis_contact_masks.tres"
const PARTS := ["Tail","RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg","Body","Head"]

static func input_paths() -> PackedStringArray:
	var result := PackedStringArray([SCENE,MASKS])
	var masks := ResourceLoader.load(MASKS,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if masks!=null:
		for path: String in masks.get_meta("inputs",{}): result.append(path)
	return result

static func apply(data: Dictionary) -> Error:
	if data.get("CanisBodyDefinition",[]).is_empty(): return OK
	var masks := ResourceLoader.load(MASKS,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if masks==null or masks.get_meta("version",0)!=1 or masks.get_meta("threshold",0)!=60: return ERR_INVALID_DATA
	var inputs = masks.get_meta("inputs",{})
	if not inputs is Dictionary or inputs.is_empty(): return ERR_INVALID_DATA
	for path: String in inputs:
		if FileAccess.get_sha256(path)!=inputs[path]:
			push_error("おおいぬの接触画像の入力が変わりました: "+path)
			return ERR_INVALID_DATA
	var sheets: Dictionary = masks.get_meta("sheets",{})
	var keys := sheets.keys()
	keys.sort()
	var rows: Array = data.get("BossImageMaskRecord",[])
	var sheet_ids := {}
	for path: String in keys:
		var sheet: Dictionary = sheets[path]
		var bits: PackedByteArray = sheet.get("bits",PackedByteArray())
		var width := int(sheet.get("width",0))
		var height := int(sheet.get("height",0))
		if width<=0 or height<=0 or bits.size()!=ceili(float(width*height)/8.0): return ERR_INVALID_DATA
		var hex := bits.hex_encode()
		var id := 0
		for existing: Dictionary in rows:
			if int(existing.width)==width and int(existing.height)==height and existing.alpha_bits_hex==hex:
				id = int(existing.id)
				break
		if id==0:
			id = rows.size()+1
			rows.append({"id":id,"width":width,"height":height,"alpha_bits_hex":hex})
		sheet_ids[path] = id
	var scene: PackedScene = load(SCENE)
	if scene==null: return ERR_FILE_NOT_FOUND
	var root := scene.instantiate()
	var parts: Array = []
	for name: String in PARTS:
		var node := root.get_node_or_null(name) as Node2D
		var sprite := root.get_node_or_null(name+"/Sprite") as Sprite2D
		if node==null or sprite==null or not sprite.texture is CanvasTexture:
			root.free(); return ERR_INVALID_DATA
		var canvas_texture := sprite.texture as CanvasTexture
		var texture: Texture2D = canvas_texture.diffuse_texture
		if texture==null or not sheet_ids.has(texture.resource_path) or not sprite.centered or sprite.offset!=Vector2.ZERO or sprite.rotation!=0.0 or sprite.scale!=Vector2.ONE or sprite.flip_v or node.rotation!=0.0 or node.scale!=Vector2.ONE:
			root.free(); return ERR_INVALID_DATA
		var sheet: Dictionary = sheets[texture.resource_path]
		parts.append({"id":parts.size()+1,"name":name,"mask":sheet_ids[texture.resource_path],
			"x":node.position.x,"y":node.position.y,"sprite_x":sprite.position.x,"sprite_y":sprite.position.y,
			"width":sheet.width,"height":sheet.height,"flip_h":sprite.flip_h,"visible":node.visible and sprite.visible})
	root.free()
	data["BossImageMaskRecord"] = rows
	data["CanisImagePartDefinition"] = parts
	return OK
