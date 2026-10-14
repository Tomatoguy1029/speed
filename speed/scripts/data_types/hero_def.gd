## 英雄の星座
## ステージに捕らわれている英雄の星座。星座の形と、解放すると特別な枠に入る力を決める。
## ---
## 値の正は res://data/heroes/*.tres。
class_name HeroDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 9

## ID
## 英雄の星座の ID。力の種類もこの ID で決まる。
## 単位：文字
@export var id: StringName
## 名前
## 画面に出す名前。
## 単位：文字
@export var display_name: String
## ステージ
## この星座が捕らわれているステージの番号。
## 単位：番号
@export var stage: int
## 星の位置
## 星座の星の位置（星座の中心からの距離。`config.hero_scale` を掛けて置く）。
## 単位：単位（距離）
@export var stars: PackedVector2Array
## 星座線
## 星座線でつながる星の番号の組（2つずつ並べる）。
## 単位：番号
@export var links: PackedInt32Array
## クールダウン
## 力を使ってから、次に使えるまでの時間（効いている時間を含む）。
## 単位：実秒
@export var cooldown: float
## 効いている時間
## 力を使ってから効いている時間（一瞬で終わる力は0）。
## 単位：実秒
@export var duration: float
## 力の値
## 力ごとの値（倍率・間隔など）。
## 単位：—
@export var params: Dictionary
