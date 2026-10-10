## なぞり1回ぶんの記録（仕様書 6.5）。同じ敵に何度当たったか、波動の帯に入っている敵など。
class_name TraceRun
extends RefCounted

## 突進の速さ（攻撃と、なぞり終えたあとの勢い）と、線をなぞる速さ（画面上の速さ）
var speed := 0.0
var rate := 0.0
## 今いる線の区間と、その区間の中での位置
var seg := 0
var seg_pos := 0.0
## 機体の本体に触れている敵（敵の id → 行番号。離れたら、もう一度当てられる）と、当てた回数（id → 回数）
var inside: Dictionary = {}
var passes: Dictionary = {}
## 波動の帯に入っている敵（敵の id → 行番号。帯から一度外れたら、もう一度当てられる）
var wave_inside: Dictionary = {}
var wave_acc := 0.0
