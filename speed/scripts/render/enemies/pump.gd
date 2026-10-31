## ポンプ座の見た目と、吸い込まれていく敵の演出。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true
	events = [&"swallow"]

const PUMP := preload("res://scripts/enemies/pump.gd")
## 吸い込まれていく敵（回りながら小さくなって口へ飛び込む）
var swallows: Array = []

func on_event(ev: Dictionary) -> void:
	if swallows.size() < 120:
		swallows.append({"type": ev.enemy_type, "pos": ev.pos, "r": ev.r, "facing": ev.facing, "color": ev.color,
			"row": ev.row, "id": ev.id, "spin": ev.spin, "life": 0.3, "max": 0.3})

func update(dt: float) -> void:
	for f in swallows:
		f.life -= dt
	swallows = swallows.filter(func(f): return f.life > 0.0)

func draw_layer(c: CanvasItem, _view: Rect2) -> void:
	_draw_swallows(c)

## ポンプ座の原画（24×37px）の継ぎ目。口がある画像の上側を正に取る。
const PUMP_SEAMS := [[10.0, 9.0], [0.5, 6.0], [-7.5, 9.0]]

## ポンプ座：吸い込んだ数に応じて継ぎ目から光が漏れ、口へ流れ込む吸い込みの筋を描く。
## 構えている間は胴体が張り詰めて脈打ち、継ぎ目が強く光り、口元に巨大な塊がせり出す。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var dp: Dictionary = t.def[i].params
	var full := clampf(float(t.buds[i]) / float(dp.store_max), 0.0, 1.0)
	var aiming := t.mode[i] == EnemyTable.Mode.WINDUP
	var px := r * 2.0 / 37.0
	var u := Vector2.from_angle(t.facing[i])
	var side := Vector2(-u.y, u.x)
	var mouth := p + u * r * PUMP.MOUTH
	var now := state.world_time
	if t.mode[i] == EnemyTable.Mode.MOVE:
		# 口へ流れ込む吸い込みの筋（外から口へ動く短い光）
		for k in 9:
			var phase := fmod(now * 1.4 + k * 0.381966, 1.0)
			var ang := t.facing[i] + (float(k) - 4.0) * 0.26
			var dist := r * (2.6 - 2.2 * phase)
			var head := mouth + Vector2.from_angle(ang) * dist
			var tail := mouth + Vector2.from_angle(ang) * (dist + r * 0.5)
			c.draw_line(tail, head, Color(t.color[i].lightened(0.55), 0.55 * sin(phase * PI)), _px(2.0))
	# 継ぎ目から漏れる光：吸い込むほど強く、構えると白熱して脈打つ
	var pulse := 0.5 + 0.5 * sin(now * (22.0 if aiming else 5.0))
	var glow := Color("#fff0c8") if aiming else t.color[i].lightened(0.55)
	var a := (0.85 + 0.15 * pulse) if aiming else full * (0.55 + 0.25 * pulse)
	if a > 0.02:
		for seam in PUMP_SEAMS:
			var center: Vector2 = p + u * float(seam[0]) * px
			var half: Vector2 = side * float(seam[1]) * px * 0.92
			c.draw_line(center - half, center + half, Color(glow, a * 0.35), maxf(_px(2.0), px * 4.5))
			c.draw_line(center - half, center + half, Color(glow, a), maxf(_px(1.0), px * 1.6))
	if aiming:
		# 張り詰めた胴体の縁と、口元にせり出す塊
		c.draw_arc(p + u * -3.0 * px, 16.5 * px * (1.03 + 0.03 * pulse), 0, TAU, 48, Color(glow, 0.55 + 0.35 * pulse), maxf(_px(2.0), px * 1.5))
		var ball := float(dp.shell_r) * (0.35 + 0.65 * t.charge[i])
		var at := mouth + u * ball * 0.55
		rm._attack_visual("shell").draw_ball(c, at, ball, t.color[i], now)

## ポンプ座に吸い込まれていく敵。自転しながら小さくなり、ポンプ座の口へ飛び込む。
func _draw_swallows(c: CanvasItem) -> void:
	var t := run.enemies.table
	for sw in swallows:
		var k := 1.0 - float(sw.life) / float(sw.max)
		var target: Vector2 = sw.pos
		if run.enemies.is_same(sw.row, sw.id):
			target = t.pos[sw.row] + Vector2.from_angle(t.facing[sw.row]) * t.r[sw.row] * PUMP.MOUTH
		var p: Vector2 = (sw.pos as Vector2).lerp(target, k * k)
		var r: float = rm.enemy_sprite_radius(sw.type, sw.r) * (1.0 - 0.85 * k)
		var angle: float = sw.facing + float(sw.spin) * (float(sw.max) - float(sw.life))
		var tex := rm._enemy_texture(sw.type)
		if tex == null:
			c.draw_circle(p, r, sw.color)
			continue
		var size := tex.get_size() / maxf(tex.get_width(), tex.get_height()) * r * 2.0
		c.draw_set_transform(p, rm._enemy_sprite_angle(sw.type, angle))
		c.draw_texture_rect(tex, Rect2(-size / 2.0, size), false)
		c.draw_set_transform(Vector2.ZERO)
