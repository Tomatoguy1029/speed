## ランの進行。時計、各 Manager の更新の順番、カメラ、3択、勝敗（設計書 4.3、仕様書 4・15・16）。
##
## ランのシーン（scenes/run/run.tscn）の Managers ノードの子。ステージが終わるとシーンごと消える。
## UI と入力からの働きかけは command() で受け取る。
class_name RunManager
extends Node

signal phase_changed(phase: RunState.Phase)
## 3択のカードが新しくなった（開いた・次の3択・引き直し）
signal cards_changed
## 1フレームぶんの出来事。表示・音・UI が受け取る
signal frame_events(events: Array[Dictionary])

@export var world_path: NodePath
@export var input_path: NodePath

var state: RunState
var cfg: GameConfig
## シーンをツリーへ追加する前に渡す。共有の本番設定を書き換えず実験を起動する。
var options: Dictionary = {}
var input_source: Callable
var encounters
const ENCOUNTERS := preload("res://scripts/encounters/encounter_coordinator.gd")
const DIRECTOR := preload("res://scripts/encounters/attack_director.gd")

@onready var field: FieldManager = $"../FieldManager"
@onready var ship: ShipManager = $"../ShipManager"
@onready var draw: DrawManager = $"../DrawManager"
@onready var combat: CombatManager = $"../CombatManager"
@onready var enemies: EnemyManager = $"../EnemyManager"
@onready var bosses: BossManager = $"../BossManager"
@onready var projectiles: ProjectileManager = $"../ProjectileManager"
@onready var build: BuildManager = $"../BuildManager"
@onready var pickups: PickupManager = $"../PickupManager"
@onready var heroes: HeroManager = $"../HeroManager"
@onready var input: InputRouter = get_node(input_path)

## 敗北・クリアの演出の経過時間（実秒）
var sequence_t := 0.0
## ボスへのトドメの直前の機体の位置の記録（スローの再生に使う。仕様書 16）
var approach: Array[Vector2] = []
var finish_replay: Array[Vector2] = []
var _cam_ready := false
## 次の世界側の更新までにたまった時間と回数（config.world_tick_div）
var _world_real_dt := 0.0
var _world_dt := 0.0
var _world_steps := 0
## 開発版の計測：処理時間の合計（マイクロ秒）・回数・最大時間。
## play_total は全体の包含時間なので、個別の項目と合算しない。
var profile: Dictionary = {}
var profiling := false

func _ready() -> void:
	if not OS.is_debug_build():
		options = {}
	cfg = options.get("config", ConfigManager.cfg)
	state = RunState.new()
	state.lab_mode = bool(options.get("lab", false))
	state.meta_override = options.get("meta", {})
	state.stage_index = int(options.get("stage_index", GameManager.run_stage))
	state.endless = bool(options.get("endless", GameManager.run_endless))
	state.stage = options.get("stage", ConfigManager.stage(state.stage_index))
	if OS.is_debug_build() and not state.lab_mode:
		state.time = GameManager.run_start_time
	GameManager.run_start_time = 0.0
	if options.has("seed"):
		state.rng.seed = int(options.seed)
	else:
		state.rng.randomize()
	state.hitstop_budget = cfg.kill_hitstop_cap
	_read_settings()
	SaveManager.settings_changed.connect(_read_settings)
	_wire()
	enemies.definitions = options.get("enemies", {})
	# 能力値を先に計算してから機体を置く
	for m: RunSystem in [field, build, ship, draw, combat, enemies, bosses, projectiles, pickups, heroes]:
		m.setup(state, cfg)
	if not state.lab_mode and state.stage.encounter_profile.get("enabled", false):
		encounters = ENCOUNTERS.new()
		add_child(encounters)
		encounters.setup(self, state.stage.encounter_profile)
	if not state.lab_mode and projectiles.director == null:
		# 強敵の攻撃の管理（時間帯の予算と群れごとの value で動く。仕様書 11.7）
		var director = DIRECTOR.new()
		director.state = state
		director.projectiles = projectiles
		director.formation_mode = true
		director.configure({"enabled": true, "budget": maxi(0, enemies.current_phase().attack_budget), "jitter": 0.0})
		projectiles.director = director
	if not state.lab_mode:
		enemies._sync_attack_budget(enemies.current_phase())
	build.cards_opened.connect(func(_c):
		set_phase(RunState.Phase.LEVELUP)
		cards_changed.emit())
	_update_camera(1.0)
	# 最初の武器を選ぶ。HUD がつながってから開く
	if not state.lab_mode:
		build.open_start_cards.call_deferred()

