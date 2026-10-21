## 予告前に分類をまとめて取得する、ラン単位の攻撃枠（仕様書 11.7）。
## 同時に出ている攻撃の重さ（cost）の合計が予算（budget）を超えないように待たせる。分類ごとの枠と間隔も使う。
## 待っていた攻撃は、許可が出てもばらつき（jitter 秒までの乱数）だけ遅れて始める。
extends RefCounted
const CATEGORIES := ["aimed", "homing", "dash", "beam", "zone", "wave", "residue"]
const BEHAVIORS := {
	"dash": ["dash"], "gunner": ["aimed"], "missile": ["homing"], "battleship": ["aimed"],
	"rocket": ["dash", "zone"], "bomber": ["zone"], "beamer": ["beam"], "pulser": ["wave"],
	"pump": ["aimed", "zone"], "sniper": ["aimed"], "ruler": ["beam"], "clock": ["residue"],
	"lynx": ["aimed"], "triangle": ["residue"],
	"phoenix": ["residue"], "crab": ["zone"], "marlin": ["dash", "aimed"],
	"aquarius": ["beam"], "auriga": ["residue"], "corona": ["residue"],
	"aquila": ["zone"], "cross": ["beam"], "dolphin": ["wave"], "cepheus": ["aimed"], "soldier": ["aimed"]}
var guard: Dictionary = {}
var enabled := false
var settings: Dictionary = {"budget": 4.0, "slots": {}, "weights": {}, "gaps": {}, "jitter": 0.3}
var groups: Dictionary = {}
var owners: Dictionary = {}
var waiting: Dictionary = {}
var last_start: Dictionary = {}
var reasons: Dictionary = {}
var serial := 0
var now := 0.0
var state: RunState
var projectiles: ProjectileManager

func configure(value: Dictionary) -> void:
	enabled = value.get("enabled", false)
	for key in ["budget", "slots", "weights", "gaps", "jitter"]:
		if value.has(key):
			settings[key] = value[key].duplicate(true) if value[key] is Dictionary else float(value[key])

func advance(time: float, enemies: EnemyManager) -> void:
	now = time
	var live := {}
	for i in projectiles.hostile_alive.size():
		if projectiles.hostile_alive[i]:
			live[projectiles.lab_hostile_group.get(i, 0)] = true
	for i in projectiles.hazard_alive.size():
		if projectiles.hazard_alive[i]:
			live[projectiles.lab_hazard_group.get(i, 0)] = true
	for token in groups.keys():
		var group: Dictionary = groups[token]
		if group.until <= now and not live.has(token):
			if state != null: state.emit(&"attack_end", {"token": token, "owner": group.owner})
			if owners.get(group.owner, 0) == token:
				owners.erase(group.owner)
			groups.erase(token)
	for owner in waiting.keys():
		var row: int = waiting[owner].row
		if not enemies.is_same(row, int(waiting[owner].id)) or enemies.table.dead[row]:
			waiting.erase(owner)
			reasons.erase(owner)

func categories(behavior: StringName) -> Array:
	return BEHAVIORS.get(String(behavior), [])

func queue(owner: String, cats: Array, row: int, id: int, priority := 0.0) -> void:
	if waiting.has(owner): waiting[owner].priority = priority
	if not waiting.has(owner):
		waiting[owner] = {"cats": cats, "row": row, "id": id, "since": now, "priority": priority}

