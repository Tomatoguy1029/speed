extends SceneTree
class Adapter:
	extends RefCounted
	var selections: Array = []
	var pool := [{"id":"a","category":"major","cost":2.0,"parts":[1],"exclusive":true},{"id":"b","category":"major","cost":2.0,"parts":[1],"exclusive":true}]
	func blocked() -> bool: return false
	func running() -> bool: return false
	func candidates(_query: Dictionary) -> Dictionary: return {"candidates":pool}
	func start(actions: Array) -> bool:
		selections.append(String(actions[0].id))
		return true
func _initialize() -> void:
	var flow = preload("res://scripts/data_types/boss_flow_def.gd").new()
	flow.maximum_stamina=2.0
	flow.empty_rest=0.01
	flow.sections=[{"request":"any","cap":2.0,"next":0,"weights":{"major":100.0}}]
	var runner = preload("res://scripts/bosses/flow/runner.gd").new()
	runner.configure(flow)
	runner.selector.random.seed=0
	var adapter := Adapter.new()
	for frame in 200: runner.tick(0.05,{},adapter)
	var repeats := 0
	for j in range(1,adapter.selections.size()):
		if adapter.selections[j]==adapter.selections[j-1]: repeats+=1
	if repeats>0: push_error("Rest discarded repeat avoidance history: %d consecutive repeats"%repeats)
	adapter.pool.resize(1)
	var before := adapter.selections.size()
	for frame in 20: runner.tick(0.05,{},adapter)
	var playable := adapter.selections.size()>before
	if not playable: push_error("A sole situational candidate must remain usable")
	print("[boss_flow_rest_history] repeats=",repeats," sole_candidate_usable=",playable)
	quit(0 if repeats==0 and playable else 1)
