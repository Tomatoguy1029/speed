## 瓦礫の尾は描画頻度・停止・吹き飛ばしに依存して伸び続けない。
extends SceneTree
const HYDRA := preload("res://scripts/render/bosses/hydra.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func effect(at: Vector2, age: float) -> Dictionary:
	return {"points":PackedVector2Array([at,at+Vector2(0.1,0)]),"age":age,"width":44.0}
func _initialize() -> void:
	var first: Dictionary = HYDRA.rubble_motion(effect(Vector2(500,100),1.0),{})
	check(first.speed==0.0,"初めて見えた瓦礫に原点からの尾を付けない")
	for fps in [15,30,60,120]:
		var dt := 1.0/float(fps)
		var next: Dictionary = HYDRA.rubble_motion(effect(first.at+Vector2(676*dt,0),1.0+dt),first)
		check(is_equal_approx(float(next.speed),676.0),"%d FPSでも同じ速度" % fps)
		var paused: Dictionary = HYDRA.rubble_motion(effect(next.at,next.age),next)
		check(paused==next,"停止中の再描画で尾を伸縮しない")
		var stopped: Dictionary = HYDRA.rubble_motion(effect(next.at,next.age+dt),next)
		check(stopped.speed==0.0,"動かなくなった瓦礫は過去の高速な尾を残さない")
	var knocked: Dictionary = HYDRA.rubble_motion(effect(first.at+Vector2(-1000,0),1.01),first)
	check(float(knocked.speed)*0.42<=352.001,"強い吹き飛ばしでも尾の長さを制限する")
	check(Vector2.from_angle(knocked.angle).dot(Vector2.LEFT)>0.999,"反転した移動方向に尾が追従する")
	var rewound: Dictionary = HYDRA.rubble_motion(effect(first.at,0.1),knocked)
	check(rewound.speed==0.0,"巻き戻し前の位置とつながない")
	print("[hydra_rubble] failed=%d" % failures)
	quit(1 if failures else 0)
