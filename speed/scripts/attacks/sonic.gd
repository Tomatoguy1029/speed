## 機体の移動に沿う衝撃波。武器と特性で命中済みの記録・同時数を共有する。
extends RunSystem
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")

var waves: Array = []
var _buf := PackedInt32Array()

## 機体の位置に衝撃波を出す。0.5実秒、機体と一緒に進路を進み、同じ波動では各敵に1回だけ当たる。
func fire(cause: StringName, radius: float, dmg: float, knock: float, travel: float) -> void:
	var wave := {"pos": state.ship_pos, "radius": radius, "dmg": dmg, "cause": cause, "knock": knock,
		"life": travel, "hits": {}}
	waves.append(wave)
	if waves.size() > 4:
		waves.pop_front()
	sweep(wave, state.ship_pos, state.ship_pos)
	var effect_key := "trait/killSonic" if cause == &"killSonic" else "weapon/sonic"
	state.emit(&"ring", {"pos": state.ship_pos, "radius": radius,
		"color": EFFECT_SETTINGS.tinted(effect_key, Color("#c8f7ff")), "life": 0.5})
	state.emit(&"sonic", {"pos": state.ship_pos, "radius": radius})

func sweep(wave: Dictionary, p0: Vector2, p1: Vector2) -> void:
	var steps := maxi(1, ceili(p0.distance_to(p1) / (wave.radius * 0.3)))
	for k in range(1, steps + 1):
		if state.phase != RunState.Phase.PLAY:
			return
		var p := p0.lerp(p1, float(k) / steps)
		ctx.combat.nearby(p, wave.radius, _buf)
		var t := ctx.enemies.table
		for i in _buf:
			if t.dead[i] != 0 or wave.hits.has(t.id[i]):
				continue
			wave.hits[t.id[i]] = true
			var d := t.pos[i] - p
			var dist := d.length()
			ctx.combat.damage_enemy(i, wave.dmg, {"cause": wave.cause, "dir": d / dist if dist > 0.0 else Vector2.ZERO, "knock": wave.knock})
			if state.phase != RunState.Phase.PLAY:
				return
	wave.pos = p1

func tick(real_dt: float, _world_dt: float) -> void:
	for wave in waves.duplicate():
		if state.phase != RunState.Phase.PLAY:
			return
		if not state.tracing:
			sweep(wave, wave.pos, state.ship_pos)
		wave.life -= real_dt
	waves = waves.filter(func(w): return w.life > 0.0)

func on_trail(p0: Vector2, p1: Vector2) -> void:
	for wave in waves.duplicate():
		sweep(wave, p0, p1)
		if state.phase != RunState.Phase.PLAY:
			return
