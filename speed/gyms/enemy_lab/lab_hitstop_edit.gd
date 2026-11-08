## ライブ編集で変わった停止倍率だけを、生成済みの他の表と共通スキーマで書き直す。
extends RefCounted
const SCHEMA := preload("res://tools/content/generated/run_schema.gd")

static func build(records: Dictionary, type: String, value: float) -> Dictionary:
	if records.is_empty() or not is_finite(value) or value<0.0: return {}
	var id := 0
	for entry: Dictionary in records.StringEntry:
		if entry.value==type:
			id = int(entry.id)
			break
	if id==0: return {}
	var next := records.duplicate()
	next.EnemyRecord = records.EnemyRecord.duplicate(true)
	var found := false
	for row: Dictionary in next.EnemyRecord:
		if int(row.id)==id:
			row.hitstop_multiplier = value
			found = true
			break
	if not found: return {}
	var bytes := SCHEMA.write_content(next,SCHEMA.sha256(var_to_bytes(next)))
	return {} if bytes.is_empty() else {"records":next,"bytes":bytes}
