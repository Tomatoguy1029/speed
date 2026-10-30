## 石化した盾への通常接触・体当たり・弾・破片を比較する。
extends "res://tests/native_shield.gd"
func _ready() -> void:
	var comparison = COMPARE.new()
	for mode in ["front_touch","front_ram","rear_ram","front_shots","back_shots","front_debris"]:
		await compare_hits(comparison,mode,true)
	print("[native_stone_combat] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
