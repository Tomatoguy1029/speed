## 強化画面の強化項目1つの定義（仕様書 12）。値の正は res://data/meta_upgrades/*.tres。
class_name MetaUpgradeDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String
## 効果を足す能力値（max_speed, max_hp, attack, charge_time, pickup, xp）
@export var stat: StringName
## 1段階ごとの効果（割合なら 0.05 = 5%）
@export var per_level: float
## 段階ごとの費用（部品）。要素数が最大段階
@export var costs: PackedInt32Array
@export var order: int
