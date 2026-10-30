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
var completed_actions := 0
var section_spent := 0.0
var interval_remaining := 0.0
var no_candidate_elapsed := 0.0
var waiting_for_candidate := false
var active_post_gap := 0.0

func configure(value: Resource) -> void:
	flow = value
	index = 0
	active = false
	stamina = flow.maximum_stamina
	last.clear()
	rest_remaining = 0.0
	retry = 0.0
	completed_actions = 0
	section_spent = 0.0
	interval_remaining = 0.0
	active_post_gap = 0.0
	_reset_candidate_wait()

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
		completed_actions += 1
		if completed_actions >= maxi(1, int(section.get("action_count", 1))) or section_spent >= float(section.get("section_budget", INF)) - 0.00001:
			_advance(section)
			interval_remaining = active_post_gap
		else:
			interval_remaining = active_post_gap + maxf(0.0, float(section.get("action_interval", 0.0)))
			if interval_remaining > 0.0: retry = 0.0
		active_post_gap = 0.0
		if stamina <= 0.00001:
			# 明示休息への遷移時は二重に休まない。
			if flow.sections[index].get("request", "normal") == "rest": index = int(flow.sections[index].get("next", 0))
			begin_rest(index)
		return
	if section.get("request", "normal") == "rest":
		completed_actions = 0
		section_spent = 0.0
		interval_remaining = 0.0
		_reset_candidate_wait()
		begin_rest(clampi(int(section.get("next", 0)), 0, flow.sections.size() - 1))
		return
	if interval_remaining > 0.0:
		interval_remaining = maxf(0.0, interval_remaining - dt)
		if interval_remaining > 0.0: return
	if waiting_for_candidate:
		no_candidate_elapsed += dt
		if section.has("no_candidate_timeout") and no_candidate_elapsed >= float(section.no_candidate_timeout):
			_skip_unavailable(section)
			return
	retry = maxf(0.0, retry - dt)
	if retry > 0.0: return
	retry = 0.15
	var query := context.duplicate()
	query["request"] = section.get("request", "normal")
	query["stamina"] = stamina
	query["stamina_max"] = flow.maximum_stamina
	query["section"] = index
	query["section_spent"] = section_spent
	var result: Dictionary = adapter.candidates(query)
	var candidates: Array = result.get("candidates", [])
	var request: String = String(section.get("request", "normal"))
	if section.has("allowed_groups") or section.has("allowed_categories"):
		candidates = candidates.filter(func(candidate): return String(candidate.get("group", "")) in section.get("allowed_groups", []) or String(candidate.get("label", "normal")) in section.get("allowed_categories", []))
	elif request == "major": candidates = candidates.filter(func(candidate): return candidate.get("category", "single") == "major")
	elif request == "normal": candidates = candidates.filter(func(candidate): return candidate.get("category", "single") != "major")
	if section.has("allowed_techniques"):
		candidates = candidates.filter(func(candidate): return String(candidate.id) in section.allowed_techniques)
	if section.has("excluded_techniques"):
		candidates = candidates.filter(func(candidate): return String(candidate.id) not in section.excluded_techniques)
	if candidates.is_empty():
		_record_decision(adapter, query, result, section, [], {}, "no_eligible_candidate")
		status = result.get("reason", "候補なし")
		_wait_for_candidate(section)
		return
	var cap := minf(float(section.get("cap", flow.maximum_stamina)), flow.maximum_stamina)
	var within_cap: Array = candidates.filter(func(c): return float(c.cost) >= 0.0 and float(c.cost) <= cap)
	var remaining_budget := maxf(0.0, float(section.get("section_budget", INF)) - section_spent)
	var within_budget: Array = within_cap.filter(func(c): return float(c.cost) <= remaining_budget)
	var affordable: Array = within_budget.filter(func(c): return float(c.cost) <= stamina)
	if affordable.is_empty():
		var reason := "section_cap" if within_cap.is_empty() else "section_budget" if within_budget.is_empty() else "stamina_rest"
		_record_decision(adapter, query, result, section, [], {}, reason)
		if not within_budget.is_empty():
			_reset_candidate_wait()
			begin_rest(index)
		else:
			status = "区間上限または最大スタミナで実行できる技がありません"
			_wait_for_candidate(section)
		return
	candidates = affordable
	var selection := section.duplicate()
	selection.available = minf(minf(stamina, cap), remaining_budget)
	if adapter.has_method("parallel_attacks_enabled"): selection["allow_parallel"] = adapter.parallel_attacks_enabled()
	if adapter.has_method("selection_bias"): selection["technique_weights"] = adapter.selection_bias()
	selector.record_details = adapter.has_method("observing_decisions") and adapter.observing_decisions()
	var actions: Array = selector.choose(candidates, selection, last, section.get("forbidden", []))
	_record_decision(adapter, query, result, section, actions, selector.diagnostics, "zero_weight" if actions.is_empty() else "weighted_random")
	if actions.is_empty():
		status = "成立する攻撃種別の確率が0です"
		_wait_for_candidate(section)
		return
	if adapter.start(actions):
		for action in actions:
			stamina = maxf(0.0, stamina - float(action.cost))
			section_spent += float(action.cost)
		active = true
		last = actions
		active_post_gap = 0.0
		for action in actions:
			if action.get("label", "normal") != "combo": active_post_gap = maxf(active_post_gap, float(action.get("post_gap", 0.0)))
		status = "実行中"
		_reset_candidate_wait()
	else:
		status = "開始条件が変わりました"
		_wait_for_candidate(section)

