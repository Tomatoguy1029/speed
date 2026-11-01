## 制作時に解決したゲージの色・円帯・目盛り。ラン中は共有して読み取る。
class_name BoostGaugeStyle
extends Resource

@export var normal_color: Color
@export var unavailable_color: Color
@export var path_color: Color
@export var ready_pulse_color: Color
@export var background_color: Color
@export var ready_tick_color: Color
@export var unavailable_tick_color: Color
@export var full_flash_color: Color
@export var bounds: Vector4
@export var tick_width: float
@export var tick_start: float
@export var tick_end: float
