## 開発用の命令は、起動時にシミュレーションの追加の入口へつなぐ。
extends RefCounted
var _run: WeakRef
func setup(run: RunSimulation) -> void:
	_run = weakref(run)
func handle(name: StringName, args: Dictionary) -> bool:
	var run := _run.get_ref() as RunSimulation
	if run == null or run.state == null: return false
	var state := run.state
	var ship := run.ship
	var loadout := run.loadout
	var projectiles := run.projectiles
	var enemies := run.enemies
	var combat := run.combat
	var field := run.field
	var bosses := run.bosses
	match name:
		&"debug_time":
			state.time += float(args.get("seconds", 30.0))
		&"debug_hazards":
			# 敵の攻撃の形を機体の周りに出して見る
			var p := state.ship_pos
			var a := state.rng.randf() * TAU
			projectiles.fire_beam(p + Vector2.from_angle(a) * 420.0, a + PI, 900.0, 26.0, 0.8, 0.35, 10.0)
			projectiles.fire_cross(p + Vector2.from_angle(a + 2.0) * 260.0, 0.0, 700.0, 18.0, 0.9, 0.3, 10.0)
			projectiles.fire_zone(p + Vector2.from_angle(a + 4.0) * 160.0, 90.0, 1.0, 10.0,
				ProjectileSystem.HazardStyle.RETICLE)
			projectiles.fire_zone(p, 70.0, 1.2, 10.0, ProjectileSystem.HazardStyle.LIGHTNING, Color("#ffe46b"))
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
			loadout.grant(args.get("kind", &"weapon"), args.get("id", &"W01"), int(args.get("levels", 1)))
		&"debug_reset_loadout":
			loadout.reset_loadout()
		&"debug_level_up":
			loadout.add_xp(loadout.xp_needed() - state.xp + 0.01)
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
				_spawn_random(run, int(args.get("count", 100)))
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
			run.finish(true)
		&"debug_fail":
			run.finish(false)
		_: return false
	return true

func _spawn_random(run: RunSimulation, count_n: int) -> void:
	var enemies := run.enemies
	var state := run.state
	var table := enemies.table
	var field := run.field
	var cfg := run.cfg
	if not OS.is_debug_build():
		return
	var choices: Array[EnemyDef] = []
	for def: EnemyDef in ContentManager.sorted(ContentManager.enemies):
		if def.behavior != &"part" and enemies.behaviors[enemies._behavior_index(def.behavior)].debug_spawnable:
			choices.append(def)
	if choices.is_empty():
		return
	var view := state.view_rect()
	for k in clampi(count_n, 1, 10000):
		var def := choices[state.rng.randi_range(0, choices.size() - 1)]
		var pos := Vector2(state.rng.randf_range(view.position.x, view.end.x),
			state.rng.randf_range(view.position.y, view.end.y))
		var opts := {"facing": (state.ship_pos - pos).angle()}
		if def.size_var:
			opts.size = def.radius * state.rng.randf_range(0.85, 1.45)
		var i := enemies.spawn(def, pos, opts)
		var r := table.r[i]
		var p := field.push_out(pos, r + 4.0)
		if p.length() > cfg.field_radius - r:
			p = p.normalized() * (cfg.field_radius - r)
		table.pos[i] = p
