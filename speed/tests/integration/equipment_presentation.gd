## 特性の槍は発動時だけ飛び、装備を外したあとは残る演出の終了で解放する。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	_check_lance_lifetime()
	if "--cpp" in OS.get_cmdline_user_args():
		await _cpp_ready()
		return
	await _cpp_ready()

func _cpp_ready() -> void:
	var preview = load("res://gyms/boss_effect_preview.gd").new()
	add_child(preview)
	preview.size = Vector2(960,600)
	preview._equipment_level.select(1)
	preview._trait_level.select(2)
	preview._post_max = {"weapon_damage":2,"area":1}
	await preview.set_effect("weapon/forward",false)
	check(preview.session.bridge!=null and preview.session.scene._sim==null,"制作画面でC++ランだけを開始する")
	if preview.session.bridge==null: get_tree().quit(1);return
	var bridge = preview.session.bridge
	check(bridge._ui.weapon_levels.any(func(v): return v.id=="W01" and v.level==2),"制作画面の武器Lvを新ランへ適用する")
	check(int(bridge._ui.post_max_stacks.get("weapon_damage",0))==2,"最大後強化をこの試行へ適用する")
	for i in 240: preview.session.step()
	preview.refresh_effects()
	await get_tree().process_frame
	check(preview.session.events.any(func(e): return e.type=="weapon_fire"),"表示付きの短い試行で通常の武器発動を通す")
	var render = preview._render()
	check(render.frame_view!=null and render.frame_view.visible,"制作画面も正式なRunFrameViewで表示する")
	check(not render.view_override.is_empty() and is_equal_approx(render.cam_zoom,float(render.view_override.zoom)),"描画用のカメラ指定を戦闘状態へ書き戻さず適用する")
	await preview.set_effect("trait/multiShot",false)
	bridge = preview.session.bridge
	check(bridge._ui.weapon_levels.any(func(v): return v.id=="W01" and v.level==2) and bridge._ui.trait_levels.any(func(v): return v.id=="T35" and v.level==3),"制作画面で武器と特性を指定Lvで組み合わせる")
	var paths := PackedStringArray()
	for asset: int in preview.session.scene.cpp_resources.keys:
		var path: String = preview.session.scene.cpp_resources.keys[asset]
		if path.contains("/weapons/"): paths.append(path)
	check(paths.has(ContentManager.catalog.find(&"weapons",&"W01").path),"通常装備と同じ定義資源を使う")
	await preview.set_effect("trait/pickup",false)
	check(preview.session.history.filter(func(item): return item.kind=="command" and item.args.name=="dev_drop_crystal" and item.args.args.kind==RunIds.GemKind.Low).size()==3,"結晶3つをkind付きの命令だけで配置する")
	await preview.set_effect("weapon/barrier",false)
	check(preview.session.events.any(func(e): return e.type=="barrier_hit"),"バリアの発動条件をC++命令から作る")
	preview.refresh_effects()
	await get_tree().process_frame
	var scope: ContentResourceScope = preview.session.scene.resources
	preview.free()
	await get_tree().process_frame
	check(scope.cancelled,"制作画面を閉じたら試行の資源を解放する")
	print("[equipment_presentation_cpp] failures=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _check_lance_lifetime() -> void:
	var lance := load("res://scripts/render/light_lance.gd").new() as Node2D
	add_child(lance)
	var event := {"from": Vector2.ZERO, "to": Vector2(840, 0), "width": 40.0}
	lance.fire(event)
	lance.step(0.40, 1.0, 1.0)
	check(lance.shots.size() == 1, "以前の消滅時刻でも槍の消え際を見せる")
	lance.fire(event)
	check(lance.shots.size() == 2 and is_equal_approx(lance.shots[0].age, 0.40), "次の槍で既存の表示を消去・巻き戻ししない")
	lance.step(0.11, 1.0, 1.0)
	check(lance.shots.size() == 1 and is_equal_approx(lance.shots[0].age, 0.11), "古い槍だけを寿命で回収する")
	lance.step(0.51, 1.0, 1.0)
	var interval: float = ContentManager.definition(&"traits", &"T06").params.cooldown
	for shot in 20:
		lance.step(interval, 1.0, 1.0)
		lance.fire(event)
		check(lance.shots.size() <= 4, "最短間隔の連続発動でも表示が蓄積し続けない")
	lance.step(0.51, 1.0, 1.0)
	check(lance.shots.is_empty(), "連続発動が終わったあと全表示を回収する")
	lance.free()
