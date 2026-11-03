## 元の敵画像を保ち、光筋を集めて発射輪を作る。
extends EnemyVisual

const LASER = preload("res://scripts/render/pulser_laser.gd")
var _rings: Array[LASER] = []
var _count := 0

func apply_frame(parent: CanvasItem, values: PackedFloat64Array) -> void:
	_count = 0
	for n in range(0,values.size(),6):
		if _count==_rings.size():
			var ring: LASER = LASER.new()
			ring.setup(parent)
			_rings.append(ring)
		_rings[_count].show_ring(Vector2(values[n],values[n+1]),values[n+2],values[n+3],values[n+4],int(values[n+5]))
		_count += 1
	for i in range(_count,_rings.size()): _rings[i].visible = false
