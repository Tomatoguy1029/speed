## Hydra の固定根元・狙い固定・再生猶予だけの短い回帰確認。
extends Node
var failures := 0
var passed := 0
func check(ok: bool, label: String) -> void:
 print("[hydra-target] ", "PASS " if ok else "FAIL ", label)
 if ok: passed += 1
 else: failures += 1
func _ready() -> void:
 var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
 add_child(lab)
 await lab.reset({"empty": true, "stage": 4, "ship_pos": [400, 0]})
 lab.run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
 var boss = lab.run.bosses.lab_instances.back().actor
 boss.hsm.set_active(false)
 check(boss.has_method("_neck_base"), "each neck has a body-fixed surface socket")
 if boss.has_method("_neck_base"):
  var neck = boss.necks[0]
  var base: Vector2 = boss._neck_base(neck)
  neck.angle += 1.0
  boss._follow_neck(neck, 0.1)
  check(boss._neck_base(neck).is_equal_approx(base) and neck.segs[0].is_equal_approx(base), "aiming moves the tip, not its socket")
  boss.table.facing[boss.body] += 0.4
  check(boss._neck_base(neck).is_equal_approx(boss.table.pos[boss.body] + (base - boss.table.pos[boss.body]).rotated(0.4)), "socket follows the body's transform")
  boss.table.facing[boss.body] -= 0.4
  var facing: float = boss.table.facing[boss.body]
  boss._move(0.5)
  check(is_equal_approx(boss.table.facing[boss.body], facing), "engaged body holds its orientation")
  boss._set_count(8)
  boss._tech_cd = 0.0
  check(boss.try_start_tech(&"north", 1.0), "starts aimed bite")
  lab.run.state.ship_pos = Vector2(450, -40)
  boss.sim_tick(0.1, 0.1)
  check(boss.north_target.is_equal_approx(lab.run.state.ship_pos), "warning captures the player before lock")
  boss.north_curl()
  var locked: Vector2 = boss.north_target
  lab.run.state.ship_pos = Vector2(600, 250)
  boss.north_burst()
  boss.sim_tick(0.05, 0.05)
  boss.north_follow()
  check(boss.north_target.is_equal_approx(locked), "player movement after lock does not redirect the bite")
  var closest := INF
  for head in boss.necks: closest = minf(closest, boss._head_pos(head).distance_to(locked))
  check(closest < 1.0, "at least one head actually reaches the advertised target")
  lab.run.ship.invincible = false
  lab.run.state.ship_pos = locked
  lab.run.state.ship_invuln = 0.0
  var hp: float = lab.run.state.ship_hp
  lab.run.projectiles.tick(0.01, 0.01)
  check(lab.run.state.ship_hp < hp, "bite sweep damages a player who stays on the marked target")
  lab.run.state.ship_pos = locked + Vector2(0, 500)
  lab.run.state.ship_invuln = 0.0
  hp = lab.run.state.ship_hp
  lab.run.projectiles.tick(0.01, 0.01)
  check(lab.run.state.ship_hp == hp, "moving away from the locked target avoids the bite")
  var tip: Vector2 = boss._head_pos(boss.necks[0])
  boss.interrupt_tech()
  check(boss._head_pos(boss.necks[0]).is_equal_approx(tip), "interruption preserves tip position for recovery without teleporting")
  boss.recovery_t = 0.0
  lab.run.combat.damage_enemy(boss.necks[0].row, 1e6, {"cause": &"ram"})
  lab.run.enemies.cleanup()
  var first = boss.necks[0]
  check(first.regrow >= float(boss.def.params.regrow) + 2.0 * float(boss.def.params.regrow_per_head), "remaining heads extend the first defeat's grace")
  boss._tick_neck(first, 0, float(boss.def.params.regrow) + 0.01)
  check(first.row == -1, "first head stays down beyond the old independent timer")
  lab.run.combat.damage_enemy(boss.necks[1].row, 1e6, {"cause": &"ram"})
  lab.run.enemies.cleanup()
  check(first.regrow >= float(boss.def.params.regrow) + float(boss.def.params.regrow_per_head), "another defeat extends grace for already defeated heads")
  boss.busy = true
  var grace: float = first.regrow
  boss._tick_neck(first, 0, 100.0)
  check(first.row == -1 and first.regrow == grace, "major attacks pause regrowth")
  boss.busy = false
  for head in boss.necks:
   if boss._alive(head):lab.run.combat.damage_enemy(head.row, 1e6, {"cause": &"ram"})
  lab.run.enemies.cleanup()
  for head in boss.necks: head.regrow = 0.0
  boss.sim_tick(0.01, 0.01)
  check(boss.chance_t > 0.0 and boss.necks.all(func(head): return head.row == -1), "all-head defeat starts chance before expired timers can regrow")
  boss.sim_tick(float(boss.def.params.chance_time)+0.1,float(boss.def.params.chance_time)+0.1)
  check(boss.necks.all(func(head): return boss._alive(head)), "heads return after guaranteed central attack window")

 lab.queue_free()
 await get_tree().process_frame
 print("[hydra-target] passed=%d failed=%d" % [passed, failures])
 get_tree().quit(1 if failures else 0)
