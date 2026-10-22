## デバッグ専用の敵・ルート実験場。
extends Control

const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const CANVAS := preload("res://gyms/enemy_lab/lab_canvas.gd")
const CARD := preload("res://gyms/enemy_lab/lab_candidate_card.gd")
const IO := preload("res://gyms/enemy_lab/lab_io.gd")
const CHECK := preload("res://scripts/encounters/route_constraints.gd")
const CONTROLS := preload("res://gyms/enemy_lab/lab_controls.gd")
const ICON := preload("res://gyms/enemy_lab/lab_icon.gd")
const TIMELINE := preload("res://gyms/enemy_lab/lab_timeline.gd")
const TRIAL := preload("res://gyms/enemy_lab/route_trial.gd")
const GENERATOR := preload("res://gyms/enemy_lab/encounter_pattern.gd")
const WORKSPACE := preload("res://gyms/enemy_lab/lab_workspace.gd")
const PALETTE_ITEM := preload("res://gyms/enemy_lab/lab_palette_item.gd")
const INSPECTOR := preload("res://gyms/enemy_lab/lab_inspector.gd")
const FIELD_ITEM := preload("res://gyms/enemy_lab/lab_field_item.gd")

var session
var controls
var trial
var generator
var comparisons: Array = []
var pattern: Dictionary = {}
var candidate_values: Array = []
var _timeline
var _evaluation_revision := -1
var _file_dialog: FileDialog
var canvas
## 本番のランを映す表示枠
var game_frame: SubViewportContainer
var inspector
var workspace
var _palette: GridContainer
var _filter: LineEdit
var _status: Label
var _result: Label
var _seek: HSlider
var _play: Button
var _seed: SpinBox
var _stage: OptionButton
var _empty: CheckButton
var _auto: CheckButton
var _terrain: CheckButton
var _rocks: CheckButton
var _gimmicks: CheckButton
var _count: SpinBox
var _updating := false
var _scrubbing := false
var _busy := false
var _branch: OptionButton
var _left: Control
var _right: Control
var _messages: Label

func _ready() -> void:
	if not OS.is_debug_build():
		GameManager.reset_to_main_menu()
		return
	theme = Theme.new()
	theme.default_font_size = 15
	session = SESSION.new()
	add_child(session)
	# 試遊中だけ、本番の入力をそのまま操作として記録する
	session.live_input = func():
		return session.run.input.poll() if canvas.mode == 3 and is_instance_valid(session.run) else null
	trial = TRIAL.new()
	add_child(trial)
	generator = GENERATOR.new()
	add_child(generator)
	_build_ui()
	trial.progress.connect(func(v): _messages.text = TranslationServer.translate("lab.message_7b47f8fa60") % roundi(v * 100))
	generator.progress.connect(func(n): _messages.text = TranslationServer.translate("lab.message_0db4675b27") % n)
	session.changed.connect(_refresh)
	session.seek_progress.connect(func(v): _messages.text = TranslationServer.translate("lab.message_7591fff9f2") % roundi(v * 100))
	await session.reset()
	canvas.zoom = game_zoom()
	_refresh()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _spin(parent: Node, minimum: float, maximum: float, value: float) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = minimum
	box.max_value = maximum
	box.value = value
	parent.add_child(box)
	return box

func _build_ui() -> void:
	workspace = WORKSPACE.new()
	workspace.build(self)
	_fill_palette()

func _fill_palette() -> void:
	for child in _palette.get_children():
		_palette.remove_child(child)
		child.queue_free()
	workspace.palette_buttons.clear()
	var filter := _filter.text.to_lower()
	var definitions := ConfigManager.sorted(ConfigManager.enemies)
	definitions.append_array(ConfigManager.sorted(ConfigManager.bosses))
	definitions.append_array(field_items())
	# 並びは「スリルと寄り道」の敵ごとの情報の表の順。そのあとにボス、出現から外した敵・障害物
	definitions.sort_custom(func(a, b):
		var left := _palette_order(a)
		var right := _palette_order(b)
		return String(a.id) < String(b.id) if left == right else left < right)
	var wanted_class: int = workspace.category.selected
	var wanted_stars: int = workspace.stars.selected
	for def in definitions:
		if def is EnemyDef and def.behavior == &"part": continue
		if def is EnemyDef and def.id in [&"triangle_star"]: continue
		var id := String(def.id)
		if wanted_class > 0 and wanted_class != _palette_class(def): continue
		# 星の数：1〜5 はその数、6 は 6〜10 をまとめて選ぶ。ボスは区分で選ぶ
		if wanted_stars > 0 and not (def is EnemyDef and (def.rank >= 6 if wanted_stars == 6 else def.rank == wanted_stars)): continue
		if not filter.is_empty() and not (id.to_lower().contains(filter) or def.display_name.to_lower().contains(filter)): continue
		var button = PALETTE_ITEM.new()
		button.definition = def
		button.picture = canvas.texture_for(id)
		button.tooltip_text = tr("lab.ui.enemy_tooltip") % [def.display_name, id]
		button.pressed.connect(func():
			canvas.spawn_type = id
			workspace._last_mode = -1
			_set_mode(1))
		workspace.palette_buttons[id] = button
		_palette.add_child(button)
	workspace._last_mode = -1

