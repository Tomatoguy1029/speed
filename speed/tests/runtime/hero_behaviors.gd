## 英雄の力は同じ入口を使い、それぞれのランにだけ作用する。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
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
	var inside: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":Vector2(120,0)}).value
	var outside: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":Vector2(50000,0)}).value
	var source: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":Vector2(250,80)}).value
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
	bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2(100,0)})
	var intent := Intent.new()
	intent.hero_press = true
	var frame := _cpp_step(bridge,intent)
	check(is_equal_approx(frame.ui.hero.active,15.0-1.0/120.0),"救出したしし座は定義の時間だけ効く")
	frame = _cpp_step(bridge)
	check(is_equal_approx(frame.ui.ship.ship_vel.length(),600.0),"獅子は定義の速さで駆ける")
	check(bridge._core.handle_draw({"press":true,"pen":Vector2(-300,0)},0,1.0) and not bridge._core.draw_snapshot().drawing,"獅子の間はなぞりを始められない")
	var struck: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":frame.ui.ship.ship_pos+Vector2(100,0)}).value
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"しし座の残り時間と敵を保持する")
	var start: int = fixture._cpp_events.size()
	_cpp_step(bridge)
	var hits: Array = fixture._cpp_events.slice(start).filter(func(e): return e.type=="combat_damage" and e.payload.target_id==struck and e.payload.applied>0.0)
	check(hits.size()==1 and hits[0].payload.cause=="ram" and hits[0].payload.applied<=25.0+0.001,"獅子の体に触れた敵へ、特性を除いた攻撃力×2.5で当たる")
	start = fixture._cpp_events.size()
	for i in 12: _cpp_step(bridge)
	check(not fixture._cpp_events.slice(start).any(func(e): return e.type=="combat_damage" and e.payload.target_id==struck),"同じ敵には間隔を置いて当たる")
	bridge.command("dev_tick_heroes",{"dt":10.0,"run_time":10.0})
	frame = _cpp_read(bridge)
	check(frame.ui.hero.active>4.0,"10秒経ってもしし座の効果が続く")
	bridge.command("dev_tick_heroes",{"dt":5.0,"run_time":15.0})
	frame = _cpp_read(bridge)
	check(frame.ui.hero.active==0.0,"15実秒の期限で獅子が終わる")
	check(bridge._core.handle_draw({"press":true,"pen":frame.ui.ship.ship_pos},0,1.0) and bridge._core.draw_snapshot().drawing,"獅子が終わるとなぞりを始められる")
	check(bridge.restore(held.value).ok,"しし座の効果途中へ戻す")
	frame = _cpp_read(bridge)
	check(frame.ui.hero.active>14.0 and StringName(frame.ui.hero.power)==&"leo","復帰で獅子の残り時間が戻る")
	bridge.dispose()
	failed += fixture.failed
	fixture.free()
	print("[cpp_H_leo] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _cpp_gemini() -> void:
	var fixture = load("res://tests/integration/hero_guidance.gd").new()
	var bridge = fixture._cpp_fixture(true)
	_cpp_rescue(bridge,"gemini")
	# 機体の向きを右へそろえる。反転の軸は機体の位置を通る横の線になる
	bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2(1,0)})
	var input := Intent.new()
	input.hero_press = true
	_cpp_step(bridge,input)
	var main_enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":Vector2(0,100)}).value
	var twin_enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":Vector2(0,-100)}).value
	bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2.ZERO})
	check(bridge._core.handle_draw({"press":true,"pen":Vector2(-300,0)},0,1.0),"ふたご座でも線は一本だけ描く")
	check(bridge._core.handle_draw({"has_cursor":true,"pen":Vector2(300,200)},1000,1.0),"線を斜めに伸ばす")
	check(bridge._core.handle_draw({"has_cursor":true,"press":true,"pen":Vector2(300,200)},2000,1.0),"一本の線を確定して突進する")
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	var frame := _cpp_read(bridge)
	var path: PackedVector2Array = frame.ui.hero.twin.path
	check(frame.ui.draw.tracing and frame.ui.hero.twin.tracing and path[0]==Vector2(-300,0) and path[path.size()-1].distance_to(Vector2(300,-200))<1.0,"影は描いた線を機体の向きで左右反転した経路を同時に走る")
	bridge._core.step_draw(0.01)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	frame = _cpp_read(bridge)
	var at: Vector2 = frame.ui.hero.twin.position
	var ship: Vector2 = frame.ui.ship.ship_pos
	check(absf(at.x-ship.x)<0.01 and absf(at.y+ship.y)<0.01,"影は本体と同じ速さで鏡の位置を進む")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"影の走行途中を保持する")
	bridge._core.step_draw(1.0)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	frame = _cpp_read(bridge)
	check(not frame.ui.draw.tracing and not frame.ui.hero.twin.tracing and frame.ui.hero.twin.path.is_empty(),"突進が終わると影の走行も片付ける")
	check(fixture._cpp_events.any(func(e): return e.type=="combat_damage" and e.payload.target_id==main_enemy and e.payload.cause=="ram" and e.payload.applied>0.0),"本体の線で通常の突進命中を解決する")
	var hits: Array = fixture._cpp_events.filter(func(e): return e.type=="combat_damage" and e.payload.target_id==twin_enemy and e.payload.cause=="ram" and e.payload.applied>0.0)
	check(hits.size()==1,"影の経路も同じ敵へ一度だけ体当たりする")
	check(bridge.restore(held.value).ok,"影が進んだ途中へ戻す")
	frame = _cpp_read(bridge)
	check(frame.ui.hero.twin.position==at and frame.ui.hero.twin.tracing and frame.ui.hero.active>9.0,"復帰で影の位置・進み・残り時間が戻る")
	bridge.command("dev_tick_heroes",{"dt":30.0,"run_time":30.0})
	frame = _cpp_read(bridge)
	check(frame.ui.hero.active==0.0 and frame.ui.hero.twin.tracing,"効果の期限後も走り出した影を残す")
	bridge._core.step_draw(1.0)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":30.0})
	check(not _cpp_read(bridge).ui.hero.twin.tracing,"期限後の影も最後まで走る")
	_cpp_draw(bridge)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":30.0})
	frame = _cpp_read(bridge)
	check(frame.ui.draw.tracing and not frame.ui.hero.twin.tracing,"効果が切れたあとの突進では影は走らない")
	bridge.dispose()
	failed += fixture.failed
	fixture.free()
	print("[cpp_H_gemini] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _cpp_hero_tick(bridge,dt: float,time: float) -> Dictionary:
	check(bridge.command("dev_tick_heroes",{"dt":dt,"run_time":time}).ok,"英雄を指定の実秒だけ進める")
	return _cpp_read(bridge)
