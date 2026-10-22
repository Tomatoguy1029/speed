## 英雄の力の共通の入口。力ごとの状態は各Behaviorが持つ。
class_name HeroBehavior
extends RunSystem
var def: HeroDef
var enemies: EnemySystem:
	get: return ctx.enemies
var combat: CombatSystem:
	get: return ctx.combat
var projectiles: ProjectileSystem:
	get: return ctx.projectiles
func configure(context: RunContext, definition: HeroDef) -> void:
	setup(context)
	def = definition
func active() -> bool:
	return state.hero_active_t > 0.0 and state.hero_power == def.id
func activate() -> void:
	pass
func trace_width() -> float:
	return 1.0
func capture_first_trace() -> bool:
	return false
