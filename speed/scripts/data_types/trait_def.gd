## 特性1つの定義（仕様書 6、一覧 docs/traits.md）。値の正は res://data/traits/*.tres。
class_name TraitDef
extends Resource

## 管理 ID（T01 など）
@export var id: StringName
## 内部 ID（endBlast など）。発動の処理（res://scripts/traits/）と対応する
@export var code_id: StringName
@export var display_name: String
@export_multiline var description: String
## 効果の値。重ね数 n に対する式の係数を持つ
@export var params: Dictionary
