## 共通スキーマから生成。直接編集しない。
extends RefCounted

const SCHEMA = {"schema_version": 1, "format_version": 1, "abi_version": 1, "records": [{"name": "RunConfig", "section": 1, "fields": [{"name": "id", "type": "u32", "min": 1}, {"name": "aim_lag", "type": "f64", "min": 0}, {"name": "aim_speed", "type": "f64", "min": 0}, {"name": "crystal_low", "type": "f64", "min": 0}, {"name": "crystal_mid", "type": "f64", "min": 0}, {"name": "crystal_high", "type": "f64", "min": 0}, {"name": "ship_config_start_radius", "type": "f64", "min": 0, "runtime": "ship_config.start_radius", "config": "start_radius"}, {"name": "ship_config_base_max_speed", "type": "f64", "min": 0, "runtime": "ship_config.base_max_speed", "config": "base_max_speed"}, {"name": "ship_config_stick_dead_zone", "type": "f64", "min": 0, "runtime": "ship_config.stick_dead_zone", "config": "stick_dead_zone"}, {"name": "ship_config_mouse_dead_zone", "type": "f64", "min": 0, "runtime": "ship_config.mouse_dead_zone", "config": "mouse_dead_zone"}, {"name": "ship_config_steer_cruise", "type": "f64", "min": 0, "runtime": "ship_config.steer_cruise", "config": "steer_cruise"}, {"name": "ship_config_glide_hold", "type": "f64", "min": 0, "runtime": "ship_config.glide_hold", "config": "glide_hold"}, {"name": "ship_config_glide_fade", "type": "f64", "min": 0, "runtime": "ship_config.glide_fade", "config": "glide_fade"}, {"name": "ship_config_cruise_floor", "type": "f64", "min": 0, "runtime": "ship_config.cruise_floor", "config": "cruise_floor"}, {"name": "ship_config_energy_cut", "type": "f64", "min": 0, "runtime": "ship_config.energy_cut", "config": "energy_cut"}, {"name": "ship_config_cruise_drag", "type": "f64", "min": 0, "runtime": "ship_config.cruise_drag", "config": "cruise_drag"}, {"name": "ship_config_overcap_decay", "type": "f64", "min": 0, "runtime": "ship_config.overcap_decay", "config": "overcap_decay"}, {"name": "ship_config_field_radius", "type": "f64", "min": 0, "runtime": "ship_config.field_radius", "config": "field_radius"}, {"name": "ship_config_boundary_push", "type": "f64", "min": 0, "runtime": "ship_config.boundary_push", "config": "boundary_push"}, {"name": "ship_config_ship_radius", "type": "f64", "min": 0, "runtime": "ship_config.ship_radius", "config": "ship_radius"}, {"name": "ship_config_crash_restitution", "type": "f64", "min": 0, "runtime": "ship_config.crash_restitution", "config": "crash_restitution"}, {"name": "ship_config_ship_hurt_time", "type": "f64", "min": 0, "runtime": "ship_config.ship_hurt_time", "config": "ship_hurt_time"}, {"name": "ship_config_max_hp", "type": "f64", "min": 0, "runtime": "ship_config.max_hp", "config": "base_hp"}, {"name": "ship_config_max_speed", "type": "f64", "min": 0, "runtime": "ship_config.max_speed", "config": "base_max_speed"}, {"name": "ship_config_turn_rate", "type": "f64", "min": 0, "runtime": "ship_config.turn_rate", "config": "steer_rate"}, {"name": "ship_config_acceleration", "type": "f64", "min": 0, "runtime": "ship_config.acceleration", "config": "steer_accel"}, {"name": "ship_config_glide_duration_mult", "type": "f64", "min": 0, "runtime": "ship_config.glide_duration_mult", "value": 1.0}, {"name": "ship_config_invulnerability", "type": "f64", "min": 0, "runtime": "ship_config.invulnerability", "config": "invuln_time"}, {"name": "draw_config_min_charge", "type": "f64", "min": 0, "runtime": "draw_config.min_charge", "config": "draw_min_charge"}, {"name": "draw_config_length", "type": "f64", "min": 0, "runtime": "draw_config.length", "config": "draw_length"}, {"name": "draw_config_point_step", "type": "f64", "min": 0, "runtime": "draw_config.point_step", "config": "draw_step"}, {"name": "draw_config_confirm_delay", "type": "f64", "min": 0, "runtime": "draw_config.confirm_delay", "config": "draw_confirm_delay"}, {"name": "draw_config_run_time", "type": "f64", "min": 0, "runtime": "draw_config.run_time", "config": "draw_run_time"}, {"name": "draw_config_time_scale", "type": "f64", "min": 0, "runtime": "draw_config.time_scale", "config": "draw_time_scale"}, {"name": "draw_config_slow_ref", "type": "f64", "min": 0, "runtime": "draw_config.slow_ref", "config": "draw_run_slow_ref"}, {"name": "draw_config_scale_min", "type": "f64", "min": 0, "runtime": "draw_config.scale_min", "config": "draw_run_scale_min"}, {"name": "draw_config_boost_duration", "type": "f64", "min": 0, "runtime": "draw_config.boost_duration", "config": "boost_duration"}, {"name": "draw_config_carry", "type": "f64", "min": 0, "runtime": "draw_config.carry", "config": "carry"}, {"name": "draw_config_launch_ratio", "type": "f64", "min": 0, "runtime": "draw_config.launch_ratio", "config": "launch_ratio"}, {"name": "draw_config_glide_ratio", "type": "f64", "min": 0, "runtime": "draw_config.glide_ratio", "config": "glide_speed_ratio"}, {"name": "draw_config_capacity", "type": "f64", "min": 0, "runtime": "draw_config.capacity", "value": 1.0}, {"name": "draw_config_charge_time", "type": "f64", "min": 0, "runtime": "draw_config.charge_time", "config": "dash_charge_time"}, {"name": "draw_config_length_mult", "type": "f64", "min": 0, "runtime": "draw_config.length_mult", "value": 1.0}, {"name": "camera_base_view", "type": "f64", "min": 0, "runtime": "control.base_view", "config": "base_view"}, {"name": "camera_zoom_ref_speed", "type": "f64", "min": 0, "runtime": "control.zoom_ref_speed", "config": "zoom_ref_speed"}, {"name": "camera_zoom_exp", "type": "f64", "min": 0, "runtime": "control.zoom_exp", "config": "zoom_exp"}, {"name": "camera_zoom_min", "type": "f64", "min": 0, "runtime": "control.zoom_min", "config": "zoom_min"}, {"name": "camera_look_ahead", "type": "f64", "min": 0, "runtime": "control.look_ahead", "config": "look_ahead"}, {"name": "world_tick_div", "type": "u32", "min": 1, "config": "world_tick_div", "runtime": "control.world_tick_div"}, {"name": "grid_cell", "type": "f64", "min": 0, "config": "grid_cell", "runtime": "frame_grid_cell"}, {"name": "time_limit", "type": "f64", "value": -1, "runtime": "control.time_limit"}], "version": 4}, {"name": "StringEntry", "section": 2, "fields": [{"name": "id", "type": "u32", "min": 1}, {"name": "value", "type": "string"}]}, {"name": "DefinitionIndex", "section": 3, "fields": [{"name": "id", "type": "u32", "min": 1, "ref": "StringEntry"}, {"name": "enemy", "type": "u32", "min": 1, "ref": "ChaseDefinition"}]}, {"name": "ChaseDefinition", "section": 4, "fields": [{"name": "id", "type": "u32", "min": 1, "ref": "StringEntry"}, {"name": "hp", "type": "f64", "native": "hp", "min": 0}, {"name": "armor", "type": "f64", "native": "armor", "min": 0}, {"name": "radius", "type": "f64", "native": "radius", "min": 0}, {"name": "speed", "type": "f64", "native": "speed", "min": 0}, {"name": "fire_interval", "type": "f64", "native": "fire_interval", "min": 0}, {"name": "xp", "type": "f64", "native": "xp", "min": 0}, {"name": "knockback", "type": "f64", "native": "knockback", "min": 0}, {"name": "hitstop_multiplier", "type": "f64", "native": "hitstop_multiplier", "min": 0}, {"name": "attack_value", "type": "f64", "native": "attack_value", "min": 0}, {"name": "attack_priority", "type": "f64", "native": "attack_priority"}, {"name": "attack_weight", "type": "f64", "native": "attack_weight", "min": 0}, {"name": "warn", "type": "f64", "native": "attack_telegraph", "min": 0, "source": "telegraph"}, {"name": "attack_managed", "type": "bool", "native": "attack_managed"}, {"name": "rank", "type": "i64", "min": 0, "native": "rank"}, {"name": "size_var", "type": "bool", "native": "size_var"}, {"name": "color_r", "type": "f32", "native": "color.r"}, {"name": "color_g", "type": "f32", "native": "color.g"}, {"name": "color_b", "type": "f32", "native": "color.b"}, {"name": "color_a", "type": "f32", "native": "color.a"}, {"name": "scaling_radius", "type": "f64", "min": 0, "native": "scaling.radius"}, {"name": "scaling_hp", "type": "f64", "min": 0, "native": "scaling.hp"}, {"name": "scaling_armor", "type": "f64", "min": 0, "native": "scaling.armor"}, {"name": "scaling_hp_mult", "type": "f64", "min": 0, "native": "scaling.hp_mult"}, {"name": "scaling_armor_mult", "type": "f64", "min": 0, "native": "scaling.armor_mult"}, {"name": "scaling_character", "type": "f64", "min": 0, "native": "scaling.character"}, {"name": "scaling_visual", "type": "f64", "min": 0, "native": "scaling.visual"}, {"name": "scaling_collision", "type": "f64", "min": 0, "native": "scaling.collision"}, {"name": "fixed_sprite", "type": "bool", "native": "scaling.fixed_sprite"}, {"name": "reward_low", "type": "u32", "native": "xp_rewards[0]"}, {"name": "reward_mid", "type": "u32", "native": "xp_rewards[1]"}, {"name": "reward_high", "type": "u32", "native": "xp_rewards[2]"}, {"name": "gold_eligible", "type": "bool", "native": "gold_eligible"}], "version": 2}, {"name": "LoadoutDefinition", "section": 5, "enabled": false, "fields": [{"name": "id", "type": "u32", "min": 1}]}, {"name": "HeroDefinition", "section": 6, "enabled": false, "fields": [{"name": "id", "type": "u32", "min": 1}]}, {"name": "FieldDefinition", "section": 7, "enabled": false, "fields": [{"name": "id", "type": "u32", "min": 1}]}, {"name": "PopulationDefinition", "section": 8, "enabled": false, "fields": [{"name": "id", "type": "u32", "min": 1}]}, {"name": "FormationDefinition", "section": 9, "enabled": false, "fields": [{"name": "id", "type": "u32", "min": 1}]}, {"name": "BossFlowDefinition", "section": 10, "enabled": false, "fields": [{"name": "id", "type": "u32", "min": 1}]}, {"name": "TechniqueDefinition", "section": 11, "enabled": false, "fields": [{"name": "id", "type": "u32", "min": 1}]}, {"name": "ResourceKey", "section": 12, "enabled": false, "fields": [{"name": "id", "type": "u32", "min": 1}]}]}

