## 最後に残る粒と全体の乱数列を保ち、確実に上書きされる先頭分だけ組立を省く。
extends RefCounted
const FLOATS := 12
var capacity: int
var cursor := 0
var _pending := PackedFloat32Array()
var _first := 0
var _skip := 0
func _init(limit: int) -> void:
	assert(limit > 0)
	capacity = limit
## 次の同期的なイベント列で最低限出る粒数。未知の追加発生は従来どおり末尾へ積む。
func reserve(minimum: int) -> void:
	if minimum < capacity: return
	# この後だけで容量を埋めるため、既に積んだ粒は必ず上書きされる。
	_pending = PackedFloat32Array()
	_skip = minimum-capacity
func append(pos: Vector2, color: Color, n: int, dir: Vector2, speed: float, life: float, size: float) -> void:
	var skipped := mini(maxi(n,0),_skip)
	for _i in skipped:
		# 元のa・s・life・sizeと同じ4回。他の演出へ続く乱数列を変えない。
		randf()
		randf()
		randf()
		randf()
	_skip -= skipped
	cursor = (cursor+skipped)%capacity
	if n <= skipped: return
	if _pending.is_empty(): _first = cursor
	for _i in n-skipped:
		var a := randf()*TAU
		var s := speed*(0.3+randf())
		var v := Vector2.from_angle(a)*s*0.6+dir*s*0.8
		var l := life*(0.6+randf()*0.6)
		_pending.append_array(PackedFloat32Array([pos.x,pos.y,v.x,v.y,l,l,size*(0.6+randf()*0.8),0.0,
			color.r*1.6,color.g*1.6,color.b*1.6,1.0]))
		cursor = (cursor+1)%capacity
func take_frame() -> Dictionary:
	var count := _pending.size()/FLOATS
	if count > capacity:
		var skip := count-capacity
		_pending = _pending.slice(skip*FLOATS)
		_first = (_first+skip)%capacity
	var result := {"data":_pending,"first":_first}
	clear()
	return result
func is_empty() -> bool:
	return _pending.is_empty() and _skip==0
func clear() -> void:
	_pending = PackedFloat32Array()
	_skip = 0
