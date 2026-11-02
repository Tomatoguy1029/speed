## 回収物ごとの取得効果を同じ入口で適用できる。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
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
