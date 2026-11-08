@tool
## 編集元の .tres を保存する共通の入口。
## エディタの外（実験場・プレビュー画面の実行中）で保存すると、本体と参照先の uid が文面から落ちる。
## 保存の前に本体の uid を控え、保存の直後に本体と ext_resource の uid を書き戻す。
class_name TresSaver
extends RefCounted

static func save(resource: Resource, path: String, flags := ResourceSaver.FLAG_NONE) -> Error:
	var own_uid := ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
	var error := ResourceSaver.save(resource, path, flags)
	if error != OK or not path.ends_with(".tres"): return error
	return _restore_uids(path, own_uid)

static func _restore_uids(path: String, own_uid: int) -> Error:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty(): return FileAccess.get_open_error()
	var lines := text.split("\n")
	var changed := false
	for i in lines.size():
		var line := lines[i]
		if i == 0 and line.begins_with("[gd_resource ") and not line.contains(" uid=\"") and own_uid != ResourceUID.INVALID_ID:
			lines[i] = line.trim_suffix("]") + " uid=\"%s\"]" % ResourceUID.id_to_text(own_uid)
			changed = true
		elif line.begins_with("[ext_resource ") and not line.contains(" uid=\"") and line.contains(" path=\""):
			var target := line.get_slice(" path=\"", 1).get_slice("\"", 0)
			var uid := ResourceLoader.get_resource_uid(target)
			if uid == ResourceUID.INVALID_ID: continue
			lines[i] = line.replace(" path=\"", " uid=\"%s\" path=\"" % ResourceUID.id_to_text(uid))
			changed = true
	if not changed: return OK
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	return OK
