## 個体・共有overrideの会計、小数、整数保存の互換読み込み、表示用合計だけを確認する。
## godot --headless --path speed res://tests/attack_values.tscn
extends Node

var failed := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)

func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true, "stage": 4})
	var em: EnemySystem = lab.run.enemies
	var pm: ProjectileSystem = lab.run.projectiles
	var stage := StageDef.new()
	stage.enemy_attack_values = {"telescope": 1.0, "reticle": 0.5, "aquarius": 4.0}
	lab.run.state.stage = stage
	var clip := SpawnClip.new()
	var data := {"layouts": [{"name": "pair", "weight": 1.0, "markers": [
		{"type": &"telescope", "pos": Vector2.ZERO, "rot": 0.0},
		{"type": &"reticle", "pos": Vector2(100, 0), "rot": 0.0}]}],
		"entries": [{"weight": 1.0, "pos": Vector2(0, -1500), "rot": 0.0}]}
	check(is_equal_approx(clip.automatic_value(stage, data.layouts[0]), 1.5), "Auto sums actual marker types including fractional costs")
	clip.types = [&"reticle"]
	check(is_equal_approx(clip.automatic_value(stage, data.layouts[0]), 0.5), "Auto respects clip type filter")
	stage.enemy_attack_values.reticle = 1.5
	check(is_equal_approx(clip.automatic_value(stage, data.layouts[0]), 1.5), "Auto refresh reads changed stage values")
	stage.enemy_attack_values.reticle = 0.5
	clip.types.clear()
	stage.enemy_attack_values.telescope = 0.0
	stage.enemy_attack_values.reticle = 0.0
	check(stage.enemy_attack_value(&"telescope") == 0.0 and clip.automatic_value(stage, data.layouts[0]) == 0.0,
		"Zero type values reach Auto without a compatibility fallback")
	stage.enemy_attack_values.reticle = 1e-18
	check(stage.enemy_attack_value(&"reticle") == 1e-18 and clip.automatic_value(stage, data.layouts[0]) == 1e-18,
		"Auto preserves a deliberate tiny positive value")
	stage.enemy_attack_values.reticle = -0.5
	check(stage.enemy_attack_value(&"reticle") == 1.0, "Negative type value keeps compatibility fallback")
	stage.enemy_attack_values.reticle = INF
	check(stage.enemy_attack_value(&"reticle") == 1.0, "Nonfinite type value keeps compatibility fallback")
	stage.enemy_attack_values = {"telescope": 1.0, "reticle": 0.5}
	clip.formation_values = {"fixture/pair": 3}
	const SAVE := "/tmp/speed-attack-values-fixture.tres"
	check(ResourceSaver.save(clip, SAVE) == OK, "Legacy integer fixture saves")
	var loaded: SpawnClip = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.formation_value("fixture.tscn", "pair") == 3.0 and loaded.formation_values["fixture/pair"] is int, "Legacy integer is preserved as explicit shared override")
	check(loaded.formation_value("fixture.tscn", "other") < 0.0, "Missing override uses individual accounting")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	clip.formation_values = {"fixture/pair": 0.0}
	check(ResourceSaver.save(clip, SAVE) == OK, "Zero shared override saves")
	loaded = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.formation_value("fixture.tscn", "pair") == 0.0,
		"Zero shared override reopens as zero")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	clip.formation_values = {"fixture/pair": 1e-18}
	check(clip.formation_value("fixture.tscn", "pair") == 1e-18,
		"Tiny positive shared override remains positive")
	clip.formation_values = {"fixture/pair": -0.5}
	check(clip.formation_value("fixture.tscn", "pair") == 1.0,
		"Negative shared override keeps compatibility fallback")
	clip.formation_values = {"fixture/pair": INF}
	check(clip.formation_value("fixture.tscn", "pair") == 1.0,
		"Nonfinite shared override keeps compatibility fallback")
	var scene: PackedScene = load("res://data/formations/telescope_reticle.tscn")
	var source_layout: Dictionary = load("res://tools/content/build_runtime_stage.gd").formation(scene).layouts[0]
	var prepared_clip := SpawnClip.new()
	prepared_clip.formations = [scene]
	prepared_clip.formation_values = {String(SpawnClip.layout_key(scene.resource_path, str(source_layout.name))): 0.0}
	var prepared = load("res://tools/content/build_runtime_stage.gd").clip(prepared_clip)
	check(prepared.prepared.size() == 1 and prepared.prepared[0].layouts[0].value == 0.0,
		"Build-time RuntimeClip keeps a zero shared override")
	var d = load("res://scripts/encounters/attack_director.gd").new()
	d.state = lab.run.state
	d.projectiles = pm
	d.formation_mode = true
	d.configure({"enabled": true, "budget": 1.5, "jitter": 0.0})
	pm.director = d
	var rows := em.ctx.spawn.spawn_formation(data, 0, 0)
	var a := rows[0]
	var b := rows[2]
	check(rows.size() == 4 and em.table.attack_group[a] == 0 and em.table.attack_group[b] == 0, "Auto keeps both spawns and uses individual owners")
	em.table.charge[a] = 0.9
	check(em._lab_admit(a, 0.016) and em._lab_admit(b, 0.016) and is_equal_approx(d.used_cost(), 1.5), "Telescope and reticle each consume their type value")
	var c := em.spawn(em.def_of(&"reticle"), Vector2.ZERO)
	check(not em._lab_admit(c, 0.016), "Another half-value individual waits at capacity")
	d.cancel_wait(em._lab_owner(c), em.table.id[c] + 10000)
	check(d.waiting.has(em._lab_owner(c)), "A different individual ID cannot cancel a shared owner's waiting entry")
	d.cancel_wait(em._lab_owner(c), em.table.id[c])
	check(d.waiting.is_empty() and d.used_cost() == 1.5, "Losing a support target cancels waiting without releasing active attacks")
	# 生きた危険範囲は、発生元が死んでも枠を保持する。
	pm.lab_context = d.token(str(em.table.id[a]))
	var h := pm.fire_wall(Vector2.ZERO, 0.0, 100.0, 10.0, 0.0, 100.0, 1.0, Color.WHITE)
	em.mark_dead(a)
	d.advance(100.0, em)
	check(d.used_cost() == 1.0, "Live hazard retains its dead source's individual budget")
	pm.release_hazard(h)
	d.advance(101.0, em)
	check(d.used_cost() == 0.0, "Budget returns after hazard disappears")
	d.waiting.clear()
	d.reasons.clear()
	rows = em.ctx.spawn.spawn_formation(data, 0, 0, [], 0.5)
	a = rows[0]
	b = rows[2]
	em.table.charge[a] = 0.9
	check(em.table.attack_group[a] > 0 and em.table.attack_group[a] == em.table.attack_group[b], "Explicit override gives the group one owner")
	check(em._lab_admit(a, 0.016) and em._lab_admit(b, 0.016) and d.used_cost() == 0.5, "Two attacking override members consume the shared cost once")
	d.groups.clear()
	d.owners.clear()
	d.waiting.clear()
	rows = em.ctx.spawn.spawn_formation(data, 0, 0, [], 0.0)
	a = rows[0]
	b = rows[2]
	em.table.charge[a] = 0.9
	check(em.table.attack_group[a] > 0 and em.table.attack_group[a] == em.table.attack_group[b]
		and em.table.attack_value[a] == 0.0 and em.table.attack_value[b] == 0.0,
		"Zero override reaches one shared group and both runtime rows")
	check(em._lab_admit(a, 0.016) and em._lab_admit(b, 0.016) and d.used_cost() == 0.0
		and d.token(em._lab_owner(a)) == 0 and d.groups.is_empty() and d.waiting.is_empty(), "value 0の群れは予算の枠と待機を作らない")
	var previous_serial: int = d.serial
	check(em._lab_admit(a, 0.016) and d.serial == previous_serial,
		"value 0の再判定でも管理用の枠を増やさない")
	d.groups.clear()
	d.owners.clear()
	d.waiting.clear()
	d.settings.budget = 0.0
	rows = em.ctx.spawn.spawn_formation(data, 0, 0, [], 0.0)
	a = rows[0]
	em.table.charge[a] = 0.9
	check(em._lab_admit(a, 0.016) and d.used_cost() == 0.0 and d.groups.is_empty() and d.waiting.is_empty(),
		"予算0でもvalue 0の群れは管理対象外として動く")
	check(stage.enemy_attack_value(&"unspecified") == 1.0, "Unspecified type uses transparent compatibility default")
	_check_light_attacks(lab)
	lab.queue_free()
	await get_tree().process_frame
	print("[attack_values] %d checks, %d failures" % [checks, failed])
	get_tree().quit(1 if failed else 0)

