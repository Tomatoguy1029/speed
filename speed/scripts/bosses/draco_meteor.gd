## 投射した遮蔽は次のブレスまで残す。中断時は飛行中を含めて片付ける。
extends "res://scripts/bosses/draco_breath.gd"
func tick(_a: BossActor,_dt: float) -> void:
	pass
func end(a: BossActor,cancelled: bool) -> void:
	if cancelled:super(a,true)
	else:
		a.placed_meteors=rocks.duplicate()
		MOTION.clear_tell(a)
func recover(_a: BossActor,_dt: float) -> void:
	pass
