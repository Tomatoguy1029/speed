## 英雄の力は同じ入口を使い、それぞれのランにだけ作用する。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	if "--cpp-hercules" in OS.get_cmdline_user_args():
		_cpp_hercules()
		return
	if "--cpp-gemini" in OS.get_cmdline_user_args():
		_cpp_gemini()
		return
	if "--cpp-leo" in OS.get_cmdline_user_args():
		_cpp_leo()
		return
	if "--cpp-perseus-boss" in OS.get_cmdline_user_args():
		_cpp_perseus_boss()
		print("[cpp_H_perseus_boss] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-perseus" in OS.get_cmdline_user_args():
		_cpp_perseus()
		return
	_cpp_leo()

func _cpp_read(bridge) -> Dictionary:
	var frame: Dictionary = bridge.read_frame()
	check(frame.ok,"英雄の状態と登録通知を読む")
	var delivered: Dictionary = bridge.collect_frame()
	check(delivered.ok and bridge.delivery_error.get("ok",true),"英雄の通知を失わず配信する")
	return frame.value if frame.ok else {}

func _cpp_rescue(bridge,id: String) -> Dictionary:
	check(bridge.command("dev_hero_place",{"id":id}).ok,"%sの星座を配置する" % id)
	var h: Dictionary = _cpp_read(bridge).ui.hero
	for i in range(0,h.links.size(),2): check(bridge.command("dev_hero_pass",{"from":h.stars[h.links[i]],"to":h.stars[h.links[i+1]],"dash":i}).ok,"星座線を通って救出する")
	h = _cpp_read(bridge).ui.hero
	check(h.power==StringName(id) and not h.captive,"救出した力が特別な枠へ入る")
	return h

func _cpp_step(bridge,intent: Intent = null) -> Dictionary:
	if intent==null: intent = Intent.new()
	var stepped: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(1280,720)})
	check(stepped.ok,"固定更新で英雄の入力と時計を進める")
	return _cpp_read(bridge)

func _cpp_enemy(bridge,id: int) -> Dictionary:
	for enemy: Dictionary in bridge._core.enemy_motion_snapshot():
		if enemy.id==id: return enemy
	return {}

