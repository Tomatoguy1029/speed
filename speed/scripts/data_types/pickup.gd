## カプセル類1つ（仕様書 10）。数の多い経験値の結晶と部品は PickupManager の列で持つ。
class_name Pickup
extends RefCounted

## COMET_WEAPON はレアな彗星が落とす、彗星限定の武器のカプセル
enum Kind { CACHE, HEAL, MAGNET, CORE, COMET_WEAPON }

var kind: Kind = Kind.CACHE
## drop：敵や隕石が落としたもの（吸い寄せる・寿命あり）、comet：レアな彗星が落としたもの（吸い寄せる・寿命なし）、
## field：フィールドの漂流カプセル、core：出力コア
var src: StringName = &"drop"
var pos := Vector2.ZERO
## 経験値の量（経験値カプセル）
var value := 0.0
## 彗星限定の武器の管理 ID（COMET_WEAPON）
var weapon_id: StringName = &""
var age := 0.0
var taken := false
