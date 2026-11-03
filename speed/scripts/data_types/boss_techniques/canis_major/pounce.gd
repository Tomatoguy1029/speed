## 飛びかかりの値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.45:
	set(value):
		active = value
		_values_dirty = true
## 群れが少ないとみなす猟犬の数
@export_range(0,100000,1) var alone_hounds := 3:
	set(value):
		alone_hounds = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 4.0:
	set(value):
		cd = value
		_values_dirty = true
## 群れが少ないときの再使用待ち（秒）
@export_range(0,100000,0.01) var cd_alone := 2.0:
	set(value):
		cd_alone = value
		_values_dirty = true
## 群れが少ないときの再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_alone_p2 := 1.5:
	set(value):
		cd_alone_p2 = value
		_values_dirty = true
## 再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_p2 := 3.0:
	set(value):
		cd_p2 = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 24.0:
	set(value):
		damage = value
		_values_dirty = true
## 狙いを固定する時間（秒）
@export_range(0,100000,0.01) var lock := 0.2:
	set(value):
		lock = value
		_values_dirty = true
## 着地点の先までの距離
@export_range(0,100000,0.01) var overshoot := 80.0:
	set(value):
		overshoot = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.4:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.7:
	set(value):
		warn = value
		_values_dirty = true
## 予告（秒）（第2形態）
@export_range(0,100000,0.01) var warn_p2 := 0.5:
	set(value):
		warn_p2 = value
		_values_dirty = true

## 着地点を先読みする追加時間（秒）
@export_range(0,100000,0.01) var lead_extra := 0.2:
	set(value):
		lead_extra = value
		_values_dirty = true
## 群れが少ないときの跳ぶ回数
@export_range(0,100000,1) var chain := 3:
	set(value):
		chain = value
		_values_dirty = true
## 2回目以降の予告（秒）
@export_range(0,100000,0.01) var chain_warn := 0.45:
	set(value):
		chain_warn = value
		_values_dirty = true
