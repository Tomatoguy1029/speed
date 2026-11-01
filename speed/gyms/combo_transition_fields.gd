## 制作項目を対象・phaseごとに並べる。内部の生変数を無分類で列挙しない。
extends RefCounted

const GROUPS := [
	["待機・再生", ["selection_seconds", "anticipation_seconds", "hold_seconds"]],
	["背景の暗転", ["dim_delay", "cover_seconds", "dim_easing", "dim_color", "background_dim"]],
	["画面移行", ["transition_delay", "opening_seconds", "transition_easing", "easing_power", "focus", "pixel_size", "rim_width", "glow_strength", "glow_width", "transition_opacity", "transition_color", "highlight_color"]],
	["Star Irisの形", ["inner_ratio", "spin_turns"]],
	["カードの動き", ["card_delay", "card_position", "card_start_position", "card_size", "card_start_scale", "card_overshoot", "card_zoom_seconds", "card_settle_seconds", "card_easing", "settle_easing", "card_start_rotation", "card_rotation"]],
	["カードの見た目", ["card_start_opacity", "card_opacity", "card_tint", "card_frame_color", "card_fill_color", "card_font_size", "card_text_color", "card_text_opacity", "card_icon_scale", "card_icon_opacity"]],
	["着地フラッシュ", ["flash_delay", "flash_color", "flash_strength", "flash_seconds", "flash_easing"]],
	["Combo文字", ["badge_delay", "badge_position", "badge_size", "badge_opacity", "badge_pop", "badge_spring_frequency", "badge_spring_decay", "badge_effect_seconds", "badge_outline_width", "badge_face", "badge_edge", "badge_under", "badge_outline", "badge_shadow", "badge_tag", "badge_tag_edge", "badge_tag_text"]],
	["Comboの光・線・粒", ["badge_lines_color", "badge_lines_opacity", "badge_lines_size", "badge_lines_seconds", "badge_sparks", "badge_glow", "badge_glow_radius"]],
	["Shatterの割れ方", ["ink_color", "ray_count", "band_count", "pattern_seed", "angle_jitter", "radius_jitter", "ring_gap", "radius_distribution", "crack_fraction", "crack_flash_width", "crack_tint_strength", "shard_ink_mix", "shard_fade_start", "front_delay", "scatter_speed", "fall_acceleration", "spin_speed"]],
]
const LABELS := {
	"glow_width": "輪郭の光の広がり（px）", "card_frame_color": "カードの枠・区切りの色", "card_fill_color": "カードの面の色",
	"badge_lines_seconds": "文字まわりの線の時間（秒）", "badge_glow_radius": "文字まわりの光の広がり（px）",
	"crack_flash_width": "割れる瞬間の光の長さ（進行割合）", "crack_tint_strength": "割れる瞬間の色の強さ", "shard_ink_mix": "破片の陰影の濃さ", "shard_fade_start": "破片が薄くなる開始（進行割合）",
	"selection_seconds": "選択前の表示（自動再生・秒）", "anticipation_seconds": "暗くしてから待つ（秒）", "hold_seconds": "着地後の保持（自動再生・秒）",
	"dim_delay": "選択→暗転の遅延（秒）", "cover_seconds": "暗くする時間（秒）", "dim_easing": "暗くなり方", "dim_color": "暗転の色", "background_dim": "背景を覆う透明度",
	"transition_delay": "待機→移行の遅延（秒）", "opening_seconds": "開く・割れる時間（秒）", "transition_easing": "形状の進み方", "easing_power": "進行の偏り", "focus": "移行の中心（横・縦）", "pixel_size": "移行のドット幅（px）", "rim_width": "輪郭・割れ線の太さ（px）", "glow_strength": "輪郭・割れ線の光", "transition_opacity": "輪郭・破片の透明度", "transition_color": "輪郭・割れ線の色", "highlight_color": "一番明るい輪郭の色",
	"inner_ratio": "星の切り込み", "spin_turns": "星の回転（回）",
	"card_delay": "移行→カードの遅延（秒）", "card_position": "着地位置（横・縦）", "card_start_position": "出始めの位置（横・縦）", "card_size": "着地サイズ（幅・高さpx）", "card_start_scale": "出始めの倍率", "card_overshoot": "着地直前の最大倍率", "card_zoom_seconds": "最大倍率まで（秒）", "card_settle_seconds": "最大→着地まで（秒）", "card_easing": "ズームの進み方", "settle_easing": "張り付きの進み方", "card_start_rotation": "出始めの角度（度）", "card_rotation": "着地の角度（度）",
	"card_start_opacity": "出始めの透明度", "card_opacity": "着地後の透明度", "card_tint": "カード全体に掛ける色", "card_font_size": "カード内の文字（px）", "card_text_color": "カード内の文字色", "card_text_opacity": "カード内の文字の透明度", "card_icon_scale": "カード内アイコン（倍）", "card_icon_opacity": "カード内アイコンの透明度",
	"flash_delay": "着地→フラッシュの遅延（秒）", "flash_color": "全画面フラッシュの色", "flash_strength": "フラッシュの最大透明度", "flash_seconds": "フラッシュが消えるまで（秒）", "flash_easing": "フラッシュの消え方",
	"badge_delay": "移行→文字の遅延（秒）", "badge_position": "Comboの位置（横・縦）", "badge_size": "Comboの大きさ（倍）", "badge_opacity": "Combo全体の透明度", "badge_pop": "文字が弾む強さ", "badge_spring_frequency": "弾む速さ", "badge_spring_decay": "弾みが収まる速さ", "badge_effect_seconds": "文字の粒が収まるまで（秒）", "badge_outline_width": "文字の太縁（px）", "badge_face": "文字の面の色", "badge_edge": "文字の上辺の色", "badge_under": "文字の下辺の色", "badge_outline": "文字の太縁の色", "badge_shadow": "文字の影の色", "badge_tag": "Comboタグの面の色", "badge_tag_edge": "Comboタグの線の色", "badge_tag_text": "Comboタグの文字色",
	"badge_lines_color": "文字まわりの線・粒の色", "badge_lines_opacity": "線・粒の透明度", "badge_lines_size": "線・粒の大きさ（倍）", "badge_sparks": "文字まわりの粒の数", "badge_glow": "文字まわりの光",
	"ink_color": "破片の陰影色", "ray_count": "放射状の割れ線の本数", "band_count": "半径方向の分割数", "pattern_seed": "割れの配置番号", "angle_jitter": "放射角度のばらつき", "radius_jitter": "半径のばらつき", "ring_gap": "長い破片の割合", "radius_distribution": "中心の割れの細かさ", "crack_fraction": "割れてから飛ぶまでの割合", "front_delay": "中心→外への時間差", "scatter_speed": "破片が飛ぶ速さ", "fall_acceleration": "破片の落ちる強さ", "spin_speed": "破片の回転速度",
}
const HELP := {
	"selection_seconds": "自動再生のときに通常3択を見せる時間。手動では実際にカードを選ぶまで待ちます。",
	"anticipation_seconds": "暗転が終わった状態でこの秒数だけ待機してから、移行を始めます。",
	"hold_seconds": "自動再生で次へ進むまで。手動では保持中に画面をクリックして次へ進めます。",
	"focus": "画面の左上が0・0、右下が1・1。カード位置とは独立しています。",
	"card_position": "画面に対する位置。0.5・0.5で中央です。",
	"card_start_position": "出始めの位置。画面の外から入れる値も指定できます。",
	"card_size": "通常カードは144×193px。表示幅に合わせて全体を最近傍拡大します。",
	"card_overshoot": "1.05で標準より5%大きくなってから、着地時間をかけて1.0へ戻ります。",
	"card_tint": "通常の水色カード素材に乗算する色。白が素材そのままです。",
	"flash_delay": "0でカードの着地と同期。負の値で着地より早く、正の値で遅く光ります。",
	"transition_easing": "「元の動き」はIris/Star Iris/Shatterそれぞれの元の進み方。他は指定カーブです。",
	"pattern_seed": "同じ値で同じ割れ分布を復元します。抽選や所持装備には影響しません。",
	"ring_gap": "外側の円周方向の分割線を減らし、長いくさび形の破片を増やします。",
}

