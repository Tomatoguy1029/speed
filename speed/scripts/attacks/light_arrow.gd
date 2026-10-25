## ボス共用の光の矢。判定は矢じり、後方の光は尾。配色を変えても同じ形・運動を使う。
extends HostileShape

func spawn(ps: ProjectileSystem, mouth: Vector2, angle: float, speed: float,
		radius: float, travel: float, damage: float, cosmic := false) -> int:
	if speed <= 0.0 or radius <= 0.0 or travel <= 0.0:
		return -1
	var kind := ProjectileSystem.HostileKind.COSMIC_ARROW if cosmic else ProjectileSystem.HostileKind.LIGHT_ARROW
	var row := ps._add_hostile(mouth, Vector2.from_angle(angle) * speed, speed,
		radius, travel / speed, damage, 0.0, 0.0, kind)
	ps.state.emit(&"shoot", {"pos": mouth, "kind": &"arrow"})
	return row
