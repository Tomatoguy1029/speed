## ケフェウス座の見た目と、兵の召喚の予告。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true
	events = [&"summon_mark"]

## 兵を召喚する位置の予告
var summon_marks: Array = []

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	super(c, t, i)
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		# 召喚の間、王冠の光が強まる
		var p := t.pos[i]
		var r := t.r[i]
		var k := t.charge[i]
		c.draw_arc(p, r * (1.15 + 0.3 * k), 0, TAU, 40, Color(1.0, 0.85, 0.4, 0.35 + 0.5 * k), _px(3.0))
		c.draw_circle(p - Vector2.from_angle(t.facing[i]) * r * 0.55, r * (0.15 + 0.2 * k), Color(1.0, 0.92, 0.6, 0.5 + 0.4 * k))

func on_event(ev: Dictionary) -> void:
	summon_marks.append({"pos": ev.pos, "king": ev.king, "color": ev.color, "life": ev.life, "max": ev.life})

func update(dt: float) -> void:
	for f in summon_marks:
		f.life -= dt
	summon_marks = summon_marks.filter(func(f): return f.life > 0.0)

func draw_layer(c: CanvasItem, _view: Rect2) -> void:
	_draw_summon_marks(c)

## ケフェウス座の召喚の予告：王から金の光が伸び、兵が現れる位置に紋章の輪が閉じていく。
func _draw_summon_marks(c: CanvasItem) -> void:
	for m in summon_marks:
		var k := 1.0 - float(m.life) / float(m.max)
		var col: Color = (m.color as Color).lightened(0.35)
		var at: Vector2 = m.pos
		c.draw_line(m.king, at, Color(1.0, 0.85, 0.45, 0.25 + 0.35 * k), _px(2.0))
		c.draw_arc(at, 30.0 * (1.6 - 0.6 * k), 0, TAU, 32, Color(col, 0.4 + 0.5 * k), _px(2.5))
		for q in 5:
			var a := state.world_time * 2.0 + q * TAU / 5.0
			c.draw_line(at + Vector2.from_angle(a) * 18.0, at + Vector2.from_angle(a) * (26.0 + 10.0 * (1.0 - k)), Color(1.0, 0.85, 0.45, 0.6 * k), _px(2.0))
		c.draw_circle(at, 6.0 + 8.0 * k, Color(1.0, 0.95, 0.75, 0.3 + 0.5 * k))
