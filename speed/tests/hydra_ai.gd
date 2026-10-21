## Hydra だけの短い接続確認。実験セッションを使い、セーブ・録画へ書かない。
extends Node
var failures := 0
var passed := 0
func check(ok: bool, label: String):
 print("[hydra] ", "PASS " if ok else "FAIL ", label)
 if not ok: failures += 1
 else: passed += 1
func _ready():
 var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
 add_child(lab)
 await lab.reset({"empty": true, "stage": 4, "ship_pos": [400, 0]})
 lab.run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
 var boss = lab.run.bosses.lab_instances.back().actor
 boss._tech_cd = 0.0
 boss._update_blackboard()
 check(boss.count == 3, "starts with three heads")
 check(boss.attack_ready(&"north") and not boss.attack_ready(&"east"), "required heads gate techniques")
 check(lab.run.projectiles.director.waiting.is_empty(), "conditions do not reserve attacks")
 var root: BTTask = boss.decision.get_bt_instance().get_root_task()
 var bb: Blackboard = boss.decision.get_bt_instance().get_blackboard()
 var range_task = load("res://scripts/bosses/tasks/hydra_range.gd").new()
 range_task.initialize(boss, bb, boss)
 bb.set_var(&"player_distance", 2000.0)
 check(range_task.execute(0.01) == BTTask.FAILURE, "editable range rejects distant player")
 bb.set_var(&"player_distance", 400.0)
 var direction_task = load("res://scripts/bosses/tasks/hydra_direction.gd").new()
 direction_task.half_angle_degrees = 30.0
 direction_task.initialize(boss, bb, boss)
 bb.set_var(&"player_angle", PI)
 check(direction_task.execute(0.01) == BTTask.FAILURE, "editable direction rejects player behind")
 boss._update_blackboard()
 boss.hsm.update(0.01)
 check(boss.tech == &"north", "tree chooses eligible specified north technique")
 root.abort()
 boss.interrupt_tech()
 check(not boss.busy and not boss.timeline.is_playing() and boss.recovery_t > 0.0, "interrupt clears timeline and opens recovery")
 check(not boss.attack_ready(&"south"), "unsettled south stays disabled")
 boss.hsm.set_active(false)
 for expected in [5, 7, 9, 0]:
  for neck in boss.necks:
   if boss._alive(neck):
    lab.run.combat.damage_enemy(neck.row, 1e6, {"cause": &"ram"})
  lab.run.enemies.cleanup()
  boss._expose_cd = 0.0
  boss._tick_immortal(0.0)
  check(boss.exposed_t > 0.0, "all heads expose immortal at " + str(boss.count))
  if boss.count == 5 or boss.count == 7:
   # Heads are absent now, so required-head conditions must fail.
   check(not boss.attack_ready(&"east"), "head loss prevents east during exposure")
  var old_count = boss.count
  boss._tick_neck(boss.necks[0], 0, 100.0)
  check(boss.necks[0].row == -1, "heads stay absent during exposure")
  lab.run.combat.damage_enemy(boss.immortal_row, 1e6, {"cause": &"ram"})
  lab.run.enemies.cleanup()
  check((boss.count == expected) if expected else boss.table.hp[boss.body] <= 0.0, "pierce advances " + str(old_count) + " to " + str(expected))
 # Edit the live tree weights to select west exclusively, with the required heads present.
 boss._set_count(7)
 boss.run_state.ship_pos = Vector2(800, 0)
 boss.table.hp[boss.body] = boss.table.max_hp[boss.body]
 boss._tech_cd = 0.0
 boss.recovery_t = 0.0
 boss._tech_until.clear()
 for i in 3: root.set_weight(i, 0.0)
 root.abort()
 boss._update_blackboard()
 check(root.execute(0.01) == BTTask.FAILURE and not boss.busy, "zero weights disable all technique branches")
 root.set_weight(2, 1.0)
 check(root.execute(0.01) == BTTask.RUNNING and boss.tech == &"west", "tree weight selects specified west")
 root.abort()
 check(not boss.busy, "BT abort cancels west")
 lab.queue_free()
 await get_tree().process_frame
 print("[hydra] passed=%d failed=%d" % [passed, failures])
 get_tree().quit(1 if failures else 0)
