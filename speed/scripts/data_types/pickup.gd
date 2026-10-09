## 拾えるもの1つ（仕様書 10）。経験値の結晶・部品・カプセル類。
class_name Pickup
extends RefCounted

enum Kind { GEM, COIN, CACHE, HEAL, MAGNET, CORE }

var kind: Kind = Kind.GEM
## drop：敵や隕石が落としたもの（吸い寄せる・寿命あり）、field：フィールドの漂流カプセル、core：出力コア
var src: StringName = &"drop"
var pos := Vector2.ZERO
## 経験値の量（結晶とカプセル）
var value := 0.0
var age := 0.0
var pulled := false
var taken := false
