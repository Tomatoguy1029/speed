## 判断の層（Behavior Tree）：攻撃を出せるか（設計書 6.1）。出せるなら SUCCESS。
@tool
extends BTCondition

## 調べる攻撃の名前（役者のタイムラインのアニメーション名）
@export var attack: StringName = &"volley"

func _generate_name() -> String:
	return "AttackReady %s" % attack

func _tick(_delta: float) -> Status:
	return SUCCESS if agent.attack_ready(attack) else FAILURE
