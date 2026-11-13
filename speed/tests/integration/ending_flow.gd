extends Node
class MemorySave:
 extends "res://scripts/managers/save_manager.gd"
 func save() -> void: pass
 func _save_settings() -> void: pass
var failed := 0
func check(ok: bool, label: String) -> void:
 if not ok:
  failed += 1
  push_error(label)
func _ready() -> void:
 var settings := SaveManager.settings.duplicate(true)
 SaveManager.set_script(MemorySave)
 SaveManager.settings = settings
 SaveManager.data = SaveManager.default_data()
 TranslationServer.set_locale("ja")
 var stage_id := 0
 for i in range(1, 6):
  var stage = ContentManager.stage(i)
  if stage != null and stage.boss_id == &"draco": stage_id = i
 check(stage_id > 0, "Draco stage exists")
 GameManager.screen = GameManager.Screen.RUN
 GameManager.finish_run({"result_id":90001,"stage":stage_id,"cleared":true,"coins":17})
 check(GameManager.screen == GameManager.Screen.ENDING, "Draco clear opens ending")
 var saved := SaveManager.data.duplicate(true)
 var ending = load("res://scenes/app/ending.tscn").instantiate()
 add_child(ending)
 await get_tree().create_timer(0.9).timeout
 ending._auto_play.set_pressed_no_signal(false)
 ending.scene_fade_seconds = 0.01
 check(ending.story.SCENES.size() == 4, "four scenes")
 for i in range(4):
  ending._show_scene(i)
  await get_tree().create_timer(0.04).timeout
  check(ending._picture.get_child_count() == 1, "replace image, no intro overlay")
  for key in ending.story.SCENES[i].text:
   ending._text.text = tr(key)
   await get_tree().process_frame
   check(ending._text.text != key, "localized story")
   check(ending._text.get_line_count()*ending._text.get_line_height() <= ending._text.size.y, "text fits")
 ending.paragraph_index = 1
 ending._begin_paragraph()
 ending._text.visible_characters = ending._text.get_total_character_count()
 ending.advance()
 check(GameManager.screen == GameManager.Screen.RESULT, "complete opens result")
 check(SaveManager.data == saved, "no duplicate rewards or intro flag changes")
 ending.queue_free()
 GameManager.screen = GameManager.Screen.RUN
 GameManager.finish_run({"result_id":90002,"stage":stage_id,"cleared":false,"coins":0})
 check(GameManager.screen == GameManager.Screen.RESULT, "death skips ending")
 GameManager.screen = GameManager.Screen.RUN
 GameManager.finish_run({"result_id":90003,"stage":1,"cleared":true,"coins":0})
 check(GameManager.screen == GameManager.Screen.RESULT, "other stage skips ending")
 GameManager.screen = GameManager.Screen.RUN
 GameManager.finish_run({"result_id":90004,"stage":stage_id,"cleared":true,"endless":true,"coins":0})
 check(GameManager.screen == GameManager.Screen.RESULT, "endless skips ending")
 GameManager.screen = GameManager.Screen.ENDING
 var skip = load("res://scenes/app/ending.tscn").instantiate()
 add_child(skip)
 await get_tree().process_frame
 saved = SaveManager.data.duplicate(true)
 skip._finish()
 check(GameManager.screen == GameManager.Screen.RESULT, "skip opens result")
 check(SaveManager.data == saved, "skip does not record again")
 skip.queue_free()
 print("ending_flow: ", "OK" if failed == 0 else "FAILED")
 get_tree().quit(failed)