static func write_content(data: Dictionary, input_sha256: PackedByteArray) -> PackedByteArray:
	if data.size() != SCHEMA.records.size() or input_sha256.size() != 32: return PackedByteArray()
	var ids := {}
	for record in SCHEMA.records:
		if not data.has(record.name) or not data[record.name] is Array: return PackedByteArray()
		if not record.get("enabled", true) and not data[record.name].is_empty(): return PackedByteArray()
		ids[record.name] = {}
		for row in data[record.name]:
			if not row is Dictionary or not _valid_record(row, record): return PackedByteArray()
			if ids[record.name].has(row.id): return PackedByteArray()
			ids[record.name][row.id] = true
	for record in SCHEMA.records:
		for row in data[record.name]:
			for field in record.fields:
				if field.has("ref") and not ids[field.ref].has(row[field.get("source",field.name)]): return PackedByteArray()
	var payload := StreamPeerBuffer.new()
	payload.big_endian = false
	var sections := []
	for record in SCHEMA.records:
		var start := payload.get_position()
		for row in data[record.name]:
			for field in record.fields:
				_put(payload,field.type,row[field.get("source",field.name)])
		sections.append([record.section,start,payload.get_position()-start,data[record.name].size(),record.get("version",1)])
	var output := StreamPeerBuffer.new()
	output.big_endian = false
	output.put_data("SPDRUN01".to_ascii_buffer())
	output.put_u32(SCHEMA.format_version)
	output.put_u32(SCHEMA.abi_version)
	output.put_u32(sections.size())
	output.put_u32(0)
	output.put_data(input_sha256)
	output.put_data(sha256(payload.data_array))
	var begin := 88+32*sections.size()
	for section in sections:
		output.put_u32(section[0])
		output.put_u32(section[4])
		output.put_u64(begin+section[1])
		output.put_u64(section[2])
		output.put_u32(section[3])
		output.put_u32(0)
	output.put_data(payload.data_array)
	return output.data_array

