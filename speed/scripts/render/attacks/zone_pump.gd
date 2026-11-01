## ポンプ圧縮弾の着弾。自爆・機雷と同じ爆発を、ポンプ専用の設定で描く。
extends "res://scripts/render/attacks/zone_bomber.gd"

const PUMP_KEY := "res://scenes/attacks/zone_pump.tscn"

func burst_key() -> String:
	return PUMP_KEY

func burst_shader() -> Shader:
	return BlastBursts.SHADER

func _create_blasts() -> void:
	super._create_blasts()
	_blasts.key = PUMP_KEY

func _preview_life() -> float:
	var mat := ShaderMaterial.new()
	mat.shader = burst_shader()
	ShaderTuning.apply(mat, PUMP_KEY)
	return BlastBursts._life(mat) * ShaderTuning.burst_time_scale(PUMP_KEY)
