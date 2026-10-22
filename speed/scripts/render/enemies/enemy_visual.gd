## 敵の見た目の、行動の種類ごとの土台（設計書 10）。種類ごとに res://scripts/render/enemies/<行動名>.gd で上書きする。
##
## RenderManager は、その戦いに出た行動の種類の Visual だけを作り、飾り・種類ごとの演出を任せる。
## ゲームの状態は読むだけで、書き換えない。
class_name EnemyVisual
extends RefCounted

var rm: RenderManager
## 行動の種類の名前（EnemyDef.behavior）
var name: StringName
## 予告・弱点などがなくても、いつも飾りを描く種類か
var always_marked := false
## 背面の弱点の弧を共通の描き方で描くか（自分で描く種類は false）
var draws_weak_arc := true
## 受け取る出来事の種類（state.emit の名前）
var events: Array[StringName] = []

var run: RunSimulation:
	get: return rm.run
var state: RunState:
	get: return rm.state
## 同じ種類の行動の処理（描くための問い合わせに使う）
var behavior: EnemyBehavior:
	get: return rm.run.enemies.behavior(name)

func setup(render: RenderManager, behavior_name: StringName) -> void:
	rm = render
	name = behavior_name

## 1体ぶんの飾り（共通の飾りのあとに描く）。普段は、撃つ前の予告として前の方に光を集める。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var charge := t.charge[i]
	if charge > 0.0:
		var muzzle := t.pos[i] + Vector2.from_angle(t.facing[i]) * t.r[i]
		c.draw_circle(muzzle, _px(3.0) + t.r[i] * 0.45 * charge, Color(1.0, 0.9, 0.6, 0.35 + 0.55 * charge))

## 敵の層の最後に、種類ごとの演出を描く。view は描く範囲。
func draw_layer(_c: CanvasItem, _view: Rect2) -> void:
	pass

## events に入れた出来事を受け取る。
func on_event(_ev: Dictionary) -> void:
	pass

## 演出を進める（実秒。ポーズ中・3択の間は止まる）。
func update(_dt: float) -> void:
	pass

func _px(px: float) -> float:
	return rm._px(px)
