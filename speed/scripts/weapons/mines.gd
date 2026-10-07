## W07 軌跡機雷：高速で実際に通った線に、一定の間隔で機雷を残す。少し遅れて有効になり、
## 敵が近づくと爆発する（一覧 docs/weapons.md）。
extends WeaponBehavior

## 機雷：pos、life、armed、dmg、radius
var mines: Array = []
var _distance := 0.0
var _buf: Array = []

func on_trail(_run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	var length := p0.distance_to(p1)
	if length < 1e-6:
		return
	var step := float(p("spacing")) / rate_k()
	var d := step - _distance
	while d <= length:
		if mines.size() < int(p("max")):
			mines.append({"pos": p0.lerp(p1, d / length), "life": p("life"), "armed": p("armed"),
				"dmg": atk() * dmg_k() * float(p("damage")), "radius": float(p("radius")) * radius_k()})
		d += step
	_distance = fmod(_distance + length, step)

func tick(dt: float, _busy: bool) -> void:
	for m in mines:
		m.life -= dt
		m.armed -= dt
		if m.armed > 0.0 or m.life <= 0.0:
			continue
		build.combat.nearby(m.pos, float(p("trigger")), _buf)
		if not _buf.is_empty():
			build.combat.explode(m.pos, m.radius, m.dmg, {"cause": &"mine", "color": Color("#ff7b54"), "knock": 300.0, "life": 0.3})
			m.life = 0.0
			if state.phase != RunState.Phase.PLAY:
				return
	mines = mines.filter(func(m): return m.life > 0.0)
