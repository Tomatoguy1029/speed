## 選択後だけ攻撃枠を要求し、指定した技を実行する。中断は待機と実行の両方を片付ける。
@tool
extends BTAction
@export var technique := "north"
## 基準時間は BossDef.params.tech_cd。技ごとにこの倍率を調整する。
@export_range(0.0, 10.0) var cooldown_scale := 1.0
var _started := false
func _generate_name() -> String:
	return "HydraTechnique %s" % technique
func _enter() -> void:
	_started = false
func _tick(_delta: float) -> Status:
	var id := StringName(technique)
	if not _started:
		if not agent.attack_ready(id): return FAILURE
		_started = agent.try_start_tech(id, cooldown_scale)
		return RUNNING
	if agent.tech == id: return RUNNING
	return SUCCESS if agent.last_tech == id and agent.last_tech_result == &"finished" else FAILURE
func _exit() -> void:
	agent.interrupt_tech(StringName(technique))
