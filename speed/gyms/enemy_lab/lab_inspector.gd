extends VBoxContainer

var session
var canvas
var _identity := -1
var _title: Label
var _details: Label
var _health: ProgressBar
var _values: VBoxContainer
var _controls: Dictionary = {}

func _ready() -> void:
	custom_minimum_size.x = 280
	_title = Label.new()
	_title.text = "敵を選択すると情報を表示"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	_health = ProgressBar.new()
	_health.show_percentage = false
	add_child(_health)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_details)
	var note := Label.new()
	note.text = "数値はこの実験の同じ種類に適用\n本番データは書き換えません"
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
		_title.text = "敵を選択すると情報を表示"
		_details.text = "姿・当たり判定・攻撃範囲を確認できます"
		_health.value = 0
		return
	var def: EnemyDef = t.def[i]
	_title.text = "%s\n%s #%d" % [def.display_name if def else "ボス", t.type[i], t.id[i]]
	_health.max_value = t.max_hp[i]
	_health.value = t.hp[i]
	var attack: float = session.run.cfg.base_attack * session.run.state.stats.attack_mult
	_details.text = "HP %.1f / %.1f\n装甲 %.1f　自機の攻撃 %.1f\n%s\n状態：%s\n位置 (%.0f, %.0f)　向き %.0f°" % [t.hp[i], t.max_hp[i], t.armor[i], attack,
		"貫通できる" if attack >= t.armor[i] else "装甲で弾かれる", "予告中" if t.charge[i] > 0 else "移動／待機", t.pos[i].x, t.pos[i].y, rad_to_deg(t.facing[i])]
	if not force and _identity == t.id[i]:
		return
	_identity = t.id[i]
	for node in _values.get_children():
		node.queue_free()
	_controls.clear()
	if def == null:
		return
	for key in ["hp", "armor", "speed", "radius"]:
		var names := {"hp": "基礎 HP", "armor": "基礎装甲", "speed": "基礎速度", "radius": "基礎半径"}
		_field(key, names[key], def.get(key))
	var label := Label.new()
	label.text = "攻撃・行動の設定"
	_values.add_child(label)
	for key in def.params:
		var description: Array = EnemyDef.PARAMS_DOCS.get(key, [String(key), "", ""])
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
	else:
		var spin := SpinBox.new()
		spin.min_value = -100000
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
	if i >= 0 and i < t.alive.size() and t.alive[i] and t.def[i] != null:
		session.perform("parameter", {"type": String(t.type[i]), "key": key, "value": value})
		canvas.result.clear()
		canvas.queue_redraw()
