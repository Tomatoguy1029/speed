## 分身の借用技が接触しても、通知と入力の配信を続ける。保存済みの本番ステージを使う。
extends Node
var failures := 0
var polls := 0
var borrowed_hit := false
func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		push_error(label)
	return ok
func input() -> Intent:
	polls += 1
	return Intent.new()
func _ready() -> void:
	var header = JSON.parse_string(FileAccess.get_file_as_string("res://.content/run/stage_5.json"))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(FileAccess.get_file_as_bytes(header.binary),{"api_version":1,"run_id":333,"mode":1,"stage_id":"5","profile":{},"settings":{"hitstop":true}})
	if not check(configured.ok,"本番ステージの生成物を読む"):
		get_tree().quit(1);return
	bridge.start(105,{"position":Vector2(700,0),"lab_mode":true})
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(700,0),"invincible":true}})
	bridge._core.set_motion_context(Vector2(700,0),Vector2(700,0),Vector2(800,450))
	var boss: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	bridge.command("dev_cancel_flow",{"entity_id":boss})
	for tick in 200: bridge._core.step(1.0/120.0)
	var rules = load("res://data/bosses/ai/draco_action_rules.tres")
	var definition := 0
	for i in rules.techniques.size():
		if rules.techniques[i].technique == &"clones": definition = i*3+1
	check(bridge.command("dev_boss_technique",{"entity_id":boss,"definition":definition}).ok,"分身を開始する")
	bridge.subscribe("分身接触の回帰",func(frame):
		for event: Dictionary in frame.events:
			if event.type == &"combat_player_damage" and event.payload.get("borrowed_technique","") == &"bite_thrust":
				borrowed_hit = true
				check(event.payload.borrowed_source == &"hydra" and event.payload.technique == &"clones", "借用元と本体の技を維持する")
		return true)
	for tick in 1800:
		var response: Dictionary = bridge.poll_and_step(1.0/120.0,input,Vector2(1280,720))
		if not check(response.ok and bridge.delivery_error.get("ok",true),"噛みつき後も通知を配信する: "+str(bridge.delivery_error)): break
	check(borrowed_hit,"分身の噛みつき判定が自機へ届く")
	check(polls == 1800,"接触後も毎tick入力を取得する")
	check(bridge.command("pause",{"paused":true}).ok,"接触後もポーズを受理する")
	var paused: Dictionary = bridge.read_frame()
	check(paused.ok,"接触後も画面状態を読み取る")
	if paused.ok: check(paused.value.ui.phase == bridge.Phase.Paused,"ポーズ状態を表示へ届ける")
	check(bridge.command("pause",{"paused":false}).ok,"ポーズを解除する")
	var before: Vector2 = bridge._core.ship_snapshot().ship_pos
	var move := Intent.new()
	move.has_cursor = true
	move.cursor = before+Vector2.DOWN*500.0
	for tick in 120: bridge.step(1.0/120.0,bridge.pack_intent(move),{"logical_size":Vector2(1280,720)})
	check(bridge._core.ship_snapshot().ship_pos.distance_to(before)>1.0,"接触後も移動できる")
	bridge.dispose()
	print("[draco_clone_input] failures=",failures)
	get_tree().quit(1 if failures else 0)
