## 全登録技を本番セッションで反復・中断し、入力と後片付けを確認する。
extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("exercise")
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func exercise() -> void:
 var save_before: String = JSON.stringify(root.get_node("SaveManager").data)
 var trial = load("res://gyms/boss_flow_trial.tscn").instantiate()
 root.add_child(trial)
 for frame in 30: await process_frame
 check(trial.manual != null, "standalone opens the existing trial with manual controls")
 if trial.manual == null: quit(1); return
 for boss_index in 2:
  if boss_index == 1: await trial._switch_boss(1)
  trial.session.playing = false
  # 起動中に実画面から記録した操舵を、低水準の固定更新試験へ持ち越さない。
  # UIの実行経路は同じ消去を行うが、下のdebug.execute直接呼び出しは行わない。
  trial._clear_trial_input()
  var session = trial.session
  var a = trial.preview_actor
  var debug = trial.manual
  # 通常AIが既に技を選んだ後でも、手動実行がその実行状態を片付ける。
  for tick in 1200:
   if a.flow_runner.active: break
   session.step()
  check(a.flow_runner.active, "autonomous move starts before manual takeover")
  check(debug.moves().size() == (6 if boss_index == 0 else 13), "enumerate every registered move")
  var original_phase: int = a.phase
  var original_zoom: float = session.run.state.camera_zoom
  var original_controls: bool = session.run.state.controls_locked
  for move in debug.moves():
   var id: String = String(move.technique)
   var phase: int = int(a.action_rules.conditions.get(id, {}).get("min_phase", 1))
   check(debug.execute(id, phase), "start " + id)
   check(not a.selection_enabled and a.mode == &"windup", "direct real windup " + id)
   check(String(a.technique) == ("charge" if boss_index == 0 and id == "combo" else id), "correct action " + id)
   check(debug.execute(id, phase), "repeat during telegraph " + id)
   for tick in 900:
    session.step()
    if a.mode == &"active": break
   check(a.mode == &"active", "reaches real active " + id)
   session.step()
   check(debug.execute(id, phase), "interrupt active " + id)
   for tick in 1800:
    session.step()
    if a.mode == &"recovery": break
   check(a.mode == &"recovery", "reaches recovery " + id)
   check(debug.execute(id, phase), "interrupt recovery " + id)
   for tick in 2400:
    session.step()
    if a.mode == &"idle": break
   check(a.mode == &"idle", "completes " + id)
   for tick in 12: session.step()
   check(a.mode == &"idle" and not a.flow_runner.active, "no autonomous selection " + id)
   debug.finish()
   check(a.selection_enabled and a.phase == original_phase, "restore AI and phase " + id)
   check(a.mode == &"idle" and a.technique == &"", "idle after cleanup " + id)
   check(session.run.projectiles.hostile_alive.count(1) == 0 and session.run.projectiles.hazard_alive.count(1) == 0, "clear live collision hazards " + id)
   check(not session.run.state.steering_locked and session.run.state.controls_locked == original_controls and is_equal_approx(session.run.state.camera_zoom, original_zoom), "restore controls and camera " + id)
   if boss_index == 1:
    check(a.retained_fields.is_empty() and a.picaro.members.is_empty() and a.placed_meteors.is_empty() and a.closing_walls.is_empty() and a.clone_damage_rows.is_empty(), "release move resources " + id)
   print("[boss-debug] ", a.def.id, "/", id, " phase=", phase, " repeated/active/recovery/completed")
  if boss_index == 0: _check_melee_input_boundary(trial)
  check(not debug.execute("missing", 1), "unknown move rejected")
  check(not debug.execute(String(debug.moves()[0].technique), 99), "invalid phase rejected")
  var gated := "lance" if boss_index == 0 else "inhale"
  check(not debug.execute(gated, 1), "phase constraint rejected")
  check(not debug.active and a.selection_enabled, "invalid requests do not interrupt AI")
  check(debug.execute("charge", 1), "start before invalid request")
  check(not debug.execute("missing", 1) and a.mode == &"windup" and a.technique == &"charge", "invalid request preserves current action")
  if boss_index == 1:
   var valid_move: Resource = a._moves[&"bite"]
   a._moves[&"bite"] = BossTechnique.new()
   check(not debug.execute("bite", 1) and debug.message.contains("スクリプト"), "実行処理がない技は理由を表示する")
   a._moves[&"bite"] = valid_move
  debug.finish()
  # Damage has to come from the actual actor and combat path, with invulnerability off.
  var attack := "charge" if boss_index == 0 else "bite"
  session.run.ship.invincible = false
  session.run.state.ship_invuln = 0.0
  var hp: float = session.run.state.ship_hp
  check(debug.execute(attack, 1), "damage test starts")
  for tick in 300:
   session.step()
   if session.run.state.ship_hp < hp: break
  check(session.run.state.ship_hp < hp, "real collision damages the ship: " + attack)
  var cause := &"horn" if boss_index == 0 else &"bite"
  check(session.events.any(func(e): return e.get("type", &"") == &"hurt" and e.get("cause", &"") == cause and e.get("source", &"") == a.def.id), "real hit event identifies attack source: " + attack)
  session.run.ship.invincible = true
  session.run.state.ship_hp = session.run.state.stats.max_hp
  debug.finish()
  # Unknown request must stay selected instead of silently executing another move.
  trial._populate_moves("missing")
  trial._process(0.0)
  check(trial._execute.disabled and trial._manual_message.text.contains("未登録"), "invalid selection visibly disabled")
  trial._populate_moves()
  session.run.input._press = true
  session.run.input._hero_press = true
  session.playing = false
  var before: int = session.tick
  trial._process(0.0)
  check(not session.run.input.poll().press and not session._intent.press and session.tick == before, "paused UI drops buffered game input")
  var click := InputEventMouseButton.new()
  click.button_index = MOUSE_BUTTON_LEFT
  click.position = trial._move_picker.get_global_rect().get_center()
  click.pressed = true
  root.push_input(click)
  click = click.duplicate()
  click.pressed = false
  root.push_input(click)
  await process_frame
  trial._move_picker.get_popup().hide()
  check(not session.run.input.poll().press and session.tick == before and not session.run.state.drawing, "real selector click while paused never draws or advances the game")
  # Resume the real autonomous selector after leaving manual control.
  a.table.pos[a.body] = Vector2.ZERO
  a.table.facing[a.body] = 0.0
  session.run.state.ship_pos = Vector2(500, 0)
  for tick in 1200:
   session.step()
   if a.flow_runner.active: break
  check(a.flow_runner.active, "autonomous AI resumes")
  if DisplayServer.get_name() != "headless":
   session.playing = false
   await process_frame
   await process_frame
   root.get_texture().get_image().save_png("/tmp/speed-boss-debug-%s.png" % a.def.id)
 check(JSON.stringify(root.get_node("SaveManager").data) == save_before, "does not modify persistent save data")
 trial.manual.execute("inhale", 3)
 var actor = trial.preview_actor
 var state = actor.run_state
 # Let the real inhale catch the ship before closing, so cleanup must release its lock.
 for tick in 300:
  trial.session.step()
  if state.steering_locked: break
 check(state.steering_locked, "real inhale acquires steering lock before exit")
 trial.queue_free()
 await process_frame
 await process_frame
 check(not is_instance_valid(actor), "exit releases actor and session")
 check(not state.controls_locked and not state.steering_locked, "exit restores control locks")
 for player in root.get_node("AudioManager")._players: player.stop(); player.stream = null
 await create_timer(0.2).timeout
 print("[boss-debug] checks=", checks, " failures=", failures)
 quit(1 if failures else 0)

func _check_melee_input_boundary(trial) -> void:
 # 残留操舵は予告中に自機を背後角・射程の外へ動かす。実行ボタンは消去してから技を開始する。
 for id in ["kick", "sweep"]:
  for cursor in [Vector2(1000, 0), Vector2(-2000, 0)]:
   trial.session.perform("input", {"has_cursor": true, "cursor": [cursor.x, cursor.y]})
   check(trial.session._intent.has_cursor, "record startup steering before " + id)
   trial._populate_moves(id)
   trial._execute.grab_focus()
   trial._execute.pressed.emit()
   trial.session.playing = false
   check(not trial.session._intent.has_cursor, "execute button clears startup steering")
   for tick in 900:
    trial.session.step()
    if trial.preview_actor.mode == &"active": break
   check(trial.preview_actor.mode == &"active", "execute button reaches real " + id + " with prior steering")
   trial.manual.finish()
