## C++が確定した表示値だけを翻訳する。候補・上限・数値の判断はランが所有する。
extends RefCounted

static func number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

static func info(values: Dictionary) -> Dictionary:
	var id: String = values.post_id
	var text := TranslationServer.translate("postmax.total").format({"a":number(values.total_before),"b":number(values.total_after),"unit":values.unit})
	var summary := "+%s%%" % number(float(values.change)*100.0)
	if values.has_current:
		text += "\n"+TranslationServer.translate("postmax.current").format({"a":number(values.current_before),"b":number(values.current_after)})
	match id:
		"heal":
			summary = "+%s%% HP" % number(float(values.increment)*100.0)
			text = TranslationServer.translate("postmax.heal_desc").format({"percent":number(float(values.increment)*100.0),"a":number(values.hp_before),"b":number(values.hp_after)})
		"weapon_interval":
			summary = TranslationServer.translate("postmax.summary.interval").format({"n":number(float(values.change)*100.0)})
			text = TranslationServer.translate("postmax.interval_total")
			for row: Dictionary in values.intervals:
				var entry: ContentEntry = ContentManager.catalog.find(&"weapons",StringName(row.weapon))
				text += "\n%s %s: %.3f → %.3fs (−%s → −%s%%)" % [entry.get_display_name(),TranslationServer.translate("postmax.interval."+row.parameter),row.before,row.after,number(row.reduction_before),number(row.reduction_after)]
		"charge_time": summary = TranslationServer.translate("postmax.summary.charge").format({"n":number(-float(values.change))})
		"max_hp":
			summary = "+%s HP" % number(values.change)
			text += "\n"+TranslationServer.translate("postmax.keep_hp")
		"invulnerability": summary = TranslationServer.translate("postmax.summary.invulnerability").format({"n":number(values.change)})
		"crit_mult": summary = TranslationServer.translate("postmax.summary.multiplier").format({"n":number(values.change)})
	for key: String in values.targets: text += "\n"+TranslationServer.translate(key)
	return {"tag":TranslationServer.translate("postmax.tag"),"name":TranslationServer.translate("postmax."+id),"desc":summary,"tooltip_desc":text,"color":Color("#9fe8ff")}

static func format_cards(ui: Dictionary) -> void:
	for card: Dictionary in ui.get("cards",{}).get("candidates",[]):
		if card.kind=="post_max" and card.info.has("post_id"): card.info = info(card.info)
	for card: Dictionary in ui.get("post_max_candidates",[]):
		if card.info.has("post_id"): card.info = info(card.info)

static func format_frame(frame: Dictionary) -> void:
	format_cards(frame.ui)
	for event: Dictionary in frame.events:
		var card: Dictionary = event.payload.get("card",{})
		if card.get("kind","")=="post_max" and card.get("info",{}).has("post_id"): card.info = info(card.info)
