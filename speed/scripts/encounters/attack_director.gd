## 予告前に取得するラン単位の攻撃予算（仕様書 11.7）。
## 本番では個体ごとにvalueを消費し、明示overrideの群れだけ1つのvalueを共有する。分類は記録用。
## 待っていた攻撃は、許可が出てもばらつき（jitter 秒までの乱数）だけ遅れて始める。
extends RefCounted
## 倍精度の加算順だけで越えた分を、値の大きさに応じた数ULPで吸収する。
## 固定の絶対epsilonは微小な正のvalueを0扱いするので使わない。
const FLOAT_ROUNDING := 4.0 * 2.220446049250313e-16
const CATEGORIES := ["aimed", "homing", "dash", "beam", "zone", "wave", "residue"]
const BEHAVIORS := {
	"dash": ["dash"], "gunner": ["aimed"], "missile": ["homing"], "battleship": ["aimed"],
	"rocket": ["dash", "zone"], "bomber": ["zone"], "beamer": ["beam"], "pulser": ["wave"],
	"pump": ["aimed", "zone"], "sniper": ["aimed"], "ruler": ["beam"], "clock": ["residue"],
	"lynx": ["aimed"], "triangle": ["residue"],
	"phoenix": ["dash", "zone"], "crab": ["zone"], "marlin": ["dash", "aimed"],
	"aquarius": ["beam"], "reticle": ["beam"], "auriga": ["residue"], "corona": ["aimed"],
	"aquila": ["zone"], "cross": ["beam"], "dolphin": ["wave"], "cepheus": ["aimed"], "soldier": ["aimed"]}
var guard: Dictionary = {}
var enabled := false
## 本番タイムライン：個体IDまたは共有override群れのIDで枠を管理する。
var formation_mode := false
var settings: Dictionary = {"budget": 4.0, "jitter": 0.3}
var groups: Dictionary = {}
var owners: Dictionary = {}
var waiting: Dictionary = {}
var reasons: Dictionary = {}
var serial := 0
var now := 0.0
var state: RunState
var projectiles: ProjectileSystem

func configure(value: Dictionary) -> void:
	enabled = value.get("enabled", false)
	for key in ["budget", "jitter"]:
		if value.has(key):
			settings[key] = value[key].duplicate(true) if value[key] is Dictionary else float(value[key])

func advance(time: float, enemies: EnemySystem) -> void:
	now = time
	# 期限前の枠は弾を調べず保持する。失効候補がある更新だけ全体を照合する。
	var expired: Array = []
	for token in groups:
		var group: Dictionary = groups[token]
		if formation_mode:
			for member in group.get("members", {}).values():
				var row := int(member.row)
				if enemies.is_same(row, int(member.id)) and not enemies.table.dead[row] and enemies.table.mode[row] == EnemyTable.Mode.WINDUP:
					group.until = maxf(float(group.until), now + maxf(0.05, enemies.table.timer[row]))
		if _time_reached(now, float(group.until)):
			expired.append(token)
	if not expired.is_empty():
		var live := {}
		for i in projectiles.hostile_alive.size():
			if projectiles.hostile_alive[i]:
				live[projectiles.lab_hostile_group.get(i, 0)] = true
		for i in projectiles.hazard_alive.size():
			if projectiles.hazard_alive[i]:
				live[projectiles.lab_hazard_group.get(i, 0)] = true
		for token in expired:
			if live.has(token):
				continue
			var group: Dictionary = groups[token]
			if state != null: state.emit(&"attack_end", {"token": token, "owner": group.owner})
			if owners.get(group.owner, 0) == token:
				owners.erase(group.owner)
			groups.erase(token)
	for owner in waiting.keys():
		var row: int = waiting[owner].row
		if not enemies.is_same(row, int(waiting[owner].id)) or enemies.table.dead[row] or enemies.table.stone[row] > 0.0 				or enemies.table.knock_t[row] > 0.0 or enemies.table.shove_time[row] > 0.0:
			waiting.erase(owner)
			reasons.erase(owner)

func categories(behavior: StringName) -> Array:
	return BEHAVIORS.get(String(behavior), [])

func queue(owner: String, cats: Array, row: int, id: int, priority := 0.0) -> void:
	if waiting.has(owner): waiting[owner].priority = priority
	if not waiting.has(owner):
		waiting[owner] = {"cats": cats, "row": row, "id": id, "since": now, "priority": priority}

## 支援対象などを失った待機だけを取り消す。開始済みの枠・弾・範囲は保持する。
func cancel_wait(owner: String, id := -1) -> void:
	if id >= 0 and waiting.has(owner) and int(waiting[owner].id) != id:
		return
	waiting.erase(owner)
	reasons.erase(owner)

