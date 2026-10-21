extends Node

func _ready() -> void:
	verify()

func verify() -> void:
	var s := RunState.new()
	s.lab_mode = true
	var cfg: GameConfig = load("res://data/config.tres")
	var em := EnemyManager.new()
	var combat := CombatManager.new()
	var build := BuildManager.new()
	em.setup(s, cfg)
	combat.setup(s, cfg)
	build.state = s
	build.cfg = cfg
	combat.enemies = em
	combat.build = build
	build.enemies = em
	build.combat = combat
	var definition := EnemyDef.new()
	definition.id = &"arc_probe"
	definition.radius = 10.0
	definition.hp = 1000.0
	var target := em.spawn(definition, Vector2.ZERO)
	for pos in [Vector2(40,0),Vector2(80,0),Vector2(120,0),Vector2(160,0),
		Vector2(-60,0),Vector2(-100,0),Vector2(-140,0),Vector2(-180,0),
		Vector2(0,-50),Vector2(0,-90),Vector2(0,-130),Vector2(0,-170)]:
		em.spawn(definition, pos)
	var meteor := em.spawn(definition, Vector2(0,30))
	em.table.meteor_index[meteor] = 0
	var dead := em.spawn(definition, Vector2(0,20))
	em.table.dead[dead] = 1
	combat.rebuild_grid()
	var arc = load("res://scripts/weapons/contactArc.gd").new()
	arc.setup(build, load("res://data/weapons/W17_contactArc.tres"))
	var visual_segments := PackedVector2Array()
	for lv in [1,5]:
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
		assert(roots.size() == mini(3,lv*2), "Branches missing")
		for i in roots.size():
			for j in range(i+1,roots.size()):
				assert(absf(roots[i].angle_to(roots[j])) >= deg_to_rad(60.0)-0.001, "Roots not separated")
		print("W17 Lv",lv,": ",ids.size()," unique hits; ",roots.size()," separated roots; damage and segments OK")
		visual_segments = segments
	# One isolated contact must terminate without searching forever.
	em.clear_all()
	target = em.spawn(definition, Vector2.ZERO)
	combat.rebuild_grid()
	s.events.clear()
	arc.on_any_contact(target)
	assert(s.events.back().segments.size() == 2)
	print("W17 isolated target: OK")
	if "--visual" in OS.get_cmdline_user_args():
		await show_visual(build, s, cfg, visual_segments)
	em.free()
	combat.free()
	build.free()
	get_tree().quit()

func show_visual(build: BuildManager, state: RunState, cfg: GameConfig, segments: PackedVector2Array) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 500)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var run := RunManager.new()
	run.build = build
	var renderer := RenderManager.new()
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
	run.free()
	viewport.queue_free()
