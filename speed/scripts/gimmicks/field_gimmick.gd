## 仕掛けの共通の入口。FieldSystemの地形・衝突情報を共有する。
class_name FieldGimmick
extends RunSystem
var field: FieldSystem:
	get: return ctx.field
var enemies: EnemySystem:
	get: return ctx.enemies
var projectiles: ProjectileSystem:
	get: return ctx.projectiles
func initialize() -> void:
	pass
