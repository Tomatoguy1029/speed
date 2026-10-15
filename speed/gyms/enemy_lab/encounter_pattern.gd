## ルートを先に回転・伸縮し、許可した領域の中だけで敵の配置を変える。
extends Node
const CONSTRUCT := preload("res://scripts/encounters/encounter_coordinator.gd")
const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const CHECK := preload("res://scripts/encounters/route_constraints.gd")
var cancelled := false
signal progress(attempt: int)

func capture(session, path: PackedVector2Array, jitter := 60.0, margin := 20.0) -> Dictionary:
	if path.size() < 2:
		return {}
	var regions := []
	var t := session.run.enemies.table as EnemyTable
	var origin := path[0]
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i]:
			var offset := t.pos[i] - origin
			regions.append({"type": String(t.type[i]), "pos": [offset.x, offset.y], "jitter": maxf(0, jitter),
				"level": t.level[i], "angle": t.facing[i], "elite": t.elite[i] != 0,
				"role": "fodder" if t.gate[i] == EnemyTable.Gate.NONE and t.hp[i] <= session.run.combat.attack_power() and t.armor[i] <= session.run.combat.attack_power() else "avoid"})
	var points := []
	for point in path:
		var offset := point - origin
		points.append([offset.x, offset.y])
	return {"route": points, "regions": regions, "anchor": [origin.x, origin.y], "margin": margin,
		"rotation": PI, "scale_min": 0.8, "scale_max": 1.0, "min_fodder": 1, "window": 0.0, "attempts": 32}

func generate(source, pattern: Dictionary, seed_value: int) -> Dictionary:
	cancelled = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var worker = SESSION.new()
	add_child(worker)
	await worker.reset(source.spec)
	worker.history.assign(source.history.duplicate(true))
	worker.furthest = source.tick
	var reasons := []
	var last_candidate: Dictionary = {}
	var last_validation: Dictionary = {}
	var supported_seen := false
	for attempt in clampi(int(pattern.get("attempts", 32)), 1, 128):
		if cancelled:
			break
		await worker.seek(source.tick)
		var candidate := CONSTRUCT.construct(pattern, rng, source.vector(pattern.get("anchor", [0, 0])))
		if not candidate.get("valid", false): continue
		var path: PackedVector2Array = candidate.route
		var commands: Array = candidate.commands
		var roles_valid := true
		var positions := []
		for command in commands:
			var at := worker.vector(command.args.pos)
			for point in positions:
				if at.distance_to(point) < float(pattern.get("min_spacing", 0)): roles_valid = false
			positions.append(at)
			worker.perform(command.kind, command.args)
			if command.args.get("role") == "avoid":
				var t: EnemyTable = worker.run.enemies.table
				var row: int = worker.selected
				if row >= 0 and CHECK.distance_to_path(t.pos[row], path) <= t.r[row] + CHECK.sweep_radius(worker.run, float(pattern.get("margin", 20))):
					roles_valid = false
		last_candidate = candidate
		var result := CHECK.validate(worker, path, float(pattern.get("margin", 20)), float(pattern.get("window", 0)), float(pattern.get("draw_seconds", 0.5)), float(pattern.get("exit_clearance", 0)))
		last_validation = result
		if result.status != "unsupported": supported_seen = true
		progress.emit(attempt + 1)
		if roles_valid and result.valid and result.fodder.size() >= int(pattern.get("min_fodder", 1)):
			worker.queue_free()
			return {"status": result.status, "admitted": true, "commands": commands, "route": path, "validation": result,
				"seed": seed_value, "attempt": attempt + 1, "source_digest": source.digest(), "source_tick": source.tick}
		reasons = result.blockers
		worker.history.assign(source.history.duplicate(true))
		worker.furthest = source.tick
		await get_tree().process_frame
	worker.queue_free()
	return {"status": "cancelled" if cancelled else ("unfound" if supported_seen else "unsupported"), "admitted": false,
		"route": last_candidate.get("route", PackedVector2Array()), "commands": last_candidate.get("commands", []),
		"validation": last_validation, "seed": seed_value, "source_digest": source.digest(), "reasons": reasons,
		"reason": TranslationServer.translate("lab.message_5931a7be25" )}
