## 出現タイムラインのパネル。上に操作のボタン、下にトラック（timeline_canvas.gd）を並べる。
## 編集はエディターの取り消し・やり直しに載せ、確定するたびにステージ（と、別ファイルの時間帯）を保存する。
@tool
extends VBoxContainer

const Canvas := preload("res://addons/spawn_timeline/timeline_canvas.gd")

var undo_redo: EditorUndoRedoManager
var _pin_buttons: Dictionary = {}
var stage: Resource = null
var canvas: Control
var _playhead_label: Label
var _info: Button
var _details: RichTextLabel
var _edit_feedback := ""
## 組み合わせのシーンのパス → 中に置いた敵の種類の一覧
var _types_cache: Dictionary = {}
var cached_mismatches: Array = []

## 時間帯の配列 phases と出現のクリップの配列 clips を持つリソースか。
static func is_stage(object: Object) -> bool:
	if not object is Resource:
		return false
	var names := {}
	for p in object.get_property_list():
		names[p.name] = true
	return names.has("phases") and names.has("clips")

func _init() -> void:
	name = "SpawnTimeline"
	custom_minimum_size = Vector2(0, 300)
	# 幅が足りなければ折り返す（トラックの幅をボタンの並びに引っ張られないようにする）
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var bar := HFlowContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(bar)
	var groups := {}
	var ui := EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0
	for spec in [["雑魚敵", _add_curve_menu], ["強敵", _add_track],
			["ボス", func() -> void: canvas.clocks.toggle_pin("boss_time")],
			["終了", func() -> void: canvas.clocks.toggle_pin("time_limit")],
			["-", func() -> void: canvas.zoom(0.8)], ["+", func() -> void: canvas.zoom(1.25)], ["最大", func() -> void: canvas.fit()],
			["再生", _launch_here],
			["？", _show_help]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		var group := "pins" if spec[0] in ["ボス", "終了"] else ("zoom" if spec[0] in ["-", "+", "最大"] else "")
		if spec[0] == "？":
			toolbar.add_child(b)
		elif group == "":
			bar.add_child(b)
		else:
			if not groups.has(group):
				var pair := HBoxContainer.new()
				bar.add_child(pair)
				groups[group] = pair
			groups[group].add_child(b)
		if spec[0] in ["ボス", "終了"]:
			_pin_buttons["boss_time" if spec[0] == "ボス" else "time_limit"] = b
			_set_button_icon(b, "pin", ui)
			b.custom_minimum_size.x = 88.0 * ui
			b.toggle_mode = true
			b.disabled = true
		elif spec[0] in ["-", "+", "最大"]:
			b.tooltip_text = {"-": "縮小", "+": "拡大", "最大": "0:00〜11:00が収まる表示に戻す"}[spec[0]]
		elif spec[0] in ["強敵", "雑魚敵"]:
			_set_button_icon(b, "add", ui)
			b.tooltip_text = "空の強敵トラックを追加。空き部分をダブルクリックして出現のクリップを置きます。" if spec[0] == "強敵" else "雑魚敵を選び、雑魚敵のトラックの末尾に曲線を追加します。"
		elif spec[0] == "再生":
			_set_button_icon(b, "play", ui)
			b.tooltip_text = "再生位置からステージを起動"
		elif spec[0] == "？":
			b.tooltip_text = "操作方法"
			b.custom_minimum_size = Vector2.ONE * 36.0 * ui
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.add_theme_font_size_override("font_size", int(16.0 * ui))
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var style := StyleBoxFlat.new()
				style.set_corner_radius_all(int(18.0 * ui))
				style.bg_color = Color(0.32, 0.32, 0.32) if state == "hover" else Color(0.25, 0.25, 0.25)
				if state == "pressed":
					style.bg_color = Color(0.18, 0.18, 0.18)
				if state == "focus":
					style.draw_center = false
					style.set_border_width_all(maxi(1, int(2.0 * ui)))
					style.border_color = Color(0.75, 0.75, 0.75)
				b.add_theme_stylebox_override(state, style)
	_playhead_label = Label.new()
	bar.add_child(_playhead_label)
	_info = Button.new()
	_info.pressed.connect(_show_rule_details)
	bar.add_child(_info)
	_details = RichTextLabel.new()
	_details.custom_minimum_size.y = 104.0 * ui
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override("normal_font_size", int(14.0 * ui))
	_details.selection_enabled = true
	_details.hide()
	add_child(_details)
	# トラックは縦にスクロールする（目盛り・時間帯・雑魚の数はトラックの描画が上に留める）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	canvas = Canvas.new()
	canvas.timeline = self
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(canvas)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: canvas.queue_redraw())

