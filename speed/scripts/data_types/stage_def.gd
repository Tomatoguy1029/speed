## ステージ1つの定義（仕様書 20.2）。値の正は res://data/stages/*.tres。
class_name StageDef
extends Resource

@export var index: int
@export var display_name: String
## ステージの配置のシーン（res://scenes/stages/）
@export var scene_path: String
## このステージで使う時間帯（PhaseDef、開始時刻順）
@export var phases: Array
## このステージのボス（res://data/bosses/ の id）
@export var boss_id: StringName
## 撃破で手に入る伝説のモジュール（空ならなし）
@export var legendary_module_id: StringName
