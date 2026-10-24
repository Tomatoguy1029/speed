## 開発用の画面は、起動処理の登録を通してだけ本体へ加える。
extends Node
func _ready() -> void:
	var extensions: Variant = GameManager.get("extension_screens")
	var ok: bool = extensions is Dictionary
	for screen in [GameManager.Screen.ENEMY_LAB, GameManager.Screen.BACKGROUND_LAB]:
		ok = ok and extensions.has(screen) and ResourceLoader.exists(extensions[screen])
	var source := FileAccess.get_file_as_string("res://scripts/ui/main.gd")
	ok = ok and not source.contains("res://gyms/")
	var title := (load("res://scenes/app/title.tscn") as PackedScene).instantiate()
	add_child(title)
	for name in ["EnemyLabButton", "BackgroundLabButton"]:
		ok = ok and title.find_child(name, true, false) is Button
	title.free()
	if not ok: push_error("開発用の起動経路から実験場の画面を登録する")
	print("[development_menu] ", ok)
	get_tree().quit(0 if ok else 1)
