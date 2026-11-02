extends WeaponVisual
## クリティカルランス：今の光の槍（light_lance）の形のまま青く描く。発射の瞬間に機首が光って小さな光の点が扇に開き、
## 貫いた敵は一瞬白く光って、ばらばらの向き・速さ・寿命の火花（白・淡い青・青）を散らす。

var flashes: Array[Dictionary] = []
var hits: Array[Dictionary] = []

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	attach("res://scripts/render/light_lance.gd", "CriticalLances", 1)

func tick(dt: float) -> void:
	node.step(0.0 if state.hitstop > 0.0 else dt, cfg.character_scale, rm.cam_zoom)
	var wdt := world_dt()
	var p := painter()
	p.begin()
	for f in flashes:
		f.age += wdt
		var q: float = f.age / 0.12
		if q >= 1.0: continue
		var nose := state.ship_pos + state.ship_heading * 9.0 * p.px
		p.disk(nose, 5.0 * (1.0 - q) + 2.0, Color.WHITE if q < 0.5 else Color("#8fc0ff"))
		for i in 5:
			var a := state.ship_heading.angle() + (i / 5.0 - 0.5) * 1.4
			p.dot(nose + Vector2.from_angle(a) * (4.0 + 10.0 * q) * p.px, Color("#cfe6ff"))
	flashes = flashes.filter(func(f): return f.age < 0.12)
	for h in hits:
		h.age += wdt
		if h.age < 0.08: p.disk(h.pos, h.r + 2.0, Color.WHITE)
		for s in h.sparks:
			var q: float = h.age / s.life
			if q >= 1.0: continue
			var d: float = h.r + s.v * (1.0 - pow(1.0 - q, 2.0))
			p.dot(h.pos + Vector2.from_angle(s.a) * d * p.px, s.c, 2 if q < 0.5 else 1)
	hits = hits.filter(func(h): return h.age < 0.4)
	p.end()

func on_event(event: Dictionary) -> void:
	if not active or event.type != &"critical_lance": return
	node.fire(event)
	flashes.append({"age": 0.0})
	# 槍の通り道にいる敵へ火花（表示だけ。当たりの判定は light_lances が受け持つ）。
	var t: EnemyTable = behavior.ctx.enemies.table
	var cell := 1.82 * cfg.character_scale
	for i in t.alive.size():
		if t.alive[i] == 0 or t.dead[i] != 0: continue
		if Geom.seg_circle_t(event.from, event.to, t.pos[i], t.r[i] + float(event.width) * 0.5) < 0.0: continue
		var sparks: Array[Dictionary] = []
		for k in 4 + randi() % 7:
			sparks.append({"a": (randf() - 0.5) * 2.2 + (PI if randf() < 0.25 else 0.0) + (event.to - event.from).angle(),
				"v": 8.0 + randf() * 30.0, "life": 0.12 + randf() * 0.28,
				"c": Color.WHITE if randf() < 0.4 else (Color("#a8d0ff") if randf() < 0.5 else Color("#5a96ff"))})
		hits.append({"pos": t.pos[i], "r": t.r[i] / cell * 0.55, "age": 0.0, "sparks": sparks})

func finished() -> bool:
	return not active and node.shots.is_empty()

## 通知の命中位置だけを使う。ゲーム側の敵表や命中処理へ戻らない。
static func frame_event(flashes: Array, hits: Array, event: Dictionary, pixel: float) -> void:
	if event.type==&"critical_lance": flashes.append({"age":0.0})
	if event.type!=&"critical_lance_hit": return
	var sparks: Array[Dictionary] = []
	for k in 4+randi()%7:
		sparks.append({"a":(randf()-0.5)*2.2+(PI if randf()<0.25 else 0.0)+event.direction.angle(),"v":8.0+randf()*30.0,"life":0.12+randf()*0.28,"c":Color.WHITE if randf()<0.4 else (Color("#a8d0ff") if randf()<0.5 else Color("#5a96ff"))})
	hits.append({"pos":event.pos,"r":event.radius/pixel*0.55,"age":0.0,"sparks":sparks})

static func frame_draw(p: PixelPainter, flashes: Array, hits: Array, dt: float, ship_pos: Vector2, heading: Vector2) -> void:
	for f in flashes:
		f.age += dt
		var q: float = f.age / 0.12
		if q >= 1.0: continue
		var nose := ship_pos + heading * 9.0 * p.px
		p.disk(nose, 5.0 * (1.0 - q) + 2.0, Color.WHITE if q < 0.5 else Color("#8fc0ff"))
		for i in 5:
			var a := heading.angle() + (i / 5.0 - 0.5) * 1.4
			p.dot(nose + Vector2.from_angle(a) * (4.0 + 10.0 * q) * p.px, Color("#cfe6ff"))
	flashes.assign(flashes.filter(func(f): return f.age < 0.12))
	for h in hits:
		h.age += dt
		if h.age < 0.08: p.disk(h.pos, h.r + 2.0, Color.WHITE)
		for s in h.sparks:
			var q: float = h.age / s.life
			if q >= 1.0: continue
			var d: float = h.r + s.v * (1.0 - pow(1.0 - q, 2.0))
			p.dot(h.pos + Vector2.from_angle(s.a) * d * p.px, s.c, 2 if q < 0.5 else 1)
	hits.assign(hits.filter(func(h): return h.age < 0.4))

## 保存した表示値を既存の式へ渡す。火花の乱数は新しい通知値を受けた時だけ作る。
static func frame_state(cache: Dictionary, flashes: Array, hits: Array, values: Array, pixel: float) -> void:
	var alive := {}
	flashes.clear()
	hits.clear()
	for value: Dictionary in values:
		alive[value.id] = true
		if not cache.has(value.id):
			var new_flashes: Array = []
			var new_hits: Array = []
			var event: Dictionary = value.duplicate()
			event.type = &"critical_lance_hit" if value.hit else &"critical_lance"
			frame_event(new_flashes,new_hits,event,pixel)
			cache[value.id] = new_hits[0] if value.hit else new_flashes[0]
		var display: Dictionary = cache[value.id]
		display.age = value.age
		if value.hit: hits.append(display)
		else: flashes.append(display)
	for id in cache.keys():
		if not alive.has(id): cache.erase(id)
