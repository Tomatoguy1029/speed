## 実験条件・攻撃・出現・配置規則・保存の編集ドック。
extends TabContainer
const UI := preload("res://gyms/enemy_lab/lab_ui.gd")
const LIGHTING := preload("res://data/visuals/enemy_lighting.tres")
const LIGHTING_DEFAULTS := preload("res://scripts/render/enemy_lighting_settings.gd")
var lab
var result_list: ItemList
var candidates: ItemList
var candidate_cards: VBoxContainer
var name_field: LineEdit
var window_seconds: SpinBox
var margin: SpinBox
var draw_seconds: SpinBox
var exit_clearance: SpinBox
var _attack_budget: SpinBox
var _ship_level: SpinBox
var _settings: Dictionary = {}
var export_targets: ItemList
var export_phase: OptionButton
var export_stage: SpinBox
var _condition_fields: Dictionary = {}
var _attack_fields: Dictionary = {}
var _attack_toggle: CheckButton
var _attack_meter: Control
var _spawn_entries: ItemList
var _schedule_hash := 0
var _lighting_fields: Dictionary = {}
var _appearance_angle: SpinBox

func _ready() -> void:
	custom_minimum_size.x = 368
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_conditions(_page(TranslationServer.translate("lab.message_72f1cf759c")))
	_attacks(_page(TranslationServer.translate("lab.message_63d8f43c5b")))
	_spawns(_page(TranslationServer.translate("lab.message_26fa279ba2")))
	_patterns(_page(TranslationServer.translate("lab.message_d7d7ce790b")))
	_files(_page(TranslationServer.translate("lab.message_fadf24dbc5")))
	_appearance(_page(tr("lab.appearance.title")))

func _appearance(page: Node) -> void:
	_text(page, tr("lab.appearance.help"))
	_button(page, tr("lab.appearance.bomber"), _inspect_bomber)
	_button(page, tr("lab.appearance.focus"), _focus_appearance)
	_appearance_angle = _number(page, tr("lab.appearance.rotation"), 0, -180, 180, 5, _rotate_appearance)
	for entry in [["key_energy", 0.0, 3.0, 0.01], ["fill_energy", 0.0, 3.0, 0.01],
		["key_angle", -180.0, 180.0, 1.0], ["fill_angle", -180.0, 180.0, 1.0],
		["height", 0.0, 1.0, 0.01], ["ambient", 0.0, 1.0, 0.01], ["normal_strength", 0.0, 3.0, 0.05]]:
		var key: String = entry[0]
		_lighting_fields[key] = _number(page, tr("lab.appearance." + key), LIGHTING.get(key), entry[1], entry[2], entry[3], _set_lighting.bind(key))
	_text(page, tr("lab.appearance.light_help"))
	_button(page, tr("lab.appearance.reset"), func():
		var defaults := LIGHTING_DEFAULTS.new()
		for key in _lighting_fields:
			LIGHTING.set(key, defaults.get(key))
			_lighting_fields[key].set_value_no_signal(LIGHTING.get(key)))
	_button(page, tr("lab.appearance.save"), func():
		for field in _lighting_fields.values():
			field.apply()
		var error := ResourceSaver.save(LIGHTING, "res://data/visuals/enemy_lighting.tres")
		lab._messages.text = tr("lab.appearance.saved") if error == OK else error_string(error))

func _set_lighting(value: float, key: String) -> void:
	LIGHTING.set(key, value)
	if is_instance_valid(lab.session.run):
		var render: RenderManager = lab.session.run.get_node("../RenderManager")
		render._apply_lighting()

func _inspect_bomber() -> void:
	if not is_instance_valid(lab.session.run):
		return
	lab.session.playing = false
	var point: Vector2 = lab.session.run.state.ship_pos + Vector2(200, 0)
	lab.session.perform("spawn", {"type": "bomber", "pos": [point.x, point.y], "count": 1})
	_focus_appearance()

