## メインメニュー（仕様書 2.1）。「ステージ選択」「機体の強化」「図鑑」。
extends UiScreen

func _ready() -> void:
	%StageSelectButton.pressed.connect(func(): _go(GameManager.Screen.STAGE_SELECT))
	%UpgradeButton.pressed.connect(func(): _go(GameManager.Screen.UPGRADE))
	%EncyclopediaButton.pressed.connect(func(): _go(GameManager.Screen.ENCYCLOPEDIA))
	%Coins.text = "部品 %d" % SaveManager.coins()
	super()

func _go(screen: GameManager.Screen) -> void:
	AudioManager.play(&"ui")
	GameManager.goto(screen)
