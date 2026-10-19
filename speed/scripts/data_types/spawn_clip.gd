## 出現のクリップ
## ステージのタイムラインに置く、山場の出現。決めた時刻に、敵の組み合わせのシーンから配置と出現位置を
## ランダムに1つずつ選んで、群れを出す。
## ---
## 値の正は res://data/stages/*.tres の clips。
class_name SpawnClip
extends Resource

## ラベル
## タイムラインに出す名前（作り手用）。
## 単位：文字
@export var label: String
## 敵の組み合わせ
## 出す群れの組み合わせのシーン（res://data/formations/*.tscn）。
## 単位：シーン
@export var formation: PackedScene
## 時刻
## ラン開始からこの時刻に、最初の群れを出す。
## 単位：実秒
@export var time: float
## 繰り返しの間隔
## 2回目からの群れを、この間隔ごとに出す。
## 単位：実秒
@export var interval: float
## 回数
## 群れを出す回数。1 なら1回だけ。
## 単位：回
@export var count: int = 1
## いる時間の目安
## 出した群れがフィールドにいると見込む時間。タイムラインで、強敵どうしの重なりを調べるのに使う。
## 単位：実秒
@export var stay: float = 30.0
