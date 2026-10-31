## ポンプ圧縮弾の着弾。自爆・機雷と同じ爆発を、ポンプ専用の設定で描く。
extends "res://scripts/render/attacks/zone_bomber.gd"

const PUMP_KEY := "res://scenes/attacks/zone_pump.tscn"
@export_range(0.0, 4.0, 0.05) var glow_energy := 1.0
var _preview_revision := -1

func burst_shader() -> Shader:
	return BlastBursts.SHADER

func _create_blasts() -> void:
	super._create_blasts()
	_blasts.key = PUMP_KEY
	_preview_revision = ShaderTuning.SETTINGS.preview_revision
	_apply_glow()

func _apply_glow() -> void:
	var emission := Color(glow_energy, glow_energy, glow_energy, 1.0)
	_blasts.modulate = RenderPipeline.plain_color(rm._layers.fx, emission * effect_tint) if rm != null else emission

func preview_step(dt: float) -> void:
	if _preview_revision != ShaderTuning.SETTINGS.preview_revision:
		# 表示時間・粒数・描画域も、停止中の同じ時刻で作り直す。
		preview_restart(_preview_age)
	super.preview_step(dt)
	_apply_glow()

func _preview_life() -> float:
	var mat := ShaderMaterial.new()
	mat.shader = burst_shader()
	ShaderTuning.apply(mat, PUMP_KEY)
	return BlastBursts._life(mat)
