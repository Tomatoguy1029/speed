## W17 の Lv ごとの全周分布・命中上限・片側配置・枝ごとの描画を短時間で確認する。
extends Node

func _ready() -> void:
	verify()

func verify() -> void:
	var s := RunState.new()
	s.lab_mode = true
	var cfg: GameConfig = load("res://data/config.tres")
	var em := EnemySystem.new()
	var combat := CombatSystem.new()
	var build := LoadoutSystem.new()
	var context := RunContext.new()
	context.state = s
	context.cfg = cfg
	context.enemies = em
	context.combat = combat
	context.loadout = build
	em.setup(context)
	combat.setup(context)
	build.ctx = context
	build.state = s
	build.cfg = cfg
	var definition := EnemyDef.new()
	definition.id = &"arc_probe"
	definition.radius = 10.0
	definition.hp = 1000.0
	var target := em.spawn(definition, Vector2.ZERO)
	# 全周の候補と、一方向だけに偏った近い候補を混ぜる。
	for k in 40:
		em.spawn(definition, Vector2.from_angle(k * TAU / 40.0 + 0.07) * 140.0)
	for distance in [40.0, 60.0, 80.0]:
		em.spawn(definition, Vector2(distance, 0))
	var meteor := em.spawn(definition, Vector2(0,30))
	em.table.meteor_index[meteor] = 0
	var dead := em.spawn(definition, Vector2(0,20))
	em.table.dead[dead] = 1
	combat.rebuild_grid()
	var arc = load("res://scripts/weapons/contactArc.gd").new()
	arc.setup(context, load("res://data/weapons/W17_contactArc.tres"))
	var visual_segments := PackedVector2Array()
	for lv in range(1, 6):
		arc.level = lv
		s.events.clear()
		arc.on_any_contact(target)
		var ids := {}
		var segments := PackedVector2Array()
		for e in s.events:
			if e.type == &"hit":
				assert(not ids.has(e.id), "Duplicate enemy hit")
				ids[e.id] = true
				assert(is_equal_approx(e.dmg, 10.0 * 0.325 * arc.dmg_k()), "Damage changed")
			if e.type == &"bolt": segments = e.segments
		assert(ids.size() == 1 + lv * 2, "Shared target cap changed")
		assert(not ids.has(em.table.id[meteor]) and not ids.has(em.table.id[dead]), "Invalid target")
		assert(segments.size() == 2 * ids.size(), "Segment endpoints missing")
		var roots: Array[Vector2] = []
		for k in range(2, segments.size(), 2):
			if segments[k] == Vector2.ZERO: roots.append(segments[k+1])
		assert(roots.size() == lv * 2, "Branches must grow with level")
		var sectors := {}
		var width := TAU / (lv * 2)
		for pos in roots:
			var sector := int(floor(fposmod(pos.angle() + width * 0.5, TAU) / width)) % (lv * 2)
			assert(not sectors.has(sector), "One direction used multiple initial branches")
			sectors[sector] = true
		if lv == 5:
			var angles: Array[float] = []
			for pos in roots: angles.append(fposmod(pos.angle(), TAU))
			angles.sort()
			for k in angles.size():
				var gap := fposmod(angles[(k + 1) % angles.size()] - angles[k], TAU)
				assert(gap < TAU / 5.0, "Lv5 left a wide empty arc despite surrounding enemies")
		print("W17 Lv", lv, ": ", ids.size(), " unique hits; ", roots.size(), " occupied angular sectors; damage OK")
		visual_segments = segments
	# 片側しか敵がいないときも全対象枠を使え、架空の命中先を作らない。
	em.clear_all()
	target = em.spawn(definition, Vector2.ZERO)
	for k in 12: em.spawn(definition, Vector2(40.0 + k * 15.0, 0))
	combat.rebuild_grid()
	s.events.clear()
	arc.on_any_contact(target)
	var one_side_hits := 0
	for e in s.events:
		if e.type == &"hit": one_side_hits += 1
	assert(one_side_hits == 11, "Unused sectors lost the shared target budget")
	for pos in s.events.back().segments:
		assert(pos.x >= 0.0 and pos.y == 0.0, "Invented a target on an empty side")
	print("W17 one-sided crowd: 11 hits, all on the occupied side")
	# 孤立した対象でも正常に終了する。
	em.clear_all()
	target = em.spawn(definition, Vector2.ZERO)
	combat.rebuild_grid()
	s.events.clear()
	arc.on_any_contact(target)
	assert(s.events.back().segments.size() == 2)
	print("W17 isolated target: OK")
	if "--visual" in OS.get_cmdline_user_args():
		await show_visual(build, s, cfg, visual_segments)
	for system in [em, combat, build]:
		system.dispose()
	get_tree().quit()

func show_visual(build: LoadoutSystem, state: RunState, cfg: GameConfig, segments: PackedVector2Array) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 500)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var run := RunSimulation.new()
	run.ctx = build.ctx
	var renderer := RunPresentation.new()
	renderer.run = run
	renderer.state = state
	renderer.cfg = cfg
	renderer._on_events([{"type": &"bolt", "segments": segments}])
	renderer.bolts[0].life = 0.16
	var layer := DrawLayer.new()
	layer.position = Vector2(250, 300)
	layer.draw_fn = renderer._draw_fx
	viewport.add_child(layer)
	var preview := ModulePreview.new()
	preview.position = Vector2(500, 100)
	preview.size = Vector2(480, 300)
	preview.setup(load("res://data/weapons/W17_contactArc.tres"), true)
	viewport.add_child(preview)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("/tmp/speed-contact-arc-branches.png")
	print("Production bolt rendering and module preview: /tmp/speed-contact-arc-branches.png")
	renderer.free()
	viewport.queue_free()
