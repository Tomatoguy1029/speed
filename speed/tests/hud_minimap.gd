## 自機中心地図・円形の切り取り・発見通知を短時間確認する。
extends "res://tests/thrill_acceptance.gd"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings_copy
	await _start(1)
	var hud = scene.view.get_node("Hud/HudRoot")
	var s := run.state
	for ship in [Vector2.ZERO, Vector2(4000, -3000), Vector2(-5500, 0)]:
		s.ship_pos = ship
		_check(hud._minimap_offset(ship).is_zero_approx(), "self stays at radar center at %s" % ship)
		var east: Vector2 = hud._minimap_offset(ship + Vector2(1000, 0))
		_check(east.is_equal_approx(Vector2(1000 * hud.MINIMAP_R / run.cfg.field_radius, 0)), "east keeps direction and scale")
		var rim: Vector2 = hud._minimap_marker(ship + Vector2(20000, -20000), 6.0)
		_check(is_equal_approx(rim.length(), hud.MINIMAP_R - 6.0) and rim.normalized().is_equal_approx(Vector2(1, -1).normalized()), "distant marker keeps direction and fits inside mask")
		await _shot("map_%d_%d" % [ship.x, ship.y])
	var segment: PackedVector2Array = hud._minimap_segment(Vector2(-100, 0), Vector2(100, 0))
	_check(segment == PackedVector2Array([Vector2(-hud.MINIMAP_R, 0), Vector2(hud.MINIMAP_R, 0)]), "line clips to both sides of radar")
	_check(hud._minimap_segment(Vector2(-100, 100), Vector2(100, 100)).is_empty(), "outside line stays hidden")
	var disks: Array = hud._minimap_disk(Vector2(hud.MINIMAP_R - 3.0, 0), 12.0)
	var in_mask := not disks.is_empty()
	for polygon in disks:
		for p in polygon:
			in_mask = in_mask and p.length() <= hud.MINIMAP_R + 0.01
	_check(in_mask, "planet crossing the rim is clipped inside the circle")
	_check(hud._minimap_disk(Vector2(100, 0), 10.0).is_empty(), "off-map planet stays hidden")
	run.heroes._place(load("res://data/heroes/perseus.tres"))
	s.ship_pos = run.heroes.center + Vector2(run.cfg.hero_glow_range - 1, 0)
	s.view_center = s.ship_pos
	s.events.clear()
	run.heroes.tick(0.01, 0.01)
	run.frame_events.emit(s.events)
	_check(hud._hero_notice_t > 0 and s.phase == RunState.Phase.PLAY, "real discovery event reaches HUD without pausing")
	await _shot("discovered")
	if shots != "" and DisplayServer.get_name() != "headless":
		get_window().content_scale_size = Vector2i.ZERO
		get_window().size = Vector2i(360, 640)
		await get_tree().process_frame
		await _shot("discovered_narrow")
		TranslationServer.set_locale("en")
		_check(hud.tr("hud.hero_discovered") == "Hero constellation discovered", "discovery notice has an English translation")
		await _shot("discovered_narrow_en")
		TranslationServer.set_locale("ja")
	hud._process(2.0)
	_check(hud._hero_notice_t == 0, "notification expires")
	s.events.clear()
	run.heroes.tick(0.01, 0.01)
	run.frame_events.emit(s.events)
	_check(hud._hero_notice_t == 0, "later frames do not restart the notice")
	await _close()
	print("[hud-minimap] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
