## 最大後強化の固定定義と、元の武器の間隔基準を生成する。
extends RefCounted

static func append(data: Dictionary, config: GameConfig, definition_source: Callable = Callable()) -> void:
	var post := config.post_max
	data.PostMaxDefinition = []
	data.PostMaxTarget = []
	data.PostMaxInterval = []
	for key: String in post.increments:
		var row := {"id":data.PostMaxDefinition.size()+1,"external_id":key,"increment":float(post.increments[key]),"minimum_ratio":post.minimum_time_ratio,"minimum_time":post.minimum_charge_time if key=="charge_time" else post.minimum_interval,"maximum":post.maximum_invulnerability if key=="invulnerability" else post.maximum_repair_fraction if key=="repair" else 0.0}
		data.PostMaxDefinition.append(row)
		for equipment: Dictionary in data.LoadoutDefinition:
			if equipment.kind!=0: continue
			var target := post.target(StringName(equipment.external_id))
			var target_key: String = {"weapon_interval":"interval","projectile_speed":"projectile"}.get(key,key)
			if target.has(target_key): data.PostMaxTarget.append({"id":data.PostMaxTarget.size()+1,"equipment":equipment.id,"effect":row.id})
	for equipment: Dictionary in data.LoadoutDefinition:
		if equipment.kind!=0: continue
		var definition := (definition_source.call(StringName(equipment.external_id)) if definition_source.is_valid() else ContentManager.definition(&"weapons",StringName(equipment.external_id))) as WeaponDef
		for key: String in post.target(definition.id).get("interval",[]):
			var raw: Variant = definition.params.get(key,0.0)
			for level in range(1,equipment.maximum_level+1):
				var base: float = float(raw[clampi(level-1,0,raw.size()-1)]) if raw is Array else float(raw)/(1.0+0.12*(definition.level_steps[level-1]-1))
				data.PostMaxInterval.append({"id":data.PostMaxInterval.size()+1,"equipment":equipment.id,"level":level,"parameter":key,"base":base})
