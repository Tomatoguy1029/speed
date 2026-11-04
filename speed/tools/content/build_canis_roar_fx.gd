## 技ごとの確定設定を、本番の独立時計と猟犬予兆へ渡す。
@tool
extends RefCounted

const BURST := "res://data/visuals/canis_burst.tres"
const SETTINGS := "res://data/visuals/fx_reference.tres"
const ROARING := ["command","stream","howl","bay","relay","hunt","hunt_pounce","nova"]
const SPEED := ["command","stream","howl","bay","relay","hunt","hunt_pounce","blaze"]

static func input_paths() -> PackedStringArray:
	return PackedStringArray([SETTINGS,BURST])

static func apply(data: Dictionary) -> Error:
	var settings := ResourceLoader.load(SETTINGS,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FxReferenceSettings
	if settings==null or not settings.valid(): return ERR_INVALID_DATA
	var burst := ResourceLoader.load(BURST,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if burst==null or float(burst.get_meta("duration",0.0))<=0.0: return ERR_INVALID_DATA
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
			"has_hound_speed":speed,"hound_speed":float(values.houndAttackSpeed) if speed else 0.0,
			"burst_duration":float(burst.get_meta("duration")) if name=="blaze" else 0.0})
	# 号令だけは共通の段階表が発射を進めるため、予兆と咆哮の確定時計へ組み替える。
	for config: Dictionary in rows:
		if config.external_id!="O-command": continue
		var technique: Dictionary = {}
		for item: Dictionary in data.get("BossTechniqueDefinition",[]):
			if int(item.id)==int(config.technique): technique = item; break
		var detail: Dictionary = {}
		for item: Dictionary in data.get("CanisCommandDefinition",[]):
			if int(item.technique)==int(config.technique): detail = item; break
		if technique.is_empty() or detail.is_empty(): return ERR_INVALID_DATA
		var warn := float(technique.warn)
		var cue := warn-minf(warn*0.65,0.32)
		var lives := [0.0,0.24,0.36,0.52]
		var start := cue+float(lives[int(config.level)])*float(config.roar_time)*float(config.timing)+float(config.order_wait)+float(config.hound_warn)
		var stages := 0
		for stage: Dictionary in data.get("BossTechniqueStage",[]):
			if int(stage.technique)!=int(config.technique): continue
			if int(stage.command)==1: stage.at = start; stages += 1
			elif int(stage.command)==2: stage.at = start+float(detail.lunge_time)+0.05; stages += 1
		if stages!=2: return ERR_INVALID_DATA
	data["CanisRoarDefinition"] = rows
	return OK
