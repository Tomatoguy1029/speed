## 編成シーンの改名後、Godotが古い場所を指すUIDキャッシュを保持していても現在の保存先へ揃える。
## ファイルとResourceの内容は変更しない。
@tool
extends RefCounted

static var aliases: Dictionary = {}

static func sync(directory := "res://data/formations") -> void:
	var paths_by_uid := {}
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".tscn"): continue
		var path := directory.path_join(file)
		var uid := ResourceLoader.get_resource_uid(path)
		if uid == ResourceUID.INVALID_ID: continue
		if not paths_by_uid.has(uid): paths_by_uid[uid] = []
		paths_by_uid[uid].append(path)
	for uid in paths_by_uid:
		var paths: Array = paths_by_uid[uid]
		if paths.size() != 1: continue
		var path: String = paths[0]
		if not ResourceUID.has_id(uid):
			ResourceUID.add_id(uid, path)
			continue
		var old_path := ResourceUID.get_id_path(uid)
		if old_path == path: continue
		if old_path != "" and not FileAccess.file_exists(old_path):
			aliases[old_path] = path
		ResourceUID.set_id(uid, path)

static func current_path(path: String) -> String:
	return path if FileAccess.file_exists(path) else str(aliases.get(path, path))

## 開いたままのStageが旧シーンを保持した場合だけ、同じUIDの新パスへ参照をつなぐ。
## 保存済みStageの同じClip IDを根拠にし、他の編集中の値は変えず、ディスクへは書かない。
static func rebind_stage(stage: StageDef) -> bool:
	if stage == null or stage.resource_path == "": return false
	sync()
	var stale := false
	for clip in stage.clips:
		for scene in clip.formations:
			if scene != null and current_path(scene.resource_path) != scene.resource_path:
				stale = true
				break
		if stale: break
	if not stale: return false
	var saved := ResourceLoader.load(stage.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	if saved == null: return false
	var by_id := {}
	for clip in saved.clips:
		var id := clip.get_scene_unique_id()
		if id != "": by_id[id] = clip
	var repaired := false
	for clip in stage.clips:
		var id := clip.get_scene_unique_id()
		if id == "" or not by_id.has(id): continue
		var disk_clip: SpawnClip = by_id[id]
		var formations: Array[PackedScene] = clip.formations.duplicate()
		var changed := false
		for index in formations.size():
			var old := formations[index]
			if old == null: continue
			var path := current_path(old.resource_path)
			if path == old.resource_path: continue
			var matches: Array[PackedScene] = []
			for candidate in disk_clip.formations:
				if candidate != null and candidate.resource_path == path:
					matches.append(candidate)
			if matches.size() != 1: continue
			formations[index] = matches[0]
			changed = true
		if not changed: continue
		clip.formations = formations
		repaired = true
		if clip.layouts.is_empty() or disk_clip.layouts.is_empty(): continue
		var allowed := false
		for scene in clip.formations:
			if scene == null: continue
			var root := scene.instantiate()
			if root.has_method("to_data") and not clip.allowed_layouts(scene.resource_path, root.to_data()).is_empty():
				allowed = true
			root.free()
		if allowed: continue
		# 旧名と新名を一意に照合できないときは、旧選択を残して保存済みの同じClipの選択も有効にする。
		var layouts: Array[StringName] = clip.layouts.duplicate()
		for key in disk_clip.layouts:
			if not layouts.has(key): layouts.append(key)
		clip.layouts = layouts
	return repaired
