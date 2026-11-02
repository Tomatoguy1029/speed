## 回収物ごとの取得効果を同じ入口で適用できる。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	if "--cpp-pickups-tail" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_pickups_tail()
		check(finished,"取得入口の後半を最後まで実施する")
		print("[cpp_pickups_tail] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

	if "--cpp-pickups" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_pickups()
		if finished: finished = await check_cpp_pickups_tail()
		check(finished,"取得入口の確認を最後まで実施する")
		print("[cpp_pickups] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

	if "--cpp-cargo-record" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_cargo_record()
		check(finished,"運搬記録の出所を最後まで照合する")
		print("[cpp_cargo_record] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

	if "--cpp-cargo" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_cargo()
		check(finished,"結晶の運搬の確認を最後まで実施する")
		print("[cpp_cargo] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

	if "--cpp-cap" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_cap()
		check(finished,"上限集約の確認を最後まで実施する")
		print("[cpp_cap] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-reward" in OS.get_cmdline_user_args() or "--cpp-reward-view" in OS.get_cmdline_user_args():
		if "--cpp-reward-view" not in OS.get_cmdline_user_args(): await check_cpp_reward()
		var finished: bool = await check_cpp_reward_view()
		check(finished,"表示側の関係ケースを最後まで実施する")
		print("[cpp_reward] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	var pickups := sim.pickups
	check(pickups.has_method("effect"), "回収物ごとの効果を取得できる")
	if pickups.has_method("effect"):
		var coins := sim.state.coins
		pickups.collect(&"coin")
		check(sim.state.coins == coins + 1, "部品を1つ増やす")
		var xp := sim.state.xp_gained
		pickups.collect(&"gem", 1.0)
		check(sim.state.xp_gained > xp, "結晶の経験値を反映する")
		sim.state.ship_hp = 1.0
		var capsule := Pickup.new()
		capsule.kind = Pickup.Kind.HEAL
		pickups._apply(capsule)
		check(sim.state.ship_hp > 1.0, "回復カプセルがHPを回復する")
		sim.state.ship_hp = sim.state.stats.max_hp
		check(not pickups.effect(&"heal").can_collect(capsule), "HP満タンでは回復カプセルを吸い寄せない")
		capsule.kind = Pickup.Kind.COMET_WEAPON
		capsule.weapon_id = &"W21"
		pickups._apply(capsule)
		check(sim.state.pending_comet_weapons.has(&"W21"), "彗星武器の受け取りを予約する")
	session.free()
	await get_tree().process_frame
	print("[pickup_effects] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func reward_bridge(definition: EnemyDef,config: GameConfig):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var bytes: PackedByteArray = builder.compile_chase(definition,config,schema.sha256("固定報酬の撃破".to_utf8_buffer()))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	if not bridge.configure(bytes,{"api_version":1,"run_id":91,"mode":1,"stage_id":"reward","profile":{},"settings":{}}).ok:
		check(false,"固定報酬と散乱の定義を生成する")
		return null
	check(bridge.start(931,{"position":Vector2(-3000,0)}).ok,"固定場面を開始する")
	return bridge

func reward_counts(gems: Array) -> Array[int]:
	var counts: Array[int] = [0,0,0]
	for gem: Dictionary in gems: counts[int(gem.kind)]+=1
	return counts

func check_cpp_reward() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.strong_gold_chance = 1.0
	var base: EnemyDef = ContentManager.enemies[&"drifter"]
	var cases: Array[Dictionary] = []
	for rank in [0,1,2,3,5,10,11]: cases.append({"rank":rank})
	cases.append({"rank":3,"override":PackedInt32Array([2,3,4])})
	cases.append({"rank":2,"override":PackedInt32Array([0,1,0])})
	cases.append({"rank":7,"override":PackedInt32Array([0,0,0])})
	for sample: Dictionary in cases:
		var definition: EnemyDef = base.duplicate(true)
		definition.rank = sample.rank
		definition.xp_reward_counts = sample.get("override",PackedInt32Array())
		var reward := definition.resolve_xp_reward()
		var expected: Array[int] = [int(reward.counts[0]),int(reward.counts[1]),int(reward.counts[2])]
		if reward.gold_eligible: expected[2]+=1
		var bridge = reward_bridge(definition,config)
		if bridge==null: return
		var records: Array = []
		bridge.subscribe("reward",func(frame):
			records.append_array(frame.events)
			return true)
		for elite in [false,true]:
			var id: int = bridge._core.spawn_enemy(definition.id,Vector2(-1000,500),{"elite":elite,"size":32.0 if elite else 16.0})
			check(id>0,"通常・大きさの異なるエリートを生成する")
			var killed: Dictionary = bridge.command("dev_kill",{"entity_id":id,"cause":"shot"})
			check(killed.ok and killed.value.killed,"共通の実撃破で報酬を供給する")
			var snapshot: Dictionary = bridge._core.pickups_snapshot()
			var gems: Array = snapshot.gems.filter(func(gem): return gem.origin.enemy_id==id)
			check(reward_counts(gems)==expected,"星数・上書きの固定報酬は通常/エリートで同じ Rank%d" % definition.rank)
			for gem: Dictionary in gems:
				check(gem.id>0 and gem.base_xp==float(config.xp_crystal_values[gem.kind]),"大きさ・機体倍率やエリートを基準XPへ掛けない")
				check(gem.origin.enemy==definition.id and gem.origin.spawn_t==0.0 and gem.origin.spawn_world_t==0.0,"結晶の出所と生成時の時計を残す")
			var rolls: int = snapshot.xp_statistics.gold_rolls
			check(rolls==(2 if elite else 1) if reward.gold_eligible else rolls==0,"対象の敵1体につき追加黄色を1回だけ抽選する")
			var dropped: int = records.filter(func(event): return event.type==&"xp_drop" and event.payload.enemy_id==id).size()
			check(dropped==gems.size(),"結晶の供給を同じ通知列へ1個ずつ記録する")
			if not gems.is_empty():
				var kill_index := -1
				var drop_index := -1
				for n in records.size():
					if records[n].type==&"kill": kill_index=n
					if records[n].type==&"xp_drop" and records[n].payload.enemy_id==id:
						drop_index=n
						break
				check(kill_index>=0 and kill_index<drop_index,"撃破の通知を結晶の供給より先に出す")
			bridge.command("dev_kill",{"entity_id":id,"cause":"shot"})
			check(bridge._core.pickups_snapshot()==snapshot,"同じ敵の二度目の撃破は供給も抽選もしない")
		# ボス本体と退場は通常報酬の入口へ流さない。
		var before: Dictionary = bridge._core.pickups_snapshot()
		var boss: int = bridge._core.spawn_enemy(definition.id,Vector2(-1000,500),{"is_boss":true})
		bridge.command("dev_kill",{"entity_id":boss,"cause":"shot"})
		var retired: int = bridge._core.spawn_enemy(definition.id,Vector2(-1000,500))
		bridge.command("dev_remove",{"entity_id":retired})
		check(before==bridge._core.pickups_snapshot(),"ボス本体の専用決着と非撃破の退場では通常報酬を出さない")
		bridge.dispose()
	for id in [&"splitter",&"drifter"]:
		var actual: EnemyDef = load("res://data/enemies/splitter.tres")
		# AIの移植前も同じ報酬経路を使い、実データの散乱・輪の有無を固定場面で確認する。
		var probe: EnemyDef = base.duplicate(true)
		probe.id = id
		probe.rank = actual.rank
		probe.params = actual.params.duplicate(true)
		probe.xp_reward_counts = actual.xp_reward_counts.duplicate()
		var bridge = reward_bridge(probe,config)
		if bridge==null: return
		var records: Array = []
		bridge.subscribe("scatter",func(frame):
			records.append_array(frame.events)
			return true)
		var enemy: int = bridge._core.spawn_enemy(probe.id,Vector2(-1000,500))
		bridge.command("dev_kill",{"entity_id":enemy,"cause":"shot"})
		var before: Dictionary = bridge._core.pickups_snapshot()
		check(not before.gems.is_empty(),"実際のsplitterの報酬データを供給する")
		for gem: Dictionary in before.gems:
			check(gem.velocity.length()>=240.0-0.0001 and gem.velocity.length()<=380.0+0.0001 and gem.wait==0.35,"固定報酬を元と同じ速度・回収待ち時間で散らす")
		bridge._core.step_pickups(0.1)
		var after: Dictionary = bridge._core.pickups_snapshot()
		for n in after.gems.size():
			check(after.gems[n].pos.distance_to(before.gems[n].pos+before.gems[n].velocity*0.1)<=0.0001,"結晶を実際に放射方向へ動かす")
			check(is_equal_approx(after.gems[n].wait,0.25) and after.gems[n].velocity.length()<before.gems[n].velocity.length(),"散乱中は減速し、待ち時間後に回収を許可する")
		var bursts: int = records.filter(func(event): return event.type==&"gem_burst").size()
		check(bursts==(0 if id==&"splitter" else 1),"splitterでは散らすだけにし、黄色い輪を追加しない")
		var saved: Dictionary = bridge.checkpoint()
		bridge._core.step_pickups(0.1)
		check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot()==after,"供給量・出所・散乱の途中状態を一緒に復帰する")
		bridge.release_checkpoint(saved.value)
		bridge.dispose()
	var bad: EnemyDef = base.duplicate(true)
	bad.xp_reward_counts = PackedInt32Array([1,2])
	check(load("res://tools/content/build_run_content.gd").chase_package(bad,config).is_empty(),"報酬の3色の形が不正なら生成を拒否する")

func check_cpp_reward_view() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	for id in [&"splitter",&"drifter"]:
		var actual: EnemyDef = load("res://data/enemies/splitter.tres")
		var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
		definition.id = id
		definition.rank = actual.rank
		definition.params = actual.params.duplicate(true)
		definition.xp_reward_counts = actual.xp_reward_counts.duplicate()
		var bridge = reward_bridge(definition,config)
		if bridge==null: return false
		var records: Array = []
		bridge.subscribe("view",func(frame):
			records.append_array(frame.events)
			return true)
		var enemy: int = bridge._core.spawn_enemy(id,Vector2(-1000,500))
		bridge.command("dev_kill",{"entity_id":enemy,"cause":"shot"})
		var scope := ContentResourceScope.new()
		for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.resources[path]=load(path)
		var view = load("res://scripts/render/run_frame_view.gd").new()
		add_child(view)
		var visuals: Array[Dictionary] = []
		view.setup(scope,visuals,config.character_scale)
		var frame: Dictionary = bridge.read_frame().value
		frame.events = records
		view.receive_frame(frame)
		view.update_effects(frame,0.0)
		check(view._rings.size()==(0 if id==&"splitter" else 1),"通常の表示でもsplitterの黄色い輪を作らず、ほかの散乱の輪を残す")
		view.free()
		scope.resources.clear()
		scope.cancel()
		bridge.dispose()
	await get_tree().process_frame
	await get_tree().process_frame
	return true

func supply_crystal(bridge,position: Vector2,kind: int) -> int:
	var result: Dictionary = bridge.command("dev_drop_crystal",{"position":position,"kind":kind})
	check(result.ok,"実際の共通供給で結晶を置く")
	return int(result.value) if result.ok else 0

func base_total(rows: Array) -> float:
	var result := 0.0
	for row: Dictionary in rows: result+=float(row.get("value",row.get("base_xp",0.0)))
	return result

func check_cpp_cap() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.gem_max = 3
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.rank = 1
	definition.xp_reward_counts = PackedInt32Array([6,0,0])
	var bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var records: Array = []
	bridge.subscribe("cap",func(frame):
		records.append_array(frame.events)
		return true)
	var oldest: int = supply_crystal(bridge,Vector2(-2000,500),0)
	var second: int = supply_crystal(bridge,Vector2(-1500,500),0)
	var enemy: int = bridge._core.spawn_enemy(definition.id,Vector2(-1000,500))
	check(bridge.command("dev_kill",{"entity_id":enemy,"cause":"shot"}).ok,"上限直前で複数個の固定報酬を供給する")
	var full: Dictionary = bridge._core.pickups_snapshot()
	check(full.gems.size()==3 and full.absorber_id==oldest,"黄色なしの満杯では最古の個体を集約先にする")
	var target: Dictionary = full.gems.filter(func(gem): return gem.id==oldest)[0]
	check(target.kind==2 and is_equal_approx(target.value,6.0*config.xp_crystal_values[0]),"元の保持XPを失わず黄色へ変えて余剰を足す")
	check(is_equal_approx(base_total(full.gems),8.0*config.xp_crystal_values[0]),"まとめた個体数に関係なく供給した全基準XPを保つ")
	check(records.any(func(event): return event.type==&"xp_absorber" and event.payload.reason==&"oldest_promoted" and event.payload.id==oldest),"集約先の変色と選択を記録する")
	var random_before: String = bridge._core.inspect().rng_state
	var incoming: int = supply_crystal(bridge,Vector2(-500,500),0)
	var absorbed: Dictionary = bridge._core.pickups_snapshot()
	check(bridge._core.inspect().rng_state==random_before and absorbed.next_ground_order==full.next_ground_order,"満杯では位置の散らしと地面の再配置を行わない")
	check(absorbed.gems.size()==3 and absorbed.absorber_id==oldest and incoming>3,"供給IDと地面の配置順を独立して進める")
	var absorption: Array = records.filter(func(event): return event.type==&"xp_absorb" and event.payload.id==incoming)
	check(absorption.size()==1 and absorption[0].payload.target_id==oldest,"吸収元と指定先の別々のIDを記録する")
	# 指定先を回収し、同じ行を再利用したあとも古いIDを指さない。
	target = absorbed.gems.filter(func(gem): return gem.id==oldest)[0]
	bridge.command("dev_ship_motion",{"position":target.pos,"velocity":Vector2.ZERO})
	bridge._core.step_pickups(0.001)
	var collected: Dictionary = bridge._core.pickups_snapshot()
	check(collected.gems.size()==2 and collected.absorber_id==0,"指定先を回収した時点で集約先を解除する")
	bridge.collect_frame()
	check(records.any(func(event): return event.type==&"xp_absorber" and event.payload.reason==&"collected" and event.payload.previous_id==oldest),"指定先の回収による解除を記録する")
	var replacement: int = supply_crystal(bridge,Vector2(-1000,900),0)
	var replaced: Dictionary = bridge._core.pickups_snapshot()
	var returned: Dictionary = replaced.gems.filter(func(gem): return gem.id==replacement)[0]
	check(returned.ground_order==3 and returned.id>returned.ground_order,"再利用行にも新しいIDと地面配置順を与える")
	supply_crystal(bridge,Vector2(-500,900),0)
	var selected: Dictionary = bridge._core.pickups_snapshot()
	check(selected.absorber_id==second,"次の超過では残った最古の結晶を選び直す")
	check(is_equal_approx(base_total(selected.gems)+base_total(selected.xp_statistics.collected),base_total(selected.xp_statistics.supplied)),"回収済みと地面を合わせると全供給量が保存される")
	var saved: Dictionary = bridge.checkpoint()
	supply_crystal(bridge,Vector2(-500,900),1)
	check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot()==selected,"指定先・配置順・供給量を保持して復帰する")
	bridge.release_checkpoint(saved.value)
	bridge.dispose()
	# 最古の個体より新しくても、黄色がある場合は最古黄色を優先する。
	bridge = reward_bridge(definition,config)
	if bridge==null: return false
	supply_crystal(bridge,Vector2(-2000,500),0)
	var high: int = supply_crystal(bridge,Vector2(-1500,500),2)
	supply_crystal(bridge,Vector2(-1000,500),2)
	supply_crystal(bridge,Vector2(-500,500),0)
	var result: Dictionary = bridge._core.pickups_snapshot()
	check(result.absorber_id==high and result.gems.size()==3,"既存の最古黄色を優先し、全色を上限以内に保つ")
	var high_row: Dictionary = result.gems.filter(func(gem): return gem.id==high)[0]
	check(is_equal_approx(high_row.value,config.xp_crystal_values[2]+config.xp_crystal_values[0]),"黄色の保持量へ供給した基準XPだけを加算する")
	bridge.dispose()

	return true

func check_cpp_cargo() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.gem_max = 2
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.rank = 0
	definition.xp_reward_counts = PackedInt32Array([1,0,0])
	var bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var records: Array = []
	bridge.subscribe("cargo",func(frame):
		records.append_array(frame.events)
		return true)
	var carrier: int = bridge._core.spawn_enemy(definition.id,Vector2(-2000,500))
	var crystal: int = supply_crystal(bridge,Vector2(-2000,500),0)
	supply_crystal(bridge,Vector2(-1500,500),1)
	supply_crystal(bridge,Vector2(-1000,500),0)
	var before: Dictionary = bridge._core.pickups_snapshot()
	var original: Dictionary = before.gems.filter(func(gem): return gem.id==crystal)[0]
	check(bridge.command("dev_carry_crystal",{"entity_id":carrier,"crystal_id":crystal}).ok,"集約黄色を共通運搬へ渡す")
	var carried: Dictionary = bridge._core.pickups_snapshot()
	check(carried.gems.size()==1 and carried.absorber_id==0 and carried.cargo.size()==1,"地面から外すと同時に指定先を解除する")
	var cargo: Dictionary = carried.cargo[0].crystals[0]
	check(cargo.id==crystal and cargo.kind==2 and cargo.base_xp==original.base_xp and cargo.origin==original.origin,"色・実保持量・ID・出所を丸ごと保持する")
	check(base_total(carried.xp_statistics.supplied)==base_total(before.xp_statistics.supplied),"運搬を新規供給へ数えない")
	check(records.any(func(event): return event.type==&"xp_transfer" and event.payload.id==crystal and event.payload.was_absorber),"集約先を運んだことを記録する")
	var saved: Dictionary = bridge.checkpoint()
	supply_crystal(bridge,Vector2(-500,500),2)
	check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot()==carried,"運搬表と指定解除・供給量を保持して復帰する")
	bridge.release_checkpoint(saved.value)
	supply_crystal(bridge,Vector2(-500,500),2)
	var filled: Dictionary = bridge._core.pickups_snapshot()
	records.clear()
	check(bridge.command("dev_kill",{"entity_id":carrier,"cause":"shot"}).ok,"運搬者を実際の撃破入口で倒す")
	var dropped: Dictionary = bridge._core.pickups_snapshot()
	check(dropped.gems.size()==2 and dropped.cargo.is_empty(),"満杯では運搬分も共通の指定先へ集約する")
	check(is_equal_approx(base_total(dropped.xp_statistics.supplied),base_total(filled.xp_statistics.supplied)+config.xp_crystal_values[0]),"撃破自身の報酬だけを供給へ加え、運搬分を二重計上しない")
	check(is_equal_approx(base_total(dropped.gems),base_total(dropped.xp_statistics.supplied)),"集約後も全基準XPが保存される")
	var supplies: Array = records.filter(func(event): return event.type==&"xp_absorb")
	check(supplies.size()==2 and supplies[0].payload.new_supply and not supplies[1].payload.new_supply and supplies[1].payload.id==crystal and supplies[1].payload.carrier_id==carrier,"自分の報酬から運搬分の順に戻し、IDと由来を記録する")
	bridge.dispose()
	# 空きがある場合は、同じIDを新しい地面配置順で戻す。
	bridge = reward_bridge(definition,config)
	if bridge==null: return false
	carrier = bridge._core.spawn_enemy(definition.id,Vector2(-2000,500))
	crystal = supply_crystal(bridge,Vector2(-2000,500),1)
	original = bridge._core.pickups_snapshot().gems[0]
	check(bridge.command("dev_carry_crystal",{"entity_id":carrier,"crystal_id":crystal}).ok,"通常色を運搬する")
	bridge.command("dev_kill",{"entity_id":carrier,"cause":"shot"})
	dropped = bridge._core.pickups_snapshot()
	var returned: Dictionary = dropped.gems.filter(func(gem): return gem.id==crystal)[0]
	check(returned.ground_order>original.ground_order and returned.kind==original.kind and returned.base_xp==original.base_xp and returned.origin==original.origin,"再配置だけ新しい順を付け、結晶の意味を変えない")
	bridge.dispose()
	# 退却・解放・一括消去は撃破報酬にせず、保存した量をlostへ移す。
	bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var lost_before := 0.0
	for action: String in ["dev_retreat","dev_remove","dev_clear_cargo"]:
		carrier = bridge._core.spawn_enemy(definition.id,Vector2(-2000,500))
		crystal = supply_crystal(bridge,Vector2(-2000,500),0)
		bridge.command("dev_carry_crystal",{"entity_id":carrier,"crystal_id":crystal})
		check(bridge.command(action,{} if action=="dev_clear_cargo" else {"entity_id":carrier}).ok,"運搬者の退却・解放・消去を通す")
		var lost: Dictionary = bridge._core.pickups_snapshot()
		check(lost.cargo.is_empty() and is_equal_approx(base_total(lost.xp_statistics.lost),lost_before+config.xp_crystal_values[0]),"運搬を消す際に保持XPだけをlostへ数える")
		lost_before = base_total(lost.xp_statistics.lost)
		if action=="dev_clear_cargo": bridge.command("dev_remove",{"entity_id":carrier})
		var replacement: int = bridge._core.spawn_enemy(definition.id,Vector2(-2000,500))
		check(replacement!=carrier and bridge._core.pickups_snapshot().cargo.is_empty(),"敵の行を再利用しても別IDへ運搬を漏らさない")
		bridge.command("dev_remove",{"entity_id":replacement})
	# ボス本体のように通常報酬へ進まない死体も、world_dt=0の整理で残さない。
	carrier = bridge._core.spawn_enemy(definition.id,Vector2(-2000,500),{"is_boss":true})
	crystal = supply_crystal(bridge,Vector2(-2000,500),1)
	bridge.command("dev_carry_crystal",{"entity_id":carrier,"crystal_id":crystal})
	bridge.command("dev_kill",{"entity_id":carrier,"cause":"shot"})
	check(bridge._core.step_pickups(0.0),"世界時間が止まっていても運搬者を整理する")
	var pruned: Dictionary = bridge._core.pickups_snapshot()
	check(pruned.cargo.is_empty() and is_equal_approx(base_total(pruned.xp_statistics.lost),lost_before+config.xp_crystal_values[1]),"無効運搬者の量を失われた量へ一度だけ移す")
	check(is_equal_approx(base_total(pruned.xp_statistics.supplied),base_total(pruned.xp_statistics.lost)),"退場と無効参照の整理後も供給量が保存される")
	bridge.dispose()
	return true

func check_cpp_cargo_record() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.rank = 0
	definition.xp_reward_counts = PackedInt32Array([0,0,0])
	var bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var records: Array = []
	bridge.subscribe("cargo_record",func(frame):
		records.append_array(frame.events)
		return true)
	var carrier: int = bridge._core.spawn_enemy(definition.id,Vector2(-2000,500))
	var crystal: int = supply_crystal(bridge,Vector2(-2000,500),1)
	var origin: Dictionary = bridge._core.pickups_snapshot().gems[0].origin
	bridge.command("dev_carry_crystal",{"entity_id":carrier,"crystal_id":crystal})
	bridge.command("dev_kill",{"entity_id":carrier,"cause":"shot"})
	var loss_carrier: int = bridge._core.spawn_enemy(definition.id,Vector2(-2000,500))
	bridge.command("dev_carry_crystal",{"entity_id":loss_carrier,"crystal_id":crystal})
	bridge.command("dev_remove",{"entity_id":loss_carrier})
	var related: Array = records.filter(func(event): return event.type in [&"xp_drop",&"xp_transfer",&"xp_lost"] and event.payload.id==crystal)
	check(related.size()==5,"供給・運搬・再配置・再運搬・喪失を同じ結晶IDで記録する")
	check(related.all(func(event): return event.payload.origin==origin and event.payload.xp==config.xp_crystal_values[1]),"運搬者が変わっても元の供給元・個体・時刻と基準XPを保つ: expected=%s actual=%s" % [var_to_str(origin),var_to_str(related.map(func(event): return event.payload.origin))])
	bridge.dispose()
	return true

func pickups_bridge(config: GameConfig):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var data: Dictionary = builder.chase_records(ContentManager.enemies[&"drifter"],config)
	var weapon: WeaponDef = load("res://data/weapons/W21_massTow.tres")
	# 交換のG02より先に、回収して待機する武器IDだけを生成済み定義へ含める。
	data.LoadoutDefinition.append({"id":data.LoadoutDefinition.size()+1,"kind":0,"maximum_level":weapon.level_steps.size(),"external_id":String(weapon.id),"comet_only":weapon.comet_only})
	var bytes: PackedByteArray = schema.write_content(data,schema.sha256("固定色の取得入口".to_utf8_buffer()))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	if not bridge.configure(bytes,{"api_version":1,"run_id":92,"mode":1,"stage_id":"pickups","profile":{},"settings":{}}).ok:
		check(false,"取得用の結晶・カプセル定義を生成する")
		return null
	check(bridge.start(932,{"position":Vector2(-3000,0)}).ok,"共通回収の固定場面を開始する")
	return bridge

func check_cpp_pickups() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.gem_max = 3
	config.xp_crystal_values = PackedFloat32Array([0.125,0.375,0.625])
	config.xp_base = 0.2
	config.xp_growth = 0.0
	config.xp_curve = 0.0
	var bridge = pickups_bridge(config)
	if bridge==null: return false
	var records: Array = []
	bridge.subscribe("pickups",func(frame):
		records.append_array(frame.events)
		return true)
	check(bridge.command("dev_pickup_rates",{"ship":1.5,"run":1.25}).ok,"機体とランの取得倍率を別々に持つ")
	supply_crystal(bridge,Vector2(-3000,0),0)
	check(bridge._core.step_pickups(0.001),"通常の吸引と回収を進める")
	bridge.collect_frame()
	var first: Dictionary = bridge._core.pickups_snapshot()
	var single: Array = records.filter(func(event): return event.type==&"xp_collect")
	check(single.size()==1 and single[0].payload.method==&"ship" and single[0].payload.multiplier==1.875 and single[0].payload.actual_xp==0.234375,"通常回収で2つの倍率を一度だけ掛け、小数XPを保つ")
	check(first.xp_statistics.collected_actual_xp==0.234375 and records.any(func(event): return event.type==&"levelup"),"取得でレベルが変わっても基準量と実取得量を分ける")
	# 画面外・吸引待ち・上限の集約先もビーコンの開始時に一括確定する。
	var carried_id: int = supply_crystal(bridge,Vector2(-2000,500),1)
	var carrier: int = bridge._core.spawn_enemy(&"drifter",Vector2(-2000,500))
	bridge.command("dev_carry_crystal",{"entity_id":carrier,"crystal_id":carried_id})
	for kind: int in [0,1,2,0]: supply_crystal(bridge,Vector2(-1000+kind*100,500),kind)
	var before: Dictionary = bridge._core.pickups_snapshot()
	var expected: float = base_total(before.gems)*1.875
	var saved: Dictionary = bridge.checkpoint()
	records.clear()
	var beacon: Dictionary = bridge.command("dev_collect_gems",{})
	var after: Dictionary = bridge._core.pickups_snapshot()
	var batch: Array = records.filter(func(event): return event.type==&"xp_collect")
	check(beacon.ok and beacon.value==expected and batch.size()==1 and batch[0].payload.count==3 and batch[0].payload.multiplier==1.875,"ビーコンは全対象と倍率を一度決め、まとめたXPで成長する")
	check(after.gems.is_empty() and after.absorber_id==0 and after.cargo.size()==1,"ビーコンは地面と集約先だけを回収し、運搬中を含めない")
	check(is_equal_approx(after.xp_statistics.collected_actual_xp-first.xp_statistics.collected_actual_xp,expected),"ビーコンの実取得XPを累計へ一度だけ足す")
	check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot()==before,"集約先・地面・運搬・基準/実取得の累計と倍率を保持して復帰する")
	bridge.release_checkpoint(saved.value)
	bridge.collect_frame()
	bridge.dispose()
	return true

func check_cpp_pickups_tail() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.xp_base = 1000.0
	var bridge = pickups_bridge(config)
	if bridge==null: return false
	bridge.command("dev_pickup_rates",{"ship":1.5,"run":1.25})
	var final_xp := 0.0625
	bridge.command("dev_add_xp",{"amount":final_xp})
	check(is_equal_approx(bridge._ui.xp,final_xp),"開発用XPへ取得倍率を再適用しない")
	check(bridge._core.pickups_snapshot().xp_statistics.collected_actual_xp==0.0,"開発用の最終XPを結晶回収へ混ぜない")
	bridge.dispose()
	# 回復拒否・寿命・コインと、彗星カプセルの待機IDを実際の更新で確認する。
	config.xp_base = 1000.0
	bridge = pickups_bridge(config)
	if bridge==null: return false
	var ship_pos := Vector2(-3000,0)
	check(bridge.command("dev_spawn_pickup",{"kind":"heal","position":ship_pos}).ok,"回復カプセルを置く")
	bridge._core.step_pickups(0.001)
	check(bridge._core.pickups_snapshot().capsules.size()==1,"HP満タンでは回復を取らない")
	bridge._core.step_pickups(config.pickup_life+1.0)
	check(bridge._core.pickups_snapshot().capsules.is_empty(),"取れない回復もドロップの寿命で消える")
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge.command("dev_ship_damage",{"amount":hp*0.25,"cause":"shot"})
	var hurt: float = bridge._core.ship_snapshot().ship_hp
	check(hurt<hp,"実際の被弾入口で回復前のHPを作る")
	bridge.command("dev_spawn_pickup",{"kind":"heal","position":ship_pos})
	bridge._core.step_pickups(0.001)
	check(is_equal_approx(bridge._core.ship_snapshot().ship_hp,minf(hp,hurt+hp*config.meteor_heal_frac)),"回復は実効最大HPの回復割合を使う")
	bridge.command("dev_spawn_pickup",{"kind":"coin","position":ship_pos})
	bridge._core.step_pickups(0.001)
	bridge.collect_frame()
	bridge.command("set_ui_overlay",{"active":false})
	check(bridge._core.pickups_snapshot().coins.is_empty() and bridge._ui.coins==1,"コインを回収して部品を1つ増やし、地面から外す")
	supply_crystal(bridge,Vector2(-1000,500),1)
	bridge.command("dev_spawn_pickup",{"kind":"magnet","position":ship_pos})
	bridge._core.step_pickups(0.001)
	check(bridge._core.pickups_snapshot().gems.is_empty(),"磁石カプセルも共通のビーコン取得入口へ通す")
	check(bridge.command("dev_spawn_pickup",{"kind":"comet_weapon","weapon":"W21","position":Vector2(-1000,0),"drop":false}).ok,"彗星限定カプセルを生成する")
	bridge._core.step_pickups(config.pickup_life+1.0)
	var capsule: Dictionary = bridge._core.pickups_snapshot().capsules[0]
	check(capsule.pos==Vector2(-1000,0),"彗星限定は吸引・寿命で消さない")
	bridge.command("dev_ship_motion",{"position":capsule.pos,"velocity":Vector2.ZERO})
	bridge._core.step_pickups(0.001)
	check(bridge._core.pickups_snapshot().pending_comet_weapons==["W21"],"触れた彗星武器を交換用の待機列へ渡す")
	var saved: Dictionary = bridge.checkpoint()
	bridge.command("dev_collect_gems",{})
	check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot().pending_comet_weapons==["W21"],"彗星武器の回収済み待機列も保持して復帰する")
	bridge.release_checkpoint(saved.value)
	bridge.dispose()
	return true
