## 武器1つの定義（仕様書 6、一覧 docs/weapons.md）。値の正は res://data/weapons/*.tres。
class_name WeaponDef
extends Resource

## 管理 ID（W01 など）
@export var id: StringName
## 内部 ID（forward など）。発動の処理（res://scripts/weapons/）と対応する
@export var code_id: StringName
@export var display_name: String
@export_multiline var description: String
## 表示 Lv1〜5 に対応する性能段階
@export var level_steps: PackedInt32Array
## 発動の値（interval, damage, count など）。Lv ごとに変わる値は配列で持つ
@export var params: Dictionary
