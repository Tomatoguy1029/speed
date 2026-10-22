## 定義を読まずに、ID・並び順・画面用の値を引く。
class_name ContentCatalog
extends Resource
@export var source_signature := ""
@export var entries: Array[ContentEntry] = []
func table(category: StringName) -> Dictionary:
	var result := {}
	for entry in entries:
		if entry.category == category:
			result[entry.index if category == &"stages" else entry.id] = entry
	return result
func find(category: StringName, id: Variant) -> ContentEntry:
	for entry in entries:
		if entry.category == category and (entry.index == id if category == &"stages" else entry.id == StringName(id)):
			return entry
	return null
