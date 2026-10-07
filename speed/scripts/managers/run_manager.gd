## ランの進行。時計、各 Manager の更新の順番、カメラ、3択、勝敗（設計書 4.3、仕様書 2・13・14）。
##
## ランのシーン（scenes/run/run.tscn）の Managers ノードの子。ステージが終わるとシーンごと消える。
## UI と入力からの働きかけは command() で受け取る。
class_name RunManager
extends Node

signal phase_changed(phase: RunState.Phase)
## 1フレームぶんの出来事。表示・音・UI が受け取る
signal frame_events(events: Array[Dictionary])

@export var world_path: NodePath
@export var input_path: NodePath

var state: RunState
var cfg: GameConfig

@onready var field: FieldManager = $"../FieldManager"
@onready var ship: ShipManager = $"../ShipManager"
@onready var draw: DrawManager = $"../DrawManager"
@onready var combat: CombatManager = $"../CombatManager"
@onready var enemies: EnemyManager = $"../EnemyManager"
@onready var bosses: BossManager = $"../BossManager"
@onready var projectiles: ProjectileManager = $"../ProjectileManager"
@onready var build: BuildManager = $"../BuildManager"
@onready var pickups: PickupManager = $"../PickupManager"
@onready var input: InputRouter = get_node(input_path)

## 敗北・クリアの演出の経過時間（実秒）
var sequence_t := 0.0
## ボスへのトドメの直前の機体の位置の記録（スローの再生に使う。仕様書 14）
var approach: Array[Vector2] = []
var finish_replay: Array[Vector2] = []
var _cam_ready := false

func _ready() -> void:
	cfg = ConfigManager.cfg
	state = RunState.new()
	state.stage_index = GameManager.run_stage
	state.endless = GameManager.run_endless
	state.stage = ConfigManager.stage(state.stage_index)
	state.rng.randomize()
	state.hitstop_budget = cfg.kill_hitstop_cap
	_wire()
	# 能力値を先に計算してから機体を置く
	for m: RunSystem in [field, build, ship, draw, combat, enemies, bosses, projectiles, pickups]:
		m.setup(state, cfg)
	build.cards_opened.connect(func(_c): set_phase(RunState.Phase.LEVELUP))
	_update_camera(1.0)

## ほかの Manager への参照を渡す。依存の向きはここで一覧できる（設計書 4.4 の決まり2）。
func _wire() -> void:
	ship.field = field
	ship.combat = combat
	ship.build = build
	draw.field = field
	draw.combat = combat
	draw.build = build
	draw.ship = ship
	combat.enemies = enemies
	combat.ship = ship
	combat.build = build
	combat.pickups = pickups
	combat.projectiles = projectiles
	combat.field = field
	combat.bosses = bosses
	enemies.field = field
	enemies.projectiles = projectiles
	enemies.bosses = bosses
	bosses.enemies = enemies
	bosses.projectiles = projectiles
	bosses.field = field
	bosses.actor_parent = get_node(world_path)
	projectiles.field = field
	projectiles.combat = combat
	projectiles.ship = ship
	projectiles.build = build
	build.combat = combat
	build.projectiles = projectiles
	build.ship = ship
	build.enemies = enemies
	build.pickups = pickups
	build.field = field
	pickups.field = field
	pickups.ship = ship
	pickups.build = build
	pickups.enemies = enemies

# ── 更新 ──────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	match state.phase:
		RunState.Phase.PLAY:
			_play_tick(delta)
		RunState.Phase.DYING:
			_dying_tick(delta)
		RunState.Phase.FINISHING:
			_finishing_tick(delta)

## 更新の順番（設計書 4.3）。
func _play_tick(real_dt: float) -> void:
	var it := input.poll()
	input.drawing = state.drawing
	ship.intent = it
	draw.intent = it
	draw.handle_input()
	if state.hitstop > 0.0:
		state.hitstop -= real_dt
		return
	combat.tick(real_dt, 0.0)
	draw.tick(real_dt, 0.0)
	if state.phase != RunState.Phase.PLAY:
		return
	state.world_scale = draw.world_scale()
	var world_dt := real_dt * state.world_scale
	state.time += real_dt
	state.world_time += world_dt
	field.tick(real_dt, world_dt)
	enemies.tick(real_dt, world_dt)
	bosses.tick(real_dt, world_dt)
	combat.rebuild_grid()
	ship.tick(real_dt, world_dt)
	if state.phase == RunState.Phase.PLAY:
		build.tick(real_dt, world_dt)
	if state.phase == RunState.Phase.PLAY:
		projectiles.tick(real_dt, world_dt)
	enemies.cleanup()
	enemies.spawner_tick(real_dt, world_dt)
	pickups.tick(real_dt, world_dt)
	_record_approach()
	_update_camera(real_dt)
	_check_end()
	if state.phase == RunState.Phase.PLAY:
		build.try_open_cards()

func _process(_delta: float) -> void:
	if state.events.is_empty():
		return
	var events := state.events
	state.events = []
	frame_events.emit(events)

