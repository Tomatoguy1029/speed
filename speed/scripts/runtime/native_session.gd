## 比較用ランの寿命と表示資源を管理する。成長の答えはcoreが所有する。
extends Node
var core: RefCounted
var candidates := {}
var equipped := {}
var reported := {}
var revision := -1
var closed := false
func attach(value: RefCounted) -> void:
	core = value
func sync_requests() -> void:
	if closed or core==null: return
	var next: int = core.progression_revision()
	if next!=revision:
		var state: Dictionary = core.progression_snapshot()
		for id in candidates:
			var scope: ContentResourceScope = candidates[id]
			if state.weapons.has(id) or state.traits.has(id): equipped[id] = scope
			else: scope.cancel()
		candidates.clear()
		reported.clear()
		revision = next
	var requests: Array = core.drain_resource_requests()
	for request in requests:
		var entry := ContentManager.catalog.find(StringName(request.category),request.id)
		if entry==null:
			core.resources_ready(request.revision,request.id,-1)
			continue
		if equipped.has(request.id):
			core.resources_ready(request.revision,request.id,1)
		else:
			candidates[request.id] = ContentManager.prepare_resources(entry.resources,DisplayServer.get_name()!="headless")
func poll_resources() -> void:
	if closed or core==null: return
	sync_requests()
	for id in candidates.keys():
		if reported.has(id): continue
		var scope: ContentResourceScope = candidates[id]
		var status := 0
		if scope.cancelled: status = -2
		elif scope.failed: status = -1
		elif scope.is_ready():
			if not scope.warmup_complete:
				load("res://scripts/render/run_presentation.gd").warm_resources(self,scope)
			else: status = 1
		if status!=0:
			reported[id] = true
			core.resources_ready(revision,id,status)
	sync_requests()
func choose(index: int) -> bool:
	if closed or core==null: return false
	var state: Dictionary = core.progression_snapshot()
	var accepted: bool = core.choose_card(index,state.revision)
	# 最後の選択で次の要求がなくても、選んだ資源を保持する。
	var after: Dictionary = core.progression_snapshot()
	if after.revision!=state.revision:
		for id in candidates:
			if after.weapons.has(id) or after.traits.has(id): equipped[id] = candidates[id]
			else: candidates[id].cancel()
		candidates.clear()
	sync_requests()
	return accepted
func _process(_dt: float) -> void:
	poll_resources()
func close() -> void:
	if closed: return
	closed = true
	for scope: ContentResourceScope in candidates.values()+equipped.values(): scope.cancel()
	candidates.clear()
	equipped.clear()
	if core!=null: core.close()
	core = null
func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE: close()