## ほかの Manager への参照を渡す。依存の向きはここで一覧できる（設計書 4.4 の決まり2）。
func _wire() -> void:
	field.enemies = enemies
	heroes.enemies = enemies
	heroes.field = field
	heroes.combat = combat
	heroes.projectiles = projectiles
	field.projectiles = projectiles
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
	if state.lab_mode:
		return
	match state.phase:
		RunState.Phase.PLAY:
			if profiling:
				_run(&"play_total", func(): _play_tick(delta))
			else:
				_play_tick(delta)
		RunState.Phase.DYING:
			_dying_tick(delta)
		RunState.Phase.FINISHING:
			_finishing_tick(delta)

## 設定のうちランに効くもの（ポーズ中に変えるとすぐ反映）。
func _read_settings() -> void:
	state.hitstop_enabled = bool(options.get("hitstop", true)) if state.lab_mode else bool(SaveManager.settings.hitstop)

## 更新の順番（設計書 4.3）。
## ワープホールからボーナスステージに入る：周りの敵と敵の攻撃を消し、雑魚と硬めの敵を多く出す（仕様書 13.1）。
func _enter_bonus() -> void:
	state.bonus_t = cfg.bonus_time
	state.gauge = 1.0
	enemies.clear_regular()
	projectiles.clear_hostile()
	state.emit(&"bonus", {"enter": true, "pos": state.ship_pos})

## ボーナスステージから戻る：ボーナスステージの敵と敵の攻撃を消し、通常の出現に戻る。
func _leave_bonus() -> void:
	state.bonus_t = 0.0
	enemies.clear_regular()
	projectiles.clear_hostile()
	state.emit(&"bonus", {"enter": false, "pos": state.ship_pos})

func _play_tick(real_dt: float) -> void:
	state.sim_time += real_dt
	var it: Intent = input_source.call() if input_source.is_valid() else input.poll()
	input.drawing = state.drawing
	ship.intent = it
	draw.intent = it
	draw.handle_input()
	if state.hitstop > 0.0:
		state.hitstop -= real_dt
		return
	if profiling:
		_run(&"combat", func(): combat.tick(real_dt, 0.0))
		_run(&"draw", func(): draw.tick(real_dt, 0.0))
	else:
		combat.tick(real_dt, 0.0)
		draw.tick(real_dt, 0.0)
	if state.phase != RunState.Phase.PLAY:
		return
	state.world_scale = draw.world_scale()
	var world_dt := real_dt * state.world_scale
	if state.bonus_t > 0.0:
		# ボーナスステージの間は、ランの時計が止まる
		state.bonus_t -= real_dt
		if state.bonus_t <= 0.0:
			_leave_bonus()
	else:
		state.time += real_dt
	if not state.lab_mode and not state.endless and not state.time_limit_reached \
			and state.stage.time_limit >= 0.0 and state.time >= state.stage.time_limit:
		state.time_limit_reached = true
		state.emit(&"time_limit_reached", {"t": state.time})
	state.world_time += world_dt
	# 世界側は config.world_tick_div 回に1回、たまった時間でまとめて進める
	_world_real_dt += real_dt
	_world_dt += world_dt
	_world_steps += 1
	var world_step := _world_steps >= maxi(1, cfg.world_tick_div)
	var wr := _world_real_dt
	var wd := _world_dt
	if world_step:
		_world_real_dt = 0.0
		_world_dt = 0.0
		_world_steps = 0
		enemies._sync_attack_budget(enemies.current_phase())
		if encounters != null:
			encounters.before_world()
		elif not state.lab_mode and projectiles.director != null:
			projectiles.director.advance(state.world_time, enemies)
		_run(&"field", func(): field.tick(wr, wd))
		_run(&"enemies", func(): enemies.tick(wr, wd))
		_run(&"bosses", func(): bosses.tick(wr, wd))
		_run(&"grid", func(): combat.rebuild_grid())
	_run(&"ship", func(): ship.tick(real_dt, world_dt))
	if it.hero_press:
		heroes.activate()
	_run(&"heroes", func(): heroes.tick(real_dt, world_dt))
	if state.phase == RunState.Phase.PLAY:
		_run(&"build", func(): build.tick(real_dt, world_dt))
	if world_step and state.phase == RunState.Phase.PLAY:
		_run(&"projectiles", func(): projectiles.tick(wr, wd))
	_run(&"cleanup", func(): enemies.cleanup())
	if world_step:
		if encounters != null:
			encounters.advance()
		if (not state.lab_mode or options.get("auto_spawn", false)) and (projectiles.director == null or not projectiles.director.guard_active()):
			_run(&"spawner", func(): enemies.spawner_tick(wr, wd))
		_run(&"pickups", func(): pickups.tick(wr, wd))
	_record_approach()
	if state.phase == RunState.Phase.PLAY and state.bonus_t <= 0.0 and field.take_warp():
		_enter_bonus()
	_update_camera(real_dt)
	_check_end()
	if state.phase == RunState.Phase.PLAY and not state.lab_mode:
		build.try_open_cards()

