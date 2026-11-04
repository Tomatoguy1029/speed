## ほうおう座の着地の炎。判定の寿命と独立した、ドット単位の爆発で描く。表示時間は爆発の調整値から決まる。
## 着地前の影・予告の輪・降る火の粉は、敵の表示（render/enemies/phoenix.gd）が描く。
extends AttackVisual
const KEY := "enemy/phoenix"
const BLAST_BURSTS := preload("res://scripts/render/fx/blast_bursts.gd")
const TUNED_SHADERS := [preload("res://shaders/blast_burst.gdshader")]
var _blasts: BlastBursts
var _seen: Dictionary = {}
var _world_time := 0.0

func _exit_tree() -> void:
	if is_instance_valid(_blasts): _blasts.queue_free()
