## 伝説のモジュール
## 中ボスを倒すと手に入る特別なモジュール。図鑑に載る。今は能力の効果を持たない。
## ---
## 値の正は res://data/legendary_modules/*.tres。
class_name LegendaryModuleDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 8

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

## モジュールの画像。図鑑・撃破後の獲得・最終武器欄・ラスボス決着の合体で使う。
@export_group("図鑑")
@export var preview_texture: Texture2D

## 画面に出る名前と説明。編集元は docs/game/text.md。翻訳キーは strings.csv の legendary.<ID>.name／.desc。
func get_display_name() -> String:
	return tr("legendary.%s.name" % id)

func get_description() -> String:
	return tr("legendary.%s.desc" % id)
