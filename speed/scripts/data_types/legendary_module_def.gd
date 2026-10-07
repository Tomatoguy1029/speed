## 伝説のモジュール1つの定義（仕様書 20.3）。能力値は持たない。
class_name LegendaryModuleDef
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## 対応する中ボス（res://data/bosses/ の id）
@export var boss_id: StringName
@export var order: int
