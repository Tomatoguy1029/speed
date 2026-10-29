## 技の @export と ## の説明を、エディターと実験場の欄へ反映する。
extends RefCounted

const ARC_KEYS := ["offset_x", "offset_y", "radius", "angle_degrees", "spread_degrees", "count"]
const ARC_LABELS := {"offset_x":"位置 X", "offset_y":"位置 Y", "radius":"半径", "angle_degrees":"中心角度", "spread_degrees":"広がり", "count":"弾数"}
const REQUIRED := {"spiral": ["warn", "active", "recover", "damage", "radius_factor", "aspect_ratio", "inner_radius_factor", "coil_time", "pause", "head_offset", "exit_duration", "spiral_length", "shrink_time"]}

static func is_angle(key: String, move: Resource = null) -> bool:
	return move != null and "radians_as_degrees" in String(move.field_property(key).get("hint_string", ""))
static func to_display(key: String, value: float, move: Resource = null) -> float:
	return rad_to_deg(value) if is_angle(key, move) else value
static func from_display(key: String, value: float, move: Resource = null) -> float:
	return deg_to_rad(value) if is_angle(key, move) else value
static func editable_keys(move: Resource) -> Array[String]:
	var keys: Array[String] = []
	if move == null: return keys
	for key in move.field_names():
		if move.technique == &"spiral" and key == "warn": continue
		if move.field(key) is int or move.field(key) is float: keys.append(String(key))
	return keys
static func label_for(move: Resource, key: String, _compact := false) -> String:
	var description: String = move.field_description(key)
	return description.split("\n")[0] if not description.is_empty() else key
static func tip_for(move: Resource, key: String) -> String:
	return move.field_description(key)
static func bounds_for(move: Resource, key: String) -> Vector2:
	var hint := String(move.field_property(key).get("hint_string", "")).split(",")
	return Vector2(float(hint[0]), float(hint[1])) if hint.size() >= 2 else Vector2(0.0, 100000.0)
static func step_for(move: Resource, key: String) -> float:
	var hint := String(move.field_property(key).get("hint_string", "")).split(",")
	return float(hint[2]) if hint.size() >= 3 else 1.0 if move.field(key) is int else 0.01
static func arc_bounds(key: String) -> Vector2:
	return Vector2(-10000.0, 100000.0) if key in ["offset_x", "offset_y", "angle_degrees"] else Vector2(1.0, 100000.0)
