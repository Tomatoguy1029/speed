## 技の追加に必要なファイル作成。既存の技とファイルを上書きしない。
@tool
extends RefCounted
const PROTOTYPES := {"draco":"tail_sweep", "monoceros":"charge", "centaurus":"volley", "canis_major":"command", "hydra":"bite_thrust"}
static func create(adapter: String, id: String, title: String, script_path: String, from_template: bool) -> Dictionary:
	if not PROTOTYPES.has(adapter): return {"error": ERR_INVALID_PARAMETER, "message": "このボスのひな形がありません。"}
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	if pattern.search(id) == null: return {"error": ERR_INVALID_PARAMETER, "message": "IDは英小文字から始め、英小文字・数字・_で入力してください。"}
	if title.strip_edges().is_empty(): return {"error": ERR_INVALID_PARAMETER, "message": "表示名を入力してください。"}
	var path := "res://data/bosses/%s_moves/%s.tres" % [adapter, id]
	if FileAccess.file_exists(path): return {"error": ERR_ALREADY_EXISTS, "message": "同じIDの技がすでにあります。"}
	if from_template:
		script_path = "res://scripts/bosses/%s/techniques/%s.gd" % [adapter, id]
		if FileAccess.file_exists(script_path): return {"error": ERR_ALREADY_EXISTS, "message": "同じ名前のスクリプトがあります。既存を選んでください。"}
		var base := "res://scripts/bosses/%s/techniques/%s.gd" % [adapter, PROTOTYPES[adapter]]
		var file := FileAccess.open(script_path, FileAccess.WRITE)
		if file == null: return {"error": FileAccess.get_open_error(), "message": "スクリプトを保存できません。"}
		file.store_string("## 技の値と動き。必要な値は @export で追加する。\n@tool\nextends \"%s\"\n\nfunc make_runner() -> RefCounted:\n\treturn Runner.new()\n\nclass Runner extends \"%s\".Runner:\n\tpass\n" % [base, base])
		file.close()
	if script_path.is_empty() or not ResourceLoader.exists(script_path): return {"error": ERR_FILE_NOT_FOUND, "message": "技のスクリプトを選んでください。"}
	var script := load(script_path) as Script
	if script == null or not script.can_instantiate(): return {"error": ERR_INVALID_DATA, "message": "スクリプトを読み込めません。"}
	var move: Variant = script.new()
	if not move is BossTechnique: return {"error": ERR_INVALID_DATA, "message": "BossTechniqueを継承するスクリプトを選んでください。"}
	move.technique = StringName(id)
	move.display_name = title.strip_edges()
	if adapter == "hydra": move.head_kind = &"bite"
	var error := ResourceSaver.save(move, path)
	if error == OK: move = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	return {"error": error, "move": move, "path": path, "script": script_path, "message": "作成しました。条件をつなぐとAIが使います。" if error == OK else "技を保存できません。"}
