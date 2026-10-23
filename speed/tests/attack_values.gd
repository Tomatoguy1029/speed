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
	clip.formation_values = {"fixture/pair": 3}
	const SAVE := "/tmp/speed-attack-values-fixture.tres"
	check(ResourceSaver.save(clip, SAVE) == OK, "Legacy integer fixture saves")
	var loaded: SpawnClip = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.formation_value("fixture.tscn", "pair") == 3.0 and loaded.formation_values["fixture/pair"] is int, "Legacy integer is preserved as explicit shared override")
	check(loaded.formation_value("fixture.tscn", "other") < 0.0, "Missing override uses individual accounting")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
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
	check(stage.enemy_attack_value(&"unspecified") == 1.0, "Unspecified type uses transparent compatibility default")
	lab.queue_free()
	await get_tree().process_frame
	print("[attack_values] %d checks, %d failures" % [checks, failed])
	get_tree().quit(1 if failed else 0)
