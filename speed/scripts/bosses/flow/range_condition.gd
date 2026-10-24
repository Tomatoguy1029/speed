@tool
extends RefCounted

static func allows(gate: Dictionary, relative: Vector2) -> bool:
	var distance := relative.length()
	return distance >= float(gate.get("min", 0.0)) and distance <= float(gate.get("max", 100000.0)) and absf(angle_difference(deg_to_rad(float(gate.get("angle", 0.0))), relative.angle())) <= deg_to_rad(float(gate.get("half_angle", 180.0))) + 0.00001

static func allows_snapshot(snapshot: Dictionary, player: Vector2) -> bool:
	var gate: Dictionary = snapshot.gate
	var body: Vector2 = snapshot.get("body", Vector2.ZERO)
	var head: Vector2 = snapshot.get("head", body)
	var base: Vector2 = snapshot.get("base", body)
	var origin: Vector2 = head if int(gate.get("distance_origin", 0)) == 1 else base if int(gate.get("distance_origin", 0)) == 2 else body
	var angle_origin: Vector2 = base if int(gate.get("angle_origin", 0)) == 1 else body
	var facing: float = snapshot.get("facing", 0.0)
	if int(gate.get("angle_origin", 0)) == 1: facing += float(snapshot.get("base_angle", 0.0))
	var angular := gate.duplicate()
	angular.min = 0.0
	angular.max = INF
	if snapshot.get("separated", false) and gate.get("ignore_when_separated", false): angular.half_angle = 180.0
	var distance := player.distance_to(origin)
	var reach: Dictionary = snapshot.get("reach", {})
	var reach_origin := base if reach.get("origin", "head") == "base" else head
	return distance >= float(gate.get("min", 0.0)) and distance <= float(gate.get("max", INF)) and allows(angular, (player - angle_origin).rotated(-facing)) and player.distance_to(reach_origin) <= float(reach.get("max", INF))
