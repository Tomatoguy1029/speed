## 敵の表から発射位置と値を渡し、弾の種類へ生成を委ねる。
extends AttackKind
func spawn(ps: ProjectileSystem, i: int, angle: float, speed: float, kind: StringName, params := {}) -> void:
	var table := ps.combat.enemies.table
	var values: Dictionary = params if not params.is_empty() else table.def[i].params
	ps.emit_attack(kind, [table.pos[i], table.r[i], angle, speed, values])
	ps.state.emit(&"shoot", {"pos": table.pos[i], "kind": kind})
