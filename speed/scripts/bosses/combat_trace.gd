## One observation per action boundary; geometric checks accumulate in constant space.
## Missing checks never imply a miss. A recording started mid-action keeps a missing prefix.
extends RefCounted
var owner: WeakRef
var generation := -1
var action_id := 0
var decision_id := 0
var action := ""
var origin := "external_forced"
var checks := 0
var contacts := 0
var applied := 0.0
var pass_index := 0
var observed_start := false
var ended := true

func bind(actor: BossActor) -> void:
	owner = weakref(actor)

func enabled(detail := 1) -> bool:
	var a = owner.get_ref() if owner != null else null
	return a != null and a.ctx != null and a.ctx.bosses != null and a.ctx.bosses.diagnostics.enabled(detail)

func _sync() -> void:
	var a = owner.get_ref()
	var current: int = a.ctx.bosses.diagnostics.generation
	if current == generation: return
	generation = current
	action_id = 0
	decision_id = 0
	checks = 0
	contacts = 0
	applied = 0.0
	pass_index = 0
	observed_start = false
	ended = false
	origin = "unobserved"
	action = String(a.get("technique")) if "technique" in a else ""

func context() -> Dictionary:
	_sync()
	var a = owner.get_ref()
	return {"boss": String(a.def.id), "body_id": a.body_id, "body_row": a.body,
		"phase": a.get("phase") if "phase" in a else null, "action": action,
		"action_id": action_id if action_id > 0 else null, "decision_id": decision_id if decision_id > 0 else null,
		"origin": origin, "observed_start": observed_start, "pass": pass_index}

func geometry() -> Dictionary:
	var a = owner.get_ref()
	var at: Vector2 = a.table.pos[a.body]
	var row := {"actor_pos": _point(at), "player_pos": _point(a.run_state.ship_pos),
		"player_velocity": _point(a.run_state.ship_vel), "facing": a.table.facing[a.body],
		"distance": at.distance_to(a.run_state.ship_pos), "mode": String(a.mode) if "mode" in a else ""}
	if "aim_point" in a: row.aim = _point(a.aim_point)
	elif "aim" in a: row.aim = _point(a.aim)
	if "direction" in a: row.direction = _point(a.direction)
	return row

func event(kind: String, extra := {}, detail := 1) -> void:
	if not enabled(detail): return
	var row := context()
	row.merge(geometry())
	row.merge(extra, true)
	owner.get_ref().ctx.bosses.diagnostics.record(kind, row, detail)

func begin(id: StringName, source: String) -> void:
	if not enabled(): return
	_sync()
	if action_id > 0 and not ended: finish("interrupted", "replaced")
	action_id = owner.get_ref().ctx.bosses.diagnostics.next_id()
	action = String(id)
	origin = source
	if source != "natural_ai": decision_id = 0
	checks = 0
	contacts = 0
	applied = 0.0
	pass_index = 0
	observed_start = true
	ended = false
	event("boss_action", {"step": "selected"})

func stage(step: String, extra := {}) -> void:
	if not enabled(): return
	_sync()
	if step == "telegraph": pass_index += 1
	event("boss_action", extra.merged({"step": step}))

func evaluate() -> void:
	if not enabled(): return
	_sync()
	checks += 1

func damage(amount: float, slow: float, cause: StringName, source: StringName) -> bool:
	var a = owner.get_ref()
	if not enabled(): return a.ctx.ship.damage(amount, slow, cause, source)
	_sync()
	contacts += 1
	var before: float = a.run_state.ship_hp
	var accepted: bool = a.ctx.ship.damage(amount, slow, cause, source, context())
	applied += maxf(0.0, before - maxf(0.0, a.run_state.ship_hp))
	return accepted

func finish(step := "completed", reason := "") -> void:
	if not enabled(): return
	_sync()
	if ended or action.is_empty(): return
	# This scope excludes detached projectile/hazard outcomes, which carry their own effect IDs.
	event("boss_action", {"step": step, "reason": reason, "observation_scope": "actor_direct_geometry",
		"checks": checks, "contacts": contacts, "applied": applied,
		"outcome": "hit" if applied > 0.0 else "contact_blocked" if contacts > 0 else "evaluated_miss" if checks > 0 else "no_hit_observed"})
	ended = true

static func _point(value: Vector2) -> Array:
	return [value.x, value.y]
