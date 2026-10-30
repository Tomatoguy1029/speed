## 破片は実際に通った位置を残し、消えるときに航跡の表示へ渡す。
extends FriendShape

func advance(ps: ProjectileSystem, i: int, pos: Vector2, dt: float) -> void:
	super(ps, i, pos, dt)
	if ps.friend_visual[i] == &"weapon/knockback": return
	var trail := ps.friend_trail[i]
	trail.append(pos)
	if trail.size() > ps.cfg.corpse_trail_points:
		trail.remove_at(0)
	ps.friend_trail[i] = trail

func on_end(ps: ProjectileSystem, i: int) -> void:
	if ps.friend_visual[i] == &"weapon/knockback": return
	if ps.friend_trail[i].size() > 1:
		ps.state.emit(&"debris_trail", {"points": ps.friend_trail[i], "color": ps.friend_color[i]})
