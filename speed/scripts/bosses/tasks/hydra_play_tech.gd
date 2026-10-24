## Settings が技別数値の正本。条件とCDは開始時だけ評価する。
@tool
extends BTAction
@export var settings: HydraTechnique
var _started := false
func _generate_name() -> String:
	return "HydraTechnique %s" % (settings.technique if settings != null else &"unset")
func _enter() -> void:
	_started = false
func _tick(_delta: float) -> Status:
	if settings == null: return FAILURE
	var id := settings.technique
	if not _started:
		_started = agent.try_start_tech(id, 1.0)
		return RUNNING if _started else FAILURE
	if agent.tech == id: return RUNNING
	return SUCCESS if agent.last_tech == id and agent.last_tech_result == &"finished" else FAILURE
func _exit() -> void:
	if _started and settings != null: agent.interrupt_tech(settings.technique)

func get_hydra_settings() -> HydraTechnique:
	return settings
