## メインメニュー（仕様書 3）。「ステージ選択」「機体の強化」「図鑑」。
extends UiScreen

func _ready() -> void:
	%StageSelectButton.pressed.connect(func(): _go(GameManager.Screen.STAGE_SELECT))
	%UpgradeButton.pressed.connect(func(): _go(GameManager.Screen.UPGRADE))
	%EncyclopediaButton.pressed.connect(func(): _go(GameManager.Screen.ENCYCLOPEDIA))
	%Coins.text = tr("common.parts").format({n = SaveManager.coins()})
	if OS.is_debug_build():
		var lab := Button.new()
		lab.text = tr("menu.enemy_lab")
		lab.custom_minimum_size = Vector2(320, 52)
		lab.pressed.connect(func(): _go(GameManager.Screen.ENEMY_LAB))
		%Content.add_child(lab)
	super()

func _go(screen: GameManager.Screen) -> void:
	AudioManager.play(&"ui")
	GameManager.goto(screen)
