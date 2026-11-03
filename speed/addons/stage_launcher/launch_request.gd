## ステージの直接起動の予約を、エディタ（プラグイン）とゲームの間で受け渡す（設計書 14.1）。
##
## 受け渡しに user:// のファイルを使う。project.godot の起動引数を書き換える方法は
## コミットに乗ってしまうため使わない。user:// はエディタと実行中のゲームで同じ場所になる。
##
## 予約は1回だけ有効。ゲーム側が起動時に読んだ直後に消すので、その後の F5 が
## 直接起動に化けることはない。
##
## この道具は Godot 本体だけに依存する（設計書 4.1）。ステージのシーンの置き場所は
## プロジェクト設定 stage_launcher/stage_dir から読む。
class_name StageLaunchRequest
extends RefCounted

const PATH := "user://stage_launch.cfg"
const SECTION := "launch"
const SETTING_DIR := "stage_launcher/stage_dir"
## ステージのシーンの名前（<STAGE_PREFIX><番号>.tscn）
const STAGE_PREFIX := "stage_"

## 最後に読んだ予約の開始時刻（秒）。consume が書く
static var start_time := 0.0
## 起動の入口。旧形式の予約は unknown として受け取る。
static var source := "unknown"
## 途中再生の生成結果。予約を消費するときだけ受け取り、次の起動へ残さない。
static var content: Dictionary = {}

## 起動を予約する（エディタ側から呼ぶ）。start は、ランの時計をこの時刻から始める（出現タイムラインの「ここから試す」）。
static func request(stage: int, start := 0.0, entry := "stage_launcher", source_path := "") -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 直前のステージの記録を残したいので、失敗しても続ける
	cfg.set_value(SECTION, "pending", true)
	cfg.set_value(SECTION, "stage", stage)
	cfg.set_value(SECTION, "start", start)
	cfg.set_value(SECTION, "source", entry)
	cfg.set_value(SECTION, "source_path", source_path)
	cfg.set_value(SECTION, "content", {})
	cfg.set_value(SECTION, "last_stage", stage)
	cfg.save(PATH)

## 予約を読み、同時に消す。予約がなければ 0。ゲームの起動時に1回だけ呼ぶ。
static func consume() -> int:
	start_time = 0.0
	source = "unknown"
	content = {}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	if not bool(cfg.get_value(SECTION, "pending", false)):
		return 0
	var stage := int(cfg.get_value(SECTION, "stage", 0))
	start_time = float(cfg.get_value(SECTION, "start", 0.0))
	source = str(cfg.get_value(SECTION, "source", "unknown"))
	var prepared: Variant = cfg.get_value(SECTION, "content", {})
	if prepared is Dictionary: content = prepared.duplicate(true)
	cfg.set_value(SECTION, "pending", false)
	cfg.set_value(SECTION, "content", {})
	cfg.set_value(SECTION, "start", 0.0)
	cfg.save(PATH)
	return stage

## 実行前フックが、保存した途中再生の制作元と生成先を受け渡す。
static func pending_timeline() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not cfg.get_value(SECTION, "pending", false) or cfg.get_value(SECTION, "source", "") != "timeline": return {}
	return {"stage":cfg.get_value(SECTION,"stage",0),"time":cfg.get_value(SECTION,"start",0.0),"source":cfg.get_value(SECTION,"source_path","")}

static func set_timeline_content(prepared: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	var error := cfg.load(PATH)
	if error != OK: return error
	if not cfg.get_value(SECTION,"pending",false) or cfg.get_value(SECTION,"source","") != "timeline": return ERR_INVALID_DATA
	cfg.set_value(SECTION,"content",prepared)
	return cfg.save(PATH)

## 直前に直接起動したステージ。記録がなければ 0。
static func last_stage() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value(SECTION, "last_stage", 0))

## シーンのパスからステージの番号を得る。ステージのシーンでなければ 0。
##   "res://scenes/stages/stage_3.tscn" → 3
static func stage_from_path(path: String) -> int:
	var dir := str(ProjectSettings.get_setting(SETTING_DIR, ""))
	if dir == "" or not path.begins_with(dir):
		return 0
	var base := path.get_file().get_basename()
	if not base.begins_with(STAGE_PREFIX):
		return 0
	var num := base.trim_prefix(STAGE_PREFIX)
	return num.to_int() if num.is_valid_int() else 0

## 起動するステージを決める：編集中のステージ → 直前に起動したステージ → ステージ1。
static func resolve(edited_path: String) -> int:
	var stage := stage_from_path(edited_path)
	if stage > 0:
		return stage
	var last := last_stage()
	return last if last > 0 else 1
