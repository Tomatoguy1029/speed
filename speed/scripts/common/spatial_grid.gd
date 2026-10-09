## 一様な格子での近傍探索（設計書 7）。毎回の更新で、敵の配列から作り直す。
##
## セルごとの先頭と、要素ごとの次の要素を PackedInt32Array で持ち、作り直しで新しい配列を作らない。
## 範囲は保持し、外へ出た要素がある時だけ拡張。前回使ったセルだけ空に戻す。
class_name SpatialGrid
extends RefCounted

var cell := 160.0
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var head := PackedInt32Array()
var next := PackedInt32Array()
var items: Array = []
var _used_cells := PackedInt32Array()

## items の各要素は pos（Vector2）と dead（bool）を持つ。
func build(list: Array, cell_size: float) -> void:
	items = list
	var n := list.size()
	if next.size() < n:
		next.resize(n)
	if cols == 0 or cell != cell_size:
		cell = cell_size
		_reset_bounds(list)
	if cols == 0:
		return
	for c in _used_cells:
		head[c] = -1
	_used_cells.clear()
	for i in n:
		var it = list[i]
		if it.dead:
			next[i] = -1
			continue
		var pos: Vector2 = it.pos
		var cx := floori((pos.x - origin.x) / cell)
		var cy := floori((pos.y - origin.y) / cell)
		if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
			# 一部を書き込んだ後でも、全体を空にして新しい範囲で作り直す。
			_reset_bounds(list)
			build(list, cell_size)
			return
		var c := cy * cols + cx
		if head[c] == -1:
			_used_cells.append(c)
		next[i] = head[c]
		head[c] = i

## 初回・範囲外へ移動した時だけ全件から範囲を求める。
func _reset_bounds(list: Array) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for it in list:
		if it.dead:
			continue
		var pos: Vector2 = it.pos
		lo = lo.min(pos)
		hi = hi.max(pos)
	_used_cells.clear()
	if lo.x == INF:
		cols = 0
		rows = 0
		return
	# 移動で毎回境界を越えないよう、4セル分の余白を確保する。
	origin = lo - Vector2(cell * 4.0, cell * 4.0)
	cols = int((hi.x - origin.x) / cell) + 5
	rows = int((hi.y - origin.y) / cell) + 5
	var cells := cols * rows
	if head.size() < cells:
		head.resize(cells)
	head.fill(-1)

## 長方形 lo〜hi に入るセルの要素を out に足す（死んだものは除く）。
func query(lo: Vector2, hi: Vector2, out: Array) -> void:
	out.clear()
	if cols == 0:
		return
	var x0 := clampi(int((lo.x - origin.x) / cell), 0, cols - 1)
	var x1 := clampi(int((hi.x - origin.x) / cell), 0, cols - 1)
	var y0 := clampi(int((lo.y - origin.y) / cell), 0, rows - 1)
	var y1 := clampi(int((hi.y - origin.y) / cell), 0, rows - 1)
	if hi.x < origin.x or hi.y < origin.y or lo.x > origin.x + cols * cell or lo.y > origin.y + rows * cell:
		return
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var i := head[cy * cols + cx]
			while i != -1:
				var it = items[i]
				if not it.dead:
					out.append(it)
				i = next[i]

## 中心 p・半径 r の範囲（要素の半径を含む）に入る要素を out に足す。
func query_radius(p: Vector2, r: float, max_item_r: float, out: Array) -> void:
	var pad := Vector2(r + max_item_r, r + max_item_r)
	query(p - pad, p + pad, out)
	var i := out.size() - 1
	while i >= 0:
		var it = out[i]
		var rr: float = r + it.r
		if it.pos.distance_squared_to(p) > rr * rr:
			out.remove_at(i)
		i -= 1
