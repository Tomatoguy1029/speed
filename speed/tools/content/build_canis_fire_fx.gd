## 炎と実通過画素に使う技別の確定値をnativeへ渡す。
@tool
extends RefCounted

const SETTINGS := "res://data/visuals/fx_reference.tres"
const MOVES := ["sirius","sirius_flame","relay","hunt"]

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
		if not boss_ids.has(int(technique.boss)) or name not in MOVES: continue
		var values := settings.for_id("O-"+name)
		var hound_jet := name=="relay"
		var hound_speed := name in ["relay","hunt"]
		var keys: Array = ["size","intensity","timing","jetLength","jetWidth","jetSpikes","emberDelay"]
		if hound_jet: keys.append_array(["houndJetLength","houndJetWidth"])
		if hound_speed: keys.append("houndAttackSpeed")
		for key: String in keys:
			if not values.has(key) or not (values[key] is int or values[key] is float) or not is_finite(float(values[key])) or float(values[key])<0.0: return ERR_INVALID_DATA
		if float(values["size"])<=0.0 or float(values.timing)<=0.0 or hound_speed and float(values.houndAttackSpeed)<=0.0: return ERR_INVALID_DATA
		rows.append({"id":rows.size()+1,"technique":int(technique.id),"external_id":"O-"+name,
			"size":float(values["size"]),"intensity":float(values.intensity),"timing":float(values.timing),
			"jet_length":float(values.jetLength),"jet_width":float(values.jetWidth),"jet_spikes":float(values.jetSpikes),"ember_delay":float(values.emberDelay),
			"has_hound_jet":hound_jet,"hound_jet_length":float(values.houndJetLength) if hound_jet else 0.0,
			"hound_jet_width":float(values.houndJetWidth) if hound_jet else 0.0,
			"has_hound_speed":hound_speed,"hound_speed":float(values.houndAttackSpeed) if hound_speed else 0.0})
	data["CanisFireFxDefinition"] = rows
	return OK
