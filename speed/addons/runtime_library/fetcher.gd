## 同じ識別子のライブラリを公開先から取得し、検証して配置する。
@tool
extends Node
signal finished(result: Result,detail: String)
enum Result {INSTALLED,NOT_PUBLISHED,FAILED}
const STATE := preload("res://addons/runtime_library/runtime_state.gd")
const BASE_URL := "https://github.com/Tomatoguy1029/speed/releases/download/runtime-library/"
const TIMEOUT_SECONDS := 300.0
var busy := false
var _http: HTTPRequest
var _runtime_id := ""
var _expected := ""

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	add_child(_http)

func _asset(runtime_id: String) -> String:
	return BASE_URL+runtime_id+"-"+STATE.library_name()

func fetch(runtime_id: String) -> void:
	if busy: return
	busy = true
	_runtime_id = runtime_id
	_http.download_file = ""
	_http.request_completed.connect(_on_hash,CONNECT_ONE_SHOT)
	if _http.request(_asset(runtime_id)+".sha256") != OK:
		_http.request_completed.disconnect(_on_hash)
		_finish(Result.FAILED,"通信を開始できません")

func _on_hash(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish(Result.FAILED,"公開先へ接続できません")
		return
	if code == 404:
		_finish(Result.NOT_PUBLISHED,"")
		return
	_expected = body.get_string_from_utf8().strip_edges()
	if code != 200 or _expected.length() != 64:
		_finish(Result.FAILED,"公開先の応答が正しくありません")
		return
	DirAccess.make_dir_recursive_absolute(STATE.bin_directory())
	_http.download_file = STATE.library_path()+".download"
	_http.request_completed.connect(_on_library,CONNECT_ONE_SHOT)
	if _http.request(_asset(_runtime_id)) != OK:
		_http.request_completed.disconnect(_on_library)
		_finish(Result.FAILED,"通信を開始できません")

func _on_library(result: int,code: int,_headers: PackedStringArray,_body: PackedByteArray) -> void:
	var downloaded := _http.download_file
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(downloaded)
		_finish(Result.FAILED,"ライブラリを取得できません")
		return
	if FileAccess.get_sha256(downloaded) != _expected:
		DirAccess.remove_absolute(downloaded)
		_finish(Result.FAILED,"取得したファイルが壊れています")
		return
	var error := STATE.replace_library(downloaded,_runtime_id)
	if error != OK:
		DirAccess.remove_absolute(downloaded)
		_finish(Result.FAILED,"ライブラリを置き換えられません: "+error_string(error))
		return
	_finish(Result.INSTALLED,"")

func _finish(result: Result,detail: String) -> void:
	busy = false
	finished.emit(result,detail)