## 敵一覧の並び：「スリルと寄り道」の敵ごとの情報の表の順（分裂体は分裂する雑魚の次）。そのあとに障害物・仕掛け
const PALETTE_ORDER := ["biter", "rocket", "bomber", "volatile", "splitter", "splitling", "beamer", "pulser", "missile", "spreader",
	"pump", "telescope", "triangle", "shield", "ruler", "crow", "lynx", "reticle", "cross", "clock", "dolphin", "crab",
	"marlin", "auriga", "corona", "phoenix", "cepheus", "aquarius", "aquila",
	"field_planet_small", "field_planet", "field_planet_large", "meteor", "field_comet", "iron", "saw", "hydra_rubble",
	"field_gravity", "field_warp", "field_gem"]
## 障害物・仕掛けに入る敵の表の種類
const OBSTACLES := ["meteor", "iron", "saw", "hydra_rubble"]

var _field_items: Array = []

## 一覧から置けるフィールドの要素（惑星・彗星・重力・ワープホール・経験値の結晶）。
func field_items() -> Array:
	if _field_items.is_empty():
		_field_items = [
			FIELD_ITEM.make(&"field_planet_small", tr("lab.field.planet_small"), &"planet", 120.0, Color("#6f7fa8")),
			FIELD_ITEM.make(&"field_planet", tr("lab.field.planet"), &"planet", 260.0, Color("#6f7fa8")),
			FIELD_ITEM.make(&"field_planet_large", tr("lab.field.planet_large"), &"planet", 520.0, Color("#6f7fa8")),
			FIELD_ITEM.make(&"field_comet", tr("lab.field.comet"), &"comet", 45.0, Color("#9fd6ff")),
			FIELD_ITEM.make(&"field_gravity", tr("lab.field.gravity"), &"gravity", 0.0, Color("#a98cff")),
			FIELD_ITEM.make(&"field_warp", tr("lab.field.warp"), &"warp", 0.0, Color("#d6a8ff")),
			FIELD_ITEM.make(&"field_gem", tr("lab.field.gem"), &"gem", 140.0, RenderManager.XP_COLOR),
		]
	return _field_items

func field_item(id: String) -> Resource:
	for item in field_items():
		if String(item.id) == id: return item
	return null

func _palette_order(def: Resource) -> int:
	var at := PALETTE_ORDER.find(String(def.id))
	if at >= 0: return at
	return 200 if def is BossDef else 300

## 敵一覧の区分（絞り込みの番号）：1 雑魚（星1）、2 硬めの敵（星2）、3 強敵（星3〜5）、4 大物（星6〜10）、
## 5 障害物・仕掛け、6 ボス、7 出現から外した敵。
func _palette_class(def: Resource) -> int:
	if def is BossDef: return 6
	if not def is EnemyDef or String(def.id) in OBSTACLES: return 5
	var rank: int = def.rank
	if rank == 1: return 1
	if rank == 2: return 2
	if rank >= 3 and rank <= 5: return 3
	if rank >= 6: return 4
	return 7

func _set_mode(mode: int) -> void:
	canvas.finish_route()
	# 試遊からほかのモードへ切り替えたら、再生を止める
	if canvas.mode == 3 and mode != 3:
		session.playing = false
	canvas.mode = mode
	canvas.cancel_gesture()
	# 試遊を選んだら、そのまま再生して操作できるようにする
	if mode == 3 and not session.playing and not session.seeking:
		session.playing = true
	_focus_play_area()
	workspace._last_mode = -1

