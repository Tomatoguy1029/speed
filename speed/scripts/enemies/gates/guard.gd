## 硬い殻：体当たりは弾かれる（失敗）。武器や波動では壊せる。
extends EnemyGate

func check(_m: EnemySystem, _i: int, _hit: Vector2, _dir: Vector2, cause: StringName, _dmg: float) -> int:
	return EnemyTable.GateResult.BOUNCE if cause == &"ram" else EnemyTable.GateResult.ALLOW
