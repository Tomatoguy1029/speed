## 項目ごとの列で持つデータ（設計書 6）の、列の長さがそろっているかの確認。
##
## 名前の頭が同じメンバー（例：hostile_pos、hostile_vel）を1組の列とみなす。
## assert(Columns.aligned(...)) の形で呼び、デバッグ版だけで確認する。
class_name Columns
extends RefCounted

const _COLUMN_TYPES := [TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY,
	TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY,
	TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY,
	TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]

## obj のメンバーのうち、名前が prefix で始まる列の名前。
static func names(obj: Object, prefix: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for prop in obj.get_property_list():
		var name: String = prop.name
		if name.begins_with(prefix) and prop.type in _COLUMN_TYPES:
			out.append(StringName(name))
	return out

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
