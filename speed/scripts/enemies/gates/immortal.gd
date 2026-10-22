## 不死の首（うみへび座）：貫いたときだけ倒せる。火では焼けない。
## 装甲を貫いた体当たりは、その1回で本体への攻撃になる。通常の頭の HP を繰り返し削る必要はない。
extends EnemyGate

func check(_m: EnemySystem, _i: int, _hit: Vector2, _dir: Vector2, cause: StringName, _dmg: float) -> int:
	return EnemyTable.GateResult.ALLOW if cause == &"ram" else EnemyTable.GateResult.PASS

func ram_damage(m: EnemySystem, i: int, dmg: float) -> float:
	return maxf(dmg, m.table.hp[i])
