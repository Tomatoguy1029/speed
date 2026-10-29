## Headless real actor / JSONL regression. Files are confined to /tmp; no saves or input replay.
extends Node
const DT := 1.0 / 120.0
class Recorder:
	extends "res://scripts/dev/play_recorder.gd"
	var directory := "/tmp/speed-combat-recording-%d" % OS.get_process_id()
	var fail_write := false
	var fail_flush := false
	func _recording_directory() -> String: return directory
	func _store_line(line: String) -> bool: return false if fail_write else super(line)
	func _flush_file() -> bool: return false if fail_flush else super()
var failures := 0
var checks := 0
var session: RunSession
var sim: RunSimulation
var actor
var rec: Recorder
var paths: Array[String] = []
var rows: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[combat_recording] " + label)

func fresh(stage_index := 1, enabled := true) -> void:
	close()
	var stage: RuntimeStage = ContentManager.runtime_stage(stage_index).duplicate(true)
	stage.boss_enabled = false
	session = RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": stage_index, "seed": 718, "hud": false}, false)
	session.auto_step = false
	sim = session.sim
	sim.state.phase = RunState.Phase.PLAY
	sim.state.ship_hp = 10000.0
	sim.state.ship_invuln = 0.0
	sim.state.ship_shield_t = 0.0
	sim.state.ship_pos = Vector2(600, 0)
	sim.state.ship_vel = Vector2.ZERO
	sim.field.bodies.clear()
	sim.field.rocks.clear()
	sim.field.moons.clear()
	sim.field.battle_arenas.clear()
	sim.field._build_moon_bands()
	sim.field.refresh_bodies()
	sim.bosses.spawn(load("res://data/bosses/%s.tres" % ("monoceros" if stage_index == 1 else "draco")), Vector2.ZERO)
	actor = sim.bosses.actor
	actor.selection_enabled = false
	actor.table.facing[actor.body] = 0.0
	if stage_index == 1: actor._cooldown = 0.0
	if enabled: begin_recording()

func begin_recording() -> void:
	rec = Recorder.new()
	add_child(rec)
	rec.set_process(false)
	rec.armed = true
	rec.combat_events_per_second = 1000
	# Test-only admission: production recorder deliberately excludes labs. Origin remains lab.
	sim.state.lab_mode = false
	rec._begin(session)
	sim.state.lab_mode = true
	check(rec._file != null, "recording opens")
	if rec._file != null: paths.append(rec._file.get_path())

func close() -> void:
	if rec != null:
		rec._end("stopped")
		check(sim.bosses.diagnostics.level == 0 and not sim.bosses.diagnostics.recorded.has_connections(), "stop disconnects combat observations")
		rec.free()
		rec = null
	if session != null:
		session.free()
		session = null

func tick(velocity := Vector2.ZERO, projectiles := true) -> void:
	sim.state.time += DT
	sim.state.world_time += DT
	sim.state.ship_vel = velocity
	sim.state.ship_pos += velocity * DT
	sim.state.ship_invuln = maxf(0.0, sim.state.ship_invuln - DT)
	sim.bosses.tick(DT, DT)
	if projectiles:
		sim.projectiles._update_hostile(DT)
		sim.projectiles._update_hazards(DT)

func current_rows() -> Array:
	if rec != null: rec._flush()
	var result := []
	var f := FileAccess.open(paths.back(), FileAccess.READ)
	while f.get_position() < f.get_length():
		var value = JSON.parse_string(f.get_line())
		check(value is Dictionary, "each persisted row parses")
		if value is Dictionary: result.append(value)
	return result

func events(kind: String) -> Array:
	return current_rows().filter(func(e): return e.type == kind)

func outcome(id: String) -> Dictionary:
	var found := events("boss_action").filter(func(e): return e.action == id and e.has("outcome"))
	return found.back() if not found.is_empty() else {}

func execute(id: StringName, dodge := false) -> void:
	check(actor.start_attack(id), "real actor starts " + String(id))
	var moved := false
	for frame in 1800:
		if dodge and not moved:
			var locked: bool = actor.locked if actor is MonocerosBoss else (actor._driver != null and "locked" in actor._driver and actor._driver.locked)
			if locked:
				sim.state.ship_pos += Vector2(0, 1000)
				moved = true
		tick()
		if actor.mode == &"idle": break
	check(actor.mode == &"idle", "real attack completes " + String(id))

