@tool
extends BTAction
@export var settings: HydraTechnique
var started := false
func _generate_name() -> String:
	return "HydraNormal %s" % (settings.technique if settings != null else &"unset")
func _enter() -> void:
	started = false
func _tick(_delta: float) -> Status:
	if settings == null: return FAILURE
	var index := int(blackboard.get_var(&"head_index"))
	if not started:
		started = agent.start_normal(index, settings.technique)
		return RUNNING if started else FAILURE
	return RUNNING if agent.necks[index].mode == settings.technique else SUCCESS

func get_hydra_settings() -> HydraTechnique:
	return settings
