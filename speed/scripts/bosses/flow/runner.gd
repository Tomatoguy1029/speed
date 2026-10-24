extends RefCounted
var flow: Resource
var index := 0
var active := false
var retry := 0.0
var stamina := 0.0
var last: Array = []
var status := ""

func configure(value: Resource) -> void:
	flow = value
	index = 0
	active = false
	stamina = flow.maximum_stamina
	last.clear()

func tick(dt: float, context: Dictionary, adapter: Object) -> void:
	if dt <= 0.0 or flow == null or flow.sections.is_empty() or adapter.blocked(): return
	var section: Dictionary = flow.sections[index]
	if active:
		if adapter.running(): return
		active = false
		index = clampi(int(section.get("next", (index + 1) % flow.sections.size())), 0, flow.sections.size() - 1)
		return
	retry = maxf(0.0, retry - dt)
	if retry > 0.0: return
	retry = 0.15
	var query := context.duplicate()
	query["request"] = section.get("request", "normal")
	query["stamina"] = stamina
	var result: Dictionary = adapter.candidates(query)
	var candidates: Array = result.get("candidates", [])
	if candidates.is_empty():
		status = result.get("reason", "候補なし")
		return
	var actions := [candidates[0]]
	if adapter.start(actions):
		active = true
		last = actions
		status = "実行中"
