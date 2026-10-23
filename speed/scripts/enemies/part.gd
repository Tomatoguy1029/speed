## 部位：位置は親が決める。親が倒れたら一緒に消える。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	if not self.is_same(table.parent[i], table.parent_id[i]) or table.dead[table.parent[i]] != 0:
		mark_dead(i)
	table.vel[i] = Vector2.ZERO
