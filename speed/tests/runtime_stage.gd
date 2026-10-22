## 実行用のステージは、配置を数値へ展開し、編集用の名前とシーン参照を外す。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var path := "res://tools/content/build_runtime_stage.gd"
	check(ResourceLoader.exists(path), "RuntimeStageの生成器がある")
	if ResourceLoader.exists(path):
		var builder = load(path)
		var source: StageDef = ContentManager.stage(4).duplicate(true)
		var clip := SpawnClip.new()
		clip.label = "recording_label"
		clip.formations = [load("res://data/formations/telescope_reticle.tscn")]
		source.clips = [clip]
		var runtime: StageDef = builder.compile(source)
		check(runtime.get_script().resource_path.ends_with("runtime_stage.gd"), "実行用の型を生成する")
		check(runtime.track_names.is_empty() and runtime.scene_path.is_empty(), "編集用の情報を外す")
		check(runtime.phases[0] != source.phases[0] and runtime.phases[0].display_name.is_empty(), "時間帯の値を独立して持ち、名前を外す")
		check(runtime.clips[0].label.is_empty() and runtime.clips[0].formations.is_empty(), "クリップにラベルとシーンを持たない")
		check(not runtime.clips[0].prepared.is_empty(), "展開済みの配置を持つ")
		check(builder.names(source).clips[0] == "recording_label", "記録用の名前を別の表に保存する")
		var minimal := StageDef.new()
		minimal.enemies = [&"drifter"]
		var prepared: Resource = builder.compile(minimal)
		var manifest: Resource = prepared.get("resources")
		check(manifest != null, "ステージが使う資源の一覧を生成する")
		if manifest != null:
			check(not "res://shaders/water_flood.gdshader" in manifest.paths, "水流を使わないステージの一覧に水流shaderを入れない")

	print("[runtime_stage] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
