## ランの進行。時計、各 System の更新の順番、カメラ、3択、勝敗（設計書 4.3、仕様書 4・15・16）。
##
## ノードを持たないので、表示のない試行でもそのまま動く。RunSession が固定更新ごとに physics_step() を呼ぶ。
## UI と入力からの働きかけは command() で受け取る。
class_name RunSimulation
extends RefCounted

signal phase_changed(phase: RunState.Phase)
## 3択のカードが新しくなった（開いた・次の3択・引き直し）
signal cards_changed
## 1フレームぶんの出来事。表示・音・UI が受け取る
signal frame_events(events: Array[Dictionary])
## ランを最後まで終えた（結果画面へ）。実験場では出さない
signal finished(result: Dictionary)
## ランを途中でやめた
signal aborted

var state: RunState
var cfg: GameConfig
var ctx := RunContext.new()
## ランの指定。RunManager がステージ・モード・開始時刻を入れて渡す。実験場は設定の上書きも入れる。
var options: Dictionary = {}
## 録画の有無にかかわらず、ランを初期化した時点の出自と状態を保持する。
var recording_origin: Dictionary = {}
## 報酬演出中は世界と時計を保留し、HUD が実時間で演出を進める。
var ui_reward_active := false
## HUD に重ねたメニュー中は、選択確定の資源待ちも含めて更新を保留する。
var ui_overlay_active := false
var _phase_before_pause := RunState.Phase.PLAY
var input_source: Callable
## 表示のあるランだけが持つ入力（表示のない試行では null）
var input: InputRouter
## ボスの役者を置くノード
var actor_parent: Node
## 画面の大きさ（options.view_size がなければここから読む）
var view_size_source: Callable
var encounters
const ENCOUNTERS := preload("res://scripts/encounters/encounter_coordinator.gd")
const DIRECTOR := preload("res://scripts/encounters/attack_director.gd")

var field: FieldSystem:
	get: return ctx.field
var ship: ShipSystem:
	get: return ctx.ship
var draw: DrawSystem:
	get: return ctx.draw
var combat: CombatSystem:
	get: return ctx.combat
var enemies: EnemySystem:
	get: return ctx.enemies
var spawn: SpawnSystem:
	get: return ctx.spawn
var bosses: BossSystem:
	get: return ctx.bosses
var projectiles: ProjectileSystem:
	get: return ctx.projectiles
var loadout: LoadoutSystem:
	get: return ctx.loadout
var pickups: PickupSystem:
	get: return ctx.pickups
var heroes: HeroSystem:
	get: return ctx.heroes

## 敗北・クリアの演出の経過時間（実秒）
var sequence_t := 0.0
## 制限時間の一撃を始めたか。
var _final_strike_started := false
## ボスへのトドメの直前の機体の位置の記録（スローの再生に使う。仕様書 16）
var approach: Array[Vector2] = []
var finish_replay: Array[Vector2] = []
var finish_origin := Vector2.ZERO
var _finish_blast_done := false
var _finish_clear_shown := false
var _cam_ready := false
## 次の世界側の更新までにたまった時間と回数（config.world_tick_div）
var _world_real_dt := 0.0
var _world_dt := 0.0
var _world_steps := 0
## 開発版の計測：処理時間の合計（マイクロ秒）・回数・最大時間。
## play_total は全体の包含時間なので、個別の項目と合算しない。
var profile: Dictionary = {}
var profiling := false
## 追加の命令。シミュレーションの利用側が必要に応じて渡す。
var command_extension: Callable