## cost は攻撃の重さ（負なら、分類の重みの合計）。
func request(owner: String, cats: Array, row: int, id: int, duration: float, priority := 0.0, cost := -1.0) -> bool:
	if cats.is_empty():
		return true
	if owners.has(owner):
		if float(groups[owners[owner]].until) > now:
			return true
		if enabled:
			reasons[owner] = TranslationServer.translate("lab.message_eb3d91decb")
			return false
	if cost < 0.0:
		cost = _weights(cats)
	queue(owner, cats, row, id, priority)
	waiting[owner].cost = cost
	var ordered := waiting.keys()
	ordered.sort_custom(func(a, b):
		var pa: float = float(waiting[a].priority) + (now - float(waiting[a].since)) * 0.2
		var pb: float = float(waiting[b].priority) + (now - float(waiting[b].since)) * 0.2
		return a < b if is_equal_approx(pa, pb) else pa > pb)
	# 適合しない先頭によって別分類まで止めない。
	for candidate in ordered if enabled else []:
		if _capacity(waiting[candidate].cats, float(waiting[candidate].get("cost", _weights(waiting[candidate].cats)))).is_empty():
			if candidate != owner:
				reasons[owner] = TranslationServer.translate("lab.message_aa5d4e5983")
				return false
			break
	var reason := _guard_reason(row)
	if reason.is_empty():
		reason = _capacity(cats, cost) if enabled else ""
	if not reason.is_empty():
		reasons[owner] = reason
		waiting[owner].erase("ready")
		return false
	# 待っていた攻撃は、少しばらつかせてから始める（順番待ちが透けて見えないように）
	if enabled and now > float(waiting[owner].since) + 0.001 and float(settings.get("jitter", 0.0)) > 0.0:
		if not waiting[owner].has("ready"):
			waiting[owner].ready = now + (state.rng.randf() if state != null else 0.5) * float(settings.jitter)
		if now < float(waiting[owner].ready):
			return false
	serial += 1
	groups[serial] = {"owner": owner, "row": row, "id": id, "categories": cats.duplicate(), "until": now + maxf(0.05, duration), "start": now, "passive": false, "pos": _source_position(row), "type": _source_type(row), "cost": cost}
	owners[owner] = serial
	for category in cats:
		last_start[category] = now
	waiting.erase(owner)
	reasons.erase(owner)
	if state != null:
		state.emit(&"attack_start", {"owner": owner, "row": row, "id": id, "categories": cats, "token": serial})
	return true

## 分類の重みの合計。
func _weights(cats: Array) -> float:
	var w := 0.0
	for category in cats:
		w += float(settings.weights.get(category, 1.0))
	return w

## 今出ている攻撃の重さの合計。
func used_cost() -> float:
	var total := 0.0
	for group in groups.values():
		total += float(group.get("cost", _weights(group.categories)))
	return total

func _capacity(cats: Array, cost: float) -> String:
	var used := {}
	var total := used_cost()
	for group in groups.values():
		for category in group.categories:
			used[category] = int(used.get(category, 0)) + 1
	for category in cats:
		if int(used.get(category, 0)) >= int(settings.slots.get(category, 1)):
			return category + TranslationServer.translate("lab.message_377bd2f0f5")
		if now - float(last_start.get(category, -1e9)) < float(settings.gaps.get(category, 0.35)):
			return category + TranslationServer.translate("lab.message_49b3b4a997")
	return TranslationServer.translate("lab.message_9ce7705ba3") if total + cost > float(settings.budget) else ""

func token(owner: String) -> int:
	return int(owners.get(owner, 0))

func passive(owner: String, row: int, id: int) -> int:
	serial += 1
	groups[serial] = {"owner": owner + ":passive:" + str(serial), "row": row, "id": id, "categories": ["zone"], "until": now, "start": now, "passive": true, "pos": _source_position(row), "type": _source_type(row)}
	return serial

## 有限時間の認証中は、対応する静止対象以外の新しい能動攻撃を許可しない。
## 未対応攻撃の包絡を安全と仮定しない、保守的な見送り。
func _guard_reason(_row: int) -> String:
	if not guard.is_empty() and now <= float(guard.get("until", -1)):
		return TranslationServer.translate("lab.message_e98c560853")
	return ""

func guard_active() -> bool:
	return not guard.is_empty() and now <= float(guard.get("until", -1))

func _source_position(row: int) -> Vector2:
	if projectiles != null and projectiles.combat != null and row >= 0 and row < projectiles.combat.enemies.table.pos.size(): return projectiles.combat.enemies.table.pos[row]
	return Vector2.ZERO

func _source_type(row: int) -> String:
	if projectiles != null and projectiles.combat != null and row >= 0 and row < projectiles.combat.enemies.table.type.size(): return String(projectiles.combat.enemies.table.type[row])
	return ""
