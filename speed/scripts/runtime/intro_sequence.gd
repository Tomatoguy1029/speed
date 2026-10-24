## 導入の場面進行。独立した本番セッションを使い、操作の処理は RunSimulation に任せる。
extends RefCounted

enum Beat { FLIGHT, TRANSFORM, HANDOFF, PRACTICE, RESTORE, OMEN, MOTIVE }

signal beat_changed(beat: Beat)
signal completed

var beat := Beat.FLIGHT
var beat_time := 0.0
var presentation: IntroPresentation
var session: RunSession
var run: RunSimulation
var practice := preload("res://scripts/runtime/intro_practice.gd").new()

func setup(parent: Node, visuals: IntroPresentation) -> void:
	presentation = visuals
	var stage := RuntimeStage.new()
	stage.phases = [PhaseDef.new()]
	stage.boss_enabled = false
	session = RunManager.create_session(parent, {"lab": true, "config": _practice_config(),
		"stage": stage, "stage_index": 1, "endless": false, "hud": false,
		"hitstop": SaveManager.settings.hitstop}, true)
	session.auto_step = false
	run = session.sim
	run.heroes.hero = null
	run.ship.invincible = true
	run.state.ship_vel = Vector2(32, 0)
	run.state.ship_heading = Vector2.RIGHT
	practice.setup(run, presentation, run.state.ship_pos)
	run.frame_events.connect(_on_events)

func _practice_config() -> GameConfig:
	var config := ContentManager.cfg.duplicate(true) as GameConfig
	# 障害物と自動出現を外す。移動・描画・突進の本番値は保持する。
	config.planet_radius = 0.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.gravity_interval_min = 1.0e9
	config.gravity_interval_max = 1.0e9
	config.comet_interval_min = 1.0e9
	config.comet_interval_max = 1.0e9
	return config

func advance(delta: float) -> void:
	if run.state.phase == RunState.Phase.PAUSED:
		return
	beat_time += delta
	match beat:
		Beat.FLIGHT:
			run.state.ship_pos += Vector2(32, 0) * delta
			_film_camera(1.35)
			if beat_time >= presentation.flight_time:
				_next(Beat.TRANSFORM)
		Beat.TRANSFORM:
			run.state.ship_vel = Vector2.ZERO
			_film_camera(1.35)
			if beat_time >= presentation.transform_time:
				practice.spawn()
				_next(Beat.HANDOFF)
		Beat.HANDOFF:
			var progress := smoothstep(0.0, presentation.handoff_time, beat_time)
			_film_camera(lerpf(1.35, 1.0, progress))
			practice.approach(progress)
			if beat_time >= presentation.handoff_time:
				practice.build_guide()
				_next(Beat.PRACTICE)
		Beat.PRACTICE:
			run._play_tick(delta)
			practice.update()
		Beat.RESTORE:
			_film_camera(1.0)
			if beat_time >= presentation.restore_time:
				_next(Beat.OMEN)
		Beat.OMEN:
			_film_camera(1.0)
			if beat_time >= presentation.omen_time:
				_next(Beat.MOTIVE)
		Beat.MOTIVE:
			_film_camera(1.0)
			if beat_time >= presentation.motive_time:
				completed.emit()

## 映像中の機体・敵と同じ座標系を保ち、操作へ渡すカメラの状態を更新する。
func _film_camera(multiplier: float) -> void:
	var state := run.state
	state.view_center = state.ship_pos + Vector2(80, -20)
	state.camera_zoom = run._base_zoom() * multiplier
	state.view_half = run._view_size() / 2.0 / state.camera_zoom

func _next(next: Beat) -> void:
	beat = next
	beat_time = 0.0
	beat_changed.emit(next)

func _on_events(events: Array[Dictionary]) -> void:
	for event in events:
		if event.type == &"kill" and practice.record_kill(event) and practice.enemies.is_empty():
			run._reset_finish_input()
			_next(Beat.RESTORE)

func dispose() -> void:
	if run != null and run.frame_events.is_connected(_on_events):
		run.frame_events.disconnect(_on_events)
	practice.dispose()
	run = null
	session = null
