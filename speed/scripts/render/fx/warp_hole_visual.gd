## ワープホールの表示。C++の位置・半径・消える時刻と世界時刻から開閉と点滅を決め、絵は warp_hole.gdshader で描く。
extends Sprite2D

## 開ききるまでの世界秒
const OPEN_TIME := 0.6
## 消える前に点滅しながら縮む世界秒
const CLOSE_TIME := 1.0
## 絵の半径 ÷ 穴の半径（縁の外の光と四芒星を含める）
const EXTENT := 1.35
const NOISE := preload("res://assets/effects/build/burst_noise.tres")

var _born := -1.0
var _gone := -1.0

func _init() -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(image)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/warp_hole.gdshader")
	mat.set_shader_parameter("extent", EXTENT)
	mat.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	material = mat
	visible = false

## warp：値型フレームの position・radius・gone・time。pixel：絵の1ドットの世界での大きさ。
func apply(warp: Dictionary, pixel: float) -> void:
	var gone := float(warp.get("gone", -1.0))
	var now := float(warp.get("time", 0.0))
	if gone < 0.0 or now >= gone:
		visible = false
		_gone = -1.0
		return
	if gone != _gone or now < _born:
		_gone = gone
		_born = now
	var radius := float(warp.radius)
	var age := now - _born
	var left := gone - now
	var close := smoothstep(0.0, CLOSE_TIME, left)
	position = warp.position
	scale = Vector2.ONE * radius * EXTENT * 2.0
	visible = true
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("time", fmod(now, 1000.0))
	mat.set_shader_parameter("size", smoothstep(0.0, OPEN_TIME, age) * (0.4 + 0.6 * close))
	mat.set_shader_parameter("blink", 1.0 if left > CLOSE_TIME else 0.6 + 0.4 * signf(sin(now * 40.0)))
	mat.set_shader_parameter("cells", maxf(8.0, radius * EXTENT * 2.0 / maxf(pixel, 0.01)))