static func populate(host: VBoxContainer, settings: ComboTransitionSettings, changed: Callable) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	for group in GROUPS:
		if group[0] == "Star Irisの形" and settings.kind != 1: continue
		if group[0] == "Shatterの割れ方" and settings.kind != 2: continue
		var toggle := Button.new()
		toggle.text = "▾ " + group[0]
		toggle.toggle_mode = true
		toggle.button_pressed = true
		host.add_child(toggle)
		var body := VBoxContainer.new()
		host.add_child(body)
		toggle.toggled.connect(func(open): body.visible = open; toggle.text = ("▾ " if open else "▸ ") + group[0])
		for key in group[1]:
			if key == "glow_width" and settings.kind == 2: continue
			_field(body, settings, key, changed)

static func _field(host: VBoxContainer, settings: ComboTransitionSettings, key: String, changed: Callable) -> void:
	var label := Label.new()
	label.text = LABELS[key]
	label.tooltip_text = HELP.get(key, "変更は現在の再生位置へ反映します。保存でこの段階の制作データに残ります。")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(label)
	var value: Variant = settings.get(key)
	if value is Color:
		var picker := ColorPickerButton.new()
		picker.color = value
		picker.custom_minimum_size.y = 28
		picker.color_changed.connect(func(color): changed.call(key, color))
		host.add_child(picker)
		return
	var property: Dictionary = {}
	for info in settings.get_property_list():
		if info.name == key: property = info; break
	if value is Vector2:
		var bounds := [16.0, 640.0, 16.0, 720.0, 1.0] if key == "card_size" else [-0.5, 1.5, -0.5, 1.5, 0.01] if key in ["card_position", "card_start_position", "badge_position"] else [0.0, 1.0, 0.0, 1.0, 0.01]
		for axis in 2:
			var initial: float = value[axis]
			_number(host, initial, bounds[axis * 2], bounds[axis * 2 + 1], bounds[4], func(number):
				var vector: Vector2 = settings.get(key)
				vector[axis] = number
				changed.call(key, vector))
	elif property.hint == PROPERTY_HINT_ENUM:
		var options := OptionButton.new()
		for option in String(property.hint_string).split(","): options.add_item(option)
		options.select(value)
		options.item_selected.connect(func(index): changed.call(key, index))
		host.add_child(options)
	else:
		var bounds: PackedStringArray = String(property.hint_string).split(",")
		_number(host, float(value), float(bounds[0]), float(bounds[1]), float(bounds[2]), func(number): changed.call(key, int(number) if value is int else number))

static func _number(host: VBoxContainer, value: float, low: float, high: float, step: float, changed: Callable) -> void:
	var row := HBoxContainer.new()
	host.add_child(row)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 100
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 104
	row.add_child(spin)
	slider.value_changed.connect(func(number): spin.set_value_no_signal(number); changed.call(number))
	spin.value_changed.connect(func(number): slider.set_value_no_signal(number); changed.call(number))