## 試遊では本番の表示枠に、編集では編集用の層に、入力を向ける。試遊に入る前にたまった入力は捨てる。
func _focus_play_area() -> void:
	if canvas.mode == 3:
		if is_instance_valid(session.run):
			session.run.input.poll()
		game_frame.grab_focus()
	else:
		canvas.grab_focus()


func _toggle_play() -> void:
	canvas.finish_route()
	session.playing = not session.playing
	_focus_play_area()
	_refresh()

func _reset() -> void:
	if _busy:
		return
	canvas.cancel_gesture()
	_busy = true
	await session.reset({"seed": int(_seed.value), "stage": _stage.selected + 1, "empty": _empty.button_pressed, "auto_spawn": _auto.button_pressed, "field": {"terrain": _terrain.button_pressed, "rocks": _rocks.button_pressed, "gimmicks": _gimmicks.button_pressed}})
	canvas.route.clear()
	canvas.selection.clear()
	canvas.result.clear()
	canvas.center = session.run.state.ship_pos
	var render: RenderManager = session.scene.view.get_node_or_null("RenderManager") if session.scene.view != null else null
	if render != null:
		canvas.zoom = render.game_zoom()
	_busy = false
	_refresh()

func _select_branch(index: int) -> void:
	if index == 0 or session.seeking:
		return
	var current := {"name": TranslationServer.translate("lab.message_549e9c3c03") % (session.branches.size() + 1), "history": session.history.duplicate(true), "end": session.furthest}
	var branch: Dictionary = session.branches[index - 1]
	session.current_branch = branch.name
	session.history.assign(branch.history)
	session.furthest = int(branch.end)
	session.branches[index - 1] = current
	await session.seek(session.furthest)
	_branch.select(0)
	_refresh()

## 描いたルートを、今の場面のまま本番どおりに描いて駆け抜けさせ、カメラで機体を追って普通に再生する。
func _try_route() -> void:
	if _busy or session.seeking:
		return
	canvas.finish_route()
	if canvas.route.size() < 2:
		_messages.text = tr("lab.message_7474db4292")
		return
	var points := []
	for p in canvas.route:
		points.append([p.x, p.y])
	session.perform("route", {"points": points, "draw_seconds": controls.draw_seconds.value})
	canvas.follow = true
	session.playing = true
	_refresh()

func _evaluate() -> void:
	if _busy or session.seeking:
		return
	canvas.finish_route()
	_busy = true
	session.playing = false
	var path: PackedVector2Array = canvas.route.duplicate()
	var revision: int = session.revision
	var result: Dictionary = await trial.evaluate(session, path, controls.draw_seconds.value)
	if is_instance_valid(self):
		if path != canvas.route: result.status = "stale"
		canvas.result = result
		_evaluation_revision = revision
		_show_result(result)
		comparisons.append({"route": path, "result": result.duplicate(true)})
		_update_comparisons()
	_busy = false

func _validate_route() -> void:
	canvas.finish_route()
	canvas.result = CHECK.validate(session, canvas.route, controls.margin.value, controls.window_seconds.value, controls.draw_seconds.value, controls.exit_clearance.value)
	_evaluation_revision = session.revision
	_show_result(canvas.result)

func _show_result(value: Dictionary) -> void:
	_result.show()
	_result.text = _status_title(value)
	if value.get("status") == "replayed":
		_result.text += TranslationServer.translate("lab.message_511972b218") % [value.kills, value.damage, value.gauge]
	elif value.has("blockers"):
		_result.text += TranslationServer.translate("lab.message_198ce2dd32") % [value.blockers.size(), float(value.margin)]
	if value.has("reason"):
		_result.text += "　" + String(value.reason)
	canvas.queue_redraw()

func _update_comparisons() -> void:
	controls.result_list.clear()
	for index in comparisons.size():
		var value: Dictionary = comparisons[index].result
		controls.result_list.add_item(TranslationServer.translate("lab.message_c93b3203d0") % [index + 1, value.get("status", TranslationServer.translate("lab.message_68dc5e1c46")), int(value.get("kills", 0))])
	canvas.comparisons = comparisons

