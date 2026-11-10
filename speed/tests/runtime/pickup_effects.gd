## 回収物ごとの取得効果を同じ入口で適用できる。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	if "--cpp-coins" in OS.get_cmdline_user_args():
		check(check_cpp_coins(),"部品の即時獲得を最後まで確認する")
		check(check_cpp_meteor_coins(),"隕石の部品抽選を最後まで確認する")
		print("[cpp_coins] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-visible" in OS.get_cmdline_user_args():
		check(check_cpp_visible(),"描画上限の確認を最後まで実施する")
		print("[cpp_visible] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
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
		if finished: finished = check_cpp_crow_index()
		check(finished,"結晶の運搬の確認を最後まで実施する")
		print("[cpp_cargo] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

	if "--cpp-cap" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_cap()
		check(finished,"上限保持の確認を最後まで実施する")
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
	check_cpp_reward()
	print("[pickup_effects] failed=%d" % failed)
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
	var base: EnemyDef = ContentManager.enemies[&"splitling"]
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
	for id in [&"splitter",&"splitling"]:
		var actual: EnemyDef = load("res://data/enemies/splitter.tres")
		# AIの移植前も同じ報酬経路を使い、実データの散乱・輪の有無を固定場面で確認する。
		var probe: EnemyDef = base.duplicate(true)
		probe.behavior = &"chase"
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
		var future: Dictionary = bridge._core.pickups_snapshot()
		check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot()==after,"供給量・出所・散乱の途中状態を一緒に復帰する")
		bridge._core.step_pickups(0.1)
		check(bridge._core.pickups_snapshot()==future,"復帰した移動対象から散乱を同じ結果へ進める")
		bridge.release_checkpoint(saved.value)
		bridge.dispose()
	var bad: EnemyDef = base.duplicate(true)
	bad.xp_reward_counts = PackedInt32Array([1,2])
	check(load("res://tools/content/build_run_content.gd").chase_package(bad,config).is_empty(),"報酬の3色の形が不正なら生成を拒否する")

func check_cpp_reward_view() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	for id in [&"splitter",&"splitling"]:
		var actual: EnemyDef = load("res://data/enemies/splitter.tres")
		var definition: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
		definition.behavior = &"chase"
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
		for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png",
			"res://assets/effects/landmark/masks.tres","res://data/visuals/landmark_aura_material.tres",
			"res://assets/effects/landmark/elite_contacts.tres","res://data/visuals/elite_runtime.tres"]: scope.resources[path]=load(path)
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
	config.gem_max = 8
	var definition: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
	definition.rank = 1
	definition.xp_reward_counts = PackedInt32Array([6,0,0])
	var bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var records: Array = []
	bridge.subscribe("cap",func(frame):
		records.append_array(frame.events)
		return true)
	for n in 8: supply_crystal(bridge,Vector2(-6000-n*100,500),1)
	var enemy: int = bridge._core.spawn_enemy(definition.id,Vector2(-1000,500))
	check(bridge.command("dev_kill",{"entity_id":enemy,"cause":"shot"}).ok,"満杯で6個の固定報酬を供給する")
	var full: Dictionary = bridge._core.pickups_snapshot()
	check(full.gems.size()==8 and full.absorber_id==0 and reward_counts(full.gems)==[6,2,0],"既存の6枠を先に確保し、同じ撃破の新しい6個を残す")
	check(full.gems.filter(func(gem): return gem.kind==0).all(func(gem): return gem.pos.distance_to(Vector2(-1000,500))<9.0),"満杯でも撃破現場へ新結晶を置く")
	check(is_equal_approx(base_total(full.xp_statistics.lost),6*config.xp_crystal_values[1]),"取り除いた保持XPを消失へ一度だけ数える")
	check(records.filter(func(event): return event.type==&"xp_lost" and event.payload.reason==&"capacity").size()==6,"上限による消失を記録する")
	check(not records.any(func(event): return event.type in [&"xp_absorb",&"xp_absorber",&"xp_collect"]),"上限で集約・自動取得を発生させない")
	check(is_equal_approx(base_total(full.gems)+base_total(full.xp_statistics.lost),base_total(full.xp_statistics.supplied)),"地面と消失を合わせて供給量を照合する")
	var recording: Dictionary = bridge.read_recording(true).value
	check(recording.xp.cap.mode=="offscreen_low_far_old" and recording.xp.cap.limit==8,"録画へ保持規則と上限を渡す")
	check(recording.xp.lost.mid.count==6 and recording.xp.lost.mid.base_xp==300.0 and recording.xp.ground.low.count==6,"消失と残存の色別個数・基準XPを録画へ渡す")
	var recorder = load("res://scripts/dev/play_recorder.gd").new()
	var window: Dictionary = recorder._xp_window(recording.xp,{},"recording_total")
	check(window.counter_color_basis=="crystal_kind_preserved" and window.lost.mid.count==6 and window.lost.mid.base_xp==300.0,"録画区間へ色保持の意味とXP消失を渡す")
	check(recorder._xp_window({"cap":{"mode":"oldest_high_absorber"}},{},"recording_total").counter_color_basis=="supplied_before_absorption_collected_after_conversion","旧集約方式の録画意味を区別する")
	var recording_path := "/tmp/speed-xp-loss-%d.jsonl" % OS.get_process_id()
	recorder._file = FileAccess.open(recording_path,FileAccess.WRITE)
	recorder._cpp_session_id = 91
	check(recorder._file!=null,"XP消失の確認用JSONLをtmpへ開く")
	if recorder._file!=null:
		recorder.consume_cpp_frame({"run_id":91,"ui":{"run_time":0.0},"events":records})
		recorder._write({"type":"sample","xp":window})
		recorder._file.close()
		recorder._file = null
		var recorded: Array = []
		for line: String in FileAccess.get_file_as_string(recording_path).split("\n",false): recorded.append(JSON.parse_string(line))
		var losses: Array = recorded.filter(func(row): return row.type=="xp_lost")
		check(losses.size()==6 and losses.all(func(row): return row.reason=="capacity" and row.kind=="mid" and row.base_xp==50.0),"実際のJSONLへ6個分の消失理由・色・基準XPを保存する")
		check(recorded.back().xp.lost.mid.base_xp==300.0,"JSONLの区間集計にも消失合計を保存する")
	recorder.free()
	bridge.set_metrics_detail(true,&"crystal_test")
	for tick in 3: check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)}).ok,"通常ランの計測経路で更新する")
	var measured: Dictionary = bridge.read_metrics(&"crystal_test").value
	check(measured.rows.crystals[0]==8 and measured.detail_timings.has("pickups") and measured.detail_timings.pickups[1]>0,"ランタイム計測で保持数と回収処理の呼出数を取得する")
	print("[crystal_metrics] rows=",measured.rows.crystals," pickups=",measured.detail_timings.pickups)
	var saved: Dictionary = bridge.checkpoint()
	supply_crystal(bridge,Vector2(-500,900),2)
	check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot()==full,"保持状態と消失量を復帰する")
	var nearby: PackedFloat32Array = bridge._core.pickup_buffer(&"gem",1.0,Color.WHITE,Rect2(-1100,400,200,200))
	check(nearby.size()==6*12,"復帰時に空間索引を再構築して全6個を照会する")
	bridge.release_checkpoint(saved.value)
	bridge.dispose()
	# 画面外を先に選び、同じ画面内外では低XP、遠い順に取り除く。
	config.gem_max = 3
	bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var ui: Dictionary = bridge.read_frame().value.ui
	var center: Vector2 = ui.view_center
	check(bridge._core.set_motion_context(Vector2(-3000,0),center,Vector2(500,300)),"画面内外を判定するカメラ範囲を設定する")
	var visible: int = supply_crystal(bridge,center,0)
	var far_high: int = supply_crystal(bridge,center+Vector2(10000,0),2)
	var far_mid: int = supply_crystal(bridge,center+Vector2(9000,0),1)
	supply_crystal(bridge,center,2)
	var result: Dictionary = bridge._core.pickups_snapshot()
	check(result.gems.any(func(gem): return gem.id==visible) and result.gems.any(func(gem): return gem.id==far_high) and not result.gems.any(func(gem): return gem.id==far_mid),"画面内の低XPを保護し、画面外は距離より低XPを優先する")
	supply_crystal(bridge,center,1)
	result = bridge._core.pickups_snapshot()
	check(not result.gems.any(func(gem): return gem.id==far_high),"画面外を取り除いてから画面内を選ぶ")
	supply_crystal(bridge,center,1)
	result = bridge._core.pickups_snapshot()
	check(not result.gems.any(func(gem): return gem.id==visible),"画面内しか残らないときは低XPから取り除く")
	bridge.dispose()
	config.gem_max = 8
	bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var at := Vector2(10000,10000)
	var ids: Array[int] = []
	for kind in 3: ids.append(supply_crystal(bridge,at+Vector2(kind*20,0),kind))
	ids.append(supply_crystal(bridge,at+Vector2(220,0),0))
	var outside: int = supply_crystal(bridge,at+Vector2(240,0),2)
	var stationary: Dictionary = bridge._core.pickups_snapshot()
	check(bridge._core.step_pickups(0.5) and bridge._core.pickups_snapshot().gems==stationary.gems,"画面外の静止結晶を移動・自動取得せず保持する")
	var rendered: Dictionary = bridge.read_render(Rect2(at-Vector2(100,100),Vector2(200,200)),1.0).value
	var crystals: Array = rendered.batches.filter(func(batch): return batch.visual_id==3)
	check(crystals.size()==1,"結晶を共通の描画バッチへ渡す")
	if crystals.size()==1:
		var batch: Dictionary = crystals[0]
		check(batch.layer==6 and batch.ids.size()==4 and not batch.ids.has(outside) and ids.all(func(id): return batch.ids.has(id)),"描画上限未満ならカメラ+128pxの全結晶を敵の背面に描き、それ以外を除外する")
		check(batch.colors[0]==Color("08DEFF") and batch.colors[1]==Color("945CFF") and batch.colors[2]==Color("FFB609"),"3種類の色を保持する")
		check(batch.transforms[0]==batch.transforms[6] and batch.transforms[0]==batch.transforms[12],"種類によらず同じ寸法にする")
	bridge.dispose()
	return true