## ランを組み立てる。input・actor_parent・view_size_source は先に入れておく。
func setup() -> void:
	cfg = options.get("config", ContentManager.cfg)
	state = RunState.new()
	state.lab_mode = bool(options.get("lab", false))
	state.meta_override = options.get("meta", {})
	state.stage_index = int(options.get("stage_index", 1))
	state.endless = bool(options.get("endless", false))
	state.stage = options.stage if options.has("stage") else ContentManager.runtime_stage(state.stage_index)
	state.time = float(options.get("start_time", 0.0))
	var start_source: String = options.get("start_source", "stage_start")
	if options.has("seed"):
		state.rng.seed = int(options.seed)
	else:
		state.rng.randomize()
	state.hitstop_budget = cfg.kill_hitstop_cap
	_read_settings()
	SaveManager.settings_changed.connect(_read_settings)
	ctx.state = state
	ctx.cfg = cfg
	ctx.options = options
	ctx.profile = options.get("profile", ProfileManager.for_run(state.lab_mode, state.meta_override)).duplicate(true)
	ctx.field = FieldSystem.new()
	ctx.ship = ShipSystem.new()
	ctx.draw = DrawSystem.new()
	ctx.combat = CombatSystem.new()
	ctx.enemies = EnemySystem.new()
	ctx.spawn = SpawnSystem.new()
	ctx.bosses = BossSystem.new()
	ctx.projectiles = ProjectileSystem.new()
	ctx.loadout = LoadoutSystem.new()
	ctx.pickups = PickupSystem.new()
	ctx.heroes = HeroSystem.new()
	bosses.actor_parent = actor_parent
	enemies.definitions = options.get("enemies", {}).duplicate()
	if not state.lab_mode:
		enemies.set_stage_tuning(state.stage.enemy_tuning)
	# 能力値を先に計算してから機体を置く
	for m: RunSystem in [field, loadout, ship, draw, combat, enemies, spawn, bosses, projectiles, pickups, heroes]:
		m.setup(ctx)
	combat.rebuild_grid()
	if not state.lab_mode and state.stage.encounter_profile.get("enabled", false):
		encounters = ENCOUNTERS.new()
		encounters.setup(self, state.stage.encounter_profile)
	# 強敵の攻撃の管理（時間帯の予算と群れごとの value で動く。仕様書 11.7）。実験場は options.director の設定で動く
	var director = DIRECTOR.new()
	director.state = state
	director.projectiles = projectiles
	if state.lab_mode:
		director.configure(options.get("director", {}))
	else:
		director.formation_mode = true
		director.configure({"enabled": true, "budget": maxi(0, spawn.current_phase().attack_budget), "jitter": 0.0})
	projectiles.director = director
	if not state.lab_mode:
		spawn._sync_attack_budget(spawn.current_phase())
	loadout.cards_opened.connect(func(_c):
		set_phase(RunState.Phase.LEVELUP)
		cards_changed.emit())
	_update_camera(1.0)
	recording_origin = recording_snapshot()
	recording_origin["source"] = "lab" if state.lab_mode else start_source
	# 最初の武器を選ぶ。HUD がつながってから開く
	if not state.lab_mode:
		loadout.open_start_cards.call_deferred()

## ランを片付ける。設定の通知を外し、ボスの役者を消す。
func dispose() -> void:
	if state != null: state.hitstop = 0.0
	command_extension = Callable()
	if SaveManager.settings_changed.is_connected(_read_settings):
		SaveManager.settings_changed.disconnect(_read_settings)
	if bosses != null:
		bosses.remove_boss()
	if projectiles != null and projectiles.director != null:
		projectiles.director.projectiles = null
		projectiles.director.state = null
		projectiles.director = null
	for name in ["field", "ship", "draw", "combat", "enemies", "spawn", "bosses", "projectiles", "loadout", "pickups", "heroes"]:
		var system: RunSystem = ctx.get(name)
		if system != null:
			system.dispose()
		ctx.set(name, null)
	if ctx.resources != null: ctx.resources.cancel()
	ctx.resources = null
	encounters = null
	input_source = Callable()
	view_size_source = Callable()

## 成長と戦闘の初期値。装備は複製し、その後の取得で記録の初期状態が変わるのを防ぐ。
func recording_snapshot() -> Dictionary:
	return {"t": state.time, "world_t": state.world_time, "phase": RunState.Phase.keys()[state.phase],
		"level": state.level, "xp": state.xp, "xp_gained": state.xp_gained, "xp_dropped": state.xp_dropped,
		"hp": state.ship_hp, "hp_max": state.stats.max_hp, "kills": state.kills,
		"weapons": state.weapons.duplicate(), "traits": state.traits.duplicate(),
		"hero_power": String(state.hero_power), "bonus_t": state.bonus_t, "endless": state.endless}

# ── 更新 ──────────────────────────────────────────────────────────

