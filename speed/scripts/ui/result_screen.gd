## 結果（仕様書 3）。記録と獲得した部品を表示し、「もう一回やる」か「メインメニューに戻る」を選ぶ。
extends UiScreen

func _ready() -> void:
	can_go_back = false
	var r := GameManager.last_result
	var cleared: bool = r.get("cleared", false)
	%Heading.text = tr("result.cleared") if cleared else tr("result.failed")
	var t := float(r.get("time", 0.0))
	var lines := [
		tr("result.stage").format({n = int(r.get("stage", 0))}),
		tr("result.time").format({time = "%d:%02d" % [int(t) / 60, int(t) % 60]}),
		tr("result.kills").format({n = int(r.get("kills", 0))}),
		tr("result.level").format({n = int(r.get("level", 1))}),
		tr("result.peak_speed").format({speed = "%.2f" % (float(r.get("peak_speed", 0.0)) * ContentManager.cfg.speed_to_kms)}),
		tr("result.parts").format({n = int(r.get("coins", 0))}),
	]
	if cleared and r.get("legendary", "") != "":
		var def = ContentManager.legendary_modules.get(StringName(r.legendary))
		if def != null:
			lines.append(tr("result.legendary").format({name = def.get_display_name()}))
	var best: Dictionary = SaveManager.data.best
	if float(best.fastest_clear) >= 0.0:
		var f := float(best.fastest_clear)
		lines.append(tr("result.fastest").format({time = "%d:%02d" % [int(f) / 60, int(f) % 60]}))
	for line in lines:
		var l := Label.new()
		l.text = line
		%Content.add_child(l)
	%RetryButton.pressed.connect(func(): AudioManager.play(&"ui"); GameManager.retry_run())
	%MenuButton.pressed.connect(func(): AudioManager.play(&"ui"); GameManager.reset_to_main_menu())
	super()
