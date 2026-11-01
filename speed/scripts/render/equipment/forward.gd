extends WeaponVisual
## ブラスター：砲身を機体の下に重ね、撃つたびに砲口の光、当たった所に十字と輪と火花。

var flashes := ShotFlashes.new()

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	underlay = load("res://assets/pixel/airship_canon.png")

func on_event(ev: Dictionary) -> void:
	frame_event(flashes,ev)

static func frame_event(current: ShotFlashes, ev: Dictionary) -> void:
	if String(ev.get("visual_key", "")) != "weapon/forward": return
	if ev.type == &"weapon_fire": current.fire(float(ev.angle))
	elif ev.type == &"shot_hit": current.hit(ev.pos, ev.dir, 2)

func tick(_dt: float) -> void:
	var p := painter()
	p.begin()
	frame_draw(flashes,p,world_dt(),state.ship_pos,state.ship_heading,active)
	p.end()

static func frame_draw(current: ShotFlashes, p: PixelPainter, dt: float, pos: Vector2, heading: Vector2, enabled: bool) -> void:
	if enabled: current.draw(p,dt,pos+heading*16.0*p.px)
