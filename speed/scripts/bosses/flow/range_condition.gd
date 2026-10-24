@tool
extends RefCounted

static func allows(gate: Dictionary, relative: Vector2) -> bool:
	var distance := relative.length()
	return distance >= float(gate.get("min", 0.0)) and distance <= float(gate.get("max", 100000.0)) and absf(angle_difference(deg_to_rad(float(gate.get("angle", 0.0))), relative.angle())) <= deg_to_rad(float(gate.get("half_angle", 180.0))) + 0.00001