func check_cpp_cargo() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.gem_max = 2
	var definition: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
	definition.rank = 0
	definition.xp_reward_counts = PackedInt32Array([1,0,0])
	var bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var records: Array = []
	bridge.subscribe("cargo",func(frame):
		records.append_array(frame.events)
		return true)
	var carrier: int = bridge._core.spawn_enemy(definition.id,Vector2(-2000,500))
	var crystal: int = supply_crystal(bridge,Vector2(-2000,500),2)
	supply_crystal(bridge,Vector2(-1500,500),1)
	var before: Dictionary = bridge._core.pickups_snapshot()
	var original: Dictionary = before.gems.filter(func(gem): return gem.id==crystal)[0]
	check(bridge.command("dev_carry_crystal",{"entity_id":carrier,"crystal_id":crystal}).ok,"黄色結晶を共通運搬へ渡す")
	var carried: Dictionary = bridge._core.pickups_snapshot()
	check(carried.gems.size()==1 and carried.absorber_id==0 and carried.cargo.size()==1,"地面から外し運搬表へ移す")
	var cargo: Dictionary = carried.cargo[0].crystals[0]
	check(cargo.id==crystal and cargo.kind==2 and cargo.base_xp==original.base_xp and cargo.origin==original.origin,"色・実保持量・ID・出所を丸ごと保持する")
	check(base_total(carried.xp_statistics.supplied)==base_total(before.xp_statistics.supplied),"運搬を新規供給へ数えない")
	check(records.any(func(event): return event.type==&"xp_transfer" and event.payload.id==crystal and not event.payload.was_absorber),"通常の結晶を運んだことを記録する")
	var saved: Dictionary = bridge.checkpoint()
	supply_crystal(bridge,Vector2(-500,500),2)
	check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot()==carried,"運搬表と供給量を保持して復帰する")
	bridge.release_checkpoint(saved.value)
	supply_crystal(bridge,Vector2(-500,500),2)
	var filled: Dictionary = bridge._core.pickups_snapshot()
	records.clear()
	check(bridge.command("dev_kill",{"entity_id":carrier,"cause":"shot"}).ok,"運搬者を実際の撃破入口で倒す")
	var dropped: Dictionary = bridge._core.pickups_snapshot()
	check(dropped.gems.size()==2 and dropped.cargo.is_empty(),"満杯でも報酬と運搬分を個別に再配置する")
	check(reward_counts(dropped.gems)==[1,0,1] and dropped.gems.any(func(gem): return gem.id==crystal),"運搬分と報酬を一括確保し、同じ撃破の新規水色を除去しない")
	check(is_equal_approx(base_total(dropped.xp_statistics.supplied),base_total(filled.xp_statistics.supplied)+config.xp_crystal_values[0]),"撃破自身の報酬だけを供給へ加え、運搬分を二重計上しない")
	check(is_equal_approx(base_total(dropped.gems)+base_total(dropped.xp_statistics.lost),base_total(dropped.xp_statistics.supplied)),"消失込みで全基準XPを照合する")
	var supplies: Array = records.filter(func(event): return event.type==&"xp_drop")
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
	var definition: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
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
	var data: Dictionary = builder.chase_records(ContentManager.enemies[&"splitling"],config)
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
	# 画面外・吸引待ちの結晶もビーコンの開始時に一括確定する。
	var carried_id: int = supply_crystal(bridge,Vector2(-2000,500),1)
	var carrier: int = bridge._core.spawn_enemy(&"splitling",Vector2(-2000,500))
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
	check(after.gems.is_empty() and after.absorber_id==0 and after.cargo.size()==1,"ビーコンは地面の結晶だけを回収し、運搬中を含めない")
	check(is_equal_approx(after.xp_statistics.collected_actual_xp-first.xp_statistics.collected_actual_xp,expected),"ビーコンの実取得XPを累計へ一度だけ足す")
	check(bridge.restore(saved.value).ok and bridge._core.pickups_snapshot()==before,"地面・運搬・基準/実取得の累計と倍率を保持して復帰する")
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

