## 機体の能力値。基礎値・レベル・特性・強化画面での強化から計算する（設計書 8.2）。
## 伝説のモジュールはこの計算に入れない（仕様書 20.3）。
class_name ShipStats
extends RefCounted

var max_speed := 0.0
var max_hp := 0.0
## 攻撃力の倍率（基礎攻撃力にかける）
var attack_mult := 1.0
var crit_chance := 0.0
var crit_mult := 2.5
var pickup_radius := 0.0
## 1単位の充填にかかる実秒
var charge_time := 0.0
## ゲージの容量（1 ＋ 0.2 × 大容量チャージ）
var capacity := 1.0
## 描ける長さの倍率（軌跡延長）
var length_mult := 1.0
var xp_mult := 1.0
