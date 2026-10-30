## 噛みつく敵を、射撃・予算・描線・間引きを含む本番更新順で比較する。
extends "res://tests/native_forward.gd"
func _ready() -> void:
	var comparison = COMPARE.new()
	for division in [1,3]: await compare_frames(comparison,1,division,false,true,true,&"biter")
	print("[native_biter] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
