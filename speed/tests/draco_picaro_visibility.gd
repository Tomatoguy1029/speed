## 独立して描くピカロの表示も、カットシーンの非表示・復帰に従う。
extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":5405,"hud":false},true)
	session.auto_step = false
	var sim := session.sim
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor = sim.bosses.actor
	var row: int = actor.picaro.spawn_picaro(&"biter",Vector2(300,100))
	var id: int = sim.enemies.table.id[row]
	var presentation = session.view.get_node("RunPresentation")
	presentation._sync_picaro()
	check(presentation._picaro_sprites.has(id),"Picaro has independent rendering node")
	var sprite: Node2D = presentation._picaro_sprites[id]
	check(sprite.visible,"Picaro visible during normal combat")
	sim.state.cinematic_hide_enemies = true
	presentation._sync_picaro()
	check(not sprite.visible,"Cinematic hides independent Picaro sprite too")
	check(sim.enemies.is_same(row,id) and sim.enemies.table.dead[row]==0,"Hiding keeps existing protected enemy alive")
	sim.state.cinematic_hide_enemies = false
	presentation._sync_picaro()
	check(sprite.visible,"Leaving cinematic restores existing Picaro sprite")
	actor.finale.begin()
	presentation._sync_picaro()
	check(not sprite.visible,"Finale hides existing Picaro sprite")
	actor.finale.dispose()
	presentation._sync_picaro()
	check(sprite.visible,"Interrupted finale restores prior Picaro visibility")
	session.free()
	print("[draco_picaro_visibility] failures=",failures)
	get_tree().quit(1 if failures>0 else 0)
