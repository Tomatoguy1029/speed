## 特殊な倒し方（EnemyDef.gate）の共通ルールの土台。ルールごとに res://scripts/enemies/gates/<名前>.gd で上書きする。
##
## 同じルールを複数の種類の敵が使う。EnemySystem は、その戦いで使うルールだけを作る。
class_name EnemyGate
extends RefCounted

## 攻撃（cause）が、位置 hit に向き dir で当たったときの扱い（EnemyTable.GateResult）。dmg は当たった攻撃のダメージ。
func check(_m: EnemySystem, _i: int, _hit: Vector2, _dir: Vector2, _cause: StringName, _dmg: float) -> int:
	return EnemyTable.GateResult.ALLOW

## 体当たりが通ったときのダメージ。
func ram_damage(_m: EnemySystem, _i: int, dmg: float) -> float:
	return dmg
