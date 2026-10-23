## 攻撃の種類ごとの表示。状態を読み、描画だけを受け持つ。
class_name AttackVisual
extends RefCounted

const PIXEL_LIGHTNING := preload("res://scripts/render/pixel_lightning.gd")
var rm: RunPresentation
var state: RunState:
	get: return rm.state

func setup(render: RunPresentation) -> void:
	rm = render

## 専用の形を描いた場合はtrue。falseなら共通の弾のバッチで描く。
func draw_shot(_c: CanvasItem, _pr: ProjectileSystem, _i: int, _pos: Vector2) -> bool:
	return false

func draw_hazard(_c: CanvasItem, _pr: ProjectileSystem, _i: int, _view: Rect2) -> void:
	pass

func update(_dt: float) -> void:
	pass

func _px(px: float) -> float:
	return rm._px(px)

func draw_friend(_c: CanvasItem, _projectiles: ProjectileSystem, _row: int, _pos: Vector2) -> void:
	pass
