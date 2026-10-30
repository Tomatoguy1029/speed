## 本番の時間帯予算・世界更新順・停止・出現待機を比較する。
extends "res://tests/native_forward.gd"
func _ready() -> void:
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("set_attack_budget_mode"):
		check(false,"攻撃予算と世界更新を接続する")
	else:
		for division in [1,3]: await compare_frames(comparison,5,division,true,true,true)
	probe.close()
	print("[native_attack_frame] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
