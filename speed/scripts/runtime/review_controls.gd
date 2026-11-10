## 審査版の停止中操作。表示資源を準備してからC++へ適用する。
extends RefCounted
var session: RunSession
var busy := false

func apply_equipment(kind: String, id: String, level: int, replace: String) -> Dictionary:
	if busy or session == null or session.bridge == null:
		return {"ok": false, "message": tr("review.unavailable")}
	var scope: ContentResourceScope
	var key := kind + ":" + id
	if level > 0:
		if not session.cpp_resources.equipment.has(key):
			return {"ok": false, "message": tr("review.unavailable")}
		busy = true
		var paths := PackedStringArray()
		for asset: int in session.cpp_resources.equipment[key]:
			var path: String = session.cpp_resources.keys[asset]
			if path not in paths: paths.append(path)
		scope = ContentManager.prepare_resources(paths, DisplayServer.get_name() != "headless", session.cpp_resources.signatures)
		session.closing.connect(scope.cancel.unbind(1), CONNECT_ONE_SHOT)
		while not scope.is_ready() and not scope.cancelled:
			await session.get_tree().process_frame
		while not scope.failed and not scope.cancelled and not scope.warmup_complete:
			load("res://scripts/render/run_presentation.gd").warm_resources(session, scope)
			if not scope.warmup_complete: await session.get_tree().process_frame
		busy = false
		if scope.failed or scope.cancelled or not is_instance_valid(session) or session.bridge == null:
			scope.cancel()
			return {"ok": false, "message": tr("review.unavailable")}
	var result: Dictionary = session.bridge.command("review_equipment", {"kind": kind, "id": id, "level": level, "replace": replace})
	if scope != null:
		if result.ok:
			if session.cpp_choices.equipped.has(key): session.cpp_choices.equipped[key].cancel()
			session.cpp_choices.equipped[key] = scope
		else: scope.cancel()
	return result
