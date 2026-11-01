## 生成した静止画の輪郭を固定し、表示範囲・位置・光だけを動かす確認用シーン。
extends Control
@export var autoplay := true
@export_range(0.5, 2.0) var playback_speed := 1.0
var elapsed := 0.0
var _art: TextureRect
func _ready() -> void:
	_art = $Artwork
	_art.material = _art.material.duplicate()
	set_time(0.0)
func _process(delta: float) -> void:
	if autoplay: set_time(fmod(elapsed + delta * playback_speed, 3.5))
func set_time(seconds: float) -> void:
	elapsed = seconds
	if _art != null: _art.material.set_shader_parameter("elapsed", elapsed)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_time(0.0)
		accept_event()
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		set_time(0.0)
		get_viewport().set_input_as_handled()