func _set_button_icon(button: Button, icon_name: String, ui: float) -> void:
	var icon_image := Image.new()
	icon_image.load_svg_from_string(FileAccess.get_file_as_string("res://addons/spawn_timeline/icons/%s.svg" % icon_name), ui)
	button.icon = ImageTexture.create_from_image(icon_image)
	# アイコンの幅をボタンの最小幅に含め、文字だけの幅に潰れるのを防ぐ。
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", int(20.0 * ui))

func _notification(what: int) -> void:
	# 下のパネルと上部の画面のどちらで編集しても、表示し直したときに最新を描く
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and stage != null:
		refresh()

func set_stage(value: Resource) -> void:
	if stage != value:
		canvas._clipboard = []
	stage = value
	_types_cache.clear()
	tooltip_text = stage.resource_path.get_file() if stage != null else "ステージを開くと表示します"
	canvas._select_hit({})
	canvas.fit()
	refresh()

func refresh() -> void:
	refresh_view()
	refresh_diagnostics()

## ドラッグ中は表示だけ追従し、全検証と詳細表示は確定時に更新する。
func refresh_view() -> void:
	for prop in _pin_buttons:
		var button: Button = _pin_buttons[prop]
		var exists: bool = stage != null and canvas.clocks.value(prop) >= 0.0
		button.set_pressed_no_signal(exists)
		button.disabled = stage == null
		button.add_theme_stylebox_override("pressed", button.get_theme_stylebox("normal"))
		button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("hover"))
		button.self_modulate = Color.WHITE if exists else Color(0.45, 0.45, 0.45)
		button.tooltip_text = "ON：クリックでOFFに切り替え" if exists else "OFF：クリックで再生位置にピンを配置（0:00なら既存の配置の末尾）"
	_playhead_label.text = "再生位置 %s　" % Canvas.clock(canvas.playhead)
	if stage != null:
		canvas.custom_minimum_size.y = canvas.content_height()
	canvas.queue_redraw()

## 件数・赤枠と同じ検証結果を、選択の詳細と全件の詳細で説明する。
func refresh_diagnostics() -> void:
	var bad: Array = canvas.mismatches() if stage != null else []
	cached_mismatches = bad
	_info.text = "ルール違反のクリップ %d%s" % [bad.size(), "（詳細）" if not bad.is_empty() else ""]
	_info.disabled = bad.is_empty()
	_info.tooltip_text = all_rule_details()
	var reports := []
	if _edit_feedback != "":
		reports.append(_edit_feedback)
	for c: Resource in canvas.selection():
		var report := clip_rule_report(c)
		if report != "":
			reports.append(report)
	_details.text = "\n\n".join(reports)
	_details.visible = not reports.is_empty()

func report_edit_rejection(reason: String) -> void:
	_edit_feedback = "操作できません：" + reason
	if not canvas._drag.is_empty():
		_details.text = _edit_feedback
		_details.show()
		return
	refresh_diagnostics()

func all_rule_details() -> String:
	var reports := []
	for c: Resource in clips():
		var report := clip_rule_report(c)
		if report != "":
			reports.append(report)
	return "\n\n".join(reports) if not reports.is_empty() else "ルール違反はありません。"

func _show_rule_details() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "ルール違反の詳細"
	var text := RichTextLabel.new()
	text.text = all_rule_details()
	text.selection_enabled = true
	var ui := EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0
	text.add_theme_font_size_override("normal_font_size", int(14.0 * ui))
	dialog.add_child(text)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(800.0 * ui, 460.0 * ui), 0.85)

