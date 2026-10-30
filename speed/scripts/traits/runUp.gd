## T32 助走：最初の接触だけに距離の倍率と範囲攻撃を加える。
extends TraitBehavior
var first := true
var strength := 0.0
func on_launch(_full: bool) -> void:
	first = true
	strength = 0.0
func multiplier(distance: float) -> float:
	if not first: return 1.0
	var x := clampf(distance / float(def.params.distance), 0.0, 1.0)
	strength = (exp(3.0 * x) - 1.0) / (exp(3.0) - 1.0)
	return 1.0 + (val("mult") - 1.0) * strength
func on_contact(_i: int, hit: Vector2, dir: Vector2, damage: float) -> void:
	if not first or not state.tracing: return
	first = false
	var radius := val("radius") * strength * ctx.loadout.area_multiplier()
	if radius > 0.0:
		ctx.combat.explode(hit, radius, damage * float(def.params.area_damage), {"cause": &"runUp", "knock": 0.0, "life": 0.2})
	state.emit(&"run_up_hit", {"pos": hit, "dir": dir, "strength": strength})
