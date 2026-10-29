## 撃ち出した船体・丸鋸。直進し、設定した速さで回転する。
extends FriendShape

func spawn(ps: ProjectileSystem, pos: Vector2, vel: Vector2, r: float, dmg: float, life: float, knock: float, type: StringName,
		angle: float, source_id: int) -> void:
	ps._add_friend(ProjectileSystem.FriendKind.HULL, &"towShot", pos, vel, r, dmg, life, true, 0, Color("#ffbe65"), true, knock,
		angle, 0.0, source_id, type, &"weapon/massTow")