func _cpp_perseus() -> void:
	var fixture = load("res://tests/integration/hero_guidance.gd").new()
	var bridge = fixture._cpp_fixture(true)
	_cpp_rescue(bridge,"perseus")
	bridge.command("dev_ship_motion",{"position":Vector2.ZERO,"velocity":Vector2.ZERO})
	var inside: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(120,0)}).value
	var outside: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(50000,0)}).value
	var source: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(250,80)}).value
	check(bridge.command("dev_fire_enemy",{"source_id":source,"angle":0.0,"speed":100.0}).ok,"画面内の敵弾を用意する")
	var input := Intent.new()
	input.hero_press = true
	var frame := _cpp_step(bridge,input)
	check(frame.ui.hero.power==&"perseus" and is_equal_approx(frame.ui.hero.active,3.8-1.0/120.0) and frame.ui.hero.cooldown>59.0,"救出後の通常入力で持続時間とクールダウンを始める")
	check(_cpp_enemy(bridge,inside).stone==0.0 and bridge._core.hostiles_snapshot()[0].stone==0.0,"目が開ききるまでは石にしない")
	bridge.command("dev_tick_heroes",{"dt":2.0,"run_time":2.0})
	check(is_equal_approx(_cpp_enemy(bridge,inside).stone,1.1) and _cpp_enemy(bridge,outside).stone==0.0,"目が開ききると画面内の敵だけを石化する")
	check(is_equal_approx(bridge._core.hostiles_snapshot()[0].stone,1.1),"画面内の弾も砕けるまで石化する")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"石化中のランを保持する")
	bridge._core.step(0.5)
	bridge._core.step_hostiles(0.5)
	check(is_equal_approx(_cpp_enemy(bridge,inside).stone,0.6) and is_equal_approx(bridge._core.hostiles_snapshot()[0].stone,0.6),"敵と弾の石化は世界時間で減る")
	check(bridge.restore(held.value).ok,"石化の途中へ復帰する")
	check(is_equal_approx(_cpp_enemy(bridge,inside).stone,1.1) and is_equal_approx(bridge._core.hostiles_snapshot()[0].stone,1.1),"復帰で敵・弾の石の残り時間が戻る")
	var render: Dictionary = bridge.read_render(Rect2(-640,-360,1280,720),1.0)
	check(render.ok and render.value.petrified_enemies.size()==6,"石化した敵を表示配列へ出す")
	bridge.command("dev_tick_heroes",{"dt":0.6,"run_time":2.6})
	frame = _cpp_read(bridge)
	check(fixture._cpp_events.any(func(e): return e.type=="kill" and e.payload.id==inside),"石化した敵は一斉に砕ける")
	check(fixture._cpp_events.any(func(e): return e.type=="kill" and e.payload.id==source),"弾を撃った敵も一斉に砕ける")
	check(not fixture._cpp_events.any(func(e): return e.type=="kill" and e.payload.id==outside),"画面外の敵は砕けない")
	bridge._core.step_hostiles(0.01)
	check(bridge._core.hostiles_snapshot().is_empty(),"石化した弾は砕ける瞬間に消える")
	bridge.command("dev_tick_heroes",{"dt":1.2,"run_time":3.8})
	frame = _cpp_read(bridge)
	check(frame.ui.hero.active==0.0 and fixture._cpp_events.any(func(e): return e.type=="hero_power_end"),"効果終了を通知する")
	bridge.dispose()
	failed += fixture.failed
	fixture.free()
	_cpp_perseus_boss()
	print("[cpp_H_perseus] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _cpp_perseus_boss() -> void:
	var fixture = load("res://tests/runtime/monoceros.gd").new()
	var scene: Dictionary = fixture.charge_fixture(true,false,450.0,false,"horn_wave")
	check(not scene.is_empty(),"ボスの衝撃波と英雄を同じランで準備する")
	if scene.is_empty(): fixture.free(); return
	var bridge = scene.bridge
	_cpp_rescue(bridge,"perseus")
	bridge._core.step(0.01)
	bridge._core.step(0.1)
	bridge._core.step(0.05)
	check(fixture.wave_rows(bridge).size()==1,"停止の確認に使う角の衝撃波を放つ")
	var input := Intent.new()
	input.hero_press = true
	var frame := _cpp_step(bridge,input)
	check(frame.ui.hero.boss_stun==0.0,"目が開ききるまではボスを止めない")
	bridge.command("dev_tick_heroes",{"dt":2.0,"run_time":2.0})
	frame = _cpp_read(bridge)
	check(frame.ui.hero.boss_stun==1.5,"目が開ききるとボスの停止時間を英雄定義から設定する")
	var radius: float = fixture.wave_rows(bridge)[0].radius
	var clock: float = bridge.command("dev_boss_body_state").value[0].clock
	var world: float = frame.ui.world_time
	var drawing := Intent.new()
	drawing.press = true
	drawing.pen = Vector2(300,0)
	frame = _cpp_step(bridge,drawing)
	var advanced := true
	for i in 178:
		var result: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
		advanced = advanced and result.ok and bridge.delivery_error.get("ok",true)
	check(advanced,"停止期限までの固定更新と通知配信を通す")
	frame = _cpp_read(bridge)
	check(frame.ui.hero.boss_stun>0.0 and frame.ui.hero.boss_stun<=1.0/120.0+0.00001,"スロー中もボス停止だけ実秒で減る")
	check(frame.ui.world_time-world<1.0 and fixture.wave_rows(bridge)[0].radius==radius and bridge.command("dev_boss_body_state").value[0].clock==clock,"ボス停止中は本体と本体所有の衝撃波を進めない")
	for i in 4: _cpp_step(bridge)
	frame = _cpp_step(bridge)
	check(frame.ui.hero.boss_stun==0.0 and fixture.wave_rows(bridge)[0].radius>radius,"停止期限後に衝撃波とボスを再開する")
	bridge.dispose()
	failed += fixture.failed
	fixture.free()

func _cpp_draw(bridge,launch := true) -> void:
	check(bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2.ZERO}).ok,"なぞりの開始位置を用意する")
	check(bridge._core.handle_draw({"press":true,"pen":Vector2(-300,0)},0,1.0),"通常の入口で線を描き始める")
	check(bridge._core.handle_draw({"has_cursor":true,"pen":Vector2(300,0)},1000,1.0),"通常の入口で線を伸ばす")
	if launch: check(bridge._core.handle_draw({"has_cursor":true,"press":true,"pen":Vector2(300,0)},2000,1.0),"同じ線を確定して突進する")

