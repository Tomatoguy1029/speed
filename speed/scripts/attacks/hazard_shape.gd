## 敵の攻撃の形（ProjectileSystem.HazardKind）ごとの当たりの土台。形ごとに res://scripts/attacks/<形>.gd で上書きする。
##
## 同じ形を複数の敵・ボスが使う。ProjectileSystem は、その戦いで使った形だけを作る。
class_name HazardShape
extends AttackKind

## 機体に1回だけ当たる（false なら残る線のように、触れている間ずっと危ない）
var hits_once := true

## 予告が終わって当たる間の、機体（ship_pos、半径 R）への当たり。i は攻撃の形の行。
func touches(_ps: ProjectileSystem, _i: int, _ship_pos: Vector2, _R: float) -> bool:
	return false

## 予告が終わって当たる間、毎回の処理（機体に当たったあとも続く敵へのダメージなど）。ランが続かなくなったら false。
func act(_ps: ProjectileSystem, _i: int, _dt: float) -> bool:
	return true

## まだ機体に当たっていない間、当たりを調べる前の処理。ランが続かなくなったら false。
func before_touch(_ps: ProjectileSystem, _i: int) -> bool:
	return true