func check_cpp_crow_index() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: EnemyDef = ContentManager.enemies[&"crow"].duplicate(true)
	definition.xp_reward_counts = PackedInt32Array([0,0,0])
	var bridge = reward_bridge(definition,config)
	if bridge==null: return false
	var at := Vector2(-1000,500)
	var carrier: int = bridge._core.spawn_enemy(&"crow",at,{"facing":0.0,"flock_member":true})
	check(carrier>0,"空間検索を使う実際のからす座を生成する")
	if carrier<=0: bridge.dispose();return false
	var radius: float = bridge._core.enemies_snapshot()[0].radius
	var feet := at-Vector2(radius*0.62,0)
	var ids: Array[int] = []
	for kind in 3: ids.append(supply_crystal(bridge,feet,kind))
	var front: int = supply_crystal(bridge,at+Vector2(100,0),0)
	var distant: int = supply_crystal(bridge,at+Vector2(2000,0),1)
	check(bridge._core.step_pickups(0.1),"空間検索から足元の結晶を収集する")
	var carried: Dictionary = bridge._core.pickups_snapshot()
	check(carried.cargo.size()==1 and carried.cargo[0].crystals.size()==3 and carried.cargo[0].crystals.all(func(gem): return gem.id in ids),"索引の近傍検索で3種類をそのまま運搬する")
	check(carried.gems.size()==2 and carried.gems.all(func(gem): return gem.id==front or gem.id==distant),"前方と探索範囲外の結晶を残す")
	var moving: int = supply_crystal(bridge,at+Vector2(-90,50),0)
	var before: Dictionary = bridge._core.pickups_snapshot().gems.filter(func(gem): return gem.id==moving)[0]
	bridge._core.step_pickups(0.01)
	var after: Dictionary = bridge._core.pickups_snapshot().gems.filter(func(gem): return gem.id==moving)[0]
	check(after.pos.distance_to(before.pos)>0.0,"からす座の吸引で地面の結晶を移動する")
	check(bridge._core.pickup_buffer(&"gem",1.0,Color.WHITE,Rect2(after.pos-Vector2.ONE,Vector2.ONE*2)).size()==12,"からす座が動かした位置で索引を照会できる")
	var saved: Dictionary = bridge.checkpoint()
	bridge._core.step_pickups(0.02)
	var future: Dictionary = bridge._core.pickups_snapshot()
	var area := Rect2(at-Vector2(200,200),Vector2(400,400))
	var visible: PackedFloat32Array = bridge._core.pickup_buffer(&"gem",1.0,Color.WHITE,area)
	check(bridge.restore(saved.value).ok,"運搬中と地面移動中を同時に復帰する")
	bridge._core.step_pickups(0.02)
	check(bridge._core.pickups_snapshot()==future and bridge._core.pickup_buffer(&"gem",1.0,Color.WHITE,area)==visible,"復帰後のからす座探索・移動・描画索引が同じ結果になる")
	bridge.release_checkpoint(saved.value)
	bridge.dispose()
	return true