func type_names(types: Array) -> String:
	var names := PackedStringArray()
	for id in types:
		var shown := enemy_name(StringName(id))
		names.append("%s（%s）" % [shown, id] if shown != String(id) else String(id))
	return "・".join(names) if not names.is_empty() else "（未選択）"

func clip_heading(c: Resource) -> String:
	var index := clips().find(c)
	var label := String(c.get("label"))
	var row: int = canvas.clip_track(index) if index >= 0 else int(c.get("track"))
	return "クリップ「%s」／行%d「%s」／%s〜%s秒" % [label if label != "" else "名前なし", row + 1,
		canvas.track_name(row), Canvas._num(float(c.get("time"))), Canvas._num(Canvas._clip_end(c))]

## 判定は clip_mismatch に集約する。使用する並びを絞っていても、登録シーン全体が検査対象。
func clip_rule_report(c: Resource) -> String:
	var reasons := clip_mismatch(c)
	if reasons.is_empty():
		return ""
	var lines := PackedStringArray([clip_heading(c), "ルール違反："])
	for reason in reasons:
		lines.append("・配置シーン「%s」に含まれる敵「%s」が、このクリップの Types にありません。" % [reason[0], type_names([reason[1]])])
	lines.append("現在の Types：%s" % type_names(c.get("types")))
	lines.append("修正：Types に不足する敵を追加するか、Spawn assets の配置シーンの敵をクリップの種類に合わせてください。")
	lines.append("検査対象は登録シーン全体です（Formations の使用する並びの選択にかかわらず）。")
	return "\n".join(lines)

func phases() -> Array:
	return stage.get("phases") if stage != null else []

func inspect_phase(index: int) -> void:
	if index >= 0 and index < phases().size() and Engine.is_editor_hint():
		EditorInterface.inspect_object(phases()[index], "", true)

func clips() -> Array:
	return stage.get("clips") if stage != null else []

## 敵の種類の名前（敵の定義の display_name。読めなければ type ID）。
func enemy_name(id: StringName) -> String:
	if not _names.has(id):
		var dir := str(ProjectSettings.get_setting("spawn_timeline/enemy_dir", ""))
		var path := dir.path_join(String(id) + ".tres")
		var res: Resource = load(path) if dir != "" and ResourceLoader.exists(path) else null
		_names[id] = str(res.get("display_name")) if res != null and res.get("display_name") != null and str(res.get("display_name")) != "" else String(id)
	return _names[id]

var _names: Dictionary = {}

## 敵の種類の区分（敵の定義の rank。雑魚は 1）。読めなければ 0。
func enemy_rank(id: StringName) -> int:
	var dir := str(ProjectSettings.get_setting("spawn_timeline/enemy_dir", ""))
	var path := dir.path_join(String(id) + ".tres")
	var res: Resource = load(path) if dir != "" and ResourceLoader.exists(path) else null
	return int(res.get("rank")) if res != null and res.get("rank") != null else 0

## 雑魚の目標の数の曲線（zako_curves）。
func curves() -> Array:
	return stage.get("zako_curves") if stage != null and stage.get("zako_curves") != null else []

## フォーメーション（組み合わせのシーン）に置いた敵の種類（置き場所のノードの enemy）。シーンごとに1回だけ調べる。
func scene_types(scene: PackedScene) -> Array:
	if scene == null:
		return []
	var path: String = scene.resource_path
	if not _types_cache.has(path):
		var found := {}
		var root: Node = scene.instantiate()
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			var e = n.get("enemy")
			if e != null and String(e) != "":
				found[StringName(e)] = true
			stack.append_array(n.get_children())
		root.free()
		_types_cache[path] = found.keys()
	return _types_cache[path]

## クリップのフォーメーションのうち、クリップの種類の組み合わせにない敵を置いているもの：[[シーンの名前, 種類], …]
func clip_mismatch(clip: Resource) -> Array:
	var out := []
	var allowed: Array = clip.get("types")
	for scene in clip.get("formations"):
		for t in scene_types(scene):
			if not allowed.has(t):
				out.append([scene.resource_path.get_file().get_basename(), t])
	return out

