extends VBoxContainer

var session
var canvas
var _identity := -1
var _definition: Resource
var _title: Label
var _details: Label
var _health: ProgressBar
var _values: VBoxContainer
var _controls: Dictionary = {}

func _ready() -> void:
	custom_minimum_size.x = 280
	_title = Label.new()
	_title.text = TranslationServer.translate("lab.message_f111d0afe0")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	_health = ProgressBar.new()
	_health.show_percentage = false
	add_child(_health)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_details)
	var note := Label.new()
	note.text = TranslationServer.translate("lab.message_479576c49c")
	note.modulate = Color("#91a5bd")
	add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_values = VBoxContainer.new()
	_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_values)

func refresh(force := false) -> void:
	if session == null or not is_instance_valid(session.run):
		return
	var t = session.run.enemies.table
	var i: int = session.selected
	if i < 0 or i >= t.alive.size() or not t.alive[i] or t.dead[i]:
		_title.text = TranslationServer.translate("lab.message_f111d0afe0")
		_details.text = TranslationServer.translate("lab.message_a19e004551")
		_health.value = 0
		return
	var def: Resource = session.definition_for_row(i)
	_title.text = "%s\n%s #%d" % [def.display_name if def else TranslationServer.translate("lab.message_cab5ef8006"), t.type[i], t.id[i]]
	_health.max_value = t.max_hp[i]
	_health.value = t.hp[i]
	var attack: float = session.run.combat.attack_power()
	_details.text = TranslationServer.translate("lab.message_6170cb0f1e") % [t.hp[i], t.max_hp[i], t.armor[i], attack,
		TranslationServer.translate("lab.message_6fb30df6c1") if attack >= t.armor[i] else TranslationServer.translate("lab.message_2c343fabe5"), TranslationServer.translate("lab.message_09a8e159ad") if t.charge[i] > 0 or t.mode[i] == EnemyTable.Mode.WINDUP else (tr("lab.status_active") if t.mode[i] == EnemyTable.Mode.DASH else (tr("lab.status_wait") if t.mode[i] == EnemyTable.Mode.RECOVER else TranslationServer.translate("lab.message_d44a3e6526"))), t.pos[i].x, t.pos[i].y, rad_to_deg(t.facing[i])]
	var d = session.run.projectiles.director
	var owner := str(t.id[i])
	for key in d.waiting:
		if int(d.waiting[key].id) == t.id[i]: owner = String(key)
	var request: Dictionary = d.waiting.get(owner, {})
	var categories: Array = d.categories(def.behavior) if def is EnemyDef else ["boss"]
	_details.text += "\n" + tr("lab.info_categories") % [", ".join(categories), float(request.get("priority", 0)), d.now - float(request.get("since", d.now)), String(d.reasons.get(owner, ""))]
	if session.run.field.body_gap(t.pos[i], t.r[i]) <= 0 or t.pos[i].length() + t.r[i] >= session.run.cfg.field_radius:
		_details.text += "\n" + tr("lab.manual_exception")
	if not force and _identity == t.id[i]:
		_definition = def
		if def != null:
			for key in _controls:
				var value = def.params.get(String(key).trim_prefix("params.")) if String(key).begins_with("params.") else def.get(key)
				var control = _controls[key]
				if control is SpinBox and not control.get_line_edit().has_focus(): control.set_value_no_signal(value)
				elif control is CheckButton: control.set_pressed_no_signal(value)
		return
	_identity = t.id[i]
	_definition = def
	for node in _values.get_children():
		node.queue_free()
	_controls.clear()
	if def == null:
		return
	if def is EnemyDef:
		var row := HBoxContainer.new()
		_values.add_child(row)
		var level := SpinBox.new()
		level.min_value = 1
		level.max_value = 100
		level.value = t.level[i]
		level.prefix = "Lv"
		row.add_child(level)
		var elite := CheckButton.new()
		elite.text = TranslationServer.translate("lab.message_684f07d574")
		elite.button_pressed = t.elite[i] != 0
		row.add_child(elite)
		var apply := Button.new()
		apply.text = TranslationServer.translate("lab.message_597e81eb3a")
		row.add_child(apply)
		apply.pressed.connect(func(): session.perform("individual", {"id": t.id[i], "level": level.value, "elite": elite.button_pressed}); refresh(true))
	for key in (["hp", "armor", "speed", "radius"] if def is EnemyDef else ["speed", "radius"]):
		var names := {"hp": TranslationServer.translate("lab.message_341a7b515f"), "armor": TranslationServer.translate("lab.message_7d629f79a9"), "speed": TranslationServer.translate("lab.message_80c64a0375"), "radius": TranslationServer.translate("lab.message_b982dccaae")}
		_field(key, names[key], def.get(key))
	var label := Label.new()
	label.text = TranslationServer.translate("lab.message_4212b2ec66")
	_values.add_child(label)
	for key in def.params:
		var description: Array = (EnemyDef.PARAMS_DOCS if def is EnemyDef else BossDef.PARAMS_DOCS).get(key, [String(key), "", ""])
		_field("params." + String(key), String(description[0]), def.params[key], String(description[1]) + "\n" + String(description[2]))

func _field(key: String, label: String, value, help := "") -> void:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
		return
	var row := HBoxContainer.new()
	_values.add_child(row)
	var title := Label.new()
	title.text = label
	title.tooltip_text = help
	title.custom_minimum_size.x = 150
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	if typeof(value) == TYPE_BOOL:
		var toggle := CheckButton.new()
		toggle.button_pressed = value
		toggle.toggled.connect(func(on): _change(key, on))
		row.add_child(toggle)
		_controls[key] = toggle
	else:
		var spin := SpinBox.new()
		spin.min_value = 0.01 if key in ["hp", "radius"] else (-100000 if key.begins_with("params.") else 0)
		spin.max_value = 1000000
		spin.step = 1 if typeof(value) == TYPE_INT else 0.05
		spin.value = value
		spin.custom_minimum_size.x = 110
		spin.tooltip_text = help
		spin.value_changed.connect(func(v): _change(key, int(v) if typeof(value) == TYPE_INT else v))
		row.add_child(spin)
		_controls[key] = spin

func _change(key: String, value) -> void:
	var t = session.run.enemies.table
	var i: int = session.selected
	if i >= 0 and i < t.alive.size() and t.alive[i] and session.definition_for_row(i) != null:
		session.perform("boss_parameter" if t.is_boss[i] else "parameter", {"type": String(t.type[i]), "key": key, "value": value})
		canvas.result.clear()
		canvas.queue_redraw()
