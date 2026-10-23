## みなみのさんかく座の星：位置は親（triangle.gd）が決める。親が倒れたら一緒に消える。
## 親の星が辺を動いている間（親の mode が DASH）は、攻撃を受けない（体当たりは貫通する）。
extends EnemyBehavior

func _init() -> void:
	debug_spawnable = false

func step(i: int, _dt: float) -> void:
	if not self.is_same(table.parent[i], table.parent_id[i]) or table.dead[table.parent[i]] != 0:
		mark_dead(i)
	table.vel[i] = Vector2.ZERO

func gate(i: int, hit: Vector2, dir: Vector2, cause: StringName, dmg: float) -> int:
	var parent := table.parent[i]
	if self.is_same(parent, table.parent_id[i]) and table.mode[parent] == EnemyTable.Mode.DASH:
		return EnemyTable.GateResult.PASS
	return m.gate_rule(i, hit, dir, cause, dmg)