## 固定更新1回ぶん。実験場は自分で _play_tick を進めるので、ここは通らない。
func physics_step(delta: float) -> void:
	if state.lab_mode or ui_overlay_active:
		return
	# 通常報酬の残りより最終勝利を優先する。首の撃破・再生は boss_dead を立てない。
	if state.phase == RunState.Phase.PLAY and state.boss_dead:
		_check_end()
	if ui_reward_active and state.phase != RunState.Phase.FINISHING:
		return
	match state.phase:
		RunState.Phase.PLAY:
			if profiling:
				_run(&"play_total", func(): _play_tick(delta))
			else:
				_play_tick(delta)
		RunState.Phase.LEVELUP:
			var choice: Variant = loadout.poll_choice()
			if choice != null and not bool(choice): set_phase(RunState.Phase.PLAY)
		RunState.Phase.DYING:
			_dying_tick(delta)
		RunState.Phase.FINISHING:
			_finishing_tick(delta)

## 設定のうちランに効くもの（ポーズ中に変えるとすぐ反映）。
func _read_settings() -> void:
	state.hitstop_enabled = bool(options.get("hitstop", true)) if state.lab_mode else bool(SaveManager.settings.hitstop)
	if not state.hitstop_enabled: state.hitstop = 0.0

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
	if state.controls_locked or state.encounter_protected: state.hitstop = 0.0
	state.sim_time += real_dt
	var it: Intent = input_source.call() if input_source.is_valid() else input.poll()
	if bosses.actor != null and bosses.actor.get("mode")==&"finale":
		bosses.actor.advance_finale(real_dt,it)
		_check_end()
		return
	if input != null:
		input.drawing = state.drawing
	if state.steering_locked: it = Intent.new()
	if state.controls_locked:
		it = Intent.new()
		state.ship_vel = Vector2.ZERO
	ship.intent = it
	draw.intent = it
	draw.handle_input()
	if state.hitstop > 0.0:
		state.hitstop = maxf(0.0, state.hitstop - real_dt)
		return
	if profiling:
		_run(&"combat", func(): combat.tick(real_dt, 0.0))
		_run(&"draw", func(): draw.tick(real_dt, 0.0))
	else:
		combat.tick(real_dt, 0.0)
		draw.tick(real_dt, 0.0)
	_check_end()
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
		spawn._sync_attack_budget(spawn.current_phase())
		if encounters != null:
			encounters.before_world()
		elif not state.lab_mode and projectiles.director != null:
			projectiles.director.advance(state.world_time, enemies)
		_run(&"field", func(): field.tick(wr, wd))
		_run(&"enemies", func(): enemies.tick(wr, wd))
		_run(&"bosses", func(): bosses.tick(wr, wd))
		_check_end()
		if state.phase != RunState.Phase.PLAY:
			return
		_run(&"grid", func(): combat.rebuild_grid())
	_run(&"ship", func(): ship.tick(real_dt, world_dt))
	if it.hero_press:
		heroes.activate()
	_run(&"heroes", func(): heroes.tick(real_dt, world_dt))
	if state.phase == RunState.Phase.PLAY:
		_run(&"build", func(): loadout.tick(real_dt, world_dt))
	if world_step and state.phase == RunState.Phase.PLAY:
		_run(&"projectiles", func(): projectiles.tick(wr, wd))
	_check_end()
	if state.phase != RunState.Phase.PLAY:
		return
	_run(&"cleanup", func(): enemies.cleanup())
	if world_step:
		if encounters != null:
			encounters.advance()
		if (not state.lab_mode or options.get("auto_spawn", false)) and (projectiles.director == null or not projectiles.director.guard_active()):
			_run(&"spawner", func(): spawn.spawner_tick(wr, wd))
		_run(&"pickups", func(): pickups.tick(wr, wd))
	_record_approach()
	if state.phase == RunState.Phase.PLAY and state.bonus_t <= 0.0 and field.take_warp():
		_enter_bonus()
	_update_camera(real_dt)
	_check_end()
	if state.phase == RunState.Phase.PLAY and not state.lab_mode:
		loadout.try_open_cards()

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

## 積んだ出来事を表示・音・UI へ渡す。RunSession が毎フレーム呼ぶ。
func flush_events() -> void:
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
	elif state.time_limit_reached:
		if not _final_strike_started:
			_begin_final_strike()
		elif state.time >= state.stage.time_limit + cfg.time_up_charge_time:
			_land_final_strike()

func set_phase(phase: RunState.Phase) -> void:
	if state.phase == phase:
		return
	state.phase = phase
	if phase != RunState.Phase.PLAY: state.hitstop = 0.0
	loadout.on_phase_changed(phase)
	phase_changed.emit(phase)

