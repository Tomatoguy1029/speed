## 背面：攻撃が背面から来たときだけ倒せる。前から当たった体当たりは弾かれる（失敗）。
extends EnemyGate

func check(m: EnemySystem, i: int, _hit: Vector2, dir: Vector2, cause: StringName, _dmg: float) -> int:
	var t := m.table
	var arc: float = t.def[i].params.get("front_arc", 1.6)
	if dir != Vector2.ZERO and absf(Geom.angle_diff(dir.angle(), t.facing[i])) < PI - arc:
		return EnemyTable.GateResult.ALLOW
	return EnemyTable.GateResult.BOUNCE if cause == &"ram" else EnemyTable.GateResult.PASS
