## 予告前に分類をまとめて取得する、ラン単位の攻撃枠。
extends RefCounted
const CATEGORIES := ["aimed", "homing", "dash", "beam", "zone", "wave", "residue"]
const BEHAVIORS := {
	"dash": ["dash"], "gunner": ["aimed"], "missile": ["homing"], "battleship": ["aimed"],
	"rocket": ["dash", "zone"], "bomber": ["zone"], "beamer": ["beam"], "pulser": ["wave"],
	"pump": ["wave"], "sniper": ["aimed"], "ruler": ["residue"], "clock": ["residue"],
	"lynx": ["wave"], "crow": ["aimed"], "reticle": ["zone"], "triangle": ["residue"],
	"phoenix": ["residue"], "crab": ["zone"], "marlin": ["dash", "aimed"],
	"aquarius": ["aimed"], "auriga": ["residue"], "corona": ["residue"],
	"cepheus": ["aimed"], "aquila": ["zone"]}
var enabled := false
var settings: Dictionary = {"budget": 4.0, "slots": {}, "weights": {}, "gaps": {}}
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
	for key in ["budget", "slots", "weights", "gaps"]:
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
	if not waiting.has(owner):
		waiting[owner] = {"cats": cats, "row": row, "id": id, "since": now, "priority": priority}

func request(owner: String, cats: Array, row: int, id: int, duration: float, priority := 0.0) -> bool:
	if cats.is_empty() or not enabled:
		return true
	if owners.has(owner):
		if float(groups[owners[owner]].until) > now:
			return true
		reasons[owner] = "残留する攻撃の終了待ち"
		return false
	queue(owner, cats, row, id, priority)
	var ordered := waiting.keys()
	ordered.sort_custom(func(a, b):
		var pa: float = float(waiting[a].priority) + (now - float(waiting[a].since)) * 0.2
		var pb: float = float(waiting[b].priority) + (now - float(waiting[b].since)) * 0.2
		return a < b if is_equal_approx(pa, pb) else pa > pb)
	# 適合しない先頭によって別分類まで止めない。
	for candidate in ordered:
		if _capacity(waiting[candidate].cats).is_empty():
			if candidate != owner:
				reasons[owner] = "優先順位の高い要求を先に処理"
				return false
			break
	var reason := _capacity(cats)
	if not reason.is_empty():
		reasons[owner] = reason
		return false
	serial += 1
	groups[serial] = {"owner": owner, "row": row, "id": id, "categories": cats.duplicate(), "until": now + maxf(0.05, duration), "start": now, "passive": false}
	owners[owner] = serial
	for category in cats:
		last_start[category] = now
	waiting.erase(owner)
	reasons.erase(owner)
	if state != null:
		state.emit(&"attack_start", {"owner": owner, "row": row, "id": id, "categories": cats, "token": serial})
	return true

func _capacity(cats: Array) -> String:
	var used := {}
	var total := 0.0
	for group in groups.values():
		for category in group.categories:
			used[category] = int(used.get(category, 0)) + 1
			total += float(settings.weights.get(category, 1.0))
	var cost := 0.0
	for category in cats:
		cost += float(settings.weights.get(category, 1.0))
		if int(used.get(category, 0)) >= int(settings.slots.get(category, 1)):
			return category + "：分類の枠待ち"
		if now - float(last_start.get(category, -1e9)) < float(settings.gaps.get(category, 0.35)):
			return category + "：共通の開始間隔待ち"
	return "全体の攻撃量の上限" if total + cost > float(settings.budget) else ""

func token(owner: String) -> int:
	return int(owners.get(owner, 0))

func passive(owner: String, row: int, id: int) -> int:
	serial += 1
	groups[serial] = {"owner": owner + ":passive:" + str(serial), "row": row, "id": id, "categories": ["zone"], "until": now, "start": now, "passive": true}
	return serial
