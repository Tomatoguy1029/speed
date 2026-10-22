## 膜：膜が消えている（頂点の星が欠けている。mode が RECOVER）間だけ、中の核を倒せる。
extends EnemyGate

func check(m: EnemySystem, i: int, _hit: Vector2, _dir: Vector2, _cause: StringName, _dmg: float) -> int:
	return EnemyTable.GateResult.ALLOW if m.table.mode[i] == EnemyTable.Mode.RECOVER else EnemyTable.GateResult.PASS
