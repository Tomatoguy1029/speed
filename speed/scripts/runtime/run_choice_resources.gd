## 候補の準備と、確定した装備の資源保持。選択や装備の可否はC++が決める。
extends RefCounted
var bridge: RefCounted
var resources: Resource
var parent: Node
var prepare: Callable
var candidates: Dictionary = {}
var equipped: Dictionary = {}
var _frame: Dictionary = {}
var _epoch := 0
var _closed := false

func attach(next_bridge: RefCounted, index: Resource, owner: Node) -> void:
	bridge = next_bridge
	resources = index
	parent = owner
	bridge.subscribe("choice_resources",consume_frame,["cards","weapon_levels","trait_levels"])

## 配信中は命令を返さず、到着した状態だけ覚える。
func consume_frame(frame: Dictionary) -> bool:
	_frame = frame
	return true

func _key(card: Dictionary) -> String:
	return str(card.get("resource_kind",card.kind))+":"+str(card.get("resource_id",card.id))

func _cancel(row: Dictionary) -> void:
	if not row.get("borrowed",false): row.scope.cancel()

func poll() -> void:
	if _closed or bridge==null or _frame.is_empty(): return
	var frame := _frame
	var ui: Dictionary = frame.ui
	var cards: Dictionary = ui.get("cards",{})
	var owned := {}
	for pair in [["weapon",ui.get("weapon_levels",[])],["trait",ui.get("trait_levels",[])]]:
		for item: Dictionary in pair[1]: owned[str(pair[0])+":"+str(item.id)] = item.level
	if _epoch != int(frame.epoch):
		for row: Dictionary in candidates.values(): _cancel(row)
		candidates.clear()
		_epoch = frame.epoch
	for key in equipped.keys():
		if not owned.has(key):
			equipped[key].cancel()
			equipped.erase(key)
	var valid := {}
	for request: Dictionary in frame.resource_requests: valid[request.request_id] = true
	for id in candidates.keys():
		if valid.has(id): continue
		var row: Dictionary = candidates[id]
		if int(owned.get(row.key,0))>=int(row.level) and row.scope.is_ready() and not row.scope.failed and not row.scope.cancelled:
			if not equipped.has(row.key): equipped[row.key] = row.scope
			elif equipped[row.key] != row.scope: _cancel(row)
		else: _cancel(row)
		candidates.erase(id)
	for request: Dictionary in frame.resource_requests:
		if not candidates.has(request.request_id):
			bridge.begin_resource_wait()
			var card := {}
			for candidate: Dictionary in cards.get("candidates",[]):
				if candidate.get("request_id")==request.request_id: card = candidate
			if card.is_empty(): continue
			var key := _key(card)
			var scope: ContentResourceScope = equipped.get(key)
			var borrowed := scope!=null
			if scope==null:
				var paths := PackedStringArray()
				var invalid := false
				for asset: int in request.asset_keys:
					if not resources.keys.has(asset): invalid = true
					else: paths.append(resources.keys[asset])
				if invalid:
					scope = ContentResourceScope.new()
					scope.failed = true
				else:
					var ordered := PackedStringArray()
					for path in resources.order:
						if path in paths: ordered.append(path)
					if ordered.size()!=paths.size():
						scope = ContentResourceScope.new()
						scope.failed = true
					else:
						scope = prepare.call(ordered) if prepare.is_valid() else ContentManager.prepare_resources(ordered,DisplayServer.get_name()!="headless",resources.signatures)
			candidates[request.request_id] = {"scope":scope,"key":key,"level":card.get("resource_level",card.level),"borrowed":borrowed,"notified":false}
		var row: Dictionary = candidates[request.request_id]
		if row.notified: continue
		var scope: ContentResourceScope = row.scope
		if not scope.is_ready(): continue
		if not scope.failed and not scope.cancelled and not scope.warmup_complete:
			load("res://scripts/render/run_presentation.gd").warm_resources(parent,scope)
			if not scope.warmup_complete: continue
		var status := -2 if scope.cancelled else -1 if scope.failed else 1
		var response: Dictionary = bridge.command("resources_complete",{"request_id":request.request_id,"status":status})
		if response.ok: row.notified = true

	if candidates.values().all(func(row): return row.notified): bridge.end_resource_wait()

func close() -> void:
	if _closed: return
	_closed = true
	for row: Dictionary in candidates.values(): _cancel(row)
	for scope: ContentResourceScope in equipped.values(): scope.cancel()
	candidates.clear()
	equipped.clear()
	if bridge!=null: bridge.unsubscribe("choice_resources")
	bridge = null
	resources = null
	parent = null
	_frame.clear()
