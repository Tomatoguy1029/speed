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
## 名前
## 図鑑に出る名前。
## 単位：文字
@export var display_name: String
## 説明
## 図鑑に出る説明。
## 単位：文字
@export_multiline var description: String
## 落とすボス
## このモジュールを落とすボスの ID。
## 単位：文字
@export var boss_id: StringName
## 並び順
## 図鑑で並べる順番（小さいほど先）。
## 単位：番号
@export var order: int
