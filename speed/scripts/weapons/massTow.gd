## W21 質量牽引砲：なぞり中の体当たりや攻撃で倒した敵の船体を、大型の敵も丸ごと牽引する。
## なぞり終えると、進む向きへ1つずつ撃ち出し、弾が尽きるまで撃ち続ける（彗星限定。一覧 docs/game/catalog/weapons.md）。
## 撃ち出した船体で倒した敵は、牽引しない。隕石とボスは牽引しない。
extends WeaponBehavior

## 牽引できる撃破の原因（なぞり中の攻撃）
const CAUSES: Array[StringName] = [&"ram", &"bump", &"wave", &"sonic", &"killSonic", &"contactWave", &"contactArc", &"critBeam"]

## 牽引中の船体。pos・r・type・color・angle・source_id・ready（撃ち出せるか）
var cargo: Array[Dictionary] = []
var _fire_t := 0.0

## 行 i の敵を倒した原因が cause のとき、船体を牽引するか決める。牽引したら true（破片は出さない）。
func capture(i: int, cause: StringName) -> bool:
	if not state.tracing or not CAUSES.has(cause):
		return false
	var t := build.enemies.table
	if t.type[i] == &"meteor" or t.is_boss[i] != 0:
		return false
	cargo.append({"pos": t.pos[i], "r": t.r[i], "type": t.type[i], "color": t.color[i],
		"angle": t.facing[i], "source_id": t.id[i], "ready": false})
	return true

func on_end() -> void:
	for c in cargo:
		c.ready = true
	_fire_t = 0.0

func tick(dt: float, _busy: bool) -> void:
	if cargo.is_empty():
		return
	var v := state.ship_vel
	var sp := v.length()
	var u := v / sp if sp > 1.0 else state.ship_heading
	# 機体の後ろに4列で並べる。弾の数に上限はなく、見せるのは先頭だけ
	var follow := 1.0 - exp(-float(p("follow")) * dt)
	for j in mini(int(p("visible")), cargo.size()):
		var c: Dictionary = cargo[j]
		var back := 85.0 + floorf(j / 4.0) * 85.0 + float(c.r)
		var side := (j % 4 - 1.5) * 65.0
		var target := state.ship_pos - u * back + Vector2(-u.y, u.x) * side
		c.pos += (target - c.pos) * follow
		c.angle = u.angle() + PI
	_fire_t -= dt
	var interval := float(p("interval")) / rate_k()
	while _fire_t <= 0.0 and not cargo.is_empty() and cargo[0].ready:
		var c: Dictionary = cargo.pop_front()
		var dmg := atk() * float(p("damage")) * dmg_k() * maxf(1.0, float(c.r) / float(p("size_ref")))
		build.projectiles.fire_hull(c.pos, u * (float(p("shot_speed")) + sp), c.r, dmg, p("life"), p("knock"),
			c.type, u.angle(), c.source_id)
		state.emit(&"ring", {"pos": c.pos, "radius": maxf(34.0, float(c.r)), "color": Color("#ffbe65"), "life": 0.15})
		_fire_t += interval
	if cargo.is_empty() or not cargo[0].ready:
		_fire_t = 0.0
