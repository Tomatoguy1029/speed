## りゅう座の吐き出しの光線。口元の光の溜めと、口から伸びる光線を専用の層とshaderで描く。
## 光線の長さは判定と同じ hazard_len を使うので、伸びていく見た目と当たりが一致する。
extends AttackVisual
const PROFILE := "boss/move/draco/inhale"

func _apply_effect_settings() -> void:
	super()
	EFFECT_SETTINGS.apply_key(self, PROFILE, scene_file_path)
	effect_tint = EFFECT_SETTINGS.resolved_values(PROFILE, scene_file_path).get("effect_tint", Color.WHITE)

## 光線が消えるときに薄れる時間
@export_range(0.02, 0.5, 0.01) var fade_seconds := 0.15
var _layer: DrawLayer

func _orb(c: CanvasItem, at: Vector2, half: float, strength: float, seed: float) -> void:
	var size := half * 2.8
	var col := Color(0.0, strength, seed, 1.0)
	var corners := [Vector2(-size, -size), Vector2(size, -size), Vector2(size, size), Vector2(-size, size)]
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(at + corner)
		uvs.append(corner / 1000.0)
	c.draw_polygon(points, PackedColorArray([col, col, col, col]), uvs)

## 口から光線の先までの帯。横は判定の幅より少し広く取り、外側の揺らぎを描く余白にする。
func _strip(c: CanvasItem, at: Vector2, angle: float, length: float, half: float, strength: float, seed: float) -> void:
	var u := Vector2.from_angle(angle)
	var v := u.orthogonal()
	var h := half * 1.6
	var col := Color(1.0, strength, seed, 1.0)
	c.draw_polygon(PackedVector2Array([at - v * h, at + u * length - v * h, at + u * length + v * h, at + v * h]),
		PackedColorArray([col, col, col, col]),
		PackedVector2Array([Vector2(0.0, -h) / 1000.0, Vector2(length, -h) / 1000.0, Vector2(length, h) / 1000.0, Vector2(0.0, h) / 1000.0]))

# C++から来る同じ判定寸法を、通常表示と同じshaderへ渡す。
var _frame_row := {}
func frame_apply(row: Dictionary, pixel: float) -> void:
	_frame_row=row
	visible=false # 見た目は draco_fx の光の奔流が描く
	if material==null:
		var mat:=ShaderMaterial.new()
		mat.shader=load("res://shaders/draco_beam.gdshader")
		mat.set_shader_parameter("noise_tex",load("res://assets/fx/water_noise.png"))
		ShaderTuning.apply(mat,PROFILE,"res://scenes/attacks/beam_draco.tscn")
		material=mat
		EFFECT_SETTINGS.apply_key(self,PROFILE,"res://scenes/attacks/beam_draco.tscn")
	var mat:=material as ShaderMaterial
	var settings: Dictionary=EFFECT_SETTINGS.resolved_values(PROFILE,"res://scenes/attacks/beam_draco.tscn")
	var tint: Color=settings.get("effect_tint",Color.WHITE)
	var color: Color=row.colors[0]
	mat.set_shader_parameter("linear_colors",get_viewport().use_hdr_2d)
	mat.set_shader_parameter("clock",row.clock)
	mat.set_shader_parameter("pixel",pixel*2.0*float(settings.get("pixel_scale",1.0)))
	mat.set_shader_parameter("half0",row.widths[0])
	mat.set_shader_parameter("tint",Vector3(color.r*tint.r,color.g*tint.g,color.b*tint.b))
	mat.set_shader_parameter("opacity",tint.a)
	mat.set_shader_parameter("beam_len",row.length)
	queue_redraw()
func _draw() -> void:
	if _frame_row.is_empty(): return
	var row: Dictionary=_frame_row
	var half: float=row.widths[0]
	var at: Vector2=row.points[0]
	var seed: float=fmod(float(row.order),17.0)/17.0
	if row.time<row.delay:
		_orb(self,at,half,clampf(row.time/maxf(row.delay,0.001),0.0,1.0),seed)
		return
	var strength:=clampf((row.delay+row.active-row.time)/maxf(fade_seconds,0.001),0.0,1.0)
	if row.length>1.0:_strip(self,at,row.angle,row.length,half,strength,seed)
	_orb(self,at,half,strength,seed)