func _generate_candidates() -> void:
	if _busy:
		return
	_busy = true
	session.playing = false
	candidate_values.clear()
	controls.candidates.clear()
	for child in controls.candidate_cards.get_children(): child.queue_free()
	for n in 3:
		var value: Dictionary = await generator.generate(session, pattern, int(_seed.value) + n)
		candidate_values.append(value)
		controls.candidates.add_item(TranslationServer.translate("lab.message_82b17798e4") % [n + 1, _status_title(value), int(_seed.value) + n])
		var index := candidate_values.size() - 1
		var card = CARD.new()
		card.value = value
		card.canvas = canvas
		card.caption = controls.candidates.get_item_text(index)
		card.pressed.connect(func(): controls.candidates.select(index); _preview_candidate(index))
		controls.candidate_cards.add_child(card)
		if generator.cancelled:
			break
	_busy = false
	_messages.text = TranslationServer.translate("lab.message_e3178fc873")

func _preview_candidate(index: int) -> void:
	if index < candidate_values.size():
		canvas.candidate = candidate_values[index]
		_messages.text = _status_title(canvas.candidate) + "　Seed " + str(canvas.candidate.get("seed", 0))
		var reasons := []
		for blocker in canvas.candidate.get("validation", {}).get("blockers", []):
			if not reasons.has(blocker.reason): reasons.append(blocker.reason)
		if not reasons.is_empty(): _messages.text += "　" + " / ".join(reasons)
		elif canvas.candidate.has("reason"): _messages.text += "　" + String(canvas.candidate.reason)
		canvas.queue_redraw()

func _apply_candidate() -> void:
	var indices: PackedInt32Array = controls.candidates.get_selected_items()
	if indices.is_empty():
		return
	var value: Dictionary = candidate_values[indices[0]]
	if not value.get("admitted", false) or not value.has("commands") or value.get("source_digest") != session.digest():
		_messages.text = TranslationServer.translate("lab.message_4949196244")
		return
	for command in value.commands:
		session.perform(command.kind, command.args)
	canvas.route = value.route.duplicate()
	canvas.candidate.clear()
	canvas.result.clear()
	_validate_route()

func _save(record_history: bool) -> void:
	canvas.finish_route()
	var data := IO.record(session, canvas.route, pattern, comparisons, candidate_values) if record_history else IO.preset(session, canvas.route, pattern)
	var path := "%s/%s-%s.json" % [IO.ROOT, IO.safe_name(controls.name_field.text), "record" if record_history else "preset"]
	data["candidates"] = IO.plain(candidate_values)
	var error := IO.save_json(path, data)
	_messages.text = ProjectSettings.globalize_path(path) if error == OK else TranslationServer.translate("lab.message_e104208879") % error_string(error)

func _choose_file() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray([TranslationServer.translate("lab.message_edf19cb8e9")])
		add_child(_file_dialog)
		_file_dialog.file_selected.connect(_load_file)
	DirAccess.make_dir_recursive_absolute(IO.ROOT)
	_file_dialog.current_dir = ProjectSettings.globalize_path(IO.ROOT)
	_file_dialog.popup_centered_ratio(0.7)

func _load_file(path: String) -> void:
	if _busy:
		return
	canvas.cancel_gesture()
	var data := IO.read_json(path)
	if data.has("error"):
		_messages.text = data.error
		return
	_busy = true
	await session.reset(data.spec)
	_seed.value = int(session.spec.seed)
	_stage.selected = int(session.spec.stage) - 1
	_empty.button_pressed = session.spec.get("empty", true)
	_auto.button_pressed = session.spec.get("auto_spawn", false)
	var flags: Dictionary = session.spec.get("field", {})
	_terrain.button_pressed = flags.get("terrain", not _empty.button_pressed)
	_rocks.button_pressed = flags.get("rocks", not _empty.button_pressed)
	_gimmicks.button_pressed = flags.get("gimmicks", not _empty.button_pressed)
	canvas.selection.clear()
	session.history.assign(data.history)
	session.branches.assign(data.get("branches", []))
	session.current_branch = String(data.get("branch_name", tr("lab.initial_branch")))
	session.branch_serial = int(data.get("branch_serial", session.branches.size()))
	session.furthest = int(data.get("end", 0))
	await session.seek(int(data.get("tick", 0)))
	canvas.route.clear()
	for point in data.get("route", []):
		canvas.route.append(session.vector(point))
	candidate_values.clear()
	controls.candidates.clear()
	for candidate in data.get("candidates", []):
		var points := PackedVector2Array()
		for point in candidate.get("route", []): points.append(session.vector(point))
		candidate["route"] = points
		if data.stale: candidate["source_digest"] = ""
		candidate_values.append(candidate)
		controls.candidates.add_item("%d %s" % [candidate_values.size(), _status_title(candidate)])
	pattern = data.get("pattern", {})
	canvas.pattern = pattern
	comparisons.clear()
	for comparison in data.get("results", []):
		var points := PackedVector2Array()
		for point in comparison.get("route", []): points.append(session.vector(point))
		comparisons.append({"route": points, "result": comparison.get("result", {})})
	canvas.result.clear()
	_update_comparisons()
	_messages.text = TranslationServer.translate("lab.message_10ccd95682") if data.stale else TranslationServer.translate("lab.message_0d4f7fc305")
	inspector.refresh(true)
	_busy = false