func _ready() -> void:
	SaveManager.data = SaveManager.default_data()
	SaveManager.dev_meta_override = {}
	# Natural candidate evaluation uses real phase, cooldown, turn, and predicted reach gates.
	fresh()
	actor.selection_enabled = true
	tick()
	var decisions := events("boss_decision")
	check(decisions.size() == 1 and decisions[0].selected.size() == 1, "natural flow records one actual selection")
	if decisions.size() == 1:
		check(decisions[0].origin == "natural_ai" and decisions[0].selection.has("draw"), "weighted draw is observed without reroll")
		check(decisions[0].candidates.any(func(c): return c.id == "lance" and "phase" in c.reasons), "phase rejects lance")
		check(decisions[0].candidates.any(func(c): return c.id == "sweep" and not c.eligible), "far player rejects melee")
		var starts := events("boss_action").filter(func(e): return e.step == "selected")
		check(starts.size() == 1 and starts[0].decision_id == decisions[0].decision_id and starts[0].origin == "natural_ai", "selected action joins its decision")
	actor.selection_enabled = false
	actor.cancel_attack()
	actor.cooldowns[&"charge"] = actor.clock + 5.0
	var candidates: Dictionary = actor.flow_adapter.candidates({"request": "any"})
	check(candidates.evaluated.any(func(c): return c.id == "charge" and "cooldown" in c.reasons), "cooldown explanation uses readiness evaluator")
	# Static target, dodge after lock, and cancellation before any geometric evaluation.
	fresh(); execute(&"charge")
	var hit := outcome("charge")
	check(hit.get("outcome") == "hit" and hit.get("contacts", 0) > 0 and hit.get("applied", 0) > 0, "Stage1 actual horn hit and applied damage")
	var actions := events("boss_action")
	check(actions.any(func(e): return e.step == "lock") and actions.any(func(e): return e.step == "execute") and actions.any(func(e): return e.step == "recovery"), "telegraph, lock, execute and recovery boundaries")
	check(actions[0].origin == "external_forced" and actions[0].decision_id == null, "forced attack is never natural AI")
	fresh(); execute(&"charge", true)
	var miss := outcome("charge")
	check(miss.get("outcome") == "evaluated_miss" and miss.get("checks", 0) > 0, "dodge after lock produces observed miss")
	actions = events("boss_action")
	var locks := actions.filter(func(e): return e.step == "lock")
	var launches := actions.filter(func(e): return e.step == "execute")
	check(locks.size() == 1 and launches.size() == 1 and locks[0].aim == launches[0].aim and locks[0].player_pos != launches[0].player_pos, "fixed aim remains while player position changes")
	fresh(); actor.start_attack(&"charge"); actor.cancel_attack()
	check(outcome("charge").get("outcome") == "no_hit_observed", "unexecuted attack cannot be called a miss")
	# Every damage rejection preserves HP and the game's bool result.
	for reason in ["shield", "invulnerability", "debug_invincible", "controls_locked", "encounter_protected", "run_phase", "boss_defeated"]:
		fresh()
		if reason == "shield": sim.state.ship_shield_t = 10.0
		if reason == "invulnerability": sim.state.ship_invuln = 10.0
		if reason == "debug_invincible": sim.ship.invincible = true
		if reason == "controls_locked": sim.state.controls_locked = true
		if reason == "encounter_protected": sim.state.encounter_protected = true
		if reason == "run_phase": sim.state.phase = RunState.Phase.PAUSED
		if reason == "boss_defeated": sim.state.boss_dead = true
		var before := sim.state.ship_hp
		check(not sim.ship.damage(7.0, 0.0, &"test", &"monoceros") and sim.state.ship_hp == before, "damage remains blocked: " + reason)
		var damage := events("combat_damage")
		check(damage.size() == 1 and damage[0].reason == reason and damage[0].applied == 0.0, "correct damage refusal: " + reason)
	fresh(); sim.state.ship_shield_t = 100.0; execute(&"charge")
	check(outcome("charge").get("outcome") == "contact_blocked", "geometry contact blocked by shield differs from dodge")
	# Stage5 uses the same actor driver, including its early locked predicted target.
	fresh(5); execute(&"charge")
	check(outcome("charge").get("outcome") == "hit", "Draco charge actual geometry hits static target")
	fresh(5); execute(&"charge", true)
	check(outcome("charge").get("outcome") == "evaluated_miss", "Draco locked charge can be dodged")
	# Damage redirects a body segment to the HP owner and discards excess at phase floor.
	fresh(5)
	actor.start_attack(&"bite")
	var struck: int = actor.body_rows[3]
	var before: float = actor.table.hp[actor.body]
	sim.combat.damage_enemy(struck, before, {"cause": &"shot"})
	var damage := events("combat_damage").filter(func(e): return e.target == "boss")
	check(damage.size() == 1 and damage[0].struck_id != damage[0].target_id and damage[0].reason == "phase_floor" and damage[0].applied > 0.0 and damage[0].discarded > 0.0, "body ID redirect and threshold-clamped damage")
	check(events("boss_phase").any(func(e): return e.phase == 2), "actual phase transition recorded")
	check(outcome("bite").get("reason") == "phase_transition", "phase interrupts current action")
	sim.combat.damage_enemy(actor.body, 2.0, {"cause": &"shot"})
	check(events("combat_damage").back().reason == "guard", "guard refusal records zero applied damage")
	# Continue the real HP threshold sequence through phase three and scripted finale.
	for frame in 2400: tick()
	check(actor.mode == &"idle" and not sim.state.encounter_protected, "phase two cinematic releases protection")
	actor.start_attack(&"bite")
	sim.combat.damage_enemy(actor.body, actor.table.max_hp[actor.body], {"cause": &"shot"})
	check(events("boss_phase").any(func(e): return e.phase == 3), "third phase boundary recorded")
	for frame in 240: tick()
	actor.start_attack(&"bite")
	sim.combat.damage_enemy(actor.body, actor.table.max_hp[actor.body], {"cause": &"shot"})
	check(events("boss_action").any(func(e): return e.step == "finale" and e.origin == "scripted_finale"), "scripted finale is distinguished from natural AI")
	# Real star fan spawns tracked projectiles. Outcomes remain separate after action recovery.
	fresh(5); execute(&"star_fan")
	var effects := events("boss_effect")
	check(effects.any(func(e): return e.step == "spawn" and e.action == "star_fan"), "real projectile emission retains source action")
	check(effects.any(func(e): return e.step == "end" and e.checks > 0), "projectile terminal has evaluated observations")
	check(outcome("star_fan").get("outcome") == "no_hit_observed", "actor direct scope does not invent projectile hit or miss")
	# Slot reuse by an unrelated source cannot inherit old boss metadata.
	var ps := sim.projectiles
	ps.clear_hostile()
	ps.fire_bolt(Vector2.ZERO, 0.0, 100.0, 1.0)
	check(ps._combat_hostiles.is_empty(), "ordinary mob projectile does not inherit boss action on slot reuse")
	# Recording starts mid-action: action ID/decision/start remain unknown, not fabricated.
	fresh(1, false); actor.start_attack(&"charge")
	for frame in 35: tick()
	begin_recording()
	for frame in 450: tick()
	actions = events("boss_action")
	check(not actions.is_empty() and actions.all(func(e): return not e.observed_start and e.action_id == null and e.origin == "unobserved"), "mid-action capture keeps missing prefix")
	# Natural phase changes and explicit finish replay are separate from AI selections.
	fresh()
	actor.table.hp[actor.body] = actor.table.max_hp[actor.body] * 0.1
	tick()
	check(events("boss_phase").any(func(e): return e.phase == 2), "Monoceros phase boundary")
	actor.begin_final_strike(0.5)
	check(events("boss_action").any(func(e): return e.step == "replay" and e.origin == "final_strike_replay"), "replay has explicit origin")
	# Disabled diagnostics preserve the actual simulation and allocate no tracked effects.
	var on := invariant_trial(true)
	var off := invariant_trial(false)
	check(on == off, "recording on/off leaves HP, actor geometry, action and RNG identical")
	check(sim.bosses.diagnostics.emitted == 0 and sim.projectiles._combat_hostiles.is_empty(), "disabled path has no events or projectile metadata")
	# Hundreds of ordinary mobs never acquire boss metadata or per-mob diagnostic rows.
	fresh(5, false)
	var mobs: Array[int] = []
	for index in 500:
		var row := sim.enemies.spawn(load("res://data/enemies/biter.tres"), Vector2(5000 + index * 50, 5000))
		sim.enemies.table.hp[row] = 10000.0
		mobs.append(row)
	var timings := []
	for enabled in [false, true]:
		if enabled: begin_recording()
		var started := Time.get_ticks_usec()
		for sweep in 20:
			for row in mobs: sim.combat.damage_enemy(row, 0.01, {"cause": &"shot"})
			sim.state.events.clear()
		timings.append((Time.get_ticks_usec() - started) / 1000.0)
	check(sim.bosses.diagnostics.emitted == 0, "500 mobs / 10000 damage calls produce zero boss rows")
	print("[combat_overhead] mobs=500 calls_per_mode=10000 disabled_ms=", timings[0], " enabled_ms=", timings[1])
	# Tracked effect storage stays bounded even when one driver emits a large burst.
	sim.bosses.recording_actor = actor
	for index in 600: sim.projectiles.fire_bolt(Vector2.ZERO, 0.0, 100.0, 1.0)
	sim.bosses.recording_actor = null
	check(sim.projectiles._combat_hostiles.size() == 512 and sim.bosses.diagnostics.dropped >= 88, "effect metadata is bounded independently of projectile count")
	sim.projectiles.clear_hostile()
	check(sim.projectiles._combat_hostiles.is_empty(), "effect clear releases all retained metadata")
	# Rate/count/byte bounds are observable. Unknown/truncated data cannot imply complete coverage.
	fresh()
	sim.bosses.diagnostics.configure(2, 2, 2)
	for n in 10: actor.combat_trace.stage("test_boundary")
	check(sim.bosses.diagnostics.emitted == 2 and sim.bosses.diagnostics.dropped == 8, "source count and rate budget bounds events")
	rec.combat_max_bytes = rec._combat_bytes
	sim.bosses.diagnostics.configure(2, 1000, 1000)
	actor.combat_trace.stage("over_byte_limit")
	check(rec._combat_dropped == 1, "byte budget preserves bounded output")
	rec._end("stopped")
	check(current_rows().back().combat_summary.size_dropped >= 1, "end discloses diagnostic loss")
	# Open, write and flush failures: game lives, signals disconnect, successful save is not claimed.
	fresh(1, false)
	rec = Recorder.new(); add_child(rec); rec.set_process(false); rec.armed = true
	rec.directory = "/dev/null/not_a_directory"
	sim.state.lab_mode = false; rec._begin(session); sim.state.lab_mode = true
	check(rec._file == null and rec._run == null and sim.bosses.diagnostics.level == 0, "I/O open failure has no connected recorder")
	for mode in ["write", "flush"]:
		fresh()
		if mode == "write": rec.fail_write = true
		else: rec.fail_flush = true
		actor.combat_trace.stage("failure_probe")
		if mode == "flush": rec._flush()
		await get_tree().process_frame
		check(rec._file == null and rec._run == null and sim.bosses.diagnostics.level == 0 and rec._saved_text == "記録に失敗しました", "I/O failure shuts down once: " + mode)
	fresh(); actor.start_attack(&"charge")
	var last: String = paths.back()
	session.free(); session = null
	check(rec._run == null and rec._file == null, "session exit flushes and closes recorder")
	check(current_rows().back().type == "end", "clean shutdown has terminal row")
	rec.free(); rec = null
	print("[combat_recording] checks=%d failures=%d directory=%s last=%s" % [checks, failures, "/tmp/speed-combat-recording-%d" % OS.get_process_id(), last])
	get_tree().quit(1 if failures else 0)

func invariant_trial(enabled: bool) -> Array:
	fresh(5, enabled)
	actor.selection_enabled = true
	for frame in 900: tick(Vector2(0, 35))
	return [sim.state.ship_hp, actor.table.pos[actor.body], actor.technique, sim.state.rng.state, sim.projectiles.hostile_count()]
