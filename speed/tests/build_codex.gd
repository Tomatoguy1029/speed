## 図鑑の全実演・未入手・タブ保持を短い静的な再生で確認する。
extends Node
const MemorySave := preload("res://tests/thrill_acceptance.gd").MemorySave
var failed := 0
func check(condition: bool, text: String) -> void:
	if not condition:
		failed+=1
		push_error(text)
func _ready() -> void:
	var locale := "ja"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locale="): locale = arg.trim_prefix("--locale=")
	TranslationServer.set_locale(locale)
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	for category in [&"weapons",&"traits",&"legendary_modules"]:
		for definition in ContentManager.catalog.table(category).values():
			if definition.id != &"W28": SaveManager.data.encyclopedia.append(String(definition.id))
	get_window().content_scale_size = Vector2i.ZERO
	var demo_script=preload("res://scripts/ui/codex_demonstration.gd")
	for category in [&"weapons",&"traits"]:
		for definition in ContentManager.catalog.table(category).values():
			var path: String="res://data/codex/%s.res" % definition.code_id
			if not ResourceLoader.exists(path): continue
			var demo=demo_script.new()
			add_child(demo)
			demo.setup(definition)
			check(demo.animation!=null and not demo.animation.frames.is_empty(),"実演を読み込む: "+String(definition.id))
			for point in [0.0,0.42,0.8]:demo.sample(demo.animation.period*point)
			demo.free()
	var page=preload("res://scenes/app/encyclopedia.tscn").instantiate()
	add_child(page)
	await get_tree().process_frame
	check(page._tab_buttons.size()==3,"武器・特性・伝説のタブを保持する")
	var ids:=[]
	for grid in page._grids:ids.append(grid.get_instance_id())
	page._select_tab(1)
	page._select_tab(0)
	var after:=[]
	for grid in page._grids:after.append(grid.get_instance_id())
	check(ids==after,"タブを戻しても一覧とサムネイルを作り直さない")
	check(not ContentManager.catalog.table(&"traits").has(&"T13") and not ContentManager.catalog.table(&"traits").has(&"T01"),"廃止した特性を図鑑の候補へ入れない")
	# コンテナの最小幅が数回の配置後に広がる不具合を、取得済みの長い名前でも確認する。
	for viewport_size in [Vector2i(1280,720),Vector2i(1581,900),Vector2i(720,960)]:
		get_viewport().size = viewport_size
		for tab in 3:
			page._select_tab(tab)
			for frame in 12: await get_tree().process_frame
			var bounds := Rect2(Vector2.ZERO,Vector2(viewport_size))
			var case_name := str(viewport_size)+" / "+str(tab)
			check(bounds.encloses(page.get_node("%Heading").get_global_rect()),"見出しが画面内にある: "+case_name)
			check(bounds.encloses(page.get_node("%BackButton").get_global_rect()),"戻るボタンが画面内にある: "+case_name)
			check(bounds.encloses(page._list_scroll.get_global_rect()),"一覧が画面内に収まる: "+case_name)
			check(bounds.encloses(page._detail_scroll.get_global_rect()),"詳細が画面内に収まる: "+case_name)
			for button in page._tab_buttons:
				check(bounds.encloses(button.get_global_rect()),"タブが画面内にある: "+case_name)
			for grid in page._grids:
				if not grid.is_visible_in_tree():continue
				check(grid.get_combined_minimum_size().x <= page._list_scroll.size.x,"一覧の列数が表示幅を超えない: "+case_name)
				for button in grid.get_children():
					check(button.get_global_rect().encloses(button.get_child(0).get_global_rect()),"画像・番号・名前がカードの中に収まる: "+case_name)
	page.free()
	print("[build_codex] failed=",failed)
	get_tree().quit(1 if failed else 0)
