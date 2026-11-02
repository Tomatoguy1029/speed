extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func _ready() -> void:
	if "--cpp-draco-picaro" in OS.get_cmdline_user_args() or "--cpp-draco-picaro-orphan" in OS.get_cmdline_user_args():
		call_deferred("native_picaro")
		return
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true);stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":505},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var a=sim.bosses.actor
	var row: int=a.picaro.spawn_picaro(&"triangle",Vector2(700,0))
	var parts: PackedInt32Array=a.table.parts[row].duplicate()
	sim.enemies.mark_dead(row);sim.enemies.cleanup();a.picaro.tick()
	for j in range(0,parts.size(),2):check(not sim.enemies.is_same(parts[j],parts[j+1]) or a.table.dead[parts[j]]!=0,"親の行が解放されても、保持した部位を残さない")
	a.picaro.clear()
	a.picaro.spawn_picaro(&"cepheus",Vector2(700,0))
	for frame in 300:
		sim.enemies.tick(1.0/60.0,1.0/60.0)
		a.sim_tick(1.0/60.0,1.0/60.0)
	var soldiers: Array=[]
	for i in a.table.alive.size():
		if a.table.alive[i]!=0 and a.table.dead[i]==0 and a.table.type[i]==&"cepheus_soldier":soldiers.append(i)
	check(not soldiers.is_empty(),"元の王の行動で兵を召喚する")
	for soldier: int in soldiers:check(a.table.def[soldier].params.get("picaro",false),"召喚した兵も同じコズミック版になる")
	a.picaro.pause(true)
	for soldier: int in soldiers:check(a.table.held[soldier]!=0,"攻撃担当の停止は増援にも適用する")
	a.picaro.clear();a.cancel_attack();a.cycle.cancel()
	a.start_attack(&"clones")
	var driver=a._runner
	var copy: int=driver.units[1].row
	var part: int=driver.units[1].parts[0].row
	a.table.pos[driver.units[1].parts[-1].row]=a.table.pos[copy]+Vector2(-500,0)
	check(sim.bosses.contains_target(copy,a.table.pos[driver.units[1].parts[-1].row],0.0),"複製も尾まで同じ対象の内部として扱う")
	sim.enemies.mark_dead(copy);sim.enemies.cleanup()
	var fresh:=sim.enemies.spawn(sim.enemies.def_of(&"biter"),Vector2(3000,0))
	var hp: float=a.table.hp[fresh]
	sim.combat.damage_enemy(part,10.0,{"cause":&"shot"})
	check(a.table.hp[fresh]==hp,"行が再利用されても複製の古い部位から別の敵へ命中しない")
	a.cancel_attack();a.picaro.clear()
	session.free()
	print("[draco_picaro_children] failures=",failures)
	get_tree().quit(1 if failures else 0)

## 既存の親行解放・兵への継承・停止・古い部位の確認をC++へつなぐ。
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
	check(view._picaro_sprites[member].modulate.a<0.71 and view._picaro_sprites[member].get_parent().z_index==8,"形成の透明度と敵の描画順を保つ")
	await get_tree().process_frame
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"形成中の所有者・子・保護を保持する")
	bridge._core.step(1.1)
	var after: Array = bridge.command("dev_boss_body_state").value[0].picaro
	check(bridge.restore(held.value).ok,"形成中の値状態を復帰する")
	bridge._core.step(1.1)
	check(bridge.command("dev_boss_body_state").value[0].picaro==after,"復帰後も同じ時刻に子を解放する")
	bridge.release_checkpoint(held.value)
	tri = bridge.command("dev_boss_body_state").value[0].picaro.filter(func(m):return m.id==member)[0]
	check(not tri.held and tri.guard==0.0,"1秒後に戦闘半径を変えず保護を解く")
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
