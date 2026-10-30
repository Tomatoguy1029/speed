extends AttackVisual
## 味方の光弾。ブラスター・リアブラスターは太い光弾、スプレッドブラスターは細い光弾、ストライクウィングは曳光弾をドット単位で描く。

var _painter: PixelPainter

func begin_batch() -> void:
	if _painter == null:
		_painter = PixelPainter.new()
		_painter.setup_painter(1.82 * rm.cfg.character_scale)
		_painter.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_painter.modulate = RenderPipeline.plain_color(rm._layers.projectiles)
		rm._layers.projectiles.add_child(_painter)
	_painter.begin()
	super()

func end_batch() -> void:
	if _painter != null: _painter.end()
	super()

func draw_friend(_c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	if _painter == null: return
	var key := String(pr.friend_visual[i])
	var angle := pr.friend_vel[i].angle()
	match key:
		"weapon/forward", "weapon/rear":
			_painter.bolt(pos, angle, 17, 2)
		"weapon/scatter":
			if pr.friend_life[i] < 0.09: _painter.bolt(pos, angle, 3, 0)
			else: _painter.bolt(pos, angle, 6, 1)
		"weapon/interceptor":
			_tracer(pos, angle)

## ストライクウィングの曳光弾：白い先端、ミントの胴4ドット、左右に淡いミント。
func _tracer(pos: Vector2, angle: float) -> void:
	var mint := Color("#8fffe2")
	for k in range(1, 4):
		_painter.along(pos, angle, k, 1.0, Color(mint, 0.4))
		_painter.along(pos, angle, k, -1.0, Color(mint, 0.4))
	for k in range(1, 5):
		_painter.along(pos, angle, k, 0.0, mint)
	_painter.along(pos, angle, 0, 0.0, Color.WHITE)
