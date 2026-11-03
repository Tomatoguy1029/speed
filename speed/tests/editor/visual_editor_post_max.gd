## 両機能を同じ実行体に読み込み、編集画面の開閉がランと追加成長を変更しないことを確認する。
extends "res://tests/integration/post_max_ui.gd"

func _ready() -> void:
	await _cpp_editor_ready()

func _cpp_editor_ready() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	var saved := JSON.stringify(SaveManager.data)
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"config":{"weapon_slots":1,"trait_slots":1},"weapons":{"W01":5},"traits":{"T09":5},"post_max":{"crit_chance":4}})
	_check(lab.bridge!=null,"最大後強化を持つ新ランを開始する")
	if lab.bridge==null: get_tree().quit(1);return
	var bridge = lab.bridge
	bridge.command("dev_edit",{"kind":"progression","payload":{"hp":40.0,"pending_levels":2}})
	bridge.command("dev_edit",{"kind":"post_max_offer","payload":{"ids":PackedStringArray(["weapon_damage","max_hp","heal"])}})
	bridge.collect_frame()
	var cards: Dictionary = bridge._ui.cards.duplicate(true)
	var before: Dictionary = bridge._ui.post_max_stacks.duplicate(true)
	if "--cpp-choice-retry" not in OS.get_cmdline_user_args():
		var editor = load("res://gyms/visual_editor.tscn").instantiate()
		add_child(editor)
		await get_tree().process_frame
		var preview: WeakRef = weakref(editor._current().stage)
		editor._current().settings.birth_rate += 1.0
		for tool in [1,2,3,0]: editor.select_tool(tool)
		_check(editor.dirty_paths().size()==1,"制作画面の未保存値をツール間で保持する")
		editor.free()
		await get_tree().process_frame
		_check(preview.get_ref()==null,"編集プレビューだけを解放する")
		_check(bridge._ui.cards==cards and int(bridge._ui.pending_levels)==2 and bridge._ui.post_max_stacks==before,"制作画面の開閉で既存ランの候補と強化を変えない")
	_check(cards.candidates.size()==3,"有効な最大後強化の候補を3枚保持する")
	if cards.candidates.size()!=3: get_tree().quit(1);return
	var heal: Dictionary = cards.candidates[2]
	bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":heal.candidate_id})
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	_check(is_equal_approx(float(bridge._ui.hp),40.0+float(bridge._ui.max_hp)*0.3) and int(bridge._ui.pending_levels)==1,"制作画面を閉じた後も元の候補を一度だけ選ぶ")
	_check(JSON.stringify(SaveManager.data)==saved,"試行値を永続セーブへ漏らさない")
	lab.free()
	var fresh = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(fresh)
	await fresh.reset({"empty":true})
	_check(fresh.bridge._ui.post_max_stacks.is_empty(),"別のランへ最大後強化を持ち越さない")
	fresh.free()
	await get_tree().process_frame
	print("[visual_editor_post_max_cpp] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
