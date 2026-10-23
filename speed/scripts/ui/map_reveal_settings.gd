## GFX-002 の視覚調整用。値は完成アートの基準ではなく試作の初期値。
extends Resource

@export_group("線の伸長")
@export_range(0.0, 2.0, 0.01, "suffix:s") var line_duration := 0.22
## 1 は等速。大きいほど線の先端がゆっくり止まる。
@export_range(1.0, 4.0, 0.1) var line_ease := 1.6
@export_group("情報の点灯")
@export_range(0.0, 1.0, 0.01, "suffix:s") var information_delay := 0.035
@export_range(0.0, 2.0, 0.01, "suffix:s") var fade_duration := 0.28
@export_range(0.0, 1.0, 0.01) var glow_strength := 0.22
@export_group("モニター")
@export_range(0.0, 1.0, 0.01) var crt_strength := 0.25
@export_range(0.0, 0.1, 0.001) var noise_strength := 0.012
@export_group("星の擬似信号")
@export_range(0.0, 5.0, 0.05) var spectrum_speed := 1.3
@export_range(0.0, 1.0, 0.01) var spectrum_motion := 0.85
@export_range(0.0, 1.0, 0.01) var spectrum_correlation := 0.72
