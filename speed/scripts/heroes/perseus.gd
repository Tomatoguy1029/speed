extends HeroBehavior

## ペルセウス座（メドゥーサの首）：画面の中の敵と敵の弾を、効いている間、石にして止める。ボスは少しの間止まるだけ。
func activate() -> void:
	var view := state.view_rect()
	var t := enemies.table
	for i in t.alive.size():
		if t.alive[i] == 0 or t.dead[i] != 0 or t.meteor_index[i] >= 0:
			continue
		if not view.has_point(t.pos[i]):
			continue
		if t.is_boss[i] != 0:
			state.boss_stun = float(def.params.get("boss_stun", 1.5))
		else:
			t.stone[i] = def.duration
	projectiles.stone_hostile(view, def.duration)