func _export() -> void:
	canvas.finish_route()
	var targets := []
	for index in controls.export_targets.get_selected_items(): targets.append(controls.export_targets.get_item_metadata(index))
	var folder := "%s/exports/%s" % [IO.ROOT, IO.safe_name(controls.name_field.text)]
	var error := IO.save_json(folder + "/record.json", IO.record(session, canvas.route, pattern, comparisons, candidate_values))
	if error == OK:
		error = IO.save_json(folder + "/preset.json", IO.preset(session, canvas.route, pattern))
	if error == OK:
		error = IO.save_json(folder + "/changes.json", {"version": 1, "baseline": IO.baseline(), "enemy_overrides": IO.differences(session), "boss_overrides": IO.boss_differences(session), "selected_enemy_ids": targets, "target_stage": int(controls.export_stage.value), "target_phase": controls.export_phase.get_item_metadata(controls.export_phase.selected), "director": IO.plain(session.run.projectiles.director.settings), "director_enabled": session.run.projectiles.director.enabled, "pattern": IO.plain(pattern), "stage": int(session.spec.stage), "production_enabled": false})
	if error == OK:
		var director: Dictionary = session.run.projectiles.director.settings.duplicate(true)
		director["enabled"] = session.run.projectiles.director.enabled
		var phase: String = controls.export_phase.get_item_metadata(controls.export_phase.selected)
		error = IO.save_json(folder + "/adoption.json", {"enabled": false, "baseline": IO.adoption_baseline(), "phases": [] if phase.is_empty() else [phase], "director": director, "patterns": [] if pattern.is_empty() else [pattern], "interval": 5.0, "target_stage": int(controls.export_stage.value), "selected_enemy_ids": targets})
	if error == OK:
		await RenderingServer.frame_post_draw
		error = get_viewport().get_texture().get_image().save_png(folder + "/overview.png")
	_messages.text = TranslationServer.translate("lab.message_6d49e93edd") + ProjectSettings.globalize_path(folder) if error == OK else TranslationServer.translate("lab.message_f6f81b6554") + error_string(error)

func _refresh() -> void:
	if not is_instance_valid(session.run):
		return
	workspace.sync()
	_seek.max_value = maxf(1, session.furthest)
	if not _scrubbing:
		_seek.set_value_no_signal(session.tick)
	_status.text = tr("lab.ui.transport_status") % [session.tick * session.DT, session.furthest * session.DT, session.run.enemies.count()]
	if _branch.item_count != session.branches.size() + 1:
		_branch.clear()
		_branch.add_item(TranslationServer.translate("lab.message_98f82d7b9f"))
		for branch in session.branches:
			_branch.add_item(branch.name)
	_branch.set_item_text(0, TranslationServer.translate("lab.message_98f82d7b9f") + " " + session.current_branch)
	for index in session.branches.size():
		_branch.set_item_text(index + 1, String(session.branches[index].name))
	_status.tooltip_text = tr("lab.message_15d10dbb3a") % [session.tick * session.DT, session.furthest * session.DT, session.run.state.world_time, session.run.enemies.count(), int(session.spec.seed)] + "\n" + tr("lab.route_length") % [CHECK.length(canvas.route), session.run.draw.budget(session.run.state.stats.capacity * session.run.state.gauge), 100 * CHECK.length(canvas.route) / maxf(0.01, session.run.draw.budget(session.run.state.stats.capacity * session.run.state.gauge))]
	canvas.queue_redraw()
	_timeline.queue_redraw()
	if not canvas.result.is_empty() and _evaluation_revision >= 0 and _evaluation_revision != session.revision:
		_result.text = TranslationServer.translate("lab.message_91f8bdc328")
	inspector.refresh()
	controls.sync_from_session()

