## 広がるビームは専用の水流の層へ渡す。
extends AttackVisual
func draw_hazard(_c: CanvasItem, _pr: ProjectileSystem, _i: int, _view: Rect2) -> void:
	rm.flood()
