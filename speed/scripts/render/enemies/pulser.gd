## 元の敵画像を保ち、光筋を集めて発射輪を作る。
extends EnemyVisual

const LASER = preload("res://scripts/render/pulser_laser.gd")
const PULSER = preload("res://scripts/enemies/pulser.gd")
var _rings: Array[LASER] = []
var _count := 0

func draw_marks(_c: CanvasItem, _t: EnemyTable, _i: int) -> void:
	pass

## 装甲のCanvasLayerより前に置く。通常の白い被弾表示には触れない。
func draw_layer(_c: CanvasItem, view: Rect2) -> void:
	_count = 0
	var t: EnemyTable = run.enemies.table
	if not state.cinematic_hide_enemies:
		for i in behavior.rows():
			if t.dead[i] != 0 or t.held[i] != 0 or t.stone[i] > 0.0 or t.pump_owner[i] >= 0:
				continue
			if t.mode[i] != EnemyTable.Mode.WINDUP:
				continue
			var radius: float = PULSER.ring_radius(t, i)
			var p: Dictionary = t.def[i].params
			var width: float = float(p.wave_width)
			if not view.grow(radius + width * 16.0).has_point(t.pos[i]):
				continue
			if _count == _rings.size():
				var ring: LASER = LASER.new()
				ring.setup(rm._lit_enemy_marks)
				_rings.append(ring)
			var progress: float = 1.0 - clampf(t.timer[i] / maxf(float(p.telegraph), 0.001), 0.0, 1.0)
			_rings[_count].show_ring(t.pos[i], radius, width, progress, t.id[i] % 4093)
			_count += 1
	for i in range(_count, _rings.size()):
		_rings[i].visible = false