func _advance(section: Dictionary) -> void:
	index = clampi(int(section.get("next", (index + 1) % flow.sections.size())), 0, flow.sections.size() - 1)
	completed_actions = 0
	section_spent = 0.0
	interval_remaining = 0.0
	_reset_candidate_wait()

func _skip_unavailable(section: Dictionary) -> void:
	index = clampi(int(section.get("fallback", section.get("next", (index + 1) % flow.sections.size()))), 0, flow.sections.size() - 1)
	completed_actions = 0
	section_spent = 0.0
	interval_remaining = 0.0
	retry = 0.0
	_reset_candidate_wait()
	status = "候補なしで次区間へ"

func _wait_for_candidate(section: Dictionary) -> void:
	if not section.has("no_candidate_timeout") and section.has("fallback"):
		_skip_unavailable(section)
		return
	if section.has("no_candidate_timeout") and float(section.no_candidate_timeout) <= 0.0:
		_skip_unavailable(section)
		return
	waiting_for_candidate = true

func _reset_candidate_wait() -> void:
	no_candidate_elapsed = 0.0
	waiting_for_candidate = false

func begin_rest(next_index: int) -> void:
	interval_remaining = 0.0
	_reset_candidate_wait()
	rest_kind = "empty" if stamina <= 0.00001 else "partial"
	rest_remaining = maxf(0.001, flow.empty_rest if rest_kind == "empty" else flow.partial_rest)
	_rest_next = next_index
	status = "枯渇休息" if rest_kind == "empty" else "残量あり休息"

func _record_decision(adapter: Object, query: Dictionary, result: Dictionary, section: Dictionary, actions: Array, selection: Dictionary, reason: String) -> void:
	if adapter.has_method("record_decision"): adapter.record_decision(query, result, section, last, actions, selection, reason)

## 接近への反応も同じスタミナを使う。実行中の区間と完了回数は保つ。
func try_start_reactive(adapter: Object, action: Dictionary) -> bool:
	if flow == null or flow.sections.is_empty() or rest_remaining > 0.0 or adapter.blocked(): return false
	var section: Dictionary = flow.sections[index]
	if section.get("request", "normal") == "rest": return false
	var cost := float(action.get("cost", INF))
	var cap := minf(float(section.get("cap", flow.maximum_stamina)), flow.maximum_stamina)
	if cost < 0.0 or cost > stamina or cost > cap or cost > float(section.get("section_budget", INF)) - section_spent: return false
	var started: bool = adapter.start_reactive(action) if adapter.has_method("start_reactive") else adapter.start([action])
	if not started: return false
	stamina = maxf(0.0, stamina - cost)
	section_spent += cost
	last = [action]
	_record_decision(adapter, {"reactive": true, "section": index}, {"candidates": [action]}, section, [action], {}, "reactive")
	return true