## 編集を取り消し・やり直しに載せる。changes は [対象, プロパティ, 前の値, 後の値] の並び。
## 値はすでに後の値になっている前提で、実行はしない。
func commit(label: String, changes: Array) -> void:
	_edit_feedback = ""
	undo_redo.create_action(label, UndoRedo.MERGE_DISABLE, stage)
	# 新規・内蔵クリップのパスによる履歴の推測を避け、ステージの1操作にまとめる。
	for c in changes:
		undo_redo.force_fixed_history()
		undo_redo.add_do_property(c[0], c[1], c[3])
		undo_redo.force_fixed_history()
		undo_redo.add_undo_property(c[0], c[1], c[2])
	undo_redo.force_fixed_history()
	undo_redo.add_do_method(self, "_save_stage", stage)
	undo_redo.force_fixed_history()
	undo_redo.add_undo_method(self, "_save_stage", stage)
	undo_redo.commit_action(false)
	_save()

## ステージと、別のファイルにある時間帯を保存する。
func _save() -> void:
	_save_stage(stage)

## Undo のあと別のステージを表示していても、編集したステージを保存する。
func _save_stage(target: Resource) -> void:
	_edit_feedback = ""
	if target == null or target.resource_path == "":
		return
	for p in target.get("phases"):
		if p is Resource and p.resource_path != "" and not p.resource_path.contains("::"):
			ResourceSaver.save(p)
	ResourceSaver.save(target)
	refresh()

## clips の要素の型（プロパティの型の指定から、プロジェクトのクラスを探して作る）。
func _new_clip() -> Resource:
	return _new_element("clips")

## 配列のプロパティ prop の要素の型のリソースを作る。
func _new_element(prop: String) -> Resource:
	for p in stage.get_property_list():
		if p.name != prop:
			continue
		var cls := String(p.hint_string).get_slice(":", 1)
		for g in ProjectSettings.get_global_class_list():
			if String(g["class"]) == cls:
				return load(g.path).new()
	return null

## 通常トラックは、空の行も名前の配列の要素として保持する。
func _add_track() -> void:
	if stage == null:
		return
	var before = stage.get("track_names")
	var after: PackedStringArray = canvas._track_names_now()
	after.append("")
	stage.set("track_names", after)
	canvas.selected = -1
	canvas.track_selected = after.size() - 1
	commit("強敵トラックを追加", [[stage, "track_names", before, after]])

## 指定位置に時間帯を追加する。数値はその位置の時間帯から引き継ぐ。
func _add_phase(at: float) -> void:
	var before := phases()
	if stage == null or before.is_empty():
		return
	var start := maxf(0.0, snappedf(at, 1.0))
	var index := 0
	for phase in before:
		if float(phase.get("start")) <= start:
			index += 1
		if is_equal_approx(float(phase.get("start")), start):
			start += 1.0
	var source: Resource = before[maxi(0, index - 1)]
	var phase: Resource = source.duplicate(true)
	phase.set("start", start)
	phase.set("id", StringName("phase_%d" % ResourceUID.create_id()))
	phase.set("display_name", "新しい時間帯")
	var after := before.duplicate()
	after.append(phase)
	after.sort_custom(func(a: Resource, b: Resource) -> bool: return float(a.get("start")) < float(b.get("start")))
	stage.set("phases", after)
	var changes := [[stage, "phases", before, after]]
	var overrides = stage.get("surge_phases")
	if overrides is Dictionary and overrides.has(String(source.get("id"))):
		var flags: Dictionary = overrides.duplicate()
		flags[String(phase.get("id"))] = overrides[String(source.get("id"))]
		stage.set("surge_phases", flags)
		changes.append([stage, "surge_phases", overrides, flags])
	commit("時間帯を追加", changes)

## ステージの並びからだけ外す。残る時間帯の名称・開始時刻と元のリソースは保つ。
func _remove_phase(index: int) -> void:
	var before := phases()
	if stage == null or before.size() <= 1 or index < 0 or index >= before.size():
		return
	var after := before.duplicate()
	after.remove_at(index)
	stage.set("phases", after)
	commit("時間帯を削除", [[stage, "phases", before, after]])

