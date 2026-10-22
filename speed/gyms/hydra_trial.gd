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
	# 読み込み・描画確認用。通常起動の試遊条件を共有設定へ保存しない。
	if OS.get_cmdline_user_args().has("--hydra-split"):
		var hydra=session.run.bosses.lab_instances.back().actor
		hydra._set_count(8)
		hydra.begin_separation()
	if OS.get_cmdline_user_args().has("--hydra-inspect"):
		session.pinned=trial_ship_position
	_set_mode(3)
	_refresh()

func _notification(what: int)->void:
	if OS.get_cmdline_user_args().has("--hydra-inspect") and what==NOTIFICATION_APPLICATION_FOCUS_OUT:return
	super._notification(what)
