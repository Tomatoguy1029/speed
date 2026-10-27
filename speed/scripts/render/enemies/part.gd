## 部位の絵は所有する役者へ渡し、HPなどの共通表示を保つ。
extends EnemyVisual

func draw_body(c: CanvasItem, table: EnemyTable, row: int, pos: Vector2) -> bool:
	var owner := run.bosses.actor_for_row(table.parent[row])
	if owner == null or owner.body_id != table.parent_id[row] or not owner.has_method("draw_head_on"):
		return false
	if not owner.draw_head_on(c, row, pos):
		return false
	rm._draw_enemy_marks(c, table, row)
	return true
