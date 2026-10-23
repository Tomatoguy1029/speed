## シミュレーション単体は開発命令を持たず、開発用の起動経路でだけ足す。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var plain := RunSimulation.new()
	var actors := Node2D.new()
	plain.actor_parent = actors
	plain.options = {"lab": true, "seed": 42, "stage": ContentManager.runtime_stage(1)}
	plain.setup()
	var before := plain.state.time
	plain.command(&"debug_time", {"seconds": 5.0})
	check(plain.state.time == before, "単体のシミュレーションへ開発命令を混ぜない")
	plain.dispose()
	actors.free()
	var packed := load("res://scenes/run/run.tscn") as PackedScene
	var scene := packed.get_state()
	for index in scene.get_node_count():
		check(not String(scene.get_node_name(index)) in ["DebugPanel", "PerfOverlay"], "本番の表示に開発用ノードを置かない")
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.sim.command(&"debug_time", {"seconds": 5.0})
	check(session.sim.state.time == 5.0, "開発用の起動経路では命令が使える")
	session.free()
	await get_tree().process_frame
	print("[development_bootstrap] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