## 未発射の照準を取り消す。同じoverride群れの別個体と、生きている弾の枠は保持する。
func cancel_attack(owner: String, id: int) -> void:
	cancel_wait(owner, id)
	if not owners.has(owner):
		return
	var group: Dictionary = groups[owners[owner]]
	if group.has("members"):
		group.members.erase(str(id))
		group.until = now
		for member in group.members.values():
			group.until = maxf(float(group.until), float(member.until))
	elif int(group.id) == id:
		group.until = now

## 予算全体に収まる待機から先頭を選ぶ。必要量が空くまで後続を待たせる。
## 待ち時間は全候補に同じ割合で加算するので、比較はpriority - since * 0.2で行える。
func _next_owner() -> String:
	var winner := ""
	var best := -INF
	var budget := float(settings.budget)
	if budget <= 0.0:
		return ""
	for candidate: String in waiting:
		var item: Dictionary = waiting[candidate]
		if _greater_than(float(item.get("cost", 1.0)), budget):
			continue
		var score := float(item.priority) - float(item.since) * 0.2
		# 同点は待機登録の順。owner名に含まれる種類や群れの有無で優先しない。
		if winner == "" or score > best:
			winner = candidate
			best = score
	return winner

## cost はownerのvalue（個体、または共有override群れ。省略時は1）。
func request(owner: String, cats: Array, row: int, id: int, duration: float, priority := 0.0, cost := -1.0) -> bool:
	if cats.is_empty():
		return true
	if owners.has(owner):
		var group: Dictionary = groups[owners[owner]]
		if formation_mode:
			var member := str(id)
			if group.members.has(member):
				return not _time_reached(now, float(group.members[member].until))
			if enabled and (float(settings.budget) <= 0.0 or _greater_than(used_cost(), float(settings.budget))):
				reasons[owner] = TranslationServer.translate("lab.message_9ce7705ba3")
				return false
			group.members[member] = {"row": row, "id": id, "until": now + maxf(0.05, duration)}
			group.until = maxf(float(group.until), now + maxf(0.05, duration))
			return true
		if not _time_reached(now, float(group.until)):
			return true
		if enabled:
			reasons[owner] = TranslationServer.translate("lab.message_eb3d91decb")
			return false
	if not is_finite(cost) or cost < 0.0:
		cost = 1.0
	queue(owner, cats, row, id, priority)
	waiting[owner].cost = cost
	if enabled:
		var next := _next_owner()
		if next != "" and next != owner:
			reasons[owner] = TranslationServer.translate("lab.message_aa5d4e5983")
			return false
	var reason := _guard_reason(row)
	if reason.is_empty():
		reason = _capacity(cost) if enabled else ""
	if not reason.is_empty():
		reasons[owner] = reason
		waiting[owner].erase("ready")
		return false
	# 待っていた攻撃は、少しばらつかせてから始める（順番待ちが透けて見えないように）
	if enabled and now > float(waiting[owner].since) + 0.001 and float(settings.get("jitter", 0.0)) > 0.0:
		if not waiting[owner].has("ready"):
			waiting[owner].ready = now + (state.rng.randf() if state != null else 0.5) * float(settings.jitter)
		if not _time_reached(now, float(waiting[owner].ready)):
			return false
	serial += 1
	groups[serial] = {"owner": owner, "row": row, "id": id, "categories": cats.duplicate(), "until": now + maxf(0.05, duration), "start": now, "passive": false, "pos": _source_position(row), "type": _source_type(row), "cost": cost}
	owners[owner] = serial
	if formation_mode:
		groups[serial].members = {str(id): {"row": row, "id": id, "until": now + maxf(0.05, duration)}}
	waiting.erase(owner)
	reasons.erase(owner)
	if state != null:
		state.emit(&"attack_start", {"owner": owner, "row": row, "id": id, "categories": cats, "token": serial})
	return true

## 今出ている攻撃の重さの合計。
func used_cost() -> float:
	var total := 0.0
	for group in groups.values():
		total += float(group.get("cost", 1.0))
	return total

func _greater_than(a: float, b: float) -> bool:
	return a > b and a - b > maxf(absf(a), absf(b)) * FLOAT_ROUNDING

func _time_reached(time: float, deadline: float) -> bool:
	return time >= deadline or deadline - time <= maxf(absf(time), absf(deadline)) * FLOAT_ROUNDING

func _capacity(cost: float) -> String:
	var budget := float(settings.budget)
	var used := used_cost()
	# 予算0は新しい能動攻撃を止める。満杯のときも微小な正valueを無料扱いしない。
	if budget <= 0.0 or (cost > 0.0 and used >= budget) \
			or _greater_than(used + cost, budget):
		return TranslationServer.translate("lab.message_9ce7705ba3")
	return ""

func token(owner: String) -> int:
	return int(owners.get(owner, 0))

func passive(owner: String, row: int, id: int) -> int:
	if formation_mode:
		return 0
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
