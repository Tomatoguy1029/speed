## 一様な格子での近傍探索（設計書 7）。毎回の更新で、敵の配列から作り直す。
##
## セルごとの先頭と、要素ごとの次の要素を PackedInt32Array で持ち、作り直しで新しい配列を作らない。
## 範囲は毎回、要素の位置の最小・最大から決める。
class_name SpatialGrid
extends RefCounted

var cell := 160.0
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var head := PackedInt32Array()
var next := PackedInt32Array()
var items: Array = []

## items の各要素は pos（Vector2）と dead（bool）を持つ。
func build(list: Array, cell_size: float) -> void:
	cell = cell_size
	items = list
	var n := list.size()
	if next.size() < n:
		next.resize(n)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for it in list:
		if it.dead:
			continue
		lo = lo.min(it.pos)
		hi = hi.max(it.pos)
	if lo.x == INF:
		cols = 0
		rows = 0
		return
	origin = lo - Vector2(cell, cell)
	cols = int((hi.x - origin.x) / cell) + 2
	rows = int((hi.y - origin.y) / cell) + 2
	var cells := cols * rows
	if head.size() < cells:
		head.resize(cells)
	head.fill(-1)
	for i in n:
		var it = list[i]
		if it.dead:
			next[i] = -1
			continue
		var cx := int((it.pos.x - origin.x) / cell)
		var cy := int((it.pos.y - origin.y) / cell)
		var c := cy * cols + cx
		next[i] = head[c]
		head[c] = i

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
