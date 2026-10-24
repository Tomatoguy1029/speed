extends "res://gyms/hydra_trial.gd"

func _ready() -> void:
	await super._ready()
	var actor = session.run.bosses.actors.back()
	actor.hsm.set_active(false)
	var program = load("res://.content/boss_preview.tres")
	if program == null: return
	actor.configure_flow(program)
