## 結果（仕様書 3）。記録と獲得した部品を表示し、「もう一回やる」か「メインメニューに戻る」を選ぶ。
extends UiScreen

func _ready() -> void:
	can_go_back = false
	var r := GameManager.last_result
	var cleared: bool = r.get("cleared", false)
	%Heading.text = "クリア" if cleared else "失敗"
	var t := float(r.get("time", 0.0))
	var lines := [
		"ステージ %d" % int(r.get("stage", 0)),
		"時間　%d:%02d" % [int(t) / 60, int(t) % 60],
		"撃破　%d" % int(r.get("kills", 0)),
		"レベル　%d" % int(r.get("level", 1)),
		"最高速度　%.2f km/s" % (float(r.get("peak_speed", 0.0)) * ConfigManager.cfg.speed_to_kms),
		"獲得した部品　%d" % int(r.get("coins", 0)),
	]
	if cleared and r.get("legendary", "") != "":
		var def = ConfigManager.legendary_modules.get(StringName(r.legendary))
		if def != null:
			lines.append("手に入れた伝説のモジュール　%s" % def.display_name)
	var best: Dictionary = SaveManager.data.best
	if float(best.fastest_clear) >= 0.0:
		var f := float(best.fastest_clear)
		lines.append("最速クリア　%d:%02d" % [int(f) / 60, int(f) % 60])
	for line in lines:
		var l := Label.new()
		l.text = line
		%Content.add_child(l)
	%RetryButton.pressed.connect(func(): AudioManager.play(&"ui"); GameManager.retry_run())
	%MenuButton.pressed.connect(func(): AudioManager.play(&"ui"); GameManager.reset_to_main_menu())
	super()
