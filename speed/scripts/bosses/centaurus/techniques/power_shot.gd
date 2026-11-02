## 通常入口を切り替えるまで使う互換Runner。編集値は専用Resourceへ置く。
@tool
extends "res://scripts/data_types/boss_techniques/centaurus/power_shot.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	var locked_origin := Vector2.ZERO
	var locked_angle := 0.0

	func alert(host: CentaurusBoss) -> void:
		if host.mode != &"windup": return
		locked_origin = host.bow_mouth()
		locked_angle = host.table.facing[host.body]
		host.alerting = true
		host._cue(&"alert")

	## 弓の先。矢はここから出る。

	func power_offsets(host: CentaurusBoss) -> Array[float]:
		var r := host.rule()
		var count := maxi(1, int(r.get("count", 1)))
		var offsets: Array[float] = []
		for k in count: offsets.append((float(k) - float(count - 1) * 0.5) * float(r.get("spread", 0.0)))
		return offsets

	func kind() -> StringName:
		return &"power_shot"
