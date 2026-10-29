## ビルドの組み合わせ・一撃・分裂・耐久の重要な境界を確認する。
extends "res://tests/thrill_acceptance.gd"

func _ready() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	scene = RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	scene.auto_step = false
	run = scene.sim
	_test_multipliers()
	_test_duplication()
	_test_discovery()
	await _close()
	print("[build_rework] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _test_multipliers() -> void:
	_check(run.loadout.grant(&"trait", &"T34", 5), "大振りを装備")
	_check(is_equal_approx(run.loadout.area_multiplier(), 1.3), "大振りLv5の半径")
	_check(run.loadout.grant(&"trait", &"T35", 5), "マルチショットを装備")
	_check(run.loadout.shot_count(1) == 2 and run.loadout.shot_count(8) == 16, "武器ごとの弾数を同じ割合で増やす")
	_check(run.loadout.grant(&"trait", &"T36", 5), "フルバーストを装備")
	run.state.gauge = 0.99
	_check(is_equal_approx(run.loadout.shooting_rate(), 1.0), "1単位未満では連射を増やさない")
	run.state.gauge = 1.0
	_check(is_equal_approx(run.loadout.shooting_rate(), 1.45), "1単位で連射が増える")
	run.state.gauge = 2.0
	_check(is_equal_approx(run.loadout.shooting_rate(), 1.9), "容量を増やした分も連射に含める")
	run.loadout.reset_loadout()

func _test_duplication() -> void:
	_check(run.loadout.grant(&"trait", &"T37", 5), "デュプリケーターを装備")
	var ps := run.projectiles
	ps.fire_shot(Vector2.ZERO, 0.0, 10.0)
	var original := 0
	var source_hit := {123: true}
	ps.friend_hit[original] = source_hit
	var before := ps.friend_count()
	for attempt in 100:
		if ps.duplicate_friend(original, Vector2.ONE): break
	_check(ps.friend_count() == before + 2, "分裂で2発増える")
	for i in range(1, 3):
		_check(ps.friend_generation[i] == 1 and is_equal_approx(ps.friend_dmg[i], 8.0), "Lv5の子は8割・次の世代")
		_check(ps.friend_hit[i].has(123), "同じ敵へ分裂直後に再命中しない")
	ps.friend_hit[1][456] = true
	_check(not ps.friend_hit[2].has(456), "左右の命中履歴を独立させる")
	ps.friend_generation[1] = 6
	_check(not ps.duplicate_friend(1, Vector2.ONE), "6世代で止まる")
	while ps.friend_count() < 219:
		ps.fire_shot(Vector2.ZERO, 0.0, 1.0)
	_check(not ps.duplicate_friend(0, Vector2.ZERO), "220を超える分裂を止める")
	ps.friend_slots.clear()
	run.loadout.reset_loadout()

func _test_discovery() -> void:
	SaveManager.data = SaveManager._migrate({"encyclopedia": ["T01", "T13", "W01"]}, SaveManager.default_data())
	_check(SaveManager.is_module_known(&"W29"), "終端爆縮の取得をエンドブラストへ引き継ぐ")
	_check(not SaveManager.is_module_known(&"T13"), "廃止した反応波動を表示しない")
	_check(SaveManager.is_module_known(&"W01"), "他の獲得記録を保つ")