static func sha256(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()

static func _valid_record(row: Dictionary, record: Dictionary) -> bool:
	if row.size()!=record.fields.size(): return false
	for field in record.fields:
		var key: String = field.get("source",field.name)
		if not row.has(key): return false
		var value = row[key]
		match field.type:
			"string":
				if not value is String or value.to_utf8_buffer().size()>4294967295: return false
			"bool":
				if not value is bool: return false
			"u8", "u32", "u64", "i64":
				if not value is int: return false
				if field.type.begins_with("u") and value<0: return false
				if field.type=="u8" and value>255: return false
				if field.type=="u32" and value>4294967295: return false
			"f32", "f64":
				if not (value is float or value is int) or not is_finite(value): return false
				if field.type=="f32" and absf(value)>3.4028234663852886e38: return false
			_:
				return false
		if field.has("min") and value<field.min: return false
		if field.has("max") and value>field.max: return false
	return true

static func _put(out: StreamPeerBuffer, type: String, value) -> void:
	match type:
		"u8", "bool": out.put_u8(int(value))
		"u32": out.put_u32(value)
		"u64": out.put_u64(value)
		"i64": out.put_64(value)
		"f32": out.put_float(value)
		"f64": out.put_double(value)
		"string":
			var bytes: PackedByteArray = value.to_utf8_buffer()
			out.put_u32(bytes.size())
			out.put_data(bytes)

