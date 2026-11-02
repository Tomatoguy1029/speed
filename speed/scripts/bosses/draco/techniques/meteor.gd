## 旧通常入口で使う隕石投射Runner。値は編集用Resourceへ分離する。
extends "res://scripts/data_types/boss_techniques/draco/meteor.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/draco/techniques/breath.gd".Runner:
	func kind() -> StringName: return &"meteor"

	func tick(_a: BossActor,_dt: float) -> void:
		pass
	func end(a: BossActor,cancelled: bool) -> void:
		if cancelled:super(a,true)
		else:
			a.placed_meteors=rocks.duplicate()
			MOTION.clear_tell(a)
	func recover(_a: BossActor,_dt: float) -> void:
		pass

	func is_meteor() -> bool:
		return true
