## W21 質量牽引砲：なぞり中に倒れた敵の船体を、大型の敵も丸ごと牽引する。
## なぞり終えると、進む向きへ1つずつ撃ち出し、弾が尽きるまで撃ち続ける（彗星限定。一覧 docs/game/catalog/weapons.md）。
## 隕石とボスは牽引しない。
extends WeaponBehavior

## 牽引中の船体。pos・r・type・color・angle・source_id・ready（撃ち出せるか）
var cargo: Array[Dictionary] = []
const GOLDEN_ANGLE := 2.39996323
var _fire_t := 0.0

## なぞり中なら、行 i の敵の船体を牽引する。牽引したら true（破片は出さない）。
func capture(i: int) -> bool:
	if not state.tracing:
		return false
	var t := build.enemies.table
	if t.meteor_index[i] >= 0 or t.is_boss[i] != 0:
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
	# 機体の後ろに1つの塊にまとめる（ひまわりの種の並び）。弾の数に上限はなく、見せるのは先頭だけ
	var follow := 1.0 - exp(-float(p("follow")) * dt)
	var count := mini(int(p("visible")), cargo.size())
	var spacing := float(p("clump_spacing"))
	var center := state.ship_pos - u * (70.0 + spacing * sqrt(float(count)) * 0.6)
	for j in count:
		var c: Dictionary = cargo[j]
		var offset := Vector2.from_angle(j * GOLDEN_ANGLE) * spacing * 0.6 * sqrt(float(j))
		var wobble := Vector2(sin(state.time * 2.0 + j), cos(state.time * 1.7 + j * 1.3)) * 5.0
		c.pos += (center + offset + wobble - c.pos) * follow
		c.angle += dt * (0.6 if j % 2 == 0 else -0.6)
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
