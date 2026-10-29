## 戦闘表示シーンの視覚値を、種類ごとのタブを作らず同じ画面で調整する。
extends Control

const SETTINGS_PATH := "res://data/visuals/effect_settings.tres"
const ROOT := "res://scenes/bosses"
const BODY_EFFECTS := {
	"boss/body/hydra": "res://scenes/bosses/hydra/beam_fixed_visual.tscn",
	"boss/body/draco": "res://scenes/bosses/draco/breath_visual.tscn",
	"boss/body/centaurus": "res://scenes/bosses/centaurus/power_shot_visual.tscn",
	"boss/body/canis_major": "res://scenes/bosses/canis_major/sirius_visual.tscn",
	"boss/body/monoceros": "res://scenes/bosses/monoceros/lance_visual.tscn",
	"boss/shared/tornado_shader": "res://scenes/bosses/hydra/tornado_visual.tscn",
}
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const BOSS_PREVIEW := preload("res://gyms/boss_effect_preview.gd")
const DIRECT_EFFECTS := [
	"weapon/forward", "weapon/scatter", "weapon/knockback", "weapon/contactArc",
	"weapon/barrier", "weapon/contactWave", "weapon/mines", "weapon/rear", "weapon/bipolar",
	"weapon/dashRangeDrone", "weapon/afterimage", "weapon/interceptor", "weapon/massTow",
	"weapon/sonic", "trait/vortex", "trait/critBeam", "weapon/endBlast", "weapon/flashSlash",
	"trait/killSonic", "trait/fullCharge", "trait/runUp", "trait/rampage", "trait/fullBurst", "trait/duplicator",
	"trait/quickCharge", "trait/capacity", "trait/critRate", "trait/speed", "trait/attack", "trait/pickup",
	"trait/length", "trait/glideDuration", "trait/bigSwing", "trait/multiShot",
	"boss/final_strike",
]
const ATTACK_SCENES := [
	"res://scenes/attacks/star_bolt.tscn", "res://scenes/attacks/hydra_shape.tscn",
	"res://scenes/attacks/beam_draco.tscn", "res://scenes/attacks/bolt.tscn",
	"res://scenes/attacks/light_arrow.tscn", "res://scenes/attacks/cosmic_arrow.tscn",
	"res://scenes/attacks/beam.tscn", "res://scenes/attacks/zone.tscn",
]
const ATTACK_PREVIEWS := {
	"res://scenes/attacks/star_bolt.tscn": "res://scenes/bosses/draco/star_fan_visual.tscn",
	"res://scenes/attacks/hydra_shape.tscn": "res://scenes/bosses/hydra/wind_blades_visual.tscn",
	"res://scenes/attacks/beam_draco.tscn": "res://scenes/bosses/draco/inhale_visual.tscn",
	"res://scenes/attacks/bolt.tscn": "res://scenes/bosses/draco/inhale_visual.tscn",
	"res://scenes/attacks/light_arrow.tscn": "res://scenes/bosses/centaurus/power_shot_visual.tscn",
	"res://scenes/attacks/cosmic_arrow.tscn": "res://scenes/bosses/draco/picaro_wall_visual.tscn",
	"res://scenes/attacks/beam.tscn": "res://scenes/bosses/canis_major/sirius_visual.tscn",
	"res://scenes/attacks/zone.tscn": "res://scenes/bosses/draco/picaro_wall_visual.tscn",
}
const SHADER_PALETTE_FIELDS := {
	"weapon/forward": [0, 1, 2, 3], "weapon/scatter": [0, 1, 2, 3],
	"weapon/rear": [0, 1, 2, 3], "weapon/interceptor": [0, 1, 2, 3],
	"weapon/knockback": [0, 1, 2, 3], "weapon/dashRangeDrone": [0, 1, 2, 3],
	"weapon/massTow": [0, 1, 2, 3], "weapon/bipolar": [0, 1, 2, 3],
	"weapon/mines": [0, 1, 2, 3], "weapon/endBlast": [0, 1, 2, 3],
	"weapon/barrier": [0, 1, 2], "weapon/sonic": [0, 1, 2],
	"weapon/flashSlash": [0, 2, 3], "trait/vortex": [0, 2],
	"trait/killSonic": [0, 2], "trait/duplicator": [0, 1, 2],
}
const VISUAL_FIELDS := [
	"pixel_size", "warning_color", "locked_color", "attack_color", "recovery_color",
	"hit_color", "line_width", "flash_duration", "base_color", "progress_color",
	"outline_color", "outline_width", "flight_scale", "burst_pixel_scale",
]
const NUMBER_LIMITS := {
	"pixel_size": [1.0, 8.0, 0.25], "line_width": [0.5, 12.0, 0.25],
	"outline_width": [0.5, 12.0, 0.25], "flash_duration": [0.05, 2.0, 0.05],
	"burst_pixel_scale": [0.5, 3.0, 0.05],
}
const DIRECT_FIELDS := {
	"weapon/dashRangeDrone": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"weapon/massTow": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"weapon/contactWave": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["ゆがみの強さ", "distortion_strength", 0.0, 2.0, 0.05, 1.0],
	],
	"weapon/barrier": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"trait/duplicator": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"trait/fullBurst": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"trait/rampage": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"trait/runUp": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"trait/fullCharge": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"weapon/flashSlash": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"weapon/endBlast": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
	],
	"weapon/forward": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["弾の長さ", "shot_length_scale", 0.25, 4.0, 0.05, 1.0],
		["弾の太さ", "shot_width_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"weapon/scatter": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["弾の長さ", "shot_length_scale", 0.25, 4.0, 0.05, 1.0],
		["弾の太さ", "shot_width_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"weapon/rear": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["弾の長さ", "shot_length_scale", 0.25, 4.0, 0.05, 1.0],
		["弾の太さ", "shot_width_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"weapon/interceptor": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["弾の長さ", "shot_length_scale", 0.25, 4.0, 0.05, 1.0],
		["弾の太さ", "shot_width_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"weapon/knockback": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["弾の長さ", "shot_length_scale", 0.25, 4.0, 0.05, 1.0],
		["弾の太さ", "shot_width_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"weapon/contactArc": [
		["雷のドット倍率", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["雷の表示秒数", "visible_seconds", 0.05, 1.0, 0.01, 0.22],
	],
	"weapon/bipolar": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["ビームの芯", "beam_core_ratio", 0.05, 1.0, 0.05, 0.3],
		["輪の線幅", "ring_width_scale", 0.25, 4.0, 0.05, 1.0],
		["残光の時間", "visible_time_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"weapon/sonic": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["航跡の長さ", "wake_length", 20.0, 300.0, 1.0, 150.0],
		["航跡の幅", "wake_width", 2.0, 40.0, 0.5, 18.0],
		["航跡の余韻", "wake_fade_seconds", 0.05, 0.5, 0.01, 0.20],
		["航跡の透明度", "wake_opacity", 0.0, 1.0, 0.01, 0.55],
		["航跡シェーダの筋", "wake_filaments", 0.0, 2.0, 0.05, 0.7],
	],
	"trait/killSonic": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"boss/body/hydra": [
		["予告線の太さ", "line_width", 1.0, 12.0, 0.25, 3.0],
		["閃光の秒数", "flash_duration", 0.05, 2.0, 0.05, 0.25],
		["爆発シェーダのドット", "burst_pixel_scale", 0.5, 3.0, 0.05, 1.0],
	],
	"trait/critBeam": [
		["槍シェーダのドット", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
	],
	"boss/body/draco": [
		["胸の光の大きさ", "core_glow_radius", 8.0, 100.0, 1.0, 43.0],
		["胸の光の透明度", "core_glow_opacity", 0.0, 1.0, 0.01, 0.16],
	],
	"boss/body/centaurus": [
		["帆の星の大きさ", "sail_star_scale", 0.25, 3.0, 0.05, 1.0],
	],
	"boss/body/canis_major": [
		["シリウスの輝き", "sirius_glow_scale", 0.25, 3.0, 0.05, 1.0],
	],
	"boss/body/monoceros": [
		["推進炎の長さ", "booster_length_scale", 0.25, 3.0, 0.05, 1.0],
	],
	"boss/shared/tornado_shader": [
		["渦シェーダのドット", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
	],
	"weapon/mines": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"trait/vortex": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["ゆがみの強さ", "distortion_strength", 0.0, 2.0, 0.05, 1.0],
	],
	"weapon/afterimage": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
		["粒の数", "particle_count_scale", 0.0, 3.0, 0.05, 1.0],
		["分身の透明度", "body_opacity", 0.0, 1.0, 0.01, 0.85],
	],
	"res://scenes/attacks/hydra_shape.tscn": [
		["ドット倍率", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
	],
	"res://scenes/attacks/beam_draco.tscn": [
		["ドット倍率", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
	],
}
const DIRECT_COLOR_FIELDS := {
	"weapon/sonic": [["航跡シェーダの色", "wake_color", Color(0.25, 0.65, 1.0)]],
	"boss/body/hydra": [["予告色", "warning_color", Color("#ffd16c")], ["攻撃色", "attack_color", Color("#ff765c")]],
	"boss/body/draco": [["胸の光色", "core_glow_color", Color(0.38, 0.59, 1.0)], ["裂け目の色", "rift_color", Color("#5a4d91")]],
	"boss/body/centaurus": [["帆の星色", "sail_star_color", Color("#fff6c8")], ["開放の輪色", "open_color", Color("#9fe8ff")]],
	"boss/body/canis_major": [["シリウス色", "sirius_color", Color("#e8f6ff")], ["光の暈色", "sirius_halo_color", Color("#9fe8ff")]],
	"boss/body/monoceros": [["推進炎の芯色", "booster_core_color", Color("#e0fbff")]],
	"boss/shared/tornado_shader": [["渦シェーダの色", "vortex_tint", Color.WHITE]],
}

var preview_host: Control
var controls_host: Control
var _working: Resource
var _source_hash := ""
var _dirty := false
var _message := ""
var _paths: Array[String] = []
var _selected := ""
var _picker := OptionButton.new()
var _fields := VBoxContainer.new()
var _sample: Node2D
var _viewport: SubViewport
var _swatch := ColorRect.new()
var _static_container: SubViewportContainer
var _boss_preview

func _ready() -> void:
	_collect(ROOT)
	_paths.append_array(DIRECT_EFFECTS)
	_paths.append_array(ATTACK_SCENES)
	_paths.append_array(BODY_EFFECTS.keys())
	_paths.sort()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(controls_host if controls_host != null else self).add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(_picker)
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for path in _paths:
		_picker.add_item(_effect_label(path))
	_picker.item_selected.connect(func(index: int): _select(_paths[index]))
	body.add_child(_fields)
	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(preview_host if preview_host != null else self).add_child(preview)
	var note := Label.new()
	note.text = "武器・特性・ボス技と共通攻撃を本番描画で試遊します。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_child(note)
	_static_container = SubViewportContainer.new()
	_static_container.stretch = true
	_static_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(_static_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(480, 480)
	_viewport.disable_3d = true
	_static_container.add_child(_viewport)
	var background := ColorRect.new()
	background.color = Color("#10141e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(background)
	_swatch.position = Vector2(168, 168)
	_swatch.size = Vector2(144, 144)
	_viewport.add_child(_swatch)
	_boss_preview = BOSS_PREVIEW.new()
	_boss_preview.visible = false
	preview.add_child(_boss_preview)
	reload_current()
	if _working == null: return
	if not _paths.is_empty(): _select(_paths[0])

func _effect_label(path: String) -> String:
	if path.begins_with("weapon/") or path.begins_with("trait/"):
		var category := &"weapons" if path.begins_with("weapon/") else &"traits"
		for entry in ContentManager.catalog.table(category).values():
			if String(entry.code_id) == path.get_slice("/",1):
				return ("武器：" if category == &"weapons" else "特性：") + entry.get_display_name()
	return path.trim_prefix(ROOT+"/").trim_suffix("_visual.tscn")

func _collect(folder: String) -> void:
	for filename in DirAccess.get_files_at(folder):
		if filename.ends_with("_visual.tscn"):
			_paths.append(folder.path_join(filename))
	for directory in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(directory))

func _select(path: String) -> void:
	_selected = path
	_picker.select(_paths.find(path))
	if is_instance_valid(_sample): _sample.queue_free()
	_sample = null
	var boss_effect := path.begins_with(ROOT + "/") or BODY_EFFECTS.has(path) or ATTACK_PREVIEWS.has(path)
	var live_effect := boss_effect or path == "boss/final_strike" or path.begins_with("weapon/") or path.begins_with("trait/")
	_static_container.visible = not live_effect
	_boss_preview.visible = live_effect
	_boss_preview.set_active(live_effect)
	if path.begins_with("res://"):
		var scene := load(path) as PackedScene
		_sample = scene.instantiate() as Node2D
		if not boss_effect:
			var base_modulate := _sample.modulate
			_sample.position = Vector2(240, 240)
			_viewport.add_child(_sample)
			_sample.set_meta("visual_base_modulate", base_modulate)
	_swatch.visible = _sample == null
	_build_fields()
	if boss_effect and is_instance_valid(_sample):
		_sample.free()
		_sample = null
	_apply_preview()
	var preview_path := String(ATTACK_PREVIEWS.get(path, BODY_EFFECTS.get(path, path))) if boss_effect else (path if live_effect else "")
	_boss_preview.set_effect(preview_path)

func _build_fields() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	if _selected in preload("res://gyms/equipment_effect_scenario.gd").PASSIVE_KEYS:
		var note := Label.new()
		note.text = "数値の変化を、効き先の射撃・移動・回収と一緒に再生します。"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fields.add_child(note)
		return
	if not BODY_EFFECTS.has(_selected): _add_color("色・明るさ倍率", "effect_tint", Color.WHITE)
	for field in DIRECT_FIELDS.get(_selected, []):
		_add_number(field[0], field[1], field[5], "%s,%s,%s" % [field[2], field[3], field[4]])
	for field in DIRECT_COLOR_FIELDS.get(_selected, []):
		_add_color(field[0], field[1], field[2])
	for channel in SHADER_PALETTE_FIELDS.get(_selected, []):
		_add_color("シェーダ色 " + str(channel), "shader_c" + str(channel), Color.WHITE)
	if not is_instance_valid(_sample): return
	for info in _sample.get_property_list():
		var name: String = info.name
		if name not in VISUAL_FIELDS: continue
		if name == "flight_scale" and _selected != "res://scenes/attacks/star_bolt.tscn": continue
		if not (info.usage & PROPERTY_USAGE_EDITOR): continue
		if info.type == TYPE_COLOR:
			_add_color(name, name, _sample.get(name))
		elif info.type == TYPE_FLOAT:
			_add_number(name, name, _sample.get(name), info.hint_string)

func _value(name: String, fallback: Variant) -> Variant:
	return (_working.profiles.get(_selected, {}) as Dictionary).get(name, fallback)

func _set_value(name: String, value: Variant) -> void:
	var values: Dictionary = _working.profiles.get(_selected, {}).duplicate()
	values[name] = value
	_working.profiles[_selected] = values
	_dirty = true
	_message = "未保存: " + _selected
	_apply_preview()
	if _selected.begins_with(ROOT + "/") or BODY_EFFECTS.has(_selected) or ATTACK_PREVIEWS.has(_selected) or _selected == "boss/final_strike" or _selected.begins_with("weapon/") or _selected.begins_with("trait/"):
		_boss_preview.refresh_effects()

func _add_color(label: String, name: String, original: Color) -> void:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var picker := ColorPickerButton.new()
	picker.color = _value(name, original)
	picker.color_changed.connect(func(color: Color): _set_value(name, color))
	row.add_child(picker)

func _add_number(label: String, name: String, original: float, hint: String) -> void:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var spin := SpinBox.new()
	var parts := hint.split(",")
	var limits: Array = NUMBER_LIMITS.get(name, [0.0, maxf(100.0, original * 4.0), 0.05])
	spin.min_value = float(parts[0]) if parts.size() > 0 and parts[0].is_valid_float() else limits[0]
	spin.max_value = float(parts[1]) if parts.size() > 1 and parts[1].is_valid_float() else limits[1]
	spin.step = float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else limits[2]
	spin.value = _value(name, original)
	spin.value_changed.connect(func(value: float): _set_value(name, value))
	row.add_child(spin)

func _apply_preview() -> void:
	_swatch.color = _value("effect_tint", Color.WHITE)
	if _selected.begins_with(ROOT + "/") or BODY_EFFECTS.has(_selected) or ATTACK_PREVIEWS.has(_selected) or _selected == "boss/final_strike" or _selected.begins_with("weapon/") or _selected.begins_with("trait/"):
		EFFECT_SETTINGS.set_preview_profiles(_working.profiles)
	if not is_instance_valid(_sample): return
	_sample.modulate = Color.WHITE
	_working.apply_to(_sample)
	_sample.queue_redraw()

func editing_state() -> Dictionary:
	var paths: Array[String] = []
	if _dirty: paths.append(SETTINGS_PATH)
	return {"path": SETTINGS_PATH, "dirty_paths": paths, "busy": false, "message": _message}

func save_current() -> void:
	if FileAccess.get_md5(SETTINGS_PATH) != _source_hash:
		_message = "保存先が外部で変更されました。再読込してください。"
		return
	var error := ResourceSaver.save(_working.duplicate(true), SETTINGS_PATH)
	if error != OK:
		_message = "保存失敗: " + error_string(error)
		return
	_source_hash = FileAccess.get_md5(SETTINGS_PATH)
	_dirty = false
	_message = "保存しました: " + SETTINGS_PATH

func reload_current() -> void:
	var loaded := ResourceLoader.load(SETTINGS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null:
		_message = "設定を読み込めません: " + SETTINGS_PATH
		return
	_working = loaded.duplicate(true)
	_source_hash = FileAccess.get_md5(SETTINGS_PATH)
	_dirty = false
	_message = "保存値を読み込みました"
	if not _selected.is_empty(): _select(_selected)

func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	var live_effect := _selected.begins_with(ROOT + "/") or BODY_EFFECTS.has(_selected) or ATTACK_PREVIEWS.has(_selected) or _selected == "boss/final_strike" or _selected.begins_with("weapon/") or _selected.begins_with("trait/")
	if is_instance_valid(_boss_preview): _boss_preview.set_active(active and live_effect)
	if not active: EFFECT_SETTINGS.clear_preview_profiles()
	elif _working != null and live_effect: EFFECT_SETTINGS.set_preview_profiles(_working.profiles)
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	EFFECT_SETTINGS.clear_preview_profiles()
