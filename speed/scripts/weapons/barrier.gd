## W05 バリアシステム：周りに定期的な波動を出し、一定間隔で敵の弾を1発防ぐ（一覧 docs/game/catalog/weapons.md）。
extends WeaponBehavior
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")

var _t := 0.0
var _block_t := 0.0

func radius() -> float:
	return float(p("radius")) * radius_k()

func tick(dt: float, busy: bool) -> void:
	_block_t = maxf(0.0, _block_t - dt)
	if _block_t <= 0.0 and ctx.projectiles.block_one(state.ship_pos, radius()):
		_block_t = interval(float(p("block_interval")) / rate_k())
	if busy:
		return
	_t += dt
	if _t < interval(float(p("interval")) / rate_k()):
		return
	_t = 0.0
	ctx.combat.explode(state.ship_pos, radius(), atk() * float(p("damage")) * dmg_k(),
		{"cause": &"barrier", "color": EFFECT_SETTINGS.tinted("weapon/barrier", Color("#76aaff")), "knock": p("knock"), "life": 0.2})
