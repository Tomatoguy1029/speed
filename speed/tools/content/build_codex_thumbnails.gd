## 図鑑の一覧用に、実演の42%の1コマだけを固定データとして保存する。
@tool
extends RefCounted
static func build(output := "res://.content") -> Error:
	for file in DirAccess.get_files_at("res://data/codex"):
		if file.get_extension() != "res": continue
		var animation := load("res://data/codex/"+file) as CodexAnimation
		if animation == null or animation.frames.is_empty(): return ERR_INVALID_DATA
		var thumbnail := CodexAnimation.new()
		thumbnail.period = animation.period
		var frame := mini(animation.frames.size()-1,floori(animation.period*0.42*30.0))
		thumbnail.frames = [animation.frames[frame]]
		var error := ResourceSaver.save(thumbnail,output.path_join("codex_thumbnail_"+file),ResourceSaver.FLAG_COMPRESS)
		if error != OK: return error
	return OK
