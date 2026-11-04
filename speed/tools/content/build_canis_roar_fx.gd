## 技ごとの確定設定を、本番の独立時計と猟犬予兆へ渡す。
@tool
extends RefCounted

const SETTINGS := "res://data/visuals/fx_reference.tres"
const ROARING := ["command","stream","howl","bay","relay","hunt","hunt_pounce","nova"]
const SPEED := ["command","stream","howl","bay","relay","hunt","hunt_pounce","blaze"]

static func input_paths() -> PackedStringArray:
	return PackedStringArray([SETTINGS])

static func apply(data: Dictionary) -> Error:
	var settings := ResourceLoader.load(SETTINGS,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FxReferenceSettings
	if settings==null or not settings.valid(): return ERR_INVALID_DATA
	var boss_ids := {}
	for boss: Dictionary in data.get("BossDefinition",[]):
		if int(boss.kind)==2: boss_ids[int(boss.id)] = true
	var rows: Array = []
	for technique: Dictionary in data.get("BossTechniqueDefinition",[]):
		var name := str(technique.external_id)
		if not boss_ids.has(int(technique.boss)) or name not in ROARING and name not in SPEED: continue
		var values := settings.for_id("O-"+name)
		var roaring := name in ROARING
		var speed := name in SPEED
		var keys: Array = ["timing"]
		if roaring: keys.append_array(["roarLevel","roarTime"])
		if roaring and name!="nova": keys.append_array(["orderWait","houndWarn"])
		if speed: keys.append("houndAttackSpeed")
		for key: String in keys:
			if not values.has(key) or not (values[key] is int or values[key] is float) or not is_finite(float(values[key])) or float(values[key])<0.0 or float(values[key])==0.0 and key!="orderWait": return ERR_INVALID_DATA
		if roaring and (int(values.roarLevel)<1 or int(values.roarLevel)>3 or float(values.roarLevel)!=float(int(values.roarLevel))): return ERR_INVALID_DATA
		rows.append({"id":rows.size()+1,"technique":int(technique.id),"external_id":"O-"+name,
			"has_roar":roaring,"level":int(values.roarLevel) if roaring else 0,
			"roar_time":float(values.roarTime) if roaring else 0.0,"timing":float(values.timing),
			"order_wait":float(values.orderWait) if roaring and name!="nova" else 0.0,
			"hound_warn":float(values.houndWarn) if roaring and name!="nova" else 0.0,
			"has_hound_speed":speed,"hound_speed":float(values.houndAttackSpeed) if speed else 0.0})
	data["CanisRoarDefinition"] = rows
	return OK
