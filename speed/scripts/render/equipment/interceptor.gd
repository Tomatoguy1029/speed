extends WeaponVisual
## ストライクウィング：今の機体の絵のまま、撃つたびに砲口の先が白→アンバーに光り、当たった所に火花。
const INTERCEPTOR_VISUAL := preload("res://scripts/render/interceptor_visual.gd")

var sparks := PixelSparks.new()

func on_event(ev: Dictionary) -> void:
	if ev.type == &"shot_hit" and String(ev.get("visual_key", "")) == "weapon/interceptor":
		sparks.add(ev.pos, 4, ev.dir.angle() + PI, 2.0, 25.0, 70.0, 0.16, [Color.WHITE, Color("#8fffe2"), Color("#3e9eaa")])

func draw_objects(c: CanvasItem) -> void:
	for d in behavior.drones:
		INTERCEPTOR_VISUAL.drone(c, d.pos, d.angle, cfg.character_scale, d.flash, visual_color(Color.WHITE))

func tick(_dt: float) -> void:
	var p := painter()
	p.begin()
	if active:
		sparks.draw(p, world_dt())
		for d in behavior.drones:
			if d.flash <= 0.0: continue
			# 砲口の光：撃った直後の半分は白い3ドット角、そのあとアンバーの2ドット角。
			var cell := p.cell(d.pos + Vector2.from_angle(d.angle) * 6.0 * p.px)
			if d.flash > 0.03: p.fill(cell.x - 1, cell.y - 1, Color.WHITE, 3, 3)
			else: p.fill(cell.x - 1, cell.y - 1, Color("#ffc77c"), 2, 2)
	p.end()
