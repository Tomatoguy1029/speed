## 時間帯1つの定義（仕様書 2.3）。値の正は res://data/phases/*.tres。
class_name PhaseDef
extends Resource

@export var id: StringName
## 作り手用の名前。ゲーム画面には出さない
@export var display_name: String
@export var start: float
@export var end: float
## 密度倍率をかける前の敵の数（開始時、終了時）
@export var pop_from: float
@export var pop_to: float
@export var level_from: float
@export var level_to: float
## 密度倍率をかける前の補充の速さ（体/秒）
@export var rate: float
## 経験値の倍率。0 は 1 倍として扱う
@export var xp_bonus: float
## 群れでまとめて出す間隔（秒）。0 なら出さない
@export var wave_interval: float
## 出力コアを出すか
@export var cores: bool
## type ID → 出現の重み
@export var mix: Dictionary
