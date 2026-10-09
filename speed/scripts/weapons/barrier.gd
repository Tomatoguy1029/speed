## W05 バリアシステム：周りに定期的な波動を出し、一定間隔で敵の弾を1発防ぐ（一覧 docs/game/weapons.md）。
extends WeaponBehavior

var _t := 0.0
var _block_t := 0.0

func radius() -> float:
	return float(p("radius")) * radius_k()

func tick(dt: float, busy: bool) -> void:
	_block_t = maxf(0.0, _block_t - dt)
	if _block_t <= 0.0 and build.projectiles.block_one(state.ship_pos, radius()):
		_block_t = float(p("block_interval")) / rate_k()
	if busy:
		return
	_t += dt
	if _t < float(p("interval")) / rate_k():
		return
	_t = 0.0
	build.combat.explode(state.ship_pos, radius(), atk() * float(p("damage")) * dmg_k(),
		{"cause": &"barrier", "color": Color("#76aaff"), "knock": p("knock"), "life": 0.2})
