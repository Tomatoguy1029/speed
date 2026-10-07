## 1回の更新ぶんの入力の意図（設計書 9）。機器ごとの入力を、この形にまとめてから Manager に渡す。
class_name Intent
extends RefCounted

## 移動：マウスならカーソルの世界座標、タッチなら仮想スティックの向きと倒し具合
var has_cursor := false
var cursor := Vector2.ZERO
var stick := Vector2.ZERO
var stick_active := false
## ペン先：描く位置と、押した瞬間（クリック・タップ・「描く」ボタン）
var pen := Vector2.ZERO
var press := false
## 描画の補助（Space）。押した瞬間
var alt_press := false
## タッチで描いている指を離した
var pen_release := false
var touch := false
