## 選んだ敵の姿、撃破可否とよく調整する数値を優先して表示する。
extends VBoxContainer
const UI := preload("res://gyms/enemy_lab/lab_ui.gd")
const ICON := preload("res://gyms/enemy_lab/lab_icon.gd")
var session
var canvas
var _identity := -1
var _definition: Resource
var _title: Label
var _details: Label
var _state: Label
var _hp: Label
var _health: ProgressBar
var _values: VBoxContainer
var _portrait
var _controls: Dictionary = {}
var _elite: CheckButton
var _individual_snapshot := -1
## どう動いて攻撃するか、どう倒すかの短い説明（文章のマスタの lab.enemy.<type ID>.move / .kill）
var _how: Label
var _kill: Label

func _ready() -> void:
	var heading := HBoxContainer.new()
	add_child(heading)
	_portrait = ICON.new()
	heading.add_child(_portrait)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(names)
	_title = _text(names, "")
	_title.add_theme_font_size_override("font_size", 18)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state = _text(names, "")
	_state.add_theme_font_size_override("font_size", 12)
	_hp = _text(self, "")
	_health = ProgressBar.new()
	_health.custom_minimum_size.y = 6
	_health.show_percentage = false
	_health.add_theme_stylebox_override("background", UI.style(Color("#29394c"), Color.TRANSPARENT, 0))
	_health.add_theme_stylebox_override("fill", UI.style(UI.ACCENT, Color.TRANSPARENT, 0))
	add_child(_health)
	_how = _note(tr("lab.ui.how_moves"))
	_kill = _note(tr("lab.ui.how_to_kill"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_values = VBoxContainer.new()
	_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_values)

## 小さな見出しと、折り返す説明の文を置き、説明の文を返す。
func _note(heading: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var title := _text(box, heading)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", UI.MUTED)
	var body := _text(box, "")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 120
	return body

## 敵の種類の説明を出す。説明が無い種類は隠す。
func _describe(type: StringName) -> void:
	for pair in [[_how, "lab.enemy.%s.move" % type], [_kill, "lab.enemy.%s.kill" % type]]:
		var label: Label = pair[0]
		var text := tr(pair[1])
		label.text = text
		label.get_parent().visible = text != pair[1]

func _text(parent: Node, value: String) -> Label:
	var label := Label.new()
	label.text = value
	parent.add_child(label)
	return label

func refresh(force := false) -> void:
	if session == null or not is_instance_valid(session.run): return
	var t: EnemyTable = session.run.enemies.table
	var i: int = session.selected
	if i < 0 or i >= t.alive.size() or not t.alive[i] or t.dead[i]:
		session.selected = -1
		_identity = -1
		return
	var def: Resource = session.definition_for_row(i)
	if def == null: return
	_title.text = def.display_name
	_describe(t.type[i])
	_title.tooltip_text = "%s #%d" % [t.type[i], t.id[i]]
	_portrait.definition = def
	_portrait.texture = canvas.texture_for(String(t.type[i]))
	_portrait.queue_redraw()
	_health.max_value = t.max_hp[i]
	_health.value = t.hp[i]
	_hp.text = tr("lab.ui.hp") % [t.hp[i], t.max_hp[i]]
	var attack: float = session.run.combat.attack_power()
	var pierce := attack >= t.armor[i]
	var state := tr("lab.message_09a8e159ad") if t.charge[i] > 0 or t.mode[i] == EnemyTable.Mode.WINDUP else (tr("lab.status_active") if t.mode[i] == EnemyTable.Mode.DASH else (tr("lab.status_wait") if t.mode[i] == EnemyTable.Mode.RECOVER else tr("lab.message_d44a3e6526")))
	_state.text = tr("lab.message_6fb30df6c1") if pierce else tr("lab.message_2c343fabe5")
	_state.add_theme_color_override("font_color", UI.ACCENT if pierce else Color("#ffbf83"))
	var live := tr("lab.message_6170cb0f1e") % [t.hp[i], t.max_hp[i], t.armor[i], attack, _state.text, state, t.pos[i].x, t.pos[i].y, rad_to_deg(t.facing[i])]
	var director = session.run.projectiles.director
	var owner := str(t.id[i])
	for key in director.waiting:
		if int(director.waiting[key].id) == t.id[i]: owner = String(key)
	var request: Dictionary = director.waiting.get(owner, {})
	var categories: Array = director.categories(def.behavior) if def is EnemyDef else ["boss"]
	live += "\n" + tr("lab.info_categories") % [", ".join(categories), float(request.get("priority", 0)), director.now - float(request.get("since", director.now)), String(director.reasons.get(owner, ""))]
	if session.run.field.body_gap(t.pos[i], t.r[i]) <= 0 or t.pos[i].length() + t.r[i] >= session.run.cfg.field_radius: live += "\n" + tr("lab.manual_exception")
	if not force and _identity == t.id[i]:
		_details.text = live
		_definition = def
		for key in _controls:
			var value = def.params.get(String(key).trim_prefix("params.")) if String(key).begins_with("params.") else def.get(key)
			var control = _controls[key]
			if control is SpinBox and not control.get_line_edit().has_focus(): control.set_value_no_signal(value)
			elif control is CheckButton: control.set_pressed_no_signal(value)
		var individual := t.elite[i]
		if individual != _individual_snapshot:
			_individual_snapshot = individual
			if is_instance_valid(_elite): _elite.set_pressed_no_signal(t.elite[i] != 0)
		return
	_identity = t.id[i]
	_definition = def
	for node in _values.get_children():
		_values.remove_child(node)
		node.queue_free()
	_controls.clear()
	_elite = null
	var note := _text(_values, tr("lab.ui.type_values"))
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UI.MUTED)
	note.tooltip_text = tr("lab.message_479576c49c")
	var basics := UI.fold(_values, tr("lab.ui.basic"), true)
	var names := {"hp": tr("lab.message_341a7b515f"), "toughness": tr("lab.toughness"), "armor": tr("lab.message_7d629f79a9"), "speed": tr("lab.message_80c64a0375"), "radius": tr("lab.message_b982dccaae")}
	# 星1〜5の敵の HP は星と HP の属性で決まるので、HP の代わりに属性を変える
	var hp_key := "toughness" if def is EnemyDef and def.uses_hp_table(session.run.cfg) else "hp"
	for key in ([hp_key, "armor", "speed", "radius"] if def is EnemyDef else ["speed", "radius"]): _field(basics, key, names[key], def.get(key))
	var frequent := ["fire_interval", "telegraph", "windup", "recover"]
	for key in frequent:
		if def.params.has(key): _parameter(basics, def, key)
	var advanced := UI.fold(_values, tr("lab.ui.attack_details"))
	for key in def.params:
		if not key in frequent: _parameter(advanced, def, key)
	if def is EnemyDef:
		var individual := UI.fold(_values, tr("lab.ui.individual"))
		var row := HBoxContainer.new()
		individual.add_child(row)
		_elite = CheckButton.new()
		_elite.text = tr("lab.message_684f07d574")
		_elite.button_pressed = t.elite[i] != 0
		_individual_snapshot = t.elite[i]
		row.add_child(_elite)
		UI.button(individual, tr("lab.message_597e81eb3a"), func(): session.perform("individual", {"id": _identity, "elite": _elite.button_pressed}); refresh(true))
	var live_box := UI.fold(_values, tr("lab.ui.live_details"))
	_details = _text(live_box, live)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 12)