# ── カメラ（仕様書 15） ──────────────────────────────────────────

func _base_zoom() -> float:
	var size := _view_size()
	var f := pow(cfg.zoom_ref_speed / maxf(cfg.zoom_ref_speed, state.stats.max_speed), cfg.zoom_exp)
	return minf(size.x, size.y) / cfg.base_view * clampf(f, cfg.zoom_min, 1.0)

func _view_size() -> Vector2:
	if options.has("view_size"):
		return options.view_size
	return view_size_source.call() if view_size_source.is_valid() else Vector2(1280, 720)

func _update_camera(real_dt: float) -> void:
	if state.cinematic_camera:
		state.view_half=_view_size()/2.0/maxf(0.001,state.camera_zoom)
		return
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
	if not loadout.choose_card(index):
		set_phase(RunState.Phase.PLAY)

# ── 敗北（仕様書 16） ─────────────────────────────────────────────

func _begin_death() -> void:
	sequence_t = 0.0
	state.emit(&"ship_death", {"pos": state.ship_pos})
	set_phase(RunState.Phase.DYING)

## 制限時間に達したら、ボスが避けられない一撃を溜める（仕様書 4.1）。溜めの間も機体は動かせる。
## ボスがいなければ、すぐに一撃が当たる。
func _begin_final_strike() -> void:
	_final_strike_started = true
	state.emit(&"final_strike", {"t": state.time})
	var actor := bosses.actor
	if bosses.has_boss() and actor != null and actor.has_method("begin_final_strike"):
		actor.begin_final_strike(cfg.time_up_charge_time)
	else:
		_land_final_strike()

## 一撃は無敵・バリアを無視して機体の HP を0にする。その後は普段の敗北と同じ流れ。
func _land_final_strike() -> void:
	ship.invincible = false
	state.ship_invuln = 0.0
	state.ship_shield_t = 0.0
	ship.damage(state.ship_hp + 1.0, 0.0, &"final_strike", &"boss")

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

## 現在の最終勝利通知 state.boss_dead の接続先。Hydra の段階移行には接続しない。
func _begin_finish() -> void:
	if state.phase != RunState.Phase.PLAY or not state.boss_dead:
		return
	sequence_t = 0.0
	_finish_blast_done = false
	_finish_clear_shown = false
	finish_origin = bosses.boss_pos(state.ship_pos)
	finish_replay = approach.duplicate()
	finish_replay.append(state.ship_pos)
	_reset_finish_input()
	projectiles.clear_hostile()
	state.emit(&"boss_finish", {"pos": finish_origin})
	set_phase(RunState.Phase.FINISHING)
	if state.draco_finish_done:
		finish_replay.clear()
		sequence_t=finish_reveal_start()+finish_reveal_duration()
		_finish_blast()

## 表示するだけ。既存の報酬付与は finish → GameManager → SaveManager が1回行う。
func finish_legendary() -> LegendaryModuleDef:
	if state.endless or state.stage_index < 1 or state.stage_index > 4 or state.stage == null:
		return null
	return ContentManager.definition(&"legendary_modules", state.stage.legendary_module_id) as LegendaryModuleDef

func finish_reveal_start() -> float:
	return maxf(0.0, cfg.boss_finish_slow_time) + maxf(0.0, cfg.boss_finish_blast_time)

func finish_reveal_duration() -> float:
	if finish_legendary() == null:
		return 0.0
	return maxf(0.0, cfg.boss_finish_relic_appear_time) + maxf(0.0, cfg.boss_finish_relic_hold_time) + maxf(0.0, cfg.boss_finish_relic_collect_time)

func _reset_finish_input() -> void:
	if input != null:
		input.cancel_gesture()
		input.drawing = false
	state.hitstop = 0.0
	state.world_scale = 1.0
	state.drawing = false
	state.tracing = false
	state.ship_vel = Vector2.ZERO
	_world_real_dt = 0.0
	_world_dt = 0.0
	_world_steps = 0

func _finish_blast() -> void:
	if _finish_blast_done:
		return
	_finish_blast_done = true
	state.emit(&"boss_explode", {"pos": finish_origin})
	var t := enemies.table
	for i in t.alive.size():
		if t.alive[i] != 0 and t.dead[i] == 0 and t.is_boss[i] == 0:
			enemies.mark_dead(i)
			state.emit(&"kill", {"pos": t.pos[i], "r": t.r[i], "type": t.type[i], "cause": &"finale", "dir": (t.pos[i] - finish_origin).normalized(), "color": t.color[i], "silent": true})
	projectiles.clear_hostile()
	bosses.remove_boss()
	enemies.cleanup()