func _add_clip(row := -1, at := -1.0) -> void:
	if stage == null:
		return
	var clip := _new_clip()
	if clip == null:
		return
	clip.set("label", "新しいクリップ")
	var start := snappedf(canvas.playhead, 1.0) if at < 0.0 else maxf(0.0, at)
	var length := 60.0
	if row >= 0:
		clip.set("track", row)
		for k in clips().size():
			var next_start := float(clips()[k].get("time"))
			if canvas.clip_track(k) == row and next_start > start:
				length = minf(length, next_start - start)
	clip.set("time", start)
	clip.set("length", length)
	var before: Array = clips()
	var after: Array = before.duplicate()
	after.append(clip)
	stage.set("clips", after)
	canvas.selected = after.size() - 1
	commit("クリップを足す", [[stage, "clips", before, after]])
	if Engine.is_editor_hint():
		EditorInterface.inspect_object(clip, "", true)

## ステージの敵のうち、まだ曲線のない雑魚（区分 1）を選んで、雑魚の目標の数の曲線を足す。
func _add_curve_menu() -> void:
	if stage == null:
		return
	var have := {}
	for c in curves():
		have[c.get("type")] = true
	var menu := PopupMenu.new()
	for id in stage.get("enemies"):
		if not have.has(id) and enemy_rank(id) == 1:
			menu.add_item(enemy_name(id))
			menu.set_item_metadata(menu.item_count - 1, String(id))
	if menu.item_count == 0:
		menu.add_item("（ステージの敵の一覧に、曲線のない雑魚がいない）")
		menu.set_item_disabled(0, true)
	menu.id_pressed.connect(func(index: int) -> void:
		_add_curve(StringName(menu.get_item_metadata(menu.get_item_index(index))))
		menu.queue_free())
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(get_screen_position() + get_local_mouse_position(), Vector2i.ZERO))

func _add_curve(type: StringName) -> void:
	var curve := _new_element("zako_curves")
	if curve == null:
		return
	curve.set("type", type)
	curve.set("points", PackedVector2Array([Vector2(0.0, 10.0)]))
	var before: Array = curves()
	var after: Array = before.duplicate()
	after.append(curve)
	stage.set("zako_curves", after)
	commit("雑魚の曲線を足す", [[stage, "zako_curves", before, after]])

## 指定された曲線だけを配列から外す。敵一覧・他の曲線・クリップは保持する。
func _remove_curve(curve: Resource) -> void:
	if stage == null:
		return
	var before: Array = curves()
	var index := before.find(curve)
	if index < 0:
		return
	var after: Array = before.duplicate()
	after.remove_at(index)
	stage.set("zako_curves", after)
	canvas.curve_selected = -1
	canvas.point_selected = -1
	commit("雑魚の曲線を消す", [[stage, "zako_curves", before, after]])

func _remove_clip() -> void:
	if stage == null or canvas.selected < 0 or canvas.selected >= clips().size():
		return
	var before: Array = clips()
	var after: Array = before.duplicate()
	for c in canvas.selection():
		after.erase(c)
	stage.set("clips", after)
	canvas.selected = -1
	commit("クリップを消す", [[stage, "clips", before, after]])

## 操作の説明を、ボタンの下に出す（外をクリックすると閉じる）。
func _show_help() -> void:
	var panel := PopupPanel.new()
	var label := Label.new()
	label.text = Canvas.HELP
	panel.add_child(label)
	panel.popup_hide.connect(panel.queue_free)
	add_child(panel)
	panel.popup(Rect2i(get_screen_position() + get_local_mouse_position() + Vector2(0, 24), Vector2i.ZERO))

## 再生位置の時刻から、このステージを起動する（ステージの起動の道具 stage_launcher の予約を使う）。
func _launch_here() -> void:
	if stage == null:
		return
	var request: GDScript = load("res://addons/stage_launcher/launch_request.gd")
	request.request(int(stage.get("index")), canvas.playhead, "timeline")
	EditorInterface.play_main_scene()
