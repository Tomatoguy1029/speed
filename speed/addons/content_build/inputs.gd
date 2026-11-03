## 生成の起動・進捗集計と、出力内容を決める処理の境界。
@tool
extends RefCounted

static func affects_output(path: String) -> bool:
	return not path.begins_with("res://addons/content_build/") and path != "res://tools/content/build_all.gd"

## 音と図鑑の専用生成器は、ステージの変換では実行しない。
static func affects_stage(path: String) -> bool:
	return affects_output(path) and path not in ["res://tools/content/build_audio.gd","res://tools/content/build_codex_thumbnails.gd"]