func _focus_appearance() -> void:
	if not is_instance_valid(lab.session.run):
		return
	var i: int = lab.session.selected
	var table: EnemyTable = lab.session.run.enemies.table
	if i < 0 or i >= table.alive.size() or not table.alive[i] or table.dead[i]:
		lab._messages.text = tr("lab.appearance.select_enemy")
		return
	lab._set_mode(0)
	lab.session.playing = false
	lab.canvas.follow = false
	lab.canvas.center = table.pos[i]
	var available: float = maxf(40.0, minf(lab.canvas.size.x, lab.canvas.size.y) - 80.0)
	lab.canvas.zoom = minf(8.0, available / maxf(1.0, RenderManager.enemy_sprite_radius(table.type[i], table.r[i], lab.session.run.cfg.character_scale) * 2.0 * sqrt(2.0)))
	lab.canvas.show_ranges = false
	lab.canvas.show_ids = false
	lab.canvas.selection.assign([table.id[i]])
	_appearance_angle.set_value_no_signal(wrapf(rad_to_deg(table.facing[i]), -180, 180))
	lab._sync_view()
	lab._refresh()

func _rotate_appearance(degrees: float) -> void:
	if not is_instance_valid(lab.session.run):
		return
	var i: int = lab.session.selected
	var table: EnemyTable = lab.session.run.enemies.table
	if i >= 0 and i < table.alive.size() and table.alive[i] and not table.dead[i]:
		lab.session.playing = false
		lab.session.perform("move", {"id": table.id[i], "pos": [table.pos[i].x, table.pos[i].y], "angle": deg_to_rad(degrees)})

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _text(parent: Node, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _number(parent: Node, title: String, value: float, lo: float, hi: float, step_value := 1.0, action := Callable()) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _text(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.5
	var box := SpinBox.new()
	box.custom_minimum_size.x = 112
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.min_value = lo
	box.max_value = hi
	box.step = step_value
	box.value = value
	row.add_child(box)
	if action.is_valid():
		box.value_changed.connect(action)
	return box

func _button(parent: Node, title: String, action: Callable) -> Button:
	return lab._button(parent, title, action)

func _conditions(page: Node) -> void:
	lab.workspace.environment(page)
	var box := UI.fold(page, tr("lab.ui.player"), true)
	var invincible := CheckButton.new()
	invincible.text = TranslationServer.translate("lab.message_9e4c412d75")
	invincible.button_pressed = true
	invincible.toggled.connect(func(value): lab.session.perform("invincible", {"value": value}))
	box.add_child(invincible)
	_ship_level = _number(box, tr("lab.ship_level"), 1, 1, 1000, 1, func(value): lab.session.perform("level", {"value": int(value)}))
	var gauge := _number(box, TranslationServer.translate("lab.message_d79714f205"), 1, 0, 1, 0.05)
	_button(box, TranslationServer.translate("lab.message_cdff100dfe"), func(): lab.session.perform("ship", {"pos": [lab.canvas.center.x, lab.canvas.center.y], "gauge": gauge.value}))
	_formations(page)
	box = UI.fold(page, tr("lab.ui.stage_time"))
	var time := _number(box, TranslationServer.translate("lab.message_c66777f550"), 0, 0, 10000, 1)
	_button(box, TranslationServer.translate("lab.message_54036730a6"), func(): lab.session.perform("time", {"value": time.value}))
	var phase_set := OptionButton.new()
	phase_set.add_item(TranslationServer.translate("lab.message_568b393d89"))
	phase_set.add_item(TranslationServer.translate("lab.message_df7c5eeb44"))
	box.add_child(phase_set)
	_button(box, TranslationServer.translate("lab.message_ace6599b1c"), func():
		var ids := []
		if phase_set.selected == 0:
			ids = ["build1", "pressure", "build2", "rampage", "tension", "escape"]
		else:
			for suffix in ["early", "mid", "late"]:
				var id := "s%d_%s" % [int(lab.session.spec.stage), suffix]
				if ConfigManager.phases.has(StringName(id)): ids.append(id)
		lab.session.perform("phase_set", {"ids": ids}))
	box = UI.fold(page, tr("lab.ui.player_stats"))
	for entry in [["base_attack", TranslationServer.translate("lab.message_0c0e2d79f0"), 10.2], ["base_max_speed", TranslationServer.translate("lab.message_0aee0183fd"), 400.0], ["draw_length", TranslationServer.translate("lab.message_017dfdb22a"), 1020.0], ["trace_radius", TranslationServer.translate("lab.message_ec7bdd3fb0"), 28.0], ["draw_time_scale", TranslationServer.translate("lab.message_355273af8a"), 0.03], ["draw_confirm_delay", TranslationServer.translate("lab.message_ab276f5393"), 0.1], ["boss_hp", TranslationServer.translate("lab.message_6384a9a6f0"), 1000], ["boss_armor", TranslationServer.translate("lab.message_391c98f217"), 30]]:
		_condition_fields[entry[0]] = _number(box, entry[1], float(ConfigManager.base.get(entry[0])), 0.01, 100000, 1, func(value): lab.session.perform("config", {"key": entry[0], "value": value}))
	box = UI.fold(page, tr("lab.ui.loadout"))
	var meta := OptionButton.new()
	box.add_child(meta)
	for id in ConfigManager.meta_upgrades:
		meta.add_item(String(id))
		meta.set_item_metadata(meta.item_count - 1, String(id))
	var meta_level := _number(box, TranslationServer.translate("lab.message_761cc8db45"), 0, 0, 100)
	_button(box, TranslationServer.translate("lab.message_c2080e1bd3"), func(): lab.session.perform("meta", {"id": meta.get_item_metadata(meta.selected), "level": int(meta_level.value)}))
	var kind := OptionButton.new()
	kind.add_item(TranslationServer.translate("lab.message_6f0f16e0c0"))
	kind.add_item(TranslationServer.translate("lab.message_b62ed716e3"))
	box.add_child(kind)
	var definitions := OptionButton.new()
	box.add_child(definitions)
	var fill := func(_i):
		definitions.clear()
		for def in ConfigManager.sorted(ConfigManager.weapons if kind.selected == 0 else ConfigManager.traits):
			definitions.add_item("%s %s" % [def.id, def.get_display_name()])
			definitions.set_item_metadata(definitions.item_count - 1, String(def.id))
	kind.item_selected.connect(fill)
	fill.call(0)
	var level := _number(box, TranslationServer.translate("lab.message_5c146b19a7"), 1, 1, 100)
	_button(box, TranslationServer.translate("lab.message_030e3f7f9b"), func(): lab.session.perform("loadout", {"kind": "weapon" if kind.selected == 0 else "trait", "id": definitions.get_item_metadata(definitions.selected), "level": int(level.value)}))
	_button(box, TranslationServer.translate("lab.message_c1f482ed04"), func(): lab.session.perform("loadout", {"reset": true}))
	var heroes := OptionButton.new()
	box.add_child(heroes)
	heroes.add_item(TranslationServer.translate("lab.message_7a50a34743"))
	heroes.set_item_metadata(0, "")
	for id in ConfigManager.heroes:
		heroes.add_item(String(id))
		heroes.set_item_metadata(heroes.item_count - 1, String(id))
	heroes.item_selected.connect(func(i): lab.session.perform("hero", {"id": heroes.get_item_metadata(i)}))
	_button(box, TranslationServer.translate("lab.message_3b8a4d49ef"), func(): lab.session.perform("input", {"has_cursor": false, "hero": true}))
	_button(box, TranslationServer.translate("lab.message_e52adaaa4c"), func():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lab/enemy_variants.json"))
		for variant in data.variants:
			for key in variant.overrides.params:
				lab.session.perform("parameter", {"type": variant.enemy, "key": "params." + key, "value": variant.overrides.params[key]}))

## 敵の組み合わせ（res://data/formations/*.tscn）の配置と出現位置を選んで、機体のまわりに並べる。
func _formations(page: Node) -> void:
	var box := UI.fold(page, tr("lab.ui.formation"))
	var files := OptionButton.new()
	var layouts := OptionButton.new()
	var entries := OptionButton.new()
	for f in DirAccess.get_files_at("res://data/formations"):
		if f.ends_with(".tscn"):
			files.add_item(f.get_basename())
			files.set_item_metadata(files.item_count - 1, "res://data/formations/" + f)
	var fill := func(_i: int) -> void:
		layouts.clear()
		entries.clear()
		if files.item_count == 0:
			return
		var node: Node = load(String(files.get_item_metadata(files.selected))).instantiate()
		for c in node.get_children():
			if c is FormationLayout:
				layouts.add_item(c.name)
			elif c is FormationEntry:
				entries.add_item(c.name)
		node.free()
	files.item_selected.connect(fill)
	box.add_child(files)
	_text(box, tr("lab.formation.layout"))
	box.add_child(layouts)
	_text(box, tr("lab.formation.entry"))
	box.add_child(entries)
	fill.call(0)
	_button(box, tr("lab.formation.place"), func():
		if files.item_count == 0:
			return
		lab.session.perform("formation", {"path": files.get_item_metadata(files.selected), "layout": layouts.selected,
			"entry": entries.selected}))

func _attacks(box: Node) -> void:
	var toggle := CheckButton.new()
	_attack_toggle = toggle
	toggle.text = TranslationServer.translate("lab.message_e2074e817f")
	toggle.toggled.connect(func(value): _settings.enabled = value; _apply_director())
	box.add_child(toggle)
	_settings = {"enabled": false, "budget": 4.0, "slots": {}, "weights": {}, "gaps": {}, "jitter": 0.3}
	_attack_budget = _number(box, TranslationServer.translate("lab.message_f4a90d8530"), 4, 0, 100, 0.25, func(value): _settings.budget = value; _apply_director())
	_number(box, tr("lab.attack.jitter"), 0.3, 0, 3, 0.05, func(value): _settings.jitter = value; _apply_director())
	# 強敵と大物の攻撃の重さ（種類ごと。予算の合計に数える）
	var heavy := UI.fold(box, tr("lab.attack.danger"))
	for def in ConfigManager.sorted(ConfigManager.enemies):
		if def.rank >= 3 and preload("res://scripts/encounters/attack_director.gd").BEHAVIORS.has(String(def.behavior)):
			_number(heavy, "%s %s" % [def.display_name, def.id], def.attack_weight, 0, 20, 0.25,
				func(value): lab.session.perform("parameter", {"type": String(def.id), "key": "attack_weight", "value": value}))
	var meter = load("res://gyms/enemy_lab/lab_attack_meter.gd").new()
	_attack_meter = meter
	meter.session = lab.session
	box.add_child(meter)
	meter.tooltip_text = tr("lab.attack_legend")
	box = UI.fold(box, tr("lab.ui.attack_limits"))
	var names := {"aimed": TranslationServer.translate("lab.message_e25e93d055"), "homing": TranslationServer.translate("lab.message_bbcc068b7e"), "dash": TranslationServer.translate("lab.message_437d9cf8d0"), "beam": TranslationServer.translate("lab.message_421607de84"), "zone": TranslationServer.translate("lab.message_1133c374e7"), "wave": TranslationServer.translate("lab.message_f3482a22c0"), "residue": TranslationServer.translate("lab.message_c04c40391d")}
	for category in names:
		_text(box, names[category])
		var row := VBoxContainer.new()
		box.add_child(row)
		for setting in [["slots", TranslationServer.translate("lab.message_61bf2700ce"), 1.0, 1.0], ["weights", TranslationServer.translate("lab.message_d0fdf2aa39"), 1.0, 0.25], ["gaps", TranslationServer.translate("lab.message_c7f2b1e003"), 0.35, 0.05]]:
			var column := VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(column)
			_settings[setting[0]][category] = setting[2]
			_attack_fields[setting[0] + ":" + category] = _number(column, setting[1], setting[2], 0, 100, setting[3], func(value): _settings[setting[0]][category] = value; _apply_director())
	_attack_toggle.tooltip_text = tr("lab.message_1a59dadeb6")

func _apply_director() -> void:
	if is_instance_valid(lab.session.run):
		lab.session.perform("director", _settings)

func _spawns(box: Node) -> void:
	box.tooltip_text = tr("lab.message_dc8d5ae40c")
	var start := _number(box, TranslationServer.translate("lab.message_5fdbd8f764"), 0, 0, 3600, 0.1)
	var end := _number(box, TranslationServer.translate("lab.message_51b9d6157a"), 30, 0, 3600, 0.1)
	var interval := _number(box, TranslationServer.translate("lab.message_274c228534"), 2, 0.1, 300, 0.1)
	var probability := _number(box, tr("lab.spawn_probability"), 1, 0, 1, 0.05)
	var radius := _number(box, tr("lab.spawn_radius"), 0, 0, 2000, 10)
	var entries := ItemList.new()
	_spawn_entries = entries
	entries.custom_minimum_size.y = 140
	box.add_child(entries)
	_button(box, TranslationServer.translate("lab.message_7c4fd18609"), func():
		var values: Array = lab.session.schedule.duplicate(true)
		values.append({"type": lab.canvas.spawn_type, "pos": [lab.canvas.center.x, lab.canvas.center.y], "count": lab.canvas.spawn_count, "start": start.value, "end": end.value, "interval": interval.value, "enabled": true, "probability": probability.value, "radius": radius.value})
		lab.session.perform("schedule", {"entries": values}))
	_button(box, tr("lab.lane_toggle"), func():
		if entries.get_selected_items().is_empty(): return
		var index := entries.get_selected_items()[0]
		var values: Array = lab.session.schedule.duplicate(true)
		if index >= values.size(): return
		values[index].enabled = not values[index].get("enabled", true)
		lab.session.perform("schedule", {"entries": values})
		entries.set_item_text(index, ("▶ " if values[index].enabled else "○ ") + String(values[index].type)))
	_button(box, tr("lab.lane_apply"), func():
		if entries.get_selected_items().is_empty(): return
		var index := entries.get_selected_items()[0]
		var values: Array = lab.session.schedule.duplicate(true)
		if index >= values.size(): return
		values[index].merge({"start": start.value, "end": end.value, "interval": interval.value, "probability": probability.value, "radius": radius.value, "pos": [lab.canvas.center.x, lab.canvas.center.y]}, true)
		lab.session.perform("schedule", {"entries": values}))
	_button(box, TranslationServer.translate("lab.message_25c440c98a"), func():
		if entries.get_selected_items().is_empty(): return
		var index := entries.get_selected_items()[0]
		var values: Array = lab.session.schedule.duplicate(true)
		if index < values.size(): values.remove_at(index)
		lab.session.perform("schedule", {"entries": values}))
	_button(box, TranslationServer.translate("lab.message_0113c8102f"), func(): lab.session.perform("schedule", {"entries": []}))

func _patterns(page: Node) -> void:
	var box := UI.fold(page, tr("lab.ui.route_settings"))
	draw_seconds = _number(box, TranslationServer.translate("lab.message_d144e6855f"), 0.5, 0.05, 20, 0.05)
	margin = _number(box, TranslationServer.translate("lab.message_2fcfd99d3b"), 20, 0, 1000, 1)
	exit_clearance = _number(box, tr("lab.exit_clearance"), 0, 0, 1000, 10, func(value): lab.canvas.exit_clearance = value; lab.canvas.result.clear())
	var spacing := _number(box, tr("lab.min_spacing"), 0, 0, 1000, 10)
	window_seconds = _number(box, TranslationServer.translate("lab.message_e10ded50d8"), 0, 0, 20, 0.1)
	_button(box, TranslationServer.translate("lab.message_f7df32cd04"), lab._validate_route)
	_button(box, TranslationServer.translate("lab.message_fb60080a99"), lab._evaluate)
	_button(box, TranslationServer.translate("lab.message_6cc4ba4282"), func():
		var value: Dictionary = lab.CHECK.validate(lab.session, lab.canvas.route, margin.value, window_seconds.value, draw_seconds.value, exit_clearance.value)
		if value.status != "window" or window_seconds.value <= 0:
			lab._messages.text = TranslationServer.translate("lab.message_65f985536b")
			return
		lab.session.perform("guard", {"route": lab.canvas.route, "margin": margin.value, "until": lab.session.run.state.world_time + window_seconds.value})
		lab._messages.text = TranslationServer.translate("lab.message_47a613a504"))
	box = UI.fold(page, tr("lab.ui.route_comparisons"))
	_button(box, TranslationServer.translate("lab.message_93025fc5b1"), func(): lab.comparisons.append({"route": lab.canvas.route.duplicate(), "result": lab.canvas.result.duplicate(true)}); lab._update_comparisons())
	result_list = ItemList.new()
	result_list.custom_minimum_size.y = 100
	box.add_child(result_list)
	result_list.item_selected.connect(lab._select_comparison)
	box = UI.fold(page, tr("lab.ui.pattern_settings"), true)
	var jitter := _number(box, TranslationServer.translate("lab.message_0a50b49bd2"), 60, 0, 1000)
	_button(box, TranslationServer.translate("lab.message_4855e0d71e"), func():
		lab.canvas.finish_route()
		lab.pattern = lab.generator.capture(lab.session, lab.canvas.route, jitter.value, margin.value)
		lab.pattern["window"] = window_seconds.value
		lab.pattern["draw_seconds"] = draw_seconds.value
		lab.pattern["exit_clearance"] = exit_clearance.value
		lab.pattern["min_spacing"] = spacing.value
		lab.canvas.pattern = lab.pattern
		lab._set_mode(4)
		lab._messages.text = TranslationServer.translate("lab.message_277d733b3c"))
	var roles := OptionButton.new()
	roles.add_item(TranslationServer.translate("lab.message_facbd979fc"))
	roles.add_item(TranslationServer.translate("lab.message_098b17ccc2"))
	box.add_child(roles)
	var min_count := _number(box, TranslationServer.translate("lab.message_1dafdf40bb"), 1, 0, 100)
	var max_count := _number(box, TranslationServer.translate("lab.message_482249e12a"), 1, 0, 100)
	_button(box, TranslationServer.translate("lab.message_21716b1b31"), func():
		var index: int = lab.canvas.selected_region
		if index < 0 or index >= lab.pattern.get("regions", []).size(): return
		var region: Dictionary = lab.pattern.regions[index]
		region.type = lab.canvas.spawn_type
		region.role = "fodder" if roles.selected == 0 else "avoid"
		region.min_count = int(min_count.value)
		region.max_count = maxi(int(min_count.value), int(max_count.value))
		lab.canvas.queue_redraw())
	var rotation := _number(box, TranslationServer.translate("lab.message_6ffb4b865c"), 180, 0, 180)
	var min_scale := _number(box, TranslationServer.translate("lab.message_2abddd7072"), 0.8, 0.1, 1, 0.05)
	var min_fodder := _number(box, TranslationServer.translate("lab.message_66086de6d6"), 1, 0, 10000)
	_button(box, TranslationServer.translate("lab.message_d8cfb525ed"), func():
		if lab.pattern.is_empty(): lab._messages.text = TranslationServer.translate("lab.message_a19b200d4f"); return
		lab.pattern.rotation = deg_to_rad(rotation.value)
		lab.pattern.scale_min = min_scale.value
		lab.pattern.min_fodder = int(min_fodder.value)
		await lab._generate_candidates())
	candidates = ItemList.new()
	candidates.custom_minimum_size.y = 110
	box.add_child(candidates)
	candidates.item_selected.connect(lab._preview_candidate)
	candidate_cards = VBoxContainer.new()
	box.add_child(candidate_cards)
	_button(box, TranslationServer.translate("lab.message_f90284f87e"), lab._apply_candidate)

func _files(box: Node) -> void:
	name_field = LineEdit.new()
	name_field.placeholder_text = TranslationServer.translate("lab.message_4499d20c4e")
	name_field.text = "experiment"
	box.add_child(name_field)
	_button(box, TranslationServer.translate("lab.message_3e46ee4fc1"), func(): lab._save(false))
	_button(box, TranslationServer.translate("lab.message_0a6f61cf06"), func(): lab._save(true))
	_button(box, TranslationServer.translate("lab.message_c1df88bfc2"), lab._choose_file)
	box = UI.fold(box, tr("lab.ui.production_export"))
	box.tooltip_text = tr("lab.message_e419196088")
	export_stage = _number(box, TranslationServer.translate("lab.message_b8d712fc9b"), 1, 1, ConfigManager.stage_count())
	export_phase = OptionButton.new()
	export_phase.add_item(TranslationServer.translate("lab.message_82b885c33d"))
	export_phase.set_item_metadata(0, "")
	for def in ConfigManager.sorted(ConfigManager.phases):
		export_phase.add_item(String(def.id))
		export_phase.set_item_metadata(export_phase.item_count - 1, String(def.id))
	box.add_child(export_phase)
	export_targets = ItemList.new()
	export_targets.select_mode = ItemList.SELECT_MULTI
	export_targets.custom_minimum_size.y = 150
	for def in ConfigManager.sorted(ConfigManager.enemies):
		export_targets.add_item("%s %s" % [def.id, def.display_name])
		export_targets.set_item_metadata(export_targets.item_count - 1, String(def.id))
	box.add_child(export_targets)
	_button(box, TranslationServer.translate("lab.message_e98240632d"), lab._export)
	export_targets.tooltip_text = tr("lab.message_5da55226e3")

func sync_from_session() -> void:
	if not is_instance_valid(lab.session.run): return
	var run: RunManager = lab.session.run
	for key in _condition_fields:
		var box: SpinBox = _condition_fields[key]
		if not box.get_line_edit().has_focus() and not is_equal_approx(box.value, float(run.cfg.get(key))): box.set_value_no_signal(float(run.cfg.get(key)))
	if not _ship_level.get_line_edit().has_focus(): _ship_level.set_value_no_signal(run.state.level)
	var director = run.projectiles.director
	_attack_toggle.set_pressed_no_signal(director.enabled)
	if not _attack_budget.get_line_edit().has_focus(): _attack_budget.set_value_no_signal(float(director.settings.budget))
	_attack_meter.queue_redraw()
	_settings = director.settings.duplicate(true)
	_settings["enabled"] = director.enabled
	for key in _attack_fields:
		var pair: PackedStringArray = String(key).split(":")
		var box: SpinBox = _attack_fields[key]
		var value := float(_settings.get(pair[0], {}).get(pair[1], 0.35 if pair[0] == "gaps" else 1.0))
		if not box.get_line_edit().has_focus() and not is_equal_approx(box.value, value): box.set_value_no_signal(value)
	var schedule_hash := hash(var_to_bytes(lab.session.schedule))
	if _schedule_hash != schedule_hash:
		_schedule_hash = schedule_hash
		var indices := _spawn_entries.get_selected_items()
		_spawn_entries.clear()
		for entry in lab.session.schedule:
			_spawn_entries.add_item(("▶ " if entry.get("enabled", true) else "○ ") + "%s ×%d %.1f–%.1fs" % [String(entry.get("type", "")), int(entry.get("count", 1)), float(entry.get("start", 0)), float(entry.get("end", 600))])
		if not indices.is_empty() and indices[0] < _spawn_entries.item_count: _spawn_entries.select(indices[0])
