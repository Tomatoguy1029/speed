## 採用したステージの配置規則だけを実行する。候補が成立しなければ出現を見送る。
extends Node
const CHECK := preload("res://scripts/encounters/route_constraints.gd")
const DIRECTOR := preload("res://scripts/encounters/attack_director.gd")
var run: RunManager
var tick: int:
	get: return roundi(run.state.sim_time * 60.0)
var spec: Dictionary = {}
var schedule: Array = []
var profile: Dictionary = {}
var _next := 0.0
var opportunity: Dictionary = {}

func setup(manager: RunManager, value: Dictionary) -> void:
	run = manager
	profile = value.duplicate(true)
	if not profile.get("enabled", false):
		return
	for path in profile.get("baseline", {}):
		if not (String(path).begins_with("res://data/") or String(path).begins_with("res://scripts/") or String(path).begins_with("res://gyms/enemy_lab/")) or FileAccess.get_sha256(path) != profile.baseline[path]:
			profile.enabled = false
			push_warning(TranslationServer.translate("lab.message_d51f72362d"))
			return
	var director = DIRECTOR.new()
	director.state = run.state
	director.projectiles = run.projectiles
	director.configure(profile.get("director", {}))
	run.projectiles.director = director

func digest() -> String:
	return str(run.state.rng.state)

func before_world() -> void:
	if run.projectiles.director != null:
		run.projectiles.director.advance(run.state.world_time, run.enemies)

func advance() -> void:
	if not profile.get("enabled", false) or run.state.world_time < _next:
		return
	_next = run.state.world_time + maxf(0.5, float(profile.get("interval", 5)))
	var phases: Array = profile.get("phases", [])
	if not phases.is_empty() and not phases.has(String(run.enemies.current_phase().id)):
		return
	var patterns: Array = profile.get("patterns", [])
	if patterns.is_empty():
		return
	var pattern: Dictionary = patterns[run.state.rng.randi_range(0, patterns.size() - 1)]
	for attempt in clampi(int(pattern.get("attempts", 8)), 1, 32):
		var candidate := construct(pattern, run.state.rng, run.state.view_center)
		if not candidate.get("valid", false):
			continue
		var path: PackedVector2Array = candidate.route
		var window := float(pattern.get("window", 0))
		var result := CHECK.validate(self, path, float(pattern.get("margin", 20)), window, float(pattern.get("draw_seconds", 0.5)), float(pattern.get("exit_clearance", 0)))
		if not result.valid or not _admit_candidates(candidate.commands, path, float(pattern.get("margin", 20)), window, pattern):
			continue
		for command in candidate.commands:
			var args: Dictionary = command.args
			run.enemies.spawn(run.enemies.def_of(StringName(args.type)), 1.0, Vector2(args.pos[0], args.pos[1]), {"facing": args.angle})
		opportunity = {"route": path, "status": result.status, "start": run.state.world_time, "window": window, "margin": result.margin}
		if window > 0:
			run.projectiles.director.guard = {"route": path, "until": run.state.world_time + window, "margin": result.margin}
		run.state.emit(&"route_opportunity", opportunity)
		return
	run.state.emit(&"encounter_deferred", {"reason": TranslationServer.translate("lab.message_5e0ec7996a")})

static func construct(pattern: Dictionary, rng: RandomNumberGenerator, anchor: Vector2) -> Dictionary:
	var angle := rng.randf_range(-float(pattern.get("rotation", PI)), float(pattern.get("rotation", PI)))
	var scale_value := rng.randf_range(float(pattern.get("scale_min", 0.8)), float(pattern.get("scale_max", 1)))
	var path := PackedVector2Array()
	for point in pattern.get("route", []):
		path.append(anchor + Vector2(float(point[0]), float(point[1])).rotated(angle) * scale_value)
	var commands := []
	for region in pattern.get("regions", []):
		var type := StringName(region.get("type", ""))
		if not ConfigManager.enemies.has(type) and not ConfigManager.bosses.has(type):
			return {"valid": false, "reason": TranslationServer.translate("lab.message_461a6d1eec")}
		var minimum := clampi(int(region.get("min_count", 1)), 0, 100)
		var maximum := clampi(int(region.get("max_count", 1)), minimum, 100)
		for n in rng.randi_range(minimum, maximum):
			var point := Vector2(float(region.pos[0]), float(region.pos[1]))
			point += Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * float(region.get("jitter", 0))
			point = anchor + point.rotated(angle) * scale_value
			commands.append({"kind": "boss" if ConfigManager.bosses.has(type) else "spawn", "args": {"type": region.type, "pos": [point.x, point.y], "angle": float(region.get("angle", 0)) + angle, "role": region.get("role", "avoid"), "level": float(region.get("level", 1)), "elite": region.get("elite", false)}})
	return {"valid": path.size() >= 2, "route": path, "commands": commands}

func _admit_candidates(commands: Array, path: PackedVector2Array, margin: float, window: float, pattern: Dictionary) -> bool:
	var fodder := 0
	var positions := []
	for command in commands:
		var args: Dictionary = command.args
		if command.kind != "spawn" or int(args.get("level", 1)) != 1 or args.get("elite", false): return false
		var def := run.enemies.def_of(StringName(args.type))
		if def == null or def.id in [&"meteor", &"saw", &"iron"] or def.behavior == &"part":
			return false
		var pos := Vector2(args.pos[0], args.pos[1])
		for point in positions:
			if point.distance_to(pos) < float(pattern.get("min_spacing", 0)): return false
		positions.append(pos)
		var radius := def.radius * run.cfg.character_scale + run.cfg.ship_radius + margin
		var can_kill := def.gate == &"" and def.hp * run.cfg.enemy_hp_mult <= run.combat.attack_power() and def.armor * run.cfg.enemy_armor_mult <= run.combat.attack_power()
		if window > 0 and (def.speed > 0 or def.behavior not in [&"drift", &"chase"] or def.params.has("chain_power")):
			return false
		if pos.length() + radius >= run.cfg.field_radius or run.field.body_gap(pos, radius) <= 0:
			return false
		if minf(CHECK.distance_to_path(pos, path), pos.distance_to(path[path.size() - 1]) - float(pattern.get("exit_clearance", 0))) <= radius:
			if not can_kill or args.role != "fodder":
				return false
			fodder += 1
	return fodder >= int(pattern.get("min_fodder", 1))
