## 再生開始時の戦闘と表示を1つだけ保持し、リセットで同じSessionへ戻す。
extends RefCounted

const FIELDS := ["tick", "_cursor", "_state_key", "_content_records", "_source", "_definitions", "_boss_definitions", "_boss_programs", "_config", "_formation_sources", "_route_play", "pinned", "schedule", "events", "_selected_id", "_last_input"]
var _bridge: RefCounted
var _scene: RunSession
var _id := 0
var _key := ""
var _values := {}
var _input := {}
var _resources: Resource
var _scope: ContentResourceScope

func clear() -> void:
	if _bridge!=null and _id>0: _bridge.release_checkpoint(_id)
	_bridge = null
	_scene = null
	_id = 0
	_values.clear()
	_input.clear()
	_resources = null
	_scope = null

func capture(session: Node) -> void:
	clear()
	var held: Dictionary = session.bridge.checkpoint()
	if not held.ok:
		session.last_error = held
		return
	_bridge = session.bridge
	_scene = session.scene
	_id = int(held.value)
	_key = session._checkpoint_key(session.tick)
	for field: String in FIELDS:
		var value: Variant = session.get(field)
		_values[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	for field in session._intent.get_script().get_script_property_list():
		_input[field.name] = session._intent.get(field.name)
	_resources = _scene.cpp_resources
	if _scene.view!=null:
		_scope = _scene.view.get_node("RunPresentation").cpp_scope

func restore(session: Node) -> bool:
	if _id==0 or not is_instance_valid(_scene) or session.scene!=_scene or session.bridge!=_bridge: return false
	if session.play_start!=int(_values.tick) or _key!=session._checkpoint_key(session.play_start): return false
	var restored: Dictionary = _bridge.restore(_id)
	if not restored.ok:
		session.last_error = restored
		return false
	for field: String in FIELDS:
		var value: Variant = _values[field]
		session.set(field,value.duplicate(true) if value is Array or value is Dictionary else value)
	session._intent = Intent.new()
	for field: String in _input: session._intent.set(field,_input[field])
	session.last_error = restored
	session._accumulator = 0.0
	session.run.cfg = session._config
	session.run.enemies.data.definitions = session._definitions
	session.run.bosses.definitions = session._boss_definitions
	_scene.cpp_resources = _resources
	if _scene.view!=null:
		var presentation: RunPresentation = _scene.view.get_node("RunPresentation")
		presentation.cpp_resources = _resources
		presentation.cpp_scope = _scope
		presentation.frame_view.replace_lab_visuals(_scope,_resources.visuals)
		presentation.sync_canvas_layers()
	_bridge.collect_frame()
	session._refresh_projection()
	session.revision += 1
	return true
