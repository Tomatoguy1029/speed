## 群れの配置・出現位置・拡大・向きと乱数を、本番の配置シーンから比較する。
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
	if not core.has_method("spawn_formation"):
		check(false, "生成済みの群れをネイティブが配置する")
	else:
		await compare_formations(comparison, core)
	core.close()
	print("[native_formations] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_formations(comparison, core) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 822, "empty": true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.cfg.base_max_speed = 100.0
	run.ship.setup(run.ship.ctx)
	var data := DATA.compile_enemy(run.enemies.def_of(&"drifter"), run.cfg, run.state.stage)
	data.enemies.append_array(DATA.compile_enemy(run.enemies.def_of(&"shield"), run.cfg, run.state.stage).enemies)
	core.configure(data)
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.set_attack_formation_mode(true)
	run.projectiles.director.formation_mode = true
	var source: Dictionary = load("res://tools/content/build_runtime_stage.gd").formation(load("res://data/formations/telescope_reticle.tscn"))
	# 配置は本番シーン、行動は現時点で移行済みの追跡と盾を使う。
	for layout in source.layouts:
		for i in layout.markers.size(): layout.markers[i].type = &"shield" if i % 2 == 0 else &"drifter"
	var generator: RefCounted = DATA.new()
	var prepared: Dictionary = generator.compile_formation(source)
	var file := FileAccess.open("/tmp/speed-native-formation.bin",FileAccess.WRITE)
	file.store_var(prepared)
	file.close()
	file = FileAccess.open("/tmp/speed-native-formation.bin",FileAccess.READ)
	var restored: Dictionary = file.get_var()
	file.close()
	check(comparison.difference(prepared,restored).is_empty(), "生成した配置の座標と角度を保存後も保つ")
	check(core.configure_formations([restored],run.cfg.base_view), "配置の固定変換を生成データから準備する")
	var bad := restored.duplicate(true)
	bad.entries[0].pos = Vector2(NAN,0)
	check(not core.configure_formations([bad],run.cfg.base_view), "不正な配置で有効な準備を上書きしない")
	core.start(822,run.enemies._next_id)
	run.state.rng.seed = 822
	var input := Intent.new()
	input.stick_active = true
	run.ship.intent = input
	for tick in 36:
		input.stick = Vector2.from_angle(tick * 0.23)
		var dt := 0.0 if tick == 0 else 0.1
		run.ship.tick(dt,dt)
		core.step_ship(dt,dt,{"stick_active":true,"stick":input.stick})
		run.state.view_half = Vector2(640,360) * (1.0 + tick%4 * 0.7)
		core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
		var layout: int = -1 if tick%3 == 0 else tick%source.layouts.size()
		var entry: int = -1 if tick%2 == 0 else tick%source.entries.size()
		if tick == 32: layout = 999
		if tick == 33: entry = 999
		var types: Array = [&"shield"] if tick%4 == 0 else []
		if tick == 11: types = [&"未選択"]
		if tick == 0: check(run.state.ship_vel.length() <= 40.0, "低速時の機体の向きを使う条件を通る")
		if tick == 20: check(run.state.ship_vel.length() > 40.0, "速度から向きを求める条件を通る")
		var value := -1.0 if tick%3 == 0 else 0.0 if tick%3 == 1 else 2.7
		var priority: Variant = null if tick%2 == 0 else 0.0
		var managed: Variant = null if tick%2 == 0 else false
		run.state.events.clear()
		var rows := run.spawn.spawn_formation(source,layout,entry,types,value,priority,managed)
		var ids := PackedInt64Array()
		for k in range(1,rows.size(),2): ids.append(rows[k])
		check(core.spawn_formation(0,layout,entry,PackedStringArray(types),value,priority,managed) == ids, "配置した群れの個体IDと順番が一致する")
		var difference: String = comparison.difference(comparison.snapshot(run,[],tick).enemies,core.enemies_snapshot())
		check(difference.is_empty(), "群れの位置・角度・個体値が一致する %d: %s" % [tick,difference])
		var expected := []
		for row in run.enemies.table.alive.size():
			if run.enemies.table.alive[row] == 0: continue
			expected.append({"id":run.enemies.table.id[row],"group":run.enemies.table.attack_group[row],"value":run.enemies.table.attack_value[row],"priority":run.enemies.table.attack_priority[row],"managed":bool(run.enemies.table.attack_managed[row])})
		expected.sort_custom(func(a,b): return a.id < b.id)
		check(comparison.difference(expected,core.enemy_attack_snapshot()).is_empty(), "群れの攻撃枠と優先度が一致する")
		check(comparison.difference(comparison.plain(run.state.events),comparison.plain(core.drain_events())).is_empty(), "出現通知の順番が一致する")
		check(str(run.state.rng.state) == core.inspect().rng_state, "配置・出現位置の抽選と個体追加の乱数が一致する")
		if tick%5 == 0:
			for k in range(0,rows.size(),2):
				core.remove_enemy(rows[k+1])
				run.enemies.mark_dead(rows[k])
			run.enemies.cleanup()
	lab.free()
