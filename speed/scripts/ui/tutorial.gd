## 初回の操作練習。ステージ1の最初のランの冒頭で、説明パネルと実際の操作を交互に進める。
## 敵の配置・回収の許可・終了はC++の tutorial 命令へ渡し、機体・線・敵・カードは通常のランをそのまま使う。
extends Control

const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase
const LESSONS := preload("res://scripts/ui/tutorial_lessons.gd")
const PROMPT := preload("res://scripts/ui/tutorial_prompt.gd")
const STRIP := preload("res://scripts/ui/tutorial_strip.gd")
const MARKERS := preload("res://scripts/ui/tutorial_markers.gd")
const DESIGN := Vector2(1280, 720)
const ENEMY := "biter"
const GATES := 3
enum Step { MOVE, BOOST, GAUGE, XP, CARDS, DONE }

var hud: Control
var bridge: RefCounted
var world: Node2D
var _ui: Dictionary = {}
var _events: Array = []
var _step := -1
var _next_step := Step.MOVE
var _delay := 0.8
var _prompt: Control
var _markers: Node2D
var _canvas: Control
var _caption_box: PanelContainer
var _caption: Label
var _strip: HBoxContainer
var _gate := Vector2.ZERO
var _gates_left := GATES
var _boosted := false
var _enemies := 0
var _start_level := 0
var _done_time := 0.0
## 敵を置いた場所（置いた順）
var _spots: Array[PackedVector2Array] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	var column := VBoxContainer.new()
	column.position = Vector2(0, 560)
	column.size = Vector2(DESIGN.x, 130)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(column)
	_caption_box = PanelContainer.new()
	_caption_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_caption_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.13, 0.85)
	style.border_color = Color("2f4466")
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_caption_box.add_theme_stylebox_override("panel", style)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 24)
	_caption_box.add_child(_caption)
	column.add_child(_caption_box)
	_strip = STRIP.new()
	column.add_child(_strip)
	_caption_box.hide()
	_strip.hide()
	_markers = MARKERS.new()
	world.add_child(_markers)
	resized.connect(_layout)
	_layout()
	bridge.subscribe("tutorial", _receive, ["draw", "ship", "view_center", "view_half", "phase", "level", "tutorial"], ["trace_end"])

func _exit_tree() -> void:
	if bridge != null:
		bridge.unsubscribe("tutorial")
	if is_instance_valid(_markers):
		_markers.queue_free()

func _layout() -> void:
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - DESIGN * factor) * 0.5

func _receive(frame: Dictionary) -> bool:
	_ui = frame.ui
	_events.append_array(frame.events)
	return true

func _ship() -> Vector2:
	return _ui.ship.ship_pos

func _process(delta: float) -> void:
	if _ui.is_empty():
		return
	var half: Vector2 = _ui.view_half
	_markers.ship = _ship()
	_markers.pixel = half.x * 2.0 / 640.0
	_markers.set_drawing(bool(_ui.draw.drawing))
	var events := _events
	_events = []
	if _step == Step.DONE:
		_done_time += delta
		_caption_box.modulate.a = clampf(5.0 - _done_time, 0.0, 1.0)
		if _done_time >= 5.0:
			queue_free()
		return
	if _prompt != null:
		return
	var phase := int(_ui.phase)
	if _step != _next_step:
		# 次の段は、通常の操作へ戻ってから少し間を置いて説明を開く。
		if phase == Phase.Play and not bool(_ui.draw.tracing):
			_delay -= delta
		if _delay <= 0.0 or (_next_step == Step.CARDS and phase == Phase.Levelup):
			_open(_next_step)
		return
	var status: Dictionary = bridge.command("tutorial", {"action": "status"})
	var target := _ship()
	if status.ok:
		_enemies = int(status.value.enemies)
		if _step in [Step.BOOST, Step.GAUGE] and _enemies > 0:
			target = status.value.nearest_enemy
		elif _step == Step.XP and int(status.value.gems) > 0:
			target = status.value.nearest_gem
	# 目標が画面の外にあるときだけ、機体から向きを示す。
	var offset := (target - Vector2(_ui.view_center)).abs()
	_markers.point_to(target, offset.x > half.x * 0.92 or offset.y > half.y * 0.92)
	match _step:
		Step.MOVE:
			if _ship().distance_to(_gate) < _markers.gate_radius:
				_gates_left -= 1
				AudioManager.play(&"ui.common.confirm")
				if _gates_left <= 0:
					_markers.hide_gate()
					_advance(Step.BOOST)
				else:
					_place_gate()
		Step.BOOST:
			for event: Dictionary in events:
				if event.type == "trace_end":
					_boosted = true
			if _boosted and not bool(_ui.draw.tracing):
				_markers.hide_path()
				_advance(Step.GAUGE)
		Step.GAUGE:
			if _enemies == 0:
				_advance(Step.XP)
		Step.XP:
			if phase == Phase.Levelup:
				_advance(Step.CARDS, 0.0)
		Step.CARDS:
			if phase == Phase.Play and int(_ui.level) > _start_level and not hud.reward_active():
				_finish()
	_refresh()

