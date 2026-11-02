## 通常入口を切り替えるまで使う互換Runner。編集値は専用Resourceへ置く。
@tool
extends "res://scripts/data_types/boss_techniques/centaurus/volley.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	pass

	func kind() -> StringName:
		return &"volley"
