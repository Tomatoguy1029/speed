## 出現のクリップ
## ステージのタイムラインに置く、強敵の出現。開始から長さの間だけ働き、その間、選んだ種類の組み合わせの群れを出し続ける。
## 群れは、フォーメーション（敵の組み合わせのシーン）からランダムに1つ選び、その配置と出現位置をランダムに1つずつ選んで出す。
## ---
## 値の正は res://data/stages/*.tres の clips。
class_name SpawnClip
extends Resource

## ラベル
## タイムラインに出す名前（作り手用）。
## 単位：文字
@export var label: String
## トラック
## タイムラインで置く行の番号（0 から）。-1 なら、クリップの並びの番号の行に置く。出し方には関係しない。
## 単位：番号
@export var track: int = -1
## 種類の組み合わせ
## このクリップが出す敵の種類。ステージの敵の一覧から選ぶ。フォーメーションには、ここで選んだ種類だけを置ける。
## 単位：type ID
@export var types: Array[StringName] = []
## フォーメーション
## 群れの形（res://data/formations/*.tscn）。出すたびにランダムに1つ選ぶ。
## 単位：シーン
@export var formations: Array[PackedScene] = []
## 開始の時刻
## ラン開始からこの時刻に、このクリップが働き始める。
## 単位：実秒
@export var time: float
## 長さ
## 開始からこの時間だけ働く。
## 単位：実秒
@export var length: float = 60.0
## 同時の群れの数
## 働いている間、このクリップから出た群れがフィールドにいてほしい数。足りなければ出す。
## 単位：群れ
@export var groups: int = 1
## 出す間隔
## このクリップから群れを出してから、次の群れを出すまでの最短の時間。
## 単位：実秒
@export var interval: float = 10.0

## 終わりの時刻。
func end_time() -> float:
	return time + length
