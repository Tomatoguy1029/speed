extends WeaponVisual
## スプレッドブラスター：砲口で白い閃光と扇状に開く青白い光の線、当たった所に小さな十字と輪と火花。

var flashes := ShotFlashes.new()

static func frame_event(current: ShotFlashes, ev: Dictionary) -> void:
	if String(ev.get("visual_key", "")) != "weapon/scatter": return
	current.muzzle_big = 1
	if ev.type == &"weapon_fire": current.fire(float(ev.angle))
	elif ev.type == &"shot_hit": current.hit(ev.pos, ev.dir, 0)

static func frame_draw(current: ShotFlashes, p: PixelPainter, dt: float, pos: Vector2, heading: Vector2, enabled: bool) -> void:
	if not enabled: return
	var nose := pos+heading*16.0*p.px
	current.draw(p,dt,nose)
	_fan(current,p,nose,current.muzzle_time/0.1)

## 扇状に開く15本の光の線（0.1秒）。
static func _fan(current: ShotFlashes, p: PixelPainter, nose: Vector2, q: float) -> void:
	if q < 0.0 or q >= 1.0: return
	for i in 15:
		var a := current.muzzle_angle + (i / 14.0 - 0.5) * 1.25
		var length := (6.0 + (i * 7) % 7) * (1.0 if q < 0.5 else 0.6)
		var color := Color("#7fd8ff") if i % 3 != 0 else (Color.WHITE if q < 0.4 else Color("#d8f6ff"))
		var u := Vector2.from_angle(a)
		p.line(nose + u * 2.0 * p.px, nose + u * length * p.px, color)
