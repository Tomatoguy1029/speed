## 敵の弾の種類（ProjectileSystem.HostileKind）ごとの動きと当たりの土台。種類ごとに res://scripts/attacks/<種類>.gd で上書きする。
##
## 同じ種類を複数の敵・ボスが使う。ProjectileSystem は、その戦いで使った種類だけを作る。
class_name HostileShape
extends RefCounted

## 画面の外で、画面から離れていく弾を消すか（追いかける弾は false）
var leaves_view := true

## 進む速度を決める（追いかける弾が向きを変える）。aim は敵の狙い。
func steer(_ps: ProjectileSystem, _i: int, vel: Vector2, _aim: Vector2, _dt: float) -> Vector2:
	return vel

## from から to へ進む間に機体（ship_pos、半径 R）へ当たれば被弾させ、止まる位置を返す。当たらなければ null。
## body_hit は先にぶつかる天体（なければ null）。step はこの更新で進む距離。
func contact(ps: ProjectileSystem, i: int, from: Vector2, to: Vector2, body_hit, ship_pos: Vector2, R: float, step: float) -> Variant:
	var rr := ps.hostile_r[i] + R
	var reach := rr + step
	if ship_pos.distance_squared_to(to) > reach * reach:
		return null
	var t := Geom.seg_circle_t(from, to, ship_pos, rr)
	if t < 0.0 or (body_hit != null and t >= body_hit.t):
		return null
	_damage_ship(ps, i)
	return from + (to - from) * t

## 機体に当たったときの被弾。
func _damage_ship(ps: ProjectileSystem, i: int) -> void:
	ps.ship.damage(ps.hostile_dmg[i], ps.hostile_slow[i], ProjectileSystem.HOSTILE_CAUSE[ps.hostile_kind[i]])

## 飛びきった・何かに当たった位置 at で消えるとき（まだ寿命が残っていたら reached は false）。
func on_end(_ps: ProjectileSystem, _i: int, _at: Vector2, _reached: bool) -> void:
	pass
