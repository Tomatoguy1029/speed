## 追い立てと飛びかかりの値と動き。
@tool
extends BossTechnique

## 最後の猟犬の発進から飛びかかりの予告まで（秒）
@export_range(0,100000,0.01) var gap := 0.1:
	set(value):
		gap = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 9.0:
	set(value):
		cd = value
		_values_dirty = true
