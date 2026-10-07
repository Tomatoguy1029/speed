## 段階1の確認用：ランを「クリア扱い」「失敗扱い」で終える。開発版だけに出す（調整パネルができたら置き換える）。
extends Control

@export var run_path: NodePath

func _ready() -> void:
	visible = OS.is_debug_build()
	var run := get_node(run_path) as RunManager
	%ClearButton.pressed.connect(func(): run.command(&"debug_clear"))
	%FailButton.pressed.connect(func(): run.command(&"debug_fail"))

func _process(_delta: float) -> void:
	var run := get_node(run_path) as RunManager
	%Info.text = "ステージ %d　%.1f 秒" % [run.state.stage_index, run.state.time]