func visible_crystal_ids(bridge,area: Rect2) -> Array:
	var ids: Array = []
	for batch: Dictionary in bridge.read_render(area,1.0).value.batches:
		if batch.visual_id==3: ids.append_array(batch.ids)
	return ids

func check_cpp_visible() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius=0;config.moon_count=0;config.gem_draw_max=2
	var definition: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
	var bridge = reward_bridge(definition,config)
	if bridge==null: return false
	bridge.subscribe("visible",func(_frame): return true,[],[])
	check(bridge.read_recording(true).value.xp_config.gem_draw_max==2,"録画へ保持上限とは独立した描画上限を記録する")
	var at := Vector2(-3000,0)
	var far: int = supply_crystal(bridge,at+Vector2(200,0),2)
	var left: int = supply_crystal(bridge,at+Vector2(-60,0),1)
	var right: int = supply_crystal(bridge,at+Vector2(60,0),0)
	var near: int = supply_crystal(bridge,at+Vector2(5,0),0)
	var area := Rect2(at-Vector2(300,200),Vector2(600,400))
	var before: Dictionary = bridge._core.pickups_snapshot()
	var ordered: Array = before.gems.duplicate()
	ordered.sort_custom(func(x,y):
		var dx: float=x.pos.distance_squared_to(at)
		var dy: float=y.pos.distance_squared_to(at)
		return dx<dy or (dx==dy and x.id<y.id))
	var expected: Array = [ordered[0].id,ordered[1].id]
	expected.sort()
	check(visible_crystal_ids(bridge,area)==expected and near in expected and far not in expected,"実際の散らばり位置から近い2個を選び、描画上限を守る")
	check(bridge._core.pickups_snapshot()==before,"描画制限は保持状態・XPを変更しない")
	var saved: Dictionary = bridge.checkpoint()
	bridge.command("dev_ship_motion",{"position":at+Vector2(61,0),"velocity":Vector2.ZERO})
	check(visible_crystal_ids(bridge,area)==[right,near],"機体の移動に応じて近い結晶を選び直す")
	check(bridge.restore(saved.value).ok,"描画上限付きの保持点を復元する")
	check(visible_crystal_ids(bridge,area)==expected,"復元後も同じ距離・IDの選択を維持する")
	bridge.release_checkpoint(saved.value)
	bridge.command("dev_pickup_rates",{"ship":1.5,"run":1.25})
	# 隠れた結晶も通常回収対象。全て足元へ移動する代わりに各配置を機体で通る。
	for gem: Dictionary in before.gems:
		bridge.command("dev_ship_motion",{"position":gem.pos,"velocity":Vector2.ZERO})
		check(bridge._core.step_pickups(0.001),"上限を超えた結晶も通常の回収判定を通る")
	var after: Dictionary = bridge._core.pickups_snapshot()
	check(after.gems.is_empty(),"描画されなかった結晶も全て回収する")
	check(is_equal_approx(after.xp_statistics.collected_actual_xp,base_total(before.gems)*1.875),"描画数によらず全基準XPへ倍率を一回適用する")
	check(base_total(after.xp_statistics.lost)==0.0,"描画制限でXPを失わない")
	bridge.dispose()
	return true