func _check_end() -> void:
	if state.phase != RunState.Phase.PLAY:
		return
	if state.ship_hp <= 0.0:
		_begin_death()
	elif state.boss_dead:
		_begin_finish()
	elif state.time >= cfg.run_time and not state.endless:
		finish(false)

func set_phase(phase: RunState.Phase) -> void:
	if state.phase == phase:
		return
	state.phase = phase
	phase_changed.emit(phase)

# ── カメラ（仕様書 13） ──────────────────────────────────────────

func _update_camera(real_dt: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var f := pow(cfg.zoom_ref_speed / maxf(cfg.zoom_ref_speed, state.stats.max_speed), cfg.zoom_exp)
	var zoom_t := minf(size.x, size.y) / cfg.base_view * clampf(f, cfg.zoom_min, 1.0)
	if not _cam_ready:
		state.view_center = state.ship_pos
		state.camera_zoom = zoom_t
		_cam_ready = true
	state.camera_locked = state.drawing or state.tracing
	if not state.camera_locked:
		var off := state.ship_vel * cfg.look_ahead
		var max_off := 0.3 * minf(size.x, size.y) / 2.0 / zoom_t
		if off.length() > max_off:
			off = off.normalized() * max_off
		var target := state.ship_pos + off
		state.view_center += (target - state.view_center) * (1.0 - exp(-7.0 * real_dt))
		state.camera_zoom += (zoom_t - state.camera_zoom) * (1.0 - exp(-2.2 * real_dt))
	state.view_half = size / 2.0 / state.camera_zoom

# ── 3択（仕様書 7.2） ─────────────────────────────────────────────

func choose_card(index: int) -> void:
	if state.phase != RunState.Phase.LEVELUP:
		return
	if not build.choose_card(index):
		set_phase(RunState.Phase.PLAY)

# ── 敗北（仕様書 14） ─────────────────────────────────────────────

func _begin_death() -> void:
	sequence_t = 0.0
	state.emit(&"ship_death", {"pos": state.ship_pos})
	set_phase(RunState.Phase.DYING)

func _dying_tick(real_dt: float) -> void:
	sequence_t += real_dt
	var t1 := cfg.death_freeze_time
	var t2 := t1 + cfg.death_explosion_time
	var t3 := t2 + cfg.death_game_over_time
	if sequence_t >= t1 and sequence_t - real_dt < t1:
		state.emit(&"ship_explode", {"pos": state.ship_pos})
	if sequence_t >= t2 and sequence_t - real_dt < t2:
		state.emit(&"game_over")
	if sequence_t >= t3:
		finish(false)

# ── クリア（仕様書 14） ───────────────────────────────────────────

func _record_approach() -> void:
	if not state.boss_spawned:
		return
	approach.append(state.ship_pos)
	var keep := int(cfg.boss_finish_replay_window * Engine.physics_ticks_per_second) + 1
	while approach.size() > keep:
		approach.remove_at(0)

func _begin_finish() -> void:
	sequence_t = 0.0
	finish_replay = approach.duplicate()
	state.emit(&"boss_finish", {"pos": bosses.boss.pos if bosses.boss != null else state.ship_pos})
	set_phase(RunState.Phase.FINISHING)

## スロー再生 → 爆発で一掃 → 破片が消える → CLEAR! → 結果画面。
func _finishing_tick(real_dt: float) -> void:
	sequence_t += real_dt
	var t1 := cfg.boss_finish_slow_time
	var t2 := t1 + cfg.boss_finish_blast_time
	var t3 := t2 + cfg.boss_finish_clear_time
	if sequence_t < t1 and not finish_replay.is_empty():
		var k := clampf(sequence_t / t1, 0.0, 1.0)
		var idx := k * (finish_replay.size() - 1)
		var i0 := int(idx)
		var i1 := mini(i0 + 1, finish_replay.size() - 1)
		state.ship_pos = finish_replay[i0].lerp(finish_replay[i1], idx - i0)
	if sequence_t >= t1 and sequence_t - real_dt < t1:
		var center := bosses.boss.pos if bosses.boss != null else state.ship_pos
		state.emit(&"boss_explode", {"pos": center})
		for e: Enemy in enemies.list:
			if not e.dead and not e.is_boss:
				e.dead = true
				state.emit(&"kill", {"pos": e.pos, "r": e.r, "type": e.type, "cause": &"finale", "dir": (e.pos - center).normalized(), "color": e.color, "silent": true})
		projectiles.clear_hostile()
		bosses.remove_boss()
		enemies.cleanup()
	if sequence_t >= t2 and sequence_t - real_dt < t2:
		state.emit(&"clear_banner")
	if sequence_t >= t3:
		finish(true)

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
		&"choose_card":
			choose_card(args.get("index", 0))
		&"pause":
			if state.phase == RunState.Phase.PLAY:
				set_phase(RunState.Phase.PAUSED)
		&"resume":
			if state.phase == RunState.Phase.PAUSED:
				set_phase(RunState.Phase.PLAY)
		&"abort":
			set_phase(RunState.Phase.ENDED)
			GameManager.abort_run()
		&"draw_button":
			input.press_draw_button()
		&"debug_clear":
			finish(true)
		&"debug_fail":
			finish(false)
