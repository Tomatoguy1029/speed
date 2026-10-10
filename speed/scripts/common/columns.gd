## 項目ごとの列で持つデータ（設計書 6）の確認。
##
## 名前の頭が同じメンバー（例：hostile_pos、hostile_vel）を1組の列とみなす。i 番目の行が1つの物。
## 行は前へ詰めず、空いた行は次に加える物に使い回す。確認はデバッグ版だけで行う。
## - aligned：全部の列の長さがそろっているか。assert(Columns.aligned(...)) の形で呼ぶ。
## - check_add：空いた行を使い回すとき、追加の関数が全部の列を書き直しているか。
class_name Columns
extends RefCounted

const _COLUMN_TYPES := [TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY,
	TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY,
	TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY,
	TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]

## 書き忘れを見つけるための目印。追加の関数が普通は書かない値にする。
const _MARK_FLOAT := -987654.25
const _MARK_INT := 117
const _MARK_VEC2 := Vector2(-987654.25, 123456.5)
const _MARK_COLOR := Color(0.123, 0.456, 0.789, 0.321)
static var _mark_object := RefCounted.new()

## obj のメンバーのうち、名前が prefix で始まる列の名前。
static func names(obj: Object, prefix: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for prop in obj.get_property_list():
		var name: String = prop.name
		if name.begins_with(prefix) and prop.type in _COLUMN_TYPES:
			out.append(StringName(name))
	return out

## 全部の列の長さを n にする。列ごとに書かないので、長さの変更で列を書き忘れることはない。
static func resize_all(obj: Object, cols: Array[StringName], n: int) -> void:
	for col in cols:
		obj.get(col).resize(n)

## 列の長さがすべて同じなら true。違えば各列の長さをエラーに出す。
static func aligned(obj: Object, cols: Array[StringName]) -> bool:
	if cols.is_empty():
		return true
	var n: int = obj.get(cols[0]).size()
	for col in cols:
		if obj.get(col).size() != n:
			var sizes: Array[String] = []
			for c in cols:
				sizes.append("%s=%d" % [c, obj.get(c).size()])
			push_error("列の長さがずれている：" + ", ".join(sizes))
			return false
	return true

## 追加の関数 add（引数なしで1行加え、その行番号を返す Callable）が、使い回す行の全部の列を書き直すか。
## free_row は、行を1つ空きにして次の追加で使い回させる Callable（行番号を受け取る）。
## 確認のために加えた行は呼び出し側で消す。書き忘れた列があれば、その名前をエラーに出して false。
static func check_add(obj: Object, cols: Array[StringName], add: Callable, free_row: Callable) -> bool:
	var row: int = add.call()
	free_row.call(row)
	for col in cols:
		_put_mark(obj.get(col), row)
	var reused: int = add.call()
	if reused != row:
		push_error("空いた行が使い回されていない：%d → %d" % [row, reused])
		return false
	var missed: Array[String] = []
	for col in cols:
		if _is_mark(obj.get(col)[row]):
			missed.append(String(col))
	if not missed.is_empty():
		push_error("追加の関数が書き直していない列：" + ", ".join(missed))
		return false
	return true

static func _put_mark(col: Variant, row: int) -> void:
	match typeof(col):
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			col[row] = _MARK_FLOAT
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			col[row] = _MARK_INT
		TYPE_PACKED_VECTOR2_ARRAY:
			col[row] = _MARK_VEC2
		TYPE_PACKED_COLOR_ARRAY:
			col[row] = _MARK_COLOR
		TYPE_ARRAY:
			# 型付き配列には同じ型の目印が入らないので、要素を目印の値の複製に置き換えられる型だけ扱う
			var a: Array = col
			if a.is_typed():
				match a.get_typed_builtin():
					TYPE_DICTIONARY:
						a[row] = {_mark_object: true}
					TYPE_PACKED_VECTOR2_ARRAY:
						a[row] = PackedVector2Array([_MARK_VEC2])
					TYPE_STRING_NAME:
						a[row] = &"__column_mark__"
					TYPE_OBJECT:
						a[row] = null
			else:
				a[row] = _mark_object

static func _is_mark(v: Variant) -> bool:
	match typeof(v):
		TYPE_FLOAT:
			return v == _MARK_FLOAT
		TYPE_INT:
			return v == _MARK_INT
		TYPE_VECTOR2:
			return v == _MARK_VEC2
		TYPE_COLOR:
			return v.is_equal_approx(_MARK_COLOR)
		TYPE_DICTIONARY:
			return v.has(_mark_object)
		TYPE_PACKED_VECTOR2_ARRAY:
			return v.size() == 1 and v[0] == _MARK_VEC2
		TYPE_STRING_NAME:
			return v == &"__column_mark__"
		TYPE_OBJECT:
			return v == _mark_object
		TYPE_NIL:
			return true
	return false
