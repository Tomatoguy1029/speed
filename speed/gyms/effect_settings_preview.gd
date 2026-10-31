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
const MODULE_ICONS := preload("res://scripts/ui/module_icons.gd")
const COMPONENTS := preload("res://scripts/render/fx/visual_effect_components.gd")
const ENEMY_EFFECTS := {
	"enemy/phoenix": {"title": "ほうおう座 · 着地の炎", "scene": ""},
	"enemy/aquila": {"title": "わし座 · 進路の雷撃", "scene": "res://scenes/attacks/zone_aquila.tscn"},
}
const BOOST_GAUGE := preload("res://scripts/ui/boost_gauge_visual.gd")
const TARGET_GROUPS := ["武器", "特性", "ボス本体", "ボス技", "敵の技", "HUD"]
const DIRECT_EFFECTS := [
	"weapon/forward", "weapon/scatter", "weapon/knockback", "weapon/contactArc",
	"weapon/barrier", "weapon/contactWave", "weapon/mines", "weapon/rear", "weapon/bipolar",
	"weapon/dashRangeDrone", "weapon/afterimage", "weapon/interceptor", "weapon/massTow",
	"weapon/sonic", "trait/vortex", "trait/critBeam", "weapon/endBlast", "weapon/flashSlash",
	"trait/killSonic", "trait/fullCharge", "trait/runUp", "trait/rampage", "trait/fullBurst", "trait/duplicator",
	"trait/quickCharge", "trait/capacity", "trait/critRate", "trait/speed", "trait/attack", "trait/pickup",
	"trait/length", "trait/glideDuration", "trait/bigSwing", "trait/multiShot",
	"boss/final_strike", BOOST_GAUGE.KEY,
]
const BOMBER_PREVIEW := "res://scenes/attacks/zone_bomber.tscn"
const ATTACK_LABELS := {
	BOMBER_PREVIEW: ["自爆する雑魚 · 自爆の爆発", "自爆する雑魚専用のピクセル炎。色・形・ノイズ・崩れ方を調整します。"],
}
const VISUAL_FIELDS := [
	"pixel_size", "warning_color", "locked_color", "attack_color", "recovery_color",
	"hit_color", "line_width", "flash_duration", "base_color", "progress_color",
	"outline_color", "outline_width", "flight_scale", "burst_pixel_scale",
	"body_radius_scale", "head_radius", "pulse_scale",
	"telegraph_line_width", "active_line_width", "telegraph_fill_opacity", "telegraph_progress_opacity", "telegraph_edge_opacity", "motion_trail_opacity", "impact_lifetime", "collapse_lifetime", "warning_opacity", "attack_opacity",
	"gather_rate", "gather_lifetime", "shard_count", "shard_speed_scale", "beam_width_scale", "streak_count", "streak_length_scale", "needle_width_scale", "streak_lifetime_scale", "wave_width_scale", "ring_width", "ring_lifetime", "ring_end_radius", "locked_line_width", "jet_radius_scale", "jet_opacity",
]
const NUMBER_LIMITS := {
	"pixel_size": [1.0, 8.0, 0.25], "line_width": [0.5, 12.0, 0.25],
	"outline_width": [0.5, 12.0, 0.25], "flash_duration": [0.05, 2.0, 0.05],
	"burst_pixel_scale": [0.5, 3.0, 0.05],
}
const DIRECT_FIELDS := {
	BOOST_GAUGE.KEY: [
		["1周目：内側の半径（px）", "first_inner_radius", 0.0, 127.5, 0.25, BOOST_GAUGE.DEFAULT_RADII.first_inner_radius],
		["1周目：外側の半径（px）", "first_outer_radius", 0.5, 128.0, 0.25, BOOST_GAUGE.DEFAULT_RADII.first_outer_radius],
		["2周目：内側の半径（px）", "second_inner_radius", 0.0, 127.5, 0.25, BOOST_GAUGE.DEFAULT_RADII.second_inner_radius],
		["2周目：外側の半径（px）", "second_outer_radius", 0.5, 128.0, 0.25, BOOST_GAUGE.DEFAULT_RADII.second_outer_radius],
		["目盛り線の太さ（1周目の幅の半分が上限）", "tick_width", 0.5, 6.0, 0.25, BOOST_GAUGE.DEFAULT_WIDTHS.tick_width],
	],
	BOMBER_PREVIEW: [
		["炎の表示（秒）", "visible_seconds", 0.05, 2.0, 0.01, 0.65],
		["ドット幅（倍）", "pixel_scale", 0.5, 4.0, 0.05, 1.0],
		["描画サイズ（倍）", "effect_scale", 0.25, 3.0, 0.05, 0.8333333333333333],
	],
	"res://scenes/bosses/canis_major/nova_visual.tscn": [
		["溜めの光芒の長さ", "warning_ray_length", 20.0, 180.0, 1.0, 100.0],
		["溜めの光芒の太さ", "warning_ray_width", 1.0, 12.0, 0.5, 4.0],
		["周囲を照らす強さ", "warning_glow_opacity", 0.0, 0.2, 0.01, 0.06],
		["光の輪の暈の倍率", "ring_halo_scale", 1.0, 6.0, 0.1, 1.6],
		["光の輪の暗い縁の太さ", "ring_outline_width", 0.0, 8.0, 0.5, 3.0],
		["光の輪の白い芯の太さ", "ring_core_width", 1.0, 12.0, 0.5, 8.0],
		["画面が白む強さ", "flash_opacity", 0.0, 0.8, 0.01, 0.12],
		["画面が白む時間", "flash_duration", 0.02, 0.3, 0.01, 0.08],
	],
	"trait/rampage": [
		["演出の大きさ", "effect_scale", 0.25, 4.0, 0.05, 1.0],
		["ドットの大きさ", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["演出の時間", "duration_scale", 0.25, 4.0, 0.05, 1.0],
	],
	"weapon/contactArc": [
		["雷のドット倍率", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["雷の表示秒数", "visible_seconds", 0.05, 1.0, 0.01, 0.22],
	],
	"weapon/sonic": [
		["航跡の長さ", "wake_length", 20.0, 300.0, 1.0, 150.0],
		["航跡の幅", "wake_width", 2.0, 40.0, 0.5, 18.0],
		["航跡の余韻", "wake_fade_seconds", 0.05, 0.5, 0.01, 0.20],
		["航跡の透明度", "wake_opacity", 0.0, 1.0, 0.01, 0.55],
		["航跡シェーダの筋", "wake_filaments", 0.0, 2.0, 0.05, 0.7],
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
	"boss/move/draco/inhale": [
		["ドット倍率", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
		["消える間の薄まり（秒）", "fade_seconds", 0.02, 0.5, 0.01, 0.15],
	],
}
const DIRECT_COLOR_FIELDS := {
	BOOST_GAUGE.KEY: [
		["通常（25%以上）", "normal_color", BOOST_GAUGE.DEFAULT_COLORS.normal_color],
		["不足（25%未満）", "unavailable_color", BOOST_GAUGE.DEFAULT_COLORS.unavailable_color],
		["経路描画中", "path_color", BOOST_GAUGE.DEFAULT_COLORS.path_color],
		["使用可能時の波紋（通常色と独立）", "ready_pulse_color", BOOST_GAUGE.DEFAULT_COLORS.ready_pulse_color],
		["下地", "background_color", BOOST_GAUGE.DEFAULT_COLORS.background_color],
		["目盛り：使用可能", "ready_tick_color", BOOST_GAUGE.DEFAULT_COLORS.ready_tick_color],
		["目盛り：不足", "unavailable_tick_color", BOOST_GAUGE.DEFAULT_COLORS.unavailable_tick_color],
		["満タン時のフラッシュ", "full_flash_color", BOOST_GAUGE.DEFAULT_COLORS.full_flash_color],
	],
	"weapon/sonic": [["航跡シェーダの色", "wake_color", Color(0.25, 0.65, 1.0)]],
	"boss/body/hydra": [["予告色", "warning_color", Color("#ffd16c")], ["攻撃色", "attack_color", Color("#ff765c")]],
	"boss/body/draco": [["胸の光色", "core_glow_color", Color(0.38, 0.59, 1.0)], ["裂け目の色", "rift_color", Color("#5a4d91")]],
	"boss/body/centaurus": [["帆の星色", "sail_star_color", Color("#fff6c8")], ["開放の輪色", "open_color", Color("#9fe8ff")]],
	"boss/body/canis_major": [["シリウス色", "sirius_color", Color("#e8f6ff")], ["光の暈色", "sirius_halo_color", Color("#9fe8ff")]],
	"boss/body/monoceros": [["推進炎の芯色", "booster_core_color", Color("#e0fbff")]],
	"boss/shared/tornado_shader": [["渦シェーダの色", "vortex_tint", Color.WHITE]],
}
const FIELD_LABELS := {
	"effect_tint": "全体色", "effect_scale": "描画サイズ（倍）", "pixel_scale": "ドット幅（倍）",
	"duration_scale": "残光時間（倍）", "particle_count_scale": "発生粒数（倍）",
	"shot_length_scale": "弾の長さ（倍）", "shot_width_scale": "弾の太さ（倍）",
	"beam_core_ratio": "ビーム芯の割合", "ring_width_scale": "輪の太さ（倍）",
	"visible_time_scale": "輪の残光（倍）", "visible_seconds": "稲妻の表示（秒）",
	"distortion_strength": "空間のゆがみ（倍）", "body_opacity": "分身の不透明度",
	"wake_length": "航跡の長さ（px）", "wake_width": "航跡の半幅（px）",
	"wake_fade_seconds": "航跡の消失（秒）", "wake_opacity": "航跡の不透明度",
	"wake_filaments": "航跡の筋の密度", "wake_color": "航跡の色",
	"pixel_size": "描画ドット幅（px）", "line_width": "予告線の幅（px）",
	"flash_duration": "閃光の時間（秒）", "burst_pixel_scale": "爆発ドット幅（倍）",
	"core_glow_radius": "胸の光の半径（px）", "core_glow_opacity": "胸の光の不透明度",
	"sail_star_scale": "帆の星の大きさ（倍）", "sirius_glow_scale": "シリウスの光の広さ（倍）",
	"booster_length_scale": "推進炎の長さ（倍）", "flight_scale": "飛翔中の大きさ（倍）",
	"warning_color": "予告色", "locked_color": "照準固定色", "attack_color": "攻撃色",
	"recovery_color": "回復色", "hit_color": "命中色", "base_color": "本体色",
	"progress_color": "進行色", "outline_color": "輪郭色", "outline_width": "輪郭幅（px）",
	"core_glow_color": "胸の光色", "rift_color": "裂け目の色", "sail_star_color": "帆の星色",
	"open_color": "開放の輪色", "sirius_color": "シリウス色", "sirius_halo_color": "光の暈色",
	"booster_core_color": "推進炎の芯色", "vortex_tint": "渦の色",
	"body_radius_scale": "胴体の表示倍率", "head_radius": "頭の表示半径（px）", "pulse_scale": "光芒の広がり（倍）",
	"glow_opacity": "円内の光の不透明度", "ring_opacity": "輪郭の不透明度", "ring_width": "輪郭の太さ（px）",
	"arm_count": "稲妻の本数", "lightning_reach": "稲妻の長さ（半径比）", "lightning_width": "稲妻の太さ（px）",
	"telegraph_line_width": "予告線の太さ（px）",
	"active_line_width": "攻撃線の太さ（px）",
	"telegraph_fill_opacity": "予告面の濃さ",
	"telegraph_progress_opacity": "進行する予告面の濃さ",
	"telegraph_edge_opacity": "予告の縁の濃さ",
	"motion_trail_opacity": "移動の軌跡の濃さ",
	"impact_lifetime": "着弾の余韻（秒）",
	"collapse_lifetime": "崩壊の余韻（秒）",
	"warning_opacity": "予告面の濃さ",
	"attack_opacity": "攻撃面の濃さ",
	"gather_rate": "集まる光粒の数（毎秒）",
	"gather_lifetime": "集まる光粒の寿命（秒）",
	"shard_count": "砕ける光片の数",
	"shard_speed_scale": "光片の広がる速さ（倍）",
	"beam_width_scale": "槍の表示幅（倍）",
	"streak_count": "斬撃の光筋の数",
	"streak_length_scale": "光筋の長さ（倍）",
	"needle_width_scale": "光筋の太さ（倍）",
	"streak_lifetime_scale": "光筋の余韻（倍）",
	"wave_width_scale": "衝撃波の表示幅（倍）",
	"ring_width": "光の輪の太さ（px）",
	"ring_lifetime": "光の輪の寿命（秒）",
	"ring_end_radius": "光の輪の最終半径（px）",
	"locked_line_width": "固定した照準の太さ（px）",
	"jet_radius_scale": "逆噴射の光の大きさ（倍）",
	"jet_opacity": "逆噴射の光の濃さ",
}
const FIELD_HELP := {
	"effect_tint": "描画結果の色に掛ける値。白で元の色。",
	"effect_scale": "シェーダ面・粒の大きさと粒の移動距離に掛ける倍率。判定範囲は変えない。",
	"pixel_scale": "エフェクトの1ドットの表示幅に掛ける倍率。",
	"duration_scale": "シェーダと粒の表示時間に掛ける倍率。攻撃判定の時間は変えない。",
	"particle_count_scale": "次の発生時に作る粒の数に掛ける倍率。現在の停止フレームの粒数は維持する。",
	"shot_length_scale": "飛行中の弾シェーダの長さに掛ける倍率。判定は変えない。",
	"shot_width_scale": "飛行中の弾シェーダの太さに掛ける倍率。判定は変えない。",
	"beam_core_ratio": "ビームの表示幅に占める明るい芯の割合。",
	"ring_width_scale": "表示する輪の線幅に掛ける倍率。",
	"visible_time_scale": "ビーム後の輪が画面に残る時間の倍率。判定時間は変えない。",
	"visible_seconds": "接触雷が画面に残る秒数。判定時間は変えない。",
	"distortion_strength": "シェーダで背景をずらす量の倍率。",
	"body_opacity": "残像として描く機体の不透明度。0で透明、1で不透明。",
	"wake_length": "機体の後ろへ残す航跡の最大長。画面上のピクセル数。",
	"wake_width": "航跡の中心から片側の幅。画面上のピクセル数。",
	"wake_fade_seconds": "航跡が消えるまでの秒数。",
	"wake_opacity": "航跡の濃さ。0で透明、1で不透明。",
	"core_glow_radius": "りゅう座の胸の光が広がる半径。画面上のピクセル数。",
	"core_glow_opacity": "りゅう座の胸の光の透明度。",
	"wake_color": "機体後方へ残る航跡の色。",
	"wake_filaments": "航跡シェーダの細い筋の寄与。大きいほど筋が目立つ。",
	"pixel_size": "攻撃描画の1ドットの幅。画面上のピクセル数。",
	"line_width": "うみへび座の攻撃前に出る予告線の表示幅。",
	"flash_duration": "うみへび座の攻撃時の閃光が残る秒数。",
	"burst_pixel_scale": "うみへび座の爆発シェーダの1ドット幅の倍率。",
	"sail_star_scale": "ケンタウルス座の帆に付く星の描画サイズの倍率。",
	"sirius_glow_scale": "おおいぬ座のシリウス周囲の輝きの広さの倍率。",
	"booster_length_scale": "いっかくじゅう座の推進炎の表示長の倍率。",
	"flight_scale": "飛翔中の星弾の描画サイズの倍率。",
	"outline_width": "攻撃表示の輪郭線の幅。画面上のピクセル数。",
	"warning_color": "攻撃前の予告を描く色。",
	"locked_color": "照準が固定されたときの表示色。",
	"attack_color": "攻撃中の表示色。",
	"recovery_color": "攻撃後の回復状態を描く色。",
	"hit_color": "命中時の表示色。",
	"base_color": "効果の本体を描く色。",
	"progress_color": "効果の進行部分を描く色。",
	"outline_color": "効果の輪郭を描く色。",
	"core_glow_color": "りゅう座の胸の光色。",
	"rift_color": "りゅう座の裂け目の表示色。",
	"sail_star_color": "ケンタウルス座の帆の星色。",
	"open_color": "ケンタウルス座の開放時に出る輪の色。",
	"sirius_color": "シリウス本体の輝きの色。",
	"sirius_halo_color": "シリウス周囲の暈の色。",
	"booster_core_color": "いっかくじゅう座の推進炎の芯の色。",
	"vortex_tint": "共有渦シェーダの色に掛ける値。",
}
## shader の調整値（ShaderTuning の tuning の組）の表示名と説明。uniform 名で引く
const SHADER_LABELS := {
	"c0": ["炎の芯の色", "炎の一番明るい部分の色。"], "c1": ["炎の明るい色", "芯の外側の色。"],
	"c2": ["炎の中間色", "炎の本体の色。"], "c3": ["炎の外側の色", "一番外の市松で透ける部分の色。"],
	"noise_scale": ["炎の模様の細かさ", "縁を崩すノイズの細かさ。大きいほど細かく崩れる。"],
	"roughness": ["炎の縁の崩れ", "ノイズで縁が崩れる強さ。0で丸い炎。"],
	"burn_speed": ["炎の燃え尽きる速さ", "時間とともに炎が細る速さ。大きいほど早く消える。"],
	"start_size": ["炎の出始めの大きさ", "爆発の瞬間の大きさ（最大に対する割合）。"],
	"flash_boost": ["炎の最初の閃き", "爆発の最初の一瞬だけ明るく大きくする量。"],
	"outer_dither": ["外炎の市松の強さ", "0で半透明の連続した外炎、1で市松の間引き。中間値では両方を混ぜます。"],
	"core_color": ["帯の芯の色", "ビームの中心の色。"], "mid_color": ["帯の色", "ビームの本体の色。"],
	"edge_color": ["帯の縁の色", "ビームの縁（市松）とねじれの影の色。"], "helix_color": ["ねじれの光の色", "帯の中を走る明るい光の色。"],
	"core_ratio": ["芯の太さ", "帯の幅に占める芯の割合。"], "mid_ratio": ["帯の本体の太さ", "帯の幅に占める本体の割合。残りが縁。"],
	"wobble": ["帯の波打ち", "帯の幅が波打つ大きさ。"], "wobble_speed": ["帯の波打つ速さ", "波打ちが流れる速さ。"],
	"helix_width": ["ねじれの幅", "2本の光がねじれる幅（帯の幅に対する割合）。"], "helix_speed": ["ねじれの速さ", "ねじれの光が流れる速さ。"],
	"dim_color": ["沈める色", "引き込みの瞬間に周りを沈める色。"], "glow_color": ["暗黒の光の色", "引き込みの瞬間に中心から広がる光の色。"],
	"lens_return": ["レンズの戻り始め", "光を曲げる範囲のうち、元の見え方へ戻り始める位置（割合）。"],
	"band_cells": ["歪みの帯の幅", "空間が歪む帯の片側の幅（ドット）。"], "brighten": ["帯の外側の明るさ", "歪みの帯の外側を明るくする量。"],
	"darken": ["帯の内側の暗さ", "歪みの帯の内側を暗くする量。"], "highlight": ["帯の外側に足す光", "歪みの帯の外側に足す光の色。"],
	"silver_rim": ["銀の縁の色", "弱いときのオーラの縁の色。"], "silver_mid": ["銀の中の色", "弱いときのオーラの中ほどの色。"], "silver_outer": ["銀の外の色", "弱いときのオーラの外側（市松）の色。"],
	"blue_rim": ["青の縁の色", "中くらいのときのオーラの縁の色。"], "blue_mid": ["青の中の色", "中くらいのときのオーラの中ほどの色。"], "blue_outer": ["青の外の色", "中くらいのときのオーラの外側の色。"],
	"gold_rim": ["金の縁の色", "最大のときのオーラの縁の色。"], "gold_mid": ["金の中の色", "最大のときのオーラの中ほどの色。"], "gold_outer": ["金の外の色", "最大のときのオーラの外側の色。"],
	"flicker_speed": ["揺らめきの速さ", "オーラの模様が流れる速さ。"], "rise": ["上へ伸びる強さ", "オーラが機体の後ろへ伸びる強さ。"],
	"pale_mix": ["光の筋の白さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"core_emission": ["芯の発光倍率", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"spark_emission": ["光の筋の発光倍率", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"rim_opacity": ["光線本体の濃さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"haze_opacity": ["光線の揺れる縁の濃さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"width_wobble": ["光線の幅の揺れ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"width_frequency": ["光線の幅のノイズ密度", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"width_speed": ["光線の幅の流速", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"haze_width": ["揺れる縁の広がり", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"haze_noise_x": ["縁ノイズの長手方向の密度", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"haze_noise_y": ["縁ノイズの横方向の密度", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"haze_speed": ["縁ノイズの流速", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"haze_threshold": ["縁が光るしきい値", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"streak_noise_x": ["光の筋の長手方向の密度", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"streak_noise_y": ["光の筋の横方向の密度", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"streak_speed": ["光の筋の流速", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"streak_threshold": ["光の筋のしきい値", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"orb_reach": ["口元の光の広がり", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"orb_start": ["口元の光の初期サイズ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"orb_growth": ["口元の光の成長幅", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"orb_core_ratio": ["口元の芯の太さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"orb_mid_ratio": ["口元の内側の太さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"orb_ring_shrink": ["口元の輪が縮む割合", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"orb_spark_speed": ["口元の粒の流速", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"arrow_color": ["矢の色", "光の矢の表示色。"],
	"orb_spark_threshold": ["口元の粒のしきい値", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"spokes": ["光条の密度", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ring_start": ["光の輪の初期半径比", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ring_growth": ["光の輪の広がり", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ring_noise": ["輪のノイズの強さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ring_thickness": ["光の輪の太さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ring_thickness_start": ["輪の出始めの太さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"inner_size": ["中央の閃光の大きさ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ray_threshold": ["光条のしきい値", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ray_reach": ["光条の長さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ray_thickness": ["光条の太さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"chip_threshold": ["飛び散る破片のしきい値", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"chip_density": ["破片の密度", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ring_opacity": ["光の輪の濃さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"ray_opacity": ["光条の濃さ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"brightness": ["光全体の明るさ", "表示だけを調整します。攻撃の判定・時間・範囲は維持します。"],
	"grain_speed": ["ノイズが切り替わる速さ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"flow_frequency": ["流れる模様の密度", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"flow_speed": ["模様の流速", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"edge_noise": ["縁ノイズの強さ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"core_wobble": ["芯の太さの揺れ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"spark_threshold": ["火花のしきい値", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"wind_spacing": ["風の筋の間隔", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"wind_speed": ["風の筋の流速", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"wind_sharpness": ["風の筋の鋭さ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"lightning_jitter": ["雷の揺れ幅", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"lightning_thickness": ["雷の主幹の太さ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"branch_threshold": ["雷の枝分かれのしきい値", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"visual_opacity": ["全体の不透明度", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"visual_brightness": ["全体の明るさ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"branch_count": ["雷の枝の数", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"branch_sharpness": ["雷の枝の鋭さ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"halo_sharpness": ["雷の暈の細さ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"noise_density": ["ノイズの密度", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"center_ratio": ["中央の光の大きさ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"circuit_speed": ["同心模様の流速", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"circuit_width": ["同心模様の太さ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"spiral_turns": ["渦の筋の数", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"spiral_frequency": ["渦の半径方向の密度", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"spiral_speed": ["渦の回る速さ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"wake_turns": ["後流の筋の数", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"wake_frequency": ["後流の模様の密度", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"wake_speed": ["後流の流速", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"band_threshold": ["渦の太い筋のしきい値", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"thread_threshold": ["渦の細い筋のしきい値", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"grit_size": ["渦の粒模様の大きさ", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"cloud_frequency": ["雲模様の密度", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
	"cloud_speed": ["雲模様の流速", "表示だけを調整します。判定・攻撃時間・移動速度は維持します。"],
}
const GROUP_ORDER := ["色", "形・大きさ", "動き・時間", "粒子", "シェーダ", "品質・負荷"]

var preview_host: Control
var controls_host: Control
var _working: Resource
var _source_hash := ""
var _dirty := false
var _message := ""
var _paths: Array[String] = []
var _selected := ""
var _target_group := "武器"
var _group_buttons := {}
var _target_buttons := {}
var _target_list := VBoxContainer.new()
var _boss_sections: Array[Dictionary] = []
var _technique_names := {}
var _move_targets: Dictionary = {}
var _move_order: Dictionary = {}
var _expanded_bosses := {}
var _editing_label := Label.new()
var _fields := VBoxContainer.new()
var _boost_boundary_inputs: Dictionary = {}
var _sample: Node2D
var _standalone_controls: HBoxContainer
var _standalone_play: Button
var _viewport: SubViewport
var _swatch := ColorRect.new()
var _static_container: SubViewportContainer
var _boss_preview
var _game_context
var _context_active := false

func _ready() -> void:
	_collect_boss_techniques()
	_paths.append_array(DIRECT_EFFECTS)
	_paths.append(BOMBER_PREVIEW)
	_paths.append_array(ENEMY_EFFECTS.keys())
	for key in BODY_EFFECTS:
		if key != "boss/shared/tornado_shader": _paths.append(key)
	_paths.sort()
	var groups := HFlowContainer.new()
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(controls_host if controls_host != null else self).add_child(groups)
	for group in TARGET_GROUPS:
		var button := Button.new()
		button.text = group
		button.toggle_mode = true
		button.pressed.connect(_show_target_group.bind(group))
		groups.add_child(button)
		_group_buttons[group] = button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(controls_host if controls_host != null else self).add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_target_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_list.add_theme_constant_override("v_separation", 4)
	body.add_child(_target_list)
	body.add_child(HSeparator.new())
	_editing_label.text = "編集対象を選択してください"
	body.add_child(_editing_label)
	body.add_child(_fields)
	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(preview_host if preview_host != null else self).add_child(preview)
	_standalone_controls = HBoxContainer.new()
	_standalone_controls.visible = false
	preview.add_child(_standalone_controls)
	_standalone_play = Button.new()
	_standalone_play.toggle_mode = true
	_standalone_play.text = "⏸"
	_standalone_play.tooltip_text = "再生・一時停止"
	_standalone_play.toggled.connect(func(paused: bool):
		_standalone_play.text = "▶" if paused else "⏸"
		if is_instance_valid(_sample): _sample.set("preview_paused", paused))
	_standalone_controls.add_child(_standalone_play)
	var standalone_step := Button.new()
	standalone_step.text = "⏭"
	standalone_step.tooltip_text = "1コマ進める"
	standalone_step.pressed.connect(func():
		_standalone_play.button_pressed = true
		if is_instance_valid(_sample): _sample.call("preview_step", 1.0 / 60.0))
	_standalone_controls.add_child(standalone_step)
	var standalone_restart := Button.new()
	standalone_restart.text = "⏮"
	standalone_restart.tooltip_text = "先頭から再生し直す"
	standalone_restart.pressed.connect(func():
		if is_instance_valid(_sample): _sample.call("preview_restart"))
	_standalone_controls.add_child(standalone_restart)
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
	_game_context = load("res://gyms/game_context_preview.gd").new()
	_game_context.visible = false
	preview.add_child(_game_context)
	reload_current()
	_show_target_group(_target_group)

func _group_for(path: String) -> String:
	if path == BOOST_GAUGE.KEY: return "HUD"
	if path.begins_with("weapon/"): return "武器"
	if path.begins_with("trait/"): return "特性"
	if path.begins_with("boss/body/"): return "ボス本体"
	if _move_targets.has(path) or path.begins_with(ROOT + "/") or path == "boss/final_strike": return "ボス技"
	return "敵の技"

func _definition_for(path: String) -> Resource:
	if not path.begins_with("weapon/") and not path.begins_with("trait/"): return null
	var category: StringName = &"weapons" if path.begins_with("weapon/") else &"traits"
	for definition in ContentManager.catalog.table(category).values():
		if String(definition.code_id) == path.get_slice("/", 1): return definition
	return null

func _target_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#213b52") if selected else Color("#141d2b")
	style.border_color = Color("#80dfff") if selected else Color("#40546b")
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(3)
	return style

func _collect_boss_techniques() -> void:
	for number in range(1, 6):
		var stage: Resource = load("res://data/stages/stage_%d.tres" % number)
		if stage == null: continue
		var boss_id := String(stage.get("boss_id"))
		var boss: Resource = load("res://data/bosses/%s.tres" % boss_id)
		var rules: Resource = load("res://data/bosses/ai/%s_action_rules.tres" % boss_id)
		if boss == null or rules == null: continue
		_boss_sections.append({"id": boss_id, "title": "ステージ%d · %s" % [number, boss.get("display_name")]})
		for item in rules.get("techniques"):
			var move: Resource = item
			if move == null: continue
			var path := "boss/move/%s/%s" % [boss_id, move.technique]
			_move_targets[path] = {"boss": boss_id, "id": String(move.technique), "visual": move.visual.resource_path if move.visual != null else "", "move": move, "projectile": move.get("shot_visual") if "shot_visual" in move else null}
			_move_order[path] = _move_order.size()
			if boss_id == "centaurus" and String(move.technique) in ["shower_chase", "shower_wall", "shower_path"]:
				_move_targets[path].projectile = preload("res://scenes/attacks/light_arrow.tscn")
			_paths.append(path)
			var names: PackedStringArray = _technique_names.get(path, PackedStringArray())
			var name: String = move.display_name if not move.display_name.is_empty() else String(move.technique)
			if not names.has(name): names.append(name)
			_technique_names[path] = names

func _toggle_boss_section(boss_id: String, items: HFlowContainer, heading: Button) -> void:
	var expanded: bool = not items.visible
	_expanded_bosses[boss_id] = expanded
	items.visible = expanded
	heading.text = ("▼ " if expanded else "▶ ") + String(heading.get_meta("title"))

func _add_target_button(path: String, parent: HFlowContainer) -> void:
	var definition := _definition_for(path)
	var name: String = definition.get_display_name() if definition != null else _effect_label(path)
	var button := Button.new()
	button.custom_minimum_size = Vector2(76, 70) if definition != null else Vector2(220, 46) if _group_for(path) == "ボス技" else Vector2(94, 42)
	if ATTACK_LABELS.has(path):
		button.tooltip_text = name + "\n" + ATTACK_LABELS[path][1] + "\n" + path
	elif definition != null:
		button.tooltip_text = name + "\n" + definition.get_description()
	elif _technique_names.has(path):
		var names: PackedStringArray = _technique_names[path]
		button.tooltip_text = "\n".join(names) + "\n" + path
	else:
		button.tooltip_text = name + "\n" + path
	button.pressed.connect(_select.bind(path))
	parent.add_child(button)
	_target_buttons[path] = button
	if definition == null:
		if _group_for(path) == "敵の技":
			button.custom_minimum_size = Vector2(112, 56)
			button.clip_contents = true
			var caption := Label.new()
			caption.text = name
			caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(caption)
			caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			caption.offset_left = 6
			caption.offset_right = -6
			return
		if _group_for(path) == "ボス技": button.text = name
		else: button.text = name.substr(0, 8) + "…" if name.length() > 8 else name
		button.clip_text = true
		return
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(column)
	var icon := TextureRect.new()
	icon.texture = MODULE_ICONS.texture_for(definition)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size.y = 43
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var caption := Label.new()
	caption.text = name.substr(0, 5) + "…" if name.length() > 5 else name
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)

func _show_target_group(group: String) -> void:
	_target_group = group
	for title in _group_buttons: _group_buttons[title].button_pressed = title == group
	for child in _target_list.get_children():
		_target_list.remove_child(child)
		child.queue_free()
	_target_buttons.clear()
	if group == "ボス技":
		for section in _boss_sections:
			var boss_id: String = section.id
			var paths: Array[String] = []
			for path in _paths:
				if path.begins_with("boss/move/" + boss_id + "/"): paths.append(path)
			paths.sort_custom(func(a: String, b: String): return _move_order[a] < _move_order[b])
			if paths.is_empty(): continue
			var heading := Button.new()
			heading.set_meta("title", section.title)
			var items := HFlowContainer.new()
			items.add_theme_constant_override("h_separation", 4)
			items.add_theme_constant_override("v_separation", 4)
			var expanded: bool = _expanded_bosses.get(boss_id, _selected.begins_with("boss/move/" + boss_id + "/") or String(_boss_sections[0]["id"]) == boss_id)
			items.visible = expanded
			heading.text = ("▼ " if expanded else "▶ ") + String(section.title)
			heading.pressed.connect(_toggle_boss_section.bind(boss_id, items, heading))
			_target_list.add_child(heading)
			_target_list.add_child(items)
			for path in paths: _add_target_button(path, items)
		if _paths.has("boss/final_strike"):
			var shared_title := Label.new()
			shared_title.text = "共通"
			_target_list.add_child(shared_title)
			var shared := HFlowContainer.new()
			_target_list.add_child(shared)
			_add_target_button("boss/final_strike", shared)
	else:
		var items := HFlowContainer.new()
		items.add_theme_constant_override("h_separation", 4)
		items.add_theme_constant_override("v_separation", 4)
		_target_list.add_child(items)
		for path in _paths:
			if _group_for(path) == group: _add_target_button(path, items)
	_refresh_target_selection()

func _refresh_target_selection() -> void:
	for path in _target_buttons:
		var selected: bool = path == _selected
		_target_buttons[path].add_theme_stylebox_override("normal", _target_style(selected))
		_target_buttons[path].add_theme_stylebox_override("hover", _target_style(selected))
	_editing_label.text = "編集中: " + _effect_label(_selected) if not _selected.is_empty() else "編集対象を選択してください"
	_editing_label.tooltip_text = _selected

func _effect_label(path: String) -> String:
	if path == BOOST_GAUGE.KEY: return "ブーストゲージ"
	if ENEMY_EFFECTS.has(path): return ENEMY_EFFECTS[path].title
	if path.begins_with("boss/body/"):
		for section in _boss_sections:
			if section.id == path.get_slice("/", 2): return String(section.title) + " · 本体"
	if ATTACK_LABELS.has(path): return ATTACK_LABELS[path][0]
	if path == "boss/final_strike": return "制限時間の一撃（共通）"
	if _technique_names.has(path):
		var names: PackedStringArray = _technique_names[path]
		return names[0] + (" ほか%d技" % (names.size() - 1) if names.size() > 1 else "")
	if path.begins_with("weapon/") or path.begins_with("trait/"):
		var category := &"weapons" if path.begins_with("weapon/") else &"traits"
		for entry in ContentManager.catalog.table(category).values():
			if String(entry.code_id) == path.get_slice("/",1):
				return ("武器：" if category == &"weapons" else "特性：") + entry.get_display_name()
	if path.begins_with(ROOT + "/"): return "技名未設定"
	return path.trim_prefix(ROOT+"/").trim_suffix("_visual.tscn")

func _select(path: String) -> void:
	_selected = path
	if path == BOOST_GAUGE.KEY:
		_working.profiles[path] = BOOST_GAUGE.migrated_values(_working.profiles.get(path, {}))
	_standalone_controls.visible = path == BOMBER_PREVIEW
	_standalone_play.set_pressed_no_signal(false)
	_standalone_play.text = "⏸"
	if _group_for(path) != _target_group: _show_target_group(_group_for(path))
	else: _refresh_target_selection()
	if is_instance_valid(_sample): _sample.queue_free()
	_sample = null
	var boss_effect := ENEMY_EFFECTS.has(path) or _move_targets.has(path) or path.begins_with(ROOT + "/") or BODY_EFFECTS.has(path)
	var live_effect := boss_effect or path == "boss/final_strike" or path.begins_with("weapon/") or path.begins_with("trait/")
	_static_container.visible = not live_effect and path != BOOST_GAUGE.KEY
	_game_context.visible = path == BOOST_GAUGE.KEY
	if path == BOOST_GAUGE.KEY: _game_context.set_boost_values(_working.profiles.get(path, {}))
	_game_context.set_active(_context_active and path == BOOST_GAUGE.KEY)
	_boss_preview.visible = live_effect
	_boss_preview.set_active(live_effect)
	if ENEMY_EFFECTS.has(path) or _move_targets.has(path) or path.begins_with("res://"):
		var scene_path: String = ENEMY_EFFECTS[path].scene if ENEMY_EFFECTS.has(path) else _move_targets[path].visual if _move_targets.has(path) else path
		var scene := load(scene_path) as PackedScene if not scene_path.is_empty() else null
		_sample = scene.instantiate() as Node2D if scene != null else null
		if not boss_effect and _sample != null:
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
	var preview_path := path if ENEMY_EFFECTS.has(path) or _move_targets.has(path) else String(BODY_EFFECTS.get(path, path)) if boss_effect else (path if live_effect else "")
	_boss_preview.set_effect(preview_path)

func _build_fields() -> void:
	_boost_boundary_inputs.clear()
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	if _selected in preload("res://gyms/equipment_effect_scenario.gd").PASSIVE_KEYS:
		var note := Label.new()
		note.text = "固有演出はありません。射撃・移動への作用は試遊で確認できます。攻撃力や回収量などの数値は表示しません。"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fields.add_child(note)
		return
	var entries: Array[Dictionary] = []
	if not BODY_EFFECTS.has(_selected) and _selected not in [BOMBER_PREVIEW, BOOST_GAUGE.KEY] and (not _move_targets.has(_selected) or _sample != null) and _selected != "enemy/phoenix": entries.append({"name": "effect_tint", "value": Color.WHITE})
	for field in DIRECT_FIELDS.get(_selected, []):
		entries.append({"name": field[1], "value": field[5], "hint": "%s,%s,%s" % [field[2], field[3], field[4]], "fallback": field[0]})
	for field in DIRECT_COLOR_FIELDS.get(_selected, []):
		entries.append({"name": field[1], "value": field[2], "fallback": field[0]})
	entries.append_array(_shader_entries(_selected))
	entries.append_array(_component_entries(_selected))
	if is_instance_valid(_sample):
		for info in _sample.get_property_list():
			var name: String = info.name
			if name not in VISUAL_FIELDS and not (_selected == "enemy/aquila" and name in ["glow_opacity", "ring_opacity", "ring_width", "arm_count", "lightning_reach", "lightning_width"]): continue
			if name == "flight_scale" and _selected != "res://scenes/attacks/star_bolt.tscn": continue
			if not (info.usage & PROPERTY_USAGE_EDITOR): continue
			if info.type in [TYPE_COLOR, TYPE_FLOAT, TYPE_INT]:
				entries.append({"name": name, "value": _sample.get(name), "hint": info.hint_string})
	var unique := {}
	for entry in entries:
		if not unique.has(entry.name): unique[entry.name] = entry
	entries.assign(unique.values())
	if entries.is_empty():
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.text = "この技は本体・猟犬の移動、または登録された構成技の表示を使います。独立した表示部品はありません。試遊で動きを確認できます。"
		_fields.add_child(note)
	for group in GROUP_ORDER:
		var grouped: Array[Dictionary] = []
		for entry in entries:
			if entry.get("group", _field_group(entry.name)) == group: grouped.append(entry)
		if grouped.is_empty(): continue
		_add_group(group)
		for entry in grouped:
			var name: String = entry.name
			var label: String = _field_label(name, String(entry.get("fallback", name)))
			var help: String = entry.get("help", FIELD_HELP.get(name, label + "の表示値を調整します。"))
			if entry.value is Color: _add_color(label, name, entry.value, help)
			else: _add_number(label, name, entry.value, String(entry.get("hint", "")), help)

## 装備の表示と、AttackVisualがTUNED_SHADERSで示すshaderの調整値。
func _shader_entries(path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var script: Script
	if path.begins_with("weapon/") or path.begins_with("trait/"):
		var script_path := "res://scripts/render/equipment/%s.gd" % path.get_slice("/", 1)
		if not ResourceLoader.exists(script_path): return entries
		script = load(script_path) as Script
	elif is_instance_valid(_sample):
		script = _sample.get_script() as Script
	else: return entries
	var seen := {}
	var defaults := {}
	while script != null:
		var constants: Dictionary = script.get_script_constant_map()
		defaults.merge(constants.get("SHADER_DEFAULTS", {}), false)
		for shader: Shader in constants.get("TUNED_SHADERS", []):
			if seen.has(shader.resource_path): continue
			seen[shader.resource_path] = true
			for info in ShaderTuning.tunables(shader):
				var name := ShaderTuning.field(shader, info.name)
				var label: Array = SHADER_LABELS.get(info.name, [info.name, ""])
				entries.append({"name": name, "value": defaults.get(name, ShaderTuning.default_value(shader, info.name)),
					"hint": info.hint_string, "fallback": label[0], "help": label[1]})
		script = script.get_base_script()
	return entries

## 部品の明示したartist値だけを列挙する。sampler・時刻・判定値は対象外。
func _component_entries(key: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var components := COMPONENTS.fire_presets(key)
	if key == "enemy/phoenix": components.append({"resource": preload("res://data/visuals/phoenix_flames.tres"), "title": "着地の炎"})
	for component in components:
		var resource: Resource = component.resource
		var allowed: Array = COMPONENTS.PHOENIX_FIELDS if key == "enemy/phoenix" else COMPONENTS.FIRE_FIELDS
		for info in resource.get_property_list():
			var name: String = info.name
			if name not in allowed: continue
			var value: Variant = resource.get(name)
			var label: String = component.title + " · " + COMPONENTS.LABELS.get(name, name)
			var prefix := COMPONENTS.prefix(resource) + name
			var quality: bool = name in COMPONENTS.QUALITY_FIELDS
			var group := "品質・負荷" if quality else "色" if value is Color else "粒子" if name.begins_with("layer_") or name in ["birth_rate", "particle_size"] else "動き・時間" if name in ["lifetime", "speed", "rise_speed", "sway", "update_fps"] else "形・大きさ"
			var help := "表示だけを変更します。判定・弾速・射程・攻撃時間を維持します。"
			if quality: help = "描画品質と負荷の設定。大きな描画域・粒数・FPSや細かい密度画素は負荷が増えます。"
			if value is Vector2 or value is Vector3:
				var axes := 2 if value is Vector2 else 3
				for axis in axes:
					var suffix: String = ["横", "縦"][axis] if axes == 2 else ["外炎", "内炎", "芯"][axis]
					entries.append({"name": prefix + "/" + "xyz"[axis], "value": value[axis], "hint": ("64,1024,8" if axis == 1 else "32,1024,8") if name == "field_size" else "0,4,0.05", "fallback": label + " · " + suffix, "help": help, "group": group})
			else:
				entries.append({"name": prefix, "value": value, "hint": info.hint_string, "fallback": label, "help": help, "group": group})
	if key.begins_with("boss/move/"):
		var body_key := "boss/body/" + key.get_slice("/", 2)
		var base: Dictionary = _working.values_for(body_key)
		for field in DIRECT_FIELDS.get(body_key, []):
			entries.append({"name": "body/" + field[1], "value": base.get(field[1], field[5]), "hint": "%s,%s,%s" % [field[2], field[3], field[4]], "fallback": "本体 · " + String(field[0]), "help": "この技の間だけ使う本体の表示値。技が切り替わると共通設定へ戻ります。", "group": "形・大きさ"})
		for field in DIRECT_COLOR_FIELDS.get(body_key, []):
			entries.append({"name": "body/" + field[1], "value": base.get(field[1], field[2]), "fallback": "本体 · " + String(field[0]), "help": "この技の間だけ使う本体の色。技が切り替わると共通設定へ戻ります。", "group": "色"})

	if key.begins_with("boss/move/hydra/"):
		var id := key.get_slice("/", 3)
		var shaders: Array[Shader] = []
		if id == "tornado": shaders.append(preload("res://shaders/hydra_tornado.gdshader"))
		else:
			if id != "thunder_drop": shaders.append(preload("res://shaders/hydra_energy.gdshader"))
			if id in ["thunder_drop", "thunder_headbutt", "bite_thrust"]: shaders.append(preload("res://shaders/hydra_area.gdshader"))
		var legacy_shape: Dictionary = _working.values_for("res://scenes/attacks/hydra_shape.tscn")
		entries.append({"name": "shape/pixel_scale", "value": legacy_shape.get("pixel_scale", 1.0), "hint": "0.5,4,0.05", "fallback": "攻撃本体 · ドット倍率", "group": "形・大きさ"})
		entries.append({"name": "shape/effect_tint", "value": legacy_shape.get("effect_tint", Color.WHITE), "fallback": "攻撃本体 · 全体色", "group": "色"})
		for shader in shaders:
			var legacy_key := "boss/shared/tornado_shader" if id == "tornado" else "res://scenes/attacks/hydra_shape.tscn"
			var legacy: Dictionary = _working.values_for(legacy_key)
			for info in ShaderTuning.tunables(shader):
				if shader.resource_path.ends_with("hydra_energy.gdshader"):
					if String(info.name).begins_with("wind_") and id not in ["wind_band", "wind_blades"]: continue
					if (String(info.name).begins_with("lightning_") or info.name == "branch_threshold") and not id.begins_with("thunder"): continue
					if info.name in ["core_ratio", "core_wobble", "flow_frequency", "flow_speed"] and id in ["wind_band", "wind_blades"]: continue
				var field := ShaderTuning.field(shader, info.name)
				var label: Array = SHADER_LABELS.get(info.name, [info.name, "表示だけを調整します。判定と攻撃時間は維持します。"])
				entries.append({"name": "shape/" + field, "value": legacy.get(field, ShaderTuning.default_value(shader, info.name)), "hint": info.hint_string, "fallback": "攻撃本体 · " + String(label[0]), "help": label[1], "group": "シェーダ"})

	if _move_targets.has(key) and _move_targets[key].projectile != null:
		var scene: PackedScene = _move_targets[key].projectile
		var visual := scene.instantiate() as AttackVisual
		if visual != null:
			var legacy := _working.values_for(visual.visual_profile_fallback if not visual.visual_profile_fallback.is_empty() else visual.scene_file_path)
			for info in visual.get_property_list():
				var name: String = info.name
				if name not in ["effect_tint", "flight_scale", "shot_length_scale", "shot_width_scale", "core_width", "arrow_color", "cosmic_color_a", "cosmic_color_b", "cosmic_speed", "cosmic_star_count"]: continue
				var cosmic := visual.visual_profile_fallback.ends_with("cosmic_arrow.tscn")
				if name.begins_with("cosmic_") and not cosmic: continue
				if name == "arrow_color" and cosmic: continue
				var value: Variant = legacy.get(name, visual.get(name))
				entries.append({"name": "projectile/" + name, "value": value, "hint": info.hint_string, "fallback": "弾の表示 · " + FIELD_LABELS.get(name, "矢の色" if name == "arrow_color" else "芯の太さ（px）" if name == "core_width" else {"effect_tint": "弾の色", "cosmic_color_a": "変化する色1", "cosmic_color_b": "変化する色2", "cosmic_speed": "色が変わる速さ", "cosmic_star_count": "尾の星の数"}.get(name, name)), "help": "この技の弾の表示だけを変更します。弾速・威力・判定を維持します。", "group": "色" if value is Color else "形・大きさ"})
			visual.free()
	return entries

func _field_group(name: String) -> String:
	if name.begins_with(ShaderTuning.PREFIX): return "シェーダ"
	if name.ends_with("color") or name.ends_with("tint") or name == "effect_tint": return "色"
	if name in ["duration_scale", "visible_time_scale", "visible_seconds", "flash_duration", "wake_fade_seconds"]: return "動き・時間"
	if name in ["particle_count_scale", "wake_filaments"]: return "粒子"
	return "形・大きさ"

func _field_label(name: String, fallback: String) -> String:
	if _selected == BOMBER_PREVIEW and name == "visible_seconds": return "炎の表示（秒）"
	return FIELD_LABELS.get(name, fallback)

func _add_group(title: String) -> void:
	_fields.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = title
	heading.add_theme_color_override("font_color", Color("#86dfff"))
	_fields.add_child(heading)

func _value(name: String, fallback: Variant) -> Variant:
	var legacy: String = _move_targets[_selected].visual if _move_targets.has(_selected) else ENEMY_EFFECTS[_selected].scene if ENEMY_EFFECTS.has(_selected) else ""
	if _selected == "boss/move/draco/inhale" and (name.begins_with("shader/") or name in ["pixel_scale", "fade_seconds"]):
		legacy = "res://scenes/attacks/beam_draco.tscn"
	return _working.resolved_values(_selected, legacy).get(name, fallback)

func _set_value(name: String, value: Variant) -> void:
	var values: Dictionary = _working.profiles.get(_selected, {}).duplicate()
	if _selected == BOOST_GAUGE.KEY:
		values = BOOST_GAUGE.edited_values(values, name, value)
		for key in _boost_boundary_inputs: _boost_boundary_inputs[key].set_value_no_signal(values[key])
	else:
		values[name] = value
	_working.profiles[_selected] = values
	_dirty = true
	_message = "未保存: " + _selected
	_apply_preview()
	if ENEMY_EFFECTS.has(_selected) or _move_targets.has(_selected) or _selected.begins_with(ROOT + "/") or BODY_EFFECTS.has(_selected) or _selected == "boss/final_strike" or _selected.begins_with("weapon/") or _selected.begins_with("trait/"):
		_boss_preview.refresh_effects()

func _add_color(label: String, name: String, original: Color, help := "") -> void:
	var row := HBoxContainer.new()
	row.tooltip_text = help
	_fields.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.tooltip_text = help
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(72, 32)
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picker.tooltip_text = help + "\nクリックして色を変更"
	picker.color = _value(name, original)
	picker.color_changed.connect(func(color: Color): _set_value(name, color))
	row.add_child(picker)

func _add_number(label: String, name: String, original: float, hint: String, help := "") -> void:
	var row := HBoxContainer.new()
	row.tooltip_text = help
	_fields.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.tooltip_text = help
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(90, 32)
	spin.tooltip_text = help
	var parts := hint.split(",")
	var limits: Array = NUMBER_LIMITS.get(name, [0.0, maxf(100.0, original * 4.0), 0.05])
	spin.min_value = float(parts[0]) if parts.size() > 0 and parts[0].is_valid_float() else limits[0]
	spin.max_value = float(parts[1]) if parts.size() > 1 and parts[1].is_valid_float() else limits[1]
	spin.step = float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else limits[2]
	spin.value = _value(name, original)
	spin.value_changed.connect(func(value: float): _set_value(name, value))
	row.add_child(spin)
	if _selected == BOOST_GAUGE.KEY and name in BOOST_GAUGE.BOUNDARY_KEYS: _boost_boundary_inputs[name] = spin

func _apply_preview() -> void:
	if _selected == BOOST_GAUGE.KEY:
		_game_context.set_boost_values(_working.profiles.get(BOOST_GAUGE.KEY, {}))
	_swatch.color = _value("effect_tint", Color.WHITE)
	if _selected in [BOMBER_PREVIEW, BOOST_GAUGE.KEY] or ENEMY_EFFECTS.has(_selected) or _move_targets.has(_selected) or _selected.begins_with(ROOT + "/") or BODY_EFFECTS.has(_selected) or _selected == "boss/final_strike" or _selected.begins_with("weapon/") or _selected.begins_with("trait/"):
		EFFECT_SETTINGS.set_preview_profiles(_working.profiles)
	if not is_instance_valid(_sample): return
	_sample.modulate = Color.WHITE
	_working.apply_to(_sample)
	if _selected == BOMBER_PREVIEW: _sample.call("preview_step", 0.0)
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
	_context_active = active
	if is_instance_valid(_game_context): _game_context.set_active(active and _selected == BOOST_GAUGE.KEY)
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	var live_effect := ENEMY_EFFECTS.has(_selected) or _move_targets.has(_selected) or _selected.begins_with(ROOT + "/") or BODY_EFFECTS.has(_selected) or _selected == "boss/final_strike" or _selected.begins_with("weapon/") or _selected.begins_with("trait/")
	if is_instance_valid(_boss_preview): _boss_preview.set_active(active and live_effect)
	if not active: EFFECT_SETTINGS.clear_preview_profiles()
	elif _working != null and (live_effect or _selected in [BOMBER_PREVIEW, BOOST_GAUGE.KEY]): EFFECT_SETTINGS.set_preview_profiles(_working.profiles)
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	EFFECT_SETTINGS.clear_preview_profiles()
