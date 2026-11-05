## 閃光の固定画像輪郭と承認値を、実行用レコードへ渡す。
@tool
extends RefCounted

const HULL_PATH := "res://data/visuals/canis_nova_hull.tres"
const EMISSION_PATH := "res://data/visuals/canis_nova_emission.tres"
const EDGES_PATH := "res://data/visuals/canis_hound_edges.tres"
const SETTINGS_PATH := "res://data/visuals/fx_reference.tres"

static func input_paths() -> PackedStringArray:
	return PackedStringArray([HULL_PATH,EMISSION_PATH,EDGES_PATH,SETTINGS_PATH,"res://tools/art/bake_canis_hound_edges.py","res://data/visuals/looks/hound.tres",
		"res://assets/pixel/hound/base.png","res://assets/pixel/hound/base.png.import",
		"res://assets/pixel/hound/armor.png","res://assets/pixel/hound/armor.png.import","res://tools/art/bake_canis_fx.py"])

static func apply(data: Dictionary) -> Error:
	if not data.get("CanisBodyDefinition",[]).is_empty():
		var edges := ResourceLoader.load(EDGES_PATH,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if edges==null or edges.get_meta("version",0)!=1: return ERR_INVALID_DATA
		for path: String in edges.get_meta("inputs",{}):
			if FileAccess.get_sha256(path)!=edges.get_meta("inputs",{})[path]:
				push_error("猟犬の炎の輪郭画像の入力が変わりました: "+path)
				return ERR_INVALID_DATA
		var points = edges.get_meta("points",PackedVector2Array())
		if not points is PackedVector2Array or points.is_empty(): return ERR_INVALID_DATA
	if data.get("CanisNovaDefinition",[]).is_empty(): return OK
	var baked := ResourceLoader.load(HULL_PATH,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if baked==null or baked.get_meta("bake_version",0)!=1:
		push_error("猟犬の閃光用輪郭がありません。tools/art/bake_canis_fx.pyで生成してください。")
		return ERR_INVALID_DATA
	var inputs = baked.get_meta("inputs",{})
	if not inputs is Dictionary or inputs.is_empty(): return ERR_INVALID_DATA
	for path: String in inputs:
		if FileAccess.get_sha256(path)!=inputs[path]:
			push_error("猟犬の閃光用輪郭の入力が変わりました: " + path)
			return ERR_INVALID_DATA
	var points = baked.get_meta("hull",PackedVector2Array())
	if not points is PackedVector2Array or points.size()<3: return ERR_INVALID_DATA
	var canonical := ""
	var rows: Array[Dictionary] = []
	for point: Vector2 in points:
		if point.x!=roundf(point.x) or point.y!=roundf(point.y): return ERR_INVALID_DATA
		canonical += "%d,%d;" % [int(point.x),int(point.y)]
		rows.append({"id":rows.size()+1,"x":point.x,"y":point.y})
	if canonical.sha256_text()!=baked.get_meta("hull_sha256",""): return ERR_INVALID_DATA
	var emission := ResourceLoader.load(EMISSION_PATH,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if emission==null or emission.get_meta("bake_version",0)!=1: return ERR_INVALID_DATA
	for path: String in emission.get_meta("inputs",{}):
		if FileAccess.get_sha256(path)!=emission.get_meta("inputs",{})[path]: return ERR_INVALID_DATA
	var samples = emission.get_meta("values",PackedFloat32Array())
	if not samples is PackedFloat32Array or samples.size()!=192*192: return ERR_INVALID_DATA
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(samples.to_byte_array())
	if digest.finish().hex_encode()!=emission.get_meta("values_sha256",""): return ERR_INVALID_DATA
	var settings := ResourceLoader.load(SETTINGS_PATH,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FxReferenceSettings
	if settings==null or not settings.valid(): return ERR_INVALID_DATA
	var values := settings.for_id("O-nova")
	for key in ["novaGatherTime","novaHoundDelay","novaFlashDelay","roarLevel","roarTime","timing"]:
		if not values.has(key) or not (values[key] is int or values[key] is float) or not is_finite(float(values[key])): return ERR_INVALID_DATA
	var width := int(baked.get_meta("source_width",0))
	var height := int(baked.get_meta("source_height",0))
	if width<=0 or height<=0: return ERR_INVALID_DATA
	data["CanisNovaHullPoint"] = rows
	data["CanisNovaFxDefinition"] = [{"id":1,"source_width":width,"source_height":height,
		"gather_time":float(values.novaGatherTime),"hound_delay":float(values.novaHoundDelay),"flash_delay":float(values.novaFlashDelay),
		"roar_level":int(values.roarLevel),"roar_time":float(values.roarTime),"timing":float(values.timing)}]
	return OK
