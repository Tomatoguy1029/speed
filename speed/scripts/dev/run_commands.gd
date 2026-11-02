## 開発命令をC++のラン窓口へ渡す。
extends RefCounted
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase
func setup_cpp(owner: RunSession) -> void:
	_cpp = weakref(owner)

func handle_cpp(name: StringName, args: Dictionary) -> Dictionary:
	var owner: RunSession = _cpp.get_ref() if _cpp!=null else null
	if owner==null or owner.bridge==null: return _cpp_failure("対象のランは終了しています。")
	if _cpp_busy: return _cpp_failure("資源を準備しています。")
	var frame: Dictionary = owner.bridge.read_frame()
	if not frame.ok: return frame
	if frame.value.ui.phase not in [Phase.Play,Phase.Paused,Phase.Levelup]: return _cpp_failure("終了中のランは変更できません。")
	match name:
		&"debug_grant":
			_cpp_busy = true
			var result: Dictionary = await _cpp_grant(owner,args)
			_cpp_busy = false
			return result
		&"debug_spawn_enemies":
			var edit = load("res://scripts/dev/run_content_edit.gd").for_session(owner)
			if not edit.error.is_empty(): return _cpp_failure(edit.error)
			_cpp_busy = true
			var ready: Dictionary = await edit.prepare_debug_enemies()
			_cpp_busy = false
			if not ready.ok: return ready
			return owner.bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":"random","args":{"ids":ready.value,"count":clampi(int(args.get("count",100)),1,10000)}}})
		&"debug_gravity": return owner.bridge.command("dev_spawn_well",{})
		&"debug_warp": return owner.bridge.command("dev_spawn_warp",{})
		&"debug_comet": return owner.bridge.command("dev_spawn_comet",{"rare":bool(args.get("rare",false))})
		&"debug_clear", &"debug_fail": return owner.bridge.command("dev_finish",{"cleared":name==&"debug_clear"})

	var allowed := [&"debug_kill_boss",&"debug_time",&"debug_boss_time",&"debug_invincible",&"debug_heal",&"debug_level_up",&"debug_gauge_full",&"debug_clear_enemies",&"debug_coins",&"debug_hurt",&"debug_die",&"debug_hazards",&"debug_reset_loadout"]
	if name not in allowed: return _cpp_failure("未登録の開発操作です。")
	var result: Dictionary = owner.bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":String(name).trim_prefix("debug_"),"args":args}})
	if result.ok and name==&"debug_reset_loadout" and owner.cpp_choices!=null: owner.cpp_choices.poll()
	return result

func _cpp_grant(owner: RunSession, args: Dictionary) -> Dictionary:
	var kind := String(args.get("kind","weapon"))
	var id := String(args.get("id","W01"))
	var key := kind+":"+id
	if not owner.cpp_resources.equipment.has(key): return _cpp_failure("装備の資源が登録されていません。")
	var paths := PackedStringArray()
	for asset: int in owner.cpp_resources.equipment[key]:
		if not owner.cpp_resources.keys.has(asset): return _cpp_failure("装備の資源番号がありません。")
		var path: String = owner.cpp_resources.keys[asset]
		if not path in paths: paths.append(path)
	var scope: ContentResourceScope = ContentManager.prepare_resources(paths,DisplayServer.get_name()!="headless",owner.cpp_resources.signatures)
	owner.closing.connect(scope.cancel.unbind(1),CONNECT_ONE_SHOT)
	while not scope.is_ready() and not scope.cancelled:
		await owner.get_tree().process_frame
	while not scope.failed and not scope.cancelled and not scope.warmup_complete:
		load("res://scripts/render/run_presentation.gd").warm_resources(owner,scope)
		if not scope.warmup_complete: await owner.get_tree().process_frame
	if scope.failed or scope.cancelled or not is_instance_valid(owner) or owner.bridge==null:
		scope.cancel()
		return _cpp_failure("装備の資源を準備できません。")
	var frame: Dictionary = owner.bridge.read_frame()
	if not frame.ok or frame.value.ui.phase not in [Phase.Play,Phase.Paused,Phase.Levelup]:
		scope.cancel()
		return _cpp_failure("終了中のランは変更できません。")
	var result: Dictionary = owner.bridge.command("dev_grant_equipment",{"kind":kind,"id":id,"levels":int(args.get("levels",1))})
	if result.ok and owner.cpp_choices!=null:
		if owner.cpp_choices.equipped.has(key): owner.cpp_choices.equipped[key].cancel()
		owner.cpp_choices.equipped[key] = scope
	else: scope.cancel()
	return result

func _cpp_failure(message: String) -> Dictionary:
	return {"ok":false,"code":4,"field":"debug","message":message,"value":null}
