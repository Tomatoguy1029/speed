## ランの進行。時計、各 Manager の更新の順番、勝敗（設計書 4.3、仕様書 2）。
##
## ランのシーン（scenes/run/run.tscn）の Managers ノードの子。ステージが終わるとシーンごと消える。
## UI と入力からの働きかけは command() で受け取る。
class_name RunManager
extends Node

signal phase_changed(phase: RunState.Phase)
## 1フレームぶんの出来事。表示・音・UI が受け取る
signal frame_events(events: Array[Dictionary])

var state: RunState
var cfg: GameConfig

func _ready() -> void:
	cfg = ConfigManager.cfg
	state = RunState.new()
	state.stage_index = GameManager.run_stage
	state.endless = GameManager.run_endless
	state.stage = ConfigManager.stage(state.stage_index)
	state.rng.randomize()
	_wire()
	for m in _systems():
		m.setup(state, cfg)

## ほかの Manager への参照を渡す。依存の向きはここで一覧できる（設計書 4.4 の決まり2）。
func _wire() -> void:
	pass

## 更新の順番（設計書 4.3）。
func _systems() -> Array[RunSystem]:
	var list: Array[RunSystem] = []
	return list

func _physics_process(delta: float) -> void:
	if state.phase != RunState.Phase.PLAY:
		return
	state.time += delta
	var world_dt := delta * state.world_scale
	state.world_time += world_dt
	for m in _systems():
		m.tick(delta, world_dt)
	_check_end()

func _process(_delta: float) -> void:
	if state.events.is_empty():
		return
	var events := state.events
	state.events = []
	frame_events.emit(events)

func _check_end() -> void:
	if state.time >= cfg.run_time and not state.endless:
		finish(false)

func set_phase(phase: RunState.Phase) -> void:
	state.phase = phase
	phase_changed.emit(phase)

## ランを終えて結果画面へ。
func finish(cleared: bool) -> void:
	if state.phase == RunState.Phase.ENDED:
		return
	state.cleared = cleared
	set_phase(RunState.Phase.ENDED)
	var coins := state.coins + (cfg.clear_bonus if cleared else 0)
	GameManager.finish_run({
		"stage": state.stage_index,
		"endless": state.endless,
		"cleared": cleared,
		"time": state.time,
		"kills": state.kills,
		"level": state.level,
		"coins": coins,
		"peak_speed": state.peak_speed,
		"modules": state.modules_obtained.map(func(id): return String(id)),
		"legendary": String(state.stage.legendary_module_id) if cleared and state.stage != null else "",
	})

## UI と入力からの命令（設計書 4.3）。
func command(name: StringName, args := {}) -> void:
	match name:
		&"debug_clear":
			finish(true)
		&"debug_fail":
			finish(false)
		&"abort":
			set_phase(RunState.Phase.ENDED)
			GameManager.abort_run()
