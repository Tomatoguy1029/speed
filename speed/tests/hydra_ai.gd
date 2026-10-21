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
 var cues: Array[Dictionary] = []
 boss.presentation_event.connect(func(event): cues.append(event))
 boss._tech_cd = 0.0
 boss._update_blackboard()
 check(boss.count == 3, "starts with three heads")
 check(lab.run.bosses.has_method("actor_for_row") and lab.run.bosses.actor_for_row(boss.body) == boss, "renderer resolves self-drawing Hydra from lab manager")
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
 check(cues.any(func(e): return e.cue == &"warning_started" and e.technique == &"north") and boss._presentation.slots.has(-1), "warning event drives placeholder scene")
 var clock: float = boss.timeline.current_animation_position
 boss.sim_tick(0.5, 0.0)
 check(boss.timeline.current_animation_position == clock, "zero world delta pauses gameplay and presentation")
 check(is_equal_approx(boss._warning_duration(&"north"), 2.4), "warning duration follows gameplay method key")
 boss.timeline.advance(2.4)
 check(cues.any(func(e): return e.cue == &"attack_started" and e.technique == &"north"), "timeline emits attack movement at actual method key")
 root.abort()
 boss.interrupt_tech()
 check(not boss.busy and not boss.timeline.is_playing() and boss.recovery_t > 0.0, "interrupt clears timeline and opens recovery")
 check(boss._presentation.flashes.is_empty() and boss._presentation.slots.size() == 1 and boss._presentation.slots[-1].cue == &"recovery_started", "abort removes attack effects and shows recovery")
 var hits := cues.filter(func(e): return e.cue == &"hit").size()
 lab.run.combat.damage_enemy(boss.necks[0].row, 1.0, {"cause": &"weapon"})
 boss._tick_neck(boss.necks[0], 0, 0.0)
 check(cues.filter(func(e): return e.cue == &"hit").size() == hits + 1, "actual head damage emits hit")
 hits += 1
 lab.run.combat.damage_enemy(boss.necks[0].row, 0.0, {"cause": &"weapon"})
 boss._tick_neck(boss.necks[0], 0, 0.0)
 check(cues.filter(func(e): return e.cue == &"hit").size() == hits, "zero damage emits no invented hit")
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
 boss.recovery_t = 0.0
 root.set_weight(2, 0.0)
 root.set_weight(1, 1.0)
 boss._update_blackboard()
 check(root.execute(0.01) == BTTask.RUNNING and boss.tech == &"east", "tree weight selects specified east")
 boss.timeline.advance(3.0)
 var hazards: Array[int] = []
 for neck in boss.necks:
  if neck.hazard >= 0: hazards.append(neck.hazard)
 root.abort()
 check(not hazards.is_empty() and hazards.all(func(h): return lab.run.projectiles.hazard_alive[h] == 0), "interrupt releases east beam hazards")
 check(load("res://gyms/hydra_trial.tscn") != null, "playable draft scene loads")
 lab.queue_free()
 await get_tree().process_frame
 print("[hydra] passed=%d failed=%d" % [passed, failures])
 get_tree().quit(1 if failures else 0)
