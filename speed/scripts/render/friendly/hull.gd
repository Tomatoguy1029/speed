extends AttackVisual
## 撃ち出された船体。撃った直後は白く焼け、橙に冷めてから元の色に戻る（焼けた輪と炎の尾は装備の表示が描く）。
func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	var key := String(pr.friend_visual[i])
	rm._draw_hull(c, pr.friend_type[i], pos, pr.friend_vel[i].angle(), pr.friend_r[i],
		Color.TRANSPARENT, EFFECT_SETTINGS.tinted(key, Color.WHITE if pr.friend_age[i] < 0.08 else Color("#ffd27a") if pr.friend_age[i] < 0.18 else Color.WHITE))
