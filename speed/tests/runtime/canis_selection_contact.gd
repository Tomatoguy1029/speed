## 本番の全技・条件を通して火炎と連携を選び、接触で自機を反射させない。
extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("exercise")
func fixture(boss_name := "canis_major", armor_override := -1.0) -> Dictionary:
 var builder=load("res://tools/content/build_run_content.gd")
 var cfg=load("res://data/config.tres").duplicate(true)
 cfg.planet_radius=0.0
 cfg.base_hp=1000.0
 var definition=load("res://data/bosses/%s.tres" % boss_name).duplicate(true)
 if armor_override>=0:
  definition.armor=armor_override
  definition.params.pack_size=0
  definition.params.call_below=0
 var package: Dictionary=builder.boss_package(definition,cfg) if boss_name=="canis_major" else builder.boss_body_package(definition,cfg)
 var bridge=load("res://scripts/runtime/run_bridge.gd").new()
 var result: Dictionary=bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":187,"mode":1,"stage_id":"canis","profile":{},"settings":{"hitstop":false}})
 if not result.ok: print(boss_name,result); quit(1); return {}
 check(result.ok,"本番ボスパッケージを設定する")
 check(bridge.start(187,{"lab_mode":true,"position":Vector2(500,0)}).ok,"試行を開始する")
 bridge._core.set_motion_context(Vector2(500,0),Vector2(500,0),Vector2(3000,2000))
 var id: int=bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
 return {"bridge":bridge,"id":id,"package":package,"cfg":cfg}
func prepare(f: Dictionary, phase: int, selection: bool) -> void:
 check(f.bridge.command("dev_boss_trial",{"entity_id":f.id,"action":"prepare","phase":phase,"origin":Vector2.ZERO,"target":Vector2(500,0),"selection":selection,"steering_locked":true,"guard":0.0}).ok,"本番フローの試行条件を準備する")
func exercise() -> void:
 var f := fixture()
 for action: Dictionary in f.package.records.BossFlowAction:
  if action.external_id in ["hunt", "hunt_pounce"]: check(action.category==1,"連携技を単発と別の抽選分類へ生成する")
 for phase in ([] if "--contact-only" in OS.get_cmdline_user_args() else [1,2]):
  prepare(f,phase,true)
  f.bridge._core.set_run_guards({"invincible":true})
  var seen := {}
  var counts := {}
  var first_flame := -1.0
  for tick in 600:
   check(f.bridge._core.step(0.05),"自然AIを更新する")
   f.bridge._core.step_hazards(0.05)
   for t: Dictionary in f.bridge.command("dev_boss_state").value:
    if seen.has(t.id): continue
    seen[t.id]=true
    counts[t.technique]=counts.get(t.technique,0)+1
    if t.technique=="sirius_flame" and first_flame<0: first_flame=tick*0.05
  print("canis phase=",phase," starts=",counts," first_flame=",first_flame)
  check(counts.size()>=3,"本番条件で複数の技を自然選択する")
  if phase==1: check(first_flame<0 and not counts.has("sirius"),"第1形態は火炎区間をスキップする")
  else: check(first_flame>=0 and first_flame<10.0,"第2形態は最初の巡回で火炎放射を使う")
 f.bridge.dispose()
 f=fixture()
 prepare(f,1,false)
 f.bridge._core.set_run_guards({"invincible":false})
 f.bridge.command("dev_ship_motion",{"position":Vector2(95,0),"velocity":Vector2(-20,0)})
 var before: Dictionary=f.bridge._core.ship_snapshot()
 f.bridge._core.collide_ship(Vector2(130,0),f.cfg.ship_radius)
 var after: Dictionary=f.bridge._core.ship_snapshot()
 check(after.ship_hp<before.ship_hp,"通常接触のダメージを保つ")
 check(after.ship_vel==before.ship_vel and after.ship_pos==before.ship_pos,"通常接触で速度反射・最低反発速度・位置押し出しを加えない")
 f.bridge.dispose()
 f=fixture()
 prepare(f,1,false)
 f.bridge._core.set_run_guards({"invincible":false})
 f.bridge.command("dev_ship_motion",{"position":Vector2(500,0),"velocity":Vector2(-20,0)})
 before=f.bridge._core.ship_snapshot()
 check(f.bridge.command("dev_boss_trial",{"entity_id":f.id,"action":"start","technique":"pounce"}).ok,"飛びかかりを開始する")
 for tick in 130: f.bridge._core.step(0.01)
 after=f.bridge._core.ship_snapshot()
 check(after.ship_hp<before.ship_hp,"着地のダメージを保つ")
 check(after.ship_vel==before.ship_vel and after.ship_pos==before.ship_pos,"着地で自機を反射・移動させない")
 f.bridge.dispose()
 f=fixture("centaurus")
 if f.is_empty():return
 f.bridge.command("dev_ship_motion",{"position":Vector2(50,0),"velocity":Vector2(-20,0)})
 f.bridge._core.collide_ship(Vector2(130,0),f.cfg.ship_radius)
 after=f.bridge._core.ship_snapshot()
 check(after.ship_vel==Vector2(-20,0),"ケンタウルスでも通常接触の自機反射を除去する")
 f.bridge.dispose()
 f=fixture("canis_major",1000000.0)
 prepare(f,1,false)
 f.bridge.command("dev_ship_motion",{"position":Vector2(-500,0),"velocity":Vector2(-3000,0)})
 before=f.bridge._core.ship_snapshot()
 var hp_before: float=f.bridge.command("dev_boss_body_state").value[0].hp
 f.bridge._core.collide_ship(Vector2(500,0),f.cfg.ship_radius)
 after=f.bridge._core.ship_snapshot()
 check(after.ship_vel==before.ship_vel and after.ship_pos==before.ship_pos,"装甲不足の体当たりでもボスは自機を反射・押し出ししない")
 check(f.bridge.command("dev_boss_body_state").value[0].hp<hp_before,"装甲不足でも衝突ダメージは保つ")
 f.bridge.dispose()
 print("[canis_selection_contact] failures=",failures)
 quit(1 if failures else 0)
