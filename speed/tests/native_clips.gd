## クリップの周期・上限・全滅と行再利用を、同じランの時計で比較する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	var comparison = COMPARE.new()
	var core = comparison.create_native()
	if not core.has_method("step_clips"):
		check(false, "クリップの時計と群れの寿命をネイティブが保持する")
	else:
		await compare_clips(comparison,core)
	core.close()
	print("[native_clips] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_clips(comparison,core) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":901,"empty":true})
	var run: RunSimulation = lab.run
	run.ship.setup(run.ship.ctx)
	run.state.view_center = run.state.ship_pos
	run.state.enemy_aim = run.state.ship_pos
	run.state.view_half = Vector2(640,360)
	run.projectiles.director.formation_mode = true
	var stage := RuntimeStage.new()
	stage.boss_enabled = false
	stage.enemy_attack_values = {"drifter":0.4,"shield":0.8}
	var phase := PhaseDef.new()
	phase.id = &"群れ比較"
	phase.mix = {"drifter":1.0,"shield":1.0}
	stage.phases = [phase]
	var formation := {"entries":[{"weight":1.0,"pos":Vector2(0,-400),"rot":PI},{"weight":0.7,"pos":Vector2(500,-50),"rot":1.7}],
		"layouts":[{"weight":1.0,"value":1.2,"attack_managed":true,"markers":[{"type":&"drifter","pos":Vector2(-35,0),"rot":0.3},{"type":&"shield","pos":Vector2(35,0),"rot":-0.4}]},
		{"weight":0.5,"value":0.0,"attack_managed":false,"markers":[{"type":&"drifter","pos":Vector2.ZERO,"rot":0.0}]}]}
	for i in 2:
		var clip := RuntimeClip.new()
		clip.time = 0.1 + i*0.2
		clip.length = 1.7 + i*0.3
		clip.groups = 2
		clip.interval = 0.23
		clip.attack_priority = i
		clip.types.assign([&"drifter",&"shield"] if i == 0 else [&"drifter"])
		var choices := [formation]
		if i == 1:
			var alternative := formation.duplicate(true)
			for layout in alternative.layouts:
				layout.markers = layout.markers.filter(func(marker): return marker.type == &"drifter")
			choices.append(alternative)
		clip.prepared.assign(choices)
		stage.clips.append(clip)
	run.state.stage = stage
	var data := {"enemies":[]}
	for type in [&"drifter",&"shield"]:
		var definition: EnemyDef = run.enemies.def_of(type).duplicate(true)
		definition.speed = 0.0
		definition.max_alive = 2 if type == &"shield" else 0
		run.enemies.definitions[type] = definition
		var one := DATA.compile_enemy(definition,run.cfg,stage)
		if not data.has("version"): data.merge(one)
		data.enemies.append_array(one.enemies)
	core.configure(data)
	core.configure_enemy_order(PackedStringArray(["chase"]))
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.set_attack_formation_mode(true)
	var timeline := DATA.compile_spawn_timeline(stage,run.cfg)
	timeline.types.shield.max_alive = 2
	core.configure_spawn_timeline(timeline)
	core.configure_population(values(run.cfg,["spawn_recycle_scale","spawn_region_cap","spawn_margin","field_radius","planet_radius"]))
	check(core.configure_clips(timeline.clip_bundle), "生成した周期と配置を準備する")
	var broken: Dictionary = timeline.clip_bundle.duplicate(true)
	broken.clips[0].formations = [999]
	check(not core.configure_clips(broken), "存在しない配置参照で有効な準備を壊さない")
	core.start(901,run.enemies._next_id)
	core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
	run.state.rng.seed = 901
	var spawn_events := 0
	var ended_events := 0
	var capped := false
	for tick in 64:
		var dt := 0.05
		run.state.time += dt
		run.state.world_time += dt
		run.enemies.tick(dt,dt)
		core.step(dt)
		if tick in [14,25,40]:
			for row in run.enemies.table.alive.size():
				if run.enemies.table.alive[row] == 0: continue
				if tick == 14 and row%2 == 0: continue
				core.remove_enemy(run.enemies.table.id[row])
				run.enemies.mark_dead(row)
			run.enemies.cleanup()
		run.state.events.clear()
		run.spawn._survey_rows(0.0)
		core.survey_population(0.0)
		capped = capped or run.spawn._formation_capped(formation)
		run.spawn._tick_clips()
		check(core.step_clips(), "クリップの周期を更新する")
		var expected := []
		for i in stage.clips.size():
			var groups := []
			for group in run.spawn._clip_groups.get(i,[]):
				var ids := []
				for k in range(1,group.size(),2): ids.append(group[k])
				groups.append(ids)
			expected.append({"next":run.spawn._clip_next.get(i,-1e9),"groups":groups})
		var difference: String = comparison.difference(expected,core.clips_snapshot())
		check(difference.is_empty(), "次回時刻と生存する群れが一致する %d: %s" % [tick,difference])
		difference = comparison.difference(comparison.snapshot(run,[],tick).enemies,core.enemies_snapshot())
		check(difference.is_empty(), "クリップが生成した個体と配置が一致する %d: %s" % [tick,difference])
		check(comparison.difference(comparison.plain(run.state.events),comparison.plain(core.drain_events())).is_empty(), "全滅と出現の通知順が一致する")
		check(str(run.state.rng.state) == core.inspect().rng_state, "上限と周期による抽選の回数が一致する")
		for event in run.state.events:
			if event.type == &"clip_group": spawn_events += 1
			if event.type == &"clip_group_end": ended_events += 1
	check(capped, "種類上限による群れの見送りを実際に通る")
	check(spawn_events >= 4 and ended_events > 0, "補充と群れの全滅を実際に通る")
	lab.free()
