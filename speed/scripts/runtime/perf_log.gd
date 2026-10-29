## 開発版の処理時間の記録先（設計書 14）。読む側（F3 の表示・ベンチ・F9 の録画）ごとに別の記録を持ち、
## 互いの集計を消さない。読む側がいない間は時間を取らない。
##
## 記録は 項目名 → [合計, 回数, 1回の最大]。時間はマイクロ秒、数は個数。名前に「.」を含む項目は、前半の名前の項目の内訳。
class_name PerfLog
extends RefCounted

## 読む側の名前 → 記録
var _sinks: Dictionary = {}
## 読む側が1つでもあるか
var active := false

## 読む側の記録を開いて返す。同じ名前なら同じ記録を返す。空にするのは読む側の役目。
func open(reader: StringName) -> Dictionary:
	if not _sinks.has(reader):
		_sinks[reader] = {}
	active = true
	return _sinks[reader]

func close(reader: StringName) -> void:
	_sinks.erase(reader)
	active = not _sinks.is_empty()

## key の記録に value を足す。
func add(key: StringName, value: int) -> void:
	for records: Dictionary in _sinks.values():
		var rec: Array = records.get(key, [0, 0, 0])
		rec[0] += value
		rec[1] += 1
		rec[2] = maxi(rec[2], value)
		records[key] = rec

## 読む側がいれば、start_us からの経過時間を key に足す。
func since(key: StringName, start_us: int) -> void:
	if active:
		add(key, Time.get_ticks_usec() - start_us)
