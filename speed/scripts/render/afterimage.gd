## 残像機の表示。自機の元絵を発光する分身として描き、武器のパーツは重ねない。
extends Node2D

const SHIP := preload("res://assets/pixel/airship.png")
const SHADER := preload("res://shaders/afterimage.gdshader")
var _body: DrawLayer
var _copies: Array[Dictionary] = []
var _scale := 1.0
var _clock := 0.0

func _ready() -> void:
	_body = DrawLayer.new()
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.draw_fn = _draw_copies
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_body.material = mat
	add_child(_body)

func step(dt: float, state: RunState, cfg: GameConfig, weapon) -> void:
	_copies.clear()
	_scale = cfg.character_scale
	if weapon != null and state.phase in [RunState.Phase.PLAY, RunState.Phase.PAUSED, RunState.Phase.LEVELUP]:
		for echo in weapon.echoes:
			for copy in echo.copies:
				if float(copy.alpha) > 0.0:
					_copies.append(copy)
		if state.phase == RunState.Phase.PLAY and state.hitstop <= 0.0:
			_clock += dt
	(_body.material as ShaderMaterial).set_shader_parameter("clock", _clock)
	_body.queue_redraw()

func _draw_copies(c: CanvasItem) -> void:
	var rect := Rect2(Vector2(-SHIP.get_width() / 2.0, -30.0), SHIP.get_size())
	for copy in _copies:
		c.draw_set_transform(copy.pos, copy.dir.angle() + PI / 2.0, Vector2.ONE * _scale)
		# 同じ元絵を数ドットずらした段階的な残光。突進曲線を跨ぐ長い直線の尾は作らない。
		for k in range(3, 0, -1):
			c.draw_texture_rect(SHIP, Rect2(rect.position + Vector2(0, k * 4), rect.size), false,
				Color(0.4, 0.85, 1.0, float(copy.alpha) * 0.12 * (4 - k)))
		c.draw_texture_rect(SHIP, rect, false, Color(1, 1, 1, float(copy.alpha) * 0.85))
	c.draw_set_transform(Vector2.ZERO)
