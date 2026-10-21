## なぞり1回ぶんの記録（仕様書 6.5）。当たり判定に触れている敵と、同じ敵に何度当たったかなど。
class_name TraceRun
extends RefCounted

## 突進の速さ（攻撃と、なぞり終えたあとの勢い）と、線をなぞる速さ（画面上の速さ）
var speed := 0.0
var rate := 0.0
## 今いる線の区間と、その区間の中での位置
var seg := 0
var seg_pos := 0.0
## 機体の当たり判定に触れている敵（敵の id → 行番号。離れたら、もう一度当てられる）と、当てた回数（id → 回数）
var inside: Dictionary = {}
var passes: Dictionary = {}
