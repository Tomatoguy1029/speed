## 列で持つデータ（設計書 6）の、行の空きの管理。
##
## 行は前へ詰めない。生きている物の行番号は、消えるまで変わらない。消えた行は空きにして、次に加える物に使い回す。
## 名前の頭が prefix の列を1組とみなし、prefix + "alive" の列（1 なら使用中）で行が使われているかを表す。
## 空きが無いときは、全部の列をまとめて伸ばす。
class_name RowSlots
extends RefCounted

var owner: Object
var cols: Array[StringName] = []
## 使用中の行の数
var live := 0
var _alive_col: StringName
var _free := PackedInt32Array()

func _init(columns_owner: Object, prefix: String) -> void:
	owner = columns_owner
	cols = Columns.names(owner, prefix)
	_alive_col = StringName(prefix + "alive")
	assert(_alive_col in cols, "列 %s が無い" % _alive_col)

## 行の数（空きを含む）。ループはこの数だけ回し、使用中でない行を飛ばす。
func capacity() -> int:
	return owner.get(_alive_col).size()

## 空いた行を1つ取り、使用中にして返す。ほかの列は呼び出し側が全部書き直す。
func take() -> int:
	if _free.is_empty():
		_grow()
	var i := _free[_free.size() - 1]
	_free.resize(_free.size() - 1)
	owner.get(_alive_col)[i] = 1
	live += 1
	return i

## 行 i を空きにする。
func release(i: int) -> void:
	owner.get(_alive_col)[i] = 0
	_free.append(i)
	live -= 1

## 全部の行を消す。
func clear() -> void:
	Columns.resize_all(owner, cols, 0)
	_free.clear()
	live = 0

func _grow() -> void:
	var cap := capacity()
	var new_cap := cap + maxi(64, cap / 2)
	Columns.resize_all(owner, cols, new_cap)
	# 小さい番号から使うよう、後ろから積む。伸ばした行の alive は 0（空き）
	for i in range(new_cap - 1, cap - 1, -1):
		_free.append(i)
	assert(Columns.aligned(owner, cols))
