## Hydra を置いた試遊用の実験場。共有ステージ・セーブ・本番の強さを変更しない。
extends "res://gyms/enemy_lab/enemy_lab.gd"

@export var trial_ship_position := Vector2(400, 0)
@export_range(1.0, 20.0) var trial_attack_multiplier := 6.0
@export var trial_invincible := true

func _ready() -> void:
	await super._ready()
	if not OS.is_debug_build(): return
	await session.reset({"empty": true, "stage": 4, "ship_pos": [trial_ship_position.x, trial_ship_position.y],
		"invincible": trial_invincible, "hero": "hercules", "config": {"base_attack": ConfigManager.base.base_attack * trial_attack_multiplier}})
	session.perform("boss", {"type": "hydra", "pos": [0, 0]})
	_set_mode(3)
	_refresh()