## 短い再生 → 仮の消滅 → 伝説の姿・名前 → 回収 → CLEAR! → 既存の短フェードと結果。
func _finishing_tick(real_dt: float) -> void:
	sequence_t += real_dt
	var t1 := maxf(0.0, cfg.boss_finish_slow_time)
	var clear_at := finish_reveal_start() + finish_reveal_duration()
	if sequence_t < t1 and not finish_replay.is_empty():
		var k := clampf(sequence_t / maxf(0.001, t1), 0.0, 1.0)
		var idx := k * (finish_replay.size() - 1)
		var i0 := int(idx)
		var i1 := mini(i0 + 1, finish_replay.size() - 1)
		state.ship_pos = finish_replay[i0].lerp(finish_replay[i1], idx - i0)
	elif not finish_replay.is_empty():
		state.ship_pos = finish_replay.back()
	var follow := 1.0 - exp(-10.0 * real_dt)
	var zoom_to := _base_zoom() * (cfg.boss_finish_zoom if sequence_t < t1 else 1.0)
	state.view_center += (state.ship_pos - state.view_center) * follow
	state.camera_zoom += (zoom_to - state.camera_zoom) * follow
	state.view_half = _view_size() / 2.0 / state.camera_zoom
	if sequence_t >= t1:
		_finish_blast()
	if sequence_t >= clear_at and not _finish_clear_shown:
		_finish_clear_shown = true
		state.emit(&"clear_banner")
	if sequence_t >= clear_at + maxf(0.0, cfg.boss_finish_clear_time):
		finish(true)

## ランを終えて結果画面へ。
func finish(cleared: bool) -> void:
	if state.lab_mode:
		state.emit(&"lab_result", {"cleared": cleared})
		return
	if state.phase == RunState.Phase.ENDED:
		return
	_reset_finish_input()
	state.cleared = cleared
	set_phase(RunState.Phase.ENDED)
	# 時間をゼロに調整しても、結果フェードがランを停止する前に最後の出来事を届ける。
	flush_events()
	var coins := state.coins + (cfg.clear_bonus if cleared else 0)
	finished.emit({
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
	if state == null: return
	if (ui_reward_active or ui_overlay_active) and name in [&"choose_card", &"reroll", &"draw_button"]:
		return
	if state.phase == RunState.Phase.FINISHING:
		if name == &"skip_finish":
			# スキップも同じ CLEAR! と保存出口を通す。連打で表示時間を伸ばさない。
			sequence_t = maxf(sequence_t, finish_reveal_start() + finish_reveal_duration())
			_reset_finish_input()
			_finishing_tick(0.0)
		elif name == &"abort":
			_reset_finish_input()
			set_phase(RunState.Phase.ENDED)
			aborted.emit()
		return
	if state.phase == RunState.Phase.ENDED:
		return
	if command_extension.is_valid() and command_extension.call(name, args): return
	match name:
		&"skip_boss_entrance":
			var owner := bosses.actor
			var entrance: RefCounted = owner.get("entrance") if owner != null else null
			if state.phase == RunState.Phase.PLAY and entrance != null and entrance.active:
				entrance.skip()
				if input != null: input.cancel_gesture()
		&"choose_card":
			choose_card(args.get("index", 0))
		&"reroll":
			if state.phase == RunState.Phase.LEVELUP:
				loadout.reroll_cards()
		&"pause":
			if state.phase in [RunState.Phase.PLAY, RunState.Phase.LEVELUP]:
				_phase_before_pause = state.phase
				if input != null: input.cancel_gesture()
				set_phase(RunState.Phase.PAUSED)
		&"resume":
			if state.phase == RunState.Phase.PAUSED:
				if input != null: input.cancel_gesture()
				set_phase(_phase_before_pause)
		&"abort":
			set_phase(RunState.Phase.ENDED)
			aborted.emit()
		&"draw_button":
			if input != null:
				input.press_draw_button()

## まだ世界側へ渡していない時間。保守的な予測の先頭に含める。
func world_time_pending() -> float:
	return maxf(0, _world_dt)
