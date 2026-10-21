## タイトル（仕様書 3）。「ゲームスタート」「設定」「終了」。
extends UiScreen

func _ready() -> void:
	%StartButton.pressed.connect(func(): _go(GameManager.Screen.MAIN_MENU))
	%SettingsButton.pressed.connect(func(): _go(GameManager.Screen.SETTINGS))
	%QuitButton.pressed.connect(GameManager.quit_game)
	# ブラウザ版ではアプリを終了できないので、終了ボタンを出さない
	%QuitButton.visible = not OS.has_feature("web")
	super()

func _go(screen: GameManager.Screen) -> void:
	AudioManager.play(&"ui")
	GameManager.goto(screen)
