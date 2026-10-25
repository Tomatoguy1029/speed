extends "res://scripts/bosses/draco_breath.gd"
func tick(_a: BossActor, _dt: float) -> void:
	pass
func end(a: BossActor, cancelled: bool) -> void:
	if cancelled: super(a,true)
	else: a.placed_meteors = rocks.duplicate()
