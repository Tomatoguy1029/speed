## C++検査の観測値を展開し、保持前後の違いを表示する。
extends RefCounted
const FORMAT_VERSION := 1

func vector(value: Vector2) -> Array:
	return [value.x, value.y]

## JSON往復で失われる型を明示的に展開する。乱数の64bit値は上で文字列にする。
func plain(value: Variant) -> Variant:
	if value is Vector2:
		return vector(value)
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	if value is StringName:
		return String(value)
	if value is Dictionary:
		var out := {}
		for key in value:
			out[String(key)] = plain(value[key])
		return out
	if value is Array or value is PackedVector2Array or value is PackedInt32Array or value is PackedFloat32Array:
		var out: Array = []
		for item in value:
			out.append(plain(item))
		return out
	return value

## 最初に食い違う値の場所を返す。数値誤差を一律に捨てない。
func difference(left: Variant, right: Variant, path := "result") -> String:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return path + ": 項目数が違う"
		for key in left:
			if not right.has(key):
				return path + "." + str(key) + ": 項目がない"
			var found := difference(left[key], right[key], path + "." + str(key))
			if not found.is_empty(): return found
		return ""
	if left is Array and right is Array:
		if left.size() != right.size(): return path + ": 要素数が違う"
		for i in left.size():
			var found := difference(left[i], right[i], path + "[%d]" % i)
			if not found.is_empty(): return found
		return ""
	return "" if left == right else path + ": %s != %s" % [str(left), str(right)]

## 比較を明示的に起動したときだけ読み込む。通常ランへ未完成の実体を混ぜない。
func create_native() -> RefCounted:
	if not ClassDB.class_exists(&"SpeedRunCore"):
		GDExtensionManager.load_extension("res://extensions/run/run_core.gdextension")
	if not ClassDB.class_exists(&"SpeedRunCore"):
		return null
	return ClassDB.instantiate(&"SpeedRunCore")

var semantics_f64_error := 0.0
var semantics_vector_error := 0.0
var semantics_numeric_values := 0

## 設計15.1。整数・列順・接触は既存の厳密比較を保つ。
func semantics_difference(left: Variant, right: Variant, path := "result") -> String:
	if left is Vector2 and right is Vector2:
		var error: float=left.distance_to(right)
		semantics_vector_error=maxf(semantics_vector_error,error)
		semantics_numeric_values+=1
		return "" if error<=1e-4 else path+": Vector2誤差 %s > 1e-4"%error
	if left is float and right is float:
		var error: float=absf(left-right)
		semantics_f64_error=maxf(semantics_f64_error,error)
		semantics_numeric_values+=1
		return "" if is_finite(left) and is_finite(right) and error<=maxf(1e-9,maxf(absf(left),absf(right))*1e-9) else path+": f64 %s != %s"%[left,right]
	if left is Dictionary and right is Dictionary:
		if left.size()!=right.size():return path+": 項目数が違う"
		for key in left:
			if not right.has(key):return path+"."+str(key)+": 項目がない"
			var found:=semantics_difference(left[key],right[key],path+"."+str(key))
			if not found.is_empty():return found
		return ""
	if left is Array and right is Array:
		if left.size()!=right.size():return path+": 要素数が違う"
		for i in left.size():
			var found:=semantics_difference(left[i],right[i],path+"[%d]"%i)
			if not found.is_empty():return found
		return ""
	return difference(left,right,path)
