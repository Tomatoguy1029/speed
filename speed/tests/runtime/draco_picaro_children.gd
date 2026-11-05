extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func _ready() -> void:
	if "--cpp-draco-picaro" in OS.get_cmdline_user_args() or "--cpp-draco-picaro-orphan" in OS.get_cmdline_user_args():
		call_deferred("native_picaro")
		return
	call_deferred("native_picaro")

func native_picaro() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var package: Dictionary = builder.boss_body_package(load("res://data/bosses/draco.tres"),cfg)
	var names := ["triangle","triangle_star","cepheus","cepheus_soldier","biter"]
	for name in names:
		var source: Dictionary = builder.chase_package(load("res://data/enemies/"+name+".tres"),cfg)
		var id: int = package.records.EnemyRecord.size()+1
		var row: Dictionary = source.records.EnemyRecord[0].duplicate(true)
		row.id = id
		row.visual_id = package.records.ResourceKey.size()+1
		package.records.EnemyRecord.append(row)
		package.records.StringEntry.append({"id":id,"value":name})
		package.records.DefinitionIndex.append({"id":id,"enemy":id})
		package.records.PopulationType.append({"id":id,"enemy":id,"rank":1,"maximum":10,"ranged":false})
		for record: Dictionary in builder.Schema.SCHEMA.records:
			if record.fields[0].get("ref","")!="EnemyRecord": continue
			for original: Dictionary in source.records[record.name]:
				var item := original.duplicate(true)
				item.id = id
				if record.name=="TriangleDefinition": item.star = 3
				if record.name=="CepheusDefinition": item.soldier = 5
				package.records[record.name].append(item)
		var look: Dictionary = source.records.FriendHullLook[0].duplicate(true)
		look.id = package.records.FriendHullLook.size()+1
		look.enemy = id
		package.records.FriendHullLook.append(look)
		var visual: Dictionary = source.visuals[5].duplicate(true)
		visual.id = row.visual_id
		if not visual.path.is_empty():
			var resource = load(visual.path)
			if resource is EnemyLook: visual.hull_preview = resource.preview_key(load("res://data/enemies/"+name+".tres").armor_colors)
		package.visuals.append(visual)
		package.records.ResourceKey.append({"id":visual.id,"role":visual.role})
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(package.records,"0".repeat(64).hex_decode())
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":179,"mode":1,"stage_id":"B_draco_picaro","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"ピカロの元敵とドラコを同じ生成データへ読む")
	if not configured.ok: print(configured);get_tree().quit(1);return
	bridge.start(505,{"position":Vector2(1400,0),"lab_mode":true})
	bridge.subscribe("確認",func(_frame): return true)
	bridge._core.set_motion_context(Vector2(1400,0),Vector2(600,0),Vector2(1200,900))
	var boss: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var member: int = bridge.command("dev_draco_picaro",{"entity_id":boss,"operation":"spawn","source":"triangle","position":Vector2(700,0)}).value
	if "--cpp-draco-picaro-orphan" in OS.get_cmdline_user_args():
		var old_parts: PackedInt64Array = bridge.command("dev_boss_body_state").value[0].picaro.filter(func(m):return m.id==member)[0].parts
		bridge._core.remove_enemy(member)
		var fresh: int = bridge._core.spawn_enemy(&"biter",Vector2(3000,0))
		var fresh_hp: float = bridge._core.enemies_snapshot().filter(func(e):return e.id==fresh)[0].hp
		bridge._core.step(0.02)
		var live: Array = bridge.command("dev_boss_body_state").value[0].picaro
		check(live.all(func(m):return not old_parts.has(m.id)),"親の行が解放されても保持した部位を残さない")
		bridge.command("dev_damage",{"entity_id":old_parts[0],"amount":10.0,"cause":"bullet"})
		check(bridge._core.enemies_snapshot().filter(func(e):return e.id==fresh)[0].hp==fresh_hp,"行が再利用されても古い部位から別の敵へ命中しない")
		bridge.dispose()
		print("[B_draco_picaro_orphan] failures=",failures)
		get_tree().quit(1 if failures else 0)
		return
	bridge._core.step(0.01)
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var tri: Dictionary = body.picaro.filter(func(m):return m.id==member)[0]
	check(body.picaro.size()==4 and tri.parts.size()==3 and tri.held and tri.guard==1.0,"生成中の保護と部位の保持、同IDの重複除去")
	var part_ids: PackedInt64Array = tri.parts.duplicate()
	var scope := ContentResourceScope.new()
	for visual: Dictionary in package.visuals:
		if not visual.path.is_empty(): scope.provide(visual.path,load(visual.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = []
	entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	var packet: Dictionary = bridge.read_render(Rect2(-3000,-2000,6000,4000)).value
	check(view.apply_frame(packet) and view._picaro_sprites.size()==4,"本体と子を既存のコズミックshaderで表示する")
	check(view._picaro_sprites[member].modulate.a==1.0 and view._picaro_sprites[member].get_parent().z_index==8,"形成中は不透明で敵の描画順を保つ")
	await get_tree().process_frame
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"形成中の所有者・子・保護を保持する")
	bridge._core.step(2.6)
	var after: Array = bridge.command("dev_boss_body_state").value[0].picaro
	check(bridge.restore(held.value).ok,"形成中の値状態を復帰する")
	bridge._core.step(2.6)
	check(bridge.command("dev_boss_body_state").value[0].picaro==after,"復帰後も同じ時刻に子を解放する")
	bridge.release_checkpoint(held.value)
	tri = bridge.command("dev_boss_body_state").value[0].picaro.filter(func(m):return m.id==member)[0]
	check(not tri.held and tri.guard==0.0,"形成が終わると戦闘半径を変えず保護を解く")
	bridge._core.remove_enemy(member)
	bridge._core.step(0.02)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.picaro.all(func(m):return not part_ids.has(m.id)),"親の行が解放されても保持した部位を残さない")
	bridge.command("dev_draco_picaro",{"entity_id":boss,"operation":"clear"})
	bridge.command("dev_draco_picaro",{"entity_id":boss,"operation":"spawn","source":"cepheus","position":Vector2(700,0)})
	for frame in 300: bridge._core.step(1.0/60.0)
	body = bridge.command("dev_boss_body_state").value[0]
	var soldiers: Array = body.picaro.filter(func(m):return m.source_type==&"cepheus_soldier")
	check(not soldiers.is_empty(),"元の王の実際の行動で同じ所有者のコズミック兵を召喚する")
	bridge.command("dev_draco_picaro",{"entity_id":boss,"operation":"pause","cancel":true})
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.picaro.all(func(m):return m.held and m.mode==0 and m.velocity==Vector2.ZERO),"攻撃担当の停止は兵の移動と所有hazardにも適用する")
	bridge.command("dev_cancel_boss",{"entity_id":boss})
	check(bridge.command("dev_boss_body_state").value[0].picaro.is_empty(),"中断で所有する子と部位を解放する")
	view.free()
	bridge.dispose()
	print("[B_draco_picaro] failures=",failures)
	get_tree().quit(1 if failures else 0)
