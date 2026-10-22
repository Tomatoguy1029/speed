## 回る丸鋸：攻撃では壊れない（体当たりで飛ばす扱いは CombatSystem）。
extends EnemyGate

func check(_m: EnemySystem, _i: int, _hit: Vector2, _dir: Vector2, _cause: StringName, _dmg: float) -> int:
	return EnemyTable.GateResult.PASS
