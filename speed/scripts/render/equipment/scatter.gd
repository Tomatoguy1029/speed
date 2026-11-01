extends WeaponVisual
## スプレッドブラスター：砲口で白い閃光と扇状に開く青白い光の線、当たった所に小さな十字と輪と火花。

var flashes := ShotFlashes.new()

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	underlay = load("res://assets/pixel/airship_canon.png")
	flashes.muzzle_big = 1

func on_event(ev: Dictionary) -> void:
	if String(ev.get("visual_key", "")) != "weapon/scatter": return
	if ev.type == &"weapon_fire": flashes.fire(float(ev.angle))
	elif ev.type == &"shot_hit": flashes.hit(ev.pos, ev.dir, 0)

func tick(_dt: float) -> void:
	var p := painter()
	p.begin()
	if active:
		var nose := state.ship_pos + state.ship_heading * 16.0 * p.px
		flashes.draw(p, world_dt(), nose)
		_fan(p, nose, flashes.muzzle_time / 0.1)
	p.end()

## 扇状に開く15本の光の線（0.1秒）。
func _fan(p: PixelPainter, nose: Vector2, q: float) -> void:
	if q < 0.0 or q >= 1.0: return
	for i in 15:
		var a := flashes.muzzle_angle + (i / 14.0 - 0.5) * 1.25
		var length := (6.0 + (i * 7) % 7) * (1.0 if q < 0.5 else 0.6)
		var color := Color("#7fd8ff") if i % 3 != 0 else (Color.WHITE if q < 0.4 else Color("#d8f6ff"))
		var u := Vector2.from_angle(a)
		p.line(nose + u * 2.0 * p.px, nose + u * length * p.px, color)
