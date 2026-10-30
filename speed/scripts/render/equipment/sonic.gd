extends WeaponVisual
## ソニックブーム：高速の間、機体から音の輪が次々に出て、その場に残って広がる。輪は足し合わせて描くので、
## 重なる所（後ろに伸びる円錐のふち）が明るく光る。機体の後ろにマッハ円錐の淡い蒸気、機首に白い山形。
## 衝撃波に触れた敵には進路側から白い弧が当たり、押されて滑る間は短い筋、威力の瞬間に白くはじけて輪と破片。

const C_RING := Color(190.0 / 255.0, 215.0 / 255.0, 1.0)
const C_VAPOR := Color(235.0 / 255.0, 243.0 / 255.0, 1.0)
var _rings: PixelShapes
var _vapor := 0.0
var _boom_age := 99.0
var _last_pulse := 0.0
## マッハ円錐の開き。細い円錐の間の値を保ち、蒸気が消えていく間は広げない
var _cone := 0.3
var pushes: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var tracks: Dictionary = {}
var sparks := PixelSparks.new()

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	blue_exhaust = true

func dispose() -> void:
	if is_instance_valid(_rings): _rings.queue_free()
	super()

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"sonic_push": pushes.append({"row": ev.row, "id": ev.id, "dir": ev.dir, "age": 0.0})
		&"sonic_impact":
			impacts.append({"pos": ev.pos, "age": 0.0, "big": ev.dead})
			sparks.add(ev.pos, 10 if ev.dead else 5, ev.dir.angle(), 1.3, 50.0, 130.0, 0.26,
				[Color.WHITE, Color("#cfe4ff"), Color("#ff7a6b"), Color("#ffd9cc")])

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	if _rings == null:
		_rings = PixelShapes.new()
		_rings.setup(p.px, PixelShapes.Shape.RING)
		_rings.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_rings.modulate = RenderPipeline.plain_color(rm._layers.fx)
		rm._layers.fx.add_child(_rings)
	_rings.begin()
	p.begin()
	if active:
		_draw_rings(_rings)
		_draw_ship(p, dt)
		_draw_enemies(p, dt)
		sparks.draw(p, dt)
	_rings.end()
	p.end()

## 音の輪：半径 R と R−1 の2重。出てから 0.7 秒で消える。輪は GPU でまとめて描く。
func _draw_rings(r: PixelShapes) -> void:
	var speed: float = behavior.wave_speed()
	var life: float = behavior.wave_life()
	for f in behavior.frames:
		var radius := speed * float(f.age) / r.px
		if radius < 1.0: continue
		var alpha := 0.24 * (1.0 - float(f.age) / life)
		r.add_ring(f.pos, radius, Color(C_RING, alpha), 0.7)

## 機体の後ろのマッハ円錐の蒸気と、機首の白い山形。一定距離ごとの衝撃の瞬間は蒸気が濃くなる。
func _draw_ship(p: PixelPainter, dt: float) -> void:
	var speed: float = behavior.speed / p.px
	var high: bool = (state.tracing or state.glide) and behavior.fast()
	# 蒸気は細い円錐が見える速さ（円錐の半角が35度以下）の間だけ出す。遅いと円錐が横へ開くので出さない
	var ring_speed: float = behavior.wave_speed() / p.px
	var cone_now := asin(minf(0.99, ring_speed / maxf(speed, ring_speed + 1.0)))
	var supersonic := high and cone_now <= deg_to_rad(35.0)
	if supersonic: _cone = cone_now
	_vapor += ((1.0 if supersonic else 0.0) - _vapor) * minf(1.0, dt * 6.0)
	_boom_age += dt
	if behavior.pulse > _last_pulse: _boom_age = 0.0
	_last_pulse = behavior.pulse
	var level := _vapor * (0.28 + 0.35 * exp(-_boom_age * 6.0))
	var u := state.ship_heading
	var n := u.orthogonal()
	if level > 0.02:
		var cone := _cone
		for i in 40:
			var k := float((i * 37) % 40) / 40.0
			var back := 4.0 + k * 20.0
			var half := back * tan(cone) * (0.35 + 0.65 * float((i * 53) % 10) / 10.0)
			var side := half if i % 2 else -half
			p.dot(state.ship_pos - u * back * p.px + n * side * p.px, Color(C_VAPOR, level * (1.0 - k * 0.6)))
	if high:
		for i in 4:
			p.dot(state.ship_pos + u * (9 - i) * p.px + n * i * p.px, Color.WHITE)
			p.dot(state.ship_pos + u * (9 - i) * p.px - n * i * p.px, Color.WHITE)

## 押された敵：白い衝撃の弧（0.07秒）と、滑っている間の短い筋。威力の瞬間の白い円と輪。
func _draw_enemies(p: PixelPainter, dt: float) -> void:
	var t: EnemyTable = behavior.ctx.enemies.table
	for push in pushes:
		push.age += dt
		var q: float = push.age / 0.07
		if q >= 1.0 or not behavior.ctx.enemies.is_same(push.row, push.id): continue
		var u: Vector2 = push.dir
		var center: Vector2 = t.pos[push.row] - u * 5.0 * p.px
		for k in range(-3, 4):
			var bend := absf(k) * 0.6
			p.dot(center + u.orthogonal() * k * p.px + u * bend * p.px, Color.WHITE if q < 0.5 else Color("#cfe4ff"))
	pushes = pushes.filter(func(x): return x.age < 0.07)
	var live := {}
	for hit in behavior.pending:
		if not behavior.ctx.enemies.is_same(hit.row, hit.id) or t.dead[hit.row] != 0: continue
		var points: Array = tracks.get(hit.id, [])
		if dt > 0.0: points.append(t.pos[hit.row])
		if points.size() > 10: points.pop_front()
		live[hit.id] = points
		var speed: float = hit.velocity.length() / p.px
		for i in maxi(0, points.size() - 1):
			var k := points.size() - 1 - i
			if speed < 6.0 or k > speed / 7.0 or (k > 3 and k % 2 == 1): continue
			p.dot(points[i], Color("#cfe4ff") if k < 3 else Color("#6f86b0"))
	tracks = live
	for d in impacts:
		d.age += dt
		var q: float = d.age / 0.16
		if q >= 1.0: continue
		if q < 0.35: p.disk(d.pos, 5.0 if d.big else 3.0, Color.WHITE)
		p.ring(d.pos, 2.0 + (9.0 if d.big else 5.0) * q, Color.WHITE if q < 0.4 else Color("#cfe4ff"))
	impacts = impacts.filter(func(d): return d.age < 0.16)
