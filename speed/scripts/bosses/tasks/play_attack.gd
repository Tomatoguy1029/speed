## 判断の層（Behavior Tree）：攻撃の振り付け（タイムライン）を再生し、終わるまで待つ（設計書 6.1）。
@tool
extends BTAction

## 再生する攻撃の名前（役者のタイムラインのアニメーション名）
@export var attack: StringName = &"volley"

func _generate_name() -> String:
	return "PlayAttack %s" % attack

func _enter() -> void:
	agent.start_attack(attack)

func _tick(_delta: float) -> Status:
	return RUNNING if agent.attack_playing() else SUCCESS