func _cpp_leo() -> void:
	var fixture = load("res://tests/integration/hero_guidance.gd").new()
	var bridge = fixture._cpp_fixture(true,100000.0)
	_cpp_rescue(bridge,"leo")
	bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2.ZERO})
	var intent := Intent.new()
	intent.hero_press = true
	var frame := _cpp_step(bridge,intent)
	check(frame.ui.hero.trace_width==4.0 and is_equal_approx(frame.ui.hero.active,14.0-1.0/120.0),"救出したしし座は発動中だけ定義の幅倍率を使う")
	var wide: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(0,100)}).value
	var armor: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2.ZERO}).value
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"しし座の残り時間と敵を保持する")
	_cpp_draw(bridge)
	check(bridge._core.draw_snapshot().tracing and bridge._core.step_draw(1.0),"広い当たりの突進を実際に進める")
	_cpp_read(bridge)
	check(fixture._cpp_events.any(func(e): return e.type=="combat_damage" and e.payload.target_id==wide and e.payload.applied>0.0),"通常の幅では届かない敵へなぞりが当たる")
	check(fixture._cpp_events.any(func(e): return e.type=="combat_damage" and e.payload.target_id==armor and e.payload.cause=="ram" and e.payload.applied>0.0),"しし座のなぞりは高い装甲を無視する")
	bridge.command("dev_tick_heroes",{"dt":14.0,"run_time":14.0})
	frame = _cpp_read(bridge)
	check(frame.ui.hero.active==0.0 and frame.ui.hero.trace_width==1.0,"実秒の期限で幅が元に戻る")
	check(bridge.restore(held.value).ok,"しし座の効果途中へ戻す")
	frame = _cpp_read(bridge)
	check(frame.ui.hero.trace_width==4.0 and is_equal_approx(frame.ui.hero.active,14.0-1.0/120.0),"復帰で残り時間と実効幅が戻る")
	bridge.command("dev_tick_heroes",{"dt":14.0,"run_time":14.0})
	var event_start: int = fixture._cpp_events.size()
	_cpp_draw(bridge)
	bridge._core.step_draw(1.0)
	_cpp_read(bridge)
	var normal: Array = fixture._cpp_events.slice(event_start)
	check(not normal.any(func(e): return e.type=="combat_damage" and e.payload.target_id==wide and e.payload.applied>0.0),"効果終了後は元の幅の外へ当たらない")
	bridge.dispose()
	failed += fixture.failed
	fixture.free()
	print("[cpp_H_leo] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _cpp_second_line(bridge) -> void:
	check(bridge._core.handle_draw({"press":true,"pen":Vector2(-300,200)},3000,1.0),"二本目を別の位置から描き始める")
	check(bridge._core.handle_draw({"has_cursor":true,"pen":Vector2(300,200)},4000,1.0),"二本目を伸ばす")
	check(bridge._core.handle_draw({"has_cursor":true,"press":true,"pen":Vector2(300,200)},5000,1.0),"二本の線を確定する")

func _cpp_gemini() -> void:
	var fixture = load("res://tests/integration/hero_guidance.gd").new()
	var bridge = fixture._cpp_fixture(true)
	_cpp_rescue(bridge,"gemini")
	bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2.ZERO})
	var input := Intent.new()
	input.hero_press = true
	_cpp_step(bridge,input)
	var main_enemy: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2.ZERO}).value
	var twin_enemy: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(0,200)}).value
	_cpp_draw(bridge)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	var frame := _cpp_read(bridge)
	check(frame.ui.hero.twin.first.size()==2 and frame.ui.draw.drawing and not frame.ui.draw.tracing and frame.ui.draw.draw_points.is_empty(),"一本目を保存して突進せず次の描き始めを待つ")
	var gauge: float = frame.ui.draw.gauge
	var limit: float = frame.ui.draw.draw_limit
	check(gauge<1.0 and fixture._cpp_events.any(func(e): return e.type=="twin_first"),"一本目だけで使用量を減らして通知する")
	var first_held: Dictionary = bridge.checkpoint()
	_cpp_second_line(bridge)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	frame = _cpp_read(bridge)
	check(frame.ui.draw.tracing and frame.ui.hero.twin.tracing and frame.ui.hero.twin.first.is_empty() and frame.ui.hero.twin.path[0]==Vector2(-300,200),"本体は一本目、双子は別の位置の二本目を走る")
	check(frame.ui.draw.gauge==gauge and frame.ui.draw.draw_limit==limit,"二本目でゲージを追加消費せず長さの上限も保つ")
	bridge._core.step_draw(0.01)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	frame = _cpp_read(bridge)
	var at: Vector2 = frame.ui.hero.twin.position
	check(is_equal_approx(at.x,frame.ui.ship.ship_pos.x) and at.y==200.0,"双子は本体と同じなぞり速度で進む")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok and first_held.ok,"一本目保存中と双子の途中を保持する")
	bridge._core.step_draw(1.0)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	frame = _cpp_read(bridge)
	check(not frame.ui.draw.tracing and not frame.ui.hero.twin.tracing and frame.ui.hero.twin.path.is_empty(),"二本を走り終えると双子の状態を片付ける")
	check(fixture._cpp_events.any(func(e): return e.type=="combat_damage" and e.payload.target_id==main_enemy and e.payload.cause=="ram" and e.payload.applied>0.0),"本体の線で通常の突進命中を解決する")
	var hits: Array = fixture._cpp_events.filter(func(e): return e.type=="combat_damage" and e.payload.target_id==twin_enemy and e.payload.cause=="ram" and e.payload.applied>0.0)
	check(hits.size()==1,"双子の線も同じ敵へ一度だけ体当たりする")
	check(bridge.restore(held.value).ok,"双子が進んだ途中へ戻す")
	frame = _cpp_read(bridge)
	check(frame.ui.hero.twin.position==at and frame.ui.hero.twin.tracing and frame.ui.hero.active>9.0,"復帰で双子の位置・進み・残り時間が戻る")
	bridge.command("dev_tick_heroes",{"dt":10.0,"run_time":10.0})
	frame = _cpp_read(bridge)
	check(frame.ui.hero.active==0.0 and frame.ui.hero.twin.tracing,"効果の期限後も発進済みの双子を残す")
	bridge._core.step_draw(1.0)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":10.0})
	check(not _cpp_read(bridge).ui.hero.twin.tracing,"期限後の双子も最後まで走る")
	check(bridge.restore(first_held.value).ok,"一本目保存中へ戻す")
	bridge._core.handle_draw({"touch":true,"pen_release":true},6000,1.0)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	frame = _cpp_read(bridge)
	check(not frame.ui.draw.drawing and frame.ui.hero.twin.first.is_empty(),"二本目を描く前の取消で保存した一本目も消す")
	bridge.dispose()
	failed += fixture.failed
	fixture.free()
	print("[cpp_H_gemini] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _cpp_hero_tick(bridge,dt: float,time: float) -> Dictionary:
	check(bridge.command("dev_tick_heroes",{"dt":dt,"run_time":time}).ok,"英雄を指定の実秒だけ進める")
	return _cpp_read(bridge)

func _cpp_hercules() -> void:
	var fixture = load("res://tests/integration/hero_guidance.gd").new()
	var bridge = fixture._cpp_fixture(true,100000.0,100000.0)
	_cpp_rescue(bridge,"hercules")
	bridge.command("dev_ship_motion",{"position":Vector2.ZERO,"velocity":Vector2.ZERO})
	var enemy: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(120,0)}).value
	var input := Intent.new()
	input.hero_press = true
	var frame := _cpp_step(bridge,input)
	var fire: Dictionary = frame.ui.hero.hercules
	check(frame.ui.hero.active>9.0 and fire.falls.size()==3 and fire.burns.is_empty(),"救出して発動すると敵を狙う火の隕石を出す")
	var at := Vector2(fire.falls[0],fire.falls[1])
	check(at.distance_to(Vector2(120,0))<=40.00001 and is_equal_approx(fire.falls[2],0.6-1.0/120.0),"敵の近くをRunRandomで狙い落下時間を実秒で減らす")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"落下中の残り時間と乱数を保持する")
	_cpp_hero_tick(bridge,0.3,0.3)
	frame = _cpp_hero_tick(bridge,0.3,0.6)
	fire = frame.ui.hero.hercules
	check(fire.falls.size()==3 and fire.burns.size()==3 and is_equal_approx(fire.burns[2],2.7),"着弾後は次の落下と燃える跡を独立して保持する")
	var first_fire: Array = fixture._cpp_events.filter(func(e): return e.type=="combat_damage" and e.payload.target_id==enemy and e.payload.cause=="fire" and e.payload.applied>0.0)
	check(first_fire.size()==2 and is_equal_approx(first_fire[1].payload.applied/first_fire[0].payload.applied,0.3),"着弾と炎の周期命中は装甲を無視して定義の倍率を使う")
	check(_cpp_enemy(bridge,enemy).fire_hit==frame.ui.world_time,"実際に当たった世界時刻を敵の焼却判定へ残す")
	check(fixture._cpp_events.any(func(e): return e.type=="explode" and e.payload.cause=="fire"),"着弾の爆発を既存の表示通知へ渡す")
	var current_cd: float = frame.ui.hero.cooldown
	check(not bridge.command("dev_set_hero",{"id":"未登録"}).ok,"未登録の英雄選択を拒否する")
	check(bridge.command("dev_set_hero",{"id":""}).ok,"実験場の正式入口で英雄の力を外す")
	var cleared := _cpp_read(bridge)
	check(cleared.ui.hero.power==&"" and cleared.ui.hero.active==0.0 and cleared.ui.hero.cooldown==current_cd and cleared.ui.hero.hercules==fire,"選択解除はCDと発射済みの隕石・炎を維持する")
	check(bridge.command("dev_set_hero",{"id":"leo"}).ok,"実験場の正式入口で別の英雄を選ぶ")
	var selected := _cpp_read(bridge)
	check(selected.ui.hero.power==&"leo" and selected.ui.hero.active==0.0 and selected.ui.hero.cooldown==current_cd,"英雄の選択は旧Labと同じ項目だけを変更する")
	check(bridge.restore(held.value).ok,"選択試行前の落下途中へ戻す")
	_cpp_hero_tick(bridge,0.3,0.3)
	frame = _cpp_hero_tick(bridge,0.3,0.6)
	fire = frame.ui.hero.hercules
	var expected: Dictionary = fire.duplicate(true)
	var expected_random: int = bridge._core.random_state()
	check(bridge.restore(held.value).ok,"落下の途中へ戻す")
	_cpp_hero_tick(bridge,0.3,0.3)
	frame = _cpp_hero_tick(bridge,0.3,0.6)
	check(frame.ui.hero.hercules==expected and bridge._core.random_state()==expected_random,"復帰で次の目標と落下・燃焼の残り時間が再現する")
	var events_before: int = fixture._cpp_events.size()
	_cpp_hero_tick(bridge,0.25,0.85)
	var periodic: Array = fixture._cpp_events.slice(events_before).filter(func(e): return e.type=="combat_damage" and e.payload.target_id==enemy and e.payload.cause=="fire" and e.payload.applied>0.0)
	check(periodic.size()==1,"世界時間を進めなくても0.25実秒で炎がもう一度当たる")
	check(bridge.restore(held.value).ok,"効果終了付近の確認へ戻す")
	_cpp_hero_tick(bridge,9.5,9.5)
	_cpp_hero_tick(bridge,0.35,9.85)
	frame = _cpp_hero_tick(bridge,0.15,10.0)
	check(frame.ui.hero.active==0.0 and frame.ui.hero.hercules.falls.size()==3,"力が終わっても発射済みの隕石は落下を続ける")
	frame = _cpp_hero_tick(bridge,0.11,10.11)
	check(frame.ui.hero.hercules.falls.is_empty() and frame.ui.hero.hercules.burns.size()==3,"効果終了後も着弾して炎を残す")
	frame = _cpp_hero_tick(bridge,3.0,13.11)
	check(frame.ui.hero.hercules.falls.is_empty() and frame.ui.hero.hercules.burns.is_empty(),"燃焼の寿命で残った表示と命中を片付ける")
	bridge.dispose()
	failed += fixture.failed
	fixture.free()
	print("[cpp_H_hercules] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
