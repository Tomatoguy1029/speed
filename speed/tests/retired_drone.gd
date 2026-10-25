## 撤回したW06を取得経路から外し、旧セーブと別ドローンを保つ。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var config := ContentManager.cfg.duplicate(true) as GameConfig
	config.start_weapon_choices = 100
	var session := RunManager.create_session(self, {"lab": true, "seed": 42, "config": config}, false)
	session.auto_step = false
	var loadout := session.sim.loadout
	check(ContentManager.catalog.find(&"weapons", &"W06") == null, "W06を登録と図鑑から除く")
	check(not loadout.grant(&"weapon", &"W06"), "旧W06の付与を安全に無視する")
	check(loadout.roll_start_cards().all(func(c): return c.id != &"W06"), "開始候補からW06を除く")
	for n in 30:
		check(loadout.roll_cards().all(func(c): return c.id != &"W06"), "成長候補からW06を除く")
	for id in [&"W25", &"W26", &"W27"]:
		check(ContentManager.catalog.find(&"weapons", id) != null, "%sの登録を保つ" % id)
		check(loadout.grant(&"weapon", id), "%sを取得できる" % id)
	var old_save := SaveManager.default_data()
	old_save.coins = 321
	old_save.cleared_stage = 3
	old_save.meta = {"M01": 2}
	old_save.encyclopedia = ["W06", "W25", "T06"]
	old_save.legendary = ["L01"]
	old_save.best.runs = 7
	var original := old_save.duplicate(true)
	var migrated: Dictionary = SaveManager._migrate(old_save, SaveManager.default_data())
	check(migrated == original, "W06を含む旧セーブの進行と取得履歴をそのまま保つ")
	check(JSON.parse_string(JSON.stringify(migrated)).encyclopedia.has("W06"), "保存し直しても旧IDの履歴を失わない")
	session.free()
	print("[retired_drone] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
