## 猟犬の群れ・欠員・冠からの復帰を、セーブを書かずに確かめる。
extends Node

var failed := 0
var passed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("[hound] " + label)

func _ready() -> void:
	if not ResourceLoader.exists("res://data/enemies/hound.tres"):
		check(false, "猟犬の専用定義がある")
		_finish()
		return
	# 空の実験場と同じ生成口を使い、他担当の生成キャッシュ更新と独立して確かめる。
	var stage = load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(3))
	var cfg := ContentManager.base.duplicate(true) as GameConfig
	for key in ["moon_count", "meteor_count", "iron_count", "saw_count"]: cfg.set(key, 0)
	var capture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
	var session := RunManager.create_session(self, {"lab": true, "seed": 42, "stage": stage, "config": cfg}, not capture.is_empty())
	session.auto_step = false
	var m := session.sim.enemies
	var t := m.table
	m.field.bodies.clear()
	m.field.planet.pos = Vector2(1e7, 1e7)
	m.field.planet.r = 0.0
	m.field.refresh_bodies()
	m.state.view_center = Vector2.ZERO
	m.state.ship_pos = Vector2(700, 0)
	var def := load("res://data/enemies/hound.tres") as EnemyDef
	var first := m.spawn(def, Vector2.ZERO)
	var dogs := m.behavior(&"hound")
	var members := dogs.rows().duplicate()
	check(members.size() == int(def.params.pack_count), "一度の出現で指定数の群れを作る")
	check(def.speed > m.def_of(&"biter").speed and def.rank == 1 and def.gate == &"", "普通に倒せる、噛みつく雑魚より速い星1の雑魚")
	m.tick(0.02, 0.02)
	check(t.vel[first].x > 0.0, "群れで機体を追う")
	m.mark_dead(first)
	m.cleanup()
	m.tick(0.02, 0.02)
	check(dogs.rows().size() == members.size() - 1 and t.vel[members[1]].x > 0.0, "最初の個体が倒れても残りで追い続ける")
	for row in dogs.rows().duplicate(): m.mark_dead(row)
	m.cleanup()
	check(dogs.packs.is_empty() and dogs.members.is_empty(), "全滅した群れの状態を残さない")
	m.spawn(def, Vector2.ZERO)
	check(dogs.rows().size() == int(def.params.pack_count), "死亡行を再利用して新しい群れを作れる")
	m.clear_all()
	check(dogs.packs.is_empty() and dogs.members.is_empty(), "全消去で群れの状態を消す")
	_test_alignment(m, def)
	_test_bite(m, def)
	_test_crown(session.sim, def)
	var render := RunPresentation.new()
	render.run = session.sim
	render.state = m.state
	render.cfg = cfg
	var visual := render._visual_for_type(&"hound")
	check(visual != null and visual.get_script().resource_path == "res://scripts/render/enemies/hound.gd", "猟犬専用の仮表示を自動ロードする")
	render.free()
	if not capture.is_empty():
		m.projectiles.clear_hostile()
		m.state.ship_pos = Vector2(200, 0)
		m.state.view_center = Vector2.ZERO
		m.spawn(def, Vector2(-40, 0))
		m.spawn(def, Vector2(-160, 100))
		for step in 10: m.tick(0.02, 0.02)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(capture) == OK, "仮表示の画面を保存する")
	session.free()
	await get_tree().process_frame
	_finish()

func _test_alignment(m: EnemySystem, source: EnemyDef) -> void:
	var def := source.duplicate(true) as EnemyDef
	def.params.pack_count = 2
	def.params.pack_alignment = 1.0
	def.params.pack_cohesion = 0.0
	def.params.pack_separation = 0.0
	m.state.ship_pos = Vector2(10000, 0)
	var a := m.spawn(def, Vector2.ZERO)
	var rows := m.behavior(&"hound").rows().duplicate()
	var b: int = rows[1]
	m.table.vel[a] = Vector2(160, 0)
	m.table.vel[b] = Vector2(0, 40)
	var initial := m.table.vel[a].distance_to(m.table.vel[b])
	for step in 30: m.tick(0.02, 0.02)
	check(m.table.vel[a].distance_to(m.table.vel[b]) < initial * 0.1 \
		and m.table.vel[a].y > 5.0 and m.table.vel[b].x > 50.0, "近くの仲間と速さ・進行方向をそろえる")
	for flag in ["held", "stone", "knock_t", "shove_time"]:
		m.table.pos[a] = Vector2.ZERO
		m.table.pos[b] = Vector2(0, 40)
		m.table.vel[a] = Vector2(160, 0)
		m.table.vel[b] = Vector2(0, 2000)
		var values = m.table.get(flag)
		values[b] = 1
		m.table.set(flag, values)
		m.tick(0.02, 0.02)
		check(is_zero_approx(m.table.vel[a].y), "通常走行を止めた仲間の速度を同期に含めない: " + flag)
		values = m.table.get(flag)
		values[b] = 0
		m.table.set(flag, values)
	m.table.pos[a] = Vector2.ZERO
	m.table.pos[b] = Vector2(0, 40)
	m.table.vel[a] = Vector2(160, 0)
	m.table.vel[b] = Vector2(0, 2000)
	m.table.mode[b] = EnemyTable.Mode.WINDUP
	m.table.timer[b] = 1.0
	m.tick(0.02, 0.02)
	check(is_zero_approx(m.table.vel[a].y), "噛みつきを構えた仲間は同期から外れ、攻撃を続ける")
	m.table.mode[b] = EnemyTable.Mode.MOVE
	m.table.pos[b] = Vector2(0, 500)
	m.table.vel[a] = Vector2(160, 0)
	m.table.vel[b] = Vector2(0, 40)
	m.tick(0.1, 0.1)
	check(absf(m.table.vel[a].y) < 1.0, "近傍の範囲を外れた仲間とは同期しない")
	m.clear_all()
	def.params.pack_count = 1
	a = m.spawn(def, Vector2.ZERO)
	b = m.spawn(def, Vector2(0, 40))
	m.table.vel[b] = Vector2(0, 40)
	m.tick(0.1, 0.1)
	check(is_zero_approx(m.table.vel[a].y), "別の群れの個体と群れ状態を混ぜない")
	m.clear_all()
	def = source.duplicate(true) as EnemyDef
	def.params.pack_count = 2
	a = m.spawn(def, Vector2(0, -60))
	b = m.behavior(&"hound").rows()[1]
	m.table.pos[b] = Vector2(0, 60)
	for step in 50: m.tick(0.02, 0.02)
	check(absf(m.table.pos[a].y - m.table.pos[b].y) < 110.0, "生存個体が近くの仲間へ寄り、ひとかたまりを保つ")
	m.clear_all()

