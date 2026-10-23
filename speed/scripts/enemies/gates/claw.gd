## ハサミ（かに座）：背面と同じ。挟んだ直後（ハサミが開いたまま。mode が RECOVER）なら正面からでも倒せる。
extends "res://scripts/enemies/gates/back.gd"

func check(m: EnemySystem, i: int, hit: Vector2, dir: Vector2, cause: StringName, dmg: float) -> int:
	if m.table.mode[i] == EnemyTable.Mode.RECOVER:
		return EnemyTable.GateResult.ALLOW
	return super(m, i, hit, dir, cause, dmg)
