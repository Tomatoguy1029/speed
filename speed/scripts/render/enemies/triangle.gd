## みなみのさんかく座の見た目。中心は描かず、辺を動く星の後ろに赤いレーザーの軌跡を描く。
extends EnemyVisual

## 軌跡の色（外側の暗い縁、本体、中心の明るい芯）
const TRAIL_EDGE := Color("#7a0c1a")
const TRAIL_BODY := Color("#ff2b3d")
const TRAIL_CORE := Color("#ffd2d2")
## 軌跡を太さの違う何段に分けて描くか（ピクセルアートらしい段差）
const TRAIL_STEPS := 6
## 後ろの端の太さ（星の側に対する割合）
const TRAIL_TAIL := 0.4

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## 中心は見えない。
func draw_body(_c: CanvasItem, _table: EnemyTable, _row: int, _pos: Vector2) -> bool:
	return true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if t.mode[i] != EnemyTable.Mode.DASH:
		return
	var w := float(t.def[i].params.trail_width)
	var parts := t.parts[i]
	for k in range(0, parts.size(), 2):
		var j := parts[k]
		if j < 0 or j >= t.alive.size() or t.alive[j] == 0 or t.id[j] != parts[k + 1] or t.dead[j] != 0:
			continue
		var tail: Vector2 = behavior.call(&"vertex", i, k / 2 + t.buds[i])
		_draw_trail(c, tail, t.pos[j], w)

## 後ろ（tail）ほど細い、段差のある赤いレーザー。後ろの端でも TRAIL_TAIL の割合の太さを保つ。
func _draw_trail(c: CanvasItem, tail: Vector2, head: Vector2, w: float) -> void:
	var length := tail.distance_to(head)
	if length < 1.0:
		return
	var u := (head - tail) / length
	var px := _px(1.0)
	for s in TRAIL_STEPS:
		var a := tail + u * length * float(s) / TRAIL_STEPS
		var b := tail + u * length * float(s + 1) / TRAIL_STEPS
		var ww := maxf(snappedf(lerpf(w * TRAIL_TAIL, w, float(s + 1) / TRAIL_STEPS), px * 2.0), px * 2.0)
		c.draw_line(a, b, TRAIL_EDGE, ww + px * 2.0)
		c.draw_line(a, b, TRAIL_BODY, ww)
		c.draw_line(a, b, TRAIL_CORE, maxf(px, snappedf(ww * 0.3, px)))
