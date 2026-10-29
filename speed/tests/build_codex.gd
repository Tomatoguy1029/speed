## 図鑑の全実演・未入手・タブ保持を短い静的な再生で確認する。
extends Node
var failed := 0
func check(condition: bool, text: String) -> void:
	if not condition:
		failed+=1
		push_error(text)
func _ready() -> void:
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
	page.free()
	print("[build_codex] failed=",failed)
	get_tree().quit(1 if failed else 0)