## 処理を呼ぶ。計測中なら時間を測る。
func _run(key: StringName, f: Callable) -> void:
	if not profiling:
		f.call()
		return
	var t0 := Time.get_ticks_usec()
	f.call()
	var elapsed := Time.get_ticks_usec() - t0
	var rec: Array = profile.get(key, [0, 0, 0])
	rec[0] += elapsed
	rec[1] += 1
	rec[2] = maxi(rec[2], elapsed)
	profile[key] = rec

func _process(_delta: float) -> void:
	if state.events.is_empty():
		return
	var events := state.events
	state.events = []
	frame_events.emit(events)

func _check_end() -> void:
	if state.lab_mode:
		return
	if state.phase != RunState.Phase.PLAY:
		return
	if state.ship_hp <= 0.0:
		_begin_death()
	elif state.boss_dead:
		_begin_finish()

func set_phase(phase: RunState.Phase) -> void:
	if state.phase == phase:
		return
	state.phase = phase
	phase_changed.emit(phase)

# ── カメラ（仕様書 15） ──────────────────────────────────────────

func _base_zoom() -> float:
	var size := _view_size()
	var f := pow(cfg.zoom_ref_speed / maxf(cfg.zoom_ref_speed, state.stats.max_speed), cfg.zoom_exp)
	return minf(size.x, size.y) / cfg.base_view * clampf(f, cfg.zoom_min, 1.0)

func _view_size() -> Vector2:
	return options.get("view_size", get_viewport().get_visible_rect().size)

func _update_camera(real_dt: float) -> void:
	var size := _view_size()
	var zoom_t := _base_zoom()
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

# ── 3択（仕様書 9.2） ─────────────────────────────────────────────

func choose_card(index: int) -> void:
	if state.phase != RunState.Phase.LEVELUP:
		return
	if not build.choose_card(index):
		set_phase(RunState.Phase.PLAY)

# ── 敗北（仕様書 16） ─────────────────────────────────────────────

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

# ── クリア（仕様書 16） ───────────────────────────────────────────

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
	state.emit(&"boss_finish", {"pos": bosses.boss_pos(state.ship_pos)})
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
	# トドメの間は機体に寄る（3.2倍）。爆発からは元のズームへ戻す
	var follow := 1.0 - exp(-10.0 * real_dt)
	var zoom_to := _base_zoom() * (cfg.boss_finish_zoom if sequence_t < t1 else 1.0)
	state.view_center += (state.ship_pos - state.view_center) * follow
	state.camera_zoom += (zoom_to - state.camera_zoom) * follow
	state.view_half = get_viewport().get_visible_rect().size / 2.0 / state.camera_zoom
	if sequence_t >= t1 and sequence_t - real_dt < t1:
		var center := bosses.boss_pos(state.ship_pos)
		state.emit(&"boss_explode", {"pos": center})
		var t := enemies.table
		for i in t.alive.size():
			if t.alive[i] != 0 and t.dead[i] == 0 and t.is_boss[i] == 0:
				enemies.mark_dead(i)
				state.emit(&"kill", {"pos": t.pos[i], "r": t.r[i], "type": t.type[i], "cause": &"finale", "dir": (t.pos[i] - center).normalized(), "color": t.color[i], "silent": true})
		projectiles.clear_hostile()
		bosses.remove_boss()
		enemies.cleanup()
	if sequence_t >= t2 and sequence_t - real_dt < t2:
		state.emit(&"clear_banner")
	if sequence_t >= t3:
		finish(true)

