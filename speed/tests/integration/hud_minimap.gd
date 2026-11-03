## 自機中心地図・円形の切り取り・発見通知を短時間確認する。
extends "res://tests/integration/thrill_acceptance.gd"
const MapPhase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase
const MapPickup := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.PickupKind

var bridge: RefCounted

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings_copy
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	scene = await _cpp_open(1, false)
	if scene.bridge == null:
		_check(false, "C++の通常ランを開始する")
		await _close()
		get_tree().quit(1)
		return
	bridge = scene.bridge
	var hud: Control = scene.view.get_node("Hud/HudRoot")
	_check(bridge.command("dev_edit", {"kind": "debug_action", "payload": {"action": "reset_loadout", "args": {}}}).ok, "初期候補を閉じて地図だけを確認する")
	for ship in [Vector2.ZERO, Vector2(4000, -3000), Vector2(-5500, 0)]:
		_set_ship(ship)
		_check(hud._minimap_offset(ship).is_zero_approx(), "機体の位置%sを地図の中心にする" % ship)
		var east: Vector2 = hud._minimap_offset(ship + Vector2(1000, 0))
		_check(east.is_equal_approx(Vector2(1000 * hud.MINIMAP_R / float(hud._cpp_ui.hero.field_radius), 0)), "東の目標は方角と縮尺を保つ")
		var rim: Vector2 = hud._minimap_marker(ship + Vector2(20000, -20000), 6.0)
		_check(is_equal_approx(rim.length(), hud.MINIMAP_R - 6.0) and rim.normalized().is_equal_approx(Vector2(1, -1).normalized()), "遠い目標は方角を保ち印全体を円内に収める")
		await _shot("map_%d_%d" % [ship.x, ship.y])
	var segment: PackedVector2Array = hud._minimap_segment(Vector2(-100, 0), Vector2(100, 0))
	_check(segment == PackedVector2Array([Vector2(-hud.MINIMAP_R, 0), Vector2(hud.MINIMAP_R, 0)]), "線は地図の両端で切る")
	_check(hud._minimap_segment(Vector2(-100, 100), Vector2(100, 100)).is_empty(), "円の外の線は出さない")
	var disks: Array = hud._minimap_disk(Vector2(hud.MINIMAP_R - 3.0, 0), 12.0)
	var in_mask := not disks.is_empty()
	for polygon in disks:
		for p in polygon:
			in_mask = in_mask and p.length() <= hud.MINIMAP_R + 0.01
	_check(in_mask, "縁をまたぐ惑星は円内だけ描く")
	_check(hud._minimap_disk(Vector2(100, 0), 10.0).is_empty(), "円外の惑星は出さない")
	_check(hud._minimap_pickup_color(MapPickup.Heal) == Color("#67e8b1"), "回復の印は緑にする")
	_check(hud._minimap_pickup_color(MapPickup.Magnet) == Color("#b8a0ff"), "磁石の印は紫にする")
	_check(hud._minimap_pickup_color(MapPickup.CometWeapon) == Color("#5fd8ff"), "武器の印は水色にする")
	_check_arrows(hud)
	var isolated: Dictionary = bridge.read_frame().value.ui
	var ship_before: Vector2 = isolated.ship.ship_pos
	isolated.ship.ship_pos = Vector2(123, 456)
	_check(bridge.read_frame().value.ui.ship.ship_pos == ship_before and hud._cpp_ui.ship.ship_pos == ship_before, "読取値の変更がランとHUDの位置を書き換えない")
	_check(bridge.command("dev_hero_place", {"id": "perseus"}).ok, "C++へ英雄の配置を頼む")
	var hero: Dictionary = bridge.read_frame().value.ui.hero
	_set_ship(hero.center + Vector2(ContentManager.cfg.hero_glow_range - 1, 0))
	_step()
	_check(hud._hero_notice_t > 0 and hud._cpp_ui.phase == MapPhase.Play, "C++の実際の発見通知がポーズをせずHUDへ届く")
	await _shot("discovered")
	if shots != "" and DisplayServer.get_name() != "headless":
		get_window().content_scale_size = Vector2i.ZERO
		get_window().size = Vector2i(360, 640)
		await get_tree().process_frame
		await _shot("discovered_narrow")
		TranslationServer.set_locale("en")
		_check(hud.tr("hud.hero_discovered") == "Hero constellation discovered", "発見通知は英語へ翻訳できる")
		await _shot("discovered_narrow_en")
		TranslationServer.set_locale("ja")
	hud._process(2.0)
	_check(hud._hero_notice_t == 0, "発見通知は時間が来たら消える")
	_step()
	_check(hud._hero_notice_t == 0, "次の更新で発見通知を繰り返さない")
	await _close()
	print("[ミニマップ] 成功=%d 失敗=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _set_ship(position: Vector2) -> void:
	_check(bridge.command("dev_edit", {"kind": "ship", "payload": {"position": position, "velocity": Vector2.ZERO}}).ok, "C++へ確認する機体位置を渡す")

func _step() -> void:
	var result: Dictionary = bridge.step(1.0 / 120.0, bridge.pack_intent(Intent.new()), {"logical_size": get_viewport().get_visible_rect().size})
	_check(result.ok and bridge.delivery_error.get("ok", true), "C++の更新とHUDへの通知を完了する")

func _check_arrows(hud: Control) -> void:
	var original := hud.size
	for viewport_size in [Vector2(1280, 720), Vector2(360, 640)]:
		hud.size = viewport_size
		var factor: float = minf(hud.size.x / hud.ART_SIZE.x, hud.size.y / hud.ART_SIZE.y)
		var map_at: Vector2 = (hud.size - hud.ART_SIZE * factor) * 0.5 + hud.MINIMAP_CENTER * factor
		var map_radius: float = (hud.MINIMAP_R + 12.0) * factor
		var target: Vector2 = (map_at - hud.size * 0.5).normalized() * 20000.0
		hud.show_minimap = false
		var without_map: Vector2 = hud._edge_arrow_tip(target, Vector2.ZERO, Vector2(100, 100))
		hud.show_minimap = true
		var with_map: Vector2 = hud._edge_arrow_tip(target, Vector2.ZERO, Vector2(100, 100))
		_check(without_map.distance_to(map_at) < map_radius + 24.0 and with_map.distance_to(map_at) >= map_radius + 24.0, "画面%sで矢印を地図の外へずらす" % viewport_size)
		_check(not hud._edge_arrow_tip(Vector2.ZERO, Vector2.ZERO, Vector2(100, 100)).is_finite(), "画面内の目標には矢印を出さない")
	hud.size = original
