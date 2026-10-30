## 制作画面と戦闘表示で共用する、パーツの基礎ポーズとコマ。
extends Resource

@export var poses: Dictionary = {}
@export var clips: Dictionary = {}
@export var extra_parts: Array[Dictionary] = []
@export var arm_joints: Dictionary = {}
@export var part_pivots: Dictionary = {}

func set_part_pivot(path: String, point: Variant) -> void:
	if point == null: part_pivots.erase(path)
	else: part_pivots[path] = point
	var all_poses: Array = poses.values()
	for frames: Array in clips.values():
		for frame: Dictionary in frames: all_poses.append(frame.pose)
	for pose: Dictionary in all_poses:
		if not pose.has(path): continue
		var entry: Dictionary = pose[path]
		if point == null: entry.erase("pivot_origin")
		else:
			entry.pivot_origin = Transform2D(float(entry.rotation), entry.scale, float(entry.get("skew", 0.0)), entry.position) * point

func duration(clip: String) -> float:
	var total := 0.0
	for frame: Dictionary in clips.get(clip, []):
		total += maxf(0.02, float(frame.get("duration", 0.15)))
	return total

func sample(clip: String, time: float) -> Dictionary:
	var frames: Array = clips.get(clip, [])
	if frames.is_empty(): return poses.get("neutral", {})
	var remaining := maxf(0.0, time)
	for index in frames.size():
		var frame: Dictionary = frames[index]
		var seconds := maxf(0.02, float(frame.get("duration", 0.15)))
		if remaining < seconds or index == frames.size() - 1:
			var pose: Dictionary = frame.pose
			if not frame.get("interpolate", false) or index == frames.size() - 1: return pose
			var next: Dictionary = frames[index + 1].pose
			var result := pose.duplicate(true)
			var fraction := clampf(remaining / seconds, 0.0, 1.0)
			for path in result:
				if not next.has(path): continue
				for field in ["position", "scale", "joint_origin", "pivot_origin", "bow_offset"]:
					if field == "bow_offset" and pose[path].get("bow_hand", "") != next[path].get("bow_hand", ""): continue
					if pose[path].has(field) and next[path].has(field):
						result[path][field] = (pose[path][field] as Vector2).lerp(next[path][field], fraction)
				result[path].rotation = lerp_angle(float(pose[path].rotation), float(next[path].rotation), fraction)
				result[path].skew = lerp_angle(float(pose[path].get("skew", 0.0)), float(next[path].get("skew", 0.0)), fraction)
				if pose[path].has("bow_rotation") and next[path].has("bow_rotation") and pose[path].get("bow_hand", "") == next[path].get("bow_hand", ""):
					result[path].bow_rotation = lerp_angle(float(pose[path].bow_rotation), float(next[path].bow_rotation), fraction)
			return result
		remaining -= seconds
	return frames.back().pose