func _advance(next: int, delay := 0.7) -> void:
	_next_step = next
	_delay = delay
	_caption_box.hide()
	_strip.hide()

## 段の準備をして説明を開く。ランは説明を閉じるまで止まる。
func _open(step: int) -> void:
	var prompt := PROMPT.new(LESSONS.LESSONS[step])
	if not hud.show_menu_overlay(prompt):
		prompt.free()
		return
	_step = step
	_prompt = prompt
	hud.add_child(prompt)
	prompt.closed.connect(_close_prompt)
	var half: Vector2 = _ui.view_half
	var reach := minf(half.x, half.y)
	match step:
		Step.MOVE:
			_markers.gate_radius = reach * 0.16
			_place_gate()
		Step.BOOST:
			var path := _guide_path(reach)
			_markers.show_path(path, ContentManager.cfg.trace_radius)
			var spots := PackedVector2Array()
			for fraction: float in [0.25, 0.4, 0.55, 0.7, 0.85]:
				spots.append(path[roundi(fraction * (path.size() - 1))])
			_spawn(spots)
		Step.GAUGE:
			var spots := PackedVector2Array()
			for side: float in [-1.0, 1.0]:
				for i in 4:
					var along := (i - 1.5) * reach * 0.3
					spots.append(_ship() + Vector2(side * reach * (1.05 - absf(i - 1.5) * 0.08), along))
			_spawn(spots)
		Step.XP:
			_start_level = int(_ui.level)
			bridge.command("tutorial", {"action": "pickups", "enabled": true})
	_refresh()

func _close_prompt() -> void:
	var prompt := _prompt
	_prompt = null
	hud.close_menu_overlay(prompt)
	prompt.queue_free()
	_refresh()

func _place_gate() -> void:
	var half: Vector2 = _ui.view_half
	var reach := minf(half.x, half.y)
	var heading: Vector2 = _ui.ship.ship_heading
	var turn: float = [0.5, -1.9, 1.6][GATES - _gates_left]
	_gate = _ship() + heading.rotated(turn) * reach * 0.95
	_markers.show_gate(_gate)

## お手本の線。機体の少し先から、進む向きへ山なりに描く。
func _guide_path(reach: float) -> PackedVector2Array:
	var heading: Vector2 = _ui.ship.ship_heading
	if heading.length() < 0.5:
		heading = Vector2.RIGHT
	var side := heading.orthogonal()
	var length := minf(float(_ui.draw.draw_reach) * 0.55, reach * 1.5)
	var start := _ship() + heading * reach * 0.3 - side * length * 0.42
	var finish := start + side * length * 0.84
	var control := (start + finish) * 0.5 + heading * length * 0.62
	var points := PackedVector2Array()
	for i in 33:
		var t := i / 32.0
		points.append(start.lerp(control, t).lerp(control.lerp(finish, t), t))
	return points

func _spawn(spots: PackedVector2Array) -> void:
	_spots.append(spots)
	var result: Dictionary = bridge.command("tutorial", {"action": "spawn", "enemy": ENEMY, "positions": spots})
	if not result.ok:
		push_warning("操作練習の敵を配置できません: " + str(result.get("message", "")))

func _finish() -> void:
	bridge.command("tutorial", {"action": "finish"})
	SaveManager.mark_tutorial_done()
	var guide := preload("res://scripts/ui/review_guide.gd").new()
	hud.add_child(guide)
	guide.run.call_deferred(hud)
	_step = Step.DONE
	_next_step = Step.DONE
	_markers.hide_gate()
	_markers.hide_path()
	_markers.point_to(Vector2.ZERO, false)
	_refresh()

func _refresh() -> void:
	var phase := int(_ui.phase)
	var text := ""
	match _step:
		Step.MOVE: text = tr("tutorial.goal.move").format({"n": _gates_left})
		Step.BOOST: text = tr("tutorial.goal.boost")
		Step.GAUGE: text = tr("tutorial.goal.gauge").format({"n": _enemies})
		Step.XP: text = tr("tutorial.goal.xp")
		Step.CARDS: text = tr("tutorial.goal.cards")
		Step.DONE: text = tr("tutorial.goal.done")
	_caption.text = text
	var playing := phase == Phase.Play or (_step == Step.CARDS and phase == Phase.Levelup)
	_caption_box.visible = _prompt == null and _step == _next_step and text != "" and (playing or _step == Step.DONE) and not (_step == Step.CARDS and hud.reward_active())
	_strip.visible = _caption_box.visible and _step in [Step.BOOST, Step.GAUGE] and phase == Phase.Play
	if _strip.visible:
		var draw: Dictionary = _ui.draw
		var active := -1
		if bool(draw.drawing):
			active = 2 if float(draw.draw_length) > float(draw.draw_limit) * 0.3 else 1
		elif not bool(draw.tracing):
			active = 0
		_strip.set_active(active)
