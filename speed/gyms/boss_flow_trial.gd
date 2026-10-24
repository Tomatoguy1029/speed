extends "res://gyms/hydra_trial.gd"

func _ready() -> void:
	await super._ready()
	var actor = session.run.bosses.actors.back()
	actor.hsm.set_active(false)
	var program = load("res://.content/boss_preview.tres")
	if program == null: return
	for move in program.data.techniques:
		actor._moves[move.technique] = move
		for index in actor.necks.size():
			if actor.necks[index].kind == move.head_kind:
				actor.necks[index].cd = 0.0
				actor.start_normal(index, move.technique)
				break
