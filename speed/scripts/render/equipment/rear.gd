extends WeaponVisual
## リアブラスター：背中の砲台。撃つたびに砲口の光と、横へ飛ぶ薬莢。当たり方はブラスターと同じ。
const BASE := preload("res://assets/pixel/airship_turret_base.png")
const TURRET := preload("res://assets/pixel/airship_turret.png")
func draw_extra(c: CanvasItem, ship_pos: Vector2, color: Color) -> void:
	c.draw_set_transform(ship_pos, state.ship_heading.angle() + PI / 2.0)
	c.draw_texture_rect(BASE, Rect2(Vector2(-BASE.get_width() / 2.0, -20.0) * cfg.character_scale,
		BASE.get_size() * cfg.character_scale), false, visual_color(color))
	var mount: Vector2 = behavior.mount_position() + (ship_pos - state.ship_pos)
	if behavior.recoil > 0.0: mount += state.ship_heading * (2.0 if behavior.recoil > 0.06 else 1.0) * 1.82 * cfg.character_scale
	var aim: Vector2 = behavior.aim_direction()
	c.draw_set_transform(mount, aim.angle() - PI / 2.0)
	c.draw_texture_rect(TURRET, Rect2(-behavior.MOUNT_PIXEL * cfg.character_scale,
		rm._ship_visual.AIRSHIP.get_size() * cfg.character_scale), false, visual_color(color))
	c.draw_set_transform(Vector2.ZERO)

var flashes := ShotFlashes.new()
var shells: Array[Dictionary] = []

func on_event(ev: Dictionary) -> void:
	if String(ev.get("visual_key", "")) != "weapon/rear": return
	if ev.type == &"weapon_fire":
		flashes.fire(float(ev.angle))
		var u := state.ship_heading
		var side := Vector2(-u.y, u.x) * (30.0 + randf() * 20.0) + Vector2(randf() - 0.5, 0.0) * 10.0
		shells.append({"pos": behavior.mount_position(), "vel": side, "age": 0.0})
	elif ev.type == &"shot_hit": flashes.hit(ev.pos, ev.dir, 2)

func tick(_dt: float) -> void:
	var p := painter()
	p.begin()
	if active:
		var dt := world_dt()
		var tip: Vector2 = behavior.mount_position() + behavior.aim_direction() * 9.0 * p.px
		flashes.draw(p, dt, tip)
		_shells(p, dt)
	p.end()

## 薬莢：横へ飛び、毎秒0.05倍に減速しながら0.35秒で消える。明るい2ドットと暗い1ドットを交互に見せて回って見せる。
func _shells(p: PixelPainter, dt: float) -> void:
	var damping := pow(0.05, dt)
	for s in shells:
		s.age += dt
		s.pos += s.vel * p.px * dt
		s.vel *= damping
		var frame := int(s.age * 30.0) % 2
		var c := Color("#ffd27a") if frame == 1 else Color("#b07a14")
		c.a = 1.0 - s.age / 0.35
		var cell := p.cell(s.pos)
		p.fill(cell.x, cell.y, c, 2 if frame == 1 else 1, 1)
	shells = shells.filter(func(s): return s.age < 0.35)
