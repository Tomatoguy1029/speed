## 実際に減ったHPにだけ応じる、物理状態を持たない短い表示用パルス。
extends RefCounted
const DURATION := 0.12
const MAX_WHITE := 0.28
const MAX_OFFSET := 2.5
const MAX_ANGLE := 0.0035
const PHASE_RATE := 86.0
const SEED_MODULO := 23
const SEED_RATE := 0.71
const Y_RATE := 1.17
const ANGLE_RATE := 0.83
const OFFSET_SCALE := 0.70710678
var clock := 0.0
var remaining: Dictionary = {}

func pulse(enemy_id: int) -> void:
	if enemy_id > 0: remaining[enemy_id] = DURATION

func tick(real_dt: float) -> void:
	clock += maxf(0.0, real_dt)
	for id in remaining.keys():
		remaining[id] = maxf(0.0, float(remaining[id]) - maxf(0.0, real_dt))
		if remaining[id] <= 0.0: remaining.erase(id)

func sample(enemy_id: int) -> Dictionary:
	var strength := float(remaining.get(enemy_id, 0.0)) / DURATION
	var phase := clock * PHASE_RATE + float(enemy_id % SEED_MODULO) * SEED_RATE
	return {"white": MAX_WHITE * strength,
		"offset": Vector2(sin(phase), cos(phase * Y_RATE)) * MAX_OFFSET * strength * OFFSET_SCALE,
		"angle": sin(phase * ANGLE_RATE) * MAX_ANGLE * strength}

func clear() -> void:
	remaining.clear()

func make_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/boss_hit_feedback.gdshader")
	result.set_shader_parameter("boss_hit_white",0.0)
	return result