func _test_bite(m: EnemySystem, source: EnemyDef) -> void:
	var def := source.duplicate(true) as EnemyDef
	def.params.pack_count = 1
	var base := m.def_of(&"biter")
	for key in ["bite_radius", "bite_reach", "bite_rest", "bite_telegraph", "bullet_dmg"]:
		check(def.params[key] == base.params[key], "噛みつきの共通値: " + key)
	m.state.ship_pos = Vector2(25, 0)
	var row := m.spawn(def, Vector2.ZERO, {"vel": Vector2.ZERO})
	m.tick(0.01, 0.01)
	check(m.table.mode[row] == EnemyTable.Mode.WINDUP and m.table.flash[row] > 0.0, "近づくと光って噛みつきを予告する")
	m.tick(float(def.params.bite_telegraph), float(def.params.bite_telegraph))
	check(m.table.mode[row] == EnemyTable.Mode.RECOVER, "予告後に既存噛みつきを出して回復へ進む")
	var bite := false
	for i in m.projectiles.hazard_alive.size():
		if m.projectiles.hazard_alive[i] and m.projectiles.hazard_style[i] == ProjectileSystem.HazardStyle.BITE:
			bite = is_equal_approx(m.projectiles.hazard_dmg[i], float(def.params.bullet_dmg))
	check(bite, "噛みつきの既存範囲攻撃・威力を使う")
	m.clear_all()

func _test_crown(run: RunSimulation, source: EnemyDef) -> void:
	var m := run.enemies
	var t := m.table
	var crown := m.spawn(m.def_of(&"corona"), Vector2.ZERO)
	var first := m.spawn(source, Vector2(0, 100))
	var dogs := m.behavior(&"hound")
	var group := dogs.rows().duplicate()
	var ids := {}
	for row in group: ids[row] = t.id[row]
	m.state.ship_pos = Vector2(650, 0)
	t.fire_t[crown] = 0.0
	run.combat.rebuild_grid()
	m.tick(0.02, 0.02)
	var vortex = m.behavior(&"corona").vortex
	check(vortex.members.size() == group.size() and t.held[first] == 1, "冠は生成済み猟犬の群れを捕捉する")
	var held_at := t.pos[first]
	dogs.tick_rows(dogs.rows(), 0.1)
	check(t.pos[first] == held_at, "捕捉中は通常の群れ行動・噛みつきを止める")
	var selected := int(vortex.owners[crown].selected)
	m.mark_dead(selected)
	m.cleanup()
	check(not vortex.members.has(selected) and dogs.rows().size() == group.size() - 1, "冠の予告中に猟犬を倒すと投擲と群れの両方から外れる")
	var thrown := -1
	for step in 160:
		m.tick(0.06, 0.06)
		run.combat.rebuild_grid()
		for row in vortex.members:
			if vortex.members[row].thrown: thrown = row
		if thrown >= 0: break
	check(thrown >= 0 and t.id[thrown] == ids.get(thrown, -1), "群れの既存個体を複製せず投擲する")
	if thrown >= 0:
		vortex.members[thrown].life = 0.01
		m.tick(0.02, 0.02)
		check(t.held[thrown] == 0 and t.dead[thrown] == 0 and dogs.members.has(thrown), "投擲時間切れで同じ生存個体が元の群れに戻る")
	m.mark_dead(crown)
	m.cleanup()
	check(vortex.members.is_empty(), "冠の撃破で保持・投擲を全て解放する")
	for row in dogs.rows():
		check(t.held[row] == 0 and t.id[row] == ids.get(row, -1), "冠撃破後も元の生存個体と群れを保つ")
	m.tick(0.02, 0.02)
	check(not dogs.packs.is_empty(), "冠の解放後も残りで追跡を再開する")
	m.clear_all()

func _finish() -> void:
	print("[hound] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
