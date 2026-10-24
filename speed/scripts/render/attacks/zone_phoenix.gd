## ほうおう座の炎は、敵の専用層で全個体を同じshaderへまとめて描く。
extends AttackVisual

func draw_hazard(_c: CanvasItem, _pr: ProjectileSystem, _i: int, _view: Rect2) -> void:
	rm._visual_for_type(&"phoenix")
