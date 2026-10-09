## カプセル類1つ（仕様書 10）。数の多い経験値の結晶と部品は PickupManager の列で持つ。
class_name Pickup
extends RefCounted

enum Kind { CACHE, HEAL, MAGNET, CORE }

var kind: Kind = Kind.CACHE
## drop：敵や隕石が落としたもの（吸い寄せる・寿命あり）、field：フィールドの漂流カプセル、core：出力コア
var src: StringName = &"drop"
var pos := Vector2.ZERO
## 経験値の量（経験値カプセル）
var value := 0.0
var age := 0.0
var taken := false
