## 武器と特性の育成完了への遷移・加算・実際の発射経路・ラン寿命を確認する。
extends "res://tests/integration/thrill_acceptance.gd"
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS

func _ready() -> void:
	await _cpp_ready()

func _cpp_edit(bridge, kind: String, payload: Dictionary) -> Dictionary:
	var result: Dictionary = bridge.command("dev_edit",{"kind":kind,"payload":payload})
	_check(result.ok,"型付きの育成命令を適用する: "+kind)
	return result

func _cpp_ready() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.levelup_bonus_chance = 0.0
	config.planet_radius = 0.0
	config.moon_count = 0
	config.weapon_slots = 1
	config.trait_slots = 1
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var bytes: PackedByteArray = builder.compile_chase(ContentManager.enemies[&"splitling"],config,schema.sha256("最大後強化の候補・効果・保持".to_utf8_buffer()))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":941,"mode":1,"stage_id":"最大後強化","profile":{},"settings":{}})
	_check(configured.ok,"最大後強化のtyped定義を読み込む: %s" % configured)
	if not configured.ok:
		get_tree().quit(1)
		return
	_check(bridge.start(42,{}).ok,"新ランを開始する")
	bridge.collect_frame()
	_check(bridge._ui.post_max_candidates.is_empty(),"通常育成が未完了なら最大後候補を開かない")
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W01","levels":5})
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T08","levels":5})
	_check(bridge._ui.normal_complete,"両方の枠と全Lvの完了を判定する")
	var before_roll: Dictionary = bridge.checkpoint()
	_cpp_edit(bridge,"progression",{"pending_levels":1})
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var expected: Array = bridge._ui.cards.candidates.map(func(c):return c.id)
	var expected_random: String = bridge._core.inspect().rng_state
	bridge.restore(before_roll.value)
	_cpp_edit(bridge,"progression",{"pending_levels":1})
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	_check(bridge._ui.cards.candidates.map(func(c):return c.id)==expected,"同じ入力から候補順と先頭の追加強化を再現する")
	_check(bridge._core.inspect().rng_state==expected_random,"保持復帰後の抽選で同じ乱数状態に到達する")
	if "--cpp-roll-retry" in OS.get_cmdline_user_args():
		bridge.dispose()
		print("[post_max_progression_cpp_roll_retry] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	var picked: Dictionary = bridge._ui.cards
	var random_before: String = bridge._core.inspect().rng_state
	bridge.command("choose_card",{"offer_id":picked.offer_id,"candidate_id":picked.candidates[0].candidate_id})
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	_check(bridge._core.inspect().rng_state==random_before,"追加強化の取得で通常装備のおまけ抽選を消費しない")
	bridge.restore(before_roll.value)
	bridge.collect_frame()
	var counts := {"max_speed":5,"max_hp":1,"crit_mult":5,"acceleration":2,"turn_rate":2,"line_length":5,"charge_time":5,"pickup_radius":5,"pickup_speed":2,"xp_gain":5,"weapon_damage":2,"followup":2,"projectile_speed":2,"duration":2,"knockback":2}
	_cpp_edit(bridge,"progression",{"hp":40.0})
	_cpp_edit(bridge,"post_max",{"stacks":counts})
	_check(is_equal_approx(bridge._ui.max_speed,config.base_max_speed*1.15),"最大速度は基準+15%で累乗しない")
	_check(is_equal_approx(bridge.read_lab().value.max_hp,105.0) and is_equal_approx(bridge._core.ship_snapshot().ship_hp,40.0),"最大HP+5は現在HPを回復しない")
	_check(is_equal_approx(bridge._ui.crit_mult,config.crit_mult+0.5),"倍率の加算を反映する")
	_check(is_equal_approx(bridge._ui.fuel_gain_mult,1.15),"追加強化の給油倍率を加算する")
	_check(is_equal_approx(bridge._ui.xp_pickup_radius,bridge._ui.pickup_radius*1.25),"吸引範囲はXP結晶だけへ反映する")
	var baseline_attack: float = bridge._ui.attack_power
	var input: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	for tick in 65: bridge.step(1.0/120.0,input,viewport)
	var friends: Array = bridge._core.projectiles_snapshot()
	_check(not friends.is_empty(),"最大後強化を実際のW01発射へ接続する")
	if not friends.is_empty():
		_check(is_equal_approx(friends[0].vel.length(),1430.0),"武器弾の速度+10%")
		_check(is_equal_approx(friends[0].knock,337.7),"武器弾の吹き飛ばし+10%")
		_check(is_equal_approx(friends[0].damage,baseline_attack*1.14*float(ContentManager.definition(&"weapons",&"W01").params.damage_by_level[4])),"武器強化をRAM本体へ漏らさず一度だけ掛ける")
	var saved: Dictionary = bridge.checkpoint()
	_check(saved.ok,"最大後強化と武器状態を保持する")
	_cpp_edit(bridge,"post_max",{"stacks":{}})
	_check(bridge.restore(saved.value).ok,"最大後強化とHP差分を復帰する")
	bridge.collect_frame()
	_check(bridge._ui.post_max_stacks==counts and is_equal_approx(bridge._core.ship_snapshot().ship_hp,40.0),"保持復帰で回数と現在HPを維持する")
	_cpp_edit(bridge,"post_max",{"stacks":{"charge_time":1000,"weapon_interval":1000,"invulnerability":1000,"repair":1000,"crit_chance":1000}})
	var capped: Array = bridge._ui.post_max_candidates.map(func(c): return c.id)
	for id in ["charge_time","weapon_interval","invulnerability","repair","crit_chance"]:
		_check(not capped.has(id),"上限到達の候補を外す: "+id)
	_check(is_equal_approx(bridge._ui.fuel_gain_mult,1.0+config.fuel_gain_max),"給油倍率は設定の上限で止まる")
	_cpp_edit(bridge,"post_max",{"stacks":{}})
	var expectations := {"W01":["weapon_interval","projectile_speed","duration","knockback","followup"],"W03":["projectile_speed","duration","knockback","area"],"W04":["knockback","area"],"W05":["weapon_interval","knockback","followup"],"W07":["duration","knockback","followup"],"W08":["duration","knockback","area"],"W17":["knockback","area"],"W21":["projectile_speed","duration","knockback","area","followup"],"W22":["knockback","area","followup"],"W23":["weapon_interval","projectile_speed","duration","knockback","followup"],"W25":["weapon_interval","projectile_speed","duration","followup"],"W26":["area"],"W27":[]}
	var previous := "W01"
	for weapon: String in expectations:
		bridge.command("dev_remove_weapon",{"id":previous})
		_check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":weapon,"levels":5}).ok,"対象の武器を全Lvで取得: "+weapon)
		previous = weapon
		var eligible: Array = bridge._ui.post_max_candidates.map(func(c): return c.id)
		for id in ["weapon_interval","projectile_speed","duration","knockback","area","followup"]:
			_check(eligible.has(id)==expectations[weapon].has(id),"実適用先で候補を絞る: "+weapon+" "+id)
	_cpp_edit(bridge,"progression",{"hp":40.0,"pending_levels":1})
	_cpp_edit(bridge,"post_max_offer",{"ids":PackedStringArray(["max_hp","heal","max_speed"])})
	var cards: Dictionary = bridge._ui.cards
	_check(bridge.command("pause",{"paused":true}).ok,"選択中に停止する")
	_check(not bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":cards.candidates[0].candidate_id}).ok,"ポーズ中の選択を遮断する")
	bridge.command("pause",{"paused":false})
	_check(bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":cards.candidates[0].candidate_id}).ok,"通常の候補IDで最大HPを選ぶ")
	bridge.step(1.0/120.0,input,viewport)
	_check(bridge._ui.pending_levels==0 and bridge._ui.phase==RunIds.Phase.Play and is_equal_approx(bridge._core.ship_snapshot().ship_hp,40.0),"1回だけ強化して現在HPを保ち戦闘を再開する")
	_cpp_edit(bridge,"post_max_offer",{"ids":PackedStringArray(["heal"])})
	cards = bridge._ui.cards
	bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":cards.candidates[0].candidate_id})
	bridge.step(1.0/120.0,input,viewport)
	_check(is_equal_approx(bridge._core.ship_snapshot().ship_hp,71.5) and not bridge._ui.post_max_stacks.has("heal"),"即時30%回復は積み増し回数を作らない")
	_cpp_edit(bridge,"progression",{"hp":105.0})
	_check(not bridge._ui.post_max_candidates.any(func(c):return c.id=="heal"),"満HPなら回復を候補から外す")
	bridge.dispose()
	print("[post_max_progression_cpp] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