func _parameter(parent: Node, def: Resource, key: String) -> void:
	var description: Array = (EnemyDef.PARAMS_DOCS if def is EnemyDef else BossDef.PARAMS_DOCS).get(key, [key, "", ""])
	_field(parent, "params." + key, String(description[0]), def.params[key], String(description[1]) + "\n" + String(description[2]))

func _field(parent: Node, key: String, label: String, value, help := "") -> void:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]: return
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := _text(row, label)
	title.tooltip_text = help
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if typeof(value) == TYPE_BOOL:
		var toggle := CheckButton.new()
		toggle.button_pressed = value
		toggle.toggled.connect(func(on): _change(key, on))
		row.add_child(toggle)
		_controls[key] = toggle
	else:
		var spin := SpinBox.new()
		spin.max_value = 1000000
		spin.step = 1 if typeof(value) == TYPE_INT else 0.05
		spin.min_value = spin.step if key in ["hp", "radius"] else (-100000 if key.begins_with("params.") else (-1 if key == "toughness" else 0))
		if key == "toughness":
			spin.max_value = 1
		spin.value = value
		spin.custom_minimum_size.x = 104
		spin.tooltip_text = help
		spin.value_changed.connect(func(v): _change(key, int(v) if typeof(value) == TYPE_INT else v))
		row.add_child(spin)
		_controls[key] = spin

func _change(key: String, value) -> void:
	var t: EnemyTable = session.run.enemies.table
	var i: int = session.selected
	if i >= 0 and i < t.alive.size() and session.definition_for_row(i) != null:
		session.perform("boss_parameter" if t.is_boss[i] else "parameter", {"type": String(t.type[i]), "key": key, "value": value})
		canvas.result.clear()
		canvas.queue_redraw()
