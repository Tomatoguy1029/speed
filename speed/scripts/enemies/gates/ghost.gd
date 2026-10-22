## すり抜け（うみへび座の本体）：体当たりも武器もすり抜ける（ダメージなし、弾かれない）。
extends EnemyGate

func check(_m: EnemySystem, _i: int, _hit: Vector2, _dir: Vector2, _cause: StringName, _dmg: float) -> int:
	return EnemyTable.GateResult.PASS
