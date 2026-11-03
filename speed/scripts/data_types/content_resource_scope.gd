## 1回の利用で保持する資源。取り消し後に到着した結果を保持しない。
class_name ContentResourceScope
extends RefCounted
var resources: Dictionary = {}
var pending := PackedStringArray()
var composites := PackedStringArray()
var signatures: Dictionary = {}
var cancelled := false
var failed := false
var warming := false
var warmup_complete := DisplayServer.get_name() == "headless"
var warmup_progress := 0.0
var warm_materials: Array[Material] = []
func is_ready() -> bool:
	return pending.is_empty()
func provide(path: String, resource: Resource) -> void:
	pending.erase(path)
	if cancelled: return
	if resource == null: failed = true
	else: resources[path] = resource
func cancel() -> void:
	cancelled = true
	resources.clear()
	warm_materials.clear()
	pending.clear()
	composites.clear()
func progress() -> float:
	return float(resources.size()) / maxf(1.0, resources.size() + pending.size())
