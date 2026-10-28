## ぎょしゃ座。
extends EnemyBehavior

func _init() -> void:
	# 移動を続けながら、帯を出す直前に攻撃の枠を取る。
	admission = false

func step(i: int, dt: float) -> void:
	_drive(i, dt)
	_auriga(i, dt)

## ぎょしゃ座：王の戦車。走った跡に、左右の車輪の跡が燃えて残る。
func _auriga(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.fire_t[i] -= dt
	if t.fire_t[i] > 0.0:
		return
	if not _lab_admit(i, dt):
		return
	t.fire_t[i] = float(p.trail_step)
	var seg := t.vel[i] * float(p.trail_step)
	var side := Vector2.from_angle(t.facing[i] + PI / 2.0) * float(p.wheel_gap)
	for s: float in [-1.0, 1.0]:
		var from := t.pos[i] - seg + side * s
		projectiles.fire_wall(from, seg.angle(), seg.length(), float(p.trail_width), 0.0, float(p.trail_time),
			float(p.bullet_dmg), Color("#ff8a3c"))
