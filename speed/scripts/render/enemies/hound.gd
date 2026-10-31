## 猟犬の攻撃予告。専用外観がないときだけ共通の矢じりに耳を添える。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	super(c, t, i)
	if rm.look_of(t.type[i]) != null: return
	var u := Vector2.from_angle(t.facing[i])
	var side := u.orthogonal()
	var r := t.r[i]
	for sign: float in [-1.0, 1.0]:
		c.draw_colored_polygon(PackedVector2Array([
			t.pos[i] + u * r * 0.1 + side * r * 0.35 * sign,
			t.pos[i] - u * r * 0.45 + side * r * 0.85 * sign,
			t.pos[i] - u * r * 0.65 + side * r * 0.25 * sign,
		]), Color.WHITE if behavior.warning(i) else t.color[i].lightened(0.25))

## 白い予告は個体の期限だけを読み、既存の本体と耳を同じ白へ寄せる。
func draw_body(c: CanvasItem, t: EnemyTable, i: int, pos: Vector2) -> bool:
	if not behavior.warning(i): return false
	var radius := sprite_radius(t, i)
	for layer in range(3, 0, -1):
		c.draw_circle(pos, radius * (1.0 + layer * 0.22), Color(1, 1, 1, 0.08))
	var batch := rm._ensure_enemy_batch(t.type[i])
	var angle := rm._enemy_sprite_angle(t.type[i], t.facing[i])
	var color := Color(1, 0, 0, 1)
	if rm._shape_ids.has(t.type[i]):
		angle = t.facing[i]
		color = Color.WHITE
	batch.add(pos, angle, radius, color)
	if rm._armor_batches.has(t.type[i]): rm._armor_batches[t.type[i]].add(pos, angle, radius, Color(1, 0, 0, 1))
	draw_marks(c, t, i)
	return true
