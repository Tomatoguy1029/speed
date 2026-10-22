## 伝説のモジュール
## 中ボスを倒すと手に入る特別なモジュール。図鑑に載る。今は能力の効果を持たない。
## ---
## 値の正は res://data/legendary_modules/*.tres。
class_name LegendaryModuleDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 8

## 演出プレビューの後光調整項目。既定値は legendary_reveal のシーンから読む。
## 値は [表示名, 下限, 上限, 刻み]。色は数値範囲を持たない。
const BACKLIGHT_PARAMETERS := {
	"backlight_width": ["光条の太さ", 0.5, 2.0, 0.05],
	"broad_ray_count": ["主光条の本数", 4, 64, 1],
	"fine_ray_count": ["細光条の本数", 8, 256, 1],
	"backlight_reach": ["光条の長さ", 0.3, 2.0, 0.05],
	"backlight_motion_speed": ["動きの速さ", 0.0, 3.0, 0.05],
	"ray_breath_strength": ["長さ・幅・明滅の変動幅", 0.0, 1.0, 0.05],
	"light_strength": ["後光の明るさ", 0.0, 1.0, 0.05],
	"broad_ray_strength": ["主光条の強さ", 0.0, 4.0, 0.05],
	"fine_ray_strength": ["細光条の強さ", 0.0, 4.0, 0.05],
	"white_core_strength": ["白い芯の強さ", 0.0, 4.0, 0.05],
	"white_core_radius": ["白い芯の広さ", 0.08, 0.35, 0.01],
	"backlight_color": ["後光の色"],
}

## ID
## モジュールを見分ける名前。ステージのデータとセーブがこの名前で指す。
## 単位：文字
@export var id: StringName
## 落とすボス
## このモジュールを落とすボスの ID。
## 単位：文字
@export var boss_id: StringName
## 並び順
## 図鑑で並べる順番（小さいほど先）。
## 単位：番号
@export var order: int

## 図鑑の専用画像。未設定なら効果イメージ／仮の部品図を表示する。
@export_group("図鑑")
@export var preview_texture: Texture2D

## 獲得時のオーラだけを調整する。モジュール画像・後光・能力は変えない。
@export_group("獲得演出：オーラ")
## オーラ領域全体の透過マスク。未指定なら従来どおり表示画像のアルファを使う。
@export var reveal_aura_mask: Texture2D
## マスクの読み方。アルファは不透明部、輝度は白い部分を生成元にする。
## 輝度にもアルファを乗じ、透明部からは生成しない。マスク未指定時は表示画像のアルファを使う。
@export_enum("透過アルファ", "白黒の輝度") var reveal_aura_mask_channel := 0
## 基準位置からのずれ。640×360 のデザイン座標でのピクセル数。
@export var reveal_aura_offset := Vector2.ZERO
## オーラ領域の横・縦の倍率。画像の表示サイズは変えない。
@export var reveal_aura_scale := Vector2.ONE
## オーラ領域の中心を軸にした回転角。単位：度。
@export_range(-180.0, 180.0, 1.0) var reveal_aura_rotation_degrees := 0.0

## オーラはプレビューでベイクし、ゲームではこの2枚のアトラスを再生する。
@export_group("獲得演出：オーラのベイク")
@export var reveal_aura_baked_back: Texture2D
@export var reveal_aura_baked_front: Texture2D
@export var reveal_aura_bake_signature := ""
@export var reveal_aura_bake_frames := 32
@export var reveal_aura_bake_columns := 8
@export var reveal_aura_bake_fps := 8.0

## 獲得演出の後光。プレビュー画面で変更した項目をこのモジュールだけに保存する。
## 空の項目は演出シーンの既定値を使う。
@export_group("獲得演出：後光")
@export var reveal_backlight_settings: Dictionary = {}

## 画面に出る名前と説明。編集元は docs/game/text.md。翻訳キーは strings.csv の legendary.<ID>.name／.desc。
func get_display_name() -> String:
	return tr("legendary.%s.name" % id)

func get_description() -> String:
	return tr("legendary.%s.desc" % id)
