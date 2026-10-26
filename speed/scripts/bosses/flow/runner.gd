extends RefCounted
var flow: Resource
var index := 0
var active := false
var retry := 0.0
var stamina := 0.0
var last: Array = []
var status := ""
var selector := preload("res://scripts/bosses/flow/selector.gd").new()
var rest_remaining := 0.0
var _rest_next := 0
var rest_kind := ""

func configure(value: Resource) -> void:
	flow = value
	index = 0
	active = false
	stamina = flow.maximum_stamina
	last.clear()
	rest_remaining = 0.0
	retry = 0.0

func tick(dt: float, context: Dictionary, adapter: Object) -> void:
	if dt > 0.0 and adapter.has_method("tick"): adapter.tick(dt)
	if dt <= 0.0 or flow == null or flow.sections.is_empty() or adapter.blocked(): return
	if rest_remaining > 0.0:
		rest_remaining = maxf(0.0, rest_remaining - dt)
		if rest_remaining <= 0.0:
			stamina = flow.maximum_stamina
			index = _rest_next
			# 休息は攻撃履歴を消さない。成立する別候補がある時の連続回避を維持する。
		return
	var section: Dictionary = flow.sections[index]
	if active:
		if adapter.running(): return
		active = false
		index = clampi(int(section.get("next", (index + 1) % flow.sections.size())), 0, flow.sections.size() - 1)
		if stamina <= 0.00001:
			# 明示休息への遷移時は二重に休まない。
			if flow.sections[index].get("request", "normal") == "rest": index = int(flow.sections[index].get("next", 0))
			begin_rest(index)
		return
	if section.get("request", "normal") == "rest":
		begin_rest(clampi(int(section.get("next", 0)), 0, flow.sections.size() - 1))
		return
	retry = maxf(0.0, retry - dt)
	if retry > 0.0: return
	retry = 0.15
	var query := context.duplicate()
	query["request"] = section.get("request", "normal")
	query["stamina"] = stamina
	query["stamina_max"] = flow.maximum_stamina
	query["section"] = index
	var result: Dictionary = adapter.candidates(query)
	var candidates: Array = result.get("candidates", [])
	if section.has("allowed_techniques"):
		candidates = candidates.filter(func(candidate): return String(candidate.id) in section.allowed_techniques)
	if candidates.is_empty():
		_record_decision(adapter, query, result, section, [], {}, "no_eligible_candidate")
		status = result.get("reason", "候補なし")
		if section.has("fallback"): index = clampi(int(section.fallback), 0, flow.sections.size() - 1)
		return
	var cap := minf(float(section.get("cap", flow.maximum_stamina)), flow.maximum_stamina)
	var within_cap: Array = candidates.filter(func(c): return float(c.cost) >= 0.0 and float(c.cost) <= cap)
	var affordable: Array = within_cap.filter(func(c): return float(c.cost) <= stamina)
	if affordable.is_empty():
		_record_decision(adapter, query, result, section, [], {}, "stamina_rest" if not within_cap.is_empty() else "section_cap")
		if not within_cap.is_empty(): begin_rest(index)
		else: status = "区間上限または最大スタミナで実行できる技がありません"
		return
	candidates = affordable
	var selection := section.duplicate()
	selection.available = minf(stamina, cap)
	selector.record_details = adapter.has_method("observing_decisions") and adapter.observing_decisions()
	var actions: Array = selector.choose(candidates, selection, last, section.get("forbidden", []))
	_record_decision(adapter, query, result, section, actions, selector.diagnostics, "zero_weight" if actions.is_empty() else "weighted_random")
	if actions.is_empty():
		status = "成立する攻撃種別の確率が0です"
		return
	if adapter.start(actions):
		for action in actions: stamina = maxf(0.0, stamina - float(action.cost))
		active = true
		last = actions
		status = "実行中"

func begin_rest(next_index: int) -> void:
	rest_kind = "empty" if stamina <= 0.00001 else "partial"
	rest_remaining = maxf(0.001, flow.empty_rest if rest_kind == "empty" else flow.partial_rest)
	_rest_next = next_index
	status = "枯渇休息" if rest_kind == "empty" else "残量あり休息"

func _record_decision(adapter: Object, query: Dictionary, result: Dictionary, section: Dictionary, actions: Array, selection: Dictionary, reason: String) -> void:
	if adapter.has_method("record_decision"): adapter.record_decision(query, result, section, last, actions, selection, reason)
