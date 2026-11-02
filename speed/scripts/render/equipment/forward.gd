extends WeaponVisual
## ブラスター：砲身を機体の下に重ね、撃つたびに砲口の光、当たった所に十字と輪と火花。

var flashes := ShotFlashes.new()

static func frame_event(current: ShotFlashes, ev: Dictionary) -> void:
	if String(ev.get("visual_key", "")) != "weapon/forward": return
	if ev.type == &"weapon_fire": current.fire(float(ev.angle))
	elif ev.type == &"shot_hit": current.hit(ev.pos, ev.dir, 2)

static func frame_draw(current: ShotFlashes, p: PixelPainter, dt: float, pos: Vector2, heading: Vector2, enabled: bool) -> void:
	if enabled: current.draw(p,dt,pos+heading*16.0*p.px)
