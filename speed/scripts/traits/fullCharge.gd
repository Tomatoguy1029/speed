## T04 ギアアップ：基本の満タンの線の長さまで、距離に応じて指数曲線で強くなる。
extends TraitBehavior
func multiplier(distance: float) -> float:
	var x := clampf(distance / cfg.draw_length, 0.0, 1.0)
	return 1.0 + (val("mult") - 1.0) * (exp(3.0 * x) - 1.0) / (exp(3.0) - 1.0)
func on_launch(_full: bool) -> void:
	ctx.combat.ignore_armor = false
	ctx.combat.burst_power = 1.0
func on_trail(_run: TraceRun, _p0: Vector2, _p1: Vector2) -> void:
	ctx.combat.burst_power = multiplier(ctx.loadout.boost_distance)
