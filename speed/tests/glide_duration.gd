## T31 の時間倍率と、既存の速度・描画・残光への接続を短時間で確認する。
## Godot --headless --path speed res://tests/glide_duration.tscn
## 描画付き確認: --headless を外し -- --out=/tmp/speed-glide-captures を付ける。
extends Node

var failed := 0
var checks := 0
var run: RunSimulation
var scene: Node
var shots := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	scene = RunManager.create_run()
	run = scene.sim
	run.options = {"lab": true, "seed": 31, "meta": {}}
	add_child(scene)
	scene.auto_step = false
	run.state.phase = RunState.Phase.PLAY
	var s := run.state
	var cfg := run.cfg
	var baseline_vel := s.ship_vel
	var baseline := [s.stats.max_speed, s.stats.capacity, s.stats.charge_time, run.draw.budget(1.0), run.draw._launch_speed(Vector2.RIGHT, 1.0)]
	check(ContentManager.traits.has(&"T31"), "T31 is loaded through the standard registry")
	var icon: Texture2D = ContentManager.traits[&"T31"].icon_texture
	check(icon != null and icon.get_width() == 47, "T31 has a card/loadout icon")
	for level in range(4):
		if level > 0:
			check(run.loadout.grant(&"trait", &"T31"), "T31 stacks through grant")
		var mult := 1.0 + 0.25 * level
		check(s.stats.glide_duration_mult == mult, "T31 provisional additive multiplier")
		s.ship_vel = baseline_vel
		check(baseline == [s.stats.max_speed, s.stats.capacity, s.stats.charge_time, run.draw.budget(1.0), run.draw._launch_speed(Vector2.RIGHT, 1.0)], "Top speed, capacity, charge, line budget and launch speed stay unchanged")
		for time in [0.0, cfg.glide_hold, cfg.glide_hold + cfg.glide_fade * 0.25, cfg.glide_hold + cfg.glide_fade * 0.5, cfg.glide_hold + cfg.glide_fade]:
			_begin_glide()
			run.ship._step(time * mult, Vector2.ZERO, 0.0)
			var cruise := s.stats.max_speed * cfg.steer_cruise
			var k := clampf((time - cfg.glide_hold) / cfg.glide_fade, 0.0, 1.0)
			check(is_equal_approx(s.ship_vel.length(), lerpf(s.stats.max_speed * cfg.glide_speed_ratio, cruise, k)), "Hold and linear fade have the same normalized curve")
			check(s.glide == (time < cfg.glide_hold + cfg.glide_fade), "Glide ends at the scaled total duration")
		_begin_glide()
		run.ship._step(7.5, Vector2.ZERO, 0.0)
		print("[glide_duration] level=%d multiplier=%.2f at7.5s speed=%.1f glide=%s" % [level, mult, s.ship_vel.length(), s.glide])
		if level == 0 or level == 3:
			await _capture("level%d_at7_5s" % level)
	if shots != "":
		run.ship._step(3.0, Vector2.ZERO, 0.0)
		await _capture("level3_late_fade")
		run.ship._step(1.75, Vector2.ZERO, 0.0)
		await _capture("level3_cruise")
	check(not run.loadout.grant(&"trait", &"T31"), "T31 respects the three-stack cap")
	check(s.modules_obtained.has(&"T31"), "Standard result module list includes T31")
	var saved := SaveManager.data.duplicate(true)
	SaveManager.unlock_module(&"T31")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(SaveManager.data))
	check(roundtrip.encyclopedia.has("T31"), "Standard save representation preserves discovery")
	SaveManager.data = saved
	# 通常の候補・強化候補への接続を、抽選対象だけ絞って確かめる。
	var weapons := ContentManager.weapons
	var traits := ContentManager.traits
	ContentManager.weapons = {}
	ContentManager.traits = {&"T31": traits[&"T31"]}
	for level in [0, 1, 3]:
		s.traits = {} if level == 0 else {&"T31": level}
		var cards := run.loadout.roll_cards()
		check(cards.any(func(c): return c.id == &"T31" and c.level == level + 1) == (level < 3), "Standard new/upgrade/maxed card pool")
	ContentManager.weapons = weapons
	ContentManager.traits = traits
	s.traits = {&"T31": 3}
	run.loadout.refresh_stats()
	s.cards = [{"kind": &"trait", "id": &"T31", "level": 3}]
	run.set_phase(RunState.Phase.LEVELUP)
	run.cards_changed.emit()
	check(scene.view.get_node("Hud/HudRoot").card_info(s.cards[0]).name.ends_with("3/3"), "Trait card displays the configured stack cap")
	await _capture("card_and_loadout")
	await get_tree().process_frame
	scene.queue_free()
	await get_tree().process_frame
	print("[glide_duration] %d checks, %d failures" % [checks, failed])
	get_tree().quit(1 if failed else 0)

func _begin_glide() -> void:
	run.state.ship_vel = Vector2.RIGHT * run.state.stats.max_speed
	run.draw._pre_dash_speed = 0.0
	run.draw._end_trace(true)

func _capture(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	run.state.ship_pos = Vector2.ZERO
	run.state.view_center = Vector2.ZERO
	run.state.ship_heading = Vector2.RIGHT
	for i in 24:
		run.state.ship_pos += run.state.ship_vel / 120.0
		run.state.view_center = run.state.ship_pos
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
