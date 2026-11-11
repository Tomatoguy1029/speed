extends Node
const WINDOW := preload("res://scripts/ui/navigation_window.gd")
const FLAGS := {"landmark": "landmark_guide_seen", "hero_discovered": "hero_guide_seen"}
var bridge: RefCounted
var hud: Control
var pending: Array[String] = []
var window: Control

func setup(connection: RefCounted, display: Control) -> void:
	bridge = connection
	hud = display
	bridge.subscribe("navigation-guides", _receive, ["hero", "phase", "lab_mode"], ["landmark", "hero_discovered", "hero_freed", "boss_spawn"])

func _receive(frame: Dictionary) -> bool:
	if frame.ui.get("lab_mode", false): return true
	for event: Dictionary in frame.events:
		var kind := String(event.type)
		if kind in ["hero_freed", "boss_spawn"]:
			pending.clear()
		elif FLAGS.has(kind) and not SaveManager.data.get(FLAGS[kind], false) and not pending.has(kind):
			pending.append(kind)
	return true

func _process(_delta: float) -> void:
	if window != null or pending.is_empty() or hud == null: return
	if not hud.can_show_navigation_guide(): return
	var kind: String = pending.pop_front()
	if SaveManager.data.get(FLAGS[kind], false): return
	window = WINDOW.new()
	window.hero_guide = kind == "hero_discovered"
	if not hud.show_menu_overlay(window):
		window.free()
		window = null
		pending.push_front(kind)
		return
	hud.add_child(window)
	window.z_index = 100
	window.closed.connect(_close)
	SaveManager.data[FLAGS[kind]] = true
	SaveManager.save()

func _close() -> void:
	if window == null: return
	hud.close_menu_overlay(window)
	window.hide()
	window.queue_free()
	window = null

func _exit_tree() -> void:
	if window != null and is_instance_valid(hud): _close()
	if bridge != null: bridge.unsubscribe("navigation-guides")