func check_cpp_coins() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
	definition.xp_reward_counts = PackedInt32Array([0,0,0])
	definition.behavior = &"chase"
	definition.params = {}
	var bridge = reward_bridge(definition,config)
	if bridge==null: return false
	bridge.collect_frame()
	var records: Array = []
	bridge.subscribe("coins",func(frame):
		records.append_array(frame.events)
		return true)
	for elite in [false,true]:
		var before: int = bridge._ui.coins
		for i in (4 if elite else 128):
			var id: int = bridge._core.spawn_enemy(definition.id,Vector2(9000,500),{"elite":elite})
			var killed: Dictionary = bridge.command("dev_kill",{"entity_id":id,"cause":"shot"})
			check(killed.ok and killed.value.killed,"離れた敵を実際の撃破入口で倒す")
		var snapshot: Dictionary = bridge._core.pickups_snapshot()
		check(bridge._ui.coins==(24 if elite else 4),"固定乱数での通常敵3%・エリート3〜6個の抽選数を維持する")
		check(bridge._core.random_state()==(-7232949288372105844 if elite else -3329702314789444196),"部品の散布を省いても後続の乱数列を維持する")
		check(snapshot.coins.is_empty(),"撃破した敵の部品を地面に残さない")
		check(bridge._ui.coins>before,"回収範囲に関係なく撃破時に部品を加算する")
	var amount: int = bridge._ui.coins
	check(records.filter(func(event): return event.type==&"pickup" and event.payload.kind==&"coin").size()==amount,"部品1個ごとの既存取得通知を維持する")
	var saved: Dictionary = bridge.checkpoint()
	var enemy: int = bridge._core.spawn_enemy(definition.id,Vector2(9000,500),{"elite":true})
	bridge.command("dev_kill",{"entity_id":enemy,"cause":"shot"})
	var after: int = bridge._ui.coins
	var rng = bridge._core.random_state()
	bridge.command("dev_kill",{"entity_id":enemy,"cause":"shot"})
	check(bridge._ui.coins==after,"同じ敵を重複撃破しても部品を二重加算しない")
	check(bridge.restore(saved.value).ok,"部品取得前の保持点へ復帰する")
	bridge.collect_frame()
	check(bridge._ui.coins==amount,"取得した部品をチェックポイントから復帰する")
	enemy = bridge._core.spawn_enemy(definition.id,Vector2(9000,500),{"elite":true})
	bridge.command("dev_kill",{"entity_id":enemy,"cause":"shot"})
	check(bridge._ui.coins==after and bridge._core.random_state()==rng,"復帰後の部品数と次の抽選を再現する")
	bridge.release_checkpoint(saved.value)
	var boss: int = bridge._core.spawn_enemy(definition.id,Vector2(9000,500),{"elite":true,"is_boss":true})
	bridge.command("dev_kill",{"entity_id":boss,"cause":"shot"})
	var removed: int = bridge._core.spawn_enemy(definition.id,Vector2(9000,500),{"elite":true})
	bridge.command("dev_remove",{"entity_id":removed})
	check(bridge._ui.coins==after,"ボス本体の専用決着と非撃破の退場を部品の通常抽選へ混ぜない")
	bridge._core.step_pickups(0.1)
	bridge.collect_frame()
	check(bridge._ui.coins==after,"後続の回収更新で部品を重複加算しない")
	check(bridge.command("dev_finish",{"cleared":false}).ok,"部品獲得済みのランを終了する")
	check(bridge.read_frame().value.result.coins==after,"自動獲得した部品を結果・保存用の獲得数へ引き継ぐ")
	bridge.dispose()
	return true

