## 全部の音の欄。インスペクタでは分類・項目ごとに折りたたんで並べ、合成音・音なしの欄は名前に印を付ける。
## 欄の一覧は sound_slots.gd、値の正は共有の音づけ表（設計書 13）。
@tool
class_name SoundTable
extends Resource

const SLOTS = preload("res://scripts/data_types/sound_slots.gd")
const SYNTH_MARK := "（合成音）"
const SILENT_MARK := "（音なし）"

## 欄ID → SoundEntry。インスペクタには下の分類つきの項目として出す。
@export_storage var entries: Dictionary = {}

var _paths: Dictionary = {}

func entry(id: StringName) -> SoundEntry:
	return entries.get(id) as SoundEntry

func _get_property_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var group := ""
	var section := ""
	for row: Array in SLOTS.ROWS:
		var base := _base(row)
		if row[1] != group:
			group = row[1]
			section = ""
			out.append({"name": group, "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": group + "/"})
		if row[2] != section:
			section = row[2]
			out.append({"name": section, "type": TYPE_NIL, "usage": PROPERTY_USAGE_SUBGROUP, "hint_string": group + "/" + section + "/"})
		var item := entry(row[0])
		var mark := ""
		if item != null: mark = SILENT_MARK if item.silent else SYNTH_MARK if item.is_synth() else ""
		var name := base + mark
		out.append({"name": name, "type": TYPE_OBJECT, "hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "SoundEntry", "usage": PROPERTY_USAGE_EDITOR})
	return out

func _get(property: StringName) -> Variant:
	var id := _id(property)
	if id == &"": return null
	return entries.get(id)

func _set(property: StringName, value: Variant) -> bool:
	var id := _id(property)
	if id == &"": return false
	if value == null: entries.erase(id)
	else: entries[id] = value
	notify_property_list_changed()
	return true

func _base(row: Array) -> String:
	return "%s/%s/%s" % [row[1], row[2], row[3]]

func _id(property: StringName) -> StringName:
	if _paths.is_empty():
		for row: Array in SLOTS.ROWS: _paths[_base(row)] = StringName(row[0])
	var name := String(property).trim_suffix(SYNTH_MARK).trim_suffix(SILENT_MARK)
	return _paths.get(name, &"")
