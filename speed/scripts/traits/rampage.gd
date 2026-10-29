## T33 快進撃：ブースト後の全攻撃を強化し、時間とともに弱まる。
extends TraitBehavior
var kills := 0
var strength := 0.0
var pop := 0.0
func on_launch(_full: bool) -> void:
	kills = 0
	strength = 0.0
func on_kill(_cause: StringName) -> void:
	if state.tracing:
		kills += 1
		pop = 1.0
func on_end() -> void:
	strength = minf(1.0, float(kills) / float(def.params.kills))
func multiplier() -> float:
	return 1.0 + val("bonus") * strength
func tick(dt: float, _busy: bool) -> void:
	if not state.tracing: strength *= pow(0.5, dt / float(def.params.half_life))
	pop = maxf(0.0, pop - dt * 5.0)