## ランを終えて結果画面へ。
func finish(cleared: bool) -> void:
	if state.lab_mode:
		state.emit(&"lab_result", {"cleared": cleared})
		return
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
		&"reroll":
			if state.phase == RunState.Phase.LEVELUP:
				build.reroll_cards()
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
		&"debug_time":
			state.time += float(args.get("seconds", 30.0))
		&"debug_hazards":
			# 敵の攻撃の形を機体の周りに出して見る
			var p := state.ship_pos
			var a := state.rng.randf() * TAU
			projectiles.fire_beam(p + Vector2.from_angle(a) * 420.0, a + PI, 900.0, 26.0, 0.8, 0.35, 10.0)
			projectiles.fire_cross(p + Vector2.from_angle(a + 2.0) * 260.0, 0.0, 700.0, 18.0, 0.9, 0.3, 10.0)
			projectiles.fire_zone(p + Vector2.from_angle(a + 4.0) * 160.0, 90.0, 1.0, 10.0,
				ProjectileManager.HazardStyle.RETICLE)
			projectiles.fire_zone(p, 70.0, 1.2, 10.0, ProjectileManager.HazardStyle.LIGHTNING, Color("#ffe46b"))
			projectiles.fire_zone(p + Vector2.from_angle(a + 1.0) * 220.0, 110.0, 0.6, 10.0)
			projectiles.fire_wave(p + Vector2.from_angle(a + 3.0) * 300.0, a, 0.5, 500.0, 420.0, 18.0, 0.5, 10.0)
			projectiles.fire_rings(p + Vector2.from_angle(a + 5.0) * 350.0, 4, 0.35, 700.0, 380.0, 16.0, 0.6, 10.0,
				a, 0.35, 0.6)
			projectiles.fire_wall(p + Vector2.from_angle(a + 0.5) * 200.0, a + PI / 2.0, 500.0, 16.0, 0.5, 3.0, 10.0)
		&"debug_boss_time":
			state.time = maxf(state.time, state.boss_at - 1.0)
		&"debug_kill_boss":
			if bosses.boss_alive():
				bosses.on_boss_defeated(bosses.boss_row, {"cause": &"debug"})
		&"debug_grant":
			build.grant(args.get("kind", &"weapon"), args.get("id", &"W01"), int(args.get("levels", 1)))
		&"debug_reset_loadout":
			build.reset_loadout()
		&"debug_level_up":
			build.add_xp(build.xp_needed() - state.xp + 0.01)
		&"debug_gauge_full":
			state.gauge = 1.0
		&"debug_heal":
			ship.heal(state.stats.max_hp)
		&"debug_invincible":
			ship.invincible = not ship.invincible
		&"debug_clear_enemies":
			var t := enemies.table
			for i in t.alive.size():
				if t.alive[i] != 0 and t.is_boss[i] == 0:
					enemies.mark_dead(i)
		&"debug_gravity":
			if OS.is_debug_build() and state.phase in [RunState.Phase.PLAY, RunState.Phase.PAUSED, RunState.Phase.LEVELUP]:
				field.spawn_well()
		&"debug_warp":
			if OS.is_debug_build() and state.phase in [RunState.Phase.PLAY, RunState.Phase.PAUSED, RunState.Phase.LEVELUP]:
				field.spawn_warp()
		&"debug_comet":
			if OS.is_debug_build() and state.phase in [RunState.Phase.PLAY, RunState.Phase.PAUSED, RunState.Phase.LEVELUP]:
				field.spawn_comet(bool(args.get("rare", false)))
		&"debug_spawn_enemies":
			if OS.is_debug_build() and state.phase in [RunState.Phase.PLAY, RunState.Phase.PAUSED, RunState.Phase.LEVELUP]:
				enemies.debug_spawn_random(int(args.get("count", 100)))
				combat.rebuild_grid()
		&"debug_hurt":
			var keep := ship.invincible
			ship.invincible = false
			state.ship_invuln = 0.0
			var shield_t := state.ship_shield_t
			state.ship_shield_t = 0.0
			ship.damage(1.0, 0.0, &"debug")
			state.ship_shield_t = shield_t
			ship.invincible = keep
		&"debug_die":
			ship.invincible = false
			state.ship_invuln = 0.0
			state.ship_shield_t = 0.0
			ship.damage(state.ship_hp + 1.0, 0.0, &"debug")
		&"debug_coins":
			state.coins += int(args.get("amount", 100))
		&"debug_clear":
			finish(true)
		&"debug_fail":
			finish(false)

## まだ世界側へ渡していない時間。保守的な予測の先頭に含める。
func world_time_pending() -> float:
	return maxf(0, _world_dt)