## 星数を条件にせず、正のvalueだけを予約し、開始済みの波動は予算減少後も保持する。
func _check_light_attacks(lab) -> void:
	var em: EnemySystem = lab.run.enemies
	var pm: ProjectileSystem = lab.run.projectiles
	em.clear_all()
	pm.clear_hostile()
	lab.run.field.bodies.clear()
	lab.run.state.ship_pos = Vector2.ZERO
	lab.run.state.enemy_aim = Vector2.ZERO
	var stage := StageDef.new()
	stage.enemy_attack_values = {"pulser": 0.5, "biter": 0.0, "bomber": 0.0}
	lab.run.state.stage = stage
	var d = load("res://scripts/encounters/attack_director.gd").new()
	d.state = lab.run.state
	d.projectiles = pm
	d.formation_mode = true
	d.configure({"enabled": true, "budget": 0.5, "jitter": 0.0})
	pm.director = d
	var a := em.spawn(em.def_of(&"pulser"), Vector2(260, 0))
	var b := em.spawn(em.def_of(&"pulser"), Vector2(260, 30))
	for row in [a, b]: em.table.fire_t[row] = 0.0
	em.tick(0.016, 0.016)
	check(em.table.mode[a] == EnemyTable.Mode.WINDUP and em.table.mode[b] == EnemyTable.Mode.MOVE,
		"星2の波動もvalue 0.5で予約し、次の波動は空くまで予告を出さない")
	check(d.used_cost() == 0.5 and d.waiting.size() == 1, "波動の予約と待機を同じ予算へ計上する")
	var token: int = d.token(em._lab_owner(a))
	check(token > 0 and pm.lab_hazard_group.values().has(token), "発生した波動を予約した枠へ結び付ける")
	d.settings.budget = 0.0
	var timer := em.table.timer[a]
	em.tick(0.016, 0.016)
	check(em.table.timer[a] < timer and em.table.mode[a] == EnemyTable.Mode.WINDUP,
		"予算が0へ下がっても開始済みの予告を続ける")
	d.advance(100.0, em)
	check(d.used_cost() == 0.5, "予算減少後も残っている波動の枠を保持する")
	pm.clear_hostile()
	em.table.mode[a] = EnemyTable.Mode.MOVE
	d.advance(101.0, em)
	check(d.used_cost() == 0.0, "予告と波動が終わった後にだけ枠を返す")
	d.waiting.clear()
	d.reasons.clear()
	var zero := em.spawn(em.def_of(&"biter"), Vector2(25, 0))
	var bomber := em.spawn(em.def_of(&"bomber"), Vector2(30, 0))
	em.tick(0.016, 0.016)
	check(em.table.mode[zero] == EnemyTable.Mode.WINDUP and em.table.mode[bomber] == EnemyTable.Mode.WINDUP,
		"value 0の雑魚は予算0でも予告へ進む")
	check(not d.waiting.has(em._lab_owner(zero)) and not d.waiting.has(em._lab_owner(bomber)),
		"value 0の雑魚を待機列へ登録しない")
	em.tick(0.4, 0.4)
	var untracked := false
	for h in pm.hazard_alive.size():
		if pm.hazard_alive[h] != 0:
			untracked = true
			check(not pm.lab_hazard_group.has(h), "value 0の攻撃を、再利用した行でも予算の追跡へ入れない")
	check(untracked, "value 0の噛みつきも実際の攻撃を生成する")
	em.clear_all()
	pm.clear_hostile()
	d.groups.clear()
	d.owners.clear()
	d.waiting.clear()
	stage.enemy_attack_values.biter = 0.5
	var paid := em.spawn(em.def_of(&"biter"), Vector2(25, 0))
	em.tick(0.016, 0.016)
	check(em.table.mode[paid] == EnemyTable.Mode.MOVE and d.waiting.has(em._lab_owner(paid)),
		"噛みつきも正のvalueなら予算0で開始を待つ")
	d.settings.budget = 0.5
	em.tick(0.016, 0.016)
	check(em.table.mode[paid] == EnemyTable.Mode.WINDUP and d.used_cost() == 0.5,
		"噛みつきも予算が空けば同じ規則で開始する")

	em.clear_all()
	pm.clear_hostile()
	d.groups.clear()
	d.owners.clear()
	d.waiting.clear()
	stage.enemy_attack_values.auriga = 0.5
	d.settings.budget = 0.0
	var driver := em.spawn(em.def_of(&"auriga"), Vector2(300, 0))
	em.table.fire_t[driver] = 0.0
	em.behavior(&"auriga").step(driver, 0.016)
	check(d.waiting.has(em._lab_owner(driver)) and d.used_cost() == 0.0,
		"移動しながら帯を出す敵も正のvalueなら発生前に予算を待つ")
	d.settings.budget = 0.5
	em.behavior(&"auriga").step(driver, 0.016)
	check(d.used_cost() == 0.5 and pm.lab_hazard_group.values().has(d.token(em._lab_owner(driver))),
		"帯も許可後は同じ枠で追跡する")