func _process(_delta: float) -> void:
	if session != null and is_instance_valid(session.run):
		_sync_view()
		_refresh()

## 試遊中は本番のカメラが機体を追い、編集用の層もその視点に合わせる。
## 編集中は編集用の層の視点（ホイール・中ドラッグで動かす）を、本番の描画のカメラに渡す。ゲームの状態は変えない。
func _sync_view() -> void:
	var render: RenderManager = session.scene.view.get_node_or_null("RenderManager") if session.scene.view != null else null
	var playing: bool = canvas.mode == 3
	var following: bool = playing or canvas.follow
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE if playing else Control.MOUSE_FILTER_STOP
	if render == null:
		return
	# HDRの本番映像を通常のUIへ重ねるときだけ、表示用の色へ変換する。
	(game_frame.material as ShaderMaterial).set_shader_parameter("convert_hdr", session.viewport.use_hdr_2d and not get_viewport().use_hdr_2d)
	# 本番の画面のうち HUD・ミニマップ・背景の星は、表示メニューで選んだときだけ出す
	render.show_background = canvas.show_background
	var hud: CanvasLayer = session.scene.view.get_node_or_null("Hud") if session.scene.view != null else null
	if hud != null:
		hud.visible = canvas.show_hud or canvas.show_minimap
		var hud_root = hud.get_node_or_null("HudRoot")
		if hud_root != null:
			hud_root.show_minimap = canvas.show_minimap
			hud_root.show_status = canvas.show_hud
	if following and render.cam_zoom > 0.0001:
		render.view_override = null
		canvas.center = render.cam_center
		canvas.zoom = render.cam_zoom
	else:
		render.view_override = {"center": canvas.center, "zoom": canvas.zoom}

## 本番の画面と同じ大きさで映す倍率（描画がまだなければ 1）。
func game_zoom() -> float:
	var render: RenderManager = session.scene.view.get_node_or_null("RenderManager") if session.scene.view != null else null
	return render.game_zoom() if render != null else 1.0

## Space で再生・停止を切り替える（実験場のどこにフォーカスがあっても。文字を入力している間を除く）。
## ボタンや本番の入力（描画の補助）には渡さない。
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	get_viewport().set_input_as_handled()
	if session == null or session.seeking or not is_instance_valid(session.run):
		return
	_toggle_play()
	# 表示枠を通って本番の入力に届いた Space（描画の補助）は捨てる
	session.run.input.poll()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and session != null:
		session.playing = false
		if is_instance_valid(canvas):
			canvas.cancel_gesture()

func _select_comparison(index: int) -> void:
	canvas.finish_route()
	var value: Dictionary = comparisons[index]
	canvas.route = value.route.duplicate()
	canvas.result = value.result.duplicate(true)
	if canvas.result.get("source_digest", canvas.result.get("digest", "")) != session.digest(): canvas.result.status = "stale"
	_evaluation_revision = session.revision
	_show_result(canvas.result)

func _status_title(value: Dictionary) -> String:
	var labels := {"static": TranslationServer.translate("lab.message_9ec7700849"), "window": TranslationServer.translate("lab.message_0df05349ff"), "unsupported": TranslationServer.translate("lab.message_af33e7e17b"), "unfound": TranslationServer.translate("lab.message_3aee526f77"), "invalid": TranslationServer.translate("lab.message_aa259c678f"), "replayed": TranslationServer.translate("lab.message_dd16bfc556") if value.get("success", false) else TranslationServer.translate("lab.message_b8f8f95d8c"), "cancelled": TranslationServer.translate("lab.message_67847e89ae"), "stale": TranslationServer.translate("lab.message_94deee7e2e")}
	return String(labels.get(value.get("status", ""), TranslationServer.translate("lab.message_68dc5e1c46")))

func _leave() -> void:
	trial.cancel()
	generator.cancelled = true
	session.cancel_seek()
	while _busy:
		await get_tree().process_frame
	GameManager.reset_to_main_menu()

func _reload_data() -> void:
	trial.cancel()
	generator.cancelled = true
	session.cancel_seek()
	while _busy: await get_tree().process_frame
	if ConfigManager.reload_experiment_data():
		await _reset()
		_fill_palette()
		_messages.text = tr("lab.data_reloaded")
	else:
		_messages.text = tr("lab.reload_failed")