func check_cpp_meteor_coins() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	for chance: float in [0.0,1.0]:
		var data: Dictionary = builder.chase_records(ContentManager.enemies[&"meteor"],config).duplicate(true)
		var terrain := {"id":1,"meteor_count":0,"iron_count":0,"saw_count":0,"planet_radius":0.0,
			"meteor_coin_chance":chance,"meteor_heal_chance":1.0,"meteor_magnet_chance":1.0,
			"saw_speed":0.0,"saw_power":0.0,"saw_life":0.0,"meteor":1,"iron":1,"saw":1,
			"meteor_radius_0":16.0,"meteor_radius_1":16.0}
		for i in 6: terrain["meteor_visual_%d" % i] = 1
		data.RockFieldDefinition = [terrain]
		var bytes: PackedByteArray = schema.write_content(data,schema.sha256("隕石の部品抽選".to_utf8_buffer()))
		var bridge = load("res://scripts/runtime/run_bridge.gd").new()
		if not bridge.configure(bytes,{"api_version":1,"run_id":93,"mode":1,"stage_id":"meteor_coins","profile":{},"settings":{}}).ok:
			check(false,"隕石の実データと固有報酬の定義を生成する")
			return false
		check(bridge.start(933,{"position":Vector2(-3000,0)}).ok,"隕石の抽選場面を開始する")
		bridge.collect_frame()
		var total := 0
		for i in 8:
			var id: int = bridge._core.spawn_enemy(&"meteor",Vector2(9000,500))
			check(bridge.command("dev_kill",{"entity_id":id,"cause":"shot"}).ok,"隕石を共通の撃破入口で破壊する")
			var amount: int = bridge._ui.coins-total
			check((amount>=1 and amount<=3) if chance==1.0 else amount==0,"隕石固有の確率と1〜3個の部品数を維持する")
			total = bridge._ui.coins
		var snapshot: Dictionary = bridge._core.pickups_snapshot()
		check(snapshot.coins.is_empty() and snapshot.gems.size()==8 and snapshot.capsules.size()==16,"隕石の部品だけを即時獲得し、固定結晶と回復・回収カプセルを維持する")
		bridge.dispose()
	return true
