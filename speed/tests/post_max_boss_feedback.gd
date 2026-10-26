## 追加成長の武器弾を共有戦闘経路から両ボスへ当て、実HP減少と表示だけの反応を確認する。
extends "res://tests/post_max_progression.gd"

func _ready() -> void:
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	var saved := JSON.stringify(SaveManager.data)
	for boss_id in ["monoceros", "draco"]:
		var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
		stage.boss_enabled = false
		scene = RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 5, "seed": 42}, false)
		scene.auto_step = false
		run = scene.sim
		run.field.bodies.clear()
		run.field.rocks.clear()
		_equip([&"W01", &"W03", &"W08", &"W17"])
		for i in 5: _check(run.loadout.post_max.select(&"weapon_damage"), "武器威力の追加成長を取得")
		for i in 10: _check(run.loadout.post_max.select(&"crit_chance"), "追加クリティカルを取得")
		for i in 3: run.loadout.grant(&"trait", &"T09")
		run.loadout.refresh_stats()
		run.bosses.spawn(load("res://data/bosses/" + boss_id + ".tres"), Vector2.ZERO)
		var actor: BossActor = run.bosses.actor
		actor.selection_enabled = false
		var row := actor.body
		run.enemies.table.guard[row] = 0.0
		run.state.controls_locked = false
		run.state.encounter_protected = false
		var origin: Vector2 = run.enemies.table.pos[row]
		var facing: float = run.enemies.table.facing[row]
		var hp: float = run.enemies.table.hp[row]
		var weapon: WeaponBehavior = run.loadout.weapon_behaviors[&"W01"]
		var damage := weapon.atk()
		_check(is_equal_approx(damage, run.combat.attack_power() * 1.1), "武器威力は追加分を一度だけ適用: " + boss_id)
		weapon.fire_shot(origin, 0.0, damage, {"speed": 10.0, "knock": 0.0})
		run.combat.rebuild_grid()
		run.projectiles._update_friendly(0.01)
		_check(is_equal_approx(hp - run.enemies.table.hp[row], damage), "追加成長の弾が実HPを一度だけ減らす: " + boss_id)
		_check(float(actor.hit_feedback.sample(actor.body_id).white) > 0.0, "実際に命中したボスだけが反応: " + boss_id)
		_check(run.enemies.table.pos[row] == origin and run.enemies.table.facing[row] == facing, "被弾表示で判定と照準を変えない: " + boss_id)
		_check(is_equal_approx(run.state.stats.crit_chance, 0.3), "武器命中後もT09予約と追加上限を維持")
		run.set_phase(RunState.Phase.PAUSED)
		scene._process(0.13)
		_check(actor.hit_feedback.remaining.is_empty(), "停止した世界でも表示パルスを解放: " + boss_id)
		_check(run.state.post_max_stacks[&"weapon_damage"] == 5, "表示の更新で追加成長を変えない")
		_check(JSON.stringify(SaveManager.data) == saved, "命中・被弾表示を永続セーブへ漏らさない")
		await _close()
	print("[post_max_boss_feedback] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
