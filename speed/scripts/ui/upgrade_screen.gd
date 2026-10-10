## 機体の強化（仕様書 14。demo のステーションにあたる）。部品で強化を1段階ずつ買う。
extends UiScreen

func _ready() -> void:
	_build()
	super()

func _build() -> void:
	for c in %Content.get_children():
		c.queue_free()
	var coins := Label.new()
	coins.text = tr("common.parts").format({n = SaveManager.coins()})
	%Content.add_child(coins)
	for def: MetaUpgradeDef in ConfigManager.sorted(ConfigManager.meta_upgrades):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var lv := SaveManager.meta_level(def.id)
		var maxed := lv >= def.costs.size()
		var label := Label.new()
		label.custom_minimum_size = Vector2(520, 0)
		label.text = tr("upgrade.row").format({name = def.get_display_name(), desc = def.get_description(), lv = lv, max = def.costs.size()})
		row.add_child(label)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(200, 48)
		buy.text = tr("upgrade.max") if maxed else tr("upgrade.buy").format({n = def.costs[lv]})
		buy.disabled = maxed or SaveManager.coins() < def.costs[lv]
		buy.pressed.connect(_buy.bind(def))
		row.add_child(buy)
		%Content.add_child(row)

func _buy(def: MetaUpgradeDef) -> void:
	if SaveManager.buy_upgrade(def):
		AudioManager.play(&"levelup")
	_build()
	_focus_first()
