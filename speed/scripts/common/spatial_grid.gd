## 一様な格子での近傍探索（設計書 7）。世界側の更新ごとに、敵の表から作り直す。
##
## セルごとの先頭と、行ごとの次の行を PackedInt32Array で持ち、作り直しで新しい配列を作らない。
## 範囲は保持し、外へ出た行がある時だけ拡張。前回使ったセルだけ空に戻す。
## 探索の結果は敵の表の行番号。作り直しの後に撃破された行は結果に入れない。後から出た敵は、次の作り直しで入る。
## 作り直しの後に空きへ戻って別の敵に使い回された行は、古い位置のセルから見つかることがある。
## 呼び出し側は、表の今の位置で線分・円の判定をしてから当てる。
class_name SpatialGrid
extends RefCounted

var cell := 160.0
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var head := PackedInt32Array()
var next := PackedInt32Array()
var table: EnemyTable
var _used_cells := PackedInt32Array()

## 使用中で撃破されていない行を登録する。
func build(enemy_table: EnemyTable, cell_size: float) -> void:
	table = enemy_table
	var alive := table.alive
	var dead := table.dead
	var pos := table.pos
	var n := alive.size()
	if next.size() < n:
		next.resize(n)
	if cols == 0 or cell != cell_size:
		cell = cell_size
		_reset_bounds()
	if cols == 0:
		return
	for c in _used_cells:
		head[c] = -1
	_used_cells.clear()
	for i in n:
		if alive[i] == 0 or dead[i] != 0:
			next[i] = -1
			continue
		var p := pos[i]
		var cx := floori((p.x - origin.x) / cell)
		var cy := floori((p.y - origin.y) / cell)
		if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
			# 一部を書き込んだ後でも、全体を空にして新しい範囲で作り直す。
			_reset_bounds()
			build(enemy_table, cell_size)
			return
		var c := cy * cols + cx
		if head[c] == -1:
			_used_cells.append(c)
		next[i] = head[c]
		head[c] = i

## 初回・範囲外へ移動した時だけ全件から範囲を求める。
func _reset_bounds() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var alive := table.alive
	var dead := table.dead
	var pos := table.pos
	for i in alive.size():
		if alive[i] == 0 or dead[i] != 0:
			continue
		lo = lo.min(pos[i])
		hi = hi.max(pos[i])
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

## 長方形 lo〜hi に入るセルの行を out に入れる（撃破済みは除く）。
func query(lo: Vector2, hi: Vector2, out: PackedInt32Array) -> void:
	out.clear()
	if cols == 0:
		return
	var x0 := clampi(int((lo.x - origin.x) / cell), 0, cols - 1)
	var x1 := clampi(int((hi.x - origin.x) / cell), 0, cols - 1)
	var y0 := clampi(int((lo.y - origin.y) / cell), 0, rows - 1)
	var y1 := clampi(int((hi.y - origin.y) / cell), 0, rows - 1)
	if hi.x < origin.x or hi.y < origin.y or lo.x > origin.x + cols * cell or lo.y > origin.y + rows * cell:
		return
	var alive := table.alive
	var dead := table.dead
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var i := head[cy * cols + cx]
			while i != -1:
				if alive[i] != 0 and dead[i] == 0:
					out.append(i)
				i = next[i]

## 中心 p・半径 r の範囲（敵の半径を含む）に入る行を out に入れる。
func query_radius(p: Vector2, r: float, max_item_r: float, out: PackedInt32Array) -> void:
	var pad := Vector2(r + max_item_r, r + max_item_r)
	query(p - pad, p + pad, out)
	var pos := table.pos
	var rad := table.r
	var w := 0
	for k in out.size():
		var i := out[k]
		var rr: float = r + rad[i]
		if pos[i].distance_squared_to(p) <= rr * rr:
			out[w] = i
			w += 1
	out.resize(w)
